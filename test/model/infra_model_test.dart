// test/model/infra_model_test.dart
// InfraInfo, InfraInfoHistory 관련 모델 단위 테스트
// Triple-A 패턴 (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/model/infra_model.dart';

void main() {
  // ─────────────────────────────────────────────
  // InfraInfo 모델
  // ─────────────────────────────────────────────
  group('InfraInfo.fromJson', () {
    test('정상 JSON에서 모든 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 10,
        'infra_id': 1,
        'msg_id': 5,
        'msg_seq': 3,
        'msg_length': 128,
        'time_stamp': 1700000000,
        'time_stamp_ms': 1700000000000,
        'number_of_objects': 4,
        'payload_crc_ok': true,
        'payload_bytes_hex': 'AABB',
        'created_ts': '2024-01-01T00:00:00',
        'updated_ts': '2024-06-01T00:00:00',
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.id, 10);
      expect(info.infraId, 1);
      expect(info.msgId, 5);
      expect(info.msgSeq, 3);
      expect(info.msgLength, 128);
      expect(info.timeStamp, 1700000000);
      expect(info.timeStampMs, 1700000000000);
      expect(info.numberOfObjects, 4);
      expect(info.payloadCrcOk, isTrue);
      expect(info.payloadBytesHex, 'AABB');
      expect(info.createdTs, '2024-01-01T00:00:00');
      expect(info.updatedTs, '2024-06-01T00:00:00');
    });

    test('time_stamp_ms가 없고 time_stamp만 있을 때 fallback', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'time_stamp': 1700000001,
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.timeStampMs, 1700000001); // time_stamp를 그대로 사용
    });

    test('payload_crc_ok 불리언 파싱 — 문자열 "true"', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'payload_crc_ok': 'true',
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.payloadCrcOk, isTrue);
    });

    test('payload_crc_ok 불리언 파싱 — 숫자 1', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'payload_crc_ok': 1,
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.payloadCrcOk, isTrue);
    });

    test('payload_crc_ok 불리언 파싱 — false', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'payload_crc_ok': false,
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.payloadCrcOk, isFalse);
    });

    test('created_at 대체 키 사용 시 createdTs 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'created_at': '2024-03-01',
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.createdTs, '2024-03-01');
    });

    test('빈 JSON이면 모든 필드 null', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{};

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.id, isNull);
      expect(info.infraId, isNull);
      expect(info.numberOfObjects, isNull);
      expect(info.payloadCrcOk, isNull);
    });

    test('infra_id가 String일 때 int로 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'infra_id': '42',
      };

      // Act
      final InfraInfo info = InfraInfo.fromJson(json);

      // Assert
      expect(info.infraId, 42);
    });
  });

  group('InfraInfo.toJson', () {
    test('모든 필드가 toJson에 포함', () {
      // Arrange
      final InfraInfo info = InfraInfo(
        id: 1,
        infraId: 2,
        msgId: 3,
        msgSeq: 4,
        msgLength: 64,
        timeStampMs: 1700000000000,
        numberOfObjects: 2,
        payloadCrcOk: true,
        payloadBytesHex: 'FF00',
        createdTs: '2024-01-01',
        updatedTs: '2024-06-01',
      );

      // Act
      final Map<String, dynamic> json = info.toJson();

      // Assert
      expect(json['id'], 1);
      expect(json['infra_id'], 2);
      expect(json['msg_id'], 3);
      expect(json['time_stamp_ms'], 1700000000000);
      expect(json['number_of_objects'], 2);
      expect(json['payload_crc_ok'], isTrue);
    });

    test('null 필드는 toJson에서 null로 직렬화', () {
      // Arrange
      final InfraInfo info = InfraInfo();

      // Act
      final Map<String, dynamic> json = info.toJson();

      // Assert
      expect(json['id'], isNull);
      expect(json['infra_id'], isNull);
      expect(json['number_of_objects'], isNull);
    });
  });

  // ─────────────────────────────────────────────
  // InfraInfoResult 모델
  // ─────────────────────────────────────────────
  group('InfraInfoResult.fromJson', () {
    test('items 리스트와 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'totalCount': 2,
        'items': <dynamic>[
          <String, dynamic>{'id': 1, 'infra_id': 1, 'number_of_objects': 3},
          <String, dynamic>{'id': 2, 'infra_id': 1, 'number_of_objects': 0},
        ],
      };

      // Act
      final InfraInfoResult result = InfraInfoResult.fromJson(json);

      // Assert
      expect(result.totalCount, 2);
      expect(result.items.length, 2);
      expect(result.items[0].numberOfObjects, 3);
      expect(result.items[1].id, 2);
    });

    test('items가 없으면 빈 리스트', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{'total_count': 0};

      // Act
      final InfraInfoResult result = InfraInfoResult.fromJson(json);

      // Assert
      expect(result.items, isEmpty);
      expect(result.totalCount, 0);
    });

    test('total 대체 키 사용 시 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'total': 7,
        'items': <dynamic>[],
      };

      // Act
      final InfraInfoResult result = InfraInfoResult.fromJson(json);

      // Assert
      expect(result.totalCount, 7);
    });
  });

  // ─────────────────────────────────────────────
  // InfraInfoHistory 모델
  // ─────────────────────────────────────────────
  group('InfraInfoHistory.fromJson', () {
    test('정상 JSON에서 history 전용 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'history_id': 100,
        'infra_info_id': 50,
        'infra_id': 1,
        'changed_at': '2024-05-01T12:00:00',
        'msg_id': 10,
        'msg_seq': 3,
        'number_of_objects': 2,
        'payload_crc_ok': true,
      };

      // Act
      final InfraInfoHistory history = InfraInfoHistory.fromJson(json);

      // Assert
      expect(history.historyId, 100);
      expect(history.infraInfoId, 50);
      expect(history.infraId, 1);
      expect(history.changedAt, '2024-05-01T12:00:00');
      expect(history.numberOfObjects, 2);
      expect(history.payloadCrcOk, isTrue);
    });

    test('time_stamp_ms 없을 때 time_stamp fallback', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'time_stamp': 1700000001,
      };

      // Act
      final InfraInfoHistory history = InfraInfoHistory.fromJson(json);

      // Assert
      expect(history.timeStampMs, 1700000001);
    });

    test('toJson에 history_id와 infra_info_id 포함', () {
      // Arrange
      final InfraInfoHistory history = InfraInfoHistory(
        historyId: 200,
        infraInfoId: 100,
        infraId: 3,
        numberOfObjects: 5,
      );

      // Act
      final Map<String, dynamic> json = history.toJson();

      // Assert
      expect(json['history_id'], 200);
      expect(json['infra_info_id'], 100);
      expect(json['infra_id'], 3);
      expect(json['number_of_objects'], 5);
    });

    test('빈 JSON이면 모든 필드 null', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{};

      // Act
      final InfraInfoHistory history = InfraInfoHistory.fromJson(json);

      // Assert
      expect(history.historyId, isNull);
      expect(history.infraId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // InfraInfoHistoryResult 모델
  // ─────────────────────────────────────────────
  group('InfraInfoHistoryResult.fromJson', () {
    test('items 리스트와 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'totalCount': 3,
        'items': <dynamic>[
          <String, dynamic>{'history_id': 1, 'infra_id': 1},
          <String, dynamic>{'history_id': 2, 'infra_id': 1},
          <String, dynamic>{'history_id': 3, 'infra_id': 1},
        ],
      };

      // Act
      final InfraInfoHistoryResult result =
          InfraInfoHistoryResult.fromJson(json);

      // Assert
      expect(result.totalCount, 3);
      expect(result.items.length, 3);
      expect(result.items[2].historyId, 3);
    });

    test('잘못된 item 엔트리는 무시하고 나머지 파싱', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'totalCount': 2,
        'items': <dynamic>[
          'invalid_entry', // Map이 아닌 항목 — 무시됨
          <String, dynamic>{'history_id': 99, 'infra_id': 2},
        ],
      };

      // Act
      final InfraInfoHistoryResult result =
          InfraInfoHistoryResult.fromJson(json);

      // Assert
      expect(result.items.length, 1);
      expect(result.items[0].historyId, 99);
    });

    test('빈 items 배열 허용', () {
      // Arrange
      final Map<String, dynamic> json = <String, dynamic>{
        'totalCount': 0,
        'items': <dynamic>[],
      };

      // Act
      final InfraInfoHistoryResult result =
          InfraInfoHistoryResult.fromJson(json);

      // Assert
      expect(result.items, isEmpty);
    });
  });
}
