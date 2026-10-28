TERMUX_PKG_HOMEPAGE=https://github.com/rebroad/scrcpy
TERMUX_PKG_DESCRIPTION="Provides display and control of Android devices (ReBroad fork)"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="@rebroad"
TERMUX_PKG_VERSION="5.0.1-20261028+rebroad1"
TERMUX_PKG_SRCURL=git+https://github.com/rebroad/scrcpy.git
TERMUX_PKG_GIT_BRANCH=master
TERMUX_PKG_SHA256=SKIP_CHECKSUM
TERMUX_PKG_DEPENDS="android-tools, ffmpeg, libusb, sdl3"
TERMUX_PKG_ANTI_BUILD_DEPENDS="android-tools"
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-Dprebuilt_server=$TERMUX_PKG_BUILDDIR/server-build/scrcpy-server
"

termux_step_pre_configure() {
	local actual
	actual=$(git -C "$TERMUX_PKG_SRCDIR" rev-parse HEAD)
	if [[ "$actual" != "4c9651632a6855ca08d9a0404e140c134aca0a0f" ]]; then
		termux_error_exit "ReBroad scrcpy source changed: expected 4c9651632a6855ca08d9a0404e140c134aca0a0f, got $actual"
	fi
	: "${ANDROID_HOME:=$HOME/lib/android-sdk-$TERMUX_SDK_REVISION}"
	export ANDROID_HOME
	BUILD_DIR="$TERMUX_PKG_BUILDDIR/server-build" \
	ANDROID_PLATFORM=35 \
	ANDROID_BUILD_TOOLS="$TERMUX_ANDROID_BUILD_TOOLS_VERSION" \
		./server/build_without_gradle.sh
}
