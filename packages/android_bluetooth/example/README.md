# AndroidBluetooth BLE explorer

Run `flutter pub get` and `flutter run` on an Android device. The app requests Bluetooth permissions when you start an operation.

* Scan and select a device to connect/discover GATT services.
* Expand services to read or subscribe to characteristics.
* Start peripheral mode to advertise a readable/writable FFF0/FFF1 service.
* Listen for an insecure LE L2CAP peer; the event log shows the dynamic PSM. The listener echoes received bytes.
* Select a peer, enter its PSM, and connect/send a sample L2CAP payload.

L2CAP needs Android 10+ and a compatible peer. Peripheral advertising depends on hardware support. Stop the app's operations or leave the screen to close registrations. The example is an explorer; build application-specific prepared-write transactions and protocol framing in your own app.

From `android`, run `./gradlew :android_bluetooth:testDebugUnitTest` for the plugin's native contract tests.
