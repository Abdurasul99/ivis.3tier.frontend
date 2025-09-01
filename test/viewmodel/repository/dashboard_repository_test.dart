//
// DashboardRepository 네트워크 레이어 단위 테스트
//  ├─ requestDashboardLayoutSetting()   (GET)
//  ├─ requestInsertDashboardLayoutSetting() (POST)
//  └─ requestDeleteDashboardLayoutSetting() (DELETE)
//
//  • 변수/메서드 이름을 축약하지 않는다.
// ────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/model/dashboard_model.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/dashboard_repository.dart';

//
// ────────────── 테스트용 HTTP 스텁 ──────────────
//

/// 가짜 HTTP 응답 데이터를 보관하는 구조체
class FakeHttpResponseData {
  final int statusCode;
  final List<int> bodyBytes;
  FakeHttpResponseData({
    required this.statusCode,
    required String body,
  }) : bodyBytes = utf8.encode(body);
}

/// HttpHeaders 최소 구현체
class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headersMap = <String, List<String>>{};

  @override
  void add(String name, Object? value, {bool preserveHeaderCase = false}) {
    final String key = name.toLowerCase();
    _headersMap.putIfAbsent(key, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headersMap[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  void clear() => _headersMap.clear();

  @override
  void forEach(void Function(String, List<String>) action) => _headersMap.forEach(action);

  // 그 외 메서드는 필요 없음
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClientRequest – HttpClientRequest 필수 구현
class FakeHttpClientRequest implements HttpClientRequest {
  final FakeHttpResponseData fakeHttpResponseData;
  final Uri requestUri;
  final FakeHttpHeaders fakeHttpHeaders = FakeHttpHeaders();

  FakeHttpClientRequest(this.fakeHttpResponseData, this.requestUri);

  // ── IOClient 가 직접 세팅하는 필드 ──────────────────────────
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = false;
  @override
  bool bufferOutput = false;
  @override
  int contentLength = 0;

  // encoding 은 null 이 불가 → non-nullable 로 수정
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding e) {}

  // ── Getter ────────────────────────────────────────────────
  @override
  HttpHeaders get headers => fakeHttpHeaders;
  @override
  Uri get uri => requestUri;
  @override
  String get method => 'GET';

  // ── 핵심: close() 구현 ─────────────────────────────────────
  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(fakeHttpResponseData);

  // 사용하지 않는 메서드/스트림 처리
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => Future.value();
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  Future<void> flush() => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClientResponse – 스트림 기반 응답
class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final FakeHttpResponseData fakeHttpResponseData;
  FakeHttpClientResponse(this.fakeHttpResponseData);

  @override
  int get statusCode => fakeHttpResponseData.statusCode;
  @override
  int get contentLength => fakeHttpResponseData.bodyBytes.length;
  @override
  HttpHeaders get headers => FakeHttpHeaders();
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => <RedirectInfo>[];
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
    return Stream<List<int>>.fromIterable(<List<int>>[fakeHttpResponseData.bodyBytes])
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError ?? false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClient – openUrl()/close() 구현
class FakeHttpClient implements HttpClient {
  final Map<Uri, FakeHttpResponseData> fakeResponses;
  FakeHttpClient(this.fakeResponses);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    final FakeHttpResponseData resp = fakeResponses[uri]!;
    debugPrint('FakeHttpClient.openUrl → $method $uri (status: ${resp.statusCode})');
    return FakeHttpClientRequest(resp, uri);
  }

  @override
  void close({bool force = false}) => debugPrint('FakeHttpClient.close(force: $force)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// HttpOverrides – FakeHttpClient 주입
class TestHttpOverrides extends HttpOverrides {
  final Map<Uri, FakeHttpResponseData> responses;
  TestHttpOverrides(this.responses);

  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeHttpClient(responses);
}

/// GetX용 최소 UserController
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'dummy-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

//
// ────────────── 실제 단위 테스트 ──────────────
//
void main() {
  late DashboardRepository dashboardRepositoryUnderTest;

  setUpAll(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  group('DashboardRepository 네트워크 호출', () {
    test('GET /setting/layout – 200 OK → 결과 1개', () async {
      debugPrint('\n[Arrange] 200 응답 설정');
      final Map<String, dynamic> fakeItemJson = <String, dynamic>{
        'title': 'Speed',
        'rowIndex': 0,
        'columnIndex': 0,
        'period': '',
        'displayMethod': '',
      };
      final String fakeBody = jsonEncode(<String, dynamic>{
        'body': <dynamic>[fakeItemJson]
      });
      final Uri requestUri = Uri.http(kApiServer, '/api/dashboard/setting/layout');
      HttpOverrides.global = TestHttpOverrides(<Uri, FakeHttpResponseData>{
        requestUri: FakeHttpResponseData(statusCode: 200, body: fakeBody),
      });

      dashboardRepositoryUnderTest = DashboardRepository();

      debugPrint('[Act] requestDashboardLayoutSetting() 호출');
      final List<LayoutSet> list = await dashboardRepositoryUnderTest.requestDashboardLayoutSetting();

      debugPrint('[Assert] 리스트 길이: ${list.length}');
      expect(list.length, 1);
      expect(list.first.title, 'Speed');
    });

    test('GET /setting/layout – 500 → 빈 리스트', () async {
      debugPrint('\n[Arrange] 500 응답 설정');
      final Uri uri = Uri.http(kApiServer, '/api/dashboard/setting/layout');
      HttpOverrides.global = TestHttpOverrides(<Uri, FakeHttpResponseData>{
        uri: FakeHttpResponseData(statusCode: 500, body: ''),
      });

      dashboardRepositoryUnderTest = DashboardRepository();

      debugPrint('[Act] requestDashboardLayoutSetting() 호출');
      final List<LayoutSet> list = await dashboardRepositoryUnderTest.requestDashboardLayoutSetting();

      debugPrint('[Assert] 빈 리스트 여부: ${list.isEmpty}');
      expect(list, isEmpty);
    });

    test('POST /setting/layout – 200 → true', () async {
      debugPrint('\n[Arrange] 200 응답 설정 (POST)');
      final Uri uri = Uri.http(kApiServer, '/api/dashboard/setting/layout');
      HttpOverrides.global = TestHttpOverrides(<Uri, FakeHttpResponseData>{
        uri: FakeHttpResponseData(statusCode: 200, body: '{"body":{}}'),
      });

      dashboardRepositoryUnderTest = DashboardRepository();

      debugPrint('[Act] requestInsertDashboardLayoutSetting() 호출');
      final bool ok = await dashboardRepositoryUnderTest.requestInsertDashboardLayoutSetting(
        <String, dynamic>{'title': 'Speed', 'rowIndex': '0', 'columnIndex': '0'},
      );

      debugPrint('[Assert] 성공 여부: $ok');
      expect(ok, isTrue);
    });

    test('POST /setting/layout – 500 → false', () async {
      debugPrint('\n[Arrange] 500 응답 설정 (POST)');
      final Uri uri = Uri.http(kApiServer, '/api/dashboard/setting/layout');
      HttpOverrides.global = TestHttpOverrides(<Uri, FakeHttpResponseData>{
        uri: FakeHttpResponseData(statusCode: 500, body: ''),
      });

      dashboardRepositoryUnderTest = DashboardRepository();

      debugPrint('[Act] requestInsertDashboardLayoutSetting() 호출');
      final bool ok = await dashboardRepositoryUnderTest.requestInsertDashboardLayoutSetting(<String, dynamic>{});

      debugPrint('[Assert] 실패 여부: ${!ok}');
      expect(ok, isFalse);
    });

    test('DELETE /setting/layout – 200 → true', () async {
      debugPrint('\n[Arrange] 200 응답 설정 (DELETE)');
      final Uri uri = Uri.http(kApiServer, '/api/dashboard/setting/layout');
      HttpOverrides.global = TestHttpOverrides(<Uri, FakeHttpResponseData>{
        uri: FakeHttpResponseData(statusCode: 200, body: '{"body":{}}'),
      });

      dashboardRepositoryUnderTest = DashboardRepository();

      debugPrint('[Act] requestDeleteDashboardLayoutSetting() 호출');
      final bool ok = await dashboardRepositoryUnderTest.requestDeleteDashboardLayoutSetting();

      debugPrint('[Assert] 성공 여부: $ok');
      expect(ok, isTrue);
    });

    test('DELETE /setting/layout – 404 → false', () async {
      debugPrint('\n[Arrange] 404 응답 설정 (DELETE)');
      final Uri uri = Uri.http(kApiServer, '/api/dashboard/setting/layout');
      HttpOverrides.global = TestHttpOverrides(<Uri, FakeHttpResponseData>{
        uri: FakeHttpResponseData(statusCode: 404, body: ''),
      });

      dashboardRepositoryUnderTest = DashboardRepository();

      debugPrint('[Act] requestDeleteDashboardLayoutSetting() 호출');
      final bool ok = await dashboardRepositoryUnderTest.requestDeleteDashboardLayoutSetting();

      debugPrint('[Assert] 실패 여부: ${!ok}');
      expect(ok, isFalse);
    });
  });
}
