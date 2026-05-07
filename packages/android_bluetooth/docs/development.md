# Development and validation

## Source layout

- `lib/android_bluetooth.dart` is the public library. Its feature parts in `lib/src/` contain both API models and the callback result types used by their streams. `host.dart` owns channel transport and registration event routing.
- `AndroidBluetoothPlugin.java` coordinates engine/activity lifecycle, channels, pending replies and broadcasts. `AdapterBridge`, `DeviceBridge`, and `EnvironmentBridge` handle adapter/device operations, permissions, location state and foreground-service requests. `BluetoothCodec` contains shared wire-value and snapshot helpers.
- `GattBridge` owns registration lookup and dispatch. `GattClient`, `GattServer`, and `GattAttributes` contain central operations, peripheral operations and shared attribute identity/snapshot handling.
- Other native bridges follow their feature names. `android/src/api36/java/` holds optional SDK 36 sources; `android/src/testApi36/java/` holds their tests.
- Dart tests are grouped by feature under `test/`; `test/support/bluetooth_test_host.dart` supplies shared channel mocks and payload fixtures. Native tests share `PluginTestSupport` and `GattTestSupport` in their test package, where they can access package-private implementation types.

## Validation

From the package directory:

```sh
flutter analyze
flutter test
```

From `example/android`, using the current host's JDK:

```sh
./gradlew :android_bluetooth:testDebugUnitTest :android_bluetooth:lintDebug :app:assembleRelease
```

The [minimum-version host](../tool/compatibility/README.md) runs the same Dart feature suites with the older Flutter/Dart SDK, builds its APK and runs the native core suite. Keep its `test/package_test.dart` imports in sync when adding a test file. The [FlutterBluePlus audit](flutter_blue_plus_compatibility.md#validation-and-migration-gate) documents the optional comparison probes against the existing backend.

Format Dart with `dart format --line-length 120`. These checks cover transport, parsing, identity and lifecycle behavior; real-device tests cover radio interoperability and OEM behavior.

## Tested toolchains

The example is verified with Flutter 3.47.5 / Dart 3.13.4, Android compile/target SDK 36, AGP 9.0.1, Gradle 9.1.0 and JDK 21. It uses AGP's built-in Kotlin support. The tested Flutter SDK still requires `android.newDsl=false` for its Android extension integration. These are tested build versions, not claims that every older Flutter/Gradle combination works. The [minimum-version host](../tool/compatibility/README.md) uses real Flutter 3.10.6 / Dart 3.0.6, SDK 33, AGP 7.4.2, Gradle 7.6.4 and JDK 17. It runs the shared Dart tests, builds an Android APK and runs native core tests. SDK 36-only tests are isolated in their own source set, while the current host runs core tests on APIs 33 and 36. API 36-only ranging/presence sources are compiled only with SDK 36. Read-only typed-list views were [added in Dart 3.3](https://api.dart.dev/dart-typed_data/Uint8List/asUnmodifiableView.html); on Dart 3.0–3.2 byte getters return isolated copies and shared snapshot bytes remain immutable lists.
