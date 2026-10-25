#!/usr/bin/env bash
set -euo pipefail

# Called from a checked-out apt-repo branch in GitHub Actions, with
# REBROAD_APT_GPG_PRIVATE_KEY and REBROAD_APT_GPG_PASSPHRASE secrets.
: "${PACKAGE_DIR:?Missing PACKAGE_DIR}"
: "${REBROAD_APT_GPG_PRIVATE_KEY:?Missing private key secret}"
: "${REBROAD_APT_GPG_PASSPHRASE:?Missing private key passphrase secret}"
expected_fpr="1ED97E796A59F08B22CE7CACFFF9DB83A50BE6C9"

declare -A expected_versions=(
    [sccache]="0.19.0+rebroad1"
    [htop]="3.6.0-dev+rebroad1"
)
declare -A seen_packages=()

shopt -s nullglob
debs=("$PACKAGE_DIR"/*.deb)
if [[ "${#debs[@]}" -ne 2 ]]; then
    echo "Expected one aarch64 DEB for sccache and htop; got ${#debs[@]}" >&2
    exit 1
fi

for pkg in "${debs[@]}"; do
    name=$(dpkg-deb --field "$pkg" Package)
    version=$(dpkg-deb --field "$pkg" Version)
    arch=$(dpkg-deb --field "$pkg" Architecture)
    expected_version="${expected_versions[$name]-}"
    [[ -n "$expected_version" ]] || { echo "Unexpected package: $name" >&2; exit 1; }
    [[ "$version" == "$expected_version" ]] || {
        echo "Unexpected $name version: $version (expected $expected_version)" >&2
        exit 1
    }
    [[ "$arch" == aarch64 ]] || { echo "Unexpected architecture for $name: $arch" >&2; exit 1; }
    [[ -z "${seen_packages[$name]-}" ]] || { echo "Duplicate package: $name" >&2; exit 1; }
    seen_packages["$name"]=1

    first_letter="${name:0:1}"
    package_pool="pool/main/$first_letter/$name"
    mkdir -p "$package_pool"
    rm -f "$package_pool"/"${name}"_*_aarch64.deb
    cp -- "$pkg" "$package_pool/"
done

for name in "${!expected_versions[@]}"; do
    [[ -n "${seen_packages[$name]-}" ]] || { echo "Missing package: $name" >&2; exit 1; }
done

export GNUPGHOME
GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"
trap 'rm -rf -- "$GNUPGHOME"' EXIT

printf '%s\n' "$REBROAD_APT_GPG_PRIVATE_KEY" | gpg --batch --pinentry-mode loopback --passphrase "$REBROAD_APT_GPG_PASSPHRASE" --import
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

gpg --batch --yes --pinentry-mode loopback --passphrase "$REBROAD_APT_GPG_PASSPHRASE" \
    --local-user "$expected_fpr" --output dists/stable/InRelease \
    --clearsign dists/stable/Release
gpg --batch --yes --pinentry-mode loopback --passphrase "$REBROAD_APT_GPG_PASSPHRASE" \
    --local-user "$expected_fpr" --output dists/stable/Release.gpg \
    --detach-sign dists/stable/Release
gpg --batch --keyring ./rebroad-keyring.gpg --import rebroad-archive-key.asc
gpgv --keyring ./rebroad-keyring.gpg dists/stable/InRelease
rm -f ./rebroad-keyring.gpg

echo "Signed APT index for sccache and htop"
sha256sum "${debs[@]}"
