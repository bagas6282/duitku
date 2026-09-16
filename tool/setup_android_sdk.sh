#!/usr/bin/env bash
# Installs the minimum Android SDK needed to build a release APK.
#
# Only platform-tools + the one build-tools/platform pair Flutter targets are
# fetched — the full SDK bundle is several GB and mostly emulator images we
# do not need on a build box.
set -euo pipefail

SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
CMDLINE_ZIP="commandlinetools-linux-11076708_latest.zip"
CMDLINE_URL="https://dl.google.com/android/repository/${CMDLINE_ZIP}"

API_LEVEL="${API_LEVEL:-35}"
BUILD_TOOLS="${BUILD_TOOLS:-35.0.0}"

mkdir -p "$SDK_ROOT/cmdline-tools"
cd /tmp

if [ ! -d "$SDK_ROOT/cmdline-tools/latest" ]; then
  echo "==> fetching command-line tools"
  curl -fsSL -o "$CMDLINE_ZIP" "$CMDLINE_URL"
  unzip -q -o "$CMDLINE_ZIP" -d /tmp/android-cmdline
  rm -rf "$SDK_ROOT/cmdline-tools/latest"
  mv /tmp/android-cmdline/cmdline-tools "$SDK_ROOT/cmdline-tools/latest"
fi

export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:$PATH"

echo "==> accepting licenses"
yes | sdkmanager --licenses >/dev/null 2>&1 || true

echo "==> installing platform-tools, platforms;android-$API_LEVEL, build-tools;$BUILD_TOOLS"
sdkmanager --install \
  "platform-tools" \
  "platforms;android-${API_LEVEL}" \
  "build-tools;${BUILD_TOOLS}" \
  2>&1 | tail -n 5

echo "==> configuring flutter"
flutter config --android-sdk "$SDK_ROOT" >/dev/null 2>&1 || true
flutter config --jdk-dir "$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")" \
  >/dev/null 2>&1 || true

echo "==> sdk contents"
ls "$SDK_ROOT"
echo "ANDROID_SDK_ROOT=$SDK_ROOT"
