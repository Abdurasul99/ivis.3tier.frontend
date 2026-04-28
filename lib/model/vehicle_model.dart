import 'object_model.dart';

class Vehicle {
  int? vehicleId;
  String? vehicleType;
  String? make;
  String? modelName;
  String? state;
  String? createdTimestamp;
  String? updatedTs;

  Vehicle({
    this.vehicleId,
    this.vehicleType,
    this.make,
    this.modelName,
    this.state,
    this.createdTimestamp,
    this.updatedTs,
  });

  Vehicle.fromJson(Map<String, dynamic> json) {
    vehicleId = _parseInt(json['vehicle_id'] ?? json['id']);
    vehicleType = _parseString(json['vehicle_type'] ?? json['type']);
    make = _parseString(json['make'] ?? json['name']);
    modelName = _parseString(
        json['model'] ?? json['model_name'] ?? json['description']);
    state = _parseString(json['state']);
    createdTimestamp = _parseString(json['created_ts'] ?? json['created_at']);
    updatedTs = _parseString(json['updated_ts'] ?? json['updated_at']);
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vehicle_id': vehicleId,
      'vehicle_type': vehicleType,
      'make': make,
      'model': modelName,
      'state': state,
      'created_ts': createdTimestamp,
      'updated_ts': updatedTs,
    };
  }
}

class VehicleInfo {
  int? id;
  int? vehicleId;
  int? msgId;
  int? msgSeq;
  int? msgLength;
  int? timeStamp;
  int? timeStampMs;
  int? navsat;
  double? velocityKph;
  double? velocityMps;
  double? positionX;
  double? positionY;
  double? positionZ;
  double? orientationHeading;
  double? accelX;
  double? accelY;
  double? accelZ;
  double? rotRateX;
  double? rotRateY;
  double? rotRateZ;
  int? transmissionGear;
  int? signalLight;
  double? steerAngle;
  double? steerTorque;
  double? pedalAccel;
  double? brake;
  int? numberOfObjects;
  bool? payloadCrcOk;
  String? payloadBytesHex;
  String? createdTs;
  String? updatedTs;

  VehicleInfo({
    this.id,
    this.vehicleId,
    this.msgId,
    this.msgSeq,
    this.msgLength,
    this.timeStamp,
    this.timeStampMs,
    this.navsat,
    this.velocityKph,
    this.velocityMps,
    this.positionX,
    this.positionY,
    this.positionZ,
    this.orientationHeading,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.rotRateX,
    this.rotRateY,
    this.rotRateZ,
    this.transmissionGear,
    this.signalLight,
    this.steerAngle,
    this.steerTorque,
    this.pedalAccel,
    this.brake,
    this.numberOfObjects,
    this.payloadCrcOk,
    this.payloadBytesHex,
    this.createdTs,
    this.updatedTs,
  });

