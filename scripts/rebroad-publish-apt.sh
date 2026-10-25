#!/usr/bin/env bash
set -euo pipefail

# Called from a checked-out apt-repo branch in GitHub Actions, with
# REBROAD_APT_GPG_PRIVATE_KEY and REBROAD_APT_GPG_PASSPHRASE secrets.
: "${PACKAGE_DIR:?Missing PACKAGE_DIR}"
: "${REBROAD_APT_GPG_PRIVATE_KEY:?Missing private key secret}"
: "${REBROAD_APT_GPG_PASSPHRASE:?Missing private key passphrase secret}"
expected_fpr="D707B230D33E2AA09C0B979FAC3209C81372E53A"

shopt -s nullglob
debs=("$PACKAGE_DIR"/sccache_*_aarch64.deb)
if [[ "${#debs[@]}" -ne 1 ]]; then
    echo "Expected exactly one aarch64 sccache package; got ${#debs[@]}" >&2
    exit 1
fi
pkg="${debs[0]}"
[[ "$(dpkg-deb --field "$pkg" Package)" == sccache ]] || exit 1
[[ "$(dpkg-deb --field "$pkg" Architecture)" == aarch64 ]] || exit 1
[[ "$(dpkg-deb --field "$pkg" Version)" == "0.18.0+rebroad1" ]] || exit 1

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

mkdir -p pool/main/s/sccache dists/stable/main/binary-aarch64
# Replace only sccache for this architecture; keep any future other packages.
rm -f pool/main/s/sccache/sccache_*_aarch64.deb
cp -- "$pkg" pool/main/s/sccache/
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

gpg --batch --yes --pinentry-mode loopback --passphrase "$REBROAD_APT_GPG_PASSPHRASE"     --local-user "$expected_fpr" --output dists/stable/InRelease     --clearsign dists/stable/Release
gpg --batch --yes --pinentry-mode loopback --passphrase "$REBROAD_APT_GPG_PASSPHRASE"     --local-user "$expected_fpr" --output dists/stable/Release.gpg     --detach-sign dists/stable/Release
gpg --batch --yes --keyring ./rebroad-keyring.gpg --import rebroad-archive-key.asc
gpgv --keyring ./rebroad-keyring.gpg dists/stable/InRelease
rm -f ./rebroad-keyring.gpg

echo "Signed APT index for $pkg"
sha256sum "$pkg"
