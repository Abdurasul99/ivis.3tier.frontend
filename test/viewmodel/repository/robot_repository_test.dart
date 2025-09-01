// robot_repository_test.dart
// ──────────────────────────────────────────────────────────────
// RobotRepository 단위 테스트 – 디버그 로그 버전 (모든 테스트마다 출력)
//
// • 각 테스트 시작·끝에 debugPrint 추가.
// • 기존 성공 상태(모든 테스트 통과)는 그대로 유지.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'; // ← debugPrint
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/robot_repository.dart';
import 'package:fms/model/robot_model.dart';

// ──────────────────────────────────────────────────────────────
// ① Fake-HTTP 인프라 (변경 없음)
// ──────────────────────────────────────────────────────────────

class FakeHttpResponseData {
  final int statusCode;
  final Map<String, dynamic> bodyAsJson;
  const FakeHttpResponseData({required this.statusCode, required this.bodyAsJson});
}

class _MinimalHeaders implements HttpHeaders {
  final Map<String, List<String>> _store = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _store.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _store[name.toLowerCase()] = [value.toString()];
  @override
  void forEach(void Function(String, List<String>) f) => _store.forEach(f);
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class FakeHttpClientRequest implements HttpClientRequest {
  FakeHttpClientRequest(this._data, this._uri, this._method);
  final FakeHttpResponseData _data;
  final Uri _uri;
  final String _method;
  bool followRedirects = true;
  int maxRedirects = 5;
  bool persistentConnection = false;
  bool bufferOutput = false;
  int contentLength = 0;
  @override
  final HttpHeaders headers = _MinimalHeaders();

  @override
  Uri get uri => _uri;
  @override
  String get method => _method;

  @override
  void add(List<int> _) {}
  @override
  void addError(Object _, [StackTrace? __]) {}
  @override
  Future<void> addStream(Stream<List<int>> _) async {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? _) {}
  @override
  void writeAll(Iterable _, [String __ = '']) {}
  @override
  void writeCharCode(int _) {}
  @override
  void writeln([Object? _ = '']) {}
  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(_data);
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeHttpClientResponse(this._data) {
    _bytes = utf8.encode(jsonEncode(_data.bodyAsJson));
  }
  final FakeHttpResponseData _data;
  late final List<int> _bytes;

  @override
  int get statusCode => _data.statusCode;
  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => '';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpHeaders get headers => _MinimalHeaders();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([_bytes])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError ?? false);

  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class FakeHttpClient implements HttpClient {
  FakeHttpClient(this._map);
  final Map<Uri, FakeHttpResponseData> _map;

  Future<HttpClientRequest> _open(String m, Uri u) async {
    final data = _map[u];
    if (data == null) throw TestFailure('Fake 응답이 등록되지 않은 URI입니다: $u');
    return FakeHttpClientRequest(data, u, m);
  }

  @override
  Future<HttpClientRequest> openUrl(String m, Uri u) => _open(m, u);
  @override
  Future<HttpClientRequest> getUrl(Uri u) => _open('GET', u);
  @override
  Future<HttpClientRequest> postUrl(Uri u) => _open('POST', u);
  @override
  Future<HttpClientRequest> deleteUrl(Uri u) => _open('DELETE', u);
  @override
  Future<HttpClientRequest> putUrl(Uri u) => _open('PUT', u);
  @override
  Future<HttpClientRequest> patchUrl(Uri u) => _open('PATCH', u);
  @override
  Future<HttpClientRequest> headUrl(Uri u) => _open('HEAD', u);

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class TestHttpOverrides extends HttpOverrides {
  TestHttpOverrides(this._map);
  final Map<Uri, FakeHttpResponseData> _map;
  @override
  HttpClient createHttpClient(SecurityContext? _) => FakeHttpClient(_map);
}

// ──────────────────────────────────────────────────────────────
// ② FakeUserController
// ──────────────────────────────────────────────────────────────
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'unit-test-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ──────────────────────────────────────────────────────────────
// ③ 테스트
// ──────────────────────────────────────────────────────────────
void main() {
  late RobotRepository repo;

  const jsonOk = {
    'code': '0000',
    'body': {'affectedRows': 1}
  };
  const jsonTypes = {
    'code': '0000',
    'body': [
      {'id': 1, 'type_description': 'TypeA'},
      {'id': 2, 'type_description': 'TypeB'}
    ]
  };
  const jsonList = {
    'code': '0000',
    'body': [
      {'id': 10, 'name': 'Taro', 'serial': 'SN001', 'object_type_id': 1}
    ]
  };
  const jsonStatus = {
    'code': '0000',
    'body': [
      // battery 는 double 이어야 함
      {'id': 99, 'robot_status': 1, 'battery': 80.0, 'name': 'T-01'}
    ]
  };

  setUpAll(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  group('RobotRepository 네트워크 테스트 (디버그 포함)', () {
    test('requestRobotTypes() – 200 OK', () async {
      debugPrint('🚀 [requestRobotTypes] 시작');
      final uri = Uri.parse('http://$kApiServer/api/robot/types');
      HttpOverrides.global = TestHttpOverrides({uri: FakeHttpResponseData(statusCode: 200, bodyAsJson: jsonTypes)});

      repo = RobotRepository();
      final types = await repo.requestRobotTypes();
      debugPrint('✅ [requestRobotTypes] 결과: $types');
      expect(types, hasLength(2));
    });

    test('requestRobotList() – 200 OK', () async {
      debugPrint('🚀 [requestRobotList] 시작');
      final uri = Uri.parse('http://$kApiServer/api/robot/list?typeId=1');
      HttpOverrides.global = TestHttpOverrides({uri: FakeHttpResponseData(statusCode: 200, bodyAsJson: jsonList)});

      repo = RobotRepository();
      final list = await repo.requestRobotList(1);
      debugPrint('✅ [requestRobotList] 결과: $list');
      expect(list, hasLength(1));
    });

    test('requestAddRobot() – 200 OK ⇒ true', () async {
      debugPrint('🚀 [requestAddRobot] 시작');
      final uri = Uri.parse('http://$kApiServer/api/robot/add');
      HttpOverrides.global = TestHttpOverrides({uri: FakeHttpResponseData(statusCode: 200, bodyAsJson: jsonOk)});

      repo = RobotRepository();
      final ok = await repo.requestAddRobot({'serial': 'NEW'});
      debugPrint('✅ [requestAddRobot] 결과: $ok');
      expect(ok, isTrue);
    });

    test('Untact 중복 시리얼 ⇒ 409 false', () async {
      debugPrint('🚀 [duplicate serial] 시작');
      final uri = Uri.parse('http://$kApiServer/api/robot/add');
      HttpOverrides.global = TestHttpOverrides({
        uri: const FakeHttpResponseData(
          statusCode: 409,
          bodyAsJson: {'code': '409', 'body': {}},
        )
      });

      repo = RobotRepository();
      final ok = await repo.requestAddRobot({'serial': 'DUP'});
      debugPrint('✅ [duplicate serial] 결과: $ok');
      expect(ok, isFalse);
    });

    test('requestRobotStatusList() – 200 OK', () async {
      debugPrint('🚀 [requestRobotStatusList] 시작');
      final uri = Uri.parse('http://$kApiServer/api/robot/status?');
      HttpOverrides.global = TestHttpOverrides({uri: FakeHttpResponseData(statusCode: 200, bodyAsJson: jsonStatus)});

      repo = RobotRepository();
      final list = await repo.requestRobotStatusList();
      debugPrint('✅ [requestRobotStatusList] 결과: $list');
      expect(list, hasLength(1));
      expect(list.first.robotStatus, equals(1));
    });
  });
}
