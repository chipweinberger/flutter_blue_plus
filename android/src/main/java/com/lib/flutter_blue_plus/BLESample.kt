package com.lib.flutter_blue_plus;

import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import java.time.LocalDateTime

data class BLESample(
    val deviceId: String,
    val alias: String?,
    val timestamp: LocalDateTime,
    val txPower: Int?,
    val rxPower: Int?,
    val device: BluetoothDevice,
    val result: ScanResult
)