// test/viewmodel/repository/notification_repository_test.dart
//
// NotificationRepository 단위 테스트 – addStream() 포함 완전판
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/model/notification_model.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/notification_repository.dart';

//
// ────────── Fake HTTP 스텁 ──────────
//

class FakeHttpResponseData {
  final int statusCode;
  final List<int> bodyBytes;
  FakeHttpResponseData({required this.statusCode, required Map<String, dynamic> body})
      : bodyBytes = utf8.encode(jsonEncode(body));
}

/// 최소 HttpHeaders – set() 구현
class _MinimalHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  void forEach(void Function(String, List<String>) action) => _map.forEach(action);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// FakeHttpClientRequest – addStream 등 IOSink 메서드 추가
class FakeHttpClientRequest implements HttpClientRequest {
  FakeHttpClientRequest(this._resp, this._uri);

  final FakeHttpResponseData _resp;
  final Uri _uri;

  // 필수 속성 --------------------------------------------------
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

  @override
  final HttpHeaders headers = _MinimalHeaders();
  String _method = 'GET';
  set methodOverride(String m) => _method = m;
  @override
  String get method => _method;
  @override
  Uri get uri => _uri;

  // IOSink ----------------------------------------------------
  @override
  void add(List<int> data) {/* body 무시 */}
  @override
  void addError(Object error, [StackTrace? st]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {/* 👉 NEW */}
  @override
  Future<void> flush() async {/* 👉 NEW */}
  @override
  void write(Object? obj) {}
  @override
  void writeln([Object? obj = '']) {}
  @override
  void writeAll(Iterable objs, [String sep = '']) {}
  @override
  void writeCharCode(int code) {}

  // 닫기 -------------------------------------------------------
  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(_resp);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// FakeHttpClientResponse
class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeHttpClientResponse(this._resp);
  final FakeHttpResponseData _resp;

  @override
  int get statusCode => _resp.statusCode;
  @override
  int get contentLength => _resp.bodyBytes.length;
  @override
  HttpHeaders get headers => _MinimalHeaders();
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];
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
  }) =>
      Stream<List<int>>.fromIterable(<List<int>>[_resp.bodyBytes]).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError ?? false,
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// FakeHttpClient
class FakeHttpClient implements HttpClient {
  FakeHttpClient(this._map);
  final Map<Uri, FakeHttpResponseData> _map;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final FakeHttpResponseData hit = _map[url]!;
    return FakeHttpClientRequest(hit, url)..methodOverride = method;
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// HttpOverrides
class TestOverrides extends HttpOverrides {
  TestOverrides(this._map);
  final Map<Uri, FakeHttpResponseData> _map;
  @override
  HttpClient createHttpClient(SecurityContext? ctx) => FakeHttpClient(_map);
}

/// 최소 UserController
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken = 'dummy';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

//
// ────────── 테스트 ──────────
//
void main() {
  late NotificationRepository repository;

  setUpAll(() {
    Get.testMode = true;
    Get.put<UserController>(FakeUserController(), permanent: true);
  });

  group('NotificationRepository – 네트워크 호출', () {
    test('requestNotifications() – 200 OK', () async {
      final Uri url = Uri.http(
        kApiServer,
        '/api/notification/list',
        {'limit': '$kNotificationListLimit', 'offset': '0'},
      );
      HttpOverrides.global = TestOverrides({
        url: FakeHttpResponseData(statusCode: 200, body: {
          'body': {
            'notificationListCount': 1,
            'notificationList': [
              {'id': 1, 'alarm_type': 'INFO', 'comment': '테스트', 'created_ts': '2025-07-01', 'is_unread': 0}
            ]
          }
        })
      });

      repository = NotificationRepository();
      final NotificationResult? res = await repository.requestNotifications(null, null, 0);
      expect(res, isNotNull);
      expect(res!.totalCount, 1);
      expect(res.notifications.length, 1);
    });

    test('requestReadNotification() – 200 OK', () async {
      final Uri url = Uri.http(kApiServer, '/api/notification/read');
      HttpOverrides.global = TestOverrides({
        url: FakeHttpResponseData(statusCode: 200, body: {'body': {}})
      });

      repository = NotificationRepository();
      final bool ok = await repository.requestReadNotification(7);
      expect(ok, isTrue);
    });

    test('requestUnreadNotifications() – 200 OK', () async {
      final Uri url = Uri.http(kApiServer, '/api/notification/unread/list');
      HttpOverrides.global = TestOverrides({
        url: FakeHttpResponseData(statusCode: 200, body: {
          'body': [
            {'id': 1, 'alarm_type': 'INFO', 'comment': 'A', 'created_ts': '2025-07-02', 'is_unread': 1},
            {'id': 2, 'alarm_type': 'WARN', 'comment': 'B', 'created_ts': '2025-07-02', 'is_unread': 1},
          ]
        })
      });

      repository = NotificationRepository();
      final List<NotificationItem> list = await repository.requestUnreadNotifications();
      expect(list.length, 2);
    });

    test('requestUnreadNotificationCount() – 200 OK', () async {
      final Uri url = Uri.http(kApiServer, '/api/notification/unread/count');
      HttpOverrides.global = TestOverrides({
        url: FakeHttpResponseData(statusCode: 200, body: {'body': 5})
      });

      repository = NotificationRepository();
      final int? count = await repository.requestUnreadNotificationCount();
      expect(count, 5);
    });
  });
}
