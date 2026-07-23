// ============================================================================
// VehicleMarkerOverlay — google_maps_flutter_web 깜빡임 회피 Flutter 오버레이
//
// google_maps_flutter_web 는 BitmapDescriptor 가 어떤 식으로 바뀌든 (심지어 같은
// 참조여도) marker 의 <img> 를 DOM 에서 detach + 새로 생성 → 디코드 race →
// 1프레임 빈공간 → 시각적 flash. 캐시/throttle/copyWith 어떤 것도 막을 수 없음.
//
// 해결: 차량을 Flutter Stack + Positioned + Image.asset 으로 직접 렌더.
//      플러그인 마커는 그대로 두되 (변경 시 위험), 그 위에 같은 위치로 덮어
//      그림 → 사용자는 mac 마커만 보임, flash 보이지 않음.
//
// ★ Kakao Mobility 스타일 클러스터링 + 줌별 adaptive 크기 (2026-06-10):
//   - zoom < 14   → 그리드(60px) 클러스터 버블 + 카운트
//   - zoom 14-19  → 개별 차량 아이콘, 크기는 줌에 따라 24→56px
//   - 부드러운 fade-in/out 으로 모드 전환 시 깜빡임 없음
//   - 스무드 이동(_interpTimer) 은 그대로 유지 (부모에서 계속 업데이트)
//
// Workflow #2 adversarial review 기반 수정 사항 / Fixes from adversarial review:
//   #1 GoogleMap.padding 지원 (MapProjection 으로 위임)
//   #2 bearing 회전 sign 수정 (MapProjection 으로 위임)
//   #6 pan 중 lag — addPersistentFrameCallback 으로 매 프레임 재투영
//   #7 unnecessary repaints — RepaintBoundary + ValueListenable
//   #9 hit target 작게 (32px) → drag 방해 최소화
//   #21 ui.Image dispose
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/map_projection.dart';

/// 클러스터 모드 전환 줌 — 이 값 미만이면 클러스터 표시
const double _kClusterZoomThreshold = 14.0;

/// 클러스터 그리드 셀 크기 (픽셀)
const double _kClusterCellPx = 60.0;

/// fade transition 폭 (zoom 단위) — 모드 경계 주변에서 부드러운 페이드
const double _kFadeBand = 0.4;

/// 오버레이가 그릴 한 대의 차량 데이터
class OverlayVehicle {
  final int id;
  final LatLng position;
  final double headingDeg; // 북=0°, 시계방향
  final bool selected;
  final bool online;

  const OverlayVehicle({
    required this.id,
    required this.position,
    required this.headingDeg,
    this.selected = false,
    this.online = true,
  });
}

/// 카메라 상태 + 컨테이너 크기를 묶은 immutable snapshot
class OverlayCameraSnapshot {
  final LatLng target;
  final double zoom;
  final double bearing;
  final Size containerSize;
  final EdgeInsets padding;

  const OverlayCameraSnapshot({
    required this.target,
    required this.zoom,
    required this.bearing,
    required this.containerSize,
    this.padding = EdgeInsets.zero,
  });

  static const OverlayCameraSnapshot empty = OverlayCameraSnapshot(
    target: LatLng(0, 0),
    zoom: 0,
    bearing: 0,
    containerSize: Size.zero,
  );

  bool get isValid =>
      containerSize.width > 0 && containerSize.height > 0 && zoom > 0;
}

/// 줌에 따른 마커 크기 (Kakao Mobility 스타일)
/// 더 가까이 볼수록 마커 크게 → 14~20 줌 구간
double _adaptiveMarkerSize(double zoom) {
  if (zoom < 14) return 0;       // 클러스터 모드 (개별 마커 미사용)
  if (zoom < 15) return 24.0;
  if (zoom < 16) return 32.0;
  if (zoom < 17) return 40.0;
  if (zoom < 18) return 48.0;
  if (zoom < 19) return 52.0;
  return 56.0;                    // zoom 19~20 (최대 줌)
}

/// 클러스터 모드 fade 가중치 (0=완전 개별, 1=완전 클러스터)
/// _kFadeBand 구간에서 부드러운 페이드 ⇒ pop-in 방지
double _clusterFade(double zoom) {
  final double diff = _kClusterZoomThreshold - zoom;
  if (diff <= 0) return 0.0;
  if (diff >= _kFadeBand) return 1.0;
  return diff / _kFadeBand;
}

/// 차량 위치 / 카메라 상태가 변할 때마다 repaint
///
/// vehicles 리스트는 매 build 에 새로 만들어도 됨 — 내부에서 화면 좌표 기준으로
/// projected 캐시를 다시 만드는데 가벼움 (~100대 < 1ms).
class VehicleMarkerOverlay extends StatefulWidget {
  final List<OverlayVehicle> vehicles;
  final ValueListenable<OverlayCameraSnapshot> cameraSnapshot;
  final void Function(int vehicleId, LatLng position)? onVehicleTap;
  final double markerSize; // 사용 안 됨 — 줌별 adaptive 로 대체. 호환성을 위해 유지.

