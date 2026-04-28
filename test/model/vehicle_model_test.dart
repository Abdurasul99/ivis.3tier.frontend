// test/model/vehicle_model_test.dart
// Vehicle 관련 모델 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/model/vehicle_model.dart';

void main() {
  // ─────────────────────────────────────────────
  // Vehicle 모델
  // ─────────────────────────────────────────────
  group('Vehicle.fromJson', () {
    test('정상 JSON에서 모든 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'vehicle_id': 1,
        'vehicle_type': 'sedan',
        'make': 'Hyundai',
        'model': 'Sonata',
        'state': 'active',
        'created_ts': '2024-01-01T00:00:00',
        'updated_ts': '2024-06-01T00:00:00',
      };

      // Act
      final Vehicle vehicle = Vehicle.fromJson(json);

      // Assert
      expect(vehicle.vehicleId, 1);
      expect(vehicle.vehicleType, 'sedan');
      expect(vehicle.make, 'Hyundai');
      expect(vehicle.modelName, 'Sonata');
      expect(vehicle.state, 'active');
      expect(vehicle.createdTimestamp, '2024-01-01T00:00:00');
      expect(vehicle.updatedTs, '2024-06-01T00:00:00');
    });

    test('vehicle_id가 String일 때 int로 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'vehicle_id': '42',
        'make': 'Kia',
      };

      // Act
      final Vehicle vehicle = Vehicle.fromJson(json);

      // Assert
      expect(vehicle.vehicleId, 42);
    });

    test('대체 키(id, type, name) 사용 시 올바르게 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'id': 10,
        'type': 'truck',
        'name': 'Porter',
        'description': 'Light truck',
      };

      // Act
      final Vehicle vehicle = Vehicle.fromJson(json);

      // Assert
      expect(vehicle.vehicleId, 10);
      expect(vehicle.vehicleType, 'truck');
      expect(vehicle.make, 'Porter');
      expect(vehicle.modelName, 'Light truck');
    });

    test('null 값 허용 — 필수 아닌 필드는 null 유지', () {
      // Arrange
      final Map<String, dynamic> json = {};

      // Act
      final Vehicle vehicle = Vehicle.fromJson(json);

      // Assert
      expect(vehicle.vehicleId, isNull);
      expect(vehicle.vehicleType, isNull);
      expect(vehicle.make, isNull);
    });

    test('vehicle_id가 double 숫자(num)일 때 int로 변환', () {
      // Arrange
      final Map<String, dynamic> json = {'vehicle_id': 7.0};

      // Act
      final Vehicle vehicle = Vehicle.fromJson(json);

      // Assert
      expect(vehicle.vehicleId, 7);
    });
  });

  group('Vehicle.toJson', () {
    test('모든 필드가 toJson에 포함', () {
      // Arrange
      final Vehicle vehicle = Vehicle(
        vehicleId: 5,
        vehicleType: 'suv',
        make: 'Genesis',
        modelName: 'GV80',
        state: 'active',
        createdTimestamp: '2024-01-01',
        updatedTs: '2024-07-01',
      );

      // Act
      final Map<String, dynamic> json = vehicle.toJson();

      // Assert
      expect(json['vehicle_id'], 5);
      expect(json['vehicle_type'], 'suv');
      expect(json['make'], 'Genesis');
      expect(json['model'], 'GV80');
      expect(json['state'], 'active');
    });

    test('null 필드는 toJson에서 null로 직렬화', () {
      // Arrange
      final Vehicle vehicle = Vehicle();

      // Act
      final Map<String, dynamic> json = vehicle.toJson();

      // Assert
      expect(json['vehicle_id'], isNull);
      expect(json['make'], isNull);
    });
  });

  // ─────────────────────────────────────────────
  // VehicleInfo 모델
  // ─────────────────────────────────────────────
  group('VehicleInfo.fromJson', () {
    test('정상 JSON에서 speed/position 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'id': 100,
        'vehicle_id': 1,
        'msg_id': 1,
        'msg_seq': 5,
        'kph': 60.0,
        'mps': 16.67,
        'pos_x_m': 100.5,
        'pos_y_m': 200.3,
        'pos_z_m': 0.0,
        'heading_deg': 45.0,
        'number_of_objects': 3,
        'time_stamp_ms': 1700000000000,
      };

      // Act
      final VehicleInfo info = VehicleInfo.fromJson(json);

      // Assert
      expect(info.id, 100);
      expect(info.vehicleId, 1);
      expect(info.velocityKph, 60.0);
      expect(info.velocityMps, closeTo(16.67, 0.01));
      expect(info.positionX, 100.5);
      expect(info.orientationHeading, 45.0);
      expect(info.numberOfObjects, 3);
      expect(info.timeStampMs, 1700000000000);
    });

    test('대체 키(velocity_kph, position_x) 사용 시 올바르게 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'velocity_kph': 80.0,
        'position_x': 300.0,
        'orientation_heading': 90.0,
      };

      // Act
      final VehicleInfo info = VehicleInfo.fromJson(json);

      // Assert
      expect(info.velocityKph, 80.0);
      expect(info.positionX, 300.0);
      expect(info.orientationHeading, 90.0);
    });

    test('payload_crc_ok 불리언 파싱 — true/false 문자열 처리', () {
      // Arrange
      final Map<String, dynamic> json1 = {'payload_crc_ok': 'true'};
      final Map<String, dynamic> json2 = {'payload_crc_ok': false};
      final Map<String, dynamic> json3 = {'payload_crc_ok': 1};

      // Act
      final VehicleInfo info1 = VehicleInfo.fromJson(json1);
      final VehicleInfo info2 = VehicleInfo.fromJson(json2);
      final VehicleInfo info3 = VehicleInfo.fromJson(json3);

      // Assert
      expect(info1.payloadCrcOk, isTrue);
      expect(info2.payloadCrcOk, isFalse);
      expect(info3.payloadCrcOk, isTrue);
    });

    test('time_stamp_ms가 없고 time_stamp만 있을 때 fallback', () {
      // Arrange
      final Map<String, dynamic> json = {'time_stamp': 1700000000};

      // Act
      final VehicleInfo info = VehicleInfo.fromJson(json);

      // Assert
      expect(info.timeStampMs, 1700000000);
    });

    test('toJson 직렬화 — 이중 키 포함 확인', () {
      // Arrange
      final VehicleInfo info = VehicleInfo(
        id: 1,
        velocityKph: 50.0,
        positionX: 10.0,
        orientationHeading: 30.0,
      );

      // Act
      final Map<String, dynamic> json = info.toJson();

      // Assert
      expect(json['kph'], 50.0);
      expect(json['velocity_kph'], 50.0);
      expect(json['pos_x_m'], 10.0);
      expect(json['heading_deg'], 30.0);
    });
  });

  // ─────────────────────────────────────────────
  // VehicleInfoHistory 모델
  // ─────────────────────────────────────────────
  group('VehicleInfoHistory.fromJson', () {
    test('정상 JSON에서 history 전용 필드 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'history_id': 500,
        'vehicle_info_id': 100,
        'vehicle_id': 1,
        'changed_at': '2024-05-01T12:00:00',
        'kph': 30.0,
        'number_of_objects': 2,
      };

      // Act
      final VehicleInfoHistory history = VehicleInfoHistory.fromJson(json);

      // Assert
      expect(history.historyId, 500);
      expect(history.vehicleInfoId, 100);
      expect(history.vehicleId, 1);
      expect(history.changedAt, '2024-05-01T12:00:00');
      expect(history.velocityKph, 30.0);
      expect(history.numberOfObjects, 2);
    });

    test('toJson에 history_id와 vehicle_info_id 포함', () {
      // Arrange
      final VehicleInfoHistory history = VehicleInfoHistory(
        historyId: 99,
        vehicleInfoId: 200,
        vehicleId: 3,
        velocityKph: 20.0,
      );

      // Act
      final Map<String, dynamic> json = history.toJson();

      // Assert
      expect(json['history_id'], 99);
      expect(json['vehicle_info_id'], 200);
      expect(json['vehicle_id'], 3);
      expect(json['kph'], 20.0);
    });
  });

  // ─────────────────────────────────────────────
  // VehicleInfoResult 모델
  // ─────────────────────────────────────────────
  group('VehicleInfoResult.fromJson', () {
    test('items 리스트와 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'totalCount': 2,
        'items': [
          {'id': 1, 'vehicle_id': 1, 'kph': 60.0},
          {'id': 2, 'vehicle_id': 1, 'kph': 80.0},
        ],
      };

      // Act
      final VehicleInfoResult result = VehicleInfoResult.fromJson(json);

      // Assert
      expect(result.totalCount, 2);
      expect(result.items.length, 2);
      expect(result.items[0].velocityKph, 60.0);
      expect(result.items[1].velocityKph, 80.0);
    });

    test('items가 null이면 빈 리스트 반환', () {
      // Arrange
      final Map<String, dynamic> json = {'total_count': 0};

      // Act
      final VehicleInfoResult result = VehicleInfoResult.fromJson(json);

      // Assert
      expect(result.items, isEmpty);
      expect(result.totalCount, 0);
    });

    test('total 대체 키 사용 시 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'total': 5,
        'items': [],
      };

      // Act
      final VehicleInfoResult result = VehicleInfoResult.fromJson(json);

      // Assert
      expect(result.totalCount, 5);
    });
  });

  // ─────────────────────────────────────────────
  // VehicleInfoHistoryResult 모델
  // ─────────────────────────────────────────────
  group('VehicleInfoHistoryResult.fromJson', () {
    test('items 리스트와 totalCount 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'totalCount': 3,
        'items': [
          {'history_id': 1, 'vehicle_id': 1, 'kph': 40.0},
          {'history_id': 2, 'vehicle_id': 1, 'kph': 55.0},
          {'history_id': 3, 'vehicle_id': 1, 'kph': 70.0},
        ],
      };

      // Act
      final VehicleInfoHistoryResult result =
          VehicleInfoHistoryResult.fromJson(json);

      // Assert
      expect(result.totalCount, 3);
      expect(result.items.length, 3);
      expect(result.items[2].velocityKph, 70.0);
    });

    test('빈 items 배열 허용', () {
      // Arrange
      final Map<String, dynamic> json = {'totalCount': 0, 'items': []};

      // Act
      final VehicleInfoHistoryResult result =
          VehicleInfoHistoryResult.fromJson(json);

      // Assert
      expect(result.items, isEmpty);
    });

    test('잘못된 item 엔트리는 무시하고 나머지 파싱', () {
      // Arrange
      final Map<String, dynamic> json = {
        'totalCount': 2,
        'items': [
          'invalid_string_entry', // Map 이 아닌 항목 — 무시됨
          {'history_id': 10, 'kph': 100.0},
        ],
      };

      // Act
      final VehicleInfoHistoryResult result =
          VehicleInfoHistoryResult.fromJson(json);

      // Assert
      expect(result.items.length, 1);
      expect(result.items[0].historyId, 10);
    });
  });
}
