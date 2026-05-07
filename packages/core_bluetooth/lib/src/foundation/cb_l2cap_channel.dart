part of '../core_bluetooth.dart';

final class CBL2CAPChannel {
  CBL2CAPChannel._({
    required this.peer,
    required this.psm,
    required String handle,
  })  : inputStream = InputStream._(handle: handle),
        outputStream = OutputStream._(handle: handle);

  factory CBL2CAPChannel.fromMap({
    CBCentralManager? manager,
    required Map<Object?, Object?> map,
  }) {
    final peerKind = map['peerKind'] as String?;
    final peer = switch (peerKind) {
      'central' => CBCentral.fromMap({
          'identifier': map['peerIdentifier'],
          'maximumUpdateValueLength': map['peerMaximumUpdateValueLength'],
        }),
      'peripheral' when manager != null => manager._upsertPeripheral({
          'identifier': map['peerIdentifier'],
          'name': map['peerName'],
          'state': map['peerState'],
          'canSendWriteWithoutResponse': map['peerCanSendWriteWithoutResponse'],
          'ancsAuthorized': map['peerAncsAuthorized'],
        }),
      _ => CBPeer(
          identifier: UUID((map['peerIdentifier'] as String?) ?? ''),
        ),
    };

    return CBL2CAPChannel._(
      handle: map['handle'] as String? ?? '',
      peer: peer,
      psm: (map['psm'] as num?)?.toInt() ?? 0,
    );
  }

  final InputStream inputStream;
  final OutputStream outputStream;
  final CBPeer peer;
  final CBL2CAPPSM psm;
}
