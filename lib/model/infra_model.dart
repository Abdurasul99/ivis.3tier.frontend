class Message {
  int? id;
  int? vehicleId;
  int? infraId;
  int? historyId;
  int? infraInfoId;
  String? changedAt;

  int? msgSeq;
  int? msgLength;

  int? timeStampMilliseconds;
  String? timeStampIso8601;

  String? navsat;

  double? positionXMeters;
  double? positionYMeters;
  double? positionZMeters;

  double? headingDegrees;

  double? speedMetersPerSecond;
  double? speedKilometersPerHour;

  double? accelerationXMps2;
  double? accelerationYMps2;
  double? accelerationZMps2;

  double? gyroXDps;
  double? gyroYDps;
  double? gyroZDps;

  double? steeringAngleDegrees;
  double? steeringTorqueNewtonMeters;

  double? acceleratorPedalPercent;
  double? brakePedalPercent;

  int? transmissionGear;
  int? signalLight;

  int? numberOfObjects;

  String? createdAt;
  String? updatedTs;

  List<dynamic>? objects;

  Message({
    this.id,
    this.vehicleId,
    this.infraId,
    this.historyId,
    this.infraInfoId,
    this.changedAt,
    this.msgSeq,
    this.msgLength,
    this.timeStampMilliseconds,
    this.timeStampIso8601,
    this.navsat,
    this.positionXMeters,
    this.positionYMeters,
    this.positionZMeters,
    this.headingDegrees,
    this.speedMetersPerSecond,
    this.speedKilometersPerHour,
    this.accelerationXMps2,
    this.accelerationYMps2,
    this.accelerationZMps2,
    this.gyroXDps,
    this.gyroYDps,
    this.gyroZDps,
    this.steeringAngleDegrees,
    this.steeringTorqueNewtonMeters,
    this.acceleratorPedalPercent,
    this.brakePedalPercent,
    this.transmissionGear,
    this.signalLight,
    this.numberOfObjects,
    this.createdAt,
    this.updatedTs,
    this.objects,
  });

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return double.tryParse(value.toString());
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

  static String? _millisecondsToIso8601(int? milliseconds) {
    if (milliseconds == null) return null;
    try {
      final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
      return dateTime.toIso8601String();
    } catch (_) {
      return null;
    }
  }

  void _autoFillSpeeds() {
    if (speedMetersPerSecond == null && speedKilometersPerHour != null) {
      speedMetersPerSecond = speedKilometersPerHour! / 3.6;
    } else if (speedKilometersPerHour == null && speedMetersPerSecond != null) {
      speedKilometersPerHour = speedMetersPerSecond! * 3.6;
    }
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final int? ms = _parseInt(
      json['time_stamp_ms'] ?? json['timestamp_ms'] ?? json['timeStampMs'] ?? json['time_stamp'] ?? json['sent_ts'],
    );

    final double? kph = _parseDouble(
      json['kph'] ?? json['velocity_kph'],
    );

    final double? mps = _parseDouble(
      json['mps'] ?? json['speed_mps'] ?? json['velocity_mps'],
    );

    final Message message = Message(
      id: _parseInt(
        json['id'] ??
            json['vehicle_info_id'] ??
            json['infra_info_id'] ??
            json['detected_object_id'] ??
            json['raw_id'] ??
            json['message_id'],
      ),
      vehicleId: _parseInt(json['vehicle_id']),
      infraId: _parseInt(json['infra_id']),
      historyId: _parseInt(json['history_id']),
      infraInfoId: _parseInt(json['infra_info_id']),
      changedAt: _parseString(json['changed_at']),
      msgSeq: _parseInt(json['msg_seq']),
      msgLength: _parseInt(json['msg_length']),
      timeStampMilliseconds: ms,
      timeStampIso8601: _millisecondsToIso8601(ms),
      navsat: _parseString(json['navsat'] ?? json['nav_sat']),
      positionXMeters: _parseDouble(json['pos_x_m'] ?? json['position_x']),
      positionYMeters: _parseDouble(json['pos_y_m'] ?? json['position_y']),
      positionZMeters: _parseDouble(json['pos_z_m'] ?? json['position_z']),
      headingDegrees: _parseDouble(
        json['heading_deg'] ?? json['heading'] ?? json['orientation_heading'] ?? json['yaw_deg'],
      ),
      speedMetersPerSecond: mps,
      speedKilometersPerHour: kph,
      accelerationXMps2: _parseDouble(json['accel_x_mps2'] ?? json['accel_x']),
      accelerationYMps2: _parseDouble(json['accel_y_mps2'] ?? json['accel_y']),
      accelerationZMps2: _parseDouble(json['accel_z_mps2'] ?? json['accel_z']),
      gyroXDps: _parseDouble(json['gyro_x_dps'] ?? json['rot_rate_x']),
      gyroYDps: _parseDouble(json['gyro_y_dps'] ?? json['rot_rate_y']),
      gyroZDps: _parseDouble(json['gyro_z_dps'] ?? json['rot_rate_z']),
      steeringAngleDegrees: _parseDouble(json['angle_deg'] ?? json['steer_angle']),
      steeringTorqueNewtonMeters: _parseDouble(json['torque_nm'] ?? json['steer_torque']),
      acceleratorPedalPercent: _parseDouble(json['accel_pct'] ?? json['pedal_accel']),
      brakePedalPercent: _parseDouble(json['brake_pct'] ?? json['brake']),
      transmissionGear: _parseInt(json['transmission_gear']),
      signalLight: _parseInt(json['signal_light']),
      numberOfObjects: _parseInt(json['number_of_objects']),
      createdAt: _parseString(json['created_ts'] ?? json['created_at']),
      updatedTs: _parseString(json['updated_ts'] ?? json['updated_at']),
      objects: json['objects'] is List ? (json['objects'] as List<dynamic>) : null,
    );

    message._autoFillSpeeds();
    return message;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};

    void put(String key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    put('id', id);
    put('vehicle_id', vehicleId);
    put('infra_id', infraId);
    put('history_id', historyId);
    put('infra_info_id', infraInfoId);
    put('changed_at', changedAt);

    put('msg_seq', msgSeq);
    put('msg_length', msgLength);

    put('time_stamp_ms', timeStampMilliseconds);
    put('time_stamp', timeStampMilliseconds);
    put('time_stamp_iso8601', timeStampIso8601);

    put('navsat', navsat);

    put('pos_x_m', positionXMeters);
    put('pos_y_m', positionYMeters);
    put('pos_z_m', positionZMeters);

    put('position_x', positionXMeters);
    put('position_y', positionYMeters);
    put('position_z', positionZMeters);

    put('heading_deg', headingDegrees);
    put('orientation_heading', headingDegrees);

    put('mps', speedMetersPerSecond);
    put('kph', speedKilometersPerHour);

    put('velocity_mps', speedMetersPerSecond);
    put('velocity_kph', speedKilometersPerHour);

    put('accel_x_mps2', accelerationXMps2);
    put('accel_y_mps2', accelerationYMps2);
    put('accel_z_mps2', accelerationZMps2);

    put('accel_x', accelerationXMps2);
    put('accel_y', accelerationYMps2);
    put('accel_z', accelerationZMps2);

    put('gyro_x_dps', gyroXDps);
    put('gyro_y_dps', gyroYDps);
    put('gyro_z_dps', gyroZDps);

    put('rot_rate_x', gyroXDps);
    put('rot_rate_y', gyroYDps);
    put('rot_rate_z', gyroZDps);

    put('angle_deg', steeringAngleDegrees);
    put('torque_nm', steeringTorqueNewtonMeters);

    put('steer_angle', steeringAngleDegrees);
    put('steer_torque', steeringTorqueNewtonMeters);

    put('accel_pct', acceleratorPedalPercent);
    put('brake_pct', brakePedalPercent);

    put('pedal_accel', acceleratorPedalPercent);
    put('brake', brakePedalPercent);

    put('transmission_gear', transmissionGear);
    put('signal_light', signalLight);

    put('number_of_objects', numberOfObjects);

    put('created_ts', createdAt);
    put('updated_ts', updatedTs);

    if (objects != null) {
      map['objects'] = objects;
    }

    return map;
  }
}
