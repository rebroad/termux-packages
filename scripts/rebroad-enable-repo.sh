#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Install ReBroad's signed APT source and give its packages first priority.
# Other Termux mirrors remain enabled and supply packages absent here.
: "${PREFIX:=/data/data/com.termux/files/usr}"
base="https://raw.githubusercontent.com/rebroad/termux-packages/apt-repo"
key_sha256="781529826d4994690e2466a094bce31f53ae154c14c463accb1ff1ca18cc78eb"
repo_key="$PREFIX/etc/apt/keyrings/rebroad.asc"
list_file="$PREFIX/etc/apt/sources.list.d/rebroad.list"
pin_file="$PREFIX/etc/apt/preferences.d/00-rebroad"

if [[ "$(dpkg --print-architecture)" != "aarch64" ]]; then
    echo "ReBroad repository currently publishes aarch64 only; refusing unsupported architecture." >&2
    exit 1
fi

tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
curl --fail --location --silent --show-error "$base/rebroad-archive-key.asc" --output "$tmp"
printf '%s  %s\n' "$key_sha256" "$tmp" | sha256sum --check --status || {
    echo "ReBroad APT signing public key failed its pinned SHA-256 check." >&2
    exit 1
}

mkdir -p "$PREFIX/etc/apt/keyrings" "$PREFIX/etc/apt/sources.list.d" "$PREFIX/etc/apt/preferences.d"
install -m 644 "$tmp" "$repo_key"
cat > "$list_file" <<EOF
deb [arch=aarch64 signed-by=$repo_key] $base stable main
EOF
cat > "$pin_file" <<'EOF'
Package: *
Pin: release o=ReBroad
Pin-Priority: 1001
EOF
echo "Enabled signed ReBroad APT feed with priority 1001 (official Termux mirrors remain enabled)."
echo "Archive key fingerprint: D707B230D33E2AA09C0B979FAC3209C81372E53A"
apt-get update
apt-cache policy sccache
