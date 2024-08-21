import 'device_identifier.dart';

class BmPreferredPhy {
  final DeviceIdentifier remoteId;
  final int txPhy;
  final int rxPhy;
  final int phyOptions;

  BmPreferredPhy({
    required this.remoteId,
    required this.txPhy,
    required this.rxPhy,
    required this.phyOptions,
  });

  factory BmPreferredPhy.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmPreferredPhy(
      remoteId: DeviceIdentifier(json['remote_id']),
      txPhy: json['tx_phy'],
      rxPhy: json['rx_phy'],
      phyOptions: json['phy_options'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'tx_phy': txPhy,
      'rx_phy': rxPhy,
      'phy_options': phyOptions,
    };
  }
}
