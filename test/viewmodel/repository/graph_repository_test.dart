// ---- test/viewmodel/repository/graph_repository_test.dart ----
//
// GraphRepository 단위 테스트 – fetch()/getChartItems()
//  ✓ GraphModel 스키마(point/total/unit) 검증
//  ✓ FakeHttpClient 구현(필수 setter 포함)
//  ✓ 모든 주석은 한국어
// --------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/model/graph_model.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/graph_repository.dart';

//
// ─────────── Fake HTTP 구성요소 ───────────
//

/// 간단한 응답 컨테이너
class FakeHttpResponseData {
  final int statusCode;
  final List<int> bodyBytes;
  FakeHttpResponseData({required this.statusCode, required String body}) : bodyBytes = utf8.encode(body);
}

/// HttpHeaders 최소 구현 (forEach 필수)
class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void add(String name, Object? value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name.toLowerCase(), () => <String>[]).add(value.toString());

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = <String>[value.toString()];

  @override
  void clear() => _map.clear();

  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;

  @override
  void forEach(void Function(String name, List<String> values) action) => _map.forEach(action);

  /// 사용하지 않는 메서드들
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClientRequest – 필수 setter 포함
class FakeHttpClientRequest implements HttpClientRequest {
  final Uri _uri;
  final FakeHttpResponseData _data;
  final FakeHttpHeaders _headers = FakeHttpHeaders();

  FakeHttpClientRequest(this._uri, this._data);

  // 필수 프로퍼티/세터
  @override
  Uri get uri => _uri;
  @override
  String get method => 'GET';
  @override
  FakeHttpHeaders get headers => _headers;

  int _contentLength = 0;
  @override
  int get contentLength => _contentLength;
  @override
  set contentLength(int v) => _contentLength = v;

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = false;
  @override
  bool bufferOutput = false;

  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(_data);

  // 바디 전송 API (테스트에선 사용 안 함)
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? obj) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClientResponse – Stream 구현
class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final FakeHttpResponseData _data;
  FakeHttpClientResponse(this._data);

  @override
  int get statusCode => _data.statusCode;
  @override
  int get contentLength => _data.bodyBytes.length;
  @override
  FakeHttpHeaders get headers => FakeHttpHeaders();
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => '';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_data.bodyBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError ?? false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClient – openUrl 가로채기
class FakeHttpClient implements HttpClient {
  final Map<Uri, FakeHttpResponseData> _responses;
  FakeHttpClient(this._responses);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    final data = _responses[uri] ?? FakeHttpResponseData(statusCode: 404, body: 'Not found');
    debugPrint('FakeHttpClient.openUrl → $method $uri (status: ${data.statusCode})');
    return FakeHttpClientRequest(uri, data);
  }

  @override
  void close({bool force = false}) => debugPrint('FakeHttpClient.close(force: $force)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// HttpOverrides 로 주입
class TestHttpOverrides extends HttpOverrides {
  final Map<Uri, FakeHttpResponseData> responses;
  TestHttpOverrides(this.responses);
  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeHttpClient(responses);
}

/// 최소 UserController (토큰만 제공)
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'dummy';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

//
// ─────────── 실제 테스트 ───────────
//
void main() {
  late GraphRepository repo;

  setUpAll(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  group('GraphRepository 네트워크 호출', () {
    test('fetch() – 200 OK → GraphModel 반환', () async {
      // Arrange
      final body = {
        'points': [
          {'label': '2025-06-20', 'value': 10.5},
          {'label': '2025-06-21', 'value': 15.5},
        ],
        'total': 26.0,
        'unit': 'km',
      };
      final uri = Uri.http(kApiServer, '/api/chart', {
        'object_id': '1',
        'period': 'daily',
        'limit': '10',
        'metric': 'distance',
      });
      HttpOverrides.global = TestHttpOverrides({
        uri: FakeHttpResponseData(
          statusCode: 200,
          // handleResponse() 는 result 필드를 не ожидает
          body: jsonEncode({'body': body}),
        ),
      });
      repo = GraphRepository();

      // Act
      final result = await repo.fetch(1, 'daily', 10, 'distance');

      // Assert
      expect(result, isNotNull);
      expect(result!.points.length, 2);
      expect(result.total, 26.0);
      expect(result.unit, 'km');
    });

    test('fetch() – 500 → null', () async {
      final uri = Uri.http(kApiServer, '/api/chart', {
        'object_id': '1',
        'period': 'daily',
        'limit': '10',
        'metric': 'distance',
      });
      HttpOverrides.global = TestHttpOverrides({uri: FakeHttpResponseData(statusCode: 500, body: '')});
      repo = GraphRepository();

      final result = await repo.fetch(1, 'daily', 10, 'distance');
      expect(result, isNull);
    });

    test('getChartItems() – 200 OK → 3개', () async {
      final items = [
        {'date': '2025-06-20', 'distance': 1.0},
        {'date': '2025-06-21', 'distance': 2.5},
        {'date': '2025-06-22', 'distance': 3.3},
      ];
      final uri = Uri.http(kApiServer, '/api/chart/items', {'objectId': '5', 'period': 'weekly'});
      HttpOverrides.global = TestHttpOverrides({
        uri: FakeHttpResponseData(
          statusCode: 200,
          body: jsonEncode({'body': items}),
        ),
      });
      repo = GraphRepository();

      final result = await repo.getChartItems(5, 'weekly');
      expect(result.length, 3);
      expect(result.first.distance, closeTo(1.0, 0.001));
    });

    test('getChartItems() – 404 → 빈 리스트', () async {
      final uri = Uri.http(kApiServer, '/api/chart/items', {'objectId': '5', 'period': 'weekly'});
      HttpOverrides.global = TestHttpOverrides({uri: FakeHttpResponseData(statusCode: 404, body: '')});
      repo = GraphRepository();

      final result = await repo.getChartItems(5, 'weekly');
      expect(result, isEmpty);
    });
  });
}
