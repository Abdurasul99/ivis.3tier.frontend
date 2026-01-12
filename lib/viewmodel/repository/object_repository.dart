import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/object_model.dart';
import 'base_repository.dart';

class ObjectRepository extends BaseRepository {
  String get apiServerHost => kApiServer;

  Uri buildUri(String path) => Uri.http(apiServerHost, path);

  int _toInteger(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  List<DetectedObject> _parseDetectedObjectList(dynamic node) {
    if (node is! List) return <DetectedObject>[];
    return node
        .whereType<Map>()
        .map((dynamic element) => DetectedObject.fromJson(Map<String, dynamic>.from(element as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> requestByVehicleInfoWithMeta({
    required int vehicleInfoId,
    int limit = 200,
    int offset = 0,
  }) async {
    final http.Response response = await http.post(
      buildUri('/api/detectedObjects/byVehicleInfo'),
      headers: getHeader(),
      body: jsonEncode(<String, dynamic>{
        'vehicle_info_id': vehicleInfoId,
        'limit': limit,
        'offset': offset,
      }),
    );

    return handleResponse(response, (json) {
      final dynamic body = json['body'];

      if (body is Map) {
        final List<DetectedObject> items = _parseDetectedObjectList(body['items']);
        final int totalCount = _toInteger(body['totalCount'] ?? body['total']);
        return <String, dynamic>{'items': items, 'totalCount': totalCount};
      }

      if (body is List) {
        final List<DetectedObject> items = _parseDetectedObjectList(body);
        return <String, dynamic>{'items': items, 'totalCount': 0};
      }

      return <String, dynamic>{'items': <DetectedObject>[], 'totalCount': 0};
    });
  }

  Future<Map<String, dynamic>> requestByInfraInfoWithMeta({
    required int infraInfoId,
    int limit = 200,
    int offset = 0,
  }) async {
    final http.Response response = await http.post(
      buildUri('/api/detectedObjects/byInfraInfo'),
      headers: getHeader(),
      body: jsonEncode(<String, dynamic>{
        'infra_info_id': infraInfoId,
        'limit': limit,
        'offset': offset,
      }),
    );

    return handleResponse(response, (json) {
      final dynamic body = json['body'];

      if (body is Map) {
        final List<DetectedObject> items = _parseDetectedObjectList(body['items']);
        final int totalCount = _toInteger(body['totalCount'] ?? body['total']);
        return <String, dynamic>{'items': items, 'totalCount': totalCount};
      }

      if (body is List) {
        final List<DetectedObject> items = _parseDetectedObjectList(body);
        return <String, dynamic>{'items': items, 'totalCount': 0};
      }

      return <String, dynamic>{'items': <DetectedObject>[], 'totalCount': 0};
    });
  }

  Future<List<DetectedObject>> requestByVehicleInfo({
    required int vehicleInfoId,
    int limit = 200,
    int offset = 0,
  }) async {
    final Map<String, dynamic> meta = await requestByVehicleInfoWithMeta(
      vehicleInfoId: vehicleInfoId,
      limit: limit,
      offset: offset,
    );
    final dynamic items = meta['items'];
    return items is List<DetectedObject> ? items : <DetectedObject>[];
  }

  Future<List<DetectedObject>> requestByInfraInfo({
    required int infraInfoId,
    int limit = 200,
    int offset = 0,
  }) async {
    final Map<String, dynamic> meta = await requestByInfraInfoWithMeta(
      infraInfoId: infraInfoId,
      limit: limit,
      offset: offset,
    );
    final dynamic items = meta['items'];
    return items is List<DetectedObject> ? items : <DetectedObject>[];
  }

  Future<List<DetectedObject>> requestHistory({
    String? from,
    String? to,
    int limit = 200,
    int offset = 0,
  }) async {
    final http.Response response = await http.post(
      buildUri('/api/detectedObjects/history'),
      headers: getHeader(),
      body: jsonEncode({
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'limit': limit,
        'offset': offset,
      }),
    );

    return handleResponse(response, (json) {
      final dynamic body = json['body'];
      if (body is Map) {
        return _parseDetectedObjectList(body['items']);
      }
      return _parseDetectedObjectList(body);
    });
  }
}
