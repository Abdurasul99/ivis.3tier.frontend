// test/widgets/dashboard_widgets_test.dart
//
// 대시보드(TabDashboard) 위젯 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
//
// 실제 TabDashboard 는 InfraVehicleMapPanel + GoogleMap + PlutoGrid + 다수
// 컨트롤러 (DashboardController, VehicleController, InfraController, ...)에
// 의존하므로 단위 위젯 테스트로 직접 펌프 하기 어렵다.
//
// 본 테스트는 대시보드의 핵심 UI 동작 — 엔티티 탭, 지도 토글, 필터 칩,
// 객체 타입 칩, 새로고침 버튼, 차량 리스트 아이템 탭 — 만을 추출한
// "Harness" 위젯들을 사용해 각 onTap/onChanged 콜백이 모킹된 컨트롤러
// 인터페이스에 올바르게 디스패치되는지 검증한다.
//
// Mockito 는 build_runner 없이 동작하도록 수기로 작성된 Mock 클래스를 사용.
//
// 검증 항목:
//   1. 엔티티 탭 클릭 (vehicle/infra) → changeEntityType 호출
//   2. 지도 토글 버튼 → enableMapView / disableMapView
//   3. 지도 닫기 버튼 → disableMapView
//   4. 팔로우 토글 → toggleAutoFollow
//   5. 객체 토글 → toggleObjectsDisplay
//   6. 지역 필터 칩 × 5 → activeFilterValue 설정
//   7. 객체 타입 칩 × 6 → filter applied
//   8. 새로고침 버튼 → refreshCurrent
//   9. 차량 리스트 아이템 탭 → selectVehicle
//  10. 컬럼 셀렉터 → applyColumnFilter
//  11. 다운로드 버튼 → export triggered
//  12. 전체 지도 모드 토글 → enableFullMapMode / disableFullMapMode

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 테스트 전용 엔티티 / 인터페이스 정의
// 실제 DashboardController 대신 추상 인터페이스를 통해 모킹한다.
// ─────────────────────────────────────────────────────────────────────────────
enum FmsEntityType { vehicle, infra }

abstract class IDashboardController {
  void changeEntityType(FmsEntityType type);
  void enableMapView();
  void disableMapView();
  void enableFullMapMode();
  void disableFullMapMode();
  void refreshCurrent();
  void applyActiveFilter(String? column, String? value);
  void applyColumnFilter(Set<String> visibleFields);
  void triggerExport();
  void selectVehicle(int vehicleId);
  void toggleAutoFollow();
  void toggleObjectsDisplay();
}

