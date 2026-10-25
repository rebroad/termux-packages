#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Install ReBroad's signed APT source and give its packages first priority.
# Other Termux mirrors remain enabled and supply packages absent here.
: "${PREFIX:=/data/data/com.termux/files/usr}"
base="https://raw.githubusercontent.com/rebroad/termux-packages/apt-repo"
key_sha256="49f10af5d74a3e79508693d80a4ccaa9f86200ce654b6b853ac0ebade6577bfc"
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
echo "Archive key fingerprint: 1ED97E796A59F08B22CE7CACFFF9DB83A50BE6C9"
apt-get update
apt-cache policy sccache
