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

  Map<dynamic, dynamic> toMap() {
    return {
      'manufacturer_id': manufacturerId,
      'data': data != null ? hex.encode(data!) : null,
      'mask': mask != null ? hex.encode(mask!) : null,
    };
  }
}
