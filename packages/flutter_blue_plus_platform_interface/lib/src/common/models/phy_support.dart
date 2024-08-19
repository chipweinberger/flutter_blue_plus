class PhySupport {
  /// High speed (PHY 2M)
  final bool le2M;

  /// Long range (PHY codec)
  final bool leCoded;

  PhySupport({
    required this.le2M,
    required this.leCoded,
  });

  factory PhySupport.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return PhySupport(
      le2M: json['le_2M'],
      leCoded: json['le_coded'],
    );
  }

  @override
  int get hashCode {
    return le2M.hashCode ^ leCoded.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PhySupport && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'le_2M': le2M,
      'le_coded': leCoded,
    };
  }
}
