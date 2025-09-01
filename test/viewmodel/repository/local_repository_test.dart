// ────────────────────────────────────────────────────────────────────────────
// LocalRepository 단위 테스트
//  • SharedPreferences.setMockInitialValues() 로 메모리 저장소 구성
//  • AAA(Arrange-Act-Assert) 패턴 + debugPrint 로 흐름 확인
//  • 식별자는 ASCII, 주석은 한국어
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fms/viewmodel/repository/local_repository.dart';

void main() {
  late LocalRepository localRepositoryUnderTest;

  // ───────── 공통 셋업 ─────────
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    localRepositoryUnderTest = LocalRepository();
  });

  group('LocalRepository – SharedPreferences 저장/조회', () {
    test('accessToken 저장 후 조회', () async {
      // Arrange
      const String expectedAccessToken = 'abc123token';
      debugPrint('[Arrange] accessToken 값 설정: $expectedAccessToken');

      // Act
      await localRepositoryUnderTest.saveAccessToken(expectedAccessToken);
      final String actualAccessToken = await localRepositoryUnderTest.getAccessToken();
      debugPrint('[Act] accessToken 조회 결과: $actualAccessToken');

      // Assert
      expect(actualAccessToken, expectedAccessToken);
    });

    test('rememberMe true/false 저장 및 조회', () async {
      // Arrange
      const bool expectedTrue = true;
      const bool expectedFalse = false;

      // Act & Assert (true)
      await localRepositoryUnderTest.saveRememberMe(expectedTrue);
      expect(await localRepositoryUnderTest.getRememberMe(), expectedTrue);

      // Act & Assert (false)
      await localRepositoryUnderTest.saveRememberMe(expectedFalse);
      expect(await localRepositoryUnderTest.getRememberMe(), expectedFalse);
    });

    test('loginEmail 저장 후 조회', () async {
      // Arrange
      const String expectedEmail = 'tester@ivis.ai';
      await localRepositoryUnderTest.saveLoginEmail(expectedEmail);

      // Act
      final String actualEmail = await localRepositoryUnderTest.getLoginEmail();

      // Assert
      expect(actualEmail, expectedEmail);
    });

    test('clearAccessToken() – accessToken만 삭제', () async {
      // Arrange
      await localRepositoryUnderTest.saveAccessToken('t1');
      await localRepositoryUnderTest.saveRememberMe(true);
      await localRepositoryUnderTest.saveLoginEmail('user@ivis.ai');

      // Act
      await localRepositoryUnderTest.clearAccessToken();

      // Assert
      expect(await localRepositoryUnderTest.getAccessToken(), isEmpty);
      expect(await localRepositoryUnderTest.getRememberMe(), isTrue);
      expect(await localRepositoryUnderTest.getLoginEmail(), 'user@ivis.ai');
    });

    test('clearPreferencesValues() – 세 키 전부 삭제', () async {
      // Arrange
      await localRepositoryUnderTest.saveAccessToken('tok');
      await localRepositoryUnderTest.saveRememberMe(false);
      await localRepositoryUnderTest.saveLoginEmail('aaa@bbb.com');

      // Act
      await localRepositoryUnderTest.clearPreferencesValues();

      // Assert
      expect(await localRepositoryUnderTest.getAccessToken(), isEmpty);
      expect(await localRepositoryUnderTest.getRememberMe(), isFalse);
      expect(await localRepositoryUnderTest.getLoginEmail(), isEmpty);
    });
  });
}
