TERMUX_PKG_HOMEPAGE=https://github.com/rebroad/htop
TERMUX_PKG_DESCRIPTION="Interactive process viewer for Linux (ReBroad fork)"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@rebroad"
TERMUX_PKG_VERSION="3.6.0-dev+rebroad1"
TERMUX_PKG_SRCURL=git+https://github.com/rebroad/htop.git
TERMUX_PKG_GIT_BRANCH=main
TERMUX_PKG_SHA256=SKIP_CHECKSUM
TERMUX_PKG_DEPENDS="libandroid-support, ncurses"
TERMUX_PKG_BREAKS="htop-legacy"
TERMUX_PKG_CONFLICTS="htop-legacy"
TERMUX_PKG_REPLACES="htop-legacy"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_RM_AFTER_INSTALL="share/applications share/pixmaps"

# The fork includes Android fallbacks for restricted /proc/stat access.
# Pin the exact reviewed commit so the git source stays reproducible.
termux_step_post_get_source() {
	local actual
	actual=$(git -C "$TERMUX_PKG_SRCDIR" rev-parse HEAD)
	if [[ "$actual" != "b282c8a2c0f7d0ecd3c352dd387f05865db6ce9d" ]]; then
		termux_error_exit "ReBroad htop source changed: expected b282c8a2c0f7d0ecd3c352dd387f05865db6ce9d, got $actual"
	fi
}

termux_step_pre_configure() {
	./autogen.sh
}

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--disable-static
ac_cv_lib_ncursesw6_addnwstr=yes
LIBS=-landroid-support
"
