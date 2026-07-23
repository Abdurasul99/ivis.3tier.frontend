// ============================================================================
// MapProjection — Google Maps Web Mercator (EPSG:3857) 동기 투영 헬퍼
// Synchronous Web-Mercator projection matching Google Maps internal math.
//
// 사용 목적: google_maps_flutter_web 의 <img> 깜빡임 회피용 Flutter 오버레이가
// 매 프레임 LatLng → 화면 픽셀 변환 필요 (mapController.getScreenCoordinate 는 async).
//
// Purpose: synchronous LatLng → screen pixel projection for Flutter overlay
// that bypasses google_maps_flutter_web marker flicker.
//
// 가정 / Assumptions:
//   - Tilt = 0 (평면 view, GoogleMap.tiltGesturesEnabled = false 권장)
//   - DPR 보정 불필요 (Flutter compositor 가 처리)
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapProjection {
  static const double _tileSize = 256.0;
  static const double _maxLatitude = 85.05112878;

  /// zoom level 에서 전체 월드 픽셀 스케일
  static double _worldScale(double zoom) =>
      _tileSize * math.pow(2.0, zoom).toDouble();

  /// LatLng → World Pixel (zoom 적용된 절대 월드 좌표)
  static Offset _latLngToWorld(LatLng latLng, double zoom) {
    final scale = _worldScale(zoom);
    final lat = latLng.latitude.clamp(-_maxLatitude, _maxLatitude);
    final lng = latLng.longitude;

    final x = (lng + 180.0) / 360.0 * scale;

    final latRad = lat * math.pi / 180.0;
    final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    final y = (0.5 -
            math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
        scale;

    return Offset(x, y);
  }

  /// World Pixel → LatLng (역변환)
  static LatLng _worldToLatLng(Offset world, double zoom) {
    final scale = _worldScale(zoom);
    final lng = world.dx / scale * 360.0 - 180.0;
    final n = math.pi * (1.0 - 2.0 * world.dy / scale);
    final latRad = math.atan(_sinh(n));
    final lat = latRad * 180.0 / math.pi;
    return LatLng(lat, lng);
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;

  // ==========================================================================
  // Public API
  // ==========================================================================

  /// LatLng → 화면 픽셀 좌표 (컨테이너 좌상단 (0,0) 기준)
  ///
  /// CORRECTED bearing rotation (adversarial review 결과):
  /// Google bearing = 카메라 시계방향 각도. 화면 Y 축은 아래로 +.
  /// 표준 2D 회전: 화면 마커는 카메라와 반대 방향으로 회전.
  /// 공식: rx = dx*cosB - dy*sinB, ry = dx*sinB + dy*cosB
  static Offset latLngToScreen({
    required LatLng position,
    required LatLng cameraTarget,
    required double cameraZoom,
    required double cameraBearing,
    required Size containerSize,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final cameraWorld = _latLngToWorld(cameraTarget, cameraZoom);
    final markerWorld = _latLngToWorld(position, cameraZoom);

    var dx = markerWorld.dx - cameraWorld.dx;
    var dy = markerWorld.dy - cameraWorld.dy;

    // bearing 회전 — corrected sign (was wrong in original design)
    if (cameraBearing != 0.0) {
      final bearingRad = cameraBearing * math.pi / 180.0;
      final cosB = math.cos(bearingRad);
      final sinB = math.sin(bearingRad);
      final rx = dx * cosB - dy * sinB; // ← corrected
      final ry = dx * sinB + dy * cosB; // ← corrected
      dx = rx;
      dy = ry;
    }

    // ★ FIX: GoogleMap 의 카메라 타겟은 padding 과 무관하게 ALWAYS 기하학적 중심에
    // 표시됨 (web 에서 padding 은 UI 컨트롤 위치에만 영향). 따라서 optical center =
    // geometric center.
    // ★ FIX: GoogleMap on web puts the camera target at the GEOMETRIC center of the
    // container regardless of padding (padding only insets UI controls on web).
    // So optical center == geometric center.
    final centerX = containerSize.width / 2.0;
    final centerY = containerSize.height / 2.0;

    return Offset(centerX + dx, centerY + dy);
  }

  /// 화면 픽셀 좌표 → LatLng (역변환)
  static LatLng screenToLatLng({
    required Offset screenPos,
    required LatLng cameraTarget,
    required double cameraZoom,
    required double cameraBearing,
    required Size containerSize,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final centerX = containerSize.width / 2.0;
    final centerY = containerSize.height / 2.0;

    var dx = screenPos.dx - centerX;
    var dy = screenPos.dy - centerY;

    if (cameraBearing != 0.0) {
      final bearingRad = cameraBearing * math.pi / 180.0;
      final cosB = math.cos(bearingRad);
      final sinB = math.sin(bearingRad);
      // 역회전
      final ux = dx * cosB + dy * sinB;
      final uy = -dx * sinB + dy * cosB;
      dx = ux;
      dy = uy;
    }

    final cameraWorld = _latLngToWorld(cameraTarget, cameraZoom);
    return _worldToLatLng(
      Offset(cameraWorld.dx + dx, cameraWorld.dy + dy),
      cameraZoom,
    );
  }

  /// 뷰포트 컬링 — 화면 영역 밖이면 그리기 생략
  static bool isInViewport(Offset screenPos, Size containerSize,
      {double margin = 80.0}) {
    return screenPos.dx >= -margin &&
        screenPos.dx <= containerSize.width + margin &&
        screenPos.dy >= -margin &&
        screenPos.dy <= containerSize.height + margin;
  }
}