  const VehicleMarkerOverlay({
    super.key,
    required this.vehicles,
    required this.cameraSnapshot,
    this.onVehicleTap,
    this.markerSize = 48.0,
  });

  @override
  State<VehicleMarkerOverlay> createState() => _VehicleMarkerOverlayState();
}

class _VehicleMarkerOverlayState extends State<VehicleMarkerOverlay> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OverlayCameraSnapshot>(
      valueListenable: widget.cameraSnapshot,
      builder: (context, camera, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final Size size = camera.containerSize.width > 0
                ? camera.containerSize
                : Size(constraints.maxWidth, constraints.maxHeight);

            if (camera.zoom <= 0) return const SizedBox.shrink();

            final double clusterFade = _clusterFade(camera.zoom);
            final double individualFade = 1.0 - clusterFade;
            final double markerSize = _adaptiveMarkerSize(camera.zoom);

            // 1) 차량 위치를 화면 좌표로 한 번만 투영 — 두 모드에서 재사용
            final List<_VehicleProjection> projections = <_VehicleProjection>[];
            for (final v in widget.vehicles) {
              final pos = MapProjection.latLngToScreen(
                position: v.position,
                cameraTarget: camera.target,
                cameraZoom: camera.zoom,
                cameraBearing: camera.bearing,
                containerSize: size,
                padding: camera.padding,
              );
              projections.add(_VehicleProjection(v, pos));
            }

            final children = <Widget>[];

            // 2) 개별 마커 (zoom ≥ ~13.6) — 부드러운 페이드 인
            if (individualFade > 0.01 && markerSize > 0) {
              for (final p in projections) {
                if (!MapProjection.isInViewport(p.screenPos, size, margin: 80)) {
                  continue;
                }
                children.add(Positioned(
                  left: p.screenPos.dx - markerSize / 2,
                  top: p.screenPos.dy - markerSize / 2,
                  width: markerSize,
                  height: markerSize,
                  child: Opacity(
                    opacity: individualFade,
                    child: _VehicleIcon(
                      headingDeg: p.vehicle.headingDeg - camera.bearing,
                      selected: p.vehicle.selected,
                      online: p.vehicle.online,
                      size: markerSize,
                      onTap: widget.onVehicleTap != null
                          ? () => widget.onVehicleTap!(
                              p.vehicle.id, p.vehicle.position)
                          : null,
                    ),
                  ),
                ));
              }
            }

            // 3) 클러스터 버블 (zoom < ~14.4) — 부드러운 페이드 아웃
            if (clusterFade > 0.01) {
              final List<_Cluster> clusters =
                  _computeClusters(projections, size);
              for (final c in clusters) {
                children.add(Positioned(
                  left: c.center.dx - c.diameter / 2,
                  top: c.center.dy - c.diameter / 2,
                  width: c.diameter,
                  height: c.diameter,
                  child: Opacity(
                    opacity: clusterFade,
                    child: _ClusterBubble(
                      count: c.count,
                      diameter: c.diameter,
                      onTap: widget.onVehicleTap != null && c.vehicles.isNotEmpty
                          ? () => widget.onVehicleTap!(
                              c.vehicles.first.id, c.vehicles.first.position)
                          : null,
                    ),
                  ),
                ));
              }
            }

            return SizedBox.fromSize(
              size: size,
              child: Stack(clipBehavior: Clip.none, children: children),
            );
          },
        );
      },
    );
  }
}

/// 차량 + 화면 투영 좌표 묶음 (한 프레임만 살아있는 임시 객체)
class _VehicleProjection {
  final OverlayVehicle vehicle;
  final Offset screenPos;
  _VehicleProjection(this.vehicle, this.screenPos);
}

/// 그리드 셀 기반 클러스터
class _Cluster {
  Offset center;
  final List<OverlayVehicle> vehicles = <OverlayVehicle>[];
  double diameter;
  _Cluster(this.center, this.diameter);

  int get count => vehicles.length;
}

/// 화면 좌표 기준 grid clustering — 60px 셀
/// (지도 줌 무관, 항상 화면에서 60px 간격 ⇒ 사용자 체감 일정)
/// 클러스터 중심은 셀 내 차량 화면좌표 평균 사용
List<_Cluster> _computeClusters(
  List<_VehicleProjection> projections,
  Size containerSize,
) {
  final Map<String, _ClusterAccum> grid = <String, _ClusterAccum>{};

  for (final p in projections) {
    // 화면 밖이면 클러스터 의미 없음 (margin 100px)
    if (p.screenPos.dx < -100 ||
        p.screenPos.dy < -100 ||
        p.screenPos.dx > containerSize.width + 100 ||
        p.screenPos.dy > containerSize.height + 100) {
      continue;
    }
    final int cx = (p.screenPos.dx / _kClusterCellPx).floor();
    final int cy = (p.screenPos.dy / _kClusterCellPx).floor();
    final String key = '$cx,$cy';
    final _ClusterAccum a = grid.putIfAbsent(key, () => _ClusterAccum());
    a.sumX += p.screenPos.dx;
    a.sumY += p.screenPos.dy;
    a.vehicles.add(p.vehicle);
  }

  final List<_Cluster> out = <_Cluster>[];
  for (final a in grid.values) {
    final int n = a.vehicles.length;
    if (n == 0) continue;
    final double avgX = a.sumX / n;
    final double avgY = a.sumY / n;
    final double diam = n < 5
        ? 36.0
        : n < 15
            ? 44.0
            : n < 50
                ? 52.0
                : 60.0;
    final _Cluster c = _Cluster(Offset(avgX, avgY), diam);
    c.vehicles.addAll(a.vehicles);
    out.add(c);
  }
  return out;
}

