// test/viewmodel/controller/dashboard_controller_test.dart
//
// HTTP-запросы перехватываются через HttpOverrides: любой URL → 200 + [].
// В каждом AAA-блоке стоят debugPrint-маркиры, чтобы видеть ход выполнения.

import 'dart:async'; // StreamSubscription
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fms/model/dashboard_model.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';

/// ░░░ Fake HTTP ░░░
class _DummyOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? ctx) => _DummyHttpClient();
}

class _DummyHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _DummyRequest(url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _DummyRequest(url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => _DummyRequest(url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) async => _DummyRequest(url);
}

class _DummyRequest extends Fake implements HttpClientRequest {
  _DummyRequest(this.url);
  final Uri url;

  @override
  HttpHeaders get headers => _DummyHeaders();

  @override
  Future<HttpClientResponse> close() async {
    debugPrint('FAKE HTTP ▶ ${url.toString()}');
    return _DummyResponse();
  }
}

class _DummyHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _store = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _store.putIfAbsent(name, () => <String>[]).add(value.toString());
  }
}

class _DummyResponse extends Fake implements HttpClientResponse {
  final List<int> _body = utf8.encode('[]');
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

/// ░░░ Тесты ░░░
void main() {
  late DashboardController controller;

  setUpAll(() {
    HttpOverrides.global = _DummyOverrides(); // режем сеть
  });

  tearDownAll(() {
    HttpOverrides.global = null; // возвращаем, как было
  });

  setUp(() {
    Get.testMode = true;
    debugPrint('SETUP ▶ DI UserController');
    Get.put<UserController>(UserController());
    controller = DashboardController();
  });

  group('DashboardController – e2e with fake HTTP', () {
    test('reqDashboardLayoutSetting completes without error', () async {
      debugPrint('ACT ▶ reqDashboardLayoutSetting');
      await controller.reqDashboardLayoutSetting();

      debugPrint('ASSERT ▶ isLoading=${controller.isLoading}');
      expect(controller.isLoading, false);
    });

    test('saveLayouts completes and returns bool', () async {
      debugPrint('ACT ▶ saveLayouts');
      final bool ok = await controller.saveLayouts();

      debugPrint('ASSERT ▶ result=$ok');
      expect(ok, isA<bool>());
    });

    test('clearLayouts empties list', () {
      debugPrint('ARRANGE ▶ add one LayoutSet');
      controller.layoutSets.assignAll(<LayoutSet>[LayoutSet()]); // тип безопасный

      debugPrint('ACT ▶ clearLayouts');
      controller.clearLayouts();

      debugPrint('ASSERT ▶ isEmpty=${controller.layoutSets.isEmpty}');
      expect(controller.layoutSets.isEmpty, true);
    });
  });
}
