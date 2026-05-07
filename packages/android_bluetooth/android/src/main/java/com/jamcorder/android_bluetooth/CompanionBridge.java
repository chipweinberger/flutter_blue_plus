package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanResult;
import android.companion.*;
import android.content.*;
import android.os.Build;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;
import java.util.regex.Pattern;

@android.annotation.TargetApi(26)
final class CompanionBridge {
    final AndroidBluetoothPlugin p;
    Request pending;

    static final class Request {
        final String id;
        final long generation;
        int requestCode = -1;
        boolean chooserLaunched, chooserFinished, created, finished;

        Request(String id, long generation) {
            this.id = id;
            this.generation = generation;
        }
    }

    CompanionBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    CompanionDeviceManager manager() {
        if (Build.VERSION.SDK_INT < 26)
            throw new UnsupportedOperationException("Requires Android API 26");
        CompanionDeviceManager m =
                (CompanionDeviceManager)
                        p.context.getSystemService(Context.COMPANION_DEVICE_SERVICE);
        if (m == null)
            throw new UnsupportedOperationException("Companion device association unavailable");
        return m;
    }

    @android.annotation.TargetApi(33)
    static Map<String, Object> association(AssociationInfo info) {
        Object selfManaged = null;
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                selfManaged = optional(info, "isSelfManaged", new Class<?>[0]);
            } catch (Exception unavailable) {
                // Optional metadata must not prevent association delivery.
            }
        }
        return map(
                "id",
                info.getId(),
                "deviceMacAddress",
                info.getDeviceMacAddress() == null ? null : info.getDeviceMacAddress().toString(),
                "displayName",
                info.getDisplayName() == null ? null : info.getDisplayName().toString(),
                "deviceProfile",
                info.getDeviceProfile(),
                "isSelfManaged",
                selfManaged);
    }

    boolean active(Request request) {
        return pending == request && !request.finished && p.generation == request.generation;
    }

    void finish(Request request) {
        request.finished = true;
        p.retireRequestCode(request.requestCode);
        request.requestCode = -1;
        if (pending == request) pending = null;
    }

    void emit(Request request, String type, Map<String, Object> values, boolean complete) {
        values.put("isComplete", complete);
        p.emit(request.id, type, values, request.generation);
        if (complete) finish(request);
    }

    void failure(Request request, Map<String, Object> values) {
        if (active(request)) emit(request, "onFailure", values, true);
    }

    void launch(Request request, IntentSender sender) {
        if (!active(request) || request.chooserLaunched) return;
        try {
            p.needActivity();
            request.requestCode = p.newRequestCode();
            request.chooserLaunched = true;
            emit(request, "onAssociationPending", map(), false);
            p.activity.startIntentSenderForResult(sender, request.requestCode, null, 0, 0, 0);
        } catch (Exception e) {
            p.releaseRequestCode(request.requestCode);
            request.requestCode = -1;
            failure(request, map("message", e.toString()));
        }
    }

    void reset() {
        if (pending != null) finish(pending);
    }

    void detach() {
        // Once the chooser result arrived, the remaining creation callback no
        // longer needs an Activity and must still be delivered on API 33+.
        if (pending != null && !pending.chooserFinished)
            failure(pending, map("message", "Activity detached"));
    }

    boolean onActivityResult(int code, int result, Intent data) {
        Request request = pending;
        if (request == null || !active(request) || code != request.requestCode) return false;
        p.releaseRequestCode(code);
        request.requestCode = -1;
        request.chooserFinished = true;
        Map<String, Object> values = map("resultCode", result);
        if (data != null) {
            Object device = data.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE);
            if (device instanceof ScanResult)
                values.put("device", deviceMap(((ScanResult) device).getDevice()));
            if (device instanceof BluetoothDevice)
                values.put("device", deviceMap((BluetoothDevice) device));
            if (Build.VERSION.SDK_INT >= 33) {
                AssociationInfo info =
                        data.getParcelableExtra(CompanionDeviceManager.EXTRA_ASSOCIATION);
                if (info != null) values.put("association", association(info));
            }
        }
        boolean success = result == Activity.RESULT_OK;
        boolean complete = !success || Build.VERSION.SDK_INT < 33 || request.created;
        emit(request, success ? "onAssociationResult" : "onAssociationCancelled", values, complete);
        return true;
    }

    @android.annotation.SuppressLint(
            "MissingPermission") // Optional companion permissions belong to the app; platform
    // exceptions propagate.
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) throws Exception {
        CompanionDeviceManager m = manager();
        switch (method) {
            case "associate":
                {
                    p.needActivity();
                    if (pending != null)
                        throw new IllegalStateException(
                                "An association request is already pending");
                    AssociationRequest.Builder b =
                            new AssociationRequest.Builder()
                                    .setSingleDevice(bool(a, "singleDevice", true));
                    List<Object> filters = list(a.get("filters"));
                    if (filters.isEmpty()) filters = Collections.singletonList(map());
                    for (Object value : filters) {
                        BluetoothLeDeviceFilter.Builder f =
                                new BluetoothLeDeviceFilter.Builder()
                                        .setScanFilter(ScanBridge.filter(object(value)));
                        if (a.get("namePattern") != null)
                            f.setNamePattern(Pattern.compile(string(a, "namePattern")));
                        b.addDeviceFilter(f.build());
                    }
                    if (a.get("displayName") != null) {
                        if (Build.VERSION.SDK_INT < 33)
                            throw new UnsupportedOperationException("Requires Android API 33");
                        b.setDisplayName(string(a, "displayName"));
                    }
                    if (bool(a, "forceConfirmation", false)) {
                        if (Build.VERSION.SDK_INT < 33)
                            throw new UnsupportedOperationException("Requires Android API 33");
                        b.setForceConfirmation(true);
                    }
                    Request request = new Request(id("association"), p.generation);
                    CompanionDeviceManager.Callback callback =
                            new CompanionDeviceManager.Callback() {
                                @Override
                                public void onDeviceFound(IntentSender sender) {
                                    p.main.post(() -> launch(request, sender));
                                }

                                @Override
                                public void onAssociationPending(IntentSender sender) {
                                    p.main.post(() -> launch(request, sender));
                                }

                                @Override
                                public void onAssociationCreated(AssociationInfo info) {
                                    p.main.post(
                                            () -> {
                                                if (!active(request)) return;
                                                request.created = true;
                                                emit(
                                                        request,
                                                        "onAssociationCreated",
                                                        map("association", association(info)),
                                                        !request.chooserLaunched
                                                                || request.chooserFinished);
                                            });
                                }

                                @Override
                                public void onFailure(CharSequence error) {
                                    p.main.post(
                                            () ->
                                                    failure(
                                                            request,
                                                            map(
                                                                    "message",
                                                                    error == null
                                                                            ? null
                                                                            : error.toString())));
                                }

                                // Newer public overload; retain when compiling against SDK 33.
                                public void onFailure(int code, CharSequence error) {
                                    p.main.post(
                                            () ->
                                                    failure(
                                                            request,
                                                            map(
                                                                    "status",
                                                                    code,
                                                                    "message",
                                                                    error == null
                                                                            ? null
                                                                            : error.toString())));
                                }
                            };
                    pending = request;
                    try {
                        m.associate(b.build(), callback, p.main);
                    } catch (RuntimeException e) {
                        finish(request);
                        throw e;
                    }
                    r.success(request.id);
                    return;
                }
            case "associations":
                {
                    List<Object> result = new ArrayList<>();
                    if (Build.VERSION.SDK_INT >= 33)
                        for (AssociationInfo info : m.getMyAssociations())
                            result.add(association(info));
                    else
                        for (String address : m.getAssociations())
                            result.add(map("deviceMacAddress", address));
                    r.success(result);
                    return;
                }
            case "disassociate":
                if (a.get("associationId") != null) {
                    if (Build.VERSION.SDK_INT < 33)
                        throw new UnsupportedOperationException("Requires Android API 33");
                    m.disassociate(integer(a, "associationId", 0));
                } else m.disassociate(string(a, "address"));
                r.success(null);
                return;
            case "observe":
            case "stopObserving":
                if (Build.VERSION.SDK_INT < 31)
                    throw new UnsupportedOperationException("Requires Android API 31");
                if (a.get("associationId") != null) {
                    if (Build.VERSION.SDK_INT < 36)
                        throw new UnsupportedOperationException("Requires Android API 36");
                    Class<?> requestType =
                            Class.forName("android.companion.ObservingDevicePresenceRequest");
                    Object builder =
                            Class.forName(
                                            "android.companion.ObservingDevicePresenceRequest$Builder")
                                    .getConstructor()
                                    .newInstance();
                    optional(
                            builder,
                            "setAssociationId",
                            new Class<?>[] {int.class},
                            integer(a, "associationId", 0));
                    Object request = optional(builder, "build", new Class<?>[0]);
                    optional(
                            m,
                            method.equals("observe")
                                    ? "startObservingDevicePresence"
                                    : "stopObservingDevicePresence",
                            new Class<?>[] {requestType},
                            request);
                } else if (method.equals("observe"))
                    m.startObservingDevicePresence(string(a, "address"));
                else m.stopObservingDevicePresence(string(a, "address"));
                r.success(null);
                return;
            case "removeBond":
                if (Build.VERSION.SDK_INT < 36)
                    throw new UnsupportedOperationException("Requires Android API 36");
                r.success(
                        optional(
                                m,
                                "removeBond",
                                new Class<?>[] {int.class},
                                integer(a, "associationId", 0)));
                return;
            default:
                r.notImplemented();
        }
    }
}
