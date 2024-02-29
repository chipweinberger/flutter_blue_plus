package com.lib.flutter_blue_plus;

import java.time.LocalDateTime

interface INearestDeviceResolver {

    val devices: List<BLEDevice>
    val nearestDevice: BLEDevice?

    fun addSample(sample: BLESample)
    fun refreshNearestDevice(timestamp: LocalDateTime)
    fun clearUnreachableDevices(from: LocalDateTime)
}