  VehicleInfo.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    vehicleId = _parseInt(json['vehicle_id']);
    msgId = _parseInt(json['msg_id']);
    msgSeq = _parseInt(json['msg_seq']);
    msgLength = _parseInt(json['msg_length']);
    timeStamp = _parseInt(json['time_stamp']);
    timeStampMs = _parseInt(json['time_stamp_ms']);
    navsat = _parseInt(json['navsat']);
    velocityKph = _parseDouble(json['kph'] ?? json['velocity_kph']);
    velocityMps = _parseDouble(json['mps'] ?? json['velocity_mps']);
    positionX = _parseDouble(json['pos_x_m'] ?? json['position_x']);
    positionY = _parseDouble(json['pos_y_m'] ?? json['position_y']);
    positionZ = _parseDouble(json['pos_z_m'] ?? json['position_z']);
    orientationHeading =
        _parseDouble(json['heading_deg'] ?? json['orientation_heading']);
    accelX = _parseDouble(json['accel_x_mps2'] ?? json['accel_x']);
    accelY = _parseDouble(json['accel_y_mps2'] ?? json['accel_y']);
    accelZ = _parseDouble(json['accel_z_mps2'] ?? json['accel_z']);
    rotRateX = _parseDouble(json['gyro_x_dps'] ?? json['rot_rate_x']);
    rotRateY = _parseDouble(json['gyro_y_dps'] ?? json['rot_rate_y']);
    rotRateZ = _parseDouble(json['gyro_z_dps'] ?? json['rot_rate_z']);
    transmissionGear = _parseInt(json['transmission_gear']);
    signalLight = _parseInt(json['signal_light']);
    steerAngle = _parseDouble(json['angle_deg'] ?? json['steer_angle']);
    steerTorque = _parseDouble(json['torque_nm'] ?? json['steer_torque']);
    pedalAccel = _parseDouble(json['accel_pct'] ?? json['pedal_accel']);
    brake = _parseDouble(json['brake_pct'] ?? json['brake']);
    numberOfObjects = _parseInt(json['number_of_objects']);
    payloadCrcOk = _parseBool(json['payload_crc_ok']);
    payloadBytesHex = _parseString(json['payload_bytes_hex']);
    createdTs = _parseString(json['created_at'] ?? json['created_ts']);
    updatedTs = _parseString(json['updated_at'] ?? json['updated_ts']);

    if (timeStampMs == null && timeStamp != null) {
      timeStampMs = timeStamp;
    }
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

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'vehicle_id': vehicleId,
      'msg_id': msgId,
      'msg_seq': msgSeq,
      'msg_length': msgLength,
      'time_stamp': timeStamp,
      'time_stamp_ms': timeStampMs,
      'navsat': navsat,
      'velocity_kph': velocityKph,
      'kph': velocityKph,
      'velocity_mps': velocityMps,
      'mps': velocityMps,
      'position_x': positionX,
      'pos_x_m': positionX,
      'position_y': positionY,
      'pos_y_m': positionY,
      'position_z': positionZ,
      'pos_z_m': positionZ,
      'orientation_heading': orientationHeading,
      'heading_deg': orientationHeading,
      'accel_x': accelX,
      'accel_x_mps2': accelX,
      'accel_y': accelY,
      'accel_y_mps2': accelY,
      'accel_z': accelZ,
      'accel_z_mps2': accelZ,
      'rot_rate_x': rotRateX,
      'gyro_x_dps': rotRateX,
      'rot_rate_y': rotRateY,
      'gyro_y_dps': rotRateY,
      'rot_rate_z': rotRateZ,
      'gyro_z_dps': rotRateZ,
      'transmission_gear': transmissionGear,
      'signal_light': signalLight,
      'steer_angle': steerAngle,
      'angle_deg': steerAngle,
      'steer_torque': steerTorque,
      'torque_nm': steerTorque,
      'pedal_accel': pedalAccel,
      'accel_pct': pedalAccel,
      'brake': brake,
      'brake_pct': brake,
      'number_of_objects': numberOfObjects,
      'payload_crc_ok': payloadCrcOk,
      'payload_bytes_hex': payloadBytesHex,
      'created_ts': createdTs,
      'updated_ts': updatedTs,
    };
  }
}

class VehicleInfoResult {
  int totalCount;
  List<VehicleInfo> items;

  VehicleInfoResult({
    this.totalCount = 0,
    this.items = const <VehicleInfo>[],
  });

