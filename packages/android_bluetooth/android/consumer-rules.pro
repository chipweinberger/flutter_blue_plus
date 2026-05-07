# This public callback was added in API 36.1. The plugin compiles against 33 or 36,
# so R8 cannot infer the override and would otherwise rename/remove it.
-keepclassmembers class com.jamcorder.android_bluetooth.** extends android.bluetooth.BluetoothGattCallback {
    public void onSubrateChange(android.bluetooth.BluetoothGatt, int, int);
}
-keepclassmembers class com.jamcorder.android_bluetooth.** extends android.companion.CompanionDeviceManager$Callback {
    public void onFailure(int, java.lang.CharSequence);
}
# Loaded only when the optional API 36 source set is built and used at runtime.
-keep class com.jamcorder.android_bluetooth.RangingBridge {
    <init>(com.jamcorder.android_bluetooth.AndroidBluetoothPlugin);
}
