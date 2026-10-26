#!/usr/bin/env bash
set -euo pipefail

# Run from a checked-out apt-repo worktree. The package manifest is read from
# this script's package-recipes checkout; PACKAGE_DIR contains built aarch64 debs.
: "${PACKAGE_DIR:?Missing PACKAGE_DIR}"
: "${REBROAD_APT_GPG_PRIVATE_KEY:?Missing private key secret}"
passphrase="${REBROAD_APT_GPG_PASSPHRASE:-}"
expected_fpr="98812D13BCDBF9125D44E0DA8C6E5024C203FC56"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
manifest="${PACKAGE_MANIFEST:-$script_dir/rebroad-upstream-packages.json}"

mapfile -t manifest_package_names < <(python3 - "$manifest" <<'PY'
import json
import sys
for item in json.load(open(sys.argv[1], encoding="utf-8"))["packages"]:
    print(item["name"])
PY
)
((${#manifest_package_names[@]} > 0)) || { echo "Package manifest is empty" >&2; exit 1; }

declare -A listed=() selected=() seen=()
for name in "${manifest_package_names[@]}"; do
    [[ -z "${listed[$name]-}" ]] || { echo "Duplicate manifest package: $name" >&2; exit 1; }
    listed["$name"]=1
done

if [[ -n "${PACKAGE_NAMES:-}" ]]; then
    IFS=',' read -r -a package_names <<< "$PACKAGE_NAMES"
else
    package_names=("${manifest_package_names[@]}")
fi
((${#package_names[@]} > 0)) || { echo "No packages selected" >&2; exit 1; }
for name in "${package_names[@]}"; do
    [[ -n "${listed[$name]-}" ]] || { echo "Package not in manifest: $name" >&2; exit 1; }
    [[ -z "${selected[$name]-}" ]] || { echo "Duplicate selected package: $name" >&2; exit 1; }
    selected["$name"]=1
done

shopt -s nullglob
debs=("$PACKAGE_DIR"/*.deb)
if [[ "${#debs[@]}" -ne "${#package_names[@]}" ]]; then
    echo "Expected ${#package_names[@]} selected aarch64 packages; got ${#debs[@]}" >&2
    exit 1
fi

for pkg in "${debs[@]}"; do
    name=$(dpkg-deb --field "$pkg" Package)
    arch=$(dpkg-deb --field "$pkg" Architecture)
    [[ -n "${listed[$name]-}" ]] || { echo "Package not in manifest: $name" >&2; exit 1; }
    [[ "$arch" == aarch64 ]] || { echo "Unexpected architecture for $name: $arch" >&2; exit 1; }
    [[ -z "${seen[$name]-}" ]] || { echo "Duplicate package: $name" >&2; exit 1; }
    seen["$name"]=1

    first_letter="${name:0:1}"
    package_pool="pool/main/$first_letter/$name"
    mkdir -p "$package_pool"
    rm -f "$package_pool"/"${name}"_*_aarch64.deb
    cp -- "$pkg" "$package_pool/"
done

for name in "${package_names[@]}"; do
    [[ -n "${seen[$name]-}" ]] || { echo "Missing package: $name" >&2; exit 1; }
done

export GNUPGHOME
GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"
apt_keyring=$(mktemp)
trap 'rm -rf -- "$GNUPGHOME"; rm -f -- "$apt_keyring"' EXIT

printf '%s\n' "$REBROAD_APT_GPG_PRIVATE_KEY" | gpg --batch --pinentry-mode loopback --passphrase "${passphrase}" --import
actual_fpr=$(gpg --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')
[[ "$actual_fpr" == "$expected_fpr" ]] || {
    echo "Wrong APT signing key: $actual_fpr" >&2
    exit 1
}

mkdir -p dists/stable/main/binary-aarch64
dpkg-scanpackages -a aarch64 pool/main /dev/null > dists/stable/main/binary-aarch64/Packages
gzip -n -9 -c dists/stable/main/binary-aarch64/Packages > dists/stable/main/binary-aarch64/Packages.gz

python3 - <<'PY'
import email.utils
import hashlib
from pathlib import Path

d = Path("dists/stable")
files = [
    "main/binary-aarch64/Packages",
    "main/binary-aarch64/Packages.gz",
]
head = [
    "Origin: ReBroad",
    "Label: ReBroad Termux",
    "Suite: stable",
    "Codename: stable",
    "Date: " + email.utils.formatdate(usegmt=True),
    "Architectures: aarch64",
    "Components: main",
    "Description: ReBroad Termux native packages (experimental)",
    "SHA256:",
]
for name in files:
    blob = (d / name).read_bytes()
    head.append(f" {hashlib.sha256(blob).hexdigest()} {len(blob):16d} {name}")
(d / "Release").write_text("\n".join(head) + "\n", encoding="utf-8")
PY

gpg --batch --yes --pinentry-mode loopback --passphrase "${passphrase}" \
    --local-user "$expected_fpr" --output dists/stable/InRelease \
    --clearsign dists/stable/Release
gpg --batch --yes --pinentry-mode loopback --passphrase "${passphrase}" \
    --local-user "$expected_fpr" --output dists/stable/Release.gpg \
    --detach-sign dists/stable/Release
gpg --batch --no-default-keyring --keyring "$apt_keyring" --import ./rebroad-archive-key.asc
gpgv --keyring "$apt_keyring" dists/stable/InRelease

echo "Signed APT index for ${#package_names[@]} selected packages"
sha256sum "${debs[@]}"
