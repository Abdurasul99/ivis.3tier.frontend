// test/controller/dashboard_controller_test.dart
// DashboardController 단위 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
// 순수 연산 메서드·상태 전환 로직만 테스트 (HTTP 호출 없음)

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/object_model.dart';
import 'package:ivis/viewmodel/controller/dashboard_controller.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/object_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';

void main() {
  late DashboardController ctrl;

  setUp(() {
    Get.testMode = true;
    // DashboardController.onInit()이 의존하는 컨트롤러 먼저 등록
    Get.put(UserController());
    Get.put(VehicleController());
    Get.put(InfraController());
    Get.put(ObjectController());
    ctrl = Get.put(DashboardController());
  });

  tearDown(() {
    Get.deleteAll();
  });

  // ─────────────────────────────────────────────
  // totalPages — 페이지 수 계산
  // ─────────────────────────────────────────────
  group('totalPages', () {
    test('totalCount=0이면 1 반환', () {
      // Arrange
      ctrl.totalCount = 0;
      ctrl.rowsPerPage = 18;

      // Act
      final int pages = ctrl.totalPages;

      // Assert
      expect(pages, 1);
    });

    test('totalCount=18, rowsPerPage=18이면 1', () {
      // Arrange
      ctrl.totalCount = 18;
      ctrl.rowsPerPage = 18;

      // Act
      final int pages = ctrl.totalPages;

      // Assert
      expect(pages, 1);
    });

    test('totalCount=19, rowsPerPage=18이면 2', () {
      // Arrange
      ctrl.totalCount = 19;
      ctrl.rowsPerPage = 18;

      // Act
      final int pages = ctrl.totalPages;

      // Assert
      expect(pages, 2);
    });

    test('totalCount=100, rowsPerPage=18이면 ceil(100/18)=6', () {
      // Arrange
      ctrl.totalCount = 100;
      ctrl.rowsPerPage = 18;

      // Act
      final int pages = ctrl.totalPages;

      // Assert
      expect(pages, 6);
    });

    test('totalCount가 음수이면 1 반환 (방어 로직)', () {
      // Arrange
      ctrl.totalCount = -5;
      ctrl.rowsPerPage = 18;

      // Act
      final int pages = ctrl.totalPages;

      // Assert
      expect(pages, 1);
    });
  });

  // ─────────────────────────────────────────────
  // parseIntValue — 다양한 타입 int 변환
  // ─────────────────────────────────────────────
  group('parseIntValue', () {
    test('int 입력 그대로 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntValue(42), 42);
    });

    test('double 입력을 int로 변환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntValue(3.9), 3);
    });

    test('String 숫자를 int로 변환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntValue('100'), 100);
    });

    test('파싱 불가 String이면 0 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntValue('abc'), 0);
    });

    test('null이면 0 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntValue(null), 0);
    });
  });

  // ─────────────────────────────────────────────
  // parseIntOrFallback — fallback 지원 int 변환
  // ─────────────────────────────────────────────
  group('parseIntOrFallback', () {
    test('정상 int는 그대로 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntOrFallback(10, 99), 10);
    });

    test('null이면 fallback 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntOrFallback(null, 99), 99);
    });

    test('파싱 불가 String이면 fallback 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseIntOrFallback('xyz', 5), 5);
    });
  });

  // ─────────────────────────────────────────────
  // formatCellValue — 셀 값 문자열 변환
  // ─────────────────────────────────────────────
  group('formatCellValue', () {
    test('null이면 빈 문자열 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.formatCellValue(null), '');
    });

    test('int 입력 → 문자열 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.formatCellValue(123), '123');
    });

    test('double 입력 → 문자열 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.formatCellValue(3.14), '3.14');
    });

    test('String 입력 → 그대로 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.formatCellValue('hello'), 'hello');
    });
  });

  // ─────────────────────────────────────────────
  // objectTypeUi — 객체 타입 → UI 매핑
  // ─────────────────────────────────────────────
  group('objectTypeUi', () {
    test('타입 0 → "미확인"', () {
      // Arrange / Act
      final ObjectTypeUi ui = ctrl.objectTypeUi(0);
      // Assert
      expect(ui.label, '미확인');
    });

    test('타입 1 → "승용차"', () {
      expect(ctrl.objectTypeUi(1).label, '승용차');
    });

    test('타입 2 → "트럭"', () {
      expect(ctrl.objectTypeUi(2).label, '트럭');
    });

    test('타입 3 → "버스"', () {
      expect(ctrl.objectTypeUi(3).label, '버스');
    });

    test('타입 4 → "보행자"', () {
      expect(ctrl.objectTypeUi(4).label, '보행자');
    });

    test('타입 5 → "이륜차"', () {
      expect(ctrl.objectTypeUi(5).label, '이륜차');
    });

    test('알 수 없는 타입(-1) → "미확인"', () {
      expect(ctrl.objectTypeUi(-1).label, '미확인');
    });

    test('null → "미확인"', () {
      expect(ctrl.objectTypeUi(null).label, '미확인');
    });
  });

  // ─────────────────────────────────────────────
  // getObjectTypeNameKorean — 한국어 이름 반환
  // ─────────────────────────────────────────────
  group('getObjectTypeNameKorean', () {
    const List<Map<String, dynamic>> cases = [
      {'type': 0, 'name': '미확인'},
      {'type': 1, 'name': '승용차'},
      {'type': 2, 'name': '트럭'},
      {'type': 3, 'name': '버스'},
      {'type': 4, 'name': '보행자'},
      {'type': 5, 'name': '이륜차'},
    ];

    for (final Map<String, dynamic> c in cases) {
      test('타입 ${c['type']} → "${c['name']}"', () {
        // Arrange / Act
        final String name = ctrl.getObjectTypeNameKorean(c['type'] as int);
        // Assert
        expect(name, c['name']);
      });
    }

    test('정의되지 않은 타입(99) → "미확인"', () {
      // Arrange / Act / Assert
      expect(ctrl.getObjectTypeNameKorean(99), '미확인');
    });

    test('null → "미확인"', () {
      // Arrange / Act / Assert
      expect(ctrl.getObjectTypeNameKorean(null), '미확인');
    });
  });

  // ─────────────────────────────────────────────
  // buildVisiblePages — 페이지네이션 번호 목록
  // ─────────────────────────────────────────────
  group('buildVisiblePages', () {
    test('총 1 페이지이면 [1] 반환', () {
      // Arrange
      ctrl.totalCount = 10;
      ctrl.rowsPerPage = 18;
      ctrl.currentPage = 1;

      // Act
      final List<int> pages = ctrl.buildVisiblePages();

      // Assert
      expect(pages, [1]);
    });

    test('5 페이지 중 3 페이지에 있을 때 인접 페이지 포함', () {
      // Arrange
      ctrl.totalCount = 90;   // 90 / 18 = 5 페이지
      ctrl.rowsPerPage = 18;
      ctrl.currentPage = 3;

      // Act
      final List<int> pages = ctrl.buildVisiblePages();

      // Assert
      // 항상 포함: 1, 5(끝), currentPage=3, 2(currentPage-1), 4(currentPage+1)
      expect(pages, containsAll([1, 2, 3, 4, 5]));
      expect(pages, isA<List<int>>());
      expect(pages, equals(pages.toList()..sort())); // 정렬 검증
    });

    test('1 페이지에 있을 때 음수 페이지 제외', () {
      // Arrange
      ctrl.totalCount = 50;
      ctrl.rowsPerPage = 18;
      ctrl.currentPage = 1;

      // Act
      final List<int> pages = ctrl.buildVisiblePages();

      // Assert
      for (final int p in pages) {
        expect(p, greaterThanOrEqualTo(1));
      }
    });

    test('반환된 목록은 오름차순 정렬', () {
      // Arrange
      ctrl.totalCount = 200;
      ctrl.rowsPerPage = 18;
      ctrl.currentPage = 6;

      // Act
      final List<int> pages = ctrl.buildVisiblePages();

      // Assert
      final List<int> sorted = List<int>.from(pages)..sort();
      expect(pages, sorted);
    });
  });

  // ─────────────────────────────────────────────
  // enableMapView / disableMapView — 지도 뷰 토글
  // ─────────────────────────────────────────────
  group('mapView 토글', () {
    test('enableMapView 호출 후 isMapView=true', () {
      // Arrange
      expect(ctrl.isMapView, isFalse);

      // Act
      ctrl.enableMapView();

      // Assert
      expect(ctrl.isMapView, isTrue);
    });

    test('disableMapView 호출 후 isMapView=false', () {
      // Arrange
      ctrl.enableMapView();

      // Act
      ctrl.disableMapView();

      // Assert
      expect(ctrl.isMapView, isFalse);
    });

    test('이미 true일 때 enableMapView 재호출해도 true 유지', () {
      // Arrange
      ctrl.enableMapView();

      // Act
      ctrl.enableMapView(); // 중복 호출

      // Assert
      expect(ctrl.isMapView, isTrue);
    });
  });

  // ─────────────────────────────────────────────
  // activeSearchParams — 검색 파라미터 getter
  // ─────────────────────────────────────────────
  group('activeSearchParams', () {
    test('filterColumn과 filterValue 모두 있을 때 값 반환', () {
      // Arrange
      ctrl.activeFilterColumn = 'vehicle_id';
      ctrl.activeFilterValue = '42';

      // Act
      final Map<String, String?> params = ctrl.activeSearchParams;

      // Assert
      expect(params['text'], '42');
      expect(params['column'], 'vehicle_id');
    });

    test('filterValue가 null이면 text/column 모두 null', () {
      // Arrange
      ctrl.activeFilterColumn = null;
      ctrl.activeFilterValue = null;

      // Act
      final Map<String, String?> params = ctrl.activeSearchParams;

      // Assert
      expect(params['text'], isNull);
      expect(params['column'], isNull);
    });

    test('filterValue가 공백만 있으면 null 반환 (trim 처리)', () {
      // Arrange
      ctrl.activeFilterColumn = 'msg_id';
      ctrl.activeFilterValue = '   ';

      // Act
      final Map<String, String?> params = ctrl.activeSearchParams;

      // Assert
      expect(params['text'], isNull);
      expect(params['column'], isNull);
    });
  });

  // ─────────────────────────────────────────────
  // applyColumnFilter — 표시 필드 필터 적용
  // ─────────────────────────────────────────────
  group('applyColumnFilter', () {
    test('vehicle 타입에서 필드 필터 적용 시 visibleVehicleFields 변경', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.vehicle;
      final Set<String> newFields = {'vehicle_id', 'kph', 'mps'};

      // Act
      ctrl.applyColumnFilter(newFields);

      // Assert
      expect(ctrl.visibleVehicleFields, equals(newFields));
    });

    test('infra 타입에서 필드 필터 적용 시 visibleInfraFields 변경', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.infra;
      final Set<String> newFields = {'infra_id', 'msg_id'};

      // Act
      ctrl.applyColumnFilter(newFields);

      // Assert
      expect(ctrl.visibleInfraFields, equals(newFields));
    });
  });

  // ─────────────────────────────────────────────
  // parseDetectedObjectsFromRaw — raw 데이터 파싱
  // ─────────────────────────────────────────────
  group('parseDetectedObjectsFromRaw', () {
    test('List가 아닌 입력이면 빈 리스트 반환', () {
      // Arrange / Act
      final List<DetectedObject> result =
          ctrl.parseDetectedObjectsFromRaw('not_a_list');

      // Assert
      expect(result, isEmpty);
    });

    test('유효한 Map 리스트에서 DetectedObject 파싱', () {
      // Arrange
      final List<Map<String, dynamic>> raw = [
        {'detected_object_id': 1, 'object_type': 1},
        {'detected_object_id': 2, 'object_type': 2},
      ];

      // Act
      final List<DetectedObject> result =
          ctrl.parseDetectedObjectsFromRaw(raw);

      // Assert
      expect(result.length, 2);
      expect(result[0].detectedObjectId, 1);
      expect(result[1].objectType, 2);
    });

    test('빈 리스트 입력이면 빈 리스트 반환', () {
      // Arrange / Act / Assert
      expect(ctrl.parseDetectedObjectsFromRaw([]), isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // selectedVehicleIdForExport / selectedInfraIdForExport
  // ─────────────────────────────────────────────
  group('export 선택 ID', () {
    test('vehicle 타입, filter="ALL"이면 null', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.vehicle;
      ctrl.vehicleIdFilter = 'ALL';

      // Act / Assert
      expect(ctrl.selectedVehicleIdForExport, isNull);
    });

    test('vehicle 타입, filter="3"이면 3 반환', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.vehicle;
      ctrl.vehicleIdFilter = '3';

      // Act / Assert
      expect(ctrl.selectedVehicleIdForExport, 3);
    });

    test('infra 타입, filter="ALL"이면 null', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.infra;
      ctrl.infraIdFilter = 'ALL';

      // Act / Assert
      expect(ctrl.selectedInfraIdForExport, isNull);
    });

    test('infra 타입, filter="7"이면 7 반환', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.infra;
      ctrl.infraIdFilter = '7';

      // Act / Assert
      expect(ctrl.selectedInfraIdForExport, 7);
    });

    test('vehicle 타입에서 selectedInfraIdForExport는 null', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.vehicle;

      // Act / Assert
      expect(ctrl.selectedInfraIdForExport, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // currentVisibleFields / currentAllFields
  // ─────────────────────────────────────────────
  group('currentVisibleFields / currentAllFields', () {
    test('vehicle 타입에서 allVehicleFields 포함 여부', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.vehicle;

      // Act
      final List<String> fields = ctrl.currentAllFields;

      // Assert
      expect(fields, contains('vehicle_id'));
      expect(fields, contains('kph'));
      expect(fields, contains('heading_deg'));
    });

    test('infra 타입에서 allInfraFields 포함 여부', () {
      // Arrange
      ctrl.currentEntityType = FmsEntityType.infra;

      // Act
      final List<String> fields = ctrl.currentAllFields;

      // Assert
      expect(fields, contains('infra_id'));
      expect(fields, contains('msg_id'));
    });
  });
}
