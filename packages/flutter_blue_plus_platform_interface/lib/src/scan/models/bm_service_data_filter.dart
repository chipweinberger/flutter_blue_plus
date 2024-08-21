import 'package:convert/convert.dart';

import '../../common/models/guid.dart';

class BmServiceDataFilter {
  Guid service;
  List<int> data;
  List<int> mask;

  BmServiceDataFilter(
    this.service,
    this.data,
    this.mask,
  );

  factory BmServiceDataFilter.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmServiceDataFilter(
      Guid(json['service']),
      json['data'] != null ? hex.decode(json['data']) : [],
      json['mask'] != null ? hex.decode(json['mask']) : [],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'service': service.str,
      'data': hex.encode(data),
      'mask': hex.encode(mask),
    };
  }
}
