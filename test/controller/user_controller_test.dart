// test/controller/user_controller_test.dart
// UserController 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
// HTTP·SharedPreferences 호출이 없는 순수 로직만 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/user_model.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(UserController());
  });

  tearDown(() {
    Get.deleteAll();
  });

  // ─────────────────────────────────────────────
  // 초기 상태
  // ─────────────────────────────────────────────
  group('초기 상태', () {
    test('컨트롤러 생성 직후 기본값 확인', () {
      // Arrange — setUp에서 등록됨
      final UserController ctrl = Get.find<UserController>();

      // Act (별도 호출 없음)

      // Assert
      expect(ctrl.loginUser, isNull);
      expect(ctrl.accessToken, isNull);
      expect(ctrl.foundUserId, '');
      expect(ctrl.foundJoinDate, '');
    });
  });

  // ─────────────────────────────────────────────
  // isAdminUser — 역할 검사 로직
  // ─────────────────────────────────────────────
  group('isAdminUser', () {
    test('role이 "admin"이면 true 반환', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      ctrl.loginUserForTest = LoginUser(
        id: 1,
        userId: 'adminUser',
        role: 'admin',
      );

      // Act
      final bool result = ctrl.isAdminUser();

      // Assert
      expect(result, isTrue);
    });

    test('role이 "user"이면 false 반환', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      ctrl.loginUserForTest = LoginUser(
        id: 2,
        userId: 'normalUser',
        role: 'user',
      );

      // Act
      final bool result = ctrl.isAdminUser();

      // Assert
      expect(result, isFalse);
    });

    test('loginUser가 null이면 false 반환', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      // loginUser는 기본 null

      // Act
      final bool result = ctrl.isAdminUser();

      // Assert
      expect(result, isFalse);
    });

    test('role이 null이면 false 반환', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      ctrl.loginUserForTest = LoginUser(id: 3, role: null);

      // Act
      final bool result = ctrl.isAdminUser();

      // Assert
      expect(result, isFalse);
    });

    test('role이 대소문자 다르면(Admin) false 반환 — 엄격 비교', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      ctrl.loginUserForTest = LoginUser(id: 4, role: 'Admin');

      // Act
      final bool result = ctrl.isAdminUser();

      // Assert
      expect(result, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // accessToken 상태 확인
  // ─────────────────────────────────────────────
  group('accessToken', () {
    test('토큰 설정 후 accessToken getter가 값 반환', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      ctrl.accessTokenForTest = 'test_token_abc';

      // Act
      final String? token = ctrl.accessToken;

      // Assert
      expect(token, 'test_token_abc');
    });

    test('토큰 없을 때 accessToken은 null', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      // 기본 상태 — 토큰 없음

      // Act
      final String? token = ctrl.accessToken;

      // Assert
      expect(token, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // ensureAccessTokenLoaded — 이미 토큰이 있는 경우
  // ─────────────────────────────────────────────
  group('ensureAccessTokenLoaded', () {
    test('토큰이 이미 있으면 SharedPreferences 없이 true 반환', () async {
      // Arrange
      final UserController ctrl = Get.find<UserController>();
      ctrl.accessTokenForTest = 'already_loaded_token';

      // Act
      final bool result = await ctrl.ensureAccessTokenLoaded();

      // Assert
      expect(result, isTrue);
    });
  });

  // ─────────────────────────────────────────────
  // foundUserId / foundJoinDate — ID 찾기 결과 저장
  // ─────────────────────────────────────────────
  group('foundUserId / foundJoinDate', () {
    test('값을 직접 설정하면 getter가 반환', () {
      // Arrange
      final UserController ctrl = Get.find<UserController>();

      // Act
      ctrl.foundUserId = 'found_user_01';
      ctrl.foundJoinDate = '2023-05-15';

      // Assert
      expect(ctrl.foundUserId, 'found_user_01');
      expect(ctrl.foundJoinDate, '2023-05-15');
    });
  });
}

// UserController에 @visibleForTesting setter가 정의되어 있음:
//   set loginUserForTest(LoginUser? user)
//   set accessTokenForTest(String? token)
// 별도 extension 불필요
