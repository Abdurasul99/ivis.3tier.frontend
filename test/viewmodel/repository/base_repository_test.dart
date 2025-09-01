// test/repository/base_repository_test.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/repository/base_repository.dart';

// Fake controller for GetX, overrides only accessToken, other calls handled by noSuchMethod
class FakeUserController extends GetxController implements UserController {
  @override
  String? accessToken;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late BaseRepository repo;
  late FakeUserController fakeUserCtrl;

  setUp(() {
    Get.reset();
    debugPrint('SETUP: Reset GetX and register FakeUserController');
    repo = BaseRepository();
    fakeUserCtrl = FakeUserController();
    Get.put<UserController>(fakeUserCtrl, permanent: true);
  });

  test('getHeader without token returns only Content-Type header', () {
    debugPrint('TEST: getHeader without token – Arrange');
    fakeUserCtrl.accessToken = null;

    debugPrint('TEST: getHeader without token – Act');
    final headers = repo.getHeader(includeToken: true);

    debugPrint('TEST: getHeader without token – Assert');
    expect(headers, {'Content-Type': 'application/json; charset=utf-8'});
  });

  test('getHeader with token adds x-access-token header', () {
    debugPrint('TEST: getHeader with token – Arrange');
    fakeUserCtrl.accessToken = 'token-123';

    debugPrint('TEST: getHeader with token – Act');
    final headers = repo.getHeader(includeToken: true);

    debugPrint('TEST: getHeader with token – Assert');
    expect(
      headers,
      {
        'Content-Type': 'application/json; charset=utf-8',
        'x-access-token': 'token-123',
      },
    );
  });

  test('handleResponse throws on non-200 status', () {
    debugPrint('TEST: handleResponse error status – Arrange');
    final badResponse = http.Response('error', 404);

    debugPrint('TEST: handleResponse error status – Act & Assert');
    expect(
      () => repo.handleResponse(badResponse, (json) => json),
      throwsA(isA<Exception>()),
    );
  });

  test('handleResponse parses JSON and returns callback result', () {
    debugPrint('TEST: handleResponse OK status – Arrange');
    final jsonBody = jsonEncode({
      'body': {'foo': 'bar'}
    });
    final okResponse = http.Response(jsonBody, 200);

    debugPrint('TEST: handleResponse OK status – Act');
    final result = repo.handleResponse(okResponse, (json) => json['body']['foo']);

    debugPrint('TEST: handleResponse OK status – Assert');
    expect(result, 'bar');
  });
}
