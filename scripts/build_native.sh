#!/usr/bin/env bash
# Build libVLC and its third-party dependencies (contribs) for OpenHarmony
# (aarch64-linux-ohos), and stage the shared libraries in entry/libs/arm64-v8a,
# where hvigor packs them into the HAP.
#
# The Oniro App Store CI runs this before hvigor (see
# .github/workflows/oniro-store.yml); it works the same on a developer machine.
#
# Usage: scripts/build_native.sh [--install-deps] [STEP...]
#
# Steps, run in this order when none is given:
#   contribs   build the contribs into libvlc/contrib/aarch64-linux-ohos
#   libvlc     configure and build libVLC, install it into vlc_install/
#   stage      copy libvlc, libvlccore and the plugins into entry/libs/arm64-v8a
#
# --install-deps installs the host build tools with apt-get first (Ubuntu 24.04).
# It is implied on GitHub Actions, where the store's workflow runs this script
# without arguments.
#
# Environment:
#   OHOS_NDK_HOME       OpenHarmony NDK ("native" directory of the SDK). Default:
#                       $OHOS_BASE_SDK_HOME/<api>/native, where <api> is the
#                       compileSdkVersion in build-profile.json5 (or OHOS_SDK_API)
#                       and OHOS_BASE_SDK_HOME defaults to ~/setup-ohos-sdk/linux.
#   JOBS                parallel make jobs (default: nproc).
#
# Every step is incremental: run it again after a change and only what changed
# is rebuilt. Delete libvlc/contrib/contrib-ohos-aarch64-linux-ohos (contribs)
# or run `make distclean` in libvlc/ (libVLC) to start over.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VLC_SRC="$ROOT_DIR/libvlc"
TARGET=aarch64-linux-ohos
CONTRIB_BUILD="$VLC_SRC/contrib/contrib-ohos-$TARGET"
CONTRIB_PREFIX="$VLC_SRC/contrib/$TARGET"
VLC_PREFIX="$ROOT_DIR/vlc_install"
LIBS_DIR="$ROOT_DIR/entry/libs/arm64-v8a"
JOBS=${JOBS:-$(nproc)}

# Host tools for the contribs and libVLC's autotools build.
APT_PACKAGES=(
  autoconf autoconf-archive automake autopoint bison bzip2 cmake curl flex
  gettext git gperf libltdl-dev libtool libtool-bin lzip make meson ninja-build
  patch pkg-config python3 python3-jinja2 python3-mako texinfo unzip wget xxd
  xz-utils zip
)

# Contribs a phone player does not need. Disc packages (DVD, Blu-ray, CDDB)
# and encoders (x264, x265, lame, ...) are left out by the bootstrap options,
# and libVLC is configured without stream output to match. aom is an AV1
# decoder too, but dav1d already decodes AV1.
PKGS_DISABLE="protobuf lua xcb srt aom"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

install_deps() {
  log "Installing host build tools"
  local sudo=()
  [ "$(id -u)" -eq 0 ] || sudo=(sudo)
  "${sudo[@]}" apt-get update -q
  DEBIAN_FRONTEND=noninteractive "${sudo[@]}" apt-get install -y -q --no-install-recommends "${APT_PACKAGES[@]}"
}

