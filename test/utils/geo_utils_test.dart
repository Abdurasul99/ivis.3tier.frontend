// test/utils/geo_utils_test.dart
// 좌표 변환 / 거리·방위 계산 유틸 단위 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// 주요 검증 대상:
//   - degreesToRadians / radiansToDegrees (각도 단위 변환)
//   - normalizeHeadingDegrees / shortestAngleDelta (방위각 정규화)
//   - convertWgs84ToUtmZone52N / convertUtmZone52NToWgs84 (실제 대구 좌표 round-trip)
//   - euclideanDistanceMeters / haversineMeters / bearingBetween
//   - 입력 검증 헬퍼 (isValidLatLng, isValidUtmCoordinate, etc.)
//   - lerpUtm (선형 보간)

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/utils/geo_utils.dart';

void main() {
  // ─────────────────────────────────────────────
  // 각도 단위 변환
  // ─────────────────────────────────────────────
  group('degreesToRadians / radiansToDegrees', () {
    test('0도는 0 라디안', () {
      // Arrange
      const double degrees = 0.0;

      // Act
      final double radians = degreesToRadians(degrees);

      // Assert
      expect(radians, 0.0);
    });

    test('180도는 pi 라디안', () {
      // Arrange
      const double degrees = 180.0;

      // Act
      final double radians = degreesToRadians(degrees);

      // Assert
      expect(radians, closeTo(pi, 1e-9));
    });

    test('역변환 — pi 라디안은 180도', () {
      // Arrange
      const double radians = pi;

      // Act
      final double degrees = radiansToDegrees(radians);

      // Assert
      expect(degrees, closeTo(180.0, 1e-9));
    });

    test('round-trip — 임의의 각도가 보존됨', () {
      // Arrange
      const double original = 137.456;

      // Act
      final double roundTripped =
          radiansToDegrees(degreesToRadians(original));

      // Assert
      expect(roundTripped, closeTo(original, 1e-9));
    });
  });

  // ─────────────────────────────────────────────
  // 방위각 정규화
  // ─────────────────────────────────────────────
  group('normalizeHeadingDegrees', () {
    test('0~360 범위 안의 값은 그대로 반환', () {
      // Arrange
      const double heading = 123.4;

      // Act
      final double normalized = normalizeHeadingDegrees(heading);

      // Assert
      expect(normalized, closeTo(123.4, 1e-9));
    });

    test('360을 넘으면 360을 빼서 정규화', () {
      // Arrange
      const double heading = 450.0;

      // Act
      final double normalized = normalizeHeadingDegrees(heading);

      // Assert
      expect(normalized, closeTo(90.0, 1e-9));
    });

    test('음수는 360을 더해서 정규화', () {
      // Arrange
      const double heading = -45.0;

      // Act
      final double normalized = normalizeHeadingDegrees(heading);

      // Assert
      expect(normalized, closeTo(315.0, 1e-9));
    });

    test('0도는 0 그대로 반환', () {
      // Arrange & Act
      final double normalized = normalizeHeadingDegrees(0.0);

      // Assert
      expect(normalized, 0.0);
    });
  });

  // ─────────────────────────────────────────────
  // 최단 각도 차이
  // ─────────────────────────────────────────────
  group('shortestAngleDelta', () {
    test('같은 각도면 0 반환', () {
      // Arrange & Act
      final double delta = shortestAngleDelta(45.0, 45.0);

      // Assert
      expect(delta, closeTo(0.0, 1e-9));
    });

    test('10도에서 350도로 — 최단 경로는 -20도', () {
      // Arrange
      const double from = 10.0;
      const double to = 350.0;

      // Act
      final double delta = shortestAngleDelta(from, to);

      // Assert
      expect(delta, closeTo(-20.0, 1e-9));
    });

    test('350도에서 10도로 — 최단 경로는 +20도', () {
      // Arrange & Act
      final double delta = shortestAngleDelta(350.0, 10.0);

      // Assert
      expect(delta, closeTo(20.0, 1e-9));
    });

    test('항상 -180 < delta <= 180 범위', () {
      // Arrange & Act
      final double delta = shortestAngleDelta(0.0, 270.0);

      // Assert
      expect(delta, closeTo(-90.0, 1e-9));
    });
  });

  // ─────────────────────────────────────────────
  // WGS84 ↔ UTM Zone 52N 변환 (실제 대구 좌표)
  // ─────────────────────────────────────────────
  group('convertWgs84ToUtmZone52N / convertUtmZone52NToWgs84', () {
    test('대구 시청 좌표(35.8714°, 128.6014°)가 UTM52N 범위 안에 있음', () {
      // Arrange — 대구 시청 위치
      const double latitudeDegrees = 35.8714;
      const double longitudeDegrees = 128.6014;

      // Act
      final Utm52NCoordinate utm = convertWgs84ToUtmZone52N(
        latitudeDegrees: latitudeDegrees,
        longitudeDegrees: longitudeDegrees,
      );

      // Assert — 한국 영역의 UTM52N 일반 범위
      expect(utm.eastingMeters, greaterThan(100000.0));
      expect(utm.eastingMeters, lessThan(900000.0));
      expect(utm.northingMeters, greaterThan(0.0));
      expect(utm.northingMeters, lessThan(10000000.0));
    });

    test('round-trip — WGS84 → UTM52N → WGS84 변환 시 원래 값 복원 (오차 1cm 이하)', () {
      // Arrange
      const double originalLat = 35.8714;
      const double originalLon = 128.6014;

      // Act
      final Utm52NCoordinate utm = convertWgs84ToUtmZone52N(
        latitudeDegrees: originalLat,
        longitudeDegrees: originalLon,
      );
      final Wgs84Coordinate restored = convertUtmZone52NToWgs84(
        eastingMeters: utm.eastingMeters,
        northingMeters: utm.northingMeters,
      );

      // Assert — 1e-6 도 ≈ 11cm 이하 정밀도
      expect(restored.latitudeDegrees, closeTo(originalLat, 1e-6));
      expect(restored.longitudeDegrees, closeTo(originalLon, 1e-6));
    });

    test('중앙경도(129°) 위에서 easting은 false easting(500000) 근접', () {
      // Arrange — UTM Zone 52N의 중앙경도는 129도
      const double latitudeDegrees = 36.0;
      const double longitudeDegrees = 129.0;

      // Act
      final Utm52NCoordinate utm = convertWgs84ToUtmZone52N(
        latitudeDegrees: latitudeDegrees,
        longitudeDegrees: longitudeDegrees,
      );

      // Assert
      expect(utm.eastingMeters, closeTo(500000.0, 1.0));
    });
  });

  // ─────────────────────────────────────────────
  // 거리 / 방위 계산
  // ─────────────────────────────────────────────
  group('euclideanDistanceMeters', () {
    test('같은 좌표는 거리 0', () {
      // Arrange & Act
      final double distance = euclideanDistanceMeters(
        x1Meters: 100.0,
        y1Meters: 200.0,
        x2Meters: 100.0,
        y2Meters: 200.0,
      );

      // Assert
      expect(distance, 0.0);
    });

    test('3-4-5 직각삼각형 — 거리 5', () {
      // Arrange & Act
      final double distance = euclideanDistanceMeters(
        x1Meters: 0.0,
        y1Meters: 0.0,
        x2Meters: 3.0,
        y2Meters: 4.0,
      );

      // Assert
      expect(distance, closeTo(5.0, 1e-9));
    });

    test('음수 좌표도 지원', () {
      // Arrange & Act
      final double distance = euclideanDistanceMeters(
        x1Meters: -3.0,
        y1Meters: -4.0,
        x2Meters: 0.0,
        y2Meters: 0.0,
      );

      // Assert
      expect(distance, closeTo(5.0, 1e-9));
    });
  });

  group('headingDegreesFromUtm', () {
    test('정북(북쪽) 이동 — 0도', () {
      // Arrange & Act
      final double heading = headingDegreesFromUtm(
        fromEastingMeters: 500000.0,
        fromNorthingMeters: 4000000.0,
        toEastingMeters: 500000.0,
        toNorthingMeters: 4000100.0,
      );

      // Assert
      expect(heading, closeTo(0.0, 1e-9));
    });

    test('정동(동쪽) 이동 — 90도', () {
      // Arrange & Act
      final double heading = headingDegreesFromUtm(
        fromEastingMeters: 500000.0,
        fromNorthingMeters: 4000000.0,
        toEastingMeters: 500100.0,
        toNorthingMeters: 4000000.0,
      );

      // Assert
      expect(heading, closeTo(90.0, 1e-9));
    });

    test('정남(남쪽) 이동 — 180도', () {
      // Arrange & Act
      final double heading = headingDegreesFromUtm(
        fromEastingMeters: 500000.0,
        fromNorthingMeters: 4000000.0,
        toEastingMeters: 500000.0,
        toNorthingMeters: 3999900.0,
      );

      // Assert
      expect(heading, closeTo(180.0, 1e-9));
    });
  });

  group('haversineMeters', () {
    test('같은 좌표는 0', () {
      // Arrange & Act
      final double distance =
          haversineMeters(35.8714, 128.6014, 35.8714, 128.6014);

      // Assert
      expect(distance, closeTo(0.0, 1e-3));
    });

    test('서울-부산 직선 거리는 약 325km (오차 5km 이하)', () {
      // Arrange — 서울 시청 ↔ 부산 시청
      const double seoulLat = 37.5665;
      const double seoulLon = 126.9780;
      const double busanLat = 35.1796;
      const double busanLon = 129.0756;

      // Act
      final double distanceMeters =
          haversineMeters(seoulLat, seoulLon, busanLat, busanLon);

      // Assert
      expect(distanceMeters, greaterThan(320000.0));
      expect(distanceMeters, lessThan(330000.0));
    });
  });

  group('bearingBetween', () {
    test('동일 좌표는 0도 (degenerate case)', () {
      // Arrange & Act
      final double bearing = bearingBetween(35.0, 128.0, 35.0, 128.0);

      // Assert — 0도 정규화
      expect(bearing, closeTo(0.0, 1e-9));
    });

    test('정북쪽 — 약 0도', () {
      // Arrange & Act
      final double bearing = bearingBetween(35.0, 128.0, 36.0, 128.0);

      // Assert
      expect(bearing, closeTo(0.0, 1e-6));
    });
  });

  // ─────────────────────────────────────────────
  // 입력 검증 헬퍼
  // ─────────────────────────────────────────────
  group('isValidLatLng', () {
    test('정상 좌표 → true', () {
      // Arrange & Act & Assert
      expect(isValidLatLng(35.8714, 128.6014), isTrue);
    });

    test('위도 91도(범위 초과) → false', () {
      // Arrange & Act & Assert
      expect(isValidLatLng(91.0, 128.0), isFalse);
    });

    test('경도 181도(범위 초과) → false', () {
      // Arrange & Act & Assert
      expect(isValidLatLng(35.0, 181.0), isFalse);
    });
  });

  group('isValidUtmCoordinate', () {
    test('정상 UTM 좌표 → true', () {
      // Arrange & Act & Assert
      expect(isValidUtmCoordinate(500000.0, 4000000.0), isTrue);
    });

    test('Easting 범위 미만 → false', () {
      // Arrange & Act & Assert
      expect(isValidUtmCoordinate(50000.0, 4000000.0), isFalse);
    });

    test('Northing 음수 → false', () {
      // Arrange & Act & Assert
      expect(isValidUtmCoordinate(500000.0, -1.0), isFalse);
    });
  });

  group('looksLikeWgsLonLat', () {
    test('WGS 범위(경도/위도)는 true', () {
      // Arrange & Act & Assert
      expect(looksLikeWgsLonLat(128.6, 35.8), isTrue);
    });

    test('UTM 범위(500000, 4000000)는 false', () {
      // Arrange & Act & Assert
      expect(looksLikeWgsLonLat(500000.0, 4000000.0), isFalse);
    });
  });

  group('validateStrictUtmPair', () {
    test('정상 UTM 페어 → true', () {
      // Arrange & Act & Assert
      expect(
        validateStrictUtmPair(easting: 500000.0, northing: 4000000.0),
        isTrue,
      );
    });

    test('WGS 좌표가 잘못 들어오면 false', () {
      // Arrange & Act & Assert
      expect(
        validateStrictUtmPair(easting: 128.6, northing: 35.8),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────
  // lerpUtm — UTM 선형 보간
  // ─────────────────────────────────────────────
  group('lerpUtm', () {
    test('t=0은 a 그대로 반환', () {
      // Arrange
      const Utm52NCoordinate a =
          Utm52NCoordinate(eastingMeters: 100.0, northingMeters: 200.0);
      const Utm52NCoordinate b =
          Utm52NCoordinate(eastingMeters: 200.0, northingMeters: 400.0);

      // Act
      final Utm52NCoordinate result = lerpUtm(a, b, 0.0);

      // Assert
      expect(result.eastingMeters, 100.0);
      expect(result.northingMeters, 200.0);
    });

    test('t=1은 b 그대로 반환', () {
      // Arrange
      const Utm52NCoordinate a =
          Utm52NCoordinate(eastingMeters: 100.0, northingMeters: 200.0);
      const Utm52NCoordinate b =
          Utm52NCoordinate(eastingMeters: 200.0, northingMeters: 400.0);

      // Act
      final Utm52NCoordinate result = lerpUtm(a, b, 1.0);

      // Assert
      expect(result.eastingMeters, 200.0);
      expect(result.northingMeters, 400.0);
    });

    test('t=0.5는 중점 반환', () {
      // Arrange
      const Utm52NCoordinate a =
          Utm52NCoordinate(eastingMeters: 100.0, northingMeters: 200.0);
      const Utm52NCoordinate b =
          Utm52NCoordinate(eastingMeters: 200.0, northingMeters: 400.0);

      // Act
      final Utm52NCoordinate result = lerpUtm(a, b, 0.5);

      // Assert
      expect(result.eastingMeters, closeTo(150.0, 1e-9));
      expect(result.northingMeters, closeTo(300.0, 1e-9));
    });
  });
}
