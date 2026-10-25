TERMUX_PKG_HOMEPAGE=https://github.com/rebroad/sccache
TERMUX_PKG_DESCRIPTION="ReBroad sccache with daemon-free in-process cache access"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="@rebroad"
TERMUX_PKG_VERSION=0.19.0+rebroad1
TERMUX_PKG_SRCURL=git+https://github.com/rebroad/sccache.git
TERMUX_PKG_GIT_BRANCH=in-process-cache-v0.19.0
TERMUX_PKG_SHA256=SKIP_CHECKSUM
TERMUX_PKG_DEPENDS="openssl"
TERMUX_PKG_BUILD_IN_SRC=true

# A moving Git branch is not a reproducible package source. The build must
# exactly match the reviewed in-process cache source revision.
termux_step_post_get_source() {
	local actual
	actual=$(git -C "$TERMUX_PKG_SRCDIR" rev-parse HEAD)
	if [[ "$actual" != "c097bfaba06bb21c6248b32c30033df3a45086c0" ]]; then
		termux_error_exit "ReBroad sccache source changed: expected c097bfaba06bb21c6248b32c30033df3a45086c0, got $actual"
	fi
}

termux_step_make() {
	termux_setup_rust
	cargo build --locked --jobs "$TERMUX_PKG_MAKE_PROCESSES" --target "$CARGO_TARGET_NAME" --release
}

termux_step_make_install() {
	install -Dm700 -t "$TERMUX_PREFIX/bin" "target/${CARGO_TARGET_NAME}/release/sccache"
}
