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

  Map<dynamic, dynamic> toMap() {
    return {
      'user_accepted': userAccepted,
    };
  }
}
