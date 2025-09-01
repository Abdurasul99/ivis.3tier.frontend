// -----------------------------------------------------------------------------
// test/viewmodel/repository/member_repository_test.dart
// -----------------------------------------------------------------------------
//
// MemberRepository 단위 테스트 (모든 주석은 한국어)
//
// 1) FakeHttpClient + HttpOverrides 로 네트워크 스텁
// 2) FakeUserController 로 토큰 의존성 해결
// 3) 주요 메서드 성공/실패 시나리오 검증
//
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/model/user_model.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/member_repository.dart';

//
// ────────────────── Fake HTTP 인프라 ──────────────────
//

class FakeHttpResponseData {
  FakeHttpResponseData({required this.statusCode, required String body}) : bodyBytes = utf8.encode(body);

  final int statusCode;
  final List<int> bodyBytes;
}

class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void add(String name, Object? value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name, () => []).add(value.toString());

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => _map[name] = [value.toString()];

  @override
  void clear() => _map.clear();

  @override
  void forEach(void Function(String name, List<String> values) action) => _map.forEach(action);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequest implements HttpClientRequest {
  FakeHttpClientRequest(this._data, this._requestUri, this._requestMethod);

  final FakeHttpResponseData _data;
  final Uri _requestUri;
  final String _requestMethod;

  // 필수 프로퍼티 ----------------------------------------------------------------
  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  String get method => _requestMethod; // 부모 getter 구현 재사용

  @override
  Uri get uri => _requestUri;

  // 리다이렉트 관련 세터 ----------------------------------------------------------
  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  // 기타 속성 --------------------------------------------------------------------
  @override
  bool persistentConnection = false;

  @override
  int contentLength = 0;

  // 요청 종료(응답 반환) ----------------------------------------------------------
  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(_data);

  // Stream/쓰기 API는 필요 없어 빈 구현 ------------------------------------------
  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> flush() async {} // ← Future<void> 로 반환형 수정

  @override
  void write(Object? obj) {}

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? obj = ""]) {}

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeHttpClientResponse(this._data);

  final FakeHttpResponseData _data;

  @override
  int get statusCode => _data.statusCode;

  @override
  int get contentLength => _data.bodyBytes.length;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_data.bodyBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError ?? false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RequestKey {
  const _RequestKey(this.method, this.uri);
  final String method;
  final Uri uri;

  @override
  bool operator ==(Object other) => other is _RequestKey && other.method == method && other.uri == uri;

  @override
  int get hashCode => Object.hash(method, uri);
}

class FakeHttpClient implements HttpClient {
  FakeHttpClient(this._map);
  final Map<_RequestKey, FakeHttpResponseData> _map;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final data = _map[_RequestKey(method, url)] ?? FakeHttpResponseData(statusCode: 404, body: '');
    debugPrint('FakeClient → $method $url (status ${data.statusCode})');
    return FakeHttpClientRequest(data, url, method);
  }

  @override
  void close({bool force = false}) => debugPrint('FakeClient.close(force:$force)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestHttpOverrides extends HttpOverrides {
  TestHttpOverrides(this._map);
  final Map<_RequestKey, FakeHttpResponseData> _map;
  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeHttpClient(_map);
}

//
// ────────────────── Fake UserController ──────────────────
//
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'dummy';

  // 필수 프로퍼티 최소 구현
  @override
  String foundJoinDate = '';
  @override
  String foundUserId = '';
  LoginUser? _loginUser;
  @override
  LoginUser? get loginUser => _loginUser;
  @override
  bool isAdminUser() => false;
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

//
// ───────────────────────── 실제 테스트 ─────────────────────────
//
void main() {
  late MemberRepository memberRepository;

  setUpAll(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  group('MemberRepository – 네트워크 호출', () {
    test('requestUnApprovedMemberList() – 200 OK ⇒ 길이 2', () async {
      final uri = Uri.http(kApiServer, '/api/member/unApprovedMember');
      HttpOverrides.global = TestHttpOverrides({
        _RequestKey('GET', uri): FakeHttpResponseData(
          statusCode: 200,
          body: jsonEncode({
            'body': [
              {'id': 1, 'email': 'a@ivis.ai'},
              {'id': 2, 'email': 'b@ivis.ai'}
            ]
          }),
        )
      });
      memberRepository = MemberRepository();
      final list = await memberRepository.requestUnApprovedMemberList();
      expect(list.length, 2);
    });

    test('requestMemberList() – 500 ⇒ 빈 리스트', () async {
      final uri = Uri.http(kApiServer, '/api/member/Member');
      HttpOverrides.global = TestHttpOverrides({
        _RequestKey('GET', uri): FakeHttpResponseData(statusCode: 500, body: ''),
      });
      memberRepository = MemberRepository();
      expect(await memberRepository.requestMemberList(), isEmpty);
    });

    test('requestApproveMember() – 200 OK ⇒ true', () async {
      final uri = Uri.http(kApiServer, '/api/member/approveMember');
      HttpOverrides.global = TestHttpOverrides({
        _RequestKey('POST', uri): FakeHttpResponseData(
          statusCode: 200,
          body: jsonEncode({
            'body': {'affectedRows': 1}
          }),
        )
      });
      memberRepository = MemberRepository();
      expect(await memberRepository.requestApproveMember(1), isTrue);
    });

    test('requestRejectMember() – 200 OK ⇒ true', () async {
      final uri = Uri.http(kApiServer, '/api/member/rejectMember');
      HttpOverrides.global = TestHttpOverrides({
        _RequestKey('POST', uri): FakeHttpResponseData(
          statusCode: 200,
          body: jsonEncode({
            'body': {'affectedRows': 1}
          }),
        )
      });
      memberRepository = MemberRepository();
      expect(await memberRepository.requestRejectMember(1), isTrue);
    });

    test('requestChangeRole() – 200 OK ⇒ true', () async {
      final uri = Uri.http(kApiServer, '/api/member/rejectMember');
      HttpOverrides.global = TestHttpOverrides({
        _RequestKey('PATCH', uri): FakeHttpResponseData(
          statusCode: 200,
          body: jsonEncode({
            'body': {'affectedRows': 1}
          }),
        )
      });
      memberRepository = MemberRepository();
      expect(await memberRepository.requestChangeRole(1, '관리자'), isTrue);
    });

    test('requestDeleteMember() – 404 ⇒ false', () async {
      final uri = Uri.http(kApiServer, '/api/member/deleteMember');
      HttpOverrides.global = TestHttpOverrides({
        _RequestKey('DELETE', uri): FakeHttpResponseData(statusCode: 404, body: ''),
      });
      memberRepository = MemberRepository();
      expect(await memberRepository.requestDeleteMember(1), isFalse);
    });
  });
}
