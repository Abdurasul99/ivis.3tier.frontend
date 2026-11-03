import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/repository/map_repository.dart';

void main() {
  late MapRepository repository;
  late List<http.Request> requests;

  setUp(() {
    Get.testMode = true;
    requests = <http.Request>[];
    repository = MapRepository(client: MockClient((request) async {
      requests.add(request);
      return http.Response('{"body":[]}', 200);
    }));
  });

  tearDown(() => Get.reset());

  test('geocode keeps the existing endpoint and coordinates', () async {
    await repository.requestGeocode(35.8, 128.6);
    expect(requests.single.url.path, '/api/activity/geocode');
    expect(jsonDecode(requests.single.body), <String, dynamic>{'latitude': 35.8, 'longitude': 128.6});
  });

  test('vehicle object lookup preserves device zero and the packet timestamp', () async {
    final params = <String, dynamic>{'vehicle_id': 0, 'latest_only': true, 'vehicle_time_stamp_ms': 1000};
    await repository.requestVehicleObjects(params);
    expect(requests.single.url.path, '/api/detectedObjects/byVehicleInfo');
    expect(jsonDecode(requests.single.body), params);
  });

  test('batch lookup keeps all requested device IDs', () async {
    await repository.requestVehicleObjectsBatch(<int>[0, 201]);
    expect(requests.single.url.path, '/api/detectedObjects/byMultipleVehicles');
    expect(jsonDecode(requests.single.body), <String, dynamic>{'vehicle_ids': <int>[0, 201], 'latest_only': true});
  });

  test('infra object lookup preserves its pagination', () async {
    await repository.requestInfraObjects(0);
    expect(requests.single.url.path, '/api/detectedObjects/byInfraInfo');
    expect(jsonDecode(requests.single.body), <String, dynamic>{'infra_id': 0, 'limit': 500, 'offset': 0});
  });

  test('status requests preserve their independent limits and object option', () async {
    await repository.requestVehicleStatus(200);
    await repository.requestInfraStatus(300);
    expect(requests[0].url.path, '/api/vehicle/status');
    expect(jsonDecode(requests[0].body), <String, dynamic>{'limit': 200, 'offset': 0});
    expect(requests[1].url.path, '/api/infra/status');
    expect(jsonDecode(requests[1].body), <String, dynamic>{'limit': 300, 'offset': 0, 'include_objects': false});
  });

  test('sends the session token when the user controller exists', () async {
    final user = Get.put(UserController());
    user.accessTokenForTest = 'map-test-token';
    await repository.requestVehicleStatus(1);
    expect(requests.single.headers['x-access-token'], 'map-test-token');
  });

  test('a missing session controller still permits the existing anonymous request', () async {
    await repository.requestVehicleStatus(1);
    expect(requests.single.headers.containsKey('x-access-token'), isFalse);
  });
}
