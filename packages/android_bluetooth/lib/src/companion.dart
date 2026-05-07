part of '../android_bluetooth.dart';

final class AssociationInfo {
  AssociationInfo._(this.data);
  final Map<String, Object?> data;

  /// Null on API 26–32, which expose associations as addresses.
  int? get id => data['id'] as int?;
  String? get deviceMacAddress => data['deviceMacAddress'] as String?;
  String? get displayName => data['displayName'] as String?;
  String? get deviceProfile => data['deviceProfile'] as String?;
  bool? get isSelfManaged => data['isSelfManaged'] as bool?;
}

final class AssociationRequest {
  const AssociationRequest(
      {this.filters = const [],
      this.singleDevice = true,
      this.namePattern,
      this.displayName,
      this.forceConfirmation = false});
  final List<ScanFilter> filters;
  final bool singleDevice, forceConfirmation;
  final String? namePattern, displayName;
  _Map _toMap() => {
        'filters': filters.map((f) => f._toMap()).toList(),
        'singleDevice': singleDevice,
        'namePattern': namePattern,
        'displayName': displayName,
        'forceConfirmation': forceConfirmation
      };
}

final class CompanionDeviceCallback extends BluetoothEvent {
  CompanionDeviceCallback._(super.data) : super._();
  AssociationInfo? get association => data['association'] == null ? null : AssociationInfo._(_map(data['association']));
  int? get resultCode => data['resultCode'] as int?;
  int? get associationId => data['associationId'] as int? ?? association?.id;
  int? get presenceEvent => data['presenceEvent'] as int?;
  String? get address => data['address'] as String? ?? association?.deviceMacAddress;
  String? get uuid => data['uuid'] as String?;

  /// The last callback for this association attempt, delivered before stream completion.
  bool get isComplete => data['isComplete'] == true;
}

final class CompanionAssociation {
  CompanionAssociation._(String id) : _session = _Session(id);
  final _Session _session;
  String get id => _session.id;

  /// Completes after success, failure or cancellation. UI-based API 33+ success
  /// retains both onAssociationCreated and onAssociationResult, in either order.
  Stream<CompanionDeviceCallback> get events => _session.events().map(CompanionDeviceCallback._);
}

/// API 26+. Association and Bluetooth bonding are distinct operations.
final class CompanionDeviceManager {
  CompanionDeviceManager._();
  static final shared = CompanionDeviceManager._();
  Stream<CompanionDeviceCallback> get events => _Host.events('companion').map(CompanionDeviceCallback._);

  /// API 26+. Requires an attached Activity; opens Android's association chooser when ready.
  /// forceConfirmation requires API 33+. Association results arrive through the returned registration.
  Future<CompanionAssociation> associate(AssociationRequest request) async =>
      CompanionAssociation._(await _Host.call<String>('companion.associate', request._toMap()));

  /// API 26+. Association is distinct from Bluetooth bonding; declare companion permissions required by the selected operation.
  Future<List<AssociationInfo>> get myAssociations async =>
      _decodeList(await _Host.call<Object>('companion.associations'), AssociationInfo._);

  /// API 26+. Association is distinct from Bluetooth bonding; declare companion permissions required by the selected operation.
  Future<void> disassociate({int? associationId, String? address}) =>
      _Host.call<void>('companion.disassociate', {'associationId': associationId, 'address': address});

  /// API 31+. Requires REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE.
  /// associationId requires API 36, a build with SDK 36+, and
  /// `com.jamcorder.android_bluetooth.BluetoothCompanionPresenceService` declared
  /// in the application manifest. Its `onDevicePresenceEvent` callbacks arrive on
  /// [events], with [CompanionDeviceCallback.associationId] and
  /// [CompanionDeviceCallback.presenceEvent]. Earlier SDKs use the associated
  /// address and `BluetoothCompanionService` for appeared/disappeared callbacks.
  Future<void> startObservingDevicePresence({int? associationId, String? address}) =>
      _Host.call<void>('companion.observe', {'associationId': associationId, 'address': address});

  /// API 31+. Requires REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE. associationId requires API 36.
  Future<void> stopObservingDevicePresence({int? associationId, String? address}) =>
      _Host.call<void>('companion.stopObserving', {'associationId': associationId, 'address': address});

  /// API 36+. Public bond removal for an app-owned companion association, as an alternative to
  /// BluetoothDevice's hidden removeBond method. Native eligibility checks still apply.
  Future<bool> removeBond(int associationId) =>
      _Host.call<bool>('companion.removeBond', {'associationId': associationId});
}

/// Optional Android foreground-service integration for an ongoing device task.
/// The application must declare FOREGROUND_SERVICE and, on 34+, FOREGROUND_SERVICE_CONNECTED_DEVICE.
/// This keeps the Android process important; it does not create or restore a Flutter engine.
abstract final class BluetoothConnectionService {
  /// Requires foreground-service permissions in the application manifest and eligibility to start a connectedDevice service. No Flutter engine is created.
  /// Throws PlatformException with code `invalid_state` if Android cannot find the service.
  static Future<void> start({required String title, required String text, int notificationId = 51722}) =>
      _Host.call<void>('background.startService', {'title': title, 'text': text, 'notificationId': notificationId});

  /// Stops the explicitly started connection foreground service.
  static Future<void> stop() => _Host.call<void>('background.stopService');
}
