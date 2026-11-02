// test/repository/member_response_parsing_test.dart
//
// 회원 관리 API 응답 성공 판정 회귀 테스트 — Triple-A 패턴
//
// 배경 (2026-07 실장애):
//   "사용자 권한을 관리자로 바꿔도 화면에서 실패로 표시된다" 는 신고가 있었다.
//   실제로 DB 는 정상 반영되고 있었고, 원인은 프론트의 성공 판정식이었다.
//   MemberRepository 가 `jsonResponse['body']['affectedRows'] != null` 로
//   성공을 판정했는데, affectedRows 는 MySQL 시절 잔재이며
//   현재 백엔드(PostgreSQL)의 buildResponse 응답에는 존재하지 않는다.
//   → 항상 false 가 되어 성공을 실패로 표시했다.
//   판정식을 `code == '0000'` 으로 고쳤고, 본 테스트가 회귀를 막는다.
//
// 검증 대상: BaseRepository.handleResponse + 성공 판정 술어

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ivis/viewmodel/repository/base_repository.dart';

void main() {
  late BaseRepository repository;

  setUp(() {
    repository = BaseRepository();
  });

  /// MemberRepository 가 실제로 사용하는 성공 판정 술어와 동일.
  bool isSuccess(dynamic jsonResponse) =>
      jsonResponse is Map && jsonResponse['code'] == '0000';

  http.Response makeResponse(Map<String, dynamic> payload, {int status = 200}) {
    return http.Response.bytes(
      utf8.encode(json.encode(payload)),
      status,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );
  }

  group('성공 판정 — code 기반', () {
    test('code "0000" 이면 성공으로 판정한다', () {
      // Arrange — 백엔드 buildResponse 성공 응답 형태
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '0000',
        'message': 'success',
        'detail': '',
        'body': null,
      });

      // Act
      final bool result = repository.handleResponse(response, isSuccess) as bool;

      // Assert
      expect(result, isTrue);
    });

    test('affectedRows 가 없어도 code 가 0000 이면 성공이다 (실장애 재현)', () {
      // Arrange — PostgreSQL 응답에는 affectedRows 가 없다.
      //   구 판정식(body.affectedRows != null)이라면 false 가 나왔을 형태.
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '0000',
        'message': 'success',
        'detail': '',
        'body': <String, dynamic>{'rowCount': 1},
      });

      // Act
      final bool result = repository.handleResponse(response, isSuccess) as bool;

      // Assert — 이 값이 false 로 되돌아가면 권한 변경이 다시 "실패"로 보인다
      expect(result, isTrue);
    });

    test('code 가 0000 이 아니면 실패로 판정한다', () {
      // Arrange — 예: 권한 없음
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '9999',
        'message': 'exception occurred',
        'detail': 'permission denied',
        'body': null,
      });

      // Act
      final bool result = repository.handleResponse(response, isSuccess) as bool;

      // Assert
      expect(result, isFalse);
    });

    test('code 필드 자체가 없으면 실패로 판정한다', () {
      // Arrange
      final http.Response response = makeResponse(<String, dynamic>{
        'message': 'no code field',
      });

      // Act
      final bool result = repository.handleResponse(response, isSuccess) as bool;

      // Assert
      expect(result, isFalse);
    });
  });

  group('handleResponse 예외 처리', () {
    test('200 이 아니면 예외를 던진다', () {
      // Arrange
      final http.Response response = makeResponse(
        <String, dynamic>{'code': '0000'},
        status: 500,
      );

      // Act / Assert
      expect(
        () => repository.handleResponse(response, isSuccess),
        throwsA(isA<Exception>()),
      );
    });

    test('본문이 JSON 이 아니면 예외를 던진다', () {
      // Arrange
      final http.Response response = http.Response.bytes(
        utf8.encode('<html>gateway error</html>'),
        200,
      );

      // Act / Assert
      expect(
        () => repository.handleResponse(response, isSuccess),
        throwsA(isA<Exception>()),
      );
    });

    test('본문이 JSON null 이면 예외를 던진다', () {
      // Arrange
      final http.Response response = http.Response.bytes(utf8.encode('null'), 200);

      // Act / Assert
      expect(
        () => repository.handleResponse(response, isSuccess),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('UTF-8 한글 응답 처리', () {
    test('한글 메시지가 깨지지 않고 파싱된다', () {
      // Arrange
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '0000',
        'message': '성공',
        'detail': '권한이 변경되었습니다',
      });

      // Act
      final String detail = repository.handleResponse(
        response,
        (dynamic j) => j['detail'] as String,
      ) as String;

      // Assert
      expect(detail, '권한이 변경되었습니다');
    });
  });
}
