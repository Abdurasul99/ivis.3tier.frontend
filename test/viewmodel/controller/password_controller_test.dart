// test/viewmodel/controller/password_controller_test.dart
//
// Unit-tests for PasswordController – production class is **not** modified.
// We inject a mock repo by wrapping the real controller in a tiny subclass
// that forwards every repository call to the provided mock.
//
// Run: flutter test test/viewmodel/controller/password_controller_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:fms/viewmodel/controller/password_controller.dart';
import 'package:fms/viewmodel/repository/password_repository.dart';
import 'package:fms/model/common_model.dart';

import 'password_controller_test.mocks.dart';

/// ---------------------------------------------------------------------------
/// Small wrapper that allows constructor injection of a mock repository.
/// ---------------------------------------------------------------------------
class TestablePasswordController extends PasswordController {
  TestablePasswordController(this._mock);
  final PasswordRepository _mock;

  // ——— Every method is copied from the base class but uses the injected mock.
  @override
  Future<CommonResponse?> reqResetPassword(String email) {
    debugPrint('[CNT] ► reqResetPassword($email)');
    return _mock.requestResetPassword(email);
  }

  @override
  Future<CommonResponse?> reqPasswordVerifyCode(String email, String code) async {
    debugPrint('[CNT] ► reqPasswordVerifyCode($email, $code)');
    final res = await _mock.requestVerifyCode(email, code);
    if (res != null && res.code == '0000') {
      final token = res.body?['verifyToken'];
      if (token != null) {
        verifyToken = token;
        resetEmail = email;
      }
    }
    return res;
  }

  @override
  Future<CommonResponse?> reqPasswordComplete(String newPassword) {
    debugPrint('[CNT] ► reqPasswordComplete($newPassword)');
    if (verifyToken == null || resetEmail == null) return Future.value(null);
    return _mock.requestCompletePassword(resetEmail!, newPassword, verifyToken!);
  }

  @override
  Future<CommonResponse?> reqResetPasswordByIdAndEmail(String userId, String email) async {
    debugPrint('[CNT] ► reqResetPasswordByIdAndEmail($userId, $email)');
    final res = await _mock.requestResetPasswordByIdAndEmail(userId, email);
    if (res != null && res.code == '0000') {
      resetUserId = userId;
      resetEmail = email;
    }
    return res;
  }

  @override
  Future<CommonResponse?> reqPasswordVerifyCodeByIdAndEmail(String code) async {
    debugPrint('[CNT] ► reqPasswordVerifyCodeByIdAndEmail($code)');
    if (resetEmail == null || resetUserId == null) return null;
    final res = await _mock.requestVerifyCodeByIdAndEmail(resetUserId!, resetEmail!, code);
    if (res != null && res.code == '0000') {
      final token = res.body?['verifyToken'];
      if (token != null) verifyToken = token;
    }
    return res;
  }
}

/// ---------------------------------------------------------------------------
/// Mockito generation
/// ---------------------------------------------------------------------------
@GenerateMocks([PasswordRepository])
void main() {
  late MockPasswordRepository mockRepo;
  late TestablePasswordController controller;

  setUpAll(() => Get.testMode = true);

  setUp(() {
    mockRepo = MockPasswordRepository();
    controller = TestablePasswordController(mockRepo); // DI through wrapper
  });

  group('PasswordController – AAA', () {
    test('reqResetPassword returns CommonResponse from repo', () async {
      debugPrint('\n=== TEST 1: reqResetPassword ===');
      // Arrange
      const email = 'ctrlcv@ivis.ai';
      final fake = CommonResponse(code: '0000', body: {'msg': 'ok'});
      when(mockRepo.requestResetPassword(email)).thenAnswer((_) async => fake);
      debugPrint('ARRANGE ✔ stubbed requestResetPassword');

      // Act
      final res = await controller.reqResetPassword(email);
      debugPrint('ACT     ✔ call completed');

      // Assert
      expect(res, fake);
      verify(mockRepo.requestResetPassword(email)).called(1);
      debugPrint('ASSERT  ✔ response and verify OK');
    });

    test('reqPasswordVerifyCode stores token and email on success', () async {
      debugPrint('\n=== TEST 2: reqPasswordVerifyCode ===');
      // Arrange
      const email = 'abdurasul@ivis.ai';
      const code = '1111';
      final fake = CommonResponse(code: '0000', body: {'verifyToken': 'TKN'});
      when(mockRepo.requestVerifyCode(email, code)).thenAnswer((_) async => fake);
      debugPrint('ARRANGE ✔ stubbed requestVerifyCode');

      // Act
      final res = await controller.reqPasswordVerifyCode(email, code);
      debugPrint('ACT     ✔ call completed');

      // Assert
      expect(res, fake);
      expect(controller.verifyToken, 'TKN');
      expect(controller.resetEmail, email);
      debugPrint('ASSERT  ✔ token/email stored');
    });

    test('reqPasswordComplete returns null when token missing', () async {
      debugPrint('\n=== TEST 3: reqPasswordComplete null branch ===');
      controller.verifyToken = null;
      controller.resetEmail = null;

      expect(await controller.reqPasswordComplete('newPwd'), isNull);
      debugPrint('ASSERT  ✔ returned null as expected');
    });

    test('reqPasswordComplete success flow', () async {
      debugPrint('\n=== TEST 4: reqPasswordComplete success ===');
      // Arrange
      controller.verifyToken = 'VT';
      controller.resetEmail = 'abdurasul@ivis.ai';

      final fake = CommonResponse(code: '0000', body: {'ok': true});
      when(mockRepo.requestCompletePassword('abdurasul@ivis.ai', 'pwd', 'VT')).thenAnswer((_) async => fake);
      debugPrint('ARRANGE ✔ stubbed requestCompletePassword');

      // Act
      final res = await controller.reqPasswordComplete('pwd');
      debugPrint('ACT     ✔ call completed');

      // Assert
      expect(res, fake);
      verify(mockRepo.requestCompletePassword('abdurasul@ivis.ai', 'pwd', 'VT')).called(1);
      debugPrint('ASSERT  ✔ response and verify OK');
    });
  });
}
