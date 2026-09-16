#!/usr/bin/env bash
# Builds the release APK and drops the whole project into a zip.
#
# Usage:
#   ./tool/build_release.sh              # build + zip
#   ./tool/build_release.sh --no-zip     # build only
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# ---------------------------------------------------------------- toolchain
# Point at whatever SDK/JDK this machine has, without hard-coding paths that
# only exist on one box.
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/android-sdk}}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"

if [ -z "${JAVA_HOME:-}" ]; then
  for candidate in \
    /usr/lib/jvm/java-17-openjdk-amd64 \
    /usr/lib/jvm/java-17-openjdk \
    "$(dirname "$(dirname "$(readlink -f "$(command -v java 2>/dev/null)" 2>/dev/null)" 2>/dev/null)" 2>/dev/null)"
  do
    if [ -x "$candidate/bin/java" ]; then
      export JAVA_HOME="$candidate"
      break
    fi
  done
fi

if ! command -v flutter >/dev/null 2>&1; then
  if [ -x "$HOME/flutter/bin/flutter" ]; then
    export PATH="$PATH:$HOME/flutter/bin"
  else
    echo "ERROR: flutter not on PATH and not at ~/flutter/bin" >&2
    exit 1
  fi
fi

echo "==> flutter   : $(command -v flutter)"
echo "==> ANDROID_HOME: $ANDROID_HOME"
echo "==> JAVA_HOME : ${JAVA_HOME:-(system default)}"
echo

# ------------------------------------------------------------------- checks
echo "==> analyzing"
flutter analyze

echo
echo "==> running tests"
flutter test

# -------------------------------------------------------------------- build
echo
echo "==> building release APK"
# --no-tree-shake-icons: categories store their icon as a code point in the
# database, so the icon set is chosen at runtime and the compiler cannot prove
# which glyphs are reachable. Without this flag the build fails outright with
# "Avoid non-constant invocations of IconData".
flutter build apk --release --no-tree-shake-icons

APK="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK" ]; then
  echo "ERROR: APK not produced at $APK" >&2
  exit 1
fi

SIZE="$(du -h "$APK" | cut -f1)"
echo
echo "==> APK ready: $APK ($SIZE)"

# ---------------------------------------------------------------- packaging
STAMP="$(date +%Y%m%d-%H%M)"
OUT_DIR="$PROJECT_DIR/dist"
ZIP="$OUT_DIR/duitku-$STAMP.zip"

mkdir -p "$OUT_DIR"
cp "$APK" "$OUT_DIR/duitku-$STAMP.apk"

if [ "${1:-}" != "--no-zip" ]; then
  echo "==> packaging source"
  # Source archive excludes build output, caches and toolchain state so the
  # zip stays small enough to move around.
  zip -q -r "$ZIP" . \
    -x "build/*" \
    -x ".dart_tool/*" \
    -x "android/.gradle/*" \
    -x "android/app/.cxx/*" \
    -x "dist/*" \
    -x ".git/*" \
    -x "*.iml" \
    -x "ios/*" -x "web/*" -x "linux/*" -x "macos/*" -x "windows/*"

  echo "==> source zip: $ZIP ($(du -h "$ZIP" | cut -f1))"
fi

echo
echo "Done."
ls -lh "$OUT_DIR" | tail -n +2
