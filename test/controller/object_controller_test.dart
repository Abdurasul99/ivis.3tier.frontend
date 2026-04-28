// test/controller/object_controller_test.dart
//
// ObjectController 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
// 순수 상태 관리 로직과 페이지네이션 계산만 테스트 (HTTP 호출 없음)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/object_model.dart';
import 'package:ivis/viewmodel/controller/object_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';

import '../mocks/fake_repositories.dart';

void main() {
  late FakeObjectRepository fakeRepo;
  late ObjectController ctrl;

  setUp(() {
    Get.testMode = true;
    fakeRepo = FakeObjectRepository();
    Get.put(UserController());
    ctrl = Get.put(ObjectController(repository: fakeRepo));
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

      // Act (별도 호출 없음)

      // Assert
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.detectedObjects, isEmpty);
      expect(ctrl.pageLimit, 200);
      expect(ctrl.pageOffset, 0);
      expect(ctrl.totalCount, 0);
      expect(ctrl.scope, DetectedObjectScope.vehicleInfo);
      expect(ctrl.currentVehicleInfoId, isNull);
      expect(ctrl.currentInfraInfoId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // canGoPrevious — 이전 페이지 가능 여부
  // ─────────────────────────────────────────────
  group('canGoPrevious', () {
    test('pageOffset=0이면 이전 페이지 불가', () {
      // Arrange
      ctrl.pageOffsetInternal = 0;

      // Act / Assert
      expect(ctrl.canGoPrevious, isFalse);
    });

    test('pageOffset>0이면 이전 페이지 가능', () {
      // Arrange
      ctrl.pageOffsetInternal = 200;

      // Act / Assert
      expect(ctrl.canGoPrevious, isTrue);
    });

    test('로딩 중이면 이전 페이지 불가', () {
      // Arrange
      ctrl.pageOffsetInternal = 200;
      ctrl.isLoadingInternal = true;

      // Act / Assert
      expect(ctrl.canGoPrevious, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // canGoNext — 다음 페이지 가능 여부
  // ─────────────────────────────────────────────
  group('canGoNext', () {
    test('전체 항목 수 이하면 다음 페이지 불가', () {
      // Arrange
      ctrl.totalCountInternal = 100;
      ctrl.pageOffsetInternal = 0;
      ctrl.pageLimitInternal = 200;
      ctrl.detectedObjectsInternal = List<DetectedObject>.generate(
        100, // totalCount와 같으므로 다음 없음
        (i) => DetectedObject(detectedObjectId: i),
      );

      // Act / Assert
      expect(ctrl.canGoNext, isFalse);
    });

    test('현재 오프셋 + 항목 수 < totalCount이면 다음 페이지 가능', () {
      // Arrange
      ctrl.totalCountInternal = 300;
      ctrl.pageOffsetInternal = 0;
      ctrl.detectedObjectsInternal = List<DetectedObject>.generate(
        200,
        (i) => DetectedObject(detectedObjectId: i),
      );

      // Act / Assert
      expect(ctrl.canGoNext, isTrue);
    });

    test('로딩 중이면 다음 페이지 불가', () {
      // Arrange
      ctrl.totalCountInternal = 300;
      ctrl.isLoadingInternal = true;

      // Act / Assert
      expect(ctrl.canGoNext, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // currentPageNumber — 현재 페이지 번호 계산
  // ─────────────────────────────────────────────
  group('currentPageNumber', () {
    test('pageOffset=0이면 1페이지', () {
      // Arrange
      ctrl.pageOffsetInternal = 0;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.currentPageNumber, 1);
    });

    test('pageOffset=200이면 2페이지 (limit=200)', () {
      // Arrange
      ctrl.pageOffsetInternal = 200;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.currentPageNumber, 2);
    });

    test('pageOffset=400이면 3페이지 (limit=200)', () {
      // Arrange
      ctrl.pageOffsetInternal = 400;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.currentPageNumber, 3);
    });
  });

  // ─────────────────────────────────────────────
  // totalPages — 전체 페이지 수 계산
  // ─────────────────────────────────────────────
  group('totalPages', () {
    test('totalCount=0이면 1 반환', () {
      // Arrange
      ctrl.totalCountInternal = 0;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.totalPages, 1);
    });

    test('totalCount=200, limit=200이면 1 반환', () {
      // Arrange
      ctrl.totalCountInternal = 200;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.totalPages, 1);
    });

    test('totalCount=201, limit=200이면 2 반환', () {
      // Arrange
      ctrl.totalCountInternal = 201;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.totalPages, 2);
    });

    test('totalCount=600, limit=200이면 3 반환', () {
      // Arrange
      ctrl.totalCountInternal = 600;
      ctrl.pageLimitInternal = 200;

      // Act / Assert
      expect(ctrl.totalPages, 3);
    });
  });

  // ─────────────────────────────────────────────
  // reset — 전체 상태 초기화
  // ─────────────────────────────────────────────
  group('reset', () {
    test('모든 상태가 초기값으로 리셋', () {
      // Arrange
      ctrl.detectedObjectsInternal = <DetectedObject>[
        DetectedObject(detectedObjectId: 1),
      ];
      ctrl.isLoadingInternal = true;
      ctrl.pageLimitInternal = 500;
      ctrl.pageOffsetInternal = 400;
      ctrl.totalCountInternal = 1000;
      ctrl.currentVehicleInfoIdInternal = 10;
      ctrl.currentInfraInfoIdInternal = 20;

      // Act
      ctrl.reset();

      // Assert
      expect(ctrl.detectedObjects, isEmpty);
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.pageLimit, 200);
      expect(ctrl.pageOffset, 0);
      expect(ctrl.totalCount, 0);
      expect(ctrl.scope, DetectedObjectScope.vehicleInfo);
      expect(ctrl.currentVehicleInfoId, isNull);
      expect(ctrl.currentInfraInfoId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // hasToken — 토큰 없는 경우
  // ─────────────────────────────────────────────
  group('hasToken', () {
    test('UserController에 토큰이 없으면 false 반환', () {
      // Act / Assert
      expect(ctrl.hasToken, isFalse);
    });

    test('토큰이 있으면 true 반환', () {
      // Arrange
      final UserController userCtrl = Get.find<UserController>();
      userCtrl.accessTokenForTest = 'some_token';

      // Act / Assert
      expect(ctrl.hasToken, isTrue);
    });
  });

  // ─────────────────────────────────────────────
  // loadPage — 토큰 없는 경우
  // ─────────────────────────────────────────────
  group('loadPage 토큰 없음', () {
    test('hasToken=false이면 detectedObjects를 비우고 반환', () async {
      // Arrange
      ctrl.detectedObjectsInternal = <DetectedObject>[
        DetectedObject(detectedObjectId: 1),
      ];
      ctrl.currentVehicleInfoIdInternal = 5;

      // Act (UserController에 토큰 없음 — setUp 기본 상태)
      await ctrl.loadPage(offset: 0, limit: 200);

      // Assert
      expect(ctrl.detectedObjects, isEmpty);
      expect(ctrl.totalCount, 0);
    });
  });

  // ─────────────────────────────────────────────
  // loadPage — Repository 연동 (Fake)
  // ─────────────────────────────────────────────
  group('loadPage — Repository 연동', () {
    setUp(() {
      // 토큰 주입
      Get.find<UserController>().accessTokenForTest = 'test_token';
    });

    test('vehicle 스코프에서 Repository가 결과를 반환하면 상태 갱신', () async {
      // Arrange
      ctrl.scopeInternal = DetectedObjectScope.vehicleInfo;
      ctrl.currentVehicleInfoIdInternal = 1;
      fakeRepo.byVehicleInfoResult = DetectedObjectResult(
        totalCount: 2,
        items: <DetectedObject>[
          DetectedObject(detectedObjectId: 10, objectType: 1),
          DetectedObject(detectedObjectId: 11, objectType: 2),
        ],
      );

      // Act
      await ctrl.loadPage(offset: 0, limit: 200);

      // Assert
      expect(ctrl.detectedObjects.length, 2);
      expect(ctrl.totalCount, 2);
      expect(ctrl.pageOffset, 0);
      expect(ctrl.isLoading, isFalse);
    });

    test('infra 스코프에서 Repository가 결과를 반환하면 상태 갱신', () async {
      // Arrange
      ctrl.scopeInternal = DetectedObjectScope.infraInfo;
      ctrl.currentInfraInfoIdInternal = 5;
      fakeRepo.byInfraInfoResult = DetectedObjectResult(
        totalCount: 3,
        items: <DetectedObject>[
          DetectedObject(detectedObjectId: 20, objectType: 0),
          DetectedObject(detectedObjectId: 21, objectType: 3),
          DetectedObject(detectedObjectId: 22, objectType: 4),
        ],
      );

      // Act
      await ctrl.loadPage(offset: 0, limit: 200);

      // Assert
      expect(ctrl.detectedObjects.length, 3);
      expect(ctrl.totalCount, 3);
    });

    test('Repository 예외 시 detectedObjects 초기화', () async {
      // Arrange
      ctrl.scopeInternal = DetectedObjectScope.vehicleInfo;
      ctrl.currentVehicleInfoIdInternal = 1;
      ctrl.detectedObjectsInternal = <DetectedObject>[
        DetectedObject(detectedObjectId: 1),
      ];
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.loadPage(offset: 0, limit: 200);

      // Assert
      expect(ctrl.detectedObjects, isEmpty);
      expect(ctrl.isLoading, isFalse);
    });
  });
}
