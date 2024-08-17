class Options {
  /// Whether to show the power alert (iOS & macOS only). i.e. CBCentralManagerOptionShowPowerAlertKey
  final bool showPowerAlert;

  Options({
    required this.showPowerAlert,
  });

  factory Options.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return Options(
      showPowerAlert: json['show_power_alert'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'show_power_alert': showPowerAlert,
    };
  }
}
