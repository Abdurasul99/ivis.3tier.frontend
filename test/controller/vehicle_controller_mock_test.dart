// test/controller/vehicle_controller_mock_test.dart
//
// VehicleController 모킹 테스트 — HTTP 없이 Repository를 Fake로 교체하여
// 컨트롤러가 Repository 호출 결과를 상태에 올바르게 반영하는지 검증한다.
// Triple-A 패턴 (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/vehicle_model.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';

import '../mocks/fake_repositories.dart';

void main() {
  late FakeVehicleRepository fakeRepo;
  late VehicleController ctrl;

  setUp(() {
    Get.testMode = true;
    fakeRepo = FakeVehicleRepository();

    // UserController를 먼저 등록 (hasToken 확인용)
    final userCtrl = Get.put(UserController());
    // 테스트 전용 setter로 토큰을 주입하여 hasToken=true 상태 만들기
    userCtrl.accessTokenForTest = 'fake_token_for_test';

    // Fake Repository를 주입한 VehicleController 등록
    ctrl = Get.put(VehicleController(repository: fakeRepo));
  });

  tearDown(() {
    Get.deleteAll();
  });

  // ─────────────────────────────────────────────
  // reqLoadVehicles — 차량 목록 로드
  // ─────────────────────────────────────────────
  group('reqLoadVehicles — Repository 연동', () {
    test('Repository가 차량 목록을 반환하면 vehicles에 저장하고 true 반환', () async {
      // Arrange
      fakeRepo.vehicleListResult = <Vehicle>[
        Vehicle(vehicleId: 1, make: 'Hyundai', modelName: 'Ioniq5'),
        Vehicle(vehicleId: 2, make: 'Kia', modelName: 'EV6'),
      ];

      // Act
      final bool success = await ctrl.reqLoadVehicles();

      // Assert
      expect(success, isTrue);
      expect(ctrl.vehicles.length, 2);
      expect(ctrl.vehicles[0].vehicleId, 1);
      expect(ctrl.vehicles[1].make, 'Kia');
      expect(ctrl.isLoading, isFalse); // 로딩 완료 후 false
    });

    test('Repository가 빈 목록을 반환하면 vehicles는 비고 첫 차량 선택 없음', () async {
      // Arrange
      fakeRepo.vehicleListResult = <Vehicle>[];

      // Act
      final bool success = await ctrl.reqLoadVehicles();

      // Assert
      expect(success, isTrue);
      expect(ctrl.vehicles, isEmpty);
      expect(ctrl.selectedVehicle, isNull);
    });

    test('목록에 차량이 있고 선택 차량이 없으면 첫 번째 차량이 자동 선택', () async {
      // Arrange
      fakeRepo.vehicleListResult = <Vehicle>[
        Vehicle(vehicleId: 10, make: 'Genesis'),
        Vehicle(vehicleId: 20, make: 'KG'),
      ];

      // Act
      await ctrl.reqLoadVehicles();

      // Assert
      expect(ctrl.selectedVehicle, isNotNull);
      expect(ctrl.selectedVehicle!.vehicleId, 10); // 첫 번째 차량
    });

    test('이미 선택된 차량이 있으면 자동 선택을 덮어쓰지 않음', () async {
      // Arrange — 미리 차량 선택
      ctrl.selectVehicle(Vehicle(vehicleId: 99, make: 'Tesla'));
      fakeRepo.vehicleListResult = <Vehicle>[
        Vehicle(vehicleId: 1, make: 'Hyundai'),
      ];

      // Act
      await ctrl.reqLoadVehicles();

      // Assert — 선택이 유지됨
      expect(ctrl.selectedVehicle!.vehicleId, 99);
    });

    test('Repository가 예외를 던지면 vehicles를 비우고 false 반환', () async {
      // Arrange
      fakeRepo.shouldThrow = true;

      // Act
      final bool success = await ctrl.reqLoadVehicles();

      // Assert
      expect(success, isFalse);
      expect(ctrl.vehicles, isEmpty);
      expect(ctrl.selectedVehicle, isNull);
      expect(ctrl.isLoading, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadLatestVehicleInfo — 최신 차량 정보 로드
  // ─────────────────────────────────────────────
  group('reqLoadLatestVehicleInfo — Repository 연동', () {
    test('Repository가 VehicleInfo를 반환하면 latestVehicleInfo에 저장', () async {
      // Arrange
      fakeRepo.latestInfoResult = VehicleInfo(
        id: 500,
        vehicleId: 1,
        velocityKph: 80.0,
        orientationHeading: 45.0,
      );

      // Act
      await ctrl.reqLoadLatestVehicleInfo(1);

      // Assert
      expect(ctrl.latestVehicleInfo, isNotNull);
      expect(ctrl.latestVehicleInfo!.id, 500);
      expect(ctrl.latestVehicleInfo!.velocityKph, 80.0);
    });

    test('Repository가 null 반환하면 latestVehicleInfo는 null', () async {
      // Arrange
      fakeRepo.latestInfoResult = null;

      // Act
      await ctrl.reqLoadLatestVehicleInfo(1);

      // Assert
      expect(ctrl.latestVehicleInfo, isNull);
    });

    test('Repository 예외 시 latestVehicleInfo는 null 유지', () async {
      // Arrange
      ctrl.latestVehicleInfoInternal = VehicleInfo(id: 999); // 기존 값
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadLatestVehicleInfo(1);

      // Assert
      expect(ctrl.latestVehicleInfo, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadHistory — 히스토리 로드
  // ─────────────────────────────────────────────
  group('reqLoadHistory — Repository 연동', () {
    test('Repository가 결과를 반환하면 historyItems와 totalCount 갱신', () async {
      // Arrange
      fakeRepo.historyResult = VehicleInfoHistoryResult(
        totalCount: 3,
        items: <VehicleInfoHistory>[
          VehicleInfoHistory(historyId: 1, vehicleId: 1),
          VehicleInfoHistory(historyId: 2, vehicleId: 1),
          VehicleInfoHistory(historyId: 3, vehicleId: 1),
        ],
      );

      // Act
      await ctrl.reqLoadHistory(vehicleId: 1, offset: 0, limit: 18);

      // Assert
      expect(ctrl.historyItems.length, 3);
      expect(ctrl.historyTotalCount, 3);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.historyLimit, 18);
      expect(ctrl.isLoading, isFalse);
    });

    test('offset 페이지네이션 — offset 18이면 historyOffset=18 저장', () async {
      // Arrange
      fakeRepo.historyResult = VehicleInfoHistoryResult(
        totalCount: 50,
        items: <VehicleInfoHistory>[
          VehicleInfoHistory(historyId: 19),
        ],
      );

      // Act
      await ctrl.reqLoadHistory(offset: 18, limit: 18);

      // Assert
      expect(ctrl.historyOffset, 18);
      expect(ctrl.historyItems.length, 1);
    });

    test('Repository가 null 반환하면 historyItems 초기화', () async {
      // Arrange — 기존 데이터 설정
      ctrl.historyItemsInternal = <VehicleInfoHistory>[
        VehicleInfoHistory(historyId: 1),
      ];
      ctrl.historyTotalCountInternal = 1;
      fakeRepo.historyResult = null;

      // Act
      await ctrl.reqLoadHistory();

      // Assert
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
    });

    test('Repository 예외 시 historyItems 초기화', () async {
      // Arrange
      ctrl.historyItemsInternal = <VehicleInfoHistory>[
        VehicleInfoHistory(historyId: 1),
      ];
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadHistory();

      // Assert
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.isLoading, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadStatus — 상태(Status) 로드
  // ─────────────────────────────────────────────
  group('reqLoadStatus — Repository 연동', () {
    test('Repository가 결과를 반환하면 statusItems와 totalCount 갱신', () async {
      // Arrange
      fakeRepo.statusResult = VehicleInfoResult(
        totalCount: 2,
        items: <VehicleInfo>[
          VehicleInfo(id: 1, velocityKph: 60.0),
          VehicleInfo(id: 2, velocityKph: 80.0),
        ],
      );

      // Act
      await ctrl.reqLoadStatus(limit: 100, offset: 0);

      // Assert
      expect(ctrl.statusItems.length, 2);
      expect(ctrl.statusTotalCount, 2);
      expect(ctrl.statusItems[0].velocityKph, 60.0);
    });

    test('Repository 예외 시 statusItems 초기화 및 isLoading=false', () async {
      // Arrange
      ctrl.statusItemsInternal = <VehicleInfo>[VehicleInfo(id: 1)];
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadStatus();

      // Assert
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.isLoading, isFalse);
    });
  });
}
