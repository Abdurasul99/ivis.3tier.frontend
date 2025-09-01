// test/viewmodel/repository/log_repository_test.dart
//
// LogRepository.requestLogList() 단위 테스트
// ──────────────────────────────────────────────────────────
// • HTTP 200  → StatusHistoryList 반환
// • HTTP 500  → null 반환
// • HTTP 404  → null 반환
// 모든 주석은 한국어, 변수·메서드 이름은 풀네임 사용
// ──────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/viewmodel/repository/log_repository.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';

//
// ────────── 더미 JSON (모델 구조에 맞춰 필요 시 수정) ──────────
//
const String _dummyJsonBody = '{"body":{"totalCount":1,"list":[{"status":"idle","time":"2025-01-01T07:00:00Z"}]}}';

//
// ────────── HTTP 스텁 클래스 ──────────
//

/// statusCode + bodyString 을 보관
class FakeHttpResponseData {
  final int statusCode;
  final List<int> bodyBytes;
  FakeHttpResponseData({required this.statusCode, required String bodyString}) : bodyBytes = utf8.encode(bodyString);
}

/// 최소 HttpHeaders 구현
class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = <String, List<String>>{};

  @override
  void add(String name, Object? value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name.toLowerCase(), () => <String>[]).add(value.toString());

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = <String>[value.toString()];

  @override
  void clear() => _map.clear();

  @override
  void forEach(void Function(String name, List<String> values) action) => _map.forEach(action);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// HttpClientRequest 대체
class FakeHttpClientRequest implements HttpClientRequest {
  final FakeHttpResponseData fakeResponse;
  final Uri requestUri;
  final FakeHttpHeaders requestHeaders = FakeHttpHeaders();

  FakeHttpClientRequest(this.fakeResponse, this.requestUri);

  // 패키지:http 가 사용하는 필드/세터
  @override
  bool followRedirects = true;
  @override
  bool persistentConnection = false;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = 0;
  @override
  bool bufferOutput = false;

  @override
  HttpHeaders get headers => requestHeaders;
  @override
  String get method => 'GET';
  @override
  Uri get uri => requestUri;

  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(fakeResponse);

  // 사용하지 않는 쓰기 계열 메서드
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  Future<void> flush() async {}
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FakeHttpClientResponse: package:http 가 요구하는 모든 getter 포함
class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final FakeHttpResponseData fakeResponse;
  FakeHttpClientResponse(this.fakeResponse);

  @override
  int get statusCode => fakeResponse.statusCode;
  @override
  int get contentLength => fakeResponse.bodyBytes.length;
  @override
  HttpHeaders get headers => FakeHttpHeaders();

  // 추가 getter (isRedirect / redirects / persistentConnection / reasonPhrase)
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
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[fakeResponse.bodyBytes])
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// URL → FakeHttpResponseData 매핑 후 응답
class FakeHttpClient implements HttpClient {
  final Map<Uri, FakeHttpResponseData> responseTable;
  FakeHttpClient(this.responseTable);

  @override
  Future<HttpClientRequest> openUrl(String httpMethod, Uri url) async {
    final FakeHttpResponseData? hit = responseTable[url];
    if (hit == null) throw StateError('정의되지 않은 URL: $url');
    debugPrint('FakeClient → $httpMethod $url (status ${hit.statusCode})');
    return FakeHttpClientRequest(hit, url);
  }

  @override
  void close({bool force = false}) => debugPrint('FakeClient.close(force:$force)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// accessToken 만 제공하는 최소 UserController
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'stub-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

//
// ────────── 실제 테스트 ──────────
//
void main() {
  late LogRepository logRepository;

  setUp(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  test('LogRepository – requestLogList() 200 OK ⇒ StatusHistoryList', () async {
    final Uri targetUri = Uri.http(
      kApiServer,
      '/api/log/list',
      <String, String>{'objectId': '1', 'limit': '10', 'offset': '0'},
    );

    final Map<Uri, FakeHttpResponseData> fakeMap = <Uri, FakeHttpResponseData>{
      targetUri: FakeHttpResponseData(statusCode: 200, bodyString: _dummyJsonBody),
    };

    await HttpOverrides.runZoned(
      () async {
        logRepository = LogRepository();
        final result = await logRepository.requestLogList(1, 10, 0);
        expect(result, isNotNull); // 정상 파싱 확인
      },
      createHttpClient: (_) => FakeHttpClient(fakeMap),
    );
  });

  test('LogRepository – requestLogList() 500 ⇒ null', () async {
    final Uri targetUri = Uri.http(
      kApiServer,
      '/api/log/list',
      <String, String>{'objectId': '1', 'limit': '10', 'offset': '0'},
    );

    final Map<Uri, FakeHttpResponseData> fakeMap = <Uri, FakeHttpResponseData>{
      targetUri: FakeHttpResponseData(statusCode: 500, bodyString: ''),
    };

    await HttpOverrides.runZoned(
      () async {
        logRepository = LogRepository();
        final result = await logRepository.requestLogList(1, 10, 0);
        expect(result, isNull);
      },
      createHttpClient: (_) => FakeHttpClient(fakeMap),
    );
  });

  test('LogRepository – requestLogList() 404 ⇒ null', () async {
    final Uri targetUri = Uri.http(
      kApiServer,
      '/api/log/list',
      <String, String>{'objectId': '1', 'limit': '10', 'offset': '0'},
    );

    final Map<Uri, FakeHttpResponseData> fakeMap = <Uri, FakeHttpResponseData>{
      targetUri: FakeHttpResponseData(statusCode: 404, bodyString: ''),
    };

    await HttpOverrides.runZoned(
      () async {
        logRepository = LogRepository();
        final result = await logRepository.requestLogList(1, 10, 0);
        expect(result, isNull);
      },
      createHttpClient: (_) => FakeHttpClient(fakeMap),
    );
  });
}
