// test/model/user_model_test.dart
// User 관련 모델 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/model/user_model.dart';

void main() {
  // ─────────────────────────────────────────────
  // LoginUser 모델
  // ─────────────────────────────────────────────
  group('LoginUser.fromJson', () {
    test('정상 JSON에서 모든 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'id': '1',
        'userId': 'admin01',
        'email': 'admin@ivis.com',
        'name': '홍길동',
        'phoneNumber': '010-1234-5678',
        'imageUrl': 'https://example.com/profile.jpg',
        'state': 'active',
        'role': 'admin',
        'accessToken': 'eyJhbGci...',
        'expireDate': 1700000000,
        'refreshToken': 'refresh_tok...',
        'refreshExpireDate': 1710000000,
      };

      // Act
      final LoginUser user = LoginUser.fromJson(json);

      // Assert
      expect(user.id, 1);
      expect(user.userId, 'admin01');
      expect(user.email, 'admin@ivis.com');
      expect(user.name, '홍길동');
      expect(user.phoneNumber, '010-1234-5678');
      expect(user.imageUrl, 'https://example.com/profile.jpg');
      expect(user.state, 'active');
      expect(user.role, 'admin');
      expect(user.accessToken, 'eyJhbGci...');
      expect(user.expiresDate, 1700000000);
      expect(user.refreshToken, 'refresh_tok...');
      expect(user.refreshExpiresDate, 1710000000);
    });

    test('id가 없거나 "0"이면 0으로 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {'id': '0'};

      // Act
      final LoginUser user = LoginUser.fromJson(json);

      // Assert
      expect(user.id, 0);
    });

    test('role이 정수로 전달되어도 String으로 변환', () {
      // Arrange
      final Map<String, dynamic> json = {'role': 1};

      // Act
      final LoginUser user = LoginUser.fromJson(json);

      // Assert
      expect(user.role, '1');
    });

    test('필드가 없으면 id=0(기본값), 나머지 null', () {
      // Arrange
      final Map<String, dynamic> json = {};

      // Act
      final LoginUser user = LoginUser.fromJson(json);

      // Assert
      // id는 코드에서 null 시 "0" fallback → int.tryParse("0") = 0
      expect(user.id, 0);
      expect(user.userId, isNull);
      expect(user.email, isNull);
      expect(user.role, isNull);
    });

    test('toString에 주요 필드 포함', () {
      // Arrange
      final LoginUser user = LoginUser(
        id: 2,
        userId: 'user01',
        role: 'member',
      );

      // Act
      final String str = user.toString();

      // Assert
      expect(str, contains('user01'));
      expect(str, contains('member'));
    });
  });

  // ─────────────────────────────────────────────
  // LoginResult 모델
  // ─────────────────────────────────────────────
  group('LoginResult.fromJson', () {
    test('code "0000"과 loginUser 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'code': '0000',
        'message': '로그인 성공',
        'additionalMessage': null,
        'responseTime': '2024-01-01T00:00:00',
        'body': {
          'id': '5',
          'userId': 'testUser',
          'email': 'test@ivis.com',
          'role': 'user',
          'accessToken': 'tok_abc',
        },
      };

      // Act
      final LoginResult result = LoginResult.fromJson(json);

      // Assert
      expect(result.code, '0000');
      expect(result.message, '로그인 성공');
      expect(result.loginUser, isNotNull);
      expect(result.loginUser!.userId, 'testUser');
      expect(result.loginUser!.accessToken, 'tok_abc');
    });

    test('body가 null이면 loginUser는 null', () {
      // Arrange
      final Map<String, dynamic> json = {
        'code': '1001',
        'message': '인증 실패',
        'body': null,
      };

      // Act
      final LoginResult result = LoginResult.fromJson(json);

      // Assert
      expect(result.code, '1001');
      expect(result.loginUser, isNull);
    });

    test('toString에 code와 message 포함', () {
      // Arrange
      final LoginResult result = LoginResult(
        code: '0000',
        message: '성공',
      );

      // Act
      final String str = result.toString();

      // Assert
      expect(str, contains('0000'));
      expect(str, contains('성공'));
    });
  });

  // ─────────────────────────────────────────────
  // Member 모델
  // ─────────────────────────────────────────────
  group('Member.fromJson', () {
    test('정상 JSON에서 모든 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'id': 10,
        'user_id': 'member01',
        'email': 'member@ivis.com',
        'name': '김민준',
        'phone_number': '010-9876-5432',
        'image_url': null,
        'state': 'active',
        'role': 'user',
        'created_ts': '2024-02-01',
      };

      // Act
      final Member member = Member.fromJson(json);

      // Assert
      expect(member.id, 10);
      expect(member.userId, 'member01');
      expect(member.email, 'member@ivis.com');
      expect(member.name, '김민준');
      expect(member.phoneNumber, '010-9876-5432');
      expect(member.imageUrl, isNull);
      expect(member.state, 'active');
      expect(member.role, 'user');
      expect(member.createdTs, '2024-02-01');
    });

    test('role이 정수로 전달되어도 String으로 변환', () {
      // Arrange
      final Map<String, dynamic> json = {
        'id': 1,
        'role': 2,
      };

      // Act
      final Member member = Member.fromJson(json);

      // Assert
      expect(member.role, '2');
    });

    test('toString에 userId와 email 포함', () {
      // Arrange
      final Member member = Member(
        userId: 'tester',
        email: 'test@ivis.com',
        role: 'admin',
      );

      // Act
      final String str = member.toString();

      // Assert
      expect(str, contains('tester'));
      expect(str, contains('test@ivis.com'));
    });
  });
}
