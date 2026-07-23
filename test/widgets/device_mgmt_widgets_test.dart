// test/widgets/device_mgmt_widgets_test.dart
//
// DEVICE 관리 (Device Management) 화면 위젯 테스트.
// Triple-A 패턴 (Arrange / Act / Assert) — 한국어 주석.
//
// 실제 TabDeviceManagement / _DeviceForm 위젯은 Google Maps, GetX 컨트롤러,
// Kakao Postcode JS interop, DeviceRegistryRepository 등 다수의 의존성을
// 요구하므로 본 테스트는 핵심 동작을 격리한 Harness 위젯으로 추출하여 검증한다.
// (login_widget_test.dart 와 동일한 패턴)
//
// 검증 항목:
//   1.  차량 목록이 등록된 모든 차량을 렌더링
//   2.  + 등록 버튼이 등록 다이얼로그를 연다
//   3.  등록 다이얼로그: 빈 장치 이름 검증 → empty_name 이벤트
//   4.  등록 다이얼로그: 스테이션 / 직접 입력 모드 토글
//   5.  등록 다이얼로그: 검색 버튼 → geocoding 호출
//   6.  등록 다이얼로그: 유효한 위도 / 경도 입력
//   7.  등록 다이얼로그: 저장 → registerVehicle 호출
//   8.  등록 다이얼로그: 취소 → 다이얼로그 닫힘
//   9.  편집 버튼 → 사전 채워진 편집 다이얼로그
//   10. 편집 다이얼로그: 저장 → updateVehicle 호출
//   11. 삭제 버튼 → 확인 다이얼로그 표시
//   12. 확인 다이얼로그: 삭제 → deleteVehicle 호출
//   13. 확인 다이얼로그: 취소 → 다이얼로그 닫힘, 삭제 호출 안 됨
//   14. 새로고침 버튼 → reqLoadDevices 호출
//   15. 인프라 패널 동등 테스트 (목록 / 등록 / 편집 / 삭제 / 새로고침)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 모델 — 테스트용 간소화된 디바이스 레지스트리 행
// ─────────────────────────────────────────────────────────────────────────────
class DeviceRow {
  final int registryId;
  final String deviceType; // 'vehicle' | 'infra'
  final int deviceId;
  final String? name;
  final String? homeStation;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final String? memo;

