part of '../flutter_blue_plus_android.dart';

const _bluetoothConnect = 'android.permission.BLUETOOTH_CONNECT';
const _bluetoothScan = 'android.permission.BLUETOOTH_SCAN';
const _bluetooth = 'android.permission.BLUETOOTH';
const _fineLocation = 'android.permission.ACCESS_FINE_LOCATION';
const _cccd = '00002902-0000-1000-8000-00805f9b34fb';
const _defaultMtu = 23;
const _maximumAttributeLength = 512;

BmBluetoothDevice _deviceInfo(ab.BluetoothDevice device) =>
    BmBluetoothDevice(remoteId: DeviceIdentifier(device.address), platformName: device.name);

Never _fail(String method, String message) => throw PlatformException(code: method, message: message);

String _shortUuid(String uuid) => Guid(uuid).str;

bool _sameUuid(String a, String b) => Guid(a) == Guid(b);

BmAdapterStateEnum _adapterState(int state) => switch (state) {
      ab.BluetoothAdapter.stateOff => BmAdapterStateEnum.off,
      ab.BluetoothAdapter.stateTurningOn => BmAdapterStateEnum.turningOn,
      ab.BluetoothAdapter.stateOn => BmAdapterStateEnum.on,
      ab.BluetoothAdapter.stateTurningOff => BmAdapterStateEnum.turningOff,
      _ => BmAdapterStateEnum.unknown,
    };

BmBondStateEnum _bondState(int? state) => switch (state) {
      ab.BluetoothDevice.bondBonding => BmBondStateEnum.bonding,
      ab.BluetoothDevice.bondBonded => BmBondStateEnum.bonded,
      _ => BmBondStateEnum.none,
    };
Map<String, Object?> _deviceMap(ab.BluetoothDevice device) =>
    {'remote_id': device.address, 'platform_name': device.name};

Map<String, Object?> _gattStatus(int status) =>
    {'success': status == 0 ? 1 : 0, 'error_code': status, 'error_string': _gattError(status)};

String _gattError(int value) => switch (value) {
      0 => 'GATT_SUCCESS',
      1 => 'GATT_INVALID_HANDLE',
      2 => 'GATT_READ_NOT_PERMITTED',
      3 => 'GATT_WRITE_NOT_PERMITTED',
      4 => 'GATT_INVALID_PDU',
      5 => 'GATT_INSUFFICIENT_AUTHENTICATION',
      6 => 'GATT_REQUEST_NOT_SUPPORTED',
      7 => 'GATT_INVALID_OFFSET',
      8 => 'GATT_INSUFFICIENT_AUTHORIZATION',
      9 => 'GATT_PREPARE_QUEUE_FULL',
      10 => 'GATT_ATTR_NOT_FOUND',
      11 => 'GATT_ATTR_NOT_LONG',
      12 => 'GATT_INSUFFICIENT_KEY_SIZE',
      13 => 'GATT_INVALID_ATTRIBUTE_LENGTH',
      14 => 'GATT_UNLIKELY',
      15 => 'GATT_INSUFFICIENT_ENCRYPTION',
      16 => 'GATT_UNSUPPORTED_GROUP',
      17 => 'GATT_INSUFFICIENT_RESOURCES',
      128 => 'GATT_NO_RESOURCES',
      129 => 'GATT_INTERNAL_ERROR',
      130 => 'GATT_WRONG_STATE',
      131 => 'GATT_DB_FULL',
      132 => 'GATT_BUSY',
      133 => 'GATT_ERROR',
      134 => 'GATT_CMD_STARTED',
      135 => 'GATT_ILLEGAL_PARAMETER',
      136 => 'GATT_PENDING',
      137 => 'GATT_AUTH_FAIL',
      138 => 'GATT_MORE',
      139 => 'GATT_INVALID_CFG',
      140 => 'GATT_SERVICE_STARTED',
      141 => 'GATT_ENCRYPTED_NO_MITM',
      142 => 'GATT_NOT_ENCRYPTED',
      143 => 'GATT_CONNECTION_CONGESTED',
      257 => 'GATT_FAILURE',
      _ => 'UNKNOWN_GATT_ERROR ($value)',
    };

