import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/vehicle_model.dart';
import '../../viewmodel/controller/user_controller.dart';

class VehicleRepository {
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

  Future<List<Vehicle>> requestVehicleList() async {
    final Uri uri = buildUri('/api/vehicle/list');
    final Map<String, dynamic> payload = <String, dynamic>{};

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return <Vehicle>[];
      }
      if (response.statusCode != 200) {
        return <Vehicle>[];
      }

      final dynamic decoded = jsonDecode(response.body);

      List<dynamic> rawList;
      if (decoded is Map<String, dynamic> && decoded['body'] is List<dynamic>) {
        rawList = decoded['body'] as List<dynamic>;
      } else if (decoded is List<dynamic>) {
        rawList = decoded;
      } else {
        rawList = const <dynamic>[];
      }

      final List<Vehicle> result = <Vehicle>[];
      for (final dynamic element in rawList) {
        if (element is Map) {
          try {
            final Map<String, dynamic> m = Map<String, dynamic>.from(element as Map);
            result.add(Vehicle.fromJson(m));
          } catch (_) {}
        }
      }

      return result;
    } catch (_) {
      return <Vehicle>[];
    }
  }

  Future<Vehicle?> getVehicleById(int vehicleId) async {
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

      if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404) {
        return null;
      }
      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic body = decoded['body'];
      if (body is! Map<String, dynamic>) {
        return null;
      }

      try {
        return Vehicle.fromJson(body);
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<List<Vehicle>> requestVehicleHistory({
    required int vehicleId,
    String? fromIsoString,
    String? toIsoString,
    int limit = 500,
    int offset = 0,
  }) async {
    final Uri uri = buildUri('/api/vehicle/history');
    final Map<String, dynamic> payload = <String, dynamic>{
      'vehicle_id': vehicleId,
      'from': fromIsoString,
      'to': toIsoString,
      'limit': limit,
      'offset': offset,
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: buildHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return <Vehicle>[];
      }
      if (response.statusCode != 200) {
        return <Vehicle>[];
      }

      final dynamic decoded = jsonDecode(response.body);

      List<dynamic> rawList;
      if (decoded is Map<String, dynamic> && decoded['body'] is List<dynamic>) {
        rawList = decoded['body'] as List<dynamic>;
      } else if (decoded is List<dynamic>) {
        rawList = decoded;
      } else {
        rawList = const <dynamic>[];
      }

      final List<Vehicle> result = <Vehicle>[];
      for (final dynamic element in rawList) {
        if (element is Map) {
          try {
            final Map<String, dynamic> m = Map<String, dynamic>.from(element as Map);
            result.add(Vehicle.fromJson(m));
          } catch (_) {}
        }
      }

      return result;
    } catch (_) {
      return <Vehicle>[];
    }
  }
}
