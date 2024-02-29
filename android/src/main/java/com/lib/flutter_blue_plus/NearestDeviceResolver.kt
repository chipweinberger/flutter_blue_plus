package com.lib.flutter_blue_plus;

import java.time.LocalDateTime
import java.util.Timer
import java.util.TimerTask


class NearestDeviceResolver(private val nearestDeviceChangedListener: NearestDeviceChangedListener) :
    INearestDeviceResolver {

    companion object {
        private const val NEAREST_DEVICE_TIMEOUT = 1000L // milliseconds
        private const val TAG: String = "NearestDeviceResolver"
    }

    private var currentNearestDevice: BLEDevice? = null
    private var nearestDeviceAssignTimestamp: LocalDateTime? = null

    override val devices: ArrayList<BLEDevice> = arrayListOf()
    override var nearestDevice: BLEDevice? = null


    override fun addSample(sample: BLESample) {
        val device = findDevice(sample)
        device.addSample(sample)
        refreshNearestDevice(sample.timestamp)
    }

    private var timer: Timer? = null

    override fun refreshNearestDevice(timestamp: LocalDateTime) {
//        clearUnreachableDevices(timestamp.minus(UNREACHABLE_DEVICE_TIMEOUT, ChronoUnit.MILLIS))
        currentNearestDevice = getNearestDevice(devices)

        //Log.d(TAG, "Nearest Native: ${currentNearestDevice?.id ?: "no id"}")

        val lastTimestamp = currentNearestDevice?.lastSampleTimestamp ?: timestamp

        if (currentNearestDevice != nearestDevice) {
            nearestDeviceAssignTimestamp = lastTimestamp
            nearestDevice = currentNearestDevice

            timer?.cancel()
            timer = Timer()
            timer?.schedule(object : TimerTask() {
                override fun run() {
                    fireEvent()
                }
            }, NEAREST_DEVICE_TIMEOUT)
        }
    }

    override fun clearUnreachableDevices(from: LocalDateTime) {
        val devicesToRemove = devices.filter { it.lastSampleTimestamp < from }
        devices.removeAll(devicesToRemove.toSet())
    }

    private fun findDevice(sample: BLESample): BLEDevice {
        val index = devices.indexOfFirst { it.id == sample.deviceId }
        if (index == -1) {
            val dev = BLEDevice(
                id = sample.deviceId,
                alias = sample.alias,
                device = sample.device,
                result = sample.result,
                lastSampleTimestamp = LocalDateTime.now()
            )
            devices.add(dev)
            return dev
        } else {
            devices[index] = devices[index].copy(
                lastSampleTimestamp = LocalDateTime.now(),
                result = sample.result
            )
            return devices[index]
        }
    }

    private fun getNearestDevice(devices: List<BLEDevice>): BLEDevice? {
        var nearestDevice = currentNearestDevice ?: (devices.firstOrNull() ?: return null)
        var maxRxPowerValue = nearestDevice.avgRxPower

        for (device in devices) {
            val avgRxPower = device.avgRxPower

            if (avgRxPower > maxRxPowerValue) {
                maxRxPowerValue = avgRxPower
                nearestDevice = device
            }
        }

        return nearestDevice
    }

    private var lastFired: BLEDevice? = null
    private fun fireEvent() {
        if (nearestDevice != null) {
            if (lastFired != nearestDevice) {
                nearestDeviceChangedListener.onDeviceChanged(nearestDevice!!)
                lastFired = nearestDevice
            }
        }
    }
}