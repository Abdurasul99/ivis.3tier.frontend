// test/controller/vehicle_controller_test.dart
// VehicleController 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
// 순수 상태 관리 로직만 테스트 (HTTP 호출 없음)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/vehicle_model.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';

void main() {
  // GetX 테스트 모드 설정
  setUp(() {
    Get.testMode = true;
    // VehicleController.hasToken이 UserController를 참조하므로 먼저 등록
    Get.put(UserController());
    Get.put(VehicleController());
  });

  tearDown(() {
    Get.deleteAll();
  });

  // ─────────────────────────────────────────────
  // 초기 상태 검증
  // ─────────────────────────────────────────────
  group('초기 상태', () {
    test('컨트롤러 생성 직후 모든 상태가 기본값', () {
      // Arrange — setUp에서 등록됨
      final VehicleController ctrl = Get.find<VehicleController>();

      // Act (별도 호출 없음)

      // Assert
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.vehicles, isEmpty);
      expect(ctrl.selectedVehicle, isNull);
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.historyLimit, 18);
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
      expect(ctrl.statusOffset, 0);
      expect(ctrl.statusLimit, 100);
      expect(ctrl.latestVehicleInfo, isNull);
      expect(ctrl.fromEpochMs, isNull);
      expect(ctrl.toEpochMs, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 날짜 범위 설정
  // ─────────────────────────────────────────────
  group('setDateRange', () {
    test('fromMs와 toMs를 정상 설정', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      const int from = 1700000000000;
      const int to = 1700086400000;

      // Act
      ctrl.setDateRange(from, to);

      // Assert
      expect(ctrl.fromEpochMs, from);
      expect(ctrl.toEpochMs, to);
    });

    test('null을 전달하면 null로 초기화', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.setDateRange(1700000000000, 1700086400000);

      // Act
      ctrl.setDateRange(null, null);

      // Assert
      expect(ctrl.fromEpochMs, isNull);
      expect(ctrl.toEpochMs, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 차량 선택
  // ─────────────────────────────────────────────
  group('selectVehicle', () {
    test('차량 선택 후 selectedVehicle 갱신', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      final Vehicle vehicle = Vehicle(
        vehicleId: 7,
        make: 'Hyundai',
        modelName: 'Ioniq5',
      );

      // Act
      ctrl.selectVehicle(vehicle);

      // Assert
      expect(ctrl.selectedVehicle, isNotNull);
      expect(ctrl.selectedVehicle!.vehicleId, 7);
      expect(ctrl.selectedVehicleId, 7);
    });

    test('다른 차량으로 재선택 시 selectedVehicle 변경', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      final Vehicle car1 = Vehicle(vehicleId: 1, make: 'Kia');
      final Vehicle car2 = Vehicle(vehicleId: 2, make: 'Genesis');
      ctrl.selectVehicle(car1);

      // Act
      ctrl.selectVehicle(car2);

      // Assert
      expect(ctrl.selectedVehicle!.vehicleId, 2);
      expect(ctrl.selectedVehicle!.make, 'Genesis');
    });
  });

  // ─────────────────────────────────────────────
  // 차량 선택 해제
  // ─────────────────────────────────────────────
  group('clearSelection', () {
    test('선택 해제 후 selectedVehicle은 null', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.selectVehicle(Vehicle(vehicleId: 3));

      // Act
      ctrl.clearSelection();

      // Assert
      expect(ctrl.selectedVehicle, isNull);
      expect(ctrl.selectedVehicleId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 히스토리 초기화
  // ─────────────────────────────────────────────
  group('clearHistory', () {
    test('historyItems, totalCount, offset, latestInfo가 초기화', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      // 내부 상태를 직접 조작하여 비어있지 않은 상태로 설정
      ctrl.historyItemsInternal = [VehicleInfoHistory(historyId: 1)];
      ctrl.historyTotalCountInternal = 10;
      ctrl.historyOffsetInternal = 18;
      ctrl.latestVehicleInfoInternal = VehicleInfo(id: 1);

      // Act
      ctrl.clearHistory();

      // Assert
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.latestVehicleInfo, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 상태(Status) 초기화
  // ─────────────────────────────────────────────
  group('clearStatus', () {
    test('statusItems, totalCount, offset이 초기화', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.statusItemsInternal = [VehicleInfo(id: 1)];
      ctrl.statusTotalCountInternal = 50;
      ctrl.statusOffsetInternal = 100;

      // Act
      ctrl.clearStatus();

      // Assert
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
      expect(ctrl.statusOffset, 0);
    });
  });

  // ─────────────────────────────────────────────
  // 전체 리셋
  // ─────────────────────────────────────────────
  group('reset', () {
    test('모든 상태가 초기값으로 리셋', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.selectVehicle(Vehicle(vehicleId: 99));
      ctrl.setDateRange(1700000000, 1700001000);
      ctrl.historyItemsInternal = [VehicleInfoHistory(historyId: 1)];
      ctrl.historyTotalCountInternal = 5;
      ctrl.statusItemsInternal = [VehicleInfo(id: 1)];
      ctrl.isLoadingInternal = true;

      // Act
      ctrl.reset();

      // Assert
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.vehicles, isEmpty);
      expect(ctrl.selectedVehicle, isNull);
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.historyLimit, 18);
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
      expect(ctrl.statusLimit, 100);
      expect(ctrl.latestVehicleInfo, isNull);
      expect(ctrl.fromEpochMs, isNull);
      expect(ctrl.toEpochMs, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // hasToken — 토큰 없는 경우
  // ─────────────────────────────────────────────
  group('hasToken', () {
    test('UserController에 토큰이 없으면 false 반환', () {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      // setUp에서 등록된 UserController는 로그인 없이 _accessToken=null

      // Act
      final bool result = ctrl.hasToken;

      // Assert
      expect(result, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadVehicles — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadVehicles 토큰 없음', () {
    test('hasToken=false이면 vehicles를 비우고 false 반환', () async {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.vehiclesInternal = [Vehicle(vehicleId: 1)];

      // Act
      final bool success = await ctrl.reqLoadVehicles();

      // Assert
      expect(success, isFalse);
      expect(ctrl.vehicles, isEmpty);
      expect(ctrl.selectedVehicle, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadHistory — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadHistory 토큰 없음', () {
    test('hasToken=false이면 historyItems를 비우고 반환', () async {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.historyItemsInternal = [VehicleInfoHistory(historyId: 1)];
      ctrl.historyTotalCountInternal = 3;

      // Act
      await ctrl.reqLoadHistory();

      // Assert
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadStatus — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadStatus 토큰 없음', () {
    test('hasToken=false이면 statusItems를 비우고 반환', () async {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.statusItemsInternal = [VehicleInfo(id: 1)];
      ctrl.statusTotalCountInternal = 5;

      // Act
      await ctrl.reqLoadStatus();

      // Assert
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadLatestVehicleInfo — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadLatestVehicleInfo 토큰 없음', () {
    test('hasToken=false이면 latestVehicleInfo를 null로 설정', () async {
      // Arrange
      final VehicleController ctrl = Get.find<VehicleController>();
      ctrl.latestVehicleInfoInternal = VehicleInfo(id: 99);

      // Act
      await ctrl.reqLoadLatestVehicleInfo(1);

      // Assert
      expect(ctrl.latestVehicleInfo, isNull);
    });
  });
}
