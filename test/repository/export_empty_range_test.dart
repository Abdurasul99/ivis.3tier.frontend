// test/repository/export_empty_range_test.dart
//
// 데이터 없는 기간 내려받기 처리 회귀 테스트 — Triple-A 패턴
//
// 배경 (2026-08-10):
//   달력에서 데이터가 없는 날짜(예: 2026-07-04)를 고르고 "데이터 다운로드" 를
//   누르면, 서버가 헤더 한 줄짜리 빈 CSV(61바이트)를 만들어 '0000 success' 로
//   응답했고 프런트는 그대로 내려받았다. 사용자는 "Export ready: 0 rows" 라는
//   성공 메시지와 함께 빈 파일을 받았다.
//
//   수정: 서버는 0건이면 파일을 만들지 않고 코드 9207 + fileName='' 을 반환하고,
//         프런트는 이를 예외가 아닌 정상 결과로 받아 "데이터 없음" 을 안내한다.
//
// 검증 대상: 응답 파싱이 0건 응답을 예외 없이 처리하는지, 그리고 정상 응답과
//           구분되는지.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  /// log_repository.exportHistoryFile 의 응답 파싱과 동일한 규칙.
  /// (레포지토리는 http 호출과 묶여 있어 파싱 규칙만 분리해 검증한다)
  Map<String, dynamic> parseExportResponse(http.Response response) {
    final dynamic decoded = jsonDecode(response.body);
    Map<String, dynamic> bodyMap = <String, dynamic>{};
    if (decoded is Map<String, dynamic>) {
      final dynamic rawBody = decoded['body'];
      bodyMap = rawBody is Map<String, dynamic> ? rawBody : decoded;
    }
    final String fileName =
        (bodyMap['fileName'] ?? bodyMap['file_name'] ?? '').toString().trim();
    final int rowCount =
        int.tryParse('${bodyMap['rowCount'] ?? bodyMap['row_count'] ?? 0}') ?? 0;

    // 0건이면 예외가 아니라 "데이터 없음" 결과로 취급한다.
    final bool isEmptyResult = fileName.isEmpty && rowCount == 0;
    if (!isEmptyResult && fileName.isEmpty) {
      throw Exception('export fileName is empty');
    }
    return <String, dynamic>{
      'fileName': fileName,
      'rowCount': rowCount,
      'isEmpty': isEmptyResult,
    };
  }

  http.Response makeResponse(Map<String, dynamic> payload) {
    return http.Response.bytes(utf8.encode(json.encode(payload)), 200);
  }

  group('데이터가 없는 기간', () {
    test('코드 9207 + fileName 빈 값이면 예외 없이 "데이터 없음" 으로 처리된다', () {
      // Arrange — 서버가 실제로 돌려주는 형태
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '9207',
        'message': 'no data for selected range',
        'body': <String, dynamic>{
          'fileName': '',
          'rowCount': 0,
          'columnCount': 4,
          'truncated': false,
        },
      });

      // Act
      final Map<String, dynamic> result = parseExportResponse(response);

      // Assert — 예외가 나면 사용자에게 "Export failed" 가 뜬다
      expect(result['isEmpty'], isTrue);
      expect(result['rowCount'], 0);
      expect(result['fileName'], isEmpty);
    });

    test('내려받기를 시도하지 않아야 한다 (파일명이 없으므로)', () {
      // Arrange
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '9207',
        'body': <String, dynamic>{'fileName': '', 'rowCount': 0},
      });

      // Act
      final Map<String, dynamic> result = parseExportResponse(response);
      final bool shouldDownload =
          result['rowCount'] != 0 && (result['fileName'] as String).isNotEmpty;

      // Assert
      expect(shouldDownload, isFalse);
    });
  });

  group('데이터가 있는 기간', () {
    test('정상 응답은 파일명과 행 수를 그대로 돌려준다', () {
      // Arrange
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '0000',
        'message': 'success',
        'body': <String, dynamic>{
          'fileName': 'history_vehicle_2026-08-10T01-02-29-176Z.csv',
          'rowCount': 34553,
          'columnCount': 4,
          'truncated': false,
        },
      });

      // Act
      final Map<String, dynamic> result = parseExportResponse(response);
      final bool shouldDownload =
          result['rowCount'] != 0 && (result['fileName'] as String).isNotEmpty;

      // Assert
      expect(result['isEmpty'], isFalse);
      expect(result['rowCount'], 34553);
      expect(shouldDownload, isTrue);
    });
  });

  group('비정상 응답', () {
    test('행이 있는데 파일명이 없으면 예외를 던진다 (실제 오류)', () {
      // Arrange — 0건이 아닌데 파일명이 비었다면 서버 오류다
      final http.Response response = makeResponse(<String, dynamic>{
        'code': '0000',
        'body': <String, dynamic>{'fileName': '', 'rowCount': 120},
      });

      // Act / Assert
      expect(() => parseExportResponse(response), throwsA(isA<Exception>()));
    });
  });
}
