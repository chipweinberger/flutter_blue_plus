// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.log;

import io.flutter.Log;

public enum LogLevel {
    NONE((tag, message, throwable) -> {
        // Do nothing
    }),    // 0
    ERROR(Log::e),   // 1
    WARNING(Log::w), // 2
    INFO(Log::i),    // 3
    DEBUG(Log::d),   // 4
    VERBOSE(Log::v); // 5

    private static final String TAG = "[FBP-Android]";
    private static LogLevel LOG_LEVEL = LogLevel.DEBUG;
    private final LogImplementation logImplementation;

    LogLevel(final LogImplementation logImplementation) {
        this.logImplementation = logImplementation;
    }

    public static void setLogLevel(final LogLevel logLevel) {
        LOG_LEVEL = logLevel;
    }

    public void log(final String message) {
        log(message, null);
    }

    public void log(final String message, final Throwable throwable) {
        if (ordinal() <= LOG_LEVEL.ordinal()) {
            logImplementation.log(TAG, String.format("[FBP] %s", message), throwable);
        }
    }

    private interface LogImplementation {
        void log(final String tag, final String message, final Throwable throwable);
    }

}

