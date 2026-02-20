// ivis.3tier.frontend/lib/model/object_model.dart

class DetectedObject {
  int? detectedObjectId;
  String? sourceKind;
  int? vehicleInfoId;
  int? infraInfoId;
  int? objectId;

  int? msgId;
  int? msgSeq;

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
  int? numberOfObjects;
  int? objectType;
  String? createdTs;
  String? updatedTs;

  DetectedObject({
    this.detectedObjectId,
    this.sourceKind,
    this.vehicleInfoId,
    this.infraInfoId,
    this.objectId,
    this.msgId,
    this.msgSeq,
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
    this.numberOfObjects,
    this.objectType,
    this.createdTs,
    this.updatedTs,
  });

  DetectedObject.fromJson(Map<String, dynamic> json) {
    detectedObjectId = _parseInt(json['detected_object_id'] ?? json['id']);
    sourceKind = _parseString(json['source_kind']);
    vehicleInfoId = _parseInt(json['vehicle_info_id']);
    infraInfoId = _parseInt(json['infra_info_id']);
    objectId = _parseInt(json['object_id']);

    msgId = _parseInt(json['msg_id']);
    msgSeq = _parseInt(json['msg_seq']);

    age = _parseInt(json['age']);
    score = _parseDouble(json['score']);
    width = _parseDouble(json['width']);
    depth = _parseDouble(json['depth']);
    height = _parseDouble(json['height']);
    positionX = _parseDouble(json['position_x']);
    positionY = _parseDouble(json['position_y']);
    positionZ = _parseDouble(json['position_z']);
    orientationHeading = _parseDouble(json['orientation_heading']);
    linearVelocityX = _parseDouble(json['linear_velocity_x']);
    linearVelocityY = _parseDouble(json['linear_velocity_y']);
    linearVelocityZ = _parseDouble(json['linear_velocity_z']);
    rotationRateX = _parseDouble(json['rotation_rate_x']);
    rotationRateY = _parseDouble(json['rotation_rate_y']);
    rotationRateZ = _parseDouble(json['rotation_rate_z']);
    numberOfObjects = _parseInt(json['number_of_objects']);
    objectType = _parseInt(json['object_type']);
    createdTs = _parseString(json['created_ts'] ?? json['created_at']);
    updatedTs = _parseString(json['updated_ts'] ?? json['updated_at']);
  }

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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'detected_object_id': detectedObjectId,
      'source_kind': sourceKind,
      'vehicle_info_id': vehicleInfoId,
      'infra_info_id': infraInfoId,
      'object_id': objectId,
      'msg_id': msgId,
      'msg_seq': msgSeq,
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
      'number_of_objects': numberOfObjects,
      'object_type': objectType,
      'created_ts': createdTs,
      'updated_ts': updatedTs,
    };
  }

  @override
  String toString() {
    return 'DetectedObject{detectedObjectId: $detectedObjectId, objectId: $objectId, msgId: $msgId, msgSeq: $msgSeq, vehicleInfoId: $vehicleInfoId, infraInfoId: $infraInfoId}';
  }
}

class DetectedObjectResult {
  int totalCount;
  List<DetectedObject> items;

  DetectedObjectResult({
    this.totalCount = 0,
    this.items = const <DetectedObject>[],
  });

  DetectedObjectResult.fromJson(Map<String, dynamic> json)
      : totalCount = 0,
        items = <DetectedObject>[] {
    totalCount = _parseInt(json['totalCount'] ?? json['total']) ?? 0;
    final dynamic itemsRaw = json['items'];
    if (itemsRaw is List) {
      items = <DetectedObject>[];
      for (final dynamic element in itemsRaw) {
        if (element is Map) {
          try {
            items.add(DetectedObject.fromJson(Map<String, dynamic>.from(element)));
          } catch (_) {}
        }
      }
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  @override
  String toString() {
    return 'DetectedObjectResult{totalCount: $totalCount, items: ${items.length}}';
  }
}

class DetectedObjectHistory {
  int? historyId;
  int? detectedObjectId;
  String? changedAt;
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
  int? numberOfObjects;
  int? objectType;
  String? createdTs;
  String? updatedTs;

  DetectedObjectHistory({
    this.historyId,
    this.detectedObjectId,
    this.changedAt,
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
    this.numberOfObjects,
    this.objectType,
    this.createdTs,
    this.updatedTs,
  });

  DetectedObjectHistory.fromJson(Map<String, dynamic> json) {
    historyId = _parseInt(json['history_id']);
    detectedObjectId = _parseInt(json['detected_object_id']);
    changedAt = _parseString(json['changed_at']);
    sourceKind = _parseString(json['source_kind']);
    vehicleInfoId = _parseInt(json['vehicle_info_id']);
    infraInfoId = _parseInt(json['infra_info_id']);
    objectId = _parseInt(json['object_id']);
    age = _parseInt(json['age']);
    score = _parseDouble(json['score']);
    width = _parseDouble(json['width']);
    depth = _parseDouble(json['depth']);
    height = _parseDouble(json['height']);
    positionX = _parseDouble(json['position_x']);
    positionY = _parseDouble(json['position_y']);
    positionZ = _parseDouble(json['position_z']);
    orientationHeading = _parseDouble(json['orientation_heading']);
    linearVelocityX = _parseDouble(json['linear_velocity_x']);
    linearVelocityY = _parseDouble(json['linear_velocity_y']);
    linearVelocityZ = _parseDouble(json['linear_velocity_z']);
    rotationRateX = _parseDouble(json['rotation_rate_x']);
    rotationRateY = _parseDouble(json['rotation_rate_y']);
    rotationRateZ = _parseDouble(json['rotation_rate_z']);
    numberOfObjects = _parseInt(json['number_of_objects']);
    objectType = _parseInt(json['object_type']);
    createdTs = _parseString(json['created_ts'] ?? json['created_at']);
    updatedTs = _parseString(json['updated_ts'] ?? json['updated_at']);
  }

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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'history_id': historyId,
      'detected_object_id': detectedObjectId,
      'changed_at': changedAt,
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
      'number_of_objects': numberOfObjects,
      'object_type': objectType,
      'created_ts': createdTs,
      'updated_ts': updatedTs,
    };
  }

  @override
  String toString() {
    return 'DetectedObjectHistory{historyId: $historyId, detectedObjectId: $detectedObjectId, objectId: $objectId}';
  }
}

class DetectedObjectHistoryResult {
  int totalCount;
  List<DetectedObjectHistory> items;

  DetectedObjectHistoryResult({
    this.totalCount = 0,
    this.items = const <DetectedObjectHistory>[],
  });

  DetectedObjectHistoryResult.fromJson(Map<String, dynamic> json)
      : totalCount = 0,
        items = <DetectedObjectHistory>[] {
    totalCount = _parseInt(json['totalCount'] ?? json['total']) ?? 0;
    final dynamic itemsRaw = json['items'];
    if (itemsRaw is List) {
      items = <DetectedObjectHistory>[];
      for (final dynamic element in itemsRaw) {
        if (element is Map) {
          try {
            items.add(DetectedObjectHistory.fromJson(Map<String, dynamic>.from(element)));
          } catch (_) {}
        }
      }
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  @override
  String toString() {
    return 'DetectedObjectHistoryResult{totalCount: $totalCount, items: ${items.length}}';
  }
}
