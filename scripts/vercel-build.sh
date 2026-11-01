#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

readonly FLUTTER_VERSION='3.41.6'
readonly FLUTTER_REVISION='db50e20168db8fee486b9abf32fc912de3bc5b6a'
# Vercel strips Git metadata from cached SDKs, which breaks Flutter's version
# checks. Use a fresh SDK checkout and cache only downloaded Pub packages.
readonly FLUTTER_SDK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/messhub-flutter.XXXXXX")"

export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
export PUB_CACHE="$PWD/.vercel/cache/pub"

git clone --depth 1 --branch "$FLUTTER_VERSION" \
  https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"

if [ "$(git -C "$FLUTTER_SDK_DIR" rev-parse HEAD)" != "$FLUTTER_REVISION" ]; then
  echo 'Flutter SDK revision does not match the pinned version.' >&2
  exit 1
fi
export PATH="$FLUTTER_SDK_DIR/bin:$PATH"

flutter --disable-analytics
flutter config --enable-web
flutter precache --web

# Web notification methods are guarded; mobile credentials are never needed.
# Preserve any real native configuration when this script is run locally.
if [ ! -f lib/utils/secrets.dart ]; then
  cp lib/utils/secrets.dart.example lib/utils/secrets.dart
fi

flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
flutter test test/available_app_update_test.dart test/user_profile_privacy_test.dart test/auth_session_test.dart
flutter build web --release
node scripts/prepare-vercel-output.mjs
