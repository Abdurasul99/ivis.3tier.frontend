// test/controller/map_controller_test.dart
// 지도 카메라 / 마커 셀렉션 상태 관리 컨트롤러 단위 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// 실제 코드베이스에는 단일한 MapController 클래스가 없지만, 지도 화면이 관리해야 할
// 상태(중심 좌표 / 줌 / 베어링 / 선택된 마커 / 따라가기 모드)는 명확하므로 본 테스트는
// 해당 상태를 캡슐화한 MapViewController(GetxController) 를 정의하여 동작을 검증한다.
//
// GeoUtils 의 실제 함수를 사용하므로 좌표 변환 정확도도 함께 검증된다.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/utils/geo_utils.dart';

void main() {
  late MapViewController ctrl;

  setUp(() {
    Get.testMode = true;
    ctrl = Get.put(MapViewController());
  });

  tearDown(() {
    Get.deleteAll();
  });

  // ─────────────────────────────────────────────
  // 초기 상태
  // ─────────────────────────────────────────────
  group('초기 상태', () {
    test('기본값으로 생성', () {
      // Arrange — setUp 에서 등록됨
      // Act (별도 호출 없음)
      // Assert
      expect(ctrl.centerLatitude, 35.8714);
      expect(ctrl.centerLongitude, 128.6014);
      expect(ctrl.zoomLevel, 14.0);
      expect(ctrl.bearingDegrees, 0.0);
      expect(ctrl.followVehicleId, isNull);
      expect(ctrl.selectedVehicleId, isNull);
      expect(ctrl.selectedInfraId, isNull);
      expect(ctrl.isSatelliteMode, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // 카메라 이동
  // ─────────────────────────────────────────────
  group('moveCamera', () {
    test('새 중심과 줌을 설정', () {
      // Arrange
      const double newLat = 37.5665;
      const double newLng = 126.9780;
      const double newZoom = 18.0;

      // Act
      ctrl.moveCamera(latitude: newLat, longitude: newLng, zoom: newZoom);

      // Assert
      expect(ctrl.centerLatitude, newLat);
      expect(ctrl.centerLongitude, newLng);
      expect(ctrl.zoomLevel, newZoom);
    });

    test('zoom 만 변경하면 중심은 유지', () {
      // Arrange
      final double originalLat = ctrl.centerLatitude;
      final double originalLng = ctrl.centerLongitude;

      // Act
      ctrl.moveCamera(zoom: 17.0);

      // Assert
      expect(ctrl.centerLatitude, originalLat);
      expect(ctrl.centerLongitude, originalLng);
      expect(ctrl.zoomLevel, 17.0);
    });

    test('유효하지 않은 좌표(위도 95) 거부', () {
      // Arrange
      final double originalLat = ctrl.centerLatitude;

      // Act
      ctrl.moveCamera(latitude: 95.0, longitude: 128.0);

      // Assert — 변경되지 않음
      expect(ctrl.centerLatitude, originalLat);
    });
  });

  // ─────────────────────────────────────────────
  // 줌 인 / 줌 아웃
  // ─────────────────────────────────────────────
  group('zoomIn / zoomOut', () {
    test('zoomIn 으로 줌 레벨 +1', () {
      // Arrange
      ctrl.moveCamera(zoom: 14.0);

      // Act
      ctrl.zoomIn();

      // Assert
      expect(ctrl.zoomLevel, 15.0);
    });

    test('zoomOut 으로 줌 레벨 -1', () {
      // Arrange
      ctrl.moveCamera(zoom: 14.0);

      // Act
      ctrl.zoomOut();

      // Assert
      expect(ctrl.zoomLevel, 13.0);
    });

    test('zoomIn 은 최대 줌(21) 을 넘지 않음', () {
      // Arrange
      ctrl.moveCamera(zoom: 21.0);

      // Act
      ctrl.zoomIn();

      // Assert
      expect(ctrl.zoomLevel, 21.0);
    });

    test('zoomOut 은 최소 줌(0) 보다 작아지지 않음', () {
      // Arrange
      ctrl.moveCamera(zoom: 0.0);

      // Act
      ctrl.zoomOut();

      // Assert
      expect(ctrl.zoomLevel, 0.0);
    });
  });

  // ─────────────────────────────────────────────
  // 차량 선택 / 인프라 선택
  // ─────────────────────────────────────────────
  group('selection', () {
    test('selectVehicle 시 selectedVehicleId 갱신', () {
      // Arrange & Act
      ctrl.selectVehicle(7);

      // Assert
      expect(ctrl.selectedVehicleId, 7);
    });

    test('selectVehicle 시 인프라 선택은 자동 해제 (배타적 선택)', () {
      // Arrange
      ctrl.selectInfra(3);

      // Act
      ctrl.selectVehicle(7);

      // Assert
      expect(ctrl.selectedVehicleId, 7);
      expect(ctrl.selectedInfraId, isNull);
    });

    test('selectInfra 시 차량 선택은 자동 해제', () {
      // Arrange
      ctrl.selectVehicle(7);

      // Act
      ctrl.selectInfra(3);

      // Assert
      expect(ctrl.selectedInfraId, 3);
      expect(ctrl.selectedVehicleId, isNull);
    });

    test('clearSelection 으로 모든 선택 해제', () {
      // Arrange
      ctrl.selectVehicle(1);
      ctrl.selectInfra(2);

      // Act
      ctrl.clearSelection();

      // Assert
      expect(ctrl.selectedVehicleId, isNull);
      expect(ctrl.selectedInfraId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 차량 따라가기 모드
  // ─────────────────────────────────────────────
  group('followVehicle', () {
    test('followVehicle(id) 호출 시 followVehicleId 설정', () {
      // Arrange & Act
      ctrl.followVehicle(42);

      // Assert
      expect(ctrl.followVehicleId, 42);
    });

    test('stopFollowing 으로 따라가기 모드 해제', () {
      // Arrange
      ctrl.followVehicle(42);

      // Act
      ctrl.stopFollowing();

      // Assert
      expect(ctrl.followVehicleId, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 지도 모드
  // ─────────────────────────────────────────────
  group('toggleSatelliteMode', () {
    test('초기값 false 에서 toggle 시 true', () {
      // Arrange & Act
      ctrl.toggleSatelliteMode();

      // Assert
      expect(ctrl.isSatelliteMode, isTrue);
    });

    test('두 번 toggle 시 다시 false', () {
      // Arrange & Act
      ctrl.toggleSatelliteMode();
      ctrl.toggleSatelliteMode();

      // Assert
      expect(ctrl.isSatelliteMode, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // GeoUtils 통합 — UTM 변환 정확도 (실제 함수)
  // ─────────────────────────────────────────────
  group('UTM 좌표 변환 (실제 GeoUtils)', () {
    test('moveCameraToUtm 으로 UTM 좌표 입력 시 WGS84 로 변환되어 저장', () {
      // Arrange — 대구 시청 근처의 UTM52N 좌표 계산
      final Utm52NCoordinate daeguUtm = convertWgs84ToUtmZone52N(
        latitudeDegrees: 35.8714,
        longitudeDegrees: 128.6014,
      );

      // Act
      ctrl.moveCameraToUtm(
        eastingMeters: daeguUtm.eastingMeters,
        northingMeters: daeguUtm.northingMeters,
      );

      // Assert — round-trip 정밀도
      expect(ctrl.centerLatitude, closeTo(35.8714, 1e-5));
      expect(ctrl.centerLongitude, closeTo(128.6014, 1e-5));
    });

    test('잘못된 UTM 좌표(범위 초과) 거부', () {
      // Arrange
      final double originalLat = ctrl.centerLatitude;

      // Act
      ctrl.moveCameraToUtm(eastingMeters: 5.0, northingMeters: 3.0);

      // Assert
      expect(ctrl.centerLatitude, originalLat);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MapViewController — 지도 화면 상태 관리 (테스트 격리용)
// 실제 코드베이스의 simulator_map_view 와 home_page 가 분산해서 관리하는 상태를
// 응집된 GetxController 로 묶었다.
// ─────────────────────────────────────────────────────────────────────────────
class MapViewController extends GetxController {
  double centerLatitude = 35.8714;
  double centerLongitude = 128.6014;
  double zoomLevel = 14.0;
  double bearingDegrees = 0.0;
  bool isSatelliteMode = false;

  int? selectedVehicleId;
  int? selectedInfraId;
  int? followVehicleId;

  static const double _minZoom = 0.0;
  static const double _maxZoom = 21.0;

  void moveCamera({double? latitude, double? longitude, double? zoom}) {
    if (latitude != null && longitude != null) {
      if (!isValidLatLng(latitude, longitude)) return;
      centerLatitude = latitude;
      centerLongitude = longitude;
    } else if (latitude != null) {
      if (!isValidLatLng(latitude, centerLongitude)) return;
      centerLatitude = latitude;
    } else if (longitude != null) {
      if (!isValidLatLng(centerLatitude, longitude)) return;
      centerLongitude = longitude;
    }

    if (zoom != null) {
      zoomLevel = zoom.clamp(_minZoom, _maxZoom);
    }
    update();
  }

  void moveCameraToUtm({
    required double eastingMeters,
    required double northingMeters,
  }) {
    if (!validateStrictUtmPair(
        easting: eastingMeters, northing: northingMeters)) {
      return;
    }
    final Wgs84Coordinate wgs = convertUtmZone52NToWgs84(
      eastingMeters: eastingMeters,
      northingMeters: northingMeters,
    );
    moveCamera(
      latitude: wgs.latitudeDegrees,
      longitude: wgs.longitudeDegrees,
    );
  }

  void zoomIn() {
    zoomLevel = (zoomLevel + 1.0).clamp(_minZoom, _maxZoom);
    update();
  }

  void zoomOut() {
    zoomLevel = (zoomLevel - 1.0).clamp(_minZoom, _maxZoom);
    update();
  }

  void selectVehicle(int vehicleId) {
    selectedVehicleId = vehicleId;
    selectedInfraId = null;
    update();
  }

  void selectInfra(int infraId) {
    selectedInfraId = infraId;
    selectedVehicleId = null;
    update();
  }

  void clearSelection() {
    selectedVehicleId = null;
    selectedInfraId = null;
    update();
  }

  void followVehicle(int vehicleId) {
    followVehicleId = vehicleId;
    update();
  }

  void stopFollowing() {
    followVehicleId = null;
    update();
  }

  void toggleSatelliteMode() {
    isSatelliteMode = !isSatelliteMode;
    update();
  }
}
