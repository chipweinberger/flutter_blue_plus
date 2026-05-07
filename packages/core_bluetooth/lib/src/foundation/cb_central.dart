part of '../core_bluetooth.dart';

final class CBCentral extends CBPeer {
  CBCentral({
    required super.identifier,
    required this.maximumUpdateValueLength,
  });

  factory CBCentral.fromMap(Map<Object?, Object?> map) {
    return CBCentral(
      identifier: UUID(map['identifier'] as String? ?? '00000000-0000-0000-0000-000000000000'),
      maximumUpdateValueLength: (map['maximumUpdateValueLength'] as num?)?.toInt() ?? 0,
    );
  }

  final int maximumUpdateValueLength;
}