String _hciStatus(int value) => switch (value) {
      0 => 'SUCCESS',
      1 => 'UNKNOWN_COMMAND',
      2 => 'UNKNOWN_CONNECTION_IDENTIFIER',
      3 => 'HARDWARE_FAILURE',
      4 => 'PAGE_TIMEOUT',
      5 => 'AUTHENTICATION_FAILURE',
      6 => 'PIN_OR_KEY_MISSING',
      7 => 'MEMORY_FULL',
      8 => 'LINK_SUPERVISION_TIMEOUT',
      9 => 'CONNECTION_LIMIT_EXCEEDED',
      10 => 'MAX_NUM_OF_CONNECTIONS_EXCEEDED',
      11 => 'CONNECTION_ALREADY_EXISTS',
      12 => 'COMMAND_DISALLOWED',
      13 => 'CONNECTION_REJECTED_LIMITED_RESOURCES',
      14 => 'CONNECTION_REJECTED_SECURITY_REASONS',
      15 => 'CONNECTION_REJECTED_UNACCEPTABLE_MAC_ADDRESS',
      16 => 'CONNECTION_ACCEPT_TIMEOUT_EXCEEDED',
      17 => 'UNSUPPORTED_PARAMETER_VALUE',
      18 => 'INVALID_COMMAND_PARAMETERS',
      19 => 'REMOTE_USER_TERMINATED_CONNECTION',
      20 => 'REMOTE_DEVICE_TERMINATED_CONNECTION_LOW_RESOURCES',
      21 => 'REMOTE_DEVICE_TERMINATED_CONNECTION_POWER_OFF',
      22 => 'CONNECTION_TERMINATED_BY_LOCAL_HOST',
      23 => 'REPEATED_ATTEMPTS',
      24 => 'PAIRING_NOT_ALLOWED',
      25 => 'UNKNOWN_LMP_PDU',
      26 => 'UNSUPPORTED_REMOTE_FEATURE',
      27 => 'SCO_OFFSET_REJECTED',
      28 => 'SCO_INTERVAL_REJECTED',
      29 => 'SCO_AIR_MODE_REJECTED',
      30 => 'INVALID_LMP_OR_LL_PARAMETERS',
      31 => 'UNSPECIFIED',
      32 => 'UNSUPPORTED_LMP_OR_LL_PARAMETER_VALUE',
      33 => 'ROLE_CHANGE_NOT_ALLOWED',
      34 => 'LMP_OR_LL_RESPONSE_TIMEOUT',
      35 => 'LMP_OR_LL_ERROR_TRANS_COLLISION',
      36 => 'LMP_PDU_NOT_ALLOWED',
      37 => 'ENCRYPTION_MODE_NOT_ACCEPTABLE',
      38 => 'LINK_KEY_CANNOT_BE_EXCHANGED',
      39 => 'REQUESTED_QOS_NOT_SUPPORTED',
      40 => 'INSTANT_PASSED',
      41 => 'PAIRING_WITH_UNIT_KEY_NOT_SUPPORTED',
      42 => 'DIFFERENT_TRANSACTION_COLLISION',
      43 => 'UNDEFINED_0x2B',
      44 => 'QOS_UNACCEPTABLE_PARAMETER',
      45 => 'QOS_REJECTED',
      46 => 'CHANNEL_CLASSIFICATION_NOT_SUPPORTED',
      47 => 'INSUFFICIENT_SECURITY',
      48 => 'PARAMETER_OUT_OF_RANGE',
      49 => 'UNDEFINED_0x31',
      50 => 'ROLE_SWITCH_PENDING',
      51 => 'UNDEFINED_0x33',
      52 => 'RESERVED_SLOT_VIOLATION',
      53 => 'ROLE_SWITCH_FAILED',
      54 => 'INQUIRY_RESPONSE_TOO_LARGE',
      55 => 'SECURE_SIMPLE_PAIRING_NOT_SUPPORTED',
      56 => 'HOST_BUSY_PAIRING',
      57 => 'CONNECTION_REJECTED_NO_SUITABLE_CHANNEL',
      58 => 'CONTROLLER_BUSY',
      59 => 'UNACCEPTABLE_CONNECTION_PARAMETERS',
      60 => 'ADVERTISING_TIMEOUT',
      61 => 'CONNECTION_TERMINATED_MIC_FAILURE',
      62 => 'CONNECTION_FAILED_ESTABLISHMENT',
      63 => 'MAC_CONNECTION_FAILED',
      64 => 'COARSE_CLOCK_ADJUSTMENT_REJECTED',
      65 => 'TYPE0_SUBMAP_NOT_DEFINED',
      66 => 'UNKNOWN_ADVERTISING_IDENTIFIER',
      67 => 'LIMIT_REACHED',
      68 => 'OPERATION_CANCELLED_BY_HOST',
      69 => 'PACKET_TOO_LONG',
      133 => 'ANDROID_SPECIFIC_ERROR',
      143 => 'GATT_CONNECTION_CONGESTED',
      147 => 'GATT_CONNECTION_TIMEOUT',
      257 => 'FAILURE_REGISTERING_CLIENT',
      _ => 'UNKNOWN_HCI_ERROR ($value)',
    };

String _bluetoothStatus(int value) => switch (value) {
      2 => 'ERROR_BLUETOOTH_NOT_ALLOWED',
      1 => 'ERROR_BLUETOOTH_NOT_ENABLED',
      3 => 'ERROR_DEVICE_NOT_BONDED',
      200 => 'ERROR_GATT_WRITE_NOT_ALLOWED',
      201 => 'ERROR_GATT_WRITE_REQUEST_BUSY',
      6 => 'ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION',
      9 => 'ERROR_PROFILE_SERVICE_NOT_BOUND',
      2147483647 => 'ERROR_UNKNOWN',
      11 => 'FEATURE_NOT_SUPPORTED',
      10 => 'FEATURE_SUPPORTED',
      0 => 'SUCCESS',
      _ => 'UNKNOWN_BLE_ERROR ($value)',
    };

String _scanFailed(int value) => switch (value) {
      1 => 'SCAN_FAILED_ALREADY_STARTED',
      2 => 'SCAN_FAILED_APPLICATION_REGISTRATION_FAILED',
      4 => 'SCAN_FAILED_FEATURE_UNSUPPORTED',
      3 => 'SCAN_FAILED_INTERNAL_ERROR',
      5 => 'SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES',
      6 => 'SCAN_FAILED_SCANNING_TOO_FREQUENTLY',
      _ => 'UNKNOWN_SCAN_ERROR ($value)',
    };
