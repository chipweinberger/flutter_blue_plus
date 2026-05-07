package com.jamcorder.android_bluetooth;

import io.flutter.plugin.common.MethodChannel;

import java.util.Map;

/** Keeps the central BLE implementation buildable without API 36 ranging classes. */
interface RangingApi {
    void closeAll();

    void handle(String method, Map<String, Object> arguments, MethodChannel.Result result);
}
