// test/viewmodel/controller/log_controller_test.dart
//
// Unit-tests for LogController with an in-memory HTTP backend.
// Production code is untouched (only this file is added).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/log_repository.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';

/// ---------------------------------------------------------------------------
/// (1) Optional mocks – not used in current test, kept for future extensions.
/// ---------------------------------------------------------------------------
@GenerateNiceMocks([
  MockSpec<LogRepository>(),
])

/// ---------------------------------------------------------------------------
/// (2) In-memory backend : request-path → JSON payload
/// ---------------------------------------------------------------------------
final Map<String, Map<String, dynamic>> fakeBackend = <String, Map<String, dynamic>>{};

/// ---------------------------------------------------------------------------
/// (3) HttpOverrides that always return the fake client
/// ---------------------------------------------------------------------------
class InMemoryOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? _) => _FakeHttpClient();
}

/// ---------------------------------------------------------------------------
/// (4) Very small fake HttpClient – only the surface touched by package:http
/// ---------------------------------------------------------------------------
class _FakeHttpClient extends Fake implements HttpClient {
  Future<HttpClientRequest> _request(Uri uri) async => _FakeRequest(uri);

  @override
  Future<HttpClientRequest> getUrl(Uri uri) => _request(uri);
  @override
  Future<HttpClientRequest> postUrl(Uri uri) => _request(uri);
  @override
  Future<HttpClientRequest> patchUrl(Uri uri) => _request(uri);
  @override
  Future<HttpClientRequest> putUrl(Uri uri) => _request(uri);
  @override
  Future<HttpClientRequest> deleteUrl(Uri uri) => _request(uri);
  @override
  Future<HttpClientRequest> headUrl(Uri uri) => _request(uri);
  @override
  Future<HttpClientRequest> openUrl(String _, Uri uri) => _request(uri);

  @override
  void close({bool force = false}) {}
}

/// ---------------------------------------------------------------------------
/// (5) Fake HttpClientRequest – implements every mutable field that IOClient sets
/// ---------------------------------------------------------------------------
class _FakeRequest extends Fake implements HttpClientRequest {
  _FakeRequest(this.uri);
  final Uri uri;

  /* mutable fields */
  bool _followRedirects = true;
  int _maxRedirects = 5;
  bool _persistentConnection = true;
  bool _autoUncompress = true;
  int _contentLength = 0;
  Encoding _encoding = utf8;

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
  bool get autoUncompress => _autoUncompress;
  @override
  set autoUncompress(bool value) => _autoUncompress = value;

  @override
  int get contentLength => _contentLength;
  @override
  set contentLength(int value) => _contentLength = value;

  @override
  Encoding get encoding => _encoding;
  @override
  set encoding(Encoding value) => _encoding = value;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  /* simplified sink – body building happens in repository */
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
    final _FakeResponse response = _FakeResponse(payload);
    _done.complete(response);
    return response;
  }

  @override
  Future<HttpClientResponse> get done => _done.future;
}

/// ---------------------------------------------------------------------------
/// (6) Fake headers – tiny key/value map
/// ---------------------------------------------------------------------------
class _FakeHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _storage = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _storage[name.toLowerCase()] = <String>[value.toString()];

  @override
  List<String>? operator [](String name) => _storage[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) => _storage.forEach(action);
}

/// ---------------------------------------------------------------------------
/// (7) Fake HttpClientResponse – full Stream<List<int>> implementation
/// ---------------------------------------------------------------------------
class _FakeResponse extends Fake implements HttpClientResponse {
  _FakeResponse(Map<String, dynamic> jsonBody)
      : _bytes = utf8.encode(json.encode(jsonBody)),
        _headers = _FakeHeaders(),
        _stream = Stream<List<int>>.value(
          utf8.encode(json.encode(jsonBody)),
        ) {
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

  /* complete Stream API */
  @override
  bool get isBroadcast => _stream.isBroadcast;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  Stream<List<int>> handleError(
    Function onError, {
    bool Function(dynamic error)? test,
  }) =>
      _stream.handleError(onError, test: test);

  @override
  Stream<R> transform<R>(StreamTransformer<List<int>, R> transformer) => _stream.transform(transformer);

  @override
  Stream<List<int>> timeout(
    Duration timeLimit, {
    void Function(EventSink<List<int>> sink)? onTimeout,
  }) =>
      _stream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<List<int>> asBroadcastStream({
    void Function(StreamSubscription<List<int>> sub)? onListen,
    void Function(StreamSubscription<List<int>> sub)? onCancel,
  }) =>
      _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
}

/// ---------------------------------------------------------------------------
/// (8) Stub UserController – supplies empty accessToken for BaseRepository
/// ---------------------------------------------------------------------------
class StubUserController extends UserController {
  @override
  String? accessToken = '';
  @override
  void onInit() {}
}

/// ---------------------------------------------------------------------------
/// (9) Tests
/// ---------------------------------------------------------------------------
void main() {
  late LogController logController;

  setUpAll(() => HttpOverrides.global = InMemoryOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    Get.testMode = true;
    Get.put<UserController>(StubUserController());
    logController = LogController();
    Get.put<LogController>(logController);
  });

  group('LogController – AAA with debug prints', () {
    test('reqLogList() maps `active` field to RobotLog message', () async {
      debugPrint('\n=== TEST: active field ===');

      /* ─── Arrange ─── */
      debugPrint('ARRANGE ▶ seed fakeBackend for /api/log/list');
      fakeBackend['/api/log/list'] = <String, dynamic>{
        'code': '0000',
        'body': <String, dynamic>{
          'listCount': 1,
          'logList': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'createdTs': DateTime.now().toIso8601String(), // camelCase key
              'active': 1,
            },
          ],
        },
      };
      logController.setSelectedRobotId(0);

      /* ─── Act ─── */
      debugPrint('ACT     ▶ call reqLogList()');
      await logController.reqLogList();

      /* ─── Assert ─── */
      debugPrint('ASSERT  ▶ verify RobotLog contents');
      expect(logController.robotLogs.length, equals(1));
      expect(logController.robotLogs.first.message, equals('활성화 되었습니다.'));
      expect(logController.isSelectedId(1), everyElement(isFalse));
    });
  });
}
