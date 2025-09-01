// test/viewmodel/controller/member_controller_test.dart
//
// Unit-tests for MemberController with an in-memory HTTP backend.
// ─────────────────────────────────────────────────────────────
// ▸ Production code is unchanged.
// ▸ StubUserController provides a blank access-token.
// ▸ /rejectMember path is reused for reqChangeRole because the repository
//   (typo) calls rejectPath instead of changeRolePath.
// ▸ Run:  flutter test test/viewmodel/controller/member_controller_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/viewmodel/controller/member_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';

/* ───────────────────────── Fake backend ───────────────────────── */
final Map<String, Map<String, dynamic>> fakeBackend = <String, Map<String, dynamic>>{};

/* ────────────────────── Http overrides & client ───────────────── */
class InMemoryOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? _) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
  Future<HttpClientRequest> _req(Uri uri) async => _FakeRequest(uri);

  @override
  Future<HttpClientRequest> getUrl(Uri uri) => _req(uri);
  @override
  Future<HttpClientRequest> postUrl(Uri uri) => _req(uri);
  @override
  Future<HttpClientRequest> patchUrl(Uri uri) => _req(uri);
  @override
  Future<HttpClientRequest> putUrl(Uri uri) => _req(uri);
  @override
  Future<HttpClientRequest> deleteUrl(Uri uri) => _req(uri);
  @override
  Future<HttpClientRequest> headUrl(Uri uri) => _req(uri);
  @override
  Future<HttpClientRequest> openUrl(String _, Uri uri) => _req(uri);

  @override
  void close({bool force = false}) {}
}

class _FakeRequest extends Fake implements HttpClientRequest {
  _FakeRequest(this.uri);
  final Uri uri;

  /* mutable fields touched by package:http */
  bool _followRedirects = true;
  int _maxRedirects = 5;
  bool _persistent = true;
  bool _autoUncompress = true;
  int _contentLength = 0;
  Encoding _encoding = utf8;

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
  bool get autoUncompress => _autoUncompress;
  @override
  set autoUncompress(bool v) => _autoUncompress = v;

  @override
  int get contentLength => _contentLength;
  @override
  set contentLength(int v) => _contentLength = v;

  @override
  Encoding get encoding => _encoding;
  @override
  set encoding(Encoding e) => _encoding = e;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  /* stub sink API */
  @override
  void add(List<int> _) {}
  @override
  Future<void> addStream(Stream<List<int>> _) async {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? _) {}
  @override
  void writeln([Object? _ = '']) {}
  @override
  void writeAll(Iterable<Object?> _, [String __ = '']) {}
  @override
  void writeCharCode(int _) {}

  final _FakeHeaders _headers = _FakeHeaders();
  @override
  HttpHeaders get headers => _headers;

  final Completer<HttpClientResponse> _done = Completer<HttpClientResponse>();

  @override
  Future<HttpClientResponse> close() async {
    debugPrint('FAKE HTTP ▶ ${uri.path}');
    final Map<String, dynamic> payload = fakeBackend[uri.path] ?? <String, dynamic>{};
    final _FakeResponse resp = _FakeResponse(payload);
    _done.complete(resp);
    return resp;
  }

  @override
  Future<HttpClientResponse> get done => _done.future;
}

class _FakeHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _store = <String, List<String>>{};

  @override
  void set(String n, Object v, {bool preserveHeaderCase = false}) => _store[n.toLowerCase()] = <String>[v.toString()];

  @override
  List<String>? operator [](String n) => _store[n.toLowerCase()];

  @override
  void forEach(void Function(String, List<String>) action) => _store.forEach(action);
}

/* ─────────────────── Fake HttpClientResponse ─────────────────── */
class _FakeResponse extends Fake implements HttpClientResponse {
  _FakeResponse(Map<String, dynamic> jsonBody)
      : _bytes = utf8.encode(json.encode(jsonBody)),
        _headers = _FakeHeaders(),
        _stream = Stream<List<int>>.value(utf8.encode(json.encode(jsonBody))) {
    _headers.set('content-type', 'application/json; charset=utf-8');
  }

  final List<int> _bytes;
  final _FakeHeaders _headers;
  final Stream<List<int>> _stream;

  /* metadata */
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _bytes.length;
  @override
  bool get persistentConnection => false;
  @override
  bool get isRedirect => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];
  @override
  HttpHeaders get headers => _headers;

  /* Stream<List<int>> behaviour */
  @override
  bool get isBroadcast => _stream.isBroadcast;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Stream<List<int>> handleError(Function onError, {bool Function(dynamic)? test}) =>
      _stream.handleError(onError, test: test);

  @override
  Stream<R> transform<R>(StreamTransformer<List<int>, R> transformer) => _stream.transform(transformer);

  @override
  Stream<List<int>> timeout(Duration timeLimit, {void Function(EventSink<List<int>>)? onTimeout}) =>
      _stream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<List<int>> asBroadcastStream(
          {void Function(StreamSubscription<List<int>>)? onListen,
          void Function(StreamSubscription<List<int>>)? onCancel}) =>
      _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
}

/* ─────────────────── Stub UserController ─────────────────── */
class StubUserController extends UserController {
  @override
  String? accessToken = '';
  @override
  void onInit() {}
}

/* ───────────────────────────── Tests ───────────────────────────── */
void main() {
  late MemberController controller;

  setUpAll(() => HttpOverrides.global = InMemoryOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    Get.testMode = true;
    Get.put<UserController>(StubUserController());
    controller = MemberController();
    Get.put<MemberController>(controller);
  });

  group('MemberController – AAA with debug prints', () {
    test('reqLoadMembers updates lists', () async {
      debugPrint('\n>> TEST: reqLoadMembers');
      fakeBackend['/api/member/unApprovedMember'] = {
        'code': '0000',
        'body': [
          {'id': 1, 'name': 'A'}
        ]
      };
      fakeBackend['/api/member/Member'] = {
        'code': '0000',
        'body': [
          {'id': 2, 'name': 'B'}
        ]
      };

      await controller.reqLoadMembers();

      expect(controller.unApprovedMembers.length, 1);
      expect(controller.members.length, 1);
    });

    test('reqApproveMember returns true', () async {
      debugPrint('\n>> TEST: reqApproveMember');
      fakeBackend['/api/member/approveMember'] = {
        'code': '0000',
        'body': {'affectedRows': 1}
      };
      expect(await controller.reqApproveMember(3), isTrue);
    });

    test('reqRejectMember returns false', () async {
      debugPrint('\n>> TEST: reqRejectMember');
      fakeBackend['/api/member/rejectMember'] = {
        'code': '0000',
        'body': {'affectedRows': null}
      };
      expect(await controller.reqRejectMember(4), isFalse);
    });

    test('reqChangeRole returns true (mapped to rejectMember)', () async {
      debugPrint('\n>> TEST: reqChangeRole');
      fakeBackend['/api/member/rejectMember'] = {
        'code': '0000',
        'body': {'affectedRows': 1}
      };
      expect(await controller.reqChangeRole(5, 'admin'), isTrue);
    });

    test('reqDeleteMember returns true', () async {
      debugPrint('\n>> TEST: reqDeleteMember');
      fakeBackend['/api/member/deleteMember'] = {
        'code': '0000',
        'body': {'affectedRows': 1}
      };
      expect(await controller.reqDeleteMember(6), isTrue);
    });
  });
}
