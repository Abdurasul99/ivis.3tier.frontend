// upload_repository_test.dart
// ──────────────────────────────────────────────────────────────
// UploadRepository 단위 테스트 – followRedirects / bufferOutput 등
// 누락된 세터 구현으로 NoSuchMethodError 해결 + debugPrint 유지.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/upload_repository.dart';
import 'package:fms/model/upload_model.dart';
import 'package:fms/model/pick_image_model.dart';

// ──────────────────────────────────────────────────────────────
// ① Fake HTTP 인프라
// ──────────────────────────────────────────────────────────────
class FakeHttpResponseData {
  final int statusCode;
  final Map<String, dynamic> body;
  const FakeHttpResponseData({required this.statusCode, required this.body});
}

class _Headers implements HttpHeaders {
  final Map<String, List<String>> _map = {};
  @override
  void add(String n, Object v, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(n.toLowerCase(), () => []).add(v.toString());
  @override
  void set(String n, Object v, {bool preserveHeaderCase = false}) => _map[n.toLowerCase()] = [v.toString()];
  @override
  void forEach(void Function(String, List<String>) f) => _map.forEach(f);
  @override
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class _Req implements HttpClientRequest {
  _Req(this.d, this.u, this.m);
  final FakeHttpResponseData d;
  final Uri u;
  final String m;

  // ────────── 상태 보관용 필드 ──────────
  bool _followRedirects = true;
  bool _persistentConnection = false;
  bool _bufferOutput = false;
  int _contentLength = 0;
  int _maxRedirects = 5; // ★ NEW: maxRedirects 필드 추가

  @override
  final headers = _Headers();

  // followRedirects
  @override
  bool get followRedirects => _followRedirects;
  @override
  set followRedirects(bool v) => _followRedirects = v;

  // maxRedirects  ★ NEW: 게터·세터 구현
  @override
  int get maxRedirects => _maxRedirects;
  @override
  set maxRedirects(int v) => _maxRedirects = v;

  // persistentConnection
  @override
  bool get persistentConnection => _persistentConnection;
  @override
  set persistentConnection(bool v) => _persistentConnection = v;

  // bufferOutput
  @override
  bool get bufferOutput => _bufferOutput;
  @override
  set bufferOutput(bool v) => _bufferOutput = v;

  // contentLength
  @override
  int get contentLength => _contentLength;
  @override
  set contentLength(int v) => _contentLength = v;

  @override
  Uri get uri => u;
  @override
  String get method => m;

  // 바디 관련 메서드들 (변경 없음) …
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
    final data = map[u];
    if (data == null) throw TestFailure('no fake for $u');
    return _Req(data, u, m);
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
// ② FakeUserController
// ──────────────────────────────────────────────────────────────
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'token';
  // loginUser 접근 시 null 반환
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ──────────────────────────────────────────────────────────────
// ③ 테스트
// ──────────────────────────────────────────────────────────────
void main() {
  late UploadRepository repo;

  const fakeResp = {
    'result': [
      {'ETag': '"e123"', 'key': 'uploads/null/test.png', 'Location': 'http://localhost:3090/static/test.png'}
    ]
  };

  setUpAll(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  test('requestUploadImage – 200 OK, UploadModel 필드 매핑', () async {
    debugPrint('🚀 upload 테스트 시작');
    final uri = Uri.parse('http://$kApiServer/api/upload/file');
    HttpOverrides.global = _Overrides({uri: FakeHttpResponseData(statusCode: 200, body: fakeResp)});

    repo = UploadRepository();

    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
    final files = [PickImageFile(fileType: PickImageFileType.imageBytes, imageBytes: bytes)];

    final result = await repo.requestUploadImage(files);
    debugPrint('✅ 결과: $result');

    expect(result, hasLength(1));
    final up = result.first;
    expect(up.eTag, equals('"e123"'));
    expect(up.key, equals('uploads/null/test.png'));
    expect(up.location, equals('http://localhost:3090/static/test.png'));
  });
}
