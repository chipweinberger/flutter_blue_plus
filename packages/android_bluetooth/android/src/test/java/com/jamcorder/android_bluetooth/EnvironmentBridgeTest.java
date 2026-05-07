package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.Manifest;
import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import io.flutter.plugin.common.MethodCall;

import org.junit.*;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import org.robolectric.util.ReflectionHelpers;

import java.util.Collections;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class EnvironmentBridgeTest {
    private AndroidBluetoothPlugin plugin;
    private Context context;

    @Before
    public void setUp() {
        plugin = new AndroidBluetoothPlugin();
        context = mock(Context.class);
        plugin.context = context;
        plugin.activity = mock(Activity.class);
        when(context.getPackageName()).thenReturn("test.app");
        ComponentName service =
                new ComponentName("test.app", BluetoothConnectionService.class.getName());
        when(context.startForegroundService(any(Intent.class))).thenReturn(service);
        when(context.startService(any(Intent.class))).thenReturn(service);
        if (Build.VERSION.SDK_INT >= 23)
            when(context.checkSelfPermission(anyString()))
                    .thenReturn(PackageManager.PERMISSION_GRANTED);
    }

    @After
    public void tearDown() {
        plugin.io.shutdownNow();
    }

    @Test
    @Config(sdk = 33)
    public void legacyPermissionRequestsReturnCurrentGrantsWithoutAnActivity() throws Exception {
        plugin.activity = null;
        String permission = Manifest.permission.ACCESS_FINE_LOCATION;
        when(context.checkCallingOrSelfPermission(permission))
                .thenReturn(PackageManager.PERMISSION_GRANTED);
        PluginTestSupport.Result result = new PluginTestSupport.Result();
        // Current Robolectric no longer supports API 21. This branch only queries
        // the mocked Context, so exercise its SDK selection on a supported runtime.
        int sdk = Build.VERSION.SDK_INT;
        try {
            ReflectionHelpers.setStaticField(Build.VERSION.class, "SDK_INT", 21);
            plugin.environment.handle(
                    "permissions.request",
                    map("permissions", Collections.singletonList(permission)),
                    result);
        } finally {
            ReflectionHelpers.setStaticField(Build.VERSION.class, "SDK_INT", sdk);
        }
        assertEquals(map(permission, true), result.value);
        assertEquals(0, result.done.getCount());
        assertNull(plugin.permissionResult);
    }

    @Test
    public void connectionServiceRetainsIntentAndSdkLaunchMethod() throws Exception {
        PluginTestSupport.Result result = new PluginTestSupport.Result();
        plugin.environment.handle(
                "background.startService", map("title", "Sensor", "text", "Connected"), result);
        assertEquals(0, result.done.getCount());
        assertNull(result.error);
        ArgumentCaptor<Intent> intent = ArgumentCaptor.forClass(Intent.class);
        if (Build.VERSION.SDK_INT >= 26) verify(context).startForegroundService(intent.capture());
        else verify(context).startService(intent.capture());
        assertEquals(
                BluetoothConnectionService.class.getName(),
                intent.getValue().getComponent().getClassName());
        assertEquals("Sensor", intent.getValue().getStringExtra("title"));
        assertEquals("Connected", intent.getValue().getStringExtra("text"));
        assertEquals(51722, intent.getValue().getIntExtra("notificationId", 0));
    }

    @Test
    public void missingConnectionServiceReturnsAnErrorAndCanBeRetried() throws Exception {
        int sdk = Build.VERSION.SDK_INT;
        ComponentName service =
                new ComponentName("test.app", BluetoothConnectionService.class.getName());
        for (boolean legacy : new boolean[] {false, true}) {
            when(context.startForegroundService(any(Intent.class))).thenReturn(null, service);
            when(context.startService(any(Intent.class))).thenReturn(null, service);
            try {
                // Exercise the pre-26 launch branch on the supported test runtime too.
                if (legacy) ReflectionHelpers.setStaticField(Build.VERSION.class, "SDK_INT", 21);
                PluginTestSupport.Result failed = new PluginTestSupport.Result();
                MethodCall call =
                        new MethodCall(
                                "background.startService",
                                map("title", "Sensor", "text", "Connected"));
                plugin.onMethodCall(call, failed);
                failed.await();
                assertEquals("invalid_state", failed.error);
                assertNull(failed.value);
                PluginTestSupport.Result retry = new PluginTestSupport.Result();
                plugin.onMethodCall(call, retry);
                retry.await();
                assertNull(retry.error);
                assertNull(retry.value);
            } finally {
                ReflectionHelpers.setStaticField(Build.VERSION.class, "SDK_INT", sdk);
            }
        }
        verify(context, times(2)).startForegroundService(any(Intent.class));
        verify(context, times(2)).startService(any(Intent.class));
    }

    @Test
    public void connectionServiceChecksActivityAndPermissionsBeforeNotificationArguments() {
        PluginTestSupport.Result result = new PluginTestSupport.Result();
        plugin.activity = null;
        assertEquals(
                "This operation requires a foreground Activity",
                assertThrows(
                                IllegalStateException.class,
                                () ->
                                        plugin.environment.handle(
                                                "background.startService",
                                                map("notificationId", 0),
                                                result))
                        .getMessage());
        plugin.activity = mock(Activity.class);
        if (Build.VERSION.SDK_INT >= 28) {
            when(context.checkSelfPermission("android.permission.FOREGROUND_SERVICE"))
                    .thenReturn(PackageManager.PERMISSION_DENIED);
            assertEquals(
                    "Declare android.permission.FOREGROUND_SERVICE in the application manifest",
                    assertThrows(
                                    SecurityException.class,
                                    () ->
                                            plugin.environment.handle(
                                                    "background.startService",
                                                    map("notificationId", 0),
                                                    result))
                            .getMessage());
            when(context.checkSelfPermission("android.permission.FOREGROUND_SERVICE"))
                    .thenReturn(PackageManager.PERMISSION_GRANTED);
        }
        if (Build.VERSION.SDK_INT >= 34) {
            when(context.checkSelfPermission(
                            "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"))
                    .thenReturn(PackageManager.PERMISSION_DENIED);
            assertEquals(
                    "Declare android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE in the"
                            + " application manifest",
                    assertThrows(
                                    SecurityException.class,
                                    () ->
                                            plugin.environment.handle(
                                                    "background.startService",
                                                    map("notificationId", 0),
                                                    result))
                            .getMessage());
            when(context.checkSelfPermission(
                            "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"))
                    .thenReturn(PackageManager.PERMISSION_GRANTED);
            for (String permission :
                    new String[] {
                        Manifest.permission.BLUETOOTH_CONNECT,
                        Manifest.permission.BLUETOOTH_SCAN,
                        Manifest.permission.BLUETOOTH_ADVERTISE
                    })
                when(context.checkSelfPermission(permission))
                        .thenReturn(PackageManager.PERMISSION_DENIED);
            assertEquals(
                    "Grant a Bluetooth runtime permission before starting the connectedDevice"
                            + " service",
                    assertThrows(
                                    SecurityException.class,
                                    () ->
                                            plugin.environment.handle(
                                                    "background.startService",
                                                    map("notificationId", 0),
                                                    result))
                            .getMessage());
            when(context.checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE))
                    .thenReturn(PackageManager.PERMISSION_GRANTED);
        }
        assertEquals(
                "notificationId must be positive",
                assertThrows(
                                IllegalArgumentException.class,
                                () ->
                                        plugin.environment.handle(
                                                "background.startService",
                                                map("notificationId", 0),
                                                result))
                        .getMessage());
        assertEquals(1, result.done.getCount());
    }
}
