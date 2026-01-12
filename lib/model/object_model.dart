class DetectedObject {
  int? detectedObjectId;
  String? sourceKind;
  int? vehicleInfoId;
  int? infraInfoId;
  int? objectId;
  int? age;
  double? score;
  double? width;
  double? depth;
  double? height;
  double? positionX;
  double? positionY;
  double? positionZ;
  double? orientationHeading;
  double? linearVelocityX;
  double? linearVelocityY;
  double? linearVelocityZ;
  double? rotationRateX;
  double? rotationRateY;
  double? rotationRateZ;
  String? createdTimestamp;
  String? updatedTs;

  DetectedObject({
    this.detectedObjectId,
    this.sourceKind,
    this.vehicleInfoId,
    this.infraInfoId,
    this.objectId,
    this.age,
    this.score,
    this.width,
    this.depth,
    this.height,
    this.positionX,
    this.positionY,
    this.positionZ,
    this.orientationHeading,
    this.linearVelocityX,
    this.linearVelocityY,
    this.linearVelocityZ,
    this.rotationRateX,
    this.rotationRateY,
    this.rotationRateZ,
    this.createdTimestamp,
    this.updatedTs,
  });

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return double.tryParse(value.toString());
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      detectedObjectId: _parseInt(json['detected_object_id'] ?? json['id']),
      sourceKind: _parseString(json['source_kind']),
      vehicleInfoId: _parseInt(json['vehicle_info_id']),
      infraInfoId: _parseInt(json['infra_info_id']),
      objectId: _parseInt(json['object_id']),
      age: _parseInt(json['age']),
      score: _parseDouble(json['score']),
      width: _parseDouble(json['width']),
      depth: _parseDouble(json['depth']),
      height: _parseDouble(json['height']),
      positionX: _parseDouble(json['position_x']),
      positionY: _parseDouble(json['position_y']),
      positionZ: _parseDouble(json['position_z']),
      orientationHeading: _parseDouble(json['orientation_heading']),
      linearVelocityX: _parseDouble(json['linear_velocity_x']),
      linearVelocityY: _parseDouble(json['linear_velocity_y']),
      linearVelocityZ: _parseDouble(json['linear_velocity_z']),
      rotationRateX: _parseDouble(json['rotation_rate_x']),
      rotationRateY: _parseDouble(json['rotation_rate_y']),
      rotationRateZ: _parseDouble(json['rotation_rate_z']),
      createdTimestamp: _parseString(json['created_ts'] ?? json['created_at']),
      updatedTs: _parseString(json['updated_ts'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'detected_object_id': detectedObjectId,
      'source_kind': sourceKind,
      'vehicle_info_id': vehicleInfoId,
      'infra_info_id': infraInfoId,
      'object_id': objectId,
      'age': age,
      'score': score,
      'width': width,
      'depth': depth,
      'height': height,
      'position_x': positionX,
      'position_y': positionY,
      'position_z': positionZ,
      'orientation_heading': orientationHeading,
      'linear_velocity_x': linearVelocityX,
      'linear_velocity_y': linearVelocityY,
      'linear_velocity_z': linearVelocityZ,
      'rotation_rate_x': rotationRateX,
      'rotation_rate_y': rotationRateY,
      'rotation_rate_z': rotationRateZ,
      'created_ts': createdTimestamp,
      'updated_ts': updatedTs,
      'created_at': createdTimestamp,
    };
  }

  @override
  String toString() {
    return 'DetectedObject{detectedObjectId: $detectedObjectId, sourceKind: $sourceKind, '
        'vehicleInfoId: $vehicleInfoId, infraInfoId: $infraInfoId, objectId: $objectId}';
  }
}
