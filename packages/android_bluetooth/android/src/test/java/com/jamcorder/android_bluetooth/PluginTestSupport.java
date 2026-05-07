package com.jamcorder.android_bluetooth;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.os.Looper;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** Shared engine, method-result, and event-sink fixtures for native tests. */
final class PluginTestSupport {
    static final String ADDRESS = "AA:BB:CC:DD:EE:FF";

    static final class Result implements MethodChannel.Result {
        volatile Object value;
        volatile String error;
        final CountDownLatch done = new CountDownLatch(1);

        public void success(Object value) {
            this.value = value;
            done.countDown();
        }

        public void error(String code, String message, Object details) {
            error = code;
            done.countDown();
        }

        public void notImplemented() {
            error = "not_implemented";
            done.countDown();
        }

        void await() throws Exception {
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
            while (done.getCount() != 0 && System.nanoTime() < deadline) {
                Shadows.shadowOf(Looper.getMainLooper()).idle();
                done.await(5, TimeUnit.MILLISECONDS);
            }
            assertEquals("Native result did not complete", 0, done.getCount());
        }
    }

    static final class Sink implements EventChannel.EventSink {
        final List<Object> values = new ArrayList<>();

        public void success(Object value) {
            values.add(value);
        }

        public void error(String code, String message, Object details) {
            fail(message);
        }

        public void endOfStream() {}
    }

    static final class Attached implements AutoCloseable {
        final AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        final FlutterEngine engine = mock(FlutterEngine.class);
        final FlutterPluginBinding binding =
                new FlutterPluginBinding(
                        RuntimeEnvironment.getApplication(),
                        engine,
                        mock(BinaryMessenger.class),
                        null,
                        null,
                        null,
                        null);

        Attached() {
            p.onAttachedToEngine(binding);
        }

        public void close() {
            if (!p.detached) p.onDetachedFromEngine(binding);
        }
    }
}
