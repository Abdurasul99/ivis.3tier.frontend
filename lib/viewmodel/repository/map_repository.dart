import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../controller/user_controller.dart';
import 'base_repository.dart';

/// The HTTP calls of the map (same endpoints and request bodies as infra_vehicle_map.dart).
/// Device numbers are sent as they are: 0 is a real device (spec uint8 0–255).
/// Every call goes through the shared 401 refresh-and-retry helper and has its own timeout.
class MapRepository extends BaseRepository {
  /// [client] is for tests; by default the shared top-level http client is used.
  MapRepository({http.Client? client}) : _client = client;

  final http.Client? _client;

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

  Future<http.Response> _post(String path, Map<String, dynamic> body, Duration timeout) {
    final Uri uri = buildApiUri(path);
    final String encoded = jsonEncode(body);
    final http.Client? client = _client;

    // Headers are rebuilt on each send so the retry carries the refreshed token.
    Future<http.Response> send(bool _) {
      final Future<http.Response> request = client != null
          ? client.post(uri, headers: _headers(), body: encoded)
          : http.post(uri, headers: _headers(), body: encoded);
      return request.timeout(timeout);
    }

    if (!Get.isRegistered<UserController>()) return send(false);
    return sendAuthorized(send);
  }

  Future<http.Response> requestGeocode(double latitude, double longitude) => _post(
        '/api/activity/geocode',
        <String, dynamic>{'latitude': latitude, 'longitude': longitude},
        const Duration(seconds: 5),
      );

  Future<http.Response> requestVehicleObjects(Map<String, dynamic> params) =>
      _post('/api/detectedObjects/byVehicleInfo', params, requestTimeout);

  Future<http.Response> requestVehicleObjectsBatch(List<int> vehicleIds) => _post(
        '/api/detectedObjects/byMultipleVehicles',
        <String, dynamic>{'vehicle_ids': vehicleIds, 'latest_only': true},
        const Duration(seconds: 8),
      );

  Future<http.Response> requestInfraObjects(int infraId) => _post(
        '/api/detectedObjects/byInfraInfo',
        <String, dynamic>{'infra_id': infraId, 'limit': 500, 'offset': 0},
        const Duration(seconds: 5),
      );

  Future<http.Response> requestVehicleStatus(int limit) => _post(
        '/api/vehicle/status',
        <String, dynamic>{'limit': limit, 'offset': 0},
        const Duration(seconds: 3),
      );

  Future<http.Response> requestInfraStatus(int limit) => _post(
        '/api/infra/status',
        <String, dynamic>{'limit': limit, 'offset': 0, 'include_objects': false},
        const Duration(seconds: 5),
      );
}
