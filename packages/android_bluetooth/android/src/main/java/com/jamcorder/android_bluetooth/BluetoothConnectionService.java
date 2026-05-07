package com.jamcorder.android_bluetooth;

import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.os.*;

/** An explicit ongoing-device notification; never starts a Flutter engine. */
public final class BluetoothConnectionService extends Service {
    static final String CHANNEL = "android_bluetooth_connection";

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            stopSelf();
            return START_NOT_STICKY;
        }
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26)
            manager.createNotificationChannel(
                    new NotificationChannel(
                            CHANNEL, "Bluetooth connection", NotificationManager.IMPORTANCE_LOW));
        Notification.Builder builder =
                Build.VERSION.SDK_INT >= 26
                        ? new Notification.Builder(this, CHANNEL)
                        : new Notification.Builder(this);
        builder.setContentTitle(intent.getStringExtra("title"))
                .setContentText(intent.getStringExtra("text"))
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setOngoing(true);
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null)
            builder.setContentIntent(
                    PendingIntent.getActivity(
                            this,
                            0,
                            launch,
                            PendingIntent.FLAG_UPDATE_CURRENT
                                    | (Build.VERSION.SDK_INT >= 23
                                            ? PendingIntent.FLAG_IMMUTABLE
                                            : 0)));
        if (Build.VERSION.SDK_INT >= 29)
            startForeground(
                    intent.getIntExtra("notificationId", 51722),
                    builder.build(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE);
        else startForeground(intent.getIntExtra("notificationId", 51722), builder.build());
        return START_NOT_STICKY;
    }
}
