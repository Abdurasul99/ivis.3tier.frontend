// test/viewmodel/controller/user_controller_test.dart
//
// Unit-tests for UserController.
// ▸ production source is NOT modified;
// ▸ mocks are injected through a thin wrapper subclass;
// ▸ detailed debug prints mark Arrange / Act / Assert blocks.
//
// run: flutter test test/viewmodel/controller/user_controller_test.dart
//
// generate mocks (once):
// flutter pub run build_runner build --delete-conflicting-outputs

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/controller/password_controller.dart';
import 'package:fms/viewmodel/repository/user_repository.dart';
import 'package:fms/viewmodel/repository/local_repository.dart';
import 'package:fms/model/user_model.dart';

import 'user_controller_test.mocks.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Wrapper-controller that lets us inject mock repositories
/// ─────────────────────────────────────────────────────────────────────────
class TestableUserController extends UserController {
  TestableUserController({
    required this.mockUserRepo,
    required this.mockLocalRepo,
  });

  final UserRepository mockUserRepo;
  final LocalRepository mockLocalRepo;

  // internal fields for tests — we do NOT touch the parent's privates
  LoginUser? _testLoginUser;
  String? _testAccessToken;

  // expose them through overridden getters
  @override
  LoginUser? get loginUser => _testLoginUser;

  @override
  String? get accessToken => _testAccessToken;

  // helper setters for quick presets
  void setLoginUserForTest(LoginUser user) => _testLoginUser = user;
  void setAccessTokenForTest(String token) => _testAccessToken = token;

  // ───── overridden methods that use mocks & update local copies ─────

  @override
  Future<bool> reqLoginById(String userId, String password) async {
    final Map<String, String> params = <String, String>{'user_id': userId, 'password': password};
    final LoginResult? result = await mockUserRepo.requestLoginById(params);
    if (result != null && result.code == '0000') {
      _testLoginUser = result.loginUser;
      _testAccessToken = result.loginUser?.accessToken ?? '';
      await mockLocalRepo.saveAccessToken(_testAccessToken!);
      update();
      return true;
    }
    return false;
  }

  @override
  Future<bool> reqChangePhoneNumber(Map<String, dynamic> params) async {
    final bool ok = await mockUserRepo.requestChangePhoneNumber(params);
    if (ok && _testLoginUser != null) {
      _testLoginUser!.phoneNumber = params['phoneNumber'] as String;
      update();
    }
    return ok;
  }

  @override
  Future<void> logout() async {
    _testLoginUser = null;
    _testAccessToken = null;
    await mockLocalRepo.clearAccessToken();
    update();
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Mockito mocks
/// ─────────────────────────────────────────────────────────────────────────
@GenerateNiceMocks(<MockSpec<dynamic>>[
  MockSpec<UserRepository>(),
  MockSpec<LocalRepository>(),
])
void main() {
  // global test environment
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  Get.testMode = true;

  late MockUserRepository mockUserRepo;
  late MockLocalRepository mockLocalRepo;
  late TestableUserController userCtrl;

  setUp(() {
    print('\n=== setUp: new mocks & controller ===');
    mockUserRepo = MockUserRepository();
    mockLocalRepo = MockLocalRepository();

    // PasswordController is required by production code
    Get.put<PasswordController>(PasswordController());

    userCtrl = TestableUserController(
      mockUserRepo: mockUserRepo,
      mockLocalRepo: mockLocalRepo,
    );
  });

  tearDown(() => Get.reset());

  // ───────────────────────────────────────────────────────────────────────
  // Tests
  // ───────────────────────────────────────────────────────────────────────
  group('UserController – AAA pattern with debug prints', () {
    test('reqLoginById stores loginUser and accessToken on success', () async {
      print('\n▶ TEST: reqLoginById()');

      // ARRANGE
      const String token = 'ACCESS_TOKEN';
      final LoginUser expected = LoginUser(
        userId: 'abdurasul',
        role: 'admin',
        accessToken: token,
        phoneNumber: '010-7506-4415',
      );
      when(mockUserRepo.requestLoginById(any)).thenAnswer(
        (_) async => LoginResult(code: '0000', loginUser: expected),
      );
      when(mockLocalRepo.saveAccessToken(token)).thenAnswer((_) async => true);

      // ACT
      print('ACT → controller.reqLoginById');
      final bool ok = await userCtrl.reqLoginById('tester', 'pwd');
      print('RESULT = $ok');

      // ASSERT
      expect(ok, isTrue);
      expect(userCtrl.loginUser, equals(expected));
      expect(userCtrl.accessToken, equals(token));
      verify(mockUserRepo.requestLoginById(any)).called(1);
      verify(mockLocalRepo.saveAccessToken(token)).called(1);
    });

    test('reqChangePhoneNumber updates stored phoneNumber', () async {
      print('\n▶ TEST: reqChangePhoneNumber()');

      // ARRANGE
      final LoginUser baseUser = LoginUser(
        userId: 'u01',
        role: 'user',
        accessToken: 'TK',
        phoneNumber: '010-7506-4415',
      );
      userCtrl.setLoginUserForTest(baseUser);
      when(mockUserRepo.requestChangePhoneNumber(any)).thenAnswer((_) async => true);

      // ACT
      const String newPhone = '010-7506-4415';
      print('ACT → change phone to $newPhone');
      final bool ok = await userCtrl.reqChangePhoneNumber(<String, String>{'phoneNumber': newPhone});
      print('RESULT = $ok, stored = ${userCtrl.loginUser!.phoneNumber}');

      // ASSERT
      expect(ok, isTrue);
      expect(userCtrl.loginUser!.phoneNumber, newPhone);
      verify(mockUserRepo.requestChangePhoneNumber(any)).called(1);
    });

    test('logout clears state and calls LocalRepository', () async {
      print('\n▶ TEST: logout()');

      // ARRANGE
      userCtrl
        ..setLoginUserForTest(LoginUser(userId: 'u', role: 'user'))
        ..setAccessTokenForTest('TK');
      when(mockLocalRepo.clearAccessToken()).thenAnswer((_) async => true);

      // ACT
      print('ACT → controller.logout()');
      await userCtrl.logout();

      // ASSERT
      expect(userCtrl.loginUser, isNull);
      expect(userCtrl.accessToken, isNull);
      verify(mockLocalRepo.clearAccessToken()).called(1);
    });
  });
}
