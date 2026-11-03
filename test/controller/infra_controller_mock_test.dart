// test/controller/infra_controller_mock_test.dart
//
// InfraController 모킹 테스트 — Fake Repository로 HTTP 없이
// Repository 호출 결과가 상태에 올바르게 반영되는지 검증한다.
// Triple-A 패턴 (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/infra_model.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';

import '../mocks/fake_repositories.dart';

void main() {
  late FakeInfraRepository fakeRepo;
  late InfraController ctrl;

  setUp(() {
    Get.testMode = true;
    fakeRepo = FakeInfraRepository();

    // 토큰을 주입하여 hasToken=true 상태 만들기
    final userCtrl = Get.put(UserController());
    userCtrl.accessTokenForTest = 'fake_token_for_test';

    ctrl = Get.put(InfraController(repository: fakeRepo));
  });

  tearDown(() {
    Get.deleteAll();
  });

  // ─────────────────────────────────────────────
  // reqLoadInfraIdentifiers — 인프라 식별자 목록
  // ─────────────────────────────────────────────
  group('reqLoadInfraIdentifiers — Repository 연동', () {
    test('Repository가 ID 목록을 반환하면 오름차순 정렬하여 저장', () async {
      // Arrange — 순서가 뒤섞인 ID 목록
      fakeRepo.identifiersResult = <int>[3, 1, 5, 2];

      // Act
      await ctrl.reqLoadInfraIdentifiers();

      // Assert — 중복 제거 후 정렬
      expect(ctrl.infraIdentifiers, orderedEquals(<int>[1, 2, 3, 5]));
    });

    test('중복 ID가 있으면 하나만 남기고 정렬', () async {
      // Arrange
      fakeRepo.identifiersResult = <int>[2, 1, 2, 3, 1];

      // Act
      await ctrl.reqLoadInfraIdentifiers();

      // Assert
      expect(ctrl.infraIdentifiers, orderedEquals(<int>[1, 2, 3]));
    });

    test('Repository가 빈 목록을 반환하면 infraIdentifiers도 빈 리스트', () async {
      // Arrange
      fakeRepo.identifiersResult = <int>[];

      // Act
      await ctrl.reqLoadInfraIdentifiers();

      // Assert
      expect(ctrl.infraIdentifiers, isEmpty);
    });

    test('Repository 예외 시 infraIdentifiers 초기화', () async {
      // Arrange
      ctrl.infraIdentifiersInternal = <int>[1, 2, 3];
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadInfraIdentifiers();

      // Assert
      expect(ctrl.infraIdentifiers, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadLatestInfraInfo — 최신 인프라 정보
  // ─────────────────────────────────────────────
  group('reqLoadLatestInfraInfo — Repository 연동', () {
    test('Repository가 InfraInfo를 반환하면 latestInfraInfo에 저장', () async {
      // Arrange
      fakeRepo.latestInfoResult = InfraInfo(
        infraId: 1,
        numberOfObjects: 5,
        timeStampMs: 1700000000000,
      );

      // Act
      await ctrl.reqLoadLatestInfraInfo(1);

      // Assert
      expect(ctrl.latestInfraInfo, isNotNull);
      expect(ctrl.latestInfraInfo!.infraId, 1);
      expect(ctrl.latestInfraInfo!.numberOfObjects, 5);
    });

    test('Repository가 null 반환하면 latestInfraInfo는 null', () async {
      // Arrange
      fakeRepo.latestInfoResult = null;

      // Act
      await ctrl.reqLoadLatestInfraInfo(1);

      // Assert
      expect(ctrl.latestInfraInfo, isNull);
    });

    test('Repository 예외 시 latestInfraInfo는 null 유지', () async {
      // Arrange
      ctrl.latestInfraInfoInternal = InfraInfo(infraId:999);
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadLatestInfraInfo(1);

      // Assert
      expect(ctrl.latestInfraInfo, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadHistory — 히스토리 로드
  // ─────────────────────────────────────────────
  group('reqLoadHistory — Repository 연동', () {
    test('Repository가 결과를 반환하면 historyItems와 totalCount 갱신', () async {
      // Arrange
      fakeRepo.historyResult = InfraInfoHistoryResult(
        totalCount: 2,
        items: <InfraInfoHistory>[
          InfraInfoHistory(historyId: 10, infraId: 1),
          InfraInfoHistory(historyId: 11, infraId: 1),
        ],
      );

      // Act
      await ctrl.reqLoadHistory(infraId: 1, offset: 0, limit: 18);

      // Assert
      expect(ctrl.historyItems.length, 2);
      expect(ctrl.historyTotalCount, 2);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.isLoading, isFalse);
    });

    test('offset 페이지네이션 — offset 18이면 historyOffset=18 저장', () async {
      // Arrange
      fakeRepo.historyResult = InfraInfoHistoryResult(
        totalCount: 40,
        items: <InfraInfoHistory>[InfraInfoHistory(historyId: 19)],
      );

      // Act
      await ctrl.reqLoadHistory(offset: 18, limit: 18);

      // Assert
      expect(ctrl.historyOffset, 18);
    });

    test('Repository가 null 반환하면 기존 historyItems 유지 + 실패 플래그', () async {
      // Arrange — 요청 실패 시 기존 데이터 유지 정책 (빈 테이블 방지)
      ctrl.historyItemsInternal = <InfraInfoHistory>[
        InfraInfoHistory(historyId: 1),
      ];
      ctrl.historyTotalCountInternal = 1;
      fakeRepo.historyResult = null;

      // Act
      await ctrl.reqLoadHistory();

      // Assert
      expect(ctrl.historyItems.length, 1);
      expect(ctrl.historyTotalCount, 1);
      expect(ctrl.historyLoadFailedInternal, isTrue);
    });

    test('Repository 예외 시 기존 historyItems 유지 및 isLoading=false', () async {
      // Arrange — 예외 시에도 기존 데이터 유지 정책 (빈 테이블 방지)
      ctrl.historyItemsInternal = <InfraInfoHistory>[
        InfraInfoHistory(historyId: 1),
      ];
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadHistory();

      // Assert
      expect(ctrl.historyItems.length, 1);
      expect(ctrl.historyLoadFailedInternal, isTrue);
      expect(ctrl.isLoading, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadStatus — 상태(Status) 로드
  // ─────────────────────────────────────────────
  group('reqLoadStatus — Repository 연동', () {
    test('Repository가 결과를 반환하면 statusItems와 totalCount 갱신', () async {
      // Arrange
      fakeRepo.statusResult = InfraInfoResult(
        totalCount: 3,
        items: <InfraInfo>[
          InfraInfo(infraId: 1, numberOfObjects: 2),
          InfraInfo(infraId: 2, numberOfObjects: 0),
          InfraInfo(infraId: 3, numberOfObjects: 5),
        ],
      );

      // Act
      await ctrl.reqLoadStatus(limit: 100, offset: 0);

      // Assert
      expect(ctrl.statusItems.length, 3);
      expect(ctrl.statusTotalCount, 3);
      expect(ctrl.statusItems[2].numberOfObjects, 5);
    });

    test('Repository 예외 시 statusItems 초기화', () async {
      // Arrange
      ctrl.statusItemsInternal = <InfraInfo>[InfraInfo(infraId:1)];
      fakeRepo.shouldThrow = true;

      // Act
      await ctrl.reqLoadStatus();

      // Assert
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.isLoading, isFalse);
    });
  });
}
