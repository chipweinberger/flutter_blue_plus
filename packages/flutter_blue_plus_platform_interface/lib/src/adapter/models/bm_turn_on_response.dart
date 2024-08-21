class BmTurnOnResponse {
  bool userAccepted;

  BmTurnOnResponse({
    required this.userAccepted,
  });

  factory BmTurnOnResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmTurnOnResponse(
      userAccepted: json['user_accepted'] ?? false,
    );
  }

  @override
  int get hashCode {
    return userAccepted.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmTurnOnResponse && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'user_accepted': userAccepted,
    };
  }
}
