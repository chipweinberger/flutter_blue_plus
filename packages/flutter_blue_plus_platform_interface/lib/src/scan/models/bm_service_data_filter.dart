import 'package:collection/collection.dart';
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

  @override
  int get hashCode {
    return service.hashCode ^
        const ListEquality<int>().hash(data) ^
        const ListEquality<int>().hash(mask);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmServiceDataFilter && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'service': service.str,
      'data': hex.encode(data),
      'mask': hex.encode(mask),
    };
  }
}
