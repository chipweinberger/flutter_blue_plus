import 'bm_scan_advertisement.dart';

class BmScanResponse {
  final List<BmScanAdvertisement> advertisements;
  final bool success;
  final int errorCode;
  final String errorString;

  BmScanResponse({
    required this.advertisements,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmScanResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmScanResponse(
      advertisements: (json['advertisements'] as List<dynamic>?)
              ?.map(
                  (advertisement) => BmScanAdvertisement.fromMap(advertisement))
              .toList() ??
          [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'advertisements':
          advertisements.map((advertisement) => advertisement.toMap()),
      'success': success,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}
