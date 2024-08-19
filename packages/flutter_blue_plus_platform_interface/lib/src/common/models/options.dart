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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Options && hashCode == other.hashCode;
  }

  @override
  int get hashCode {
    return showPowerAlert.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'show_power_alert': showPowerAlert,
    };
  }
}
