// test/viewmodel/repository/password_repository_test.dart
//
// PasswordRepository 단위 테스트 (AAA 패턴)
// ① FakeHttpClient 로 http 패키지 호출 가로채기
// ② 각 API(6개) 성공/실패 시나리오 검증
// ──────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/model/common_model.dart';
import 'package:fms/viewmodel/repository/password_repository.dart';

//
// ────────────── Fake HTTP 구현 ──────────────
//

/// 응답 데이터를 보관하는 구조체
class FakeHttpResponseData {
  final int statusCode;
  final Map<String, dynamic> bodyJson;
  FakeHttpResponseData({required this.statusCode, required this.bodyJson});
}

/// set()/forEach() 만 구현한 최소 HttpHeaders
class _MiniHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name.toLowerCase(), () => <String>[]).add(value.toString());
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = <String>[value.toString()];
  @override
  void forEach(void Function(String, List<String>) action) => _map.forEach(action);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Fake 요청 – IOSink 메서드 포함
class FakeHttpClientRequest implements HttpClientRequest {
  FakeHttpClientRequest(this._data, this._uri, this._method);
  final FakeHttpResponseData _data;
  final Uri _uri;
  final String _method;

  // 필수 필드
  @override
  final HttpHeaders headers = _MiniHeaders();
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

  // getter
  @override
  String get method => _method;
  @override
  Uri get uri => _uri;

  // IOSink 구현
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? st]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? obj) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  void writeAll(Iterable objects, [String sep = '']) {}
  @override
  void writeCharCode(int charCode) {}

  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(_data);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Fake 응답
class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeHttpClientResponse(this._data);
  final FakeHttpResponseData _data;

  @override
  int get statusCode => _data.statusCode;
  @override
  int get contentLength => -1;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => '';
  @override
  HttpHeaders get headers => _MiniHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final bytes = utf8.encode(jsonEncode(_data.bodyJson));
    return Stream<List<int>>.fromIterable(<List<int>>[bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError ?? false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// FakeHttpClient – openUrl 만 구현
class FakeHttpClient implements HttpClient {
  FakeHttpClient(this._map);
  final Map<Uri, FakeHttpResponseData> _map;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final hit = _map[url]!;
    return FakeHttpClientRequest(hit, url, method);
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// HttpOverrides 로 Fake 클라이언트 주입
class TestOverrides extends HttpOverrides {
  final Map<Uri, FakeHttpResponseData> map;
  TestOverrides(this.map);
  @override
  HttpClient createHttpClient(SecurityContext? _) => FakeHttpClient(map);
}

//
// ────────────── 실제 테스트 ──────────────
//
void main() {
  late PasswordRepository repository;

  // 공통 200 응답 JSON
  const Map<String, dynamic> okBody = {"code": "0000", "body": {}};

  group('PasswordRepository – 네트워크 호출', () {
    test('requestResetPassword() – 200 OK', () async {
      final uri = Uri.http(kApiServer, '/api/password/reset');
      HttpOverrides.global = TestOverrides({
        uri: FakeHttpResponseData(statusCode: 200, bodyJson: okBody),
      });

      repository = PasswordRepository();
      final CommonResponse? res = await repository.requestResetPassword('ctrlcv@ivis.ai');
      expect(res, isNotNull);
      expect(res!.code, '0000');
    });

    test('requestVerifyCode() – 200 OK', () async {
      final uri = Uri.http(kApiServer, '/api/password/verify');
      HttpOverrides.global = TestOverrides({
        uri: FakeHttpResponseData(statusCode: 200, bodyJson: okBody),
      });

      repository = PasswordRepository();
      final CommonResponse? res = await repository.requestVerifyCode('ctrlcv@ivis.ai', '1111');
      expect(res, isNotNull);
      expect(res!.code, '0000');
    });

    test('requestCompletePassword() – 200 OK', () async {
      final uri = Uri.http(kApiServer, '/api/password/complete');
      HttpOverrides.global = TestOverrides({
        uri: FakeHttpResponseData(statusCode: 200, bodyJson: okBody),
      });

      repository = PasswordRepository();
      final CommonResponse? res =
          await repository.requestCompletePassword('ctrlcv@ivis.ai', '1111', 'verify-token');
      expect(res, isNotNull);
      expect(res!.code, '0000');
    });

    test('requestResetPasswordByIdAndEmail() – 200 OK', () async {
      final uri = Uri.http(kApiServer, '/api/password/resetByIdAndEmail');
      HttpOverrides.global = TestOverrides({
        uri: FakeHttpResponseData(statusCode: 200, bodyJson: okBody),
      });

      repository = PasswordRepository();
      final CommonResponse? res = await repository.requestResetPasswordByIdAndEmail('admin', 'ctrlcv@ivis.ai');
      expect(res, isNotNull);
      expect(res!.code, '0000');
    });

    test('requestVerifyCodeByIdAndEmail() – 404 → null', () async {
      final uri = Uri.http(kApiServer, '/api/password/verifyByIdAndEmail');
      HttpOverrides.global = TestOverrides({
        uri: FakeHttpResponseData(statusCode: 404, bodyJson: {}),
      });

      repository = PasswordRepository();
      final CommonResponse? res = await repository.requestVerifyCodeByIdAndEmail('admin', 'ctrlcv@ivis.ai', '1111');
      expect(res, isNull);
    });
  });
}
