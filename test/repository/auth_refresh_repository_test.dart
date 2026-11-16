// test/repository/auth_refresh_repository_test.dart
//
// Session handling of the API layer (http is mocked, no server is contacted):
//   1. a server outage / network error never wipes the stored tokens, a refused token does
//   2. every authenticated call refreshes on 401 and retries; concurrent 401s refresh once
//   3. infra id 0 is a valid id
//   4. 4xx envelopes (wrong password, admin-only 403) come back as clear failures

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/repository/base_repository.dart';
import 'package:ivis/viewmodel/repository/infra_repository.dart';
import 'package:ivis/viewmodel/repository/map_repository.dart';
import 'package:ivis/viewmodel/repository/member_repository.dart';
import 'package:ivis/viewmodel/repository/object_repository.dart';
import 'package:ivis/viewmodel/repository/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _oldAccess = 'old-access';
const String _newAccess = 'new-access';
const String _refresh = 'stored-refresh';

const String _loginByTokenPath = '/api/users/signInByToken';
const String _refreshPath = '/api/users/accessToken';

http.Response _json(int status, Map<String, dynamic> payload) =>
    http.Response.bytes(utf8.encode(jsonEncode(payload)), status,
        headers: <String, String>{'content-type': 'application/json; charset=utf-8'});

http.Response _envelope(int status, String code, {dynamic body}) => _json(status, <String, dynamic>{
      'code': code,
      'message': 'm$code',
      'additionalMessage': '',
      'body': body,
    });

http.Response _refreshOk() => _envelope(200, '0000', body: <String, dynamic>{'accessToken': _newAccess});

http.Response _loginOk(String token) => _envelope(200, '0000', body: <String, dynamic>{
      'id': 7,
      'userId': 'tester',
      'role': 'user',
      'accessToken': token,
      'refreshToken': _refresh,
    });

Future<T> _withHttp<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() body,
) {
  return http.runWithClient(body, () => MockClient(handler));
}

Future<String?> _stored(String key) async => (await SharedPreferences.getInstance()).getString(key);