setup_toolchain() {
  if [ -z "${OHOS_NDK_HOME:-}" ]; then
    local api=${OHOS_SDK_API:-}
    if [ -z "$api" ]; then
      api=$(grep -oE '"compileSdkVersion"[[:space:]]*:[[:space:]]*[0-9]+' "$ROOT_DIR/build-profile.json5" | head -n1 | grep -oE '[0-9]+$') ||
        die "cannot read compileSdkVersion from build-profile.json5; set OHOS_SDK_API or OHOS_NDK_HOME"
    fi
    OHOS_NDK_HOME="${OHOS_BASE_SDK_HOME:-$HOME/setup-ohos-sdk/linux}/$api/native"
  fi
  local llvm="$OHOS_NDK_HOME/llvm/bin"
  SYSROOT="$OHOS_NDK_HOME/sysroot"
  [ -x "$llvm/clang" ] || die "no clang in $llvm (set OHOS_NDK_HOME to the SDK's native directory)"
  [ -d "$SYSROOT" ] || die "no sysroot at $SYSROOT"

  CC_BIN="$llvm/clang"
  CXX_BIN="$llvm/clang++"
  AR="$llvm/llvm-ar"
  NM="$llvm/llvm-nm"
  RANLIB="$llvm/llvm-ranlib"
  STRIP="$llvm/llvm-strip"
  STRINGS="$llvm/llvm-strings"
  OBJDUMP="$llvm/llvm-objdump"
  TARGET_FLAGS="--target=$TARGET --sysroot=$SYSROOT"
  # 16 KB pages: the alignment OpenHarmony devices load libraries with.
  PAGE_FLAGS="-Wl,-z,max-page-size=16384"

  # The command-line tools ship a broken diff in openharmony/toolchains, which
  # breaks the contribs' patching when it is on PATH.
  PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/openharmony/toolchains/*$' | paste -sd: -)
  export PATH

  echo "NDK: $OHOS_NDK_HOME ($("$CC_BIN" --version | head -n1))"
}

build_contribs() {
  [ -f "$VLC_SRC/contrib/bootstrap" ] || die "libvlc/ is empty: run git submodule update --init"
  log "Building the contribs (${JOBS} jobs)"
  mkdir -p "$CONTRIB_BUILD"
  cd "$CONTRIB_BUILD"
  if [ ! -f Makefile ]; then
    ../bootstrap --build=x86_64-linux-gnu --host="$TARGET" --disable-disc --disable-sout
  fi
  cat > config.mak <<EOF
EXTRA_CFLAGS=$TARGET_FLAGS -fPIC
EXTRA_CXXFLAGS=
EXTRA_LDFLAGS=$TARGET_FLAGS $PAGE_FLAGS
CC=$CC_BIN
CXX=$CXX_BIN
AR=$AR
AS=$CC_BIN -c
RANLIB=$RANLIB
LD=$CC_BIN
NM=$NM
STRIP=$STRIP
STRINGS=$STRINGS
OBJDUMP=$OBJDUMP
PKGS_DISABLE += $PKGS_DISABLE
EOF
  make list
  # Downloads are checked against the SHA512SUMS of each package.
  make -j"$JOBS" fetch
  make -j"$JOBS"
}

build_libvlc() {
  [ -d "$CONTRIB_PREFIX/lib" ] || die "no contribs in $CONTRIB_PREFIX: run the contribs step first"
  log "Building libVLC (${JOBS} jobs)"
  cd "$VLC_SRC"
  [ -x configure ] || ./bootstrap
  # The autotools config.sub does not know the ohos OS name.
  if ! grep -q 'linux-ohos' autotools/config.sub; then
    sed -i -e 's/linux-android\*/linux-android*|linux-ohos*|ohos*/g' -e 's/android\*/android* | ohos*/g' autotools/config.sub
  fi
  if [ ! -f Makefile ]; then
    PKG_CONFIG_LIBDIR="$CONTRIB_PREFIX/lib/pkgconfig" PKG_CONFIG_PATH="" PKG_CONFIG="pkg-config --static" \
    ./configure \
      --host="$TARGET" \
      --prefix="$VLC_PREFIX" \
      --with-contrib="$CONTRIB_PREFIX" \
      --disable-a52 \
      --disable-xcb \
      --disable-qt \
      --disable-skins2 \
      --disable-vlc \
      --enable-nls=no \
      --disable-alsa \
      --disable-pulse \
      --disable-jack \
      --disable-sndio \
      --disable-wayland \
      --disable-v4l2 \
      --disable-lua \
      --disable-dbus \
      --disable-shout \
      --disable-taglib \
      --disable-visual \
      --disable-sout \
      CC="$CC_BIN $TARGET_FLAGS" \
      CXX="$CXX_BIN $TARGET_FLAGS" \
      CFLAGS="-fPIC" \
      CXXFLAGS="-fPIC" \
      LDFLAGS="$PAGE_FLAGS -lc++_shared" \
      AR="$AR" NM="$NM" RANLIB="$RANLIB" STRIP="$STRIP" OBJDUMP="$OBJDUMP"
  fi
  make -j"$JOBS"
  make install
}

stage_libs() {
  [ -f "$VLC_PREFIX/lib/libvlc.so" ] || die "no libVLC in $VLC_PREFIX: run the libvlc step first"
  log "Staging the libraries in ${LIBS_DIR#"$ROOT_DIR"/}"
  rm -rf "$LIBS_DIR"
  mkdir -p "$LIBS_DIR"
  # Only the sonames are loaded at runtime (libvlcnative needs libvlc.so.5 and
  # libvlccore.so.9); the build links against vlc_install/lib directly.
  local lib soname
  for lib in libvlc.so libvlccore.so; do
    soname=$("$OBJDUMP" -p "$VLC_PREFIX/lib/$lib" | awk '/SONAME/ { print $2 }')
    cp -L "$VLC_PREFIX/lib/$soname" "$LIBS_DIR/"
  done
  # VLC_PLUGIN_PATH points at the bundle's library directory, which is flat.
  find "$VLC_PREFIX/lib/vlc/plugins" -name '*.so' -exec cp -L -t "$LIBS_DIR/" {} +
  "$STRIP" --strip-unneeded "$LIBS_DIR"/*.so*
  echo "$(find "$LIBS_DIR" -type f | wc -l) libraries, $(du -sh "$LIBS_DIR" | cut -f1)"
}

steps=()
for arg in "$@"; do
  case "$arg" in
    --install-deps) INSTALL_DEPS=1 ;;
    contribs | libvlc | stage) steps+=("$arg") ;;
    -h | --help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) die "unknown argument: $arg (see --help)" ;;
  esac
done
[ "${#steps[@]}" -gt 0 ] || steps=(contribs libvlc stage)
[ "${GITHUB_ACTIONS:-}" != true ] || INSTALL_DEPS=1

[ -z "${INSTALL_DEPS:-}" ] || install_deps
setup_toolchain
for step in "${steps[@]}"; do
  case "$step" in
    contribs) build_contribs ;;
    libvlc) build_libvlc ;;
    stage) stage_libs ;;
  esac
done
