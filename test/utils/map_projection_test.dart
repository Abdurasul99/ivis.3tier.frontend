// test/utils/map_projection_test.dart
// MapProjection (Web Mercator) 단위 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// Google Maps Web Mercator(EPSG:3857) 동기 투영 헬퍼의 핵심 동작을 검증한다:
//   - latLngToScreen: 카메라 타겟이 컨테이너 중심에 투영되는지 (식별성)
//   - screenToLatLng: 역변환이 원래 좌표를 복원하는지 (round-trip)
//   - bearing 회전 시 화면 위치가 올바르게 회전하는지
//   - 뷰포트 컬링 (isInViewport) 가 마진을 포함한 영역을 정확히 판정하는지

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ivis/utils/map_projection.dart';

void main() {
  // 공통 테스트 매개변수
  const LatLng daeguCity = LatLng(35.8714, 128.6014);
  const Size containerSize = Size(800.0, 600.0);

  // ─────────────────────────────────────────────
  // latLngToScreen — 마커 화면 좌표 계산
  // ─────────────────────────────────────────────
  group('latLngToScreen', () {
    test('카메라 타겟과 동일한 좌표는 컨테이너 중심에 배치', () {
      // Arrange
      const LatLng position = daeguCity;
      const LatLng cameraTarget = daeguCity;

      // Act
      final Offset screen = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 14.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );

      // Assert — 컨테이너 중심 (400, 300)
      expect(screen.dx, closeTo(400.0, 1e-6));
      expect(screen.dy, closeTo(300.0, 1e-6));
    });

    test('카메라 타겟 동쪽 좌표는 중심보다 오른쪽 (dx > 400)', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      // 약 동쪽 100m 정도 (경도 +0.001)
      const LatLng position = LatLng(35.8714, 128.6024);

      // Act
      final Offset screen = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 16.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );

      // Assert
      expect(screen.dx, greaterThan(400.0));
      // 위도가 동일하면 dy는 중심에 가까움
      expect(screen.dy, closeTo(300.0, 1.0));
    });

    test('카메라 타겟 북쪽 좌표는 중심보다 위쪽 (dy < 300)', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      const LatLng position = LatLng(35.8724, 128.6014); // 북쪽

      // Act
      final Offset screen = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 16.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );

      // Assert — 화면 y축은 아래로 +이므로 북쪽 = dy 더 작음
      expect(screen.dy, lessThan(300.0));
      expect(screen.dx, closeTo(400.0, 1.0));
    });

    test('zoom 증가 시 같은 위치의 화면 거리도 증가', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      const LatLng position = LatLng(35.8714, 128.6024);

      // Act
      final Offset screenLowZoom = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 12.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );
      final Offset screenHighZoom = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 18.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );

      // Assert — zoom 큰 쪽이 중심에서 더 먼 픽셀로 투영
      final double dxLow = (screenLowZoom.dx - 400.0).abs();
      final double dxHigh = (screenHighZoom.dx - 400.0).abs();
      expect(dxHigh, greaterThan(dxLow));
    });

    test('bearing=180일 때 좌우/상하가 반전 (벡터가 음수 곱)', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      const LatLng position = LatLng(35.8714, 128.6024);

      // Act — bearing 0 (정상)
      final Offset noBearing = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 14.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );
      // bearing 180 (180도 회전)
      final Offset reversed = MapProjection.latLngToScreen(
        position: position,
        cameraTarget: cameraTarget,
        cameraZoom: 14.0,
        cameraBearing: 180.0,
        containerSize: containerSize,
      );

      // Assert — 중심에서 동일한 거리, 반대 방향
      final double dxNo = noBearing.dx - 400.0;
      final double dxRev = reversed.dx - 400.0;
      expect(dxRev, closeTo(-dxNo, 1e-6));
    });
  });

  // ─────────────────────────────────────────────
  // screenToLatLng — 역변환 round-trip
  // ─────────────────────────────────────────────
  group('screenToLatLng (round-trip)', () {
    test('중심 픽셀 → cameraTarget 그대로 복원', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      const Offset centerPixel = Offset(400.0, 300.0);

      // Act
      final LatLng latLng = MapProjection.screenToLatLng(
        screenPos: centerPixel,
        cameraTarget: cameraTarget,
        cameraZoom: 14.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );

      // Assert
      expect(latLng.latitude, closeTo(cameraTarget.latitude, 1e-6));
      expect(latLng.longitude, closeTo(cameraTarget.longitude, 1e-6));
    });

    test('latLngToScreen → screenToLatLng round-trip 이 원래 좌표 복원', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      const LatLng original = LatLng(35.8800, 128.6100);

      // Act
      final Offset screen = MapProjection.latLngToScreen(
        position: original,
        cameraTarget: cameraTarget,
        cameraZoom: 14.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );
      final LatLng restored = MapProjection.screenToLatLng(
        screenPos: screen,
        cameraTarget: cameraTarget,
        cameraZoom: 14.0,
        cameraBearing: 0.0,
        containerSize: containerSize,
      );

      // Assert
      expect(restored.latitude, closeTo(original.latitude, 1e-6));
      expect(restored.longitude, closeTo(original.longitude, 1e-6));
    });

    test('bearing 회전 round-trip 도 보존', () {
      // Arrange
      const LatLng cameraTarget = daeguCity;
      const LatLng original = LatLng(35.8800, 128.6100);

      // Act
      final Offset screen = MapProjection.latLngToScreen(
        position: original,
        cameraTarget: cameraTarget,
        cameraZoom: 15.0,
        cameraBearing: 90.0,
        containerSize: containerSize,
      );
      final LatLng restored = MapProjection.screenToLatLng(
        screenPos: screen,
        cameraTarget: cameraTarget,
        cameraZoom: 15.0,
        cameraBearing: 90.0,
        containerSize: containerSize,
      );

      // Assert
      expect(restored.latitude, closeTo(original.latitude, 1e-6));
      expect(restored.longitude, closeTo(original.longitude, 1e-6));
    });
  });

  // ─────────────────────────────────────────────
  // isInViewport — 뷰포트 컬링
  // ─────────────────────────────────────────────
  group('isInViewport', () {
    test('컨테이너 안쪽 좌표는 true', () {
      // Arrange
      const Offset inside = Offset(400.0, 300.0);

      // Act & Assert
      expect(MapProjection.isInViewport(inside, containerSize), isTrue);
    });

    test('컨테이너 정확히 모서리는 true (margin 영역)', () {
      // Arrange
      const Offset corner = Offset(800.0, 600.0);

      // Act & Assert
      expect(MapProjection.isInViewport(corner, containerSize), isTrue);
    });

    test('마진(기본 80px) 이내는 true', () {
      // Arrange
      const Offset nearEdge = Offset(-30.0, 300.0);

      // Act & Assert
      expect(MapProjection.isInViewport(nearEdge, containerSize), isTrue);
    });

    test('마진 바깥 좌표는 false', () {
      // Arrange
      const Offset farOut = Offset(-200.0, 300.0);

      // Act & Assert
      expect(MapProjection.isInViewport(farOut, containerSize), isFalse);
    });

    test('사용자 지정 마진(0) 이면 컨테이너 바깥은 false', () {
      // Arrange
      const Offset justOutside = Offset(801.0, 300.0);

      // Act
      final bool result =
          MapProjection.isInViewport(justOutside, containerSize, margin: 0.0);

      // Assert
      expect(result, isFalse);
    });
  });
}
