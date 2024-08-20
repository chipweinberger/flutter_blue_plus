import 'package:collection/collection.dart';

import 'bm_msd_filter.dart';
import 'bm_service_data_filter.dart';
import 'guid.dart';

class BmScanSettings {
  final List<Guid> withServices;
  final List<String> withRemoteIds;
  final List<String> withNames;
  final List<String> withKeywords;
  final List<BmMsdFilter> withMsd;
  final List<BmServiceDataFilter> withServiceData;
  final bool continuousUpdates;
  final int continuousDivisor;
  final bool androidLegacy;
  final int androidScanMode;
  final bool androidUsesFineLocation;

  BmScanSettings({
    required this.withServices,
    required this.withRemoteIds,
    required this.withNames,
    required this.withKeywords,
    required this.withMsd,
    required this.withServiceData,
    required this.continuousUpdates,
    required this.continuousDivisor,
    required this.androidLegacy,
    required this.androidScanMode,
    required this.androidUsesFineLocation,
  });

  factory BmScanSettings.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmScanSettings(
      withServices: (json['with_services'] as List<dynamic>?)
              ?.map((str) => Guid(str))
              .toList() ??
          [],
      withRemoteIds:
          (json['with_remote_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      withNames: (json['with_names'] as List<dynamic>?)?.cast<String>() ?? [],
      withKeywords:
          (json['with_keywords'] as List<dynamic>?)?.cast<String>() ?? [],
      withMsd: (json['with_msd'] as List<dynamic>?)
              ?.map((manufacturerData) => BmMsdFilter.fromMap(manufacturerData))
              .toList() ??
          [],
      withServiceData: (json['with_service_data'] as List<dynamic>?)
              ?.map((serviceData) => BmServiceDataFilter.fromMap(serviceData))
              .toList() ??
          [],
      continuousUpdates: json['continuous_updates'],
      continuousDivisor: json['continuous_divisor'],
      androidLegacy: json['android_legacy'],
      androidScanMode: json['android_scan_mode'],
      androidUsesFineLocation: json['android_uses_fine_location'],
    );
  }

  @override
  int get hashCode {
    return const ListEquality<Guid>().hash(withServices) ^
        const ListEquality<String>().hash(withRemoteIds) ^
        const ListEquality<String>().hash(withNames) ^
        const ListEquality<String>().hash(withKeywords) ^
        const ListEquality<BmMsdFilter>().hash(withMsd) ^
        const ListEquality<BmServiceDataFilter>().hash(withServiceData) ^
        continuousUpdates.hashCode ^
        continuousDivisor.hashCode ^
        androidLegacy.hashCode ^
        androidScanMode.hashCode ^
        androidUsesFineLocation.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmScanSettings && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'with_services': withServices.map((uuid) => uuid.str).toList(),
      'with_remote_ids': withRemoteIds,
      'with_names': withNames,
      'with_keywords': withKeywords,
      'with_msd':
          withMsd.map((manufacturerData) => manufacturerData.toMap()).toList(),
      'with_service_data':
          withServiceData.map((serviceData) => serviceData.toMap()).toList(),
      'continuous_updates': continuousUpdates,
      'continuous_divisor': continuousDivisor,
      'android_legacy': androidLegacy,
      'android_scan_mode': androidScanMode,
      'android_uses_fine_location': androidUsesFineLocation,
    };
  }
}
