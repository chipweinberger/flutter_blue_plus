package com.lib.flutter_blue_plus;

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.le.ScanResult
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

data class BLEDevice(
    val id: String,
    val alias: String?,
    val samples: LimitedQueue<BLESample> = LimitedQueue(SAMPLE_QUEUE_CAPACITY),
    val lastSampleTimestamp: LocalDateTime,
    val device: BluetoothDevice,
    val result: ScanResult,
    val gatt: BluetoothGatt? = null
) {

    companion object {
        const val MAX_POWER_LEVEL = 6
        private const val SAMPLE_QUEUE_CAPACITY = 5
        private const val IS_ALIVE_TIMEOUT = 2000L // 2000 milliseconds
        private const val TAG: String = "BLEDevice"
    }

    val isAlive: Boolean
        get() = ChronoUnit.MILLIS.between(
            LocalDateTime.now(),
            lastSampleTimestamp
        ) < IS_ALIVE_TIMEOUT

    val avgRxPower: Int get() {
        val filtered = samples.filter { it.txPower != null }
            .map { it.rxPower }
        return filtered.fold(0) { a, b -> a + b!! } / filtered.size
    }

    private val lastRxPower: Int? get() {
        return samples.filter { it.txPower != null }
            .map { it.rxPower }.lastOrNull()
    }


    fun addSample(sample: BLESample) {
        samples.add(sample)
//        Log.d(TAG, "LimitedQueue Size: ${samples.size}")

        // Update lastSampleTimestamp here if needed, based on your logic
        // e.g., lastSampleTimestamp = LocalDateTime.now()
    }

    override fun toString(): String {
        return "$alias (LST: ${lastRxPower ?: 0}) (AVG: ${avgRxPower})"
    }

    fun timer1msTick() {

    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as BLEDevice

        return id == other.id
    }
}