// ─────────────────────────────────────────────────────────────────────────────
// MockDashboardController — Mockito 수기 작성 Mock
// ─────────────────────────────────────────────────────────────────────────────
class MockDashboardController extends Mock implements IDashboardController {
  @override
  void changeEntityType(FmsEntityType? type) => super.noSuchMethod(
        Invocation.method(#changeEntityType, <Object?>[type]),
        returnValueForMissingStub: null,
      );

  @override
  void enableMapView() => super.noSuchMethod(
        Invocation.method(#enableMapView, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void disableMapView() => super.noSuchMethod(
        Invocation.method(#disableMapView, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void enableFullMapMode() => super.noSuchMethod(
        Invocation.method(#enableFullMapMode, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void disableFullMapMode() => super.noSuchMethod(
        Invocation.method(#disableFullMapMode, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void refreshCurrent() => super.noSuchMethod(
        Invocation.method(#refreshCurrent, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void applyActiveFilter(String? column, String? value) => super.noSuchMethod(
        Invocation.method(#applyActiveFilter, <Object?>[column, value]),
        returnValueForMissingStub: null,
      );

  @override
  void applyColumnFilter(Set<String>? visibleFields) => super.noSuchMethod(
        Invocation.method(#applyColumnFilter, <Object?>[visibleFields]),
        returnValueForMissingStub: null,
      );

  @override
  void triggerExport() => super.noSuchMethod(
        Invocation.method(#triggerExport, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void selectVehicle(int? vehicleId) => super.noSuchMethod(
        Invocation.method(#selectVehicle, <Object?>[vehicleId]),
        returnValueForMissingStub: null,
      );

  @override
  void toggleAutoFollow() => super.noSuchMethod(
        Invocation.method(#toggleAutoFollow, <Object?>[]),
        returnValueForMissingStub: null,
      );

  @override
  void toggleObjectsDisplay() => super.noSuchMethod(
        Invocation.method(#toggleObjectsDisplay, <Object?>[]),
        returnValueForMissingStub: null,
      );
}

void main() {
  late MockDashboardController mockCtrl;

  setUp(() {
    mockCtrl = MockDashboardController();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 엔티티 탭 (Vehicle / Infra) — changeEntityType 디스패치
  // ───────────────────────────────────────────────────────────────────────────
  group('EntityTabsHarness — 엔티티 탭 클릭', () {
    Future<void> pump(WidgetTester tester, FmsEntityType current) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntityTabsHarness(
              controller: mockCtrl,
              currentEntityType: current,
            ),
          ),
        ),
      );
    }

    testWidgets('Vehicle/Infra 칩 둘 다 렌더링', (WidgetTester tester) async {
      // Arrange & Act
      await pump(tester, FmsEntityType.vehicle);

      // Assert
      expect(find.byKey(const Key('chip-vehicle')), findsOneWidget);
      expect(find.byKey(const Key('chip-infra')), findsOneWidget);
    });

    testWidgets('Vehicle 칩 탭 → changeEntityType(vehicle) 호출',
        (WidgetTester tester) async {
      // Arrange — 현재는 infra 상태
      await pump(tester, FmsEntityType.infra);

      // Act
      await tester.tap(find.byKey(const Key('chip-vehicle')));
      await tester.pump();

      // Assert
      verify(mockCtrl.changeEntityType(FmsEntityType.vehicle)).called(1);
    });

    testWidgets('Infra 칩 탭 → changeEntityType(infra) 호출',
        (WidgetTester tester) async {
      // Arrange — 현재는 vehicle 상태
      await pump(tester, FmsEntityType.vehicle);

      // Act
      await tester.tap(find.byKey(const Key('chip-infra')));
      await tester.pump();

      // Assert
      verify(mockCtrl.changeEntityType(FmsEntityType.infra)).called(1);
    });

    testWidgets('이미 선택된 엔티티 칩 재탭 → changeEntityType 호출 안함',
        (WidgetTester tester) async {
      // Arrange — 현재 vehicle 상태
      await pump(tester, FmsEntityType.vehicle);

      // Act — 이미 선택된 vehicle 재탭
      await tester.tap(find.byKey(const Key('chip-vehicle')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changeEntityType(any));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 지도 토글 (Map View Toggle) — 지도 열기/닫기
  // ───────────────────────────────────────────────────────────────────────────
  group('MapToggleHarness — 지도 열기/닫기 버튼', () {
    Future<void> pump(WidgetTester tester, bool isMapView) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapToggleHarness(
              controller: mockCtrl,
              isMapView: isMapView,
            ),
          ),
        ),
      );
    }

    testWidgets('지도 닫힌 상태에서 토글 → enableMapView 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester, false);

      // Act
      await tester.tap(find.byKey(const Key('map-toggle')));
      await tester.pump();

      // Assert
      verify(mockCtrl.enableMapView()).called(1);
      verifyNever(mockCtrl.disableMapView());
    });

    testWidgets('지도 열린 상태에서 토글 → disableMapView 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester, true);

      // Act
      await tester.tap(find.byKey(const Key('map-toggle')));
      await tester.pump();

      // Assert
      verify(mockCtrl.disableMapView()).called(1);
      verifyNever(mockCtrl.enableMapView());
    });

    testWidgets('지도 닫기 전용 버튼 탭 → 항상 disableMapView 호출',
        (WidgetTester tester) async {
      // Arrange — 지도 열린 상태에서 우상단 X 버튼
      await pump(tester, true);

      // Act
      await tester.tap(find.byKey(const Key('map-close')));
      await tester.pump();

      // Assert
      verify(mockCtrl.disableMapView()).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 전체 지도 모드 (Full Map Mode) 토글
  // ───────────────────────────────────────────────────────────────────────────
  group('FullMapModeHarness — 전체 지도 모드 토글', () {
    Future<void> pump(WidgetTester tester, bool isFullMap) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullMapModeHarness(
              controller: mockCtrl,
              isFullMapMode: isFullMap,
            ),
          ),
        ),
      );
    }

    testWidgets('일반 모드에서 토글 → enableFullMapMode',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester, false);

      // Act
      await tester.tap(find.byKey(const Key('full-map-toggle')));
      await tester.pump();

      // Assert
      verify(mockCtrl.enableFullMapMode()).called(1);
    });

    testWidgets('전체 지도 모드에서 토글 → disableFullMapMode',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester, true);

      // Act
      await tester.tap(find.byKey(const Key('full-map-toggle')));
      await tester.pump();

      // Assert
      verify(mockCtrl.disableFullMapMode()).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 팔로우 / 객체 토글 — 지도 패널 옵션
  // ───────────────────────────────────────────────────────────────────────────
  group('MapOptionsHarness — 팔로우/객체 토글', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapOptionsHarness(controller: mockCtrl),
          ),
        ),
      );
    }

    testWidgets('팔로우 토글 버튼 → toggleAutoFollow 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      await tester.tap(find.byKey(const Key('toggle-follow')));
      await tester.pump();

      // Assert
      verify(mockCtrl.toggleAutoFollow()).called(1);
    });

    testWidgets('객체 표시 토글 버튼 → toggleObjectsDisplay 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      await tester.tap(find.byKey(const Key('toggle-objects')));
      await tester.pump();

      // Assert
      verify(mockCtrl.toggleObjectsDisplay()).called(1);
    });

    testWidgets('팔로우 / 객체 버튼 동시 존재 검증', (WidgetTester tester) async {
      // Arrange & Act
      await pump(tester);

      // Assert
      expect(find.byKey(const Key('toggle-follow')), findsOneWidget);
      expect(find.byKey(const Key('toggle-objects')), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 지역 필터 칩 — 5개 (서울/경기/인천/대전/부산)
  // ───────────────────────────────────────────────────────────────────────────
  group('RegionFilterHarness — 지역 필터 칩 5종', () {
    const List<String> regions = <String>['서울', '경기', '인천', '대전', '부산'];

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RegionFilterHarness(
              controller: mockCtrl,
              regions: regions,
            ),
          ),
        ),
      );
    }

    testWidgets('5개의 지역 칩 모두 렌더링', (WidgetTester tester) async {
      // Arrange & Act
      await pump(tester);

      // Assert
      for (final String region in regions) {
        expect(find.text(region), findsOneWidget);
      }
    });

    testWidgets('서울 칩 탭 → applyActiveFilter("region", "서울")',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      await tester.tap(find.byKey(const Key('region-chip-서울')));
      await tester.pump();

      // Assert
      verify(mockCtrl.applyActiveFilter('region', '서울')).called(1);
    });

    testWidgets('부산 칩 탭 → applyActiveFilter("region", "부산")',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      await tester.tap(find.byKey(const Key('region-chip-부산')));
      await tester.pump();

      // Assert
      verify(mockCtrl.applyActiveFilter('region', '부산')).called(1);
    });

    testWidgets('5개 칩 순차 탭 → applyActiveFilter 5회 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      for (final String region in regions) {
        await tester.tap(find.byKey(Key('region-chip-$region')));
        await tester.pump();
      }

      // Assert
      verify(mockCtrl.applyActiveFilter('region', any)).called(5);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 객체 타입 칩 — 6종 (Vehicle / Pedestrian / Cyclist / Motorcycle / Truck / Bus)
  // ───────────────────────────────────────────────────────────────────────────
  group('ObjectTypeFilterHarness — 객체 타입 칩 6종', () {
    const List<String> objectTypes = <String>[
      'Vehicle',
      'Pedestrian',
      'Cyclist',
      'Motorcycle',
      'Truck',
      'Bus',
    ];

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectTypeFilterHarness(
              controller: mockCtrl,
              objectTypes: objectTypes,
            ),
          ),
        ),
      );
    }

    testWidgets('6개의 객체 타입 칩 모두 렌더링', (WidgetTester tester) async {
      // Arrange & Act
      await pump(tester);

      // Assert
      for (final String t in objectTypes) {
        expect(find.byKey(Key('obj-chip-$t')), findsOneWidget);
      }
    });

    testWidgets('Vehicle 객체 칩 탭 → applyActiveFilter("object_type", "Vehicle")',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      await tester.tap(find.byKey(const Key('obj-chip-Vehicle')));
      await tester.pump();

      // Assert
      verify(mockCtrl.applyActiveFilter('object_type', 'Vehicle')).called(1);
    });

