// test/model/object_model_test.dart
// DetectedObject 관련 모델 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/model/object_model.dart';

void main() {
  // ─────────────────────────────────────────────
  // DetectedObject 모델
  // ─────────────────────────────────────────────
  group('DetectedObject.fromJson', () {
    test('정상 JSON에서 모든 주요 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'detected_object_id': 1001,
        'source_kind': 'vehicle',
        'vehicle_id': 50,
        'infra_id': null,
        'object_id': 3,
        'msg_id': 10,
        'msg_seq': 7,
        'time_stamp_ms': 1700000000000,
        'age': 5,
        'score': 0.95,
        'width': 1.8,
        'depth': 4.5,
        'height': 1.5,
        'position_x': 10.0,
        'position_y': 20.0,
        'position_z': 0.0,
        'orientation_heading': 30.0,
        'linear_velocity_x': 5.0,
        'linear_velocity_y': 0.0,
        'linear_velocity_z': 0.0,
        'rotation_rate_x': 0.0,
        'rotation_rate_y': 0.0,
        'rotation_rate_z': 0.1,
        'object_type': 1,
        'created_ts': '2024-01-01',
        'updated_ts': '2024-06-01',
      };

      // Act
      final DetectedObject obj = DetectedObject.fromJson(json);

      // Assert
      expect(obj.detectedObjectId, 1001);
      expect(obj.sourceKind, 'vehicle');
      expect(obj.vehicleId, 50);
      expect(obj.infraId, isNull);
      expect(obj.objectId, 3);
      expect(obj.msgSeq, 7);
      expect(obj.timeStampMs, 1700000000000);
      expect(obj.score, closeTo(0.95, 0.001));
      expect(obj.width, 1.8);
      expect(obj.objectType, 1);
    });

    test('대체 키(id, time_stamp) 사용 시 올바르게 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'id': 999,
        'time_stamp': 1700000001000,
      };

      // Act
      final DetectedObject obj = DetectedObject.fromJson(json);

      // Assert
      expect(obj.detectedObjectId, 999);
      expect(obj.timeStampMs, 1700000001000);
    });

    test('object_type이 String으로 들어와도 int로 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {'object_type': '2'};

      // Act
      final DetectedObject obj = DetectedObject.fromJson(json);

      // Assert
      expect(obj.objectType, 2);
    });

    test('빈 JSON이면 모든 필드 null', () {
      // Arrange
      final Map<String, dynamic> json = {};

      // Act
      final DetectedObject obj = DetectedObject.fromJson(json);

      // Assert
      expect(obj.detectedObjectId, isNull);
      expect(obj.objectType, isNull);
      expect(obj.score, isNull);
    });

    test('score가 int로 들어와도 double로 변환', () {
      // Arrange
      final Map<String, dynamic> json = {'score': 1};

      // Act
      final DetectedObject obj = DetectedObject.fromJson(json);

      // Assert
      expect(obj.score, 1.0);
      expect(obj.score, isA<double>());
    });
  });

  group('DetectedObject.toJson', () {
    test('모든 필드가 toJson에 포함', () {
      // Arrange
      final DetectedObject obj = DetectedObject(
        detectedObjectId: 200,
        objectId: 1,
        msgSeq: 3,
        timeStampMs: 1700000005000,
        objectType: 4,
        score: 0.88,
        positionX: 5.5,
        positionY: 6.6,
      );

      // Act
      final Map<String, dynamic> json = obj.toJson();

      // Assert
      expect(json['detected_object_id'], 200);
      expect(json['object_id'], 1);
      expect(json['msg_seq'], 3);
      expect(json['time_stamp_ms'], 1700000005000);
      expect(json['object_type'], 4);
      expect(json['score'], 0.88);
      expect(json['position_x'], 5.5);
    });

    test('null 필드는 toJson에서 null로 직렬화', () {
      // Arrange
      final DetectedObject obj = DetectedObject();

      // Act
      final Map<String, dynamic> json = obj.toJson();

      // Assert
      expect(json['detected_object_id'], isNull);
      expect(json['object_type'], isNull);
    });
  });

  // ─────────────────────────────────────────────
  // DetectedObjectResult 모델
  // ─────────────────────────────────────────────
  group('DetectedObjectResult.fromJson', () {
    test('totalCount와 items 리스트 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'totalCount': 2,
        'items': [
          {'detected_object_id': 1, 'object_type': 1},
          {'detected_object_id': 2, 'object_type': 2},
        ],
      };

      // Act
      final DetectedObjectResult result = DetectedObjectResult.fromJson(json);

      // Assert
      expect(result.totalCount, 2);
      expect(result.items.length, 2);
      expect(result.items[0].detectedObjectId, 1);
      expect(result.items[1].objectType, 2);
    });

    test('대체 키 total 사용 시 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'total': 10,
        'items': [],
      };

      // Act
      final DetectedObjectResult result = DetectedObjectResult.fromJson(json);

      // Assert
      expect(result.totalCount, 10);
      expect(result.items, isEmpty);
    });

    test('items가 없으면 빈 리스트 반환', () {
      // Arrange
      final Map<String, dynamic> json = {'totalCount': 0};

      // Act
      final DetectedObjectResult result = DetectedObjectResult.fromJson(json);

      // Assert
      expect(result.items, isEmpty);
    });

    test('toString에 totalCount와 items 길이 포함', () {
      // Arrange
      final DetectedObjectResult result = DetectedObjectResult(
        totalCount: 3,
        items: [DetectedObject(detectedObjectId: 1)],
      );

      // Act
      final String str = result.toString();

      // Assert
      expect(str, contains('3'));
      expect(str, contains('1'));
    });
  });

  // ─────────────────────────────────────────────
  // DetectedObjectHistory 모델
  // ─────────────────────────────────────────────
  group('DetectedObjectHistory.fromJson', () {
    test('history_id와 changed_at 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'history_id': 777,
        'detected_object_id': 100,
        'changed_at': '2024-03-01T09:00:00',
        'source_kind': 'infra',
        'object_type': 3,
        'score': 0.75,
      };

      // Act
      final DetectedObjectHistory history =
          DetectedObjectHistory.fromJson(json);

      // Assert
      expect(history.historyId, 777);
      expect(history.detectedObjectId, 100);
      expect(history.changedAt, '2024-03-01T09:00:00');
      expect(history.sourceKind, 'infra');
      expect(history.objectType, 3);
      expect(history.score, closeTo(0.75, 0.001));
    });

    test('toJson에 history_id 포함', () {
      // Arrange
      final DetectedObjectHistory history = DetectedObjectHistory(
        historyId: 50,
        objectType: 5,
      );

      // Act
      final Map<String, dynamic> json = history.toJson();

      // Assert
      expect(json['history_id'], 50);
      expect(json['object_type'], 5);
    });
  });

  // ─────────────────────────────────────────────
  // DetectedObjectHistoryResult 모델
  // ─────────────────────────────────────────────
  group('DetectedObjectHistoryResult.fromJson', () {
    test('items 리스트 파싱 및 totalCount 확인', () {
      // Arrange
      final Map<String, dynamic> json = {
        'totalCount': 1,
        'items': [
          {'history_id': 1, 'object_type': 0},
        ],
      };

      // Act
      final DetectedObjectHistoryResult result =
          DetectedObjectHistoryResult.fromJson(json);

      // Assert
      expect(result.totalCount, 1);
      expect(result.items.length, 1);
      expect(result.items[0].historyId, 1);
    });
  });
}
