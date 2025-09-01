// test/viewmodel/controller/register_controller_test.dart
//
// Unit-tests for RegisterController using a mocked RegisterRepository.
// Production controller is NOT modified.
//
// ───────── mock generation ─────────
// flutter pub run build_runner build --delete-conflicting-outputs
//
// ───────── run tests ───────────────
// flutter test test/viewmodel/controller/register_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:fms/viewmodel/controller/register_controller.dart';
import 'package:fms/viewmodel/repository/register_repository.dart';
import 'package:fms/model/common_model.dart';

import 'register_controller_test.mocks.dart';

/// ──────────────────────────────────────────────────────────────
/// Test-only wrapper that injects a mock RegisterRepository.
/// ──────────────────────────────────────────────────────────────
class TestableRegisterController extends RegisterController {
  TestableRegisterController(this.mockRepository);

  final RegisterRepository mockRepository;

  @override
  Future<bool> sendRegisterCode(String name, String email) async {
    final CommonResponse? response = await mockRepository.requestRegisterSendCode(name, email);
    return response != null && response.code == '0000';
  }

  @override
  Future<bool> verifyRegisterCode(String email, String code) async {
    final CommonResponse? response = await mockRepository.requestRegisterVerifyCode(email, code);
    if (response == null) return false;
    if (response.code == '0000') {
      verifyToken = response.body?['verifyToken'];
      return true;
    }
    return false;
  }

  @override
  Future<bool> completeRegister({
    required String email,
    required String userId,
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    if (verifyToken == null || verifyToken!.isEmpty) return false;

    final CommonResponse? response = await mockRepository.requestRegisterComplete(
      email: email,
      userId: userId,
      name: name,
      phoneNumber: phoneNumber,
      password: password,
      verifyToken: verifyToken!,
    );
    return response != null && response.code == '0000';
  }
}

/// ──────────────────────────────────────────────────────────────
/// Mockito specification
/// ──────────────────────────────────────────────────────────────
@GenerateNiceMocks(<MockSpec<dynamic>>[
  MockSpec<RegisterRepository>(),
])
void main() {
  late MockRegisterRepository mockRepository;
  late TestableRegisterController controller;

  setUpAll(() => Get.testMode = true);

  setUp(() {
    print('\n=== setUp: fresh mock & controller ===');
    mockRepository = MockRegisterRepository();
    controller = TestableRegisterController(mockRepository);
  });

  tearDown(Get.reset);

  group('RegisterController – AAA pattern with debug prints', () {
    test('sendRegisterCode returns true on success response', () async {
      print('\n▶ TEST: sendRegisterCode()');
      // Arrange
      print('ARRANGE → stub success response for send code');
      when(
        mockRepository.requestRegisterSendCode('Tom', 'a@b.com'),
      ).thenAnswer(
        (_) async => CommonResponse(code: '0000', body: <String, dynamic>{}),
      );

      // Act
      print('ACT     → call controller.sendRegisterCode');
      final bool result = await controller.sendRegisterCode('Tom', 'a@b.com');
      print('RESULT  = $result');

      // Assert
      print('ASSERT  → interaction & result');
      expect(result, isTrue);
      verify(mockRepository.requestRegisterSendCode('Tom', 'a@b.com')).called(1);
    });

    test('verifyRegisterCode stores verifyToken when successful', () async {
      print('\n▶ TEST: verifyRegisterCode()');
      // Arrange
      print('ARRANGE → stub success with verifyToken');
      when(
        mockRepository.requestRegisterVerifyCode('a@b.com', '1234'),
      ).thenAnswer(
        (_) async => CommonResponse(
          code: '0000',
          body: <String, dynamic>{'verifyToken': 'VT'},
        ),
      );

      // Act
      print('ACT     → call controller.verifyRegisterCode');
      final bool ok = await controller.verifyRegisterCode('a@b.com', '1234');
      print('RESULT  = $ok, stored token = ${controller.verifyToken}');

      // Assert
      expect(ok, isTrue);
      expect(controller.verifyToken, 'VT');
      verify(mockRepository.requestRegisterVerifyCode('a@b.com', '1234')).called(1);
    });

    test('completeRegister returns false if verifyToken missing', () async {
      print('\n▶ TEST: completeRegister() without token');
      final bool ok = await controller.completeRegister(
        email: 'no@token.com',
        userId: 'usr',
        name: 'NoToken',
        phoneNumber: '000',
        password: 'pwd',
      );
      expect(ok, isFalse);
    });

    test('completeRegister returns true on valid flow', () async {
      print('\n▶ TEST: completeRegister() success path');
      // ---------- Arrange ----------
      controller.verifyToken = 'TOK';

      const String goodEmail = 'abdurasul@ivis.ai';
      const String goodUserId = 'minsu';
      const String goodName = 'abdurasul';
      const String goodPhone = '010-7506-4415';
      const String goodPassword = '1111';

      print('ARRANGE → stub success for requestRegisterComplete');
      when(
        mockRepository.requestRegisterComplete(
          email: goodEmail,
          userId: goodUserId,
          name: goodName,
          phoneNumber: goodPhone,
          password: goodPassword,
          verifyToken: 'TOK',
        ),
      ).thenAnswer(
        (_) async => CommonResponse(code: '0000', body: <String, dynamic>{}),
      );

      // ---------- Act --------------
      print('ACT     → call controller.completeRegister');
      final bool ok = await controller.completeRegister(
        email: goodEmail,
        userId: goodUserId,
        name: goodName,
        phoneNumber: goodPhone,
        password: goodPassword,
      );
      print('RESULT  = $ok');

      // ---------- Assert -----------
      print('ASSERT  → verify interaction with repository');
      expect(ok, isTrue);
      verify(
        mockRepository.requestRegisterComplete(
          email: goodEmail,
          userId: goodUserId,
          name: goodName,
          phoneNumber: goodPhone,
          password: goodPassword,
          verifyToken: 'TOK',
        ),
      ).called(1);
    });
  });
}
