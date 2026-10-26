#!/usr/bin/env python3
"""Refresh pinned source commits and package versions from the manifest."""
import argparse
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument(
    "--package",
    action="append",
    dest="package_names",
    help="refresh only this manifest-listed package (may be repeated)",
)
args = parser.parse_args()
manifest_path = root / "scripts/rebroad-upstream-packages.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
packages = manifest["packages"]
if args.package_names:
    requested = set(args.package_names)
    available = {package["name"] for package in packages}
    unknown = requested - available
    if unknown:
        raise SystemExit(f"Unknown package(s): {', '.join(sorted(unknown))}")
    packages = [package for package in packages if package["name"] in requested]
timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
changed = []

for package in packages:
    name = package["name"]
    repo = package["repository"]
    branch = package["branch"]
    old_commit = package["source_commit"]
    ref = f"refs/heads/{branch}"
    result = subprocess.run(
        ["git", "ls-remote", f"https://github.com/{repo}.git", ref],
        check=True, capture_output=True, text=True,
    )
    rows = [line.split() for line in result.stdout.splitlines() if line.strip()]
    if len(rows) != 1 or len(rows[0][0]) != 40:
        raise SystemExit(f"Could not resolve exactly one HEAD for {repo}:{branch}")
    new_commit = rows[0][0]
    if new_commit == old_commit:
        print(f"{name}: unchanged at {new_commit}")
        continue

    recipe = root / "packages" / name / "build.sh"
    text = recipe.read_text(encoding="utf-8")
    if old_commit not in text:
        raise SystemExit(f"{recipe}: expected source pin {old_commit} was not found")
    text = text.replace(old_commit, new_commit)
    version = f"{package['version_prefix']}.{timestamp}.g{new_commit[:8]}"
    text, count = re.subn(
        r"(?m)^TERMUX_PKG_VERSION=.*$",
        f'TERMUX_PKG_VERSION="{version}"',
        text,
    )
    if count != 1:
        raise SystemExit(f"{recipe}: expected one TERMUX_PKG_VERSION assignment, found {count}")
    recipe.write_text(text, encoding="utf-8")
    package["source_commit"] = new_commit
    changed.append((name, old_commit, new_commit, version))
    print(f"{name}: {old_commit[:12]} -> {new_commit[:12]} ({version})")

if changed:
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {len(changed)} package(s)")
else:
    print("No upstream updates found")
