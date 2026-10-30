TERMUX_PKG_HOMEPAGE=https://github.com/rebroad/sccache
TERMUX_PKG_DESCRIPTION="ReBroad sccache with daemon-free in-process cache access"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="@rebroad"
TERMUX_PKG_VERSION="0.19.0+rebroad2.20261029105629.gb8166766"
TERMUX_PKG_SRCURL=git+https://github.com/rebroad/sccache.git
TERMUX_PKG_GIT_BRANCH=main
TERMUX_PKG_SHA256=SKIP_CHECKSUM
TERMUX_PKG_DEPENDS="openssl"
TERMUX_PKG_BUILD_IN_SRC=true

# A moving Git branch is not a reproducible package source. The build must
# exactly match the pinned sccache main branch commit.
termux_step_post_get_source() {
	local actual
	actual=$(git -C "$TERMUX_PKG_SRCDIR" rev-parse HEAD)
	if [[ "$actual" != "b8166766ba94489a7a49dd33121893a9e9fc3e06" ]]; then
		termux_error_exit "ReBroad sccache source changed: expected b8166766ba94489a7a49dd33121893a9e9fc3e06, got $actual"
	fi
}

termux_step_make() {
	termux_setup_rust
	cargo build --locked --jobs "$TERMUX_PKG_MAKE_PROCESSES" --target "$CARGO_TARGET_NAME" --release
}

termux_step_make_install() {
	install -Dm700 -t "$TERMUX_PREFIX/bin" "target/${CARGO_TARGET_NAME}/release/sccache"
}
