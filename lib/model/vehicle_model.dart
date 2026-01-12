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

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vehicleId: _parseInt(json['vehicle_id'] ?? json['id']),
      vehicleType: _parseString(json['vehicle_type'] ?? json['type']),
      make: _parseString(json['make'] ?? json['name']),
      modelName: _parseString(json['model'] ?? json['model_name'] ?? json['description']),
      state: _parseString(json['state']),
      createdTimestamp: _parseString(json['created_ts'] ?? json['created_at']),
      updatedTs: _parseString(json['updated_ts'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vehicle_id': vehicleId,
      'vehicle_type': vehicleType,
      'make': make,
      'model': modelName,
      'model_name': modelName,
      'state': state,
      'created_ts': createdTimestamp,
      'updated_ts': updatedTs,
      'created_at': createdTimestamp,
    };
  }

  dynamic get description => null;

  @override
  String toString() {
    return 'Vehicle{vehicleId: $vehicleId, vehicleType: $vehicleType, make: $make, '
        'modelName: $modelName, state: $state}';
  }
}
