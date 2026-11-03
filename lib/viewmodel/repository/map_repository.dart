import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../controller/user_controller.dart';

/// The HTTP calls of the map (same endpoints and request bodies as infra_vehicle_map.dart).
/// Device numbers are sent as they are: 0 is a real device (spec uint8 0–255).
class MapRepository {
  MapRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) {
    final String server = kApiServer;
    if (server.startsWith('http://') || server.startsWith('https://')) {
      final Uri parsed = Uri.parse(server);
      final String base = parsed.path.endsWith('/')
          ? parsed.path.substring(0, parsed.path.length - 1)
          : parsed.path;
      return parsed.replace(path: '$base$path');
    }
    if (kIsWeb && Uri.base.scheme == 'https') {
      return Uri.https(server, path);
    }
    return Uri.http(server, path);
  }

  Map<String, String> _headers() {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (Get.isRegistered<UserController>()) {
      final String token = Get.find<UserController>().accessToken ?? '';
      if (token.isNotEmpty) {
        headers['x-access-token'] = token;
      }
    }
    return headers;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return _client.post(_uri(path), headers: _headers(), body: jsonEncode(body));
  }

  Future<http.Response> requestGeocode(double latitude, double longitude) =>
      _post('/api/activity/geocode', <String, dynamic>{'latitude': latitude, 'longitude': longitude});

  Future<http.Response> requestVehicleObjects(Map<String, dynamic> params) =>
      _post('/api/detectedObjects/byVehicleInfo', params);

  Future<http.Response> requestVehicleObjectsBatch(List<int> vehicleIds) => _post(
        '/api/detectedObjects/byMultipleVehicles',
        <String, dynamic>{'vehicle_ids': vehicleIds, 'latest_only': true},
      );

  Future<http.Response> requestInfraObjects(int infraId) => _post(
        '/api/detectedObjects/byInfraInfo',
        <String, dynamic>{'infra_id': infraId, 'limit': 500, 'offset': 0},
      );

  Future<http.Response> requestVehicleStatus(int limit) =>
      _post('/api/vehicle/status', <String, dynamic>{'limit': limit, 'offset': 0});

  Future<http.Response> requestInfraStatus(int limit) => _post(
        '/api/infra/status',
        <String, dynamic>{'limit': limit, 'offset': 0, 'include_objects': false},
      );
}
