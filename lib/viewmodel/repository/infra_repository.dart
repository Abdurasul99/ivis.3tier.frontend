import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/infra_model.dart';
import '../../viewmodel/controller/user_controller.dart';

class InfraRepository {
  String get apiServerHost => kApiServer;

  Uri buildUri(String path) {
    return Uri.http(apiServerHost, path);
  }

  Map<String, String> buildHeaders() {
    String accessToken = '';
    try {
      accessToken = Get.find<UserController>().accessToken ?? '';
    } catch (_) {
      accessToken = '';
    }

    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (accessToken.isNotEmpty) {
      headers['x-access-token'] = accessToken;
    }

    return headers;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  List<Message> _parseMessageList(dynamic node) {
    if (node is! List) return <Message>[];
    final List<Message> result = <Message>[];
    for (final dynamic element in node) {
      if (element is Map) {
        try {
          result.add(Message.fromJson(Map<String, dynamic>.from(element as Map)));
        } catch (_) {}
      }
    }
    return result;
  }

  Map<String, dynamic> _decodeJsonBody(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<List<int>> requestInfraIdentifiers() async {
    final Uri uri = buildUri('/api/infra/identifiers');
    final Map<String, dynamic> payload = <String, dynamic>{};

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        return <int>[];
      }

      final Map<String, dynamic> decoded = _decodeJsonBody(response);

      dynamic body = decoded['body'];
      if (body == null) body = decoded;

      if (body is List) {
        final List<int> ids = <int>[];
        for (final dynamic element in body) {
          final int value = _toInt(element);
          if (value > 0) ids.add(value);
        }
        return ids;
      }

      if (body is Map) {
        final Map<String, dynamic> mapBody = Map<String, dynamic>.from(body as Map);
        final dynamic items = mapBody['items'] ?? mapBody['infra_ids'] ?? mapBody['ids'];
        if (items is List) {
          final List<int> ids = <int>[];
          for (final dynamic element in items) {
            final int value = _toInt(element);
            if (value > 0) ids.add(value);
          }
          return ids;
        }
      }

      return <int>[];
    } catch (_) {
      return <int>[];
    }
  }

  Future<Message?> requestLatestVehicle(int vehicleId) async {
    final Uri uri = buildUri('/api/vehicle/getById');
    final Map<String, dynamic> payload = <String, dynamic>{
      'vehicle_id': vehicleId,
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final dynamic body = decoded['body'];
      if (body is! Map<String, dynamic>) return null;

      try {
        return Message.fromJson(body);
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<Message?> requestLatestInfra(int infraId) async {
    final Uri uri = buildUri('/api/infra/latest');
    final Map<String, dynamic> payload = <String, dynamic>{
      'infra_id': infraId,
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final dynamic body = decoded['body'];
      if (body is! Map<String, dynamic>) return null;

      try {
        return Message.fromJson(body);
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> requestHistoryVehicleWithMeta({
    int? vehicleId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
  }) async {
    final Uri uri = buildUri('/api/vehicle/history');

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (fromEpochMs != null) 'from': fromEpochMs,
      if (toEpochMs != null) 'to': toEpochMs,
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
      }

      final Map<String, dynamic> decoded = _decodeJsonBody(response);
      dynamic body = decoded['body'];
      if (body == null) body = decoded;

      if (body is Map) {
        final Map<String, dynamic> mapBody = Map<String, dynamic>.from(body as Map);
        final List<Message> items = _parseMessageList(mapBody['items']);
        final int totalCount = _toInt(mapBody['totalCount'] ?? mapBody['total']);
        return <String, dynamic>{'items': items, 'totalCount': totalCount};
      }

      if (body is List) {
        final List<Message> items = _parseMessageList(body);
        return <String, dynamic>{'items': items, 'totalCount': 0};
      }

      return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
    } catch (_) {
      return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
    }
  }

  Future<Map<String, dynamic>> requestHistoryInfraWithMeta({
    int? infraId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
  }) async {
    final Uri uri = buildUri('/api/infra/history');

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (infraId != null) 'infra_id': infraId,
      if (fromEpochMs != null) 'from': fromEpochMs,
      if (toEpochMs != null) 'to': toEpochMs,
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
      }

      final Map<String, dynamic> decoded = _decodeJsonBody(response);
      dynamic body = decoded['body'];
      if (body == null) body = decoded;

      if (body is Map) {
        final Map<String, dynamic> mapBody = Map<String, dynamic>.from(body as Map);
        final List<Message> items = _parseMessageList(mapBody['items']);
        final int totalCount = _toInt(mapBody['totalCount'] ?? mapBody['total']);
        return <String, dynamic>{'items': items, 'totalCount': totalCount};
      }

      if (body is List) {
        final List<Message> items = _parseMessageList(body);
        return <String, dynamic>{'items': items, 'totalCount': 0};
      }

      return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
    } catch (_) {
      return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
    }
  }
}
