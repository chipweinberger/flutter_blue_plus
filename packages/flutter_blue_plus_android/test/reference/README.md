# Original Android contract

`java/com/jmx/flutter_blue_plus/FlutterBluePlusPlugin.java` is the unmodified Android backend from commit `348f0480c9e6761aae350417195b9eabd3bc45fb` (package 9.0.5), retained solely as a test reference. It is not part of the runtime plugin or its Android source set.

The opt-in AndroidBluetooth audit harness compiles it alongside native comparison tests. `LegacyContractFixtureTest` generates `contract.json` by calling its real service and advertisement serializers; `legacy_contract_test.dart` compares the migrated backend's complete serialized models with that output. The fixture covers unique characteristics, repeated characteristics, repeated services, included services, properties, descriptors, and repeated manufacturer fields.

Check the fixture against the original implementation from `packages/android_bluetooth/example/android`:

```sh
./gradlew :android_bluetooth:testDebugUnitTest \
  --init-script ../../tool/flutter_blue_plus_audit/compare.gradle --console=plain
```

To intentionally regenerate it, add `-PupdateFbpContract=true` and select `--tests com.jamcorder.android_bluetooth.LegacyContractFixtureTest`. Review fixture changes against the retained source; do not regenerate it from the new Dart backend.