  const DeviceRow({
    required this.registryId,
    required this.deviceType,
    required this.deviceId,
    this.name,
    this.homeStation,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.memo,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 테스트 전용 추상화 — DeviceRegistryRepository / VehicleRepository 대용
// ─────────────────────────────────────────────────────────────────────────────
abstract class IDeviceService {
  Future<List<DeviceRow>> reqLoadDevices(String deviceType);
  Future<bool> registerVehicle(DeviceRow row);
  Future<bool> updateVehicle(DeviceRow row);
  Future<bool> deleteVehicle(int deviceId);
  Future<bool> registerInfra(DeviceRow row);
  Future<bool> updateInfra(DeviceRow row);
  Future<bool> deleteInfra(int deviceId);
  Future<Map<String, double>?> geocode(String address);
}

// build_runner 없이도 동작하도록 수기 작성한 Mock 클래스
class MockDeviceService extends Mock implements IDeviceService {
  @override
  Future<List<DeviceRow>> reqLoadDevices(String? deviceType) =>
      super.noSuchMethod(
        Invocation.method(#reqLoadDevices, <Object?>[deviceType]),
        returnValue: Future<List<DeviceRow>>.value(<DeviceRow>[]),
        returnValueForMissingStub: Future<List<DeviceRow>>.value(<DeviceRow>[]),
      ) as Future<List<DeviceRow>>;

  @override
  Future<bool> registerVehicle(DeviceRow? row) => super.noSuchMethod(
        Invocation.method(#registerVehicle, <Object?>[row]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>;

  @override
  Future<bool> updateVehicle(DeviceRow? row) => super.noSuchMethod(
        Invocation.method(#updateVehicle, <Object?>[row]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>;

  @override
  Future<bool> deleteVehicle(int? deviceId) => super.noSuchMethod(
        Invocation.method(#deleteVehicle, <Object?>[deviceId]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>;

  @override
  Future<bool> registerInfra(DeviceRow? row) => super.noSuchMethod(
        Invocation.method(#registerInfra, <Object?>[row]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>;

  @override
  Future<bool> updateInfra(DeviceRow? row) => super.noSuchMethod(
        Invocation.method(#updateInfra, <Object?>[row]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>;

  @override
  Future<bool> deleteInfra(int? deviceId) => super.noSuchMethod(
        Invocation.method(#deleteInfra, <Object?>[deviceId]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>;

  @override
  Future<Map<String, double>?> geocode(String? address) => super.noSuchMethod(
        Invocation.method(#geocode, <Object?>[address]),
        returnValue: Future<Map<String, double>?>.value(null),
        returnValueForMissingStub: Future<Map<String, double>?>.value(null),
      ) as Future<Map<String, double>?>;
}

// ─────────────────────────────────────────────────────────────────────────────
// 테스트 본체
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  late MockDeviceService service;
  late List<String> dispatched;

  setUp(() {
    service = MockDeviceService();
    dispatched = <String>[];
  });

  // 디바이스 관리 위젯 빌드 헬퍼
  Future<void> pumpDeviceManagement(
    WidgetTester tester, {
    List<DeviceRow> vehicles = const <DeviceRow>[],
    List<DeviceRow> infras = const <DeviceRow>[],
  }) async {
    when(service.reqLoadDevices('vehicle'))
        .thenAnswer((_) async => vehicles);
    when(service.reqLoadDevices('infra'))
        .thenAnswer((_) async => infras);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceManagementHarness(
            service: service,
            onEvent: dispatched.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. 차량 목록 렌더링
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle List Section — 렌더링', () {
    testWidgets('등록된 모든 차량을 목록에 표시', (WidgetTester tester) async {
      // Arrange
      final List<DeviceRow> vehicles = <DeviceRow>[
        const DeviceRow(
            registryId: 1,
            deviceType: 'vehicle',
            deviceId: 1,
            name: '차량 1'),
        const DeviceRow(
            registryId: 2,
            deviceType: 'vehicle',
            deviceId: 2,
            name: '차량 2'),
        const DeviceRow(
            registryId: 3,
            deviceType: 'vehicle',
            deviceId: 3,
            name: '차량 3'),
      ];

      // Act
      await pumpDeviceManagement(tester, vehicles: vehicles);

      // Assert — 3개 차량 모두 표시
      expect(find.text('차량 1'), findsOneWidget);
      expect(find.text('차량 2'), findsOneWidget);
      expect(find.text('차량 3'), findsOneWidget);
      verify(service.reqLoadDevices('vehicle')).called(1);
    });

    testWidgets('차량 없을 때 빈 상태 메시지', (WidgetTester tester) async {
      // Arrange & Act
      await pumpDeviceManagement(tester);

      // Assert
      expect(find.text('등록된 차량 없음'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. + 등록 버튼 → 등록 다이얼로그
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 다이얼로그 열기', () {
    testWidgets('+ 등록 버튼 누르면 등록 다이얼로그 표시', (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);

      // Act
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('device-form-dialog')), findsOneWidget);
      expect(find.byKey(const Key('device-name-field')), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. 빈 장치 이름 검증
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 입력 검증', () {
    testWidgets('빈 장치 이름으로 저장 시도 → empty_name 이벤트, register 호출 안 됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_name'));
      verifyNever(service.registerVehicle(any));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. 위치 모드 토글 (스테이션 vs 직접 입력)
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 위치 모드 토글', () {
    testWidgets('기본은 스테이션 모드, 직접 입력 토글 시 좌표 필드 노출',
        (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();

      // Assert — 초기 상태: 스테이션 드롭다운 표시
      expect(find.byKey(const Key('station-dropdown')), findsOneWidget);
      expect(find.byKey(const Key('latitude-field')), findsNothing);

      // Act — 직접 입력 모드 전환
      await tester.tap(find.byKey(const Key('mode-direct-button')));
      await tester.pump();

      // Assert — 좌표 필드로 전환됨
      expect(find.byKey(const Key('latitude-field')), findsOneWidget);
      expect(find.byKey(const Key('longitude-field')), findsOneWidget);
      expect(find.byKey(const Key('station-dropdown')), findsNothing);
    });

    testWidgets('직접 입력 후 다시 스테이션 모드 복귀', (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode-direct-button')));
      await tester.pump();

      // Act — 스테이션 모드로 복귀
      await tester.tap(find.byKey(const Key('mode-station-button')));
      await tester.pump();

      // Assert
      expect(find.byKey(const Key('station-dropdown')), findsOneWidget);
      expect(find.byKey(const Key('latitude-field')), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. 검색 버튼 → geocoding 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 검색 / Geocoding', () {
    testWidgets('주소 입력 후 검색 → service.geocode 호출 및 좌표 채워짐',
        (WidgetTester tester) async {
      // Arrange
      when(service.geocode('대구역')).thenAnswer(
        (_) async => <String, double>{'lat': 35.875931, 'lng': 128.596053},
      );
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode-direct-button')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('address-field')), '대구역');

      // Act
      await tester.tap(find.byKey(const Key('search-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(service.geocode('대구역')).called(1);
      final TextField latField = tester.widget<TextField>(
          find.byKey(const Key('latitude-field')));
      expect(latField.controller?.text, '35.875931');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 6. 위도 / 경도 유효한 숫자 입력
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 좌표 입력', () {
    testWidgets('위도 / 경도 필드는 유효한 숫자 문자열 수용', (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode-direct-button')));
      await tester.pump();

      // Act
      await tester.enterText(
          find.byKey(const Key('latitude-field')), '35.123456');
      await tester.enterText(
          find.byKey(const Key('longitude-field')), '128.654321');
      await tester.pump();

      // Assert
      final TextField latField = tester.widget<TextField>(
          find.byKey(const Key('latitude-field')));
      final TextField lngField = tester.widget<TextField>(
          find.byKey(const Key('longitude-field')));
      expect(latField.controller?.text, '35.123456');
      expect(lngField.controller?.text, '128.654321');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 7. 저장 → registerVehicle 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 저장', () {
    testWidgets('유효한 입력으로 저장 → service.registerVehicle 호출 및 다이얼로그 닫힘',
        (WidgetTester tester) async {
      // Arrange
      when(service.registerVehicle(any)).thenAnswer((_) async => true);
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('device-name-field')), '신규 차량');

      // Act
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(service.registerVehicle(any)).called(1);
      expect(find.byKey(const Key('device-form-dialog')), findsNothing);
      expect(dispatched, contains('register_success'));
    });

    testWidgets('저장 진행 중 CircularProgressIndicator 표시',
        (WidgetTester tester) async {
      // Arrange — 비동기 응답 지연
      when(service.registerVehicle(any)).thenAnswer(
        (_) => Future<bool>.delayed(
            const Duration(milliseconds: 200), () => true),
      );
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('device-name-field')), '신규 차량');

      // Act
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      // Assert — 로딩 표시
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 정리
      await tester.pumpAndSettle();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 8. 취소 → 다이얼로그 닫힘
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Register — 취소', () {
    testWidgets('취소 누르면 다이얼로그 닫히고 register 호출 안 됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);
      await tester.tap(find.byKey(const Key('register-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('device-name-field')), '신규 차량');

      // Act
      await tester.tap(find.byKey(const Key('cancel-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('device-form-dialog')), findsNothing);
      verifyNever(service.registerVehicle(any));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 9. 편집 다이얼로그 — 사전 채워진 값
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Edit — 다이얼로그 사전 채우기', () {
    testWidgets('편집 버튼 누르면 기존 값들이 사전 채워진 다이얼로그 표시',
        (WidgetTester tester) async {
      // Arrange
      final List<DeviceRow> vehicles = <DeviceRow>[
        const DeviceRow(
          registryId: 1,
          deviceType: 'vehicle',
          deviceId: 1,
          name: '편집할 차량',
          locationAddress: '대구광역시 중구',
          locationLat: 35.86,
          locationLng: 128.59,
          memo: '테스트 메모',
        ),
      ];
      await pumpDeviceManagement(tester, vehicles: vehicles);

      // Act
      await tester.tap(find.byKey(const Key('edit-vehicle-1')));
      await tester.pumpAndSettle();

      // Assert — 다이얼로그 열림 & 사전 채워짐
      expect(find.byKey(const Key('device-form-dialog')), findsOneWidget);
      final TextField nameField = tester.widget<TextField>(
          find.byKey(const Key('device-name-field')));
      expect(nameField.controller?.text, '편집할 차량');

      // 직접 입력 모드로 전환 후 좌표 확인
      await tester.tap(find.byKey(const Key('mode-direct-button')));
      await tester.pump();
      final TextField latField = tester.widget<TextField>(
          find.byKey(const Key('latitude-field')));
      expect(latField.controller?.text, '35.86');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 10. 편집 저장 → updateVehicle 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Edit — 저장', () {
    testWidgets('편집 후 저장 → service.updateVehicle 호출', (WidgetTester tester) async {
      // Arrange
      when(service.updateVehicle(any)).thenAnswer((_) async => true);
      final List<DeviceRow> vehicles = <DeviceRow>[
        const DeviceRow(
            registryId: 1,
            deviceType: 'vehicle',
            deviceId: 1,
            name: '원본 이름'),
      ];
      await pumpDeviceManagement(tester, vehicles: vehicles);
      await tester.tap(find.byKey(const Key('edit-vehicle-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('device-name-field')), '수정된 이름');

      // Act
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(service.updateVehicle(any)).called(1);
      verifyNever(service.registerVehicle(any));
      expect(dispatched, contains('update_success'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 11. 삭제 버튼 → 확인 다이얼로그
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Delete — 확인 다이얼로그', () {
    testWidgets('삭제 버튼 누르면 확인 다이얼로그 표시', (WidgetTester tester) async {
      // Arrange
      final List<DeviceRow> vehicles = <DeviceRow>[
        const DeviceRow(
            registryId: 1,
            deviceType: 'vehicle',
            deviceId: 1,
            name: '삭제 대상'),
      ];
      await pumpDeviceManagement(tester, vehicles: vehicles);

      // Act
      await tester.tap(find.byKey(const Key('delete-vehicle-1')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('confirm-dialog')), findsOneWidget);
      expect(find.byKey(const Key('confirm-delete-button')), findsOneWidget);
      expect(find.byKey(const Key('confirm-cancel-button')), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 12. 확인 다이얼로그 삭제 → deleteVehicle 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Delete — 확인', () {
    testWidgets('확인 다이얼로그 삭제 → service.deleteVehicle 호출',
        (WidgetTester tester) async {
      // Arrange
      when(service.deleteVehicle(1)).thenAnswer((_) async => true);
      final List<DeviceRow> vehicles = <DeviceRow>[
        const DeviceRow(
            registryId: 1,
            deviceType: 'vehicle',
            deviceId: 1,
            name: '삭제 대상'),
      ];
      await pumpDeviceManagement(tester, vehicles: vehicles);
      await tester.tap(find.byKey(const Key('delete-vehicle-1')));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('confirm-delete-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(service.deleteVehicle(1)).called(1);
      expect(find.byKey(const Key('confirm-dialog')), findsNothing);
      expect(dispatched, contains('delete_success'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 13. 확인 다이얼로그 취소 → 삭제 호출 안 됨
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle Delete — 취소', () {
    testWidgets('확인 다이얼로그 취소 → 다이얼로그 닫힘, 삭제 호출 안 됨',
        (WidgetTester tester) async {
      // Arrange
      final List<DeviceRow> vehicles = <DeviceRow>[
        const DeviceRow(
            registryId: 1,
            deviceType: 'vehicle',
            deviceId: 1,
            name: '삭제 대상'),
      ];
      await pumpDeviceManagement(tester, vehicles: vehicles);
      await tester.tap(find.byKey(const Key('delete-vehicle-1')));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('confirm-cancel-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('confirm-dialog')), findsNothing);
      verifyNever(service.deleteVehicle(any));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 14. 새로고침 → reqLoadDevices 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('Vehicle List — 새로고침', () {
    testWidgets('새로고침 버튼 → reqLoadDevices 다시 호출', (WidgetTester tester) async {
      // Arrange
      await pumpDeviceManagement(tester);
      clearInteractions(service);
      when(service.reqLoadDevices(any)).thenAnswer((_) async => <DeviceRow>[]);

      // Act
      await tester.tap(find.byKey(const Key('refresh-button')));
      await tester.pumpAndSettle();

      // Assert — 차량 + 인프라 둘 다 다시 로드
      verify(service.reqLoadDevices('vehicle')).called(1);
      verify(service.reqLoadDevices('infra')).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 15. 인프라 동등 테스트
  // ───────────────────────────────────────────────────────────────────────────
  group('Infra Panel — 동등 동작', () {
    testWidgets('인프라 목록이 등록된 모든 인프라를 표시', (WidgetTester tester) async {
      // Arrange
      final List<DeviceRow> infras = <DeviceRow>[
        const DeviceRow(
            registryId: 10,
            deviceType: 'infra',
            deviceId: 1,
            name: 'IS-1'),
        const DeviceRow(
            registryId: 11,
            deviceType: 'infra',
            deviceId: 2,
            name: 'IS-2'),
      ];

      // Act
      await pumpDeviceManagement(tester, infras: infras);

      // Assert
      expect(find.text('IS-1'), findsOneWidget);
      expect(find.text('IS-2'), findsOneWidget);
    });

    testWidgets('인프라 + 등록 → 다이얼로그 표시 & 저장 → registerInfra 호출',
        (WidgetTester tester) async {
      // Arrange
      when(service.registerInfra(any)).thenAnswer((_) async => true);
      await pumpDeviceManagement(tester);

      // Act — 인프라 등록 다이얼로그
      await tester.tap(find.byKey(const Key('register-infra-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('device-form-dialog')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('device-name-field')), '신규 인프라');
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Assert — 인프라 등록 호출
      verify(service.registerInfra(any)).called(1);
      verifyNever(service.registerVehicle(any));
    });

    testWidgets('인프라 편집 저장 → updateInfra 호출', (WidgetTester tester) async {
      // Arrange
      when(service.updateInfra(any)).thenAnswer((_) async => true);
      final List<DeviceRow> infras = <DeviceRow>[
        const DeviceRow(
            registryId: 10,
            deviceType: 'infra',
            deviceId: 5,
            name: '인프라 원본'),
      ];
      await pumpDeviceManagement(tester, infras: infras);

      // Act
      await tester.tap(find.byKey(const Key('edit-infra-5')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('device-name-field')), '인프라 수정');
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(service.updateInfra(any)).called(1);
    });

    testWidgets('인프라 삭제 확인 → deleteInfra 호출', (WidgetTester tester) async {
      // Arrange
      when(service.deleteInfra(7)).thenAnswer((_) async => true);
      final List<DeviceRow> infras = <DeviceRow>[
        const DeviceRow(
            registryId: 12,
            deviceType: 'infra',
            deviceId: 7,
            name: '인프라 삭제'),
      ];
      await pumpDeviceManagement(tester, infras: infras);

      // Act
      await tester.tap(find.byKey(const Key('delete-infra-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(service.deleteInfra(7)).called(1);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceManagementHarness — 테스트 격리용 디바이스 관리 화면
// 실제 TabDeviceManagement 와 동일한 핵심 동작을 구현하지만,
// Google Maps / GetX / JS interop / nginx 의존성을 제거하고
// 서비스를 props 로 주입받는다.
// ─────────────────────────────────────────────────────────────────────────────
class DeviceManagementHarness extends StatefulWidget {
  final IDeviceService service;
  final void Function(String event) onEvent;

  const DeviceManagementHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  @override
  State<DeviceManagementHarness> createState() =>
      _DeviceManagementHarnessState();
}

class _DeviceManagementHarnessState extends State<DeviceManagementHarness> {
  List<DeviceRow> _vehicles = <DeviceRow>[];
  List<DeviceRow> _infras = <DeviceRow>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<DeviceRow> v =
        await widget.service.reqLoadDevices('vehicle');
    final List<DeviceRow> i = await widget.service.reqLoadDevices('infra');
    if (!mounted) return;
    setState(() {
      _vehicles = v;
      _infras = i;
    });
  }

  Future<void> _openForm({
    required String deviceType,
    DeviceRow? existing,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (_) => DeviceFormDialog(
        key: const Key('device-form-dialog'),
        deviceType: deviceType,
        existing: existing,
        service: widget.service,
        onEvent: widget.onEvent,
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _delete({
    required String deviceType,
    required int deviceId,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('confirm-dialog'),
        title: const Text('삭제 확인'),
        content: Text('$deviceType $deviceId 삭제하시겠습니까?'),
        actions: <Widget>[
          TextButton(
            key: const Key('confirm-cancel-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('confirm-delete-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final bool ok = deviceType == 'vehicle'
        ? await widget.service.deleteVehicle(deviceId)
        : await widget.service.deleteInfra(deviceId);
    if (ok) widget.onEvent('delete_success');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('DEVICE 관리'),
              const Spacer(),
              IconButton(
                key: const Key('refresh-button'),
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _buildPanel('vehicle', _vehicles)),
                const SizedBox(width: 16),
                Expanded(child: _buildPanel('infra', _infras)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(String deviceType, List<DeviceRow> rows) {
    final String label = deviceType == 'vehicle' ? '차량' : '인프라';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('$label 관리'),
            const Spacer(),
            ElevatedButton(
              key: Key('register-$deviceType-button'),
              onPressed: () => _openForm(deviceType: deviceType),
              child: const Text('+ 등록'),
            ),
          ],
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('등록된 $label 없음'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, int i) {
                final DeviceRow r = rows[i];
                return ListTile(
                  title: Text(r.name ?? '-'),
                  subtitle: Text('${r.deviceId}번'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        key: Key('edit-$deviceType-${r.deviceId}'),
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(
                            deviceType: deviceType, existing: r),
                      ),
                      IconButton(
                        key: Key('delete-$deviceType-${r.deviceId}'),
                        icon: const Icon(Icons.delete),
                        onPressed: () => _delete(
                            deviceType: deviceType, deviceId: r.deviceId),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceFormDialog — 등록 / 편집 폼 (다이얼로그)
// ─────────────────────────────────────────────────────────────────────────────
class DeviceFormDialog extends StatefulWidget {
  final String deviceType;
  final DeviceRow? existing;
  final IDeviceService service;
  final void Function(String event) onEvent;

  const DeviceFormDialog({
    super.key,
    required this.deviceType,
    required this.service,
    required this.onEvent,
    this.existing,
  });

  @override
  State<DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<DeviceFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _memo;

  // 모드: 'station' | 'direct'
  String _mode = 'station';
  String? _selectedStation;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final DeviceRow? e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _address = TextEditingController(text: e?.locationAddress ?? '');
    _lat = TextEditingController(
        text: e?.locationLat != null ? e!.locationLat.toString() : '');
    _lng = TextEditingController(
        text: e?.locationLng != null ? e!.locationLng.toString() : '');
    _memo = TextEditingController(text: e?.memo ?? '');
    _selectedStation = e?.homeStation;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final Map<String, double>? result =
        await widget.service.geocode(_address.text.trim());
    if (result == null || !mounted) return;
    setState(() {
      _lat.text = result['lat']!.toString();
      _lng.text = result['lng']!.toString();
    });
  }

  Future<void> _onSave() async {
    // 검증 — 빈 이름
    if (_name.text.trim().isEmpty) {
      widget.onEvent('empty_name');
      return;
    }

    setState(() => _saving = true);
    final DeviceRow row = DeviceRow(
      registryId: widget.existing?.registryId ?? 0,
      deviceType: widget.deviceType,
      deviceId: widget.existing?.deviceId ?? 0,
      name: _name.text.trim(),
      homeStation: _mode == 'station' ? _selectedStation : null,
      locationAddress: _address.text.trim().isEmpty ? null : _address.text.trim(),
      locationLat: double.tryParse(_lat.text.trim()),
      locationLng: double.tryParse(_lng.text.trim()),
      memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
    );

    final bool ok = _isEdit
        ? (widget.deviceType == 'vehicle'
            ? await widget.service.updateVehicle(row)
            : await widget.service.updateInfra(row))
        : (widget.deviceType == 'vehicle'
            ? await widget.service.registerVehicle(row)
            : await widget.service.registerInfra(row));

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      widget.onEvent(_isEdit ? 'update_success' : 'register_success');
      Navigator.of(context).pop(true);
    } else {
      widget.onEvent(_isEdit ? 'update_fail' : 'register_fail');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_isEdit ? '편집' : '등록'),
              const SizedBox(height: 12),

              // 장치 이름
              TextField(
                key: const Key('device-name-field'),
                controller: _name,
                decoration: const InputDecoration(labelText: '장치 이름'),
              ),
              const SizedBox(height: 12),

              // 위치 모드 토글
              Row(
                children: <Widget>[
                  ChoiceChip(
                    key: const Key('mode-station-button'),
                    label: const Text('스테이션'),
                    selected: _mode == 'station',
                    onSelected: (_) => setState(() => _mode = 'station'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('mode-direct-button'),
                    label: const Text('직접 입력'),
                    selected: _mode == 'direct',
                    onSelected: (_) => setState(() => _mode = 'direct'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 모드별 입력
              if (_mode == 'station')
                DropdownButton<String>(
                  key: const Key('station-dropdown'),
                  value: _selectedStation,
                  hint: const Text('스테이션 선택'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                        value: '대구역', child: Text('대구역')),
                    DropdownMenuItem<String>(
                        value: '동대구역', child: Text('동대구역')),
                    DropdownMenuItem<String>(
                        value: '수성구', child: Text('수성구')),
                    DropdownMenuItem<String>(
                        value: '범어역', child: Text('범어역')),
                    DropdownMenuItem<String>(
                        value: '칠성시장', child: Text('칠성시장')),
                  ],
                  onChanged: (String? v) =>
                      setState(() => _selectedStation = v),
                )
              else ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('address-field'),
                        controller: _address,
                        decoration:
                            const InputDecoration(labelText: '주소'),
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('search-button'),
                      onPressed: _onSearch,
                      child: const Text('검색'),
                    ),
                  ],
                ),
                TextField(
                  key: const Key('latitude-field'),
                  controller: _lat,
                  decoration: const InputDecoration(labelText: '위도'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  key: const Key('longitude-field'),
                  controller: _lng,
                  decoration: const InputDecoration(labelText: '경도'),
                  keyboardType: TextInputType.number,
                ),
              ],

              const SizedBox(height: 12),
              TextField(
                key: const Key('memo-field'),
                controller: _memo,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '메모'),
              ),
              const SizedBox(height: 12),

              if (_saving) const CircularProgressIndicator(),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    key: const Key('cancel-button'),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('save-button'),
                    onPressed: _saving ? null : _onSave,
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
