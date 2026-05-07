package com.lib.android_bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.os.ParcelUuid;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import io.flutter.plugin.common.EventChannel;

public final class ScanController
{
    private EventChannel.EventSink scanBatchResultsSink;
    private EventChannel.EventSink scanFailedSink;
    private boolean scanning = false;
    private ScanCallback scanCallback;
    private EventChannel.EventSink scanResultsSink;

    public void setScanBatchResultsSink(EventChannel.EventSink scanBatchResultsSink)
    {
        this.scanBatchResultsSink = scanBatchResultsSink;
    }

    public void setScanFailedSink(EventChannel.EventSink scanFailedSink)
    {
        this.scanFailedSink = scanFailedSink;
    }

    public void setScanResultsSink(EventChannel.EventSink scanResultsSink)
    {
        this.scanResultsSink = scanResultsSink;
    }

    public boolean isScanning()
    {
        return scanning;
    }

    @SuppressWarnings("unchecked")
    public boolean startScan(BluetoothAdapter bluetoothAdapter, HashMap<String, Object> arguments)
    {
        if (bluetoothAdapter == null || bluetoothAdapter.getState() != BluetoothAdapter.STATE_ON) {
            return false;
        }

        BluetoothLeScanner bluetoothLeScanner = bluetoothAdapter.getBluetoothLeScanner();
        if (bluetoothLeScanner == null) {
            return false;
        }

        if (scanning) {
            return true;
        }

        try {
            HashMap<String, Object> settingsMap = arguments == null ? null : (HashMap<String, Object>) arguments.get("settings");
            List<HashMap<String, Object>> filtersMap = arguments == null ? null : (List<HashMap<String, Object>>) arguments.get("filters");

            ScanSettings settings = buildScanSettings(settingsMap);
            List<ScanFilter> filters = buildScanFilters(filtersMap);

            bluetoothLeScanner.startScan(filters, settings, getScanCallback());
            scanning = true;
            return true;
        } catch (SecurityException exception) {
            return false;
        } catch (IllegalStateException exception) {
            return false;
        }
    }

    public boolean stopScan(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            scanning = false;
            return false;
        }

        BluetoothLeScanner bluetoothLeScanner = bluetoothAdapter.getBluetoothLeScanner();
        if (bluetoothLeScanner == null) {
            scanning = false;
            return false;
        }

        if (!scanning) {
            return true;
        }

