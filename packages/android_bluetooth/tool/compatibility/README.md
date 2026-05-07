# Compatibility test hosts

The normal package tests use the current Flutter SDK. `minimum_host` separately pins the effective minimum Flutter/Dart line: Flutter 3.10.6, Dart 3.0.6, Android compile/target SDK 33, AGP 7.4.2, Gradle 7.6.4 and JDK 17. The package itself still declares Dart 3.0+ and Flutter 3.7+; Flutter 3.10 is the first stable Flutter line containing Dart 3.0.

This is a real Flutter application with a path dependency on the package. It runs the shared Dart contract/lifecycle tests, builds an Android APK, and runs the native core tests against the older host's actual Flutter embedding. It does not use a Flutter services stub or copied production sources. The fixture declares compatible development dependencies independently of the current example app.

Install the pinned Flutter SDK, JDK 17 and Android platform 33, then run from the package directory:

```sh
FLUTTER_MINIMUM_HOME=/path/to/flutter-3.10.6 \
JAVA_HOME=/path/to/jdk-17 \
ANDROID_SDK_ROOT=/path/to/android-sdk \
  ./tool/compatibility/check_minimum.sh
```

The script checks its Flutter/JDK versions and writes only ignored host-local configuration and build outputs. It does not download or select a different Flutter/JDK installation. Gradle downloads its pinned distribution and normal development dependencies as needed. Use macOS or Linux for this shell runner.

Core Java tests live in `android/src/test/java` and run on APIs 33 and 36, with individual older-version cases. The minimum host filters out runtime SDKs newer than its compile SDK. Tests requiring API 36 types live in `android/src/testApi36/java` and are added only when the library builds with compile SDK 36+. This preserves core coverage in the older host while testing advanced ranging/socket behavior in the current example host:

```sh
cd example/android
./gradlew :android_bluetooth:testDebugUnitTest --console=plain
```

The SDK 33 native tests use Robolectric 4.12.2; SDK 36 builds use 4.17. This keeps newer framework types out of the older test classpath. Both are development-only dependencies. The AndroidX-only minimum fixture disables Jetifier.

Setting only `androidBluetoothCompileSdk=33` in the current example does not substitute for the minimum host: the current Flutter embedding has its own newer AndroidX requirements. The dedicated host keeps Flutter, Android dependencies and compile SDK consistent. Physical-device radio and OEM behavior remain separate integration checks.