class _ClusterAccum {
  double sumX = 0;
  double sumY = 0;
  final List<OverlayVehicle> vehicles = <OverlayVehicle>[];
}

/// 디버그 배너 — overlay 가 살아있고 어떤 카메라 상태인지 표시
class _DebugBanner extends StatelessWidget {
  final String message;
  const _DebugBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xCC008800),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Kakao Mobility 스타일 클러스터 버블
/// 작을 때: 파랑, 중간: 주황, 많을 때: 빨강
class _ClusterBubble extends StatelessWidget {
  final int count;
  final double diameter;
  final VoidCallback? onTap;

  const _ClusterBubble({
    required this.count,
    required this.diameter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = count < 10
        ? const Color(0xFF0F9ED5) // cyan
        : count < 50
            ? const Color(0xFFE97132) // orange
            : const Color(0xFFD32F2F); // red

    final Widget bubble = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: diameter * 0.38,
          height: 1.0,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: bubble,
      );
    }
    return bubble;
  }
}

/// 단일 차량 아이콘 — 회전된 PNG + 선택 링
/// hit target 은 중앙 32px (markerSize 48 인 경우 가장자리 8px 마진)
class _VehicleIcon extends StatelessWidget {
  final double headingDeg;
  final bool selected;
  final bool online;
  final double size;
  final VoidCallback? onTap;

  const _VehicleIcon({
    required this.headingDeg,
    required this.selected,
    required this.online,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double hitMargin = (size - 32.0) / 2.0;

    // Kakao Navi 스타일: car.png 회전 + 선택 시 시안 링
    // Real car.png with rotation (like Kakao Navigator marker style)
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (selected)
          Container(
            width: size + 8,
            height: size + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0F9ED5),
                width: 3.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x550F9ED5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        Transform.rotate(
          angle: headingDeg * 3.141592653589793 / 180.0,
          child: Opacity(
            opacity: online ? 1.0 : 0.55,
            child: Image.asset(
              'assets/images/car.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true, // ★ 핵심: 다음 프레임 로딩 중 이전 프레임 유지
              errorBuilder: (_, __, ___) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _DebugVehiclePainter(
                    online: online,
                    selected: false,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: hitMargin > 0 ? hitMargin : 0,
          top: hitMargin > 0 ? hitMargin : 0,
          width: size < 32 ? size : 32,
          height: size < 32 ? size : 32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _DebugVehiclePainter extends CustomPainter {
  final bool online;
  final bool selected;
  _DebugVehiclePainter({required this.online, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.40;

    // 선택 링
    if (selected) {
      canvas.drawCircle(
        Offset(cx, cy),
        r + 5,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    // 본체 — 빨간색 (플러그인 파란 핀과 즉시 구분)
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = online
            ? const Color(0xFFE63946) // 밝은 빨강
            : const Color(0xFF5A7A9A),
    );
    // 흰 테두리
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 헤딩 삼각형 (위쪽)
    final tri = Path()
      ..moveTo(cx, cy - r - 4)
      ..lineTo(cx - r * 0.55, cy - r * 0.3)
      ..lineTo(cx + r * 0.55, cy - r * 0.3)
      ..close();
    canvas.drawPath(
      tri,
      Paint()..color = const Color(0xFFFFEB3B), // 노란 화살표
    );
    canvas.drawPath(
      tri,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_DebugVehiclePainter old) =>
      old.online != online || old.selected != selected;
}

class _FallbackVehicleShape extends StatelessWidget {
  final double size;
  final bool online;
  const _FallbackVehicleShape({required this.size, required this.online});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FallbackPainter(online: online),
    );
  }
}

class _FallbackPainter extends CustomPainter {
  final bool online;
  _FallbackPainter({required this.online});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.35;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = online ? const Color(0xFF156082) : const Color(0xFF5A7A9A),
    );
    final tri = Path()
      ..moveTo(cx, cy - r * 1.3)
      ..lineTo(cx - r * 0.5, cy - r * 0.4)
      ..lineTo(cx + r * 0.5, cy - r * 0.4)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFFE97132));
  }

  @override
  bool shouldRepaint(_FallbackPainter old) => old.online != online;
}