  VehicleInfoResult.fromJson(Map<String, dynamic> json)
      : totalCount = 0,
        items = <VehicleInfo>[] {
    totalCount =
        _parseInt(json['totalCount'] ?? json['total_count'] ?? json['total']) ??
            0;
    final dynamic itemsRaw = json['items'];
    if (itemsRaw is List) {
      items = <VehicleInfo>[];
      for (final dynamic element in itemsRaw) {
        if (element is Map) {
          try {
            items.add(VehicleInfo.fromJson(Map<String, dynamic>.from(element)));
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
}

class VehicleInfoHistory {
  int? historyId;
  int? vehicleInfoId;
  int? vehicleId;
  String? changedAt;
  int? msgId;
  int? msgSeq;
  int? msgLength;
  int? timeStamp;
  int? timeStampMs;
  int? navsat;
  double? velocityKph;
  double? velocityMps;
  double? positionX;
  double? positionY;
  double? positionZ;
  double? orientationHeading;
  double? accelX;
  double? accelY;
  double? accelZ;
  double? rotRateX;
  double? rotRateY;
  double? rotRateZ;
  int? transmissionGear;
  int? signalLight;
  double? steerAngle;
  double? steerTorque;
  double? pedalAccel;
  double? brake;
  int? numberOfObjects;
  List<DetectedObject> objects = const <DetectedObject>[];
  bool? payloadCrcOk;
  String? payloadBytesHex;
  String? createdTs;
  String? updatedTs;

  VehicleInfoHistory({
    this.historyId,
    this.vehicleInfoId,
    this.vehicleId,
    this.changedAt,
    this.msgId,
    this.msgSeq,
    this.msgLength,
    this.timeStamp,
    this.timeStampMs,
    this.navsat,
    this.velocityKph,
    this.velocityMps,
    this.positionX,
    this.positionY,
    this.positionZ,
    this.orientationHeading,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.rotRateX,
    this.rotRateY,
    this.rotRateZ,
    this.transmissionGear,
    this.signalLight,
    this.steerAngle,
    this.steerTorque,
    this.pedalAccel,
    this.brake,
    this.numberOfObjects,
    this.objects = const <DetectedObject>[],
    this.payloadCrcOk,
    this.payloadBytesHex,
    this.createdTs,
    this.updatedTs,
  });

  VehicleInfoHistory.fromJson(Map<String, dynamic> json) {
    historyId = _parseInt(json['history_id']);
    vehicleInfoId = _parseInt(json['vehicle_info_id']);
    vehicleId = _parseInt(json['vehicle_id']);
    changedAt = _parseString(json['changed_at']);
    msgId = _parseInt(json['msg_id']);
    msgSeq = _parseInt(json['msg_seq']);
    msgLength = _parseInt(json['msg_length']);
    timeStamp = _parseInt(json['time_stamp']);
    timeStampMs = _parseInt(json['time_stamp_ms']);
    navsat = _parseInt(json['navsat']);
    velocityKph = _parseDouble(json['kph'] ?? json['velocity_kph']);
    velocityMps = _parseDouble(json['mps'] ?? json['velocity_mps']);
    positionX = _parseDouble(json['pos_x_m'] ?? json['position_x']);
    positionY = _parseDouble(json['pos_y_m'] ?? json['position_y']);
    positionZ = _parseDouble(json['pos_z_m'] ?? json['position_z']);
    orientationHeading =
        _parseDouble(json['heading_deg'] ?? json['orientation_heading']);
    accelX = _parseDouble(json['accel_x_mps2'] ?? json['accel_x']);
    accelY = _parseDouble(json['accel_y_mps2'] ?? json['accel_y']);
    accelZ = _parseDouble(json['accel_z_mps2'] ?? json['accel_z']);
    rotRateX = _parseDouble(json['gyro_x_dps'] ?? json['rot_rate_x']);
    rotRateY = _parseDouble(json['gyro_y_dps'] ?? json['rot_rate_y']);
    rotRateZ = _parseDouble(json['gyro_z_dps'] ?? json['rot_rate_z']);
    transmissionGear = _parseInt(json['transmission_gear']);
    signalLight = _parseInt(json['signal_light']);
    steerAngle = _parseDouble(json['angle_deg'] ?? json['steer_angle']);
    steerTorque = _parseDouble(json['torque_nm'] ?? json['steer_torque']);
    pedalAccel = _parseDouble(json['accel_pct'] ?? json['pedal_accel']);
    brake = _parseDouble(json['brake_pct'] ?? json['brake']);
    numberOfObjects = _parseInt(json['number_of_objects']);
    objects = _parseObjects(
        json['objects'] ?? json['detected_objects'] ?? json['detectedObjects']);
    payloadCrcOk = _parseBool(json['payload_crc_ok']);
    payloadBytesHex = _parseString(json['payload_bytes_hex']);
    createdTs = _parseString(json['created_at'] ?? json['created_ts']);
    updatedTs = _parseString(json['updated_at'] ?? json['updated_ts']);

    if (timeStampMs == null && timeStamp != null) {
      timeStampMs = timeStamp;
    }
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

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  static List<DetectedObject> _parseObjects(dynamic value) {
    if (value is! List) return <DetectedObject>[];

    final List<DetectedObject> parsed = <DetectedObject>[];
    for (final dynamic element in value) {
      if (element is Map) {
        try {
          parsed
              .add(DetectedObject.fromJson(Map<String, dynamic>.from(element)));
        } catch (_) {}
      }
    }
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'history_id': historyId,
      'vehicle_info_id': vehicleInfoId,
      'vehicle_id': vehicleId,
      'changed_at': changedAt,
      'msg_id': msgId,
      'msg_seq': msgSeq,
      'msg_length': msgLength,
      'time_stamp': timeStamp,
      'time_stamp_ms': timeStampMs,
      'navsat': navsat,
      'velocity_kph': velocityKph,
      'kph': velocityKph,
      'velocity_mps': velocityMps,
      'mps': velocityMps,
      'position_x': positionX,
      'pos_x_m': positionX,
      'position_y': positionY,
      'pos_y_m': positionY,
      'position_z': positionZ,
      'pos_z_m': positionZ,
      'orientation_heading': orientationHeading,
      'heading_deg': orientationHeading,
      'accel_x': accelX,
      'accel_x_mps2': accelX,
      'accel_y': accelY,
      'accel_y_mps2': accelY,
      'accel_z': accelZ,
      'accel_z_mps2': accelZ,
      'rot_rate_x': rotRateX,
      'gyro_x_dps': rotRateX,
      'rot_rate_y': rotRateY,
      'gyro_y_dps': rotRateY,
      'rot_rate_z': rotRateZ,
      'gyro_z_dps': rotRateZ,
      'transmission_gear': transmissionGear,
      'signal_light': signalLight,
      'steer_angle': steerAngle,
      'angle_deg': steerAngle,
      'steer_torque': steerTorque,
      'torque_nm': steerTorque,
      'pedal_accel': pedalAccel,
      'accel_pct': pedalAccel,
      'brake': brake,
      'brake_pct': brake,
      'number_of_objects': numberOfObjects,
      'objects': objects.map((DetectedObject item) => item.toJson()).toList(),
      'payload_crc_ok': payloadCrcOk,
      'payload_bytes_hex': payloadBytesHex,
      'created_ts': createdTs,
      'updated_ts': updatedTs,
    };
  }
}

class VehicleInfoHistoryResult {
  int totalCount;
  List<VehicleInfoHistory> items;

  VehicleInfoHistoryResult({
    this.totalCount = 0,
    this.items = const <VehicleInfoHistory>[],
  });

  VehicleInfoHistoryResult.fromJson(Map<String, dynamic> json)
      : totalCount = 0,
        items = <VehicleInfoHistory>[] {
    totalCount =
        _parseInt(json['totalCount'] ?? json['total_count'] ?? json['total']) ??
            0;
    final dynamic itemsRaw = json['items'];
    if (itemsRaw is List) {
      items = <VehicleInfoHistory>[];
      for (final dynamic element in itemsRaw) {
        if (element is Map) {
          try {
            items.add(VehicleInfoHistory.fromJson(
                Map<String, dynamic>.from(element)));
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
}
