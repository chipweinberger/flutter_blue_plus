part of '../core_bluetooth.dart';

final class CBError {
  const CBError({
    required this.code,
    required this.domain,
    this.localizedDescription,
  });

  factory CBError.fromMap(Map<Object?, Object?> map) {
    return CBError(
      code: CBErrorCode.fromRawValue((map['code'] as num?)?.toInt() ?? 0),
      domain: map['domain'] as String? ?? 'CBErrorDomain',
      localizedDescription: map['localizedDescription'] as String?,
    );
  }

  final CBErrorCode code;
  final String domain;
  final String? localizedDescription;
}