        try {
            bluetoothLeScanner.stopScan(getScanCallback());
            scanning = false;
            return true;
        } catch (SecurityException exception) {
            return false;
        } catch (IllegalStateException exception) {
            return false;
        }
    }

    public boolean flushPendingScanResults(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        BluetoothLeScanner bluetoothLeScanner = bluetoothAdapter.getBluetoothLeScanner();
        if (bluetoothLeScanner == null) {
            return false;
        }

        try {
            bluetoothLeScanner.flushPendingScanResults(getScanCallback());
            return true;
        } catch (SecurityException exception) {
            return false;
        } catch (IllegalStateException exception) {
            return false;
        }
    }

    private ScanCallback getScanCallback()
    {
        if (scanCallback == null) {
            scanCallback = new ScanCallback()
            {
                @Override
                public void onScanResult(int callbackType, ScanResult result)
                {
                    if (scanResultsSink == null || result == null) {
                        return;
                    }

                    scanResultsSink.success(serializeScanResult(callbackType, result));
                }

                @Override
                public void onBatchScanResults(List<ScanResult> results)
                {
                    if (results == null) {
                        return;
                    }

                    if (scanBatchResultsSink != null) {
                        List<HashMap<String, Object>> serializedResults = new ArrayList<>();
                        for (ScanResult result : results) {
                            HashMap<String, Object> event =
                                serializeScanResult(ScanSettings.CALLBACK_TYPE_ALL_MATCHES, result);
                            if (event != null) {
                                serializedResults.add(event);
                            }
                        }
                        scanBatchResultsSink.success(serializedResults);
                    }

                    for (ScanResult result : results) {
                        onScanResult(ScanSettings.CALLBACK_TYPE_ALL_MATCHES, result);
                    }
                }

                @Override
                public void onScanFailed(int errorCode)
                {
                    scanning = false;
                    if (scanFailedSink == null) {
                        return;
                    }

                    HashMap<String, Object> event = new HashMap<>();
                    event.put("errorCode", errorCode);
                    scanFailedSink.success(event);
                }
            };
        }

        return scanCallback;
    }

    private String getLocalName(ScanRecord scanRecord)
    {
        if (scanRecord == null) {
            return null;
        }

        return scanRecord.getDeviceName();
    }

    private HashMap<String, Object> serializeScanResult(int callbackType, ScanResult result)
    {
        if (result == null) {
            return null;
        }

        HashMap<String, Object> event = new HashMap<>();
        event.put("advertisingSid", getAdvertisingSid(result));
        event.put("callbackType", callbackType);
        event.put("device", BluetoothDeviceSerializer.serialize(result.getDevice()));
        event.put("isConnectable", getIsConnectable(result));
        event.put("isLegacy", getIsLegacy(result));
        event.put("localName", getLocalName(result.getScanRecord()));
        event.put("periodicAdvertisingInterval", getPeriodicAdvertisingInterval(result));
        event.put("primaryPhy", getPrimaryPhy(result));
        event.put("rssi", result.getRssi());
        event.put("scanRecord", ScanRecordSerializer.serialize(result.getScanRecord()));
        event.put("secondaryPhy", getSecondaryPhy(result));
        event.put("timestampNanos", result.getTimestampNanos());
        event.put("txPower", getTxPower(result));
        return event;
    }

    private Boolean getIsConnectable(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.isConnectable();
    }

    private Boolean getIsLegacy(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.isLegacy();
    }

    private Integer getPrimaryPhy(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.getPrimaryPhy();
    }

    private Integer getSecondaryPhy(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.getSecondaryPhy();
    }

    private Integer getAdvertisingSid(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.getAdvertisingSid();
    }

    private Integer getTxPower(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.getTxPower();
    }

    private Integer getPeriodicAdvertisingInterval(ScanResult scanResult)
    {
        if (android.os.Build.VERSION.SDK_INT < 26 || scanResult == null) {
            return null;
        }

        return scanResult.getPeriodicAdvertisingInterval();
    }

    private List<ScanFilter> buildScanFilters(List<HashMap<String, Object>> filtersMap)
    {
        List<ScanFilter> filters = new ArrayList<>();
        if (filtersMap == null) {
            return filters;
        }

        for (HashMap<String, Object> filterMap : filtersMap) {
            ScanFilter.Builder builder = new ScanFilter.Builder();

            byte[] advertisingData = (byte[]) filterMap.get("advertisingData");
            byte[] advertisingDataMask = (byte[]) filterMap.get("advertisingDataMask");
            Integer advertisingDataType = (Integer) filterMap.get("advertisingDataType");
            String deviceAddress = (String) filterMap.get("deviceAddress");
            String deviceName = (String) filterMap.get("deviceName");
            byte[] manufacturerData = (byte[]) filterMap.get("manufacturerData");
            byte[] manufacturerDataMask = (byte[]) filterMap.get("manufacturerDataMask");
            Integer manufacturerId = (Integer) filterMap.get("manufacturerId");
            byte[] serviceData = (byte[]) filterMap.get("serviceData");
            byte[] serviceDataMask = (byte[]) filterMap.get("serviceDataMask");
            String serviceDataUuid = (String) filterMap.get("serviceDataUuid");
            String serviceSolicitationUuid = (String) filterMap.get("serviceSolicitationUuid");
            String serviceSolicitationUuidMask = (String) filterMap.get("serviceSolicitationUuidMask");
            String serviceUuid = (String) filterMap.get("serviceUuid");
            String serviceUuidMask = (String) filterMap.get("serviceUuidMask");

            if (deviceAddress != null) {
                builder.setDeviceAddress(deviceAddress);
            }
            if (deviceName != null) {
                builder.setDeviceName(deviceName);
            }
            if (serviceUuid != null) {
                ParcelUuid parcelUuid = ParcelUuid.fromString(serviceUuid);
                if (serviceUuidMask != null) {
                    builder.setServiceUuid(parcelUuid, ParcelUuid.fromString(serviceUuidMask));
                } else {
                    builder.setServiceUuid(parcelUuid);
                }
            }
            if (android.os.Build.VERSION.SDK_INT >= 29 && serviceSolicitationUuid != null) {
                ParcelUuid parcelUuid = ParcelUuid.fromString(serviceSolicitationUuid);
                if (serviceSolicitationUuidMask != null) {
                    builder.setServiceSolicitationUuid(parcelUuid, ParcelUuid.fromString(serviceSolicitationUuidMask));
                } else {
                    builder.setServiceSolicitationUuid(parcelUuid);
                }
            }
            if (manufacturerId != null && manufacturerData != null) {
                if (manufacturerDataMask != null) {
                    builder.setManufacturerData(manufacturerId, manufacturerData, manufacturerDataMask);
                } else {
                    builder.setManufacturerData(manufacturerId, manufacturerData);
                }
            }
            if (serviceDataUuid != null && serviceData != null) {
                ParcelUuid parcelUuid = ParcelUuid.fromString(serviceDataUuid);
                if (serviceDataMask != null) {
                    builder.setServiceData(parcelUuid, serviceData, serviceDataMask);
                } else {
                    builder.setServiceData(parcelUuid, serviceData);
                }
            }
            if (android.os.Build.VERSION.SDK_INT >= 33 && advertisingDataType != null) {
                if (advertisingData != null) {
                    builder.setAdvertisingDataTypeWithData(advertisingDataType, advertisingData, advertisingDataMask);
                } else {
                    builder.setAdvertisingDataType(advertisingDataType);
                }
            }

            filters.add(builder.build());
        }

        return filters;
    }

    private ScanSettings buildScanSettings(HashMap<String, Object> settingsMap)
    {
        ScanSettings.Builder builder = new ScanSettings.Builder();
        int callbackType = ScanSettings.CALLBACK_TYPE_ALL_MATCHES;
        boolean legacy = true;
        int matchMode = ScanSettings.MATCH_MODE_AGGRESSIVE;
        int numOfMatches = ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT;
        int phy = ScanSettings.PHY_LE_ALL_SUPPORTED;
        long reportDelayMillis = 0L;
        int scanMode = ScanSettings.SCAN_MODE_LOW_POWER;

        if (settingsMap != null) {
            Object callbackTypeValue = settingsMap.get("callbackType");
            if (callbackTypeValue instanceof Integer) {
                callbackType = (Integer) callbackTypeValue;
            }

            Object scanModeValue = settingsMap.get("scanMode");
            if (scanModeValue instanceof Integer) {
                scanMode = (Integer) scanModeValue;
            }

            Object legacyValue = settingsMap.get("legacy");
            if (legacyValue instanceof Boolean) {
                legacy = (Boolean) legacyValue;
            }

            Object matchModeValue = settingsMap.get("matchMode");
            if (matchModeValue instanceof Integer) {
                matchMode = (Integer) matchModeValue;
            }

            Object numOfMatchesValue = settingsMap.get("numOfMatches");
            if (numOfMatchesValue instanceof Integer) {
                numOfMatches = (Integer) numOfMatchesValue;
            }

            Object phyValue = settingsMap.get("phy");
            if (phyValue instanceof Integer) {
                phy = (Integer) phyValue;
            }

            Object reportDelayValue = settingsMap.get("reportDelayMillis");
            if (reportDelayValue instanceof Integer) {
                reportDelayMillis = ((Integer) reportDelayValue).longValue();
            } else if (reportDelayValue instanceof Long) {
                reportDelayMillis = (Long) reportDelayValue;
            }
        }

        builder.setCallbackType(callbackType);
        builder.setReportDelay(reportDelayMillis);
        builder.setScanMode(scanMode);
        if (android.os.Build.VERSION.SDK_INT >= 23) {
            builder.setMatchMode(matchMode);
            builder.setNumOfMatches(numOfMatches);
        }
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            builder.setLegacy(legacy);
            builder.setPhy(phy);
        }
        return builder.build();
    }
}
