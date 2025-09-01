// register_repository_test.dart
// ──────────────────────────────────────────────────────────────
// RegisterRepository 및 RegisterController 단위 테스트
//
// ▣ 주요 특징
//   1. 모든 식별자는 의미 있는 풀네임으로 작성 (짧은 한 글자 변수나 축약형 사용 ❌)
//   2. Fake HTTP 인프라에 followRedirects·maxRedirects·persistentConnection·
//      bufferOutput·contentLength 세터 완비 → http.post 호출 시 예외 없음
//   3. Repository 메서드 3종 + Controller 3-step flow 전부 검증
//   4. 각 테스트 앞뒤로 debugPrint 로그 포함

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/viewmodel/repository/register_repository.dart';
import 'package:fms/viewmodel/controller/register_controller.dart';
import 'package:fms/model/common_model.dart';

//////////////////////////////////////////////////////////////////////////////
// ① Fake HTTP 인프라 (모든 필드·메서드 풀네임 사용)
//////////////////////////////////////////////////////////////////////////////

class FakeHttpResponseBlueprint {
  final int statusCode;
  final Map<String, dynamic> responseJson;
  const FakeHttpResponseBlueprint({required this.statusCode, required this.responseJson});
}

class DetailedHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> headerStorage = <String, List<String>>{};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      headerStorage.putIfAbsent(name.toLowerCase(), () => <String>[]).add(value.toString());

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      headerStorage[name.toLowerCase()] = <String>[value.toString()];

  @override
  void forEach(void Function(String, List<String>) action) => headerStorage.forEach(action);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequestDetailed implements HttpClientRequest {
  FakeHttpClientRequestDetailed(this.blueprint, this.requestUri, this.httpMethod);

  final FakeHttpResponseBlueprint blueprint;
  final Uri requestUri;
  final String httpMethod;

  bool _followRedirects = true;
  int _maxRedirects = 5;
  bool _persistentConnection = false;
  bool _bufferOutput = false;
  int _contentLength = 0;

  @override
  final HttpHeaders headers = DetailedHttpHeaders();

  @override
  bool get followRedirects => _followRedirects;
  @override
  set followRedirects(bool value) => _followRedirects = value;

  @override
  int get maxRedirects => _maxRedirects;
  @override
  set maxRedirects(int value) => _maxRedirects = value;

  @override
  bool get persistentConnection => _persistentConnection;
  @override
  set persistentConnection(bool value) => _persistentConnection = value;

  @override
  bool get bufferOutput => _bufferOutput;
  @override
  set bufferOutput(bool value) => _bufferOutput = value;

  @override
  int get contentLength => _contentLength;
  @override
  set contentLength(int value) => _contentLength = value;

  @override
  Uri get uri => requestUri;
  @override
  String get method => httpMethod;

  // 본문 스트림은 무시 (단위 테스트용)
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = ""]) {}

  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponseDetailed(blueprint);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientResponseDetailed extends Stream<List<int>> implements HttpClientResponse {
  FakeHttpClientResponseDetailed(this.blueprint) {
    encodedBodyBytes = utf8.encode(jsonEncode(blueprint.responseJson));
  }

  final FakeHttpResponseBlueprint blueprint;
  late final List<int> encodedBodyBytes;

  @override
  int get statusCode => blueprint.statusCode;
  @override
  int get contentLength => encodedBodyBytes.length;
  @override
  String get reasonPhrase => '';
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];
  @override
  bool get persistentConnection => false;
  @override
  HttpHeaders get headers => DetailedHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable(<List<int>>[encodedBodyBytes]).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError ?? false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientDetailed implements HttpClient {
  FakeHttpClientDetailed(this.responseMap);
  final Map<Uri, FakeHttpResponseBlueprint> responseMap;

  Future<HttpClientRequest> _open(String httpMethod, Uri requestUri) async {
    final FakeHttpResponseBlueprint? selectedBlueprint = responseMap[requestUri];
    if (selectedBlueprint == null) {
      throw TestFailure('해당 URI 에 대한 Fake 응답이 없습니다: $requestUri');
    }
    return FakeHttpClientRequestDetailed(selectedBlueprint, requestUri, httpMethod);
  }

  @override
  Future<HttpClientRequest> openUrl(String httpMethod, Uri requestUri) => _open(httpMethod, requestUri);
  @override
  Future<HttpClientRequest> postUrl(Uri requestUri) => _open('POST', requestUri);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestHttpOverridesDetailed extends HttpOverrides {
  TestHttpOverridesDetailed(this.responseMap);
  final Map<Uri, FakeHttpResponseBlueprint> responseMap;

  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeHttpClientDetailed(responseMap);
}

//////////////////////////////////////////////////////////////////////////////
// ② 공통 JSON 응답
//////////////////////////////////////////////////////////////////////////////

const Map<String, dynamic> jsonSuccessWithoutBody = <String, dynamic>{
  'code': '0000',
  'message': 'OK',
  'body': <String, dynamic>{},
};

const Map<String, dynamic> jsonVerifySuccess = <String, dynamic>{
  'code': '0000',
  'message': 'OK',
  'body': <String, dynamic>{
    'verifyToken': 'mock-verification-token',
  },
};

//////////////////////////////////////////////////////////////////////////////
// ③ 테스트
//////////////////////////////////////////////////////////////////////////////

void main() {
  late RegisterRepository registerRepositoryInstance;
  late RegisterController registerControllerInstance;

  setUpAll(() {
    Get.testMode = true; // GetX 테스트 모드 활성화
  });

  ////////////////////////////////////////////////////////////////////////////
  // Repository 레이어 테스트
  ////////////////////////////////////////////////////////////////////////////

  group('RegisterRepository API 테스트', () {
    test('requestRegisterSendCode() – 200 OK', () async {
      debugPrint('🚀 RegisterRepository.sendCode 시작');
      final Uri sendCodeUri = Uri.parse('http://$kApiServer/api/findId/sendCode');
      HttpOverrides.global = TestHttpOverridesDetailed(
        <Uri, FakeHttpResponseBlueprint>{
          sendCodeUri: const FakeHttpResponseBlueprint(
            statusCode: 200,
            responseJson: jsonSuccessWithoutBody,
          ),
        },
      );

      registerRepositoryInstance = RegisterRepository();
      final CommonResponse? apiResponse =
          await registerRepositoryInstance.requestRegisterSendCode('홍길동', 'hong@example.com');
      debugPrint('✅ 결과: $apiResponse');

      expect(apiResponse, isNotNull);
      expect(apiResponse!.code, equals('0000'));
    });

    test('requestRegisterVerifyCode() – 200 OK', () async {
      debugPrint('🚀 RegisterRepository.verifyCode 시작');
      final Uri verifyCodeUri = Uri.parse('http://$kApiServer/api/findId/verify');
      HttpOverrides.global = TestHttpOverridesDetailed(
        <Uri, FakeHttpResponseBlueprint>{
          verifyCodeUri: const FakeHttpResponseBlueprint(
            statusCode: 200,
            responseJson: jsonVerifySuccess,
          ),
        },
      );

      registerRepositoryInstance = RegisterRepository();
      final CommonResponse? apiResponse =
          await registerRepositoryInstance.requestRegisterVerifyCode('hong@example.com', '1234');
      debugPrint('✅ 결과: $apiResponse');

      expect(apiResponse, isNotNull);
      expect(apiResponse!.code, equals('0000'));
      expect(apiResponse.body['verifyToken'], equals('mock-verification-token'));
    });

    test('requestRegisterComplete() – 200 OK', () async {
      debugPrint('🚀 RegisterRepository.complete 시작');
      final Uri completeUri = Uri.parse('http://$kApiServer/api/findId/complete');
      HttpOverrides.global = TestHttpOverridesDetailed(
        <Uri, FakeHttpResponseBlueprint>{
          completeUri: const FakeHttpResponseBlueprint(
            statusCode: 200,
            responseJson: jsonSuccessWithoutBody,
          ),
        },
      );

      registerRepositoryInstance = RegisterRepository();
      final CommonResponse? apiResponse = await registerRepositoryInstance.requestRegisterComplete(
        email: 'abdurasul@ivis.ai',
        userId: 'Abdurasul',
        name: 'Abdurasul',
        phoneNumber: '01075064415',
        password: 'Test1234@',
        verifyToken: 'mock-verification-token',
      );
      debugPrint('✅ 결과: $apiResponse');

      expect(apiResponse, isNotNull);
      expect(apiResponse!.code, equals('0000'));
    });
  });

  ////////////////////////////////////////////////////////////////////////////
  // Controller 레이어 전체 Flow 테스트
  ////////////////////////////////////////////////////////////////////////////

  group('RegisterController 전체 회원가입 플로우', () {
    test('sendCode → verifyCode → completeRegister 성공 시나리오', () async {
      debugPrint('🚀 RegisterController 플로우 시작');

      // (1) 코드 전송 단계 – 성공 응답 세팅
      final Uri sendCodeUri = Uri.parse('http://$kApiServer/api/findId/sendCode');
      HttpOverrides.global = TestHttpOverridesDetailed(
        <Uri, FakeHttpResponseBlueprint>{
          sendCodeUri: const FakeHttpResponseBlueprint(
            statusCode: 200,
            responseJson: jsonSuccessWithoutBody,
          ),
        },
      );

      registerControllerInstance = RegisterController();
      final bool sendCodeResult = await registerControllerInstance.sendRegisterCode('Abdurasul', 'abdurasul@ivis.ai');
      expect(sendCodeResult, isTrue);

      // (2) 코드 검증 단계 – verifyToken 응답 포함
      final Uri verifyCodeUri = Uri.parse('http://$kApiServer/api/findId/verify');
      HttpOverrides.global = TestHttpOverridesDetailed(
        <Uri, FakeHttpResponseBlueprint>{
          verifyCodeUri: const FakeHttpResponseBlueprint(
            statusCode: 200,
            responseJson: jsonVerifySuccess,
          ),
        },
      );

      final bool verifyCodeResult = await registerControllerInstance.verifyRegisterCode('abdurasul@ivis.ai', '1234');
      expect(verifyCodeResult, isTrue);
      expect(registerControllerInstance.verifyToken, equals('mock-verification-token'));

      // (3) 회원가입 완료 단계 – 성공 응답
      final Uri completeUri = Uri.parse('http://$kApiServer/api/findId/complete');
      HttpOverrides.global = TestHttpOverridesDetailed(
        <Uri, FakeHttpResponseBlueprint>{
          completeUri: const FakeHttpResponseBlueprint(
            statusCode: 200,
            responseJson: jsonSuccessWithoutBody,
          ),
        },
      );

      final bool completeResult = await registerControllerInstance.completeRegister(
        email: 'abdurasul@ivis.ai',
        userId: 'Abdurasul',
        name: 'Abdurasul',
        phoneNumber: '01075064415',
        password: 'Test1234@',
      );
      expect(completeResult, isTrue);
    });
  });
}