void main() {
  late UserController userController;
  late int sessionExpiredCalls;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessToken': _oldAccess,
      'refreshToken': _refresh,
    });
    userController = Get.put(UserController());
    sessionExpiredCalls = 0;
    BaseRepository.onSessionExpired = () => sessionExpiredCalls++;
  });

  tearDown(() {
    BaseRepository.onSessionExpired = null;
    Get.reset();
  });

  group('reqLoginByToken keeps the session when the server is unreachable', () {
    test('HTTP 500 at page load: false, tokens kept', () async {
      final bool result = await _withHttp(
        (http.Request request) async => http.Response('boom', 500),
        () => userController.reqLoginByToken(),
      );

      expect(result, isFalse);
      expect(userController.lastSessionCheckUnreachable, isTrue);
      expect(await _stored('accessToken'), _oldAccess);
      expect(await _stored('refreshToken'), _refresh);
    });

    test('network error at page load: false, tokens kept', () async {
      final bool result = await _withHttp(
        (http.Request request) async => throw http.ClientException('connection refused'),
        () => userController.reqLoginByToken(),
      );

      expect(result, isFalse);
      expect(userController.lastSessionCheckUnreachable, isTrue);
      expect(await _stored('accessToken'), _oldAccess);
      expect(await _stored('refreshToken'), _refresh);
    });

    test('access token expired but the refresh call hits a 503: tokens kept', () async {
      final bool result = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _loginByTokenPath) return _envelope(401, '401');
          return http.Response('unavailable', 503);
        },
        () => userController.reqLoginByToken(),
      );

      expect(result, isFalse);
      expect(userController.lastSessionCheckUnreachable, isTrue);
      expect(await _stored('accessToken'), _oldAccess);
      expect(await _stored('refreshToken'), _refresh);
    });

    test('both tokens refused by the server: session cleared', () async {
      final bool result = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _loginByTokenPath) return _envelope(401, '401');
          return _envelope(400, '8033'); // refresh token expired
        },
        () => userController.reqLoginByToken(),
      );

      expect(result, isFalse);
      expect(userController.lastSessionCheckUnreachable, isFalse);
      expect(userController.accessToken, isNull);
      expect(await _stored('accessToken'), isNull);
      expect(await _stored('refreshToken'), isNull);
    });

    test('access token expired, refresh succeeds: logged in with the new token', () async {
      final bool result = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _refreshPath) return _refreshOk();
          final String token = request.headers['x-access-token'] ?? '';
          return token == _newAccess ? _loginOk(_newAccess) : _envelope(401, '401');
        },
        () => userController.reqLoginByToken(),
      );

      expect(result, isTrue);
      expect(userController.accessToken, _newAccess);
      expect(userController.loginUser?.userId, 'tester');
      expect(await _stored('accessToken'), _newAccess);
    });
  });

  group('401 refresh-and-retry', () {
    test('refresh fails with 5xx: session kept, no redirect', () async {
      userController.accessTokenForTest = _oldAccess;

      final result = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _refreshPath) return http.Response('bad gateway', 502);
          return _envelope(401, '401');
        },
        () => ObjectRepository().requestByVehicleInfo(vehicleId: 0),
      );

      expect(result, isNull);
      expect(sessionExpiredCalls, 0);
      expect(userController.accessToken, _oldAccess);
      expect(await _stored('refreshToken'), _refresh);
    });

    test('refresh token refused: logged out and redirected once', () async {
      userController.accessTokenForTest = _oldAccess;

      await _withHttp(
        (http.Request request) async {
          if (request.url.path == _refreshPath) return _envelope(400, '8033');
          return _envelope(401, '401');
        },
        () => Future.wait(<Future<dynamic>>[
          ObjectRepository().requestByVehicleInfo(vehicleId: 0),
          ObjectRepository().requestByInfraInfo(infraId: 0),
        ]),
      );

      expect(sessionExpiredCalls, 1);
      expect(userController.accessToken, isNull);
      expect(await _stored('refreshToken'), isNull);
    });

    test('concurrent 401s from different repositories trigger a single refresh', () async {
      userController.accessTokenForTest = _oldAccess;
      int refreshCalls = 0;
      final List<String> retriedPaths = <String>[];

      final List<dynamic> results = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _refreshPath) {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return _refreshOk();
          }
          if (request.headers['x-access-token'] != _newAccess) {
            // The member list answers late: its 401 arrives after the refresh has finished.
            if (request.url.path == '/api/member/Member') {
              await Future<void>.delayed(const Duration(milliseconds: 80));
            }
            return _envelope(401, '401');
          }
          retriedPaths.add(request.url.path);
          return _envelope(200, '0000', body: <dynamic>[]);
        },
        () => Future.wait(<Future<dynamic>>[
          ObjectRepository().requestByVehicleInfo(vehicleId: 0),
          ObjectRepository().requestByInfraInfo(infraId: 0),
          MemberRepository().requestUnApprovedMemberList(),
          MemberRepository().requestMemberList(),
        ]),
      );

      expect(refreshCalls, 1);
      expect(retriedPaths, hasLength(4));
      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(sessionExpiredCalls, 0);
      expect(userController.accessToken, _newAccess);
      expect(await _stored('accessToken'), _newAccess);
    });

    test('map calls are retried with the new token', () async {
      userController.accessTokenForTest = _oldAccess;
      int refreshCalls = 0;

      final List<http.Response> responses = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _refreshPath) {
            refreshCalls++;
            return _refreshOk();
          }
          if (request.headers['x-access-token'] != _newAccess) return _envelope(401, '401');
          return _envelope(200, '0000', body: <dynamic>[]);
        },
        () => Future.wait(<Future<http.Response>>[
          MapRepository().requestVehicleStatus(10),
          MapRepository().requestInfraStatus(10),
          MapRepository().requestInfraObjects(0),
        ]),
      );

      expect(refreshCalls, 1);
      expect(responses.map((http.Response r) => r.statusCode), everyElement(200));
    });

    test('PATCH and DELETE member calls are retried with the new token', () async {
      userController.accessTokenForTest = _oldAccess;
      final List<String> okMethods = <String>[];

      final List<bool> results = await _withHttp(
        (http.Request request) async {
          if (request.url.path == _refreshPath) return _refreshOk();
          if (request.headers['x-access-token'] != _newAccess) return _envelope(401, '401');
          okMethods.add(request.method);
          return _envelope(200, '0000');
        },
        () async => <bool>[
          await MemberRepository().requestChangeRole(3, 'user'),
          await MemberRepository().requestDeleteMember(3),
        ],
      );

      expect(results, <bool>[true, true]);
      expect(okMethods, <String>['PATCH', 'DELETE']);
    });
  });

  group('4xx envelopes', () {
    test('admin-only 403 is a plain failure: no exception, session kept', () async {
      userController.accessTokenForTest = _oldAccess;

      final List<dynamic> results = await _withHttp(
        (http.Request request) async => _envelope(403, '4030'),
        () async => <dynamic>[
          await MemberRepository().requestApproveMember(1),
          await MemberRepository().requestRejectMember(1),
          await MemberRepository().requestChangeRole(1, 'user'),
          await MemberRepository().requestDeleteMember(1),
          await MemberRepository().requestMemberList(),
        ],
      );

      expect(results.sublist(0, 4), <bool>[false, false, false, false]);
      expect(results[4], isEmpty);
      expect(sessionExpiredCalls, 0);
      expect(userController.accessToken, _oldAccess);
    });

    test('login: wrong password (HTTP 400, code 8003) reaches the caller', () async {
      final bool ok = await _withHttp(
        (http.Request request) async => _envelope(400, '8003'),
        () => userController.reqLoginById('tester', 'wrong'),
      );

      expect(ok, isFalse);
      expect(userController.lastLoginErrorCode, '8003');
      expect(userController.lastLoginErrorMessage, 'm8003');
    });

    test('login: unreachable server leaves no error code', () async {
      final bool ok = await _withHttp(
        (http.Request request) async => http.Response('boom', 500),
        () => userController.reqLoginById('tester', 'pw'),
      );

      expect(ok, isFalse);
      expect(userController.lastLoginErrorCode, isNull);
    });

    test('change password: code 8003 with HTTP 400 gives "wrong password"', () async {
      userController.accessTokenForTest = _oldAccess;

      final String result = await _withHttp(
        (http.Request request) async => _envelope(400, '8003'),
        () => UserRepository().requestChangePassword(<String, dynamic>{'password': 'x'}),
      );

      expect(result, 'wrong password');
    });
  });

  group('infra identifiers', () {
    test('id 0 is kept (list body)', () async {
      userController.accessTokenForTest = _oldAccess;

      final List<int> ids = await _withHttp(
        (http.Request request) async => _envelope(200, '0000', body: <dynamic>[0, 5, '255', -1]),
        () => InfraRepository().requestInfraIdentifiers(),
      );

      expect(ids, <int>[0, 5, 255]);
    });

    test('id 0 is kept (map body)', () async {
      userController.accessTokenForTest = _oldAccess;

      final List<int> ids = await _withHttp(
        (http.Request request) async => _envelope(200, '0000', body: <String, dynamic>{
          'items': <dynamic>[0, 17],
        }),
        () => InfraRepository().requestInfraIdentifiers(),
      );

      expect(ids, <int>[0, 17]);
    });
  });
}
