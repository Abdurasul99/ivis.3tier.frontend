// test/controller/infra_controller_test.dart
// InfraController 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
// 순수 상태 관리 로직만 테스트 (HTTP 호출 없음)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/infra_model.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    // InfraController.hasToken이 UserController를 참조하므로 먼저 등록
    Get.put(UserController());
    Get.put(InfraController());
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
      final InfraController ctrl = Get.find<InfraController>();

      // Act (별도 호출 없음)

      // Assert
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.infraIdentifiers, isEmpty);
      expect(ctrl.selectedInfraId, isNull);
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.historyLimit, 18);
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
      expect(ctrl.statusOffset, 0);
      expect(ctrl.statusLimit, 100);
      expect(ctrl.latestInfraInfo, isNull);
      expect(ctrl.fromEpochMs, isNull);
      expect(ctrl.toEpochMs, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 인프라 ID 선택
  // ─────────────────────────────────────────────
  group('setSelectedInfraId', () {
    test('ID 설정 후 selectedInfraId 반영', () {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();

      // Act
      ctrl.setSelectedInfraId(5);

      // Assert
      expect(ctrl.selectedInfraId, 5);
    });

    test('null 설정 시 selectedInfraId는 null', () {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.setSelectedInfraId(10);

      // Act
      ctrl.setSelectedInfraId(null);

      // Assert
      expect(ctrl.selectedInfraId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 날짜 범위 설정
  // ─────────────────────────────────────────────
  group('setDateRange', () {
    test('fromMs와 toMs를 정상 설정', () {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
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
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.setDateRange(1700000000000, 1700086400000);

      // Act
      ctrl.setDateRange(null, null);

      // Assert
      expect(ctrl.fromEpochMs, isNull);
      expect(ctrl.toEpochMs, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 히스토리 초기화
  // ─────────────────────────────────────────────
  group('clearHistory', () {
    test('historyItems, totalCount, offset, latestInfo가 초기화', () {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.historyItemsInternal = <InfraInfoHistory>[
        InfraInfoHistory(historyId: 1),
      ];
      ctrl.historyTotalCountInternal = 10;
      ctrl.historyOffsetInternal = 18;
      ctrl.latestInfraInfoInternal = InfraInfo(id: 1);

      // Act
      ctrl.clearHistory();

      // Assert
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.latestInfraInfo, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 상태(Status) 초기화
  // ─────────────────────────────────────────────
  group('clearStatus', () {
    test('statusItems, totalCount, offset이 초기화', () {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.statusItemsInternal = <InfraInfo>[InfraInfo(id: 1)];
      ctrl.statusTotalCountInternal = 20;
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
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.setSelectedInfraId(7);
      ctrl.setDateRange(1700000000, 1700001000);
      ctrl.historyItemsInternal = <InfraInfoHistory>[
        InfraInfoHistory(historyId: 1),
      ];
      ctrl.historyTotalCountInternal = 5;
      ctrl.statusItemsInternal = <InfraInfo>[InfraInfo(id: 1)];
      ctrl.isLoadingInternal = true;
      ctrl.infraIdentifiersInternal = <int>[1, 2, 3];

      // Act
      ctrl.reset();

      // Assert
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.infraIdentifiers, isEmpty);
      expect(ctrl.selectedInfraId, isNull);
      expect(ctrl.historyItems, isEmpty);
      expect(ctrl.historyTotalCount, 0);
      expect(ctrl.historyOffset, 0);
      expect(ctrl.historyLimit, 18);
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
      expect(ctrl.statusLimit, 100);
      expect(ctrl.latestInfraInfo, isNull);
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
      final InfraController ctrl = Get.find<InfraController>();
      // setUp에서 등록된 UserController는 로그인 없이 _accessToken=null

      // Act
      final bool result = ctrl.hasToken;

      // Assert
      expect(result, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadInfraIdentifiers — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadInfraIdentifiers 토큰 없음', () {
    test('hasToken=false이면 infraIdentifiers를 비우고 반환', () async {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.infraIdentifiersInternal = <int>[1, 2, 3];

      // Act
      await ctrl.reqLoadInfraIdentifiers();

      // Assert
      expect(ctrl.infraIdentifiers, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadHistory — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadHistory 토큰 없음', () {
    test('hasToken=false이면 historyItems를 비우고 반환', () async {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.historyItemsInternal = <InfraInfoHistory>[
        InfraInfoHistory(historyId: 1),
      ];
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
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.statusItemsInternal = <InfraInfo>[InfraInfo(id: 1)];
      ctrl.statusTotalCountInternal = 5;

      // Act
      await ctrl.reqLoadStatus();

      // Assert
      expect(ctrl.statusItems, isEmpty);
      expect(ctrl.statusTotalCount, 0);
    });
  });

  // ─────────────────────────────────────────────
  // reqLoadLatestInfraInfo — 토큰 없을 때
  // ─────────────────────────────────────────────
  group('reqLoadLatestInfraInfo 토큰 없음', () {
    test('hasToken=false이면 latestInfraInfo를 null로 설정', () async {
      // Arrange
      final InfraController ctrl = Get.find<InfraController>();
      ctrl.latestInfraInfoInternal = InfraInfo(id: 99);

      // Act
      await ctrl.reqLoadLatestInfraInfo(1);

      // Assert
      expect(ctrl.latestInfraInfo, isNull);
    });
  });
}