    testWidgets('Pedestrian/Cyclist 칩 순차 탭 → 각 호출 검증',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      await tester.tap(find.byKey(const Key('obj-chip-Pedestrian')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('obj-chip-Cyclist')));
      await tester.pump();

      // Assert
      verify(mockCtrl.applyActiveFilter('object_type', 'Pedestrian'))
          .called(1);
      verify(mockCtrl.applyActiveFilter('object_type', 'Cyclist')).called(1);
    });

    testWidgets('6개 칩 모두 탭 → applyActiveFilter 6회 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester);

      // Act
      for (final String t in objectTypes) {
        await tester.tap(find.byKey(Key('obj-chip-$t')));
        await tester.pump();
      }

      // Assert
      verify(mockCtrl.applyActiveFilter('object_type', any)).called(6);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 새로고침 버튼 — refreshCurrent 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('RefreshButtonHarness — 새로고침', () {
    testWidgets('새로고침 버튼 탭 → refreshCurrent 호출',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshButtonHarness(controller: mockCtrl, isLoading: false),
          ),
        ),
      );

      // Act
      await tester.tap(find.byKey(const Key('refresh-button')));
      await tester.pump();

      // Assert
      verify(mockCtrl.refreshCurrent()).called(1);
    });

    testWidgets('로딩 중에는 새로고침 버튼 비활성화 (탭해도 호출 안됨)',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshButtonHarness(controller: mockCtrl, isLoading: true),
          ),
        ),
      );

      // Act
      await tester.tap(find.byKey(const Key('refresh-button')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.refreshCurrent());
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 다운로드 버튼 — export 트리거
  // ───────────────────────────────────────────────────────────────────────────
  group('DownloadButtonHarness — CSV 다운로드', () {
    testWidgets('다운로드 버튼 탭 → triggerExport 호출',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadButtonHarness(
                controller: mockCtrl, isExporting: false),
          ),
        ),
      );

      // Act
      await tester.tap(find.byKey(const Key('download-button')));
      await tester.pump();

      // Assert
      verify(mockCtrl.triggerExport()).called(1);
    });

    testWidgets('export 중에는 다운로드 버튼 비활성화',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body:
                DownloadButtonHarness(controller: mockCtrl, isExporting: true),
          ),
        ),
      );

      // Act
      await tester.tap(find.byKey(const Key('download-button')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.triggerExport());
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 차량 리스트 아이템 탭 — selectVehicle 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('VehicleListHarness — 차량 리스트 아이템 탭', () {
    Future<void> pump(WidgetTester tester, List<int> vehicleIds) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleListHarness(
              controller: mockCtrl,
              vehicleIds: vehicleIds,
            ),
          ),
        ),
      );
    }

    testWidgets('빈 차량 리스트는 placeholder 표시', (WidgetTester tester) async {
      // Arrange & Act
      await pump(tester, <int>[]);

      // Assert
      expect(find.text('차량 없음'), findsOneWidget);
    });

    testWidgets('차량 리스트 아이템 3개 렌더링', (WidgetTester tester) async {
      // Arrange & Act
      await pump(tester, <int>[1, 2, 3]);

      // Assert
      expect(find.byKey(const Key('vehicle-item-1')), findsOneWidget);
      expect(find.byKey(const Key('vehicle-item-2')), findsOneWidget);
      expect(find.byKey(const Key('vehicle-item-3')), findsOneWidget);
    });

    testWidgets('차량 ID=7 아이템 탭 → selectVehicle(7) 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester, <int>[5, 7, 9]);

      // Act
      await tester.tap(find.byKey(const Key('vehicle-item-7')));
      await tester.pump();

      // Assert
      verify(mockCtrl.selectVehicle(7)).called(1);
    });

    testWidgets('서로 다른 차량 아이템 순차 탭 → 각 ID 로 selectVehicle 호출',
        (WidgetTester tester) async {
      // Arrange
      await pump(tester, <int>[10, 20, 30]);

      // Act
      await tester.tap(find.byKey(const Key('vehicle-item-10')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('vehicle-item-30')));
      await tester.pump();

      // Assert
      verify(mockCtrl.selectVehicle(10)).called(1);
      verify(mockCtrl.selectVehicle(30)).called(1);
      verifyNever(mockCtrl.selectVehicle(20));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 컬럼 셀렉터 — applyColumnFilter 다이얼로그
  // ───────────────────────────────────────────────────────────────────────────
  group('ColumnSelectorHarness — 컬럼 필터', () {
    testWidgets('컬럼 선택 후 적용 버튼 → applyColumnFilter 호출',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColumnSelectorHarness(
              controller: mockCtrl,
              allFields: const <String>['vehicle_id', 'speed', 'heading'],
            ),
          ),
        ),
      );

      // Act — 'heading' 토글 끄고 적용
      await tester.tap(find.byKey(const Key('col-checkbox-heading')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('col-apply')));
      await tester.pump();

      // Assert — heading 제외 한 set 으로 applyColumnFilter 호출
      verify(mockCtrl.applyColumnFilter(<String>{'vehicle_id', 'speed'}))
          .called(1);
    });

    testWidgets('전체 선택 / 해제 토글', (WidgetTester tester) async {
      // Arrange — 처음 모두 선택된 상태
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColumnSelectorHarness(
              controller: mockCtrl,
              allFields: const <String>['a', 'b', 'c'],
            ),
          ),
        ),
      );

      // Act — Deselect All
      await tester.tap(find.byKey(const Key('col-deselect-all')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('col-apply')));
      await tester.pump();

      // Assert — 빈 set 적용
      verify(mockCtrl.applyColumnFilter(<String>{})).called(1);
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// HARNESS 위젯들 — 테스트 격리용 소형 위젯
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// EntityTabsHarness — Vehicle/Infra 칩 선택 UI
// ─────────────────────────────────────────────────────────────────────────────
class EntityTabsHarness extends StatelessWidget {
  final IDashboardController controller;
  final FmsEntityType currentEntityType;

