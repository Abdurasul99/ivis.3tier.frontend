import 'object_model.dart';

class InfraInfo {
  int? id;
  int? infraId;
  int? msgId;
  int? msgSeq;
  int? msgLength;
  int? timeStamp;
  int? timeStampMs;
  int? numberOfObjects;
  bool? payloadCrcOk;
  String? payloadBytesHex;
  String? createdTs;
  String? updatedTs;

  InfraInfo({
    this.id,
    this.infraId,
    this.msgId,
    this.msgSeq,
    this.msgLength,
    this.timeStamp,
    this.timeStampMs,
    this.numberOfObjects,
    this.payloadCrcOk,
    this.payloadBytesHex,
    this.createdTs,
    this.updatedTs,
  });

  InfraInfo.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    infraId = _parseInt(json['infra_id']);
    msgId = _parseInt(json['msg_id']);
    msgSeq = _parseInt(json['msg_seq']);
    msgLength = _parseInt(json['msg_length']);
    timeStamp = _parseInt(json['time_stamp']);
    timeStampMs = _parseInt(json['time_stamp_ms']);
    numberOfObjects = _parseInt(json['number_of_objects']);
    payloadCrcOk = _parseBool(json['payload_crc_ok']);
    payloadBytesHex = _parseString(json['payload_bytes_hex']);
    createdTs = _parseString(json['created_ts'] ?? json['created_at']);
    updatedTs = _parseString(json['updated_ts'] ?? json['updated_at']);

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
      'infra_id': infraId,
      'msg_id': msgId,
      'msg_seq': msgSeq,
      'msg_length': msgLength,
      'time_stamp': timeStamp,
      'time_stamp_ms': timeStampMs,
      'number_of_objects': numberOfObjects,
      'payload_crc_ok': payloadCrcOk,
      'payload_bytes_hex': payloadBytesHex,
      'created_ts': createdTs,
      'updated_ts': updatedTs,
    };
  }
}

class InfraInfoResult {
  int totalCount;
  List<InfraInfo> items;

  InfraInfoResult({
    this.totalCount = 0,
    this.items = const <InfraInfo>[],
  });

  InfraInfoResult.fromJson(Map<String, dynamic> json)
      : totalCount = 0,
        items = <InfraInfo>[] {
    totalCount =
        _parseInt(json['totalCount'] ?? json['total_count'] ?? json['total']) ??
            0;
    final dynamic itemsRaw = json['items'];
    if (itemsRaw is List) {
      items = <InfraInfo>[];
      for (final dynamic element in itemsRaw) {
        if (element is Map) {
          try {
            items.add(InfraInfo.fromJson(Map<String, dynamic>.from(element)));
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

class InfraInfoHistory {
  int? historyId;
  int? infraInfoId;
  int? infraId;
  String? changedAt;
  int? msgId;
  int? msgSeq;
  int? msgLength;
  int? timeStamp;
  int? timeStampMs;
  int? numberOfObjects;
  List<DetectedObject> objects = const <DetectedObject>[];
  bool? payloadCrcOk;
  String? payloadBytesHex;
  String? createdTs;
  String? updatedTs;

  InfraInfoHistory({
    this.historyId,
    this.infraInfoId,
    this.infraId,
    this.changedAt,
    this.msgId,
    this.msgSeq,
    this.msgLength,
    this.timeStamp,
    this.timeStampMs,
    this.numberOfObjects,
    this.objects = const <DetectedObject>[],
    this.payloadCrcOk,
    this.payloadBytesHex,
    this.createdTs,
    this.updatedTs,
  });

  InfraInfoHistory.fromJson(Map<String, dynamic> json) {
    historyId = _parseInt(json['history_id']);
    infraInfoId = _parseInt(json['infra_info_id']);
    infraId = _parseInt(json['infra_id']);
    changedAt = _parseString(json['changed_at']);
    msgId = _parseInt(json['msg_id']);
    msgSeq = _parseInt(json['msg_seq']);
    msgLength = _parseInt(json['msg_length']);
    timeStamp = _parseInt(json['time_stamp']);
    timeStampMs = _parseInt(json['time_stamp_ms']);
    numberOfObjects = _parseInt(json['number_of_objects']);
    objects = _parseObjects(
        json['objects'] ?? json['detected_objects'] ?? json['detectedObjects']);
    payloadCrcOk = _parseBool(json['payload_crc_ok']);
    payloadBytesHex = _parseString(json['payload_bytes_hex']);
    createdTs = _parseString(json['created_ts'] ?? json['created_at']);
    updatedTs = _parseString(json['updated_ts'] ?? json['updated_at']);

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
      'infra_info_id': infraInfoId,
      'infra_id': infraId,
      'changed_at': changedAt,
      'msg_id': msgId,
      'msg_seq': msgSeq,
      'msg_length': msgLength,
      'time_stamp': timeStamp,
      'time_stamp_ms': timeStampMs,
      'number_of_objects': numberOfObjects,
      'objects': objects.map((DetectedObject item) => item.toJson()).toList(),
      'payload_crc_ok': payloadCrcOk,
      'payload_bytes_hex': payloadBytesHex,
      'created_ts': createdTs,
      'updated_ts': updatedTs,
    };
  }
}

class InfraInfoHistoryResult {
  int totalCount;
  List<InfraInfoHistory> items;

  InfraInfoHistoryResult({
    this.totalCount = 0,
    this.items = const <InfraInfoHistory>[],
  });

  InfraInfoHistoryResult.fromJson(Map<String, dynamic> json)
      : totalCount = 0,
        items = <InfraInfoHistory>[] {
    totalCount =
        _parseInt(json['totalCount'] ?? json['total_count'] ?? json['total']) ??
            0;
    final dynamic itemsRaw = json['items'];
    if (itemsRaw is List) {
      items = <InfraInfoHistory>[];
      for (final dynamic element in itemsRaw) {
        if (element is Map) {
          try {
            items.add(
                InfraInfoHistory.fromJson(Map<String, dynamic>.from(element)));
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
