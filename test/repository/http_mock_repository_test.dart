// test/repository/http_mock_repository_test.dart
//
// HTTP 응답 처리 회귀 테스트 — Triple-A 패턴, http 클라이언트 모킹
//
// 배경 (2026-08-20):
//   /api/infra/dailyObjectCounts 가 원본 테이블(32GB / 8,880만 행)을 전수 집계하다
//   statement timeout 에 걸려 HTTP 500 을 반환했다. 그런데 화면에는 오류가 아니라
//   "감지된 객체 데이터가 없습니다" 로 표시됐다 — 레포지토리가 비-200 응답을
//   조용히 빈 배열로 바꾸기 때문이다.
//
//   즉 서버 장애가 "데이터 없음" 으로 위장된다. 이 동작 자체는 화면을 깨뜨리지
//   않으려는 의도적 설계지만, 두 상황을 구분할 수 없다는 점이 문제였다.
//
// 여기서 고정하는 것:
//   1. 정상 응답(200 + 배열) 은 그대로 파싱된다
//   2. 서버 오류(500) 는 예외를 던지지 않고 빈 목록이 된다 — 화면 보호
//   3. 빈 배열(200) 과 서버 오류(500) 는 반환값이 같다 → 구분하려면 별도 신호 필요
//   4. 잘린 JSON·null 본문에도 죽지 않는다

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  /// infra_repository.requestInfraDailyObjectCounts 의 응답 처리와 동일한 규칙.
  /// (레포지토리는 인증·URL 조립과 묶여 있어 파싱 규칙만 분리해 검증한다)
  List<Map<String, dynamic>> parseListResponse(http.Response response) {
    if (response.statusCode != 200) return <Map<String, dynamic>>[];
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic body = decoded is Map ? decoded['body'] : decoded;
      if (body is List) {
        return body
            .whereType<Map>()
            .map((Map e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  http.Response ok(Object payload) =>
      http.Response.bytes(utf8.encode(json.encode(payload)), 200);

  group('정상 응답', () {
    test('body 배열이 그대로 파싱된다', () {
      // Arrange
      final http.Response response = ok(<String, dynamic>{
        'code': '0000',
        'body': <Map<String, dynamic>>[
          <String, dynamic>{'date_kst': '2026-08-18', 'total_objects': 16218},
          <String, dynamic>{'date_kst': '2026-08-17', 'total_objects': 1680},
        ],
      });

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, hasLength(2));
      expect(rows.first['total_objects'], 16218);
      expect(rows.last['date_kst'], '2026-08-17');
    });

    test('body 없이 최상위가 배열이어도 파싱된다', () {
      // Arrange — 일부 엔드포인트는 래핑 없이 배열을 직접 반환한다
      final http.Response response = ok(<Map<String, dynamic>>[
        <String, dynamic>{'infra_id': 17, 'total_objects': 38097},
      ]);

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, hasLength(1));
      expect(rows.first['infra_id'], 17);
    });

    test('데이터가 정말 없으면 빈 목록이 된다', () {
      // Arrange
      final http.Response response =
          ok(<String, dynamic>{'code': '0000', 'body': <dynamic>[]});

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, isEmpty);
    });
  });

  group('서버 오류 — 화면을 깨뜨리지 않는다', () {
    test('500 응답은 예외 없이 빈 목록이 된다 (2026-08-20 사례)', () {
      // Arrange — statement timeout 으로 백엔드가 500 을 반환한 상황
      final http.Response response = http.Response.bytes(
        utf8.encode(json.encode(<String, dynamic>{
          'code': '9999',
          'message': 'exception occurred',
          'detail': 'canceling statement due to statement timeout',
        })),
        500,
      );

      // Act
      List<Map<String, dynamic>>? rows;
      void act() {
        rows = parseListResponse(response);
      }

      // Assert — 예외가 나면 앱이 오류 화면으로 떨어진다
      expect(act, returnsNormally);
      expect(rows, isEmpty);
    });

    test('403(인증 만료) 도 동일하게 빈 목록이 된다', () {
      // Arrange
      final http.Response response = http.Response('forbidden', 403);

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, isEmpty);
    });

    test('서버 오류와 진짜 빈 데이터는 반환값이 같다 — 구분 불가', () {
      // Arrange
      final http.Response serverError = http.Response('boom', 500);
      final http.Response genuinelyEmpty =
          ok(<String, dynamic>{'body': <dynamic>[]});

      // Act
      final List<Map<String, dynamic>> a = parseListResponse(serverError);
      final List<Map<String, dynamic>> b = parseListResponse(genuinelyEmpty);

      // Assert — 이 등가성이 "장애가 데이터 없음으로 보이는" 원인이다.
      //   화면에서 둘을 구분하려면 상태 코드를 별도로 전달해야 한다.
      expect(a, equals(b));
      expect(a, isEmpty);
    });
  });

  group('망가진 응답', () {
    test('잘린 JSON 에도 죽지 않는다', () {
      // Arrange — 연결이 중간에 끊겨 본문이 잘린 경우
      final http.Response response =
          http.Response.bytes(utf8.encode('{"body":[{"a":1'), 200);

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, isEmpty);
    });

    test('body 가 배열이 아니면 빈 목록이 된다', () {
      // Arrange
      final http.Response response =
          ok(<String, dynamic>{'body': <String, dynamic>{'unexpected': true}});

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, isEmpty);
    });

    test('배열 안의 비-객체 항목은 걸러진다', () {
      // Arrange — 서버가 섞인 배열을 보낸 경우
      final http.Response response = ok(<String, dynamic>{
        'body': <dynamic>[
          <String, dynamic>{'date_kst': '2026-08-18'},
          'not-an-object',
          42,
          null,
        ],
      });

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert — 하나라도 이상하면 전체가 날아가면 안 된다
      expect(rows, hasLength(1));
      expect(rows.first['date_kst'], '2026-08-18');
    });

    test('빈 본문(200) 도 빈 목록이 된다', () {
      // Arrange
      final http.Response response = http.Response.bytes(<int>[], 200);

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows, isEmpty);
    });
  });

  group('한글 인코딩', () {
    test('UTF-8 한글이 깨지지 않고 파싱된다', () {
      // Arrange — bodyBytes 를 거치지 않으면 한글이 깨진다
      final http.Response response = ok(<String, dynamic>{
        'body': <Map<String, dynamic>>[
          <String, dynamic>{'name': '대구역', 'infra_id': 1},
        ],
      });

      // Act
      final List<Map<String, dynamic>> rows = parseListResponse(response);

      // Assert
      expect(rows.first['name'], '대구역');
    });
  });
}
