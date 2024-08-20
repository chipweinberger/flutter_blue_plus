import 'package:collection/collection.dart';
import 'package:convert/convert.dart';

class BmMsdFilter {
  int manufacturerId;
  List<int>? data;
  List<int>? mask;

  BmMsdFilter(
    this.manufacturerId,
    this.data,
    this.mask,
  );

  factory BmMsdFilter.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmMsdFilter(
      json['manufacturer_id'],
      json['data'] != null ? hex.decode(json['data']) : null,
      json['mask'] != null ? hex.decode(json['mask']) : null,
    );
  }

  @override
  int get hashCode {
    return manufacturerId.hashCode ^
        const ListEquality<int>().hash(data) ^
        const ListEquality<int>().hash(mask);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmMsdFilter && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'manufacturer_id': manufacturerId,
      'data': data != null ? hex.encode(data!) : null,
      'mask': mask != null ? hex.encode(mask!) : null,
    };
  }
}
