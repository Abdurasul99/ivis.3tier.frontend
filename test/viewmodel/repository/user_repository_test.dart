// user_repository_test.dart
// ──────────────────────────────────────────────────────────────
// UserRepository 단위 테스트 – 모든 API 엔드포인트 검증
//
// • 각 테스트 시작·끝에 debugPrint 출력
// • 로컬 Fake-HTTP 레이어로 http.post 모킹
// • UserController 인스턴스는 Get 컨테이너에 등록해 BaseRepository 헤더 생성에 사용
//
// 테스트 목록
//   1. 회원가입  (requestSignUpByIdAndEmail)
//   2. ID 로그인 (requestLoginById)
//   3. 토큰로그인 (requestLoginByToken)
//   4. 비밀번호 변경 – 성공
//   5. 비밀번호 변경 – 기존 PW 오류
//   6. 휴대폰 번호 변경
//   7. 프로필이미지 업데이트
//   8. 아이디찾기 – 코드 전송
//   9. 아이디찾기 – 코드 검증

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/user_repository.dart';
import 'package:fms/model/common_model.dart';
import 'package:fms/model/user_model.dart';

// ──────────────────────────────────────────────────────────────
// ① Fake HTTP 레이어
// ──────────────────────────────────────────────────────────────
class FakeHttpResponseData {
  final int statusCode;
  final Map<String, dynamic> body;
  const FakeHttpResponseData({required this.statusCode, required this.body});
}

