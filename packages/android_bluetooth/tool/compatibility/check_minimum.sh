#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/minimum_host" && pwd)"
flutter_sdk="${FLUTTER_MINIMUM_HOME:?Set FLUTTER_MINIMUM_HOME to Flutter 3.10.6}"
android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
java_home="${JAVA_HOME:?Set JAVA_HOME to JDK 17}"
flutter_bin="$flutter_sdk/bin/flutter"

if [[ -z "$android_sdk" ]]; then
    printf '%s\n' 'Set ANDROID_SDK_ROOT or ANDROID_HOME to an Android SDK with platform 33 installed.' >&2
    exit 1
fi
flutter_version="$("$flutter_bin" --version)"
if [[ "$flutter_version" != *'Flutter 3.10.6 '* ]]; then
    printf '%s\n' 'This fixture requires Flutter 3.10.6 (Dart 3.0.6).' >&2
    exit 1
fi
java_version="$("$java_home/bin/java" -version 2>&1)"
if [[ "$java_version" != *'version "17.'* ]]; then
    printf '%s\n' 'This fixture requires JDK 17 for Gradle and Robolectric.' >&2
    exit 1
fi

printf 'flutter.sdk=%s\nsdk.dir=%s\nflutter.buildMode=debug\n' "$flutter_sdk" "$android_sdk" \
    > "$fixture_dir/android/local.properties"
cd "$fixture_dir"
"$flutter_bin" pub get
"$flutter_bin" analyze
"$flutter_bin" test --reporter expanded
# Invoke Gradle directly so Flutter's Android Studio JDK preference cannot
# override the pinned JAVA_HOME in this fixture.
cd android
./gradlew :app:assembleDebug :android_bluetooth:testDebugUnitTest --console=plain