  const EntityTabsHarness({
    super.key,
    required this.controller,
    required this.currentEntityType,
  });

  void _onTap(FmsEntityType target) {
    if (currentEntityType == target) return;
    controller.changeEntityType(target);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        InkWell(
          key: const Key('chip-vehicle'),
          onTap: () => _onTap(FmsEntityType.vehicle),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Vehicle'),
          ),
        ),
        InkWell(
          key: const Key('chip-infra'),
          onTap: () => _onTap(FmsEntityType.infra),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Infra'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MapToggleHarness — 지도 열기/닫기 토글
// ─────────────────────────────────────────────────────────────────────────────
class MapToggleHarness extends StatelessWidget {
  final IDashboardController controller;
  final bool isMapView;

  const MapToggleHarness({
    super.key,
    required this.controller,
    required this.isMapView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        InkWell(
          key: const Key('map-toggle'),
          onTap: () {
            if (isMapView) {
              controller.disableMapView();
            } else {
              controller.enableMapView();
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('지도'),
          ),
        ),
        if (isMapView)
          InkWell(
            key: const Key('map-close'),
            onTap: controller.disableMapView,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FullMapModeHarness — 전체 지도 모드 토글
// ─────────────────────────────────────────────────────────────────────────────
class FullMapModeHarness extends StatelessWidget {
  final IDashboardController controller;
  final bool isFullMapMode;

  const FullMapModeHarness({
    super.key,
    required this.controller,
    required this.isFullMapMode,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('full-map-toggle'),
      onTap: () {
        if (isFullMapMode) {
          controller.disableFullMapMode();
        } else {
          controller.enableFullMapMode();
        }
      },
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Text('전체 지도'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MapOptionsHarness — 팔로우 / 객체 표시 토글
// ─────────────────────────────────────────────────────────────────────────────
class MapOptionsHarness extends StatelessWidget {
  final IDashboardController controller;

  const MapOptionsHarness({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        InkWell(
          key: const Key('toggle-follow'),
          onTap: controller.toggleAutoFollow,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('팔로우'),
          ),
        ),
        InkWell(
          key: const Key('toggle-objects'),
          onTap: controller.toggleObjectsDisplay,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('객체'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RegionFilterHarness — 지역 필터 칩
// ─────────────────────────────────────────────────────────────────────────────
class RegionFilterHarness extends StatelessWidget {
  final IDashboardController controller;
  final List<String> regions;

  const RegionFilterHarness({
    super.key,
    required this.controller,
    required this.regions,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: regions
          .map((String r) => InkWell(
                key: Key('region-chip-$r'),
                onTap: () => controller.applyActiveFilter('region', r),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(r),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ObjectTypeFilterHarness — 객체 타입 필터 칩
// ─────────────────────────────────────────────────────────────────────────────
class ObjectTypeFilterHarness extends StatelessWidget {
  final IDashboardController controller;
  final List<String> objectTypes;

  const ObjectTypeFilterHarness({
    super.key,
    required this.controller,
    required this.objectTypes,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: objectTypes
          .map((String t) => InkWell(
                key: Key('obj-chip-$t'),
                onTap: () => controller.applyActiveFilter('object_type', t),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RefreshButtonHarness — 새로고침 버튼
// ─────────────────────────────────────────────────────────────────────────────
class RefreshButtonHarness extends StatelessWidget {
  final IDashboardController controller;
  final bool isLoading;

  const RefreshButtonHarness({
    super.key,
    required this.controller,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('refresh-button'),
      onPressed: isLoading ? null : controller.refreshCurrent,
      icon: const Icon(Icons.refresh),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DownloadButtonHarness — CSV 다운로드 버튼
// ─────────────────────────────────────────────────────────────────────────────
class DownloadButtonHarness extends StatelessWidget {
  final IDashboardController controller;
  final bool isExporting;

  const DownloadButtonHarness({
    super.key,
    required this.controller,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('download-button'),
      onPressed: isExporting ? null : controller.triggerExport,
      icon: const Icon(Icons.download),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VehicleListHarness — 사이드바 차량 리스트
// ─────────────────────────────────────────────────────────────────────────────
class VehicleListHarness extends StatelessWidget {
  final IDashboardController controller;
  final List<int> vehicleIds;

  const VehicleListHarness({
    super.key,
    required this.controller,
    required this.vehicleIds,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicleIds.isEmpty) {
      return const Center(child: Text('차량 없음'));
    }
    return ListView(
      children: vehicleIds
          .map((int id) => ListTile(
                key: Key('vehicle-item-$id'),
                title: Text('Vehicle $id'),
                onTap: () => controller.selectVehicle(id),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ColumnSelectorHarness — 컬럼 선택 다이얼로그 본문
// ─────────────────────────────────────────────────────────────────────────────
class ColumnSelectorHarness extends StatefulWidget {
  final IDashboardController controller;
  final List<String> allFields;

  const ColumnSelectorHarness({
    super.key,
    required this.controller,
    required this.allFields,
  });

  @override
  State<ColumnSelectorHarness> createState() => _ColumnSelectorHarnessState();
}

class _ColumnSelectorHarnessState extends State<ColumnSelectorHarness> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.allFields);
  }

  void _toggle(String field) {
    setState(() {
      if (_selected.contains(field)) {
        _selected.remove(field);
      } else {
        _selected.add(field);
      }
    });
  }

  void _selectAll() => setState(() {
        _selected = Set<String>.from(widget.allFields);
      });

  void _deselectAll() => setState(() => _selected = <String>{});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ...widget.allFields.map(
          (String f) => CheckboxListTile(
            key: Key('col-checkbox-$f'),
            value: _selected.contains(f),
            title: Text(f),
            onChanged: (_) => _toggle(f),
          ),
        ),
        Row(
          children: <Widget>[
            OutlinedButton(
              key: const Key('col-select-all'),
              onPressed: _selectAll,
              child: const Text('전체 선택'),
            ),
            OutlinedButton(
              key: const Key('col-deselect-all'),
              onPressed: _deselectAll,
              child: const Text('전체 해제'),
            ),
            ElevatedButton(
              key: const Key('col-apply'),
              onPressed: () => widget.controller.applyColumnFilter(_selected),
              child: const Text('적용'),
            ),
          ],
        ),
      ],
    );
  }
}