class _Headers implements HttpHeaders {
  final Map<String, List<String>> _m = {};
  @override
  void add(String n, Object v, {bool preserveHeaderCase = false}) =>
      _m.putIfAbsent(n.toLowerCase(), () => []).add(v.toString());
  @override
  void set(String n, Object v, {bool preserveHeaderCase = false}) => _m[n.toLowerCase()] = [v.toString()];
  @override
  void forEach(void Function(String, List<String>) f) => _m.forEach(f);
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class _Req implements HttpClientRequest {
  _Req(this.d, this.u, this.m);
  final FakeHttpResponseData d;
  final Uri u;
  final String m;

  bool _followRedirects = true;
  int _maxRedirects = 5;
  bool _persistent = false;
  bool _bufferOutput = false;
  int _contentLength = 0;

  @override
  final headers = _Headers();

  @override
  bool get followRedirects => _followRedirects;
  @override
  set followRedirects(bool v) => _followRedirects = v;
  @override
  int get maxRedirects => _maxRedirects;
  @override
  set maxRedirects(int v) => _maxRedirects = v;
  @override
  bool get persistentConnection => _persistent;
  @override
  set persistentConnection(bool v) => _persistent = v;
  @override
  bool get bufferOutput => _bufferOutput;
  @override
  set bufferOutput(bool v) => _bufferOutput = v;
  @override
  int get contentLength => _contentLength;
  @override
  set contentLength(int v) => _contentLength = v;

  @override
  Uri get uri => u;
  @override
  String get method => m;

  // body 무시
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
  Future<HttpClientResponse> close() async => _Res(d);
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class _Res extends Stream<List<int>> implements HttpClientResponse {
  _Res(this.d) {
    _bytes = utf8.encode(jsonEncode(d.body));
  }
  final FakeHttpResponseData d;
  late final List<int> _bytes;

  @override
  int get statusCode => d.statusCode;
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
  HttpHeaders get headers => _Headers();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([_bytes]).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError ?? false,
      );

  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class _Client implements HttpClient {
  _Client(this.map);
  final Map<Uri, FakeHttpResponseData> map;
  Future<HttpClientRequest> _open(String m, Uri u) async {
    final d = map[u];
    if (d == null) throw TestFailure('No fake for $u');
    return _Req(d, u, m);
  }

  @override
  Future<HttpClientRequest> openUrl(String m, Uri u) => _open(m, u);
  @override
  Future<HttpClientRequest> postUrl(Uri u) => _open('POST', u);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class _Overrides extends HttpOverrides {
  _Overrides(this.map);
  final Map<Uri, FakeHttpResponseData> map;
  @override
  HttpClient createHttpClient(SecurityContext? _) => _Client(map);
}

// ──────────────────────────────────────────────────────────────
// ② 테스트 세팅
// ──────────────────────────────────────────────────────────────
void main() {
  late UserRepository repo;

  // 공통 OK
  const okJson = {'code': '0000', 'message': 'OK', 'body': {}};

  // 로그인 OK
  const loginJson = {
    'code': '0000',
    'body': {'id': 1, 'userId': 'tester', 'email': 'ctrlcv@ivis.ai', 'accessToken': 'token-abc', 'role': 'admin'}
  };

  // 비번 오류
  const wrongPwdJson = {'code': '8003', 'body': {}};

  // 아이디 찾기 verify OK
  const verifyJson = {
    'code': '0000',
    'body': {'user_id': 'tester', 'join_date': '2025-06-25', 'verifyToken': 'pw-1234', 'email': 'ctrlcv@ivis.ai'}
  };

  setUpAll(() {
    Get.testMode = true;
    // UserController 는 헤더 생성시 필요
    Get.put<UserController>(UserController(), permanent: true);
  });

  ////////////////////////////////////////////////////////////////
  group('UserRepository 네트워크 테스트', () {
    test('회원가입 requestSignUpByIdAndEmail() – 200 OK', () async {
      debugPrint('🚀 signUp 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/signUpByIdAndEmail');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: okJson)});

      repo = UserRepository();
      final resp = await repo.requestSignUpByIdAndEmail({'foo': 'bar'});
      debugPrint('✅ 결과: $resp');
      expect(resp, isA<CommonResponse>());
      expect(resp!.code, equals('0000'));
    });

    test('ID 로그인 requestLoginById() – 200 OK', () async {
      debugPrint('🚀 loginById 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/signInById');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: loginJson)});

      repo = UserRepository();
      final lr = await repo.requestLoginById({'x': 'y'});
      debugPrint('✅ 결과: $lr');
      expect(lr, isA<LoginResult>());
      expect(lr!.loginUser!.userId, equals('tester'));
    });

    test('토큰 로그인 requestLoginByToken() – 200 OK', () async {
      debugPrint('🚀 loginByToken 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/signInByToken');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: loginJson)});

      repo = UserRepository();
      final lr = await repo.requestLoginByToken('token-abc');
      debugPrint('✅ 결과: $lr');
      expect(lr, isNotNull);
      expect(lr!.loginUser!.accessToken, equals('token-abc'));
    });

    test('비밀번호 변경 – 성공', () async {
      debugPrint('🚀 changePwd 성공 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/update');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: okJson)});

      repo = UserRepository();
      final result = await repo.requestChangePassword({'old': 'pw', 'new': 'pw2'});
      debugPrint('✅ 결과: $result');
      expect(result, equals('changed password'));
    });

    test('비밀번호 변경 – 기존 PW 오류', () async {
      debugPrint('🚀 changePwd 오류 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/update');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: wrongPwdJson)});

      repo = UserRepository();
      final result = await repo.requestChangePassword({'old': 'bad', 'new': 'pw2'});
      debugPrint('✅ 결과: $result');
      expect(result, equals('wrong password'));
    });

    test('휴대폰 번호 변경 requestChangePhoneNumber() – 200 OK', () async {
      debugPrint('🚀 changePhone 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/updatePhoneNumber');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: okJson)});

      repo = UserRepository();
      final ok = await repo.requestChangePhoneNumber({'phoneNumber': '010'});
      debugPrint('✅ 결과: $ok');
      expect(ok, isTrue);
    });

    test('프로필 이미지 업데이트 requestUpdateProfileImage() – 200 OK', () async {
      debugPrint('🚀 updateProfileImage 테스트');
      final uri = Uri.parse('http://$kApiServer/api/users/updateProfile');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: okJson)});

      repo = UserRepository();
      final ok = await repo.requestUpdateProfileImage({'imageUrl': 'img'});
      debugPrint('✅ 결과: $ok');
      expect(ok, isTrue);
    });

    test('아이디찾기 코드전송 requestFindIdSendCode() – 200 OK', () async {
      debugPrint('🚀 findId sendCode 테스트');
      final uri = Uri.parse('http://$kApiServer/api/findid/sendCode');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: okJson)});

      repo = UserRepository();
      final ok = await repo.requestFindIdSendCode({'name': 'a', 'email': 'b'});
      debugPrint('✅ 결과: $ok');
      expect(ok, isTrue);
    });

    test('아이디찾기 코드검증 requestFindIdVerifyCodeWithData() – 200 OK', () async {
      debugPrint('🚀 findId verifyCode 테스트');
      final uri = Uri.parse('http://$kApiServer/api/findid/verify');
      HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: verifyJson)});

      repo = UserRepository();
      final res = await repo.requestFindIdVerifyCodeWithData({'email': 'e', 'code': 'c'});
      debugPrint('✅ 결과: $res');
      expect(res['success'], isTrue);
      expect(res['userId'], equals('tester'));
    });
  });
}
