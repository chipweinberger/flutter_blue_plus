package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.app.Activity;
import android.bluetooth.*;
import android.content.*;
import android.os.*;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.*;

import java.lang.reflect.InvocationTargetException;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Engine-scoped native registrations. No Classic profile or RFCOMM entry points. */
public final class AndroidBluetoothPlugin
        implements FlutterPlugin,
                ActivityAware,
                MethodChannel.MethodCallHandler,
                EventChannel.StreamHandler,
                PluginRegistry.ActivityResultListener,
                PluginRegistry.RequestPermissionsResultListener {
    static final Set<AndroidBluetoothPlugin> ACTIVE = new CopyOnWriteArraySet<>();
    // Retired codes stay reserved until Android returns their old result. Null
    // owners are tombstones, so a dialog cannot retain a detached engine.
    static final Map<Integer, AndroidBluetoothPlugin> REQUEST_OWNERS = new HashMap<>();
    static int nextRequestCode = 51720;
    final Handler main = new Handler(Looper.getMainLooper());
    ExecutorService io = Executors.newCachedThreadPool();
    final ArrayDeque<Map<String, Object>> pendingEvents = new ArrayDeque<>();
    final Map<String, byte[]> pairingPins = new ConcurrentHashMap<>();
    final Set<PendingResult> pendingResults =
            Collections.newSetFromMap(new ConcurrentHashMap<PendingResult, Boolean>());
    final Map<String, BluetoothDevice> knownDevices =
            Collections.synchronizedMap(
                    new LinkedHashMap<String, BluetoothDevice>(32, 0.75f, true) {
                        @Override
                        protected boolean removeEldestEntry(
                                Map.Entry<String, BluetoothDevice> entry) {
                            return size() > 512;
                        }
                    });
    Context context;
    Activity activity;
    BluetoothManager manager;
    ActivityPluginBinding activityBinding;
    volatile EventChannel.EventSink sink;
    MethodChannel methods;
    EventChannel events;
    final AdapterBridge adapterBridge = new AdapterBridge(this);
    final DeviceBridge deviceBridge = new DeviceBridge(this);
    final EnvironmentBridge environment = new EnvironmentBridge(this);
    ScanBridge scans;
    GattBridge gatts;
    SocketBridge sockets;
    AdvertisingBridge advertisements;
    CompanionBridge companions;
    RangingApi ranging;
    MethodChannel.Result enableResult, permissionResult;
    int enableRequestCode = -1, permissionRequestCode = -1;
    String[] requestedPermissions;
    volatile boolean detached;
    volatile long generation;
    FlutterEngine engine;
    final FlutterEngine.EngineLifecycleListener engineLifecycle =
            new FlutterEngine.EngineLifecycleListener() {
                @Override
                public void onPreEngineRestart() {
                    resetSession();
                }

                @Override
                public void onEngineWillDestroy() {}
            };

    int newRequestCode() {
        synchronized (REQUEST_OWNERS) {
            for (int i = 0; i <= 0xffff; i++) {
                int code = nextRequestCode;
                nextRequestCode = (nextRequestCode + 1) & 0xffff;
                if (!REQUEST_OWNERS.containsKey(code)) {
                    REQUEST_OWNERS.put(code, this);
                    return code;
                }
            }
        }
        throw new IllegalStateException("All Android Activity request codes are still outstanding");
    }

    void releaseRequestCode(int code) {
        synchronized (REQUEST_OWNERS) {
            if (REQUEST_OWNERS.get(code) == this) REQUEST_OWNERS.remove(code);
        }
    }

    void retireRequestCode(int code) {
        synchronized (REQUEST_OWNERS) {
            if (REQUEST_OWNERS.get(code) == this) REQUEST_OWNERS.put(code, null);
        }
    }

    boolean consumeRetiredRequestCode(int code) {
        synchronized (REQUEST_OWNERS) {
            if (!REQUEST_OWNERS.containsKey(code) || REQUEST_OWNERS.get(code) != null) return false;
            REQUEST_OWNERS.remove(code);
            return true;
        }
    }

    void retireRequestCodes() {
        synchronized (REQUEST_OWNERS) {
            for (Map.Entry<Integer, AndroidBluetoothPlugin> entry : REQUEST_OWNERS.entrySet())
                if (entry.getValue() == this) entry.setValue(null);
        }
    }

    MethodChannel.Result enableEventResult() {
        return new MethodChannel.Result() {
            public void success(Object accepted) {
                emit("adapter", "onEnableResponse", map("userAccepted", accepted));
            }

            public void error(String code, String message, Object details) {
                emit(
                        "adapter",
                        "onEnableResponse",
                        map("userAccepted", false, "errorCode", code, "message", message));
            }

            public void notImplemented() {
                error("unsupported", "Enable request unavailable", null);
            }
        };
    }

    void emitBackgroundError(String message, Map<String, Object> details) {
        long expectedGeneration = generation;
        EventChannel.EventSink target = sink;
        if (target == null) return;
        main.post(
                () -> {
                    if (!detached && generation == expectedGeneration && sink == target)
                        target.error("background_error", message, details);
                });
    }

    void emit(String owner, String type, Map<String, Object> data) {
        emit(owner, type, data, generation);
    }

    void emit(String owner, String type, Map<String, Object> data, long expectedGeneration) {
        Map<String, Object> event = new LinkedHashMap<>(data);
        event.put("owner", owner);
        event.put("type", type);
        main.post(
                () -> {
                    if (detached || generation != expectedGeneration) return;
                    if (sink != null) sink.success(event);
                    else pendingEvents.addLast(event);
                });
    }

    void fail(MethodChannel.Result result, Throwable failure) {
        String code =
                failure instanceof SecurityException
                        ? "permission_denied"
                        : failure instanceof NoSuchMethodException
                                        || failure instanceof IllegalAccessException
                                ? "restricted_api"
                                : failure instanceof UnsupportedOperationException
                                        ? "unsupported"
                                        : failure instanceof IllegalArgumentException
                                                ? "invalid_argument"
                                                : failure instanceof IllegalStateException
                                                        ? "invalid_state"
                                                        : failure instanceof java.io.IOException
                                                                ? "io_error"
                                                                : "android_error";
        result.error(
                code,
                failure.toString(),
                map("exception", failure.getClass().getName(), "apiLevel", Build.VERSION.SDK_INT));
    }

    interface Reply {
        void send(MethodChannel.Result result);
    }

    final class PendingResult implements MethodChannel.Result {
        final MethodChannel.Result original;
        final long expectedGeneration = generation;
        final AtomicBoolean completed = new AtomicBoolean();

        PendingResult(MethodChannel.Result original) {
            this.original = original;
            pendingResults.add(this);
        }

        void cancel(String code, String message) {
            Runnable completion =
                    () -> {
                        if (!completed.compareAndSet(false, true)) return;
                        pendingResults.remove(this);
                        try {
                            original.error(code, message, null);
                        } catch (RuntimeException unavailable) {
                            // The messenger may already be destroyed during an engine shutdown.
                        }
                    };
            if (Looper.myLooper() == main.getLooper()) completion.run();
            else main.post(completion);
        }

        void post(Reply reply) {
            if (completed.get()) return;
            main.post(
                    () -> {
                        if (generation != expectedGeneration || detached) {
                            cancel(
                                    detached ? "engine_detached" : "engine_restarted",
                                    "Native engine session ended");
                            return;
                        }
                        if (!completed.compareAndSet(false, true)) return;
                        pendingResults.remove(this);
                        reply.send(original);
                    });
        }

        public void success(Object value) {
            post(result -> result.success(value));
        }

        public void error(String code, String message, Object details) {
            post(result -> result.error(code, message, details));
        }

        public void notImplemented() {
            post(MethodChannel.Result::notImplemented);
        }
    }

    MethodChannel.Result onMain(MethodChannel.Result original) {
        return new PendingResult(original);
    }

    void cancelPendingResults() {
        for (PendingResult result : pendingResults)
            result.cancel(
                    detached ? "engine_detached" : "engine_restarted",
                    "Native engine session ended");
    }

    void worker(MethodChannel.Result result, Callable<Object> task) {
        io.execute(
                () -> {
                    try {
                        result.success(task.call());
                    } catch (Exception e) {
                        fail(result, e);
                    }
                });
    }

    void needActivity() {
        if (activity == null)
            throw new IllegalStateException("This operation requires a foreground Activity");
    }

    final BroadcastReceiver receiver =
            new BroadcastReceiver() {
                @Override
                public void onReceive(Context c, Intent intent) {
                    String action = intent.getAction();
                    if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)
                            || BluetoothAdapter.ACTION_LOCAL_NAME_CHANGED.equals(action)) {
                        int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1);
                        if (state == BluetoothAdapter.STATE_TURNING_OFF
                                || state == BluetoothAdapter.STATE_OFF) pairingPins.clear();
                        emit(
                                "adapter",
                                action,
                                map(
                                        "state",
                                        intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1),
                                        "previousState",
                                        intent.getIntExtra(
                                                BluetoothAdapter.EXTRA_PREVIOUS_STATE, -1),
                                        "name",
                                        intent.getStringExtra(BluetoothAdapter.EXTRA_LOCAL_NAME)));
                        return;
                    }
                    BluetoothDevice d = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                    if (d == null) return;
                    if (BluetoothDevice.ACTION_PAIRING_REQUEST.equals(action))
                        deviceBridge.applyPairingPin(d);
                    if (BluetoothDevice.ACTION_ACL_DISCONNECTED.equals(action)
                            || BluetoothDevice.ACTION_BOND_STATE_CHANGED.equals(action)
                                    && intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)
                                            != BluetoothDevice.BOND_BONDING)
                        pairingPins.remove(d.getAddress());
                    Map<String, Object> data = map("device", deviceMap(d));
                    Bundle extras = intent.getExtras();
                    Map<String, Object> values = new LinkedHashMap<>();
                    if (extras != null)
                        for (String key : extras.keySet()) {
                            Object value = extras.get(key);
                            if (value == null
                                    || value instanceof String
                                    || value instanceof Number
                                    || value instanceof Boolean
                                    || value instanceof byte[]) values.put(key, value);
                        }
                    data.put("extras", values);
                    emit("device", action, data);
                }
            };

    @Override
    public void onListen(Object args, EventChannel.EventSink sink) {
        this.sink = sink;
        while (!pendingEvents.isEmpty()) sink.success(pendingEvents.removeFirst());
        BackgroundEvents.flush();
    }

    @Override
    public void onCancel(Object args) {
        sink = null;
    }

    @Override
    public boolean onActivityResult(int code, int resultCode, Intent data) {
        if (code == enableRequestCode && enableResult != null) {
            releaseRequestCode(code);
            enableRequestCode = -1;
            MethodChannel.Result result = enableResult;
            enableResult = null;
            result.success(resultCode == Activity.RESULT_OK);
            return true;
        }
        if (companions != null && companions.onActivityResult(code, resultCode, data)) return true;
        return consumeRetiredRequestCode(code);
    }

    @Override
    public boolean onRequestPermissionsResult(int code, String[] permissions, int[] grants) {
        if (code != permissionRequestCode || permissionResult == null)
            return consumeRetiredRequestCode(code);
        releaseRequestCode(code);
        permissionRequestCode = -1;
        permissionResult.success(
                environment.permissionStates(new ArrayList<>(Arrays.asList(requestedPermissions))));
        permissionResult = null;
        requestedPermissions = null;
        return true;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding;
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
        binding.addRequestPermissionsResultListener(this);
    }

    void detachActivity(boolean reconfiguring) {
        if (activityBinding != null) {
            activityBinding.removeActivityResultListener(this);
            activityBinding.removeRequestPermissionsResultListener(this);
        }
        activityBinding = null;
        activity = null;
        if (!reconfiguring) {
            retireRequestCode(enableRequestCode);
            retireRequestCode(permissionRequestCode);
            enableRequestCode = permissionRequestCode = -1;
            if (enableResult != null)
                enableResult.error("activity_detached", "Activity detached", null);
            if (permissionResult != null)
                permissionResult.error("activity_detached", "Activity detached", null);
            enableResult = permissionResult = null;
            if (companions != null) companions.detach();
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachActivity(true);
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachActivity(false);
    }

    @Override
    @SuppressWarnings(
            "deprecation") // Flutter exposes engine-restart hooks through this binding accessor.
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        detached = false;
        if (io.isShutdown()) io = Executors.newCachedThreadPool();
        context = binding.getApplicationContext();
        engine = binding.getFlutterEngine();
        engine.addEngineLifecycleListener(engineLifecycle);
        manager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
        scans = new ScanBridge(this);
        gatts = new GattBridge(this);
        sockets = new SocketBridge(this);
        advertisements = new AdvertisingBridge(this);
        companions = Build.VERSION.SDK_INT >= 26 ? new CompanionBridge(this) : null;
        // RangingBridge is only loaded on API 36+, avoiding older Android verifier failures.
        methods = new MethodChannel(binding.getBinaryMessenger(), "dev.android_bluetooth/methods");
        events = new EventChannel(binding.getBinaryMessenger(), "dev.android_bluetooth/events");
        methods.setMethodCallHandler(this);
        events.setStreamHandler(this);
        IntentFilter filter = new IntentFilter();
        for (String action :
                Arrays.asList(
                        BluetoothAdapter.ACTION_STATE_CHANGED,
                        BluetoothAdapter.ACTION_LOCAL_NAME_CHANGED,
                        BluetoothDevice.ACTION_ACL_CONNECTED,
                        BluetoothDevice.ACTION_ACL_DISCONNECTED,
                        BluetoothDevice.ACTION_ACL_DISCONNECT_REQUESTED,
                        BluetoothDevice.ACTION_BOND_STATE_CHANGED,
                        BluetoothDevice.ACTION_NAME_CHANGED,
                        BluetoothDevice.ACTION_PAIRING_REQUEST,
                        "android.bluetooth.device.action.ALIAS_CHANGED",
                        "android.bluetooth.device.action.ENCRYPTION_CHANGE",
                        "android.bluetooth.device.action.KEY_MISSING",
                        "android.bluetooth.device.action.LE_APPEARANCE_CHANGED"))
            filter.addAction(action);
        // Bluetooth broadcasts originate in the privileged Bluetooth process, not our UID.
        if (Build.VERSION.SDK_INT >= 33)
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED);
        else context.registerReceiver(receiver, filter);
        ACTIVE.add(this);
    }

    /**
     * Reset ephemeral registrations when Dart restarts; process-local background work remains owned
     * by the app.
     */
    void resetSession() {
        generation++;
        cancelPendingResults();
        retireRequestCodes();
        enableRequestCode = permissionRequestCode = -1;
        sink = null;
        if (sockets != null) sockets.closeAll();
        if (gatts != null) gatts.closeAll();
        if (scans != null) scans.closeAll();
        if (advertisements != null) advertisements.closeAll();
        if (ranging != null) ranging.closeAll();
        ranging = null;
        if (companions != null) companions.reset();
        permissionResult = enableResult = null;
        requestedPermissions = null;
        pendingEvents.clear();
        knownDevices.clear();
        pairingPins.clear();
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        // Deliver directly: emit() posts work that resetSession's generation guard would discard.
        EventChannel.EventSink listener = sink;
        try {
            if (listener != null) {
                listener.success(map("owner", "engine", "type", "onDetachedFromEngine"));
                listener.endOfStream();
            }
        } catch (RuntimeException unavailable) {
            // An already-destroyed messenger must not prevent native resource cleanup.
        }
        detached = true;
        ACTIVE.remove(this);
        engine.removeEngineLifecycleListener(engineLifecycle);
        methods.setMethodCallHandler(null);
        events.setStreamHandler(null);
        context.unregisterReceiver(receiver);
        detachActivity(false);
        resetSession();
        io.shutdownNow();
    }

    @android.annotation.SuppressLint(
            "MissingPermission") // Explicit Dart permission requests; native SecurityExceptions
    // propagate.
    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result rawResult) {
        MethodChannel.Result result = onMain(rawResult);
        if (detached) {
            result.error("engine_detached", "Native engine session ended", null);
            return;
        }
        Map<String, Object> a = object(call.arguments);
        String method = call.method;
        try {
            if (method.startsWith("scan.")) {
                scans.handle(method.substring(5), a, result);
                return;
            }
            if (method.startsWith("gatt.") || method.startsWith("server.")) {
                gatts.handle(method, a, result);
                return;
            }
            if (method.startsWith("socket.")) {
                sockets.handle(method.substring(7), a, result);
                return;
            }
            if (method.startsWith("advertise.")) {
                advertisements.handle(method.substring(10), a, result);
                return;
            }
            if (method.startsWith("companion.")) {
                if (companions == null)
                    throw new UnsupportedOperationException("Requires Android API 26");
                companions.handle(method.substring(10), a, result);
                return;
            }
            if (method.startsWith("ranging.")) {
                if (Build.VERSION.SDK_INT < 36)
                    throw new UnsupportedOperationException("Requires Android API 36");
                if (ranging == null) {
                    try {
                        ranging =
                                (RangingApi)
                                        Class.forName(
                                                        "com.jamcorder.android_bluetooth.RangingBridge")
                                                .getDeclaredConstructor(
                                                        AndroidBluetoothPlugin.class)
                                                .newInstance(this);
                    } catch (ClassNotFoundException absent) {
                        throw new UnsupportedOperationException(
                                "BLE ranging requires building android_bluetooth with compile SDK"
                                        + " 36",
                                absent);
                    } catch (InvocationTargetException failure) {
                        if (failure.getCause() instanceof Exception)
                            throw (Exception) failure.getCause();
                        throw failure;
                    }
                }
                ranging.handle(method.substring(8), a, result);
                return;
            }
            if (method.startsWith("adapter.") || method.startsWith("manager.")) {
                adapterBridge.handle(method, a, result);
                return;
            }
            if (method.startsWith("device.")) {
                deviceBridge.handle(method.substring(7), a, result);
                return;
            }
            environment.handle(method, a, result);
        } catch (Exception e) {
            if (permissionResult == result) {
                releaseRequestCode(permissionRequestCode);
                permissionRequestCode = -1;
                permissionResult = null;
                requestedPermissions = null;
            }
            if (enableResult == result) enableResult = null;
            fail(result, e);
        }
    }
}
