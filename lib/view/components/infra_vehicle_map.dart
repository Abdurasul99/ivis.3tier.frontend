import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import '../../model/infra_model.dart';
import '../../model/object_model.dart';
import '../../model/vehicle_model.dart';
import '../../utils/geo_utils.dart' as geo;
import '../../viewmodel/controller/infra_controller.dart';
import '../../viewmodel/controller/object_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../../viewmodel/controller/vehicle_controller.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../../viewmodel/repository/device_registry_repository.dart';
import 'vehicle_marker_overlay.dart';

enum MapEntityType { vehicle, infra }

LatLng lerpLatLng(LatLng a, LatLng b, double t) {
  final double ct = t.clamp(0.0, 1.0);
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * ct,
    a.longitude + (b.longitude - a.longitude) * ct,
  );
}

Map<String, String> _getAuthHeaders() {
  final Map<String, String> headers = <String, String>{
    'Content-Type': 'application/json; charset=utf-8',
  };

  try {
    final String accessToken = Get.find<UserController>().accessToken ?? '';
    if (accessToken.isNotEmpty) {
      headers['x-access-token'] = accessToken;
    }
  } catch (_) {}

  return headers;
}

Uri buildApiUri(String path, [Map<String, String>? queryParams]) {
  String server = kApiServer;
  if (server.startsWith('http://') || server.startsWith('https://')) {
    final Uri parsed = Uri.parse(server);
    final String base = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;
    return parsed.replace(path: '$base$path', queryParameters: queryParams);
  }
  if (kIsWeb && Uri.base.scheme == 'https') {
    return Uri.https(server, path, queryParams);
  }
  return Uri.http(server, path, queryParams);
}

class KiapiWaypointData {
  final double lat;
  final double lon;
  final String name;
  final String shortLabel;
  const KiapiWaypointData({
    required this.lat,
    required this.lon,
    required this.name,
    required this.shortLabel,
  });
}

const List<KiapiWaypointData> kiapiRoadWaypoints = <KiapiWaypointData>[
  KiapiWaypointData(
      lat: 35.875931, lon: 128.596053, name: '대구역', shortLabel: '대구역'),
  KiapiWaypointData(
      lat: 35.877992, lon: 128.627778, name: '동대구역', shortLabel: '동대구'),
  KiapiWaypointData(
      lat: 35.854300, lon: 128.616000, name: '수성구', shortLabel: '수성구'),
  KiapiWaypointData(
      lat: 35.859167, lon: 128.626111, name: '범어역', shortLabel: '범어역'),
  KiapiWaypointData(
      lat: 35.876110, lon: 128.605000, name: '칠성시장', shortLabel: '칠성'),
];

const double kiapiCenterLat = 35.868810;
const double kiapiCenterLon = 128.614446;
// 대구역 건물 내부가 아닌 북동쪽 도로변 RSU 위치
const double kiapiInfraLat = 35.876400;
const double kiapiInfraLon = 128.597800;

class VehicleTrackingData {
  LatLng? targetPosition;
  LatLng? displayPosition;
  double targetHeading;
  double displayHeading;
  bool hasReceivedFirstPosition;
  VehicleInfo? vehicleInfo;
  List<DetectedObject> objects;
  int lastUpdateMs;
  int lastPacketMs;
  double retainedSpeedMps;

  VehicleTrackingData()
      : targetPosition = null,
        displayPosition = null,
        targetHeading = 0.0,
        displayHeading = 0.0,
        hasReceivedFirstPosition = false,
        vehicleInfo = null,
        objects = <DetectedObject>[],
        lastUpdateMs = 0,
        lastPacketMs = 0,
        retainedSpeedMps = 0.0;
}

class _VehicleLiveTrackingSession {
  _VehicleLiveTrackingSession({
    required this.vehicleId,
    required this.startedAtMs,
  });

  final int vehicleId;
  final int startedAtMs;
  int movingStartedAtMs = 0;
  int lastUpdatedAtMs = 0;
  int peakObjectCount = 0;
  int peakMovingObjectCount = 0;
  double peakSpeedKph = 0.0;
  final Set<String> uniqueObjectKeys = <String>{};

  // 실시간 역지오코딩 위치 정보
  String? departureLocationName;   // 출발지 (최초 이동 시작 위치)
  String? currentLocationName;     // 현재 위치 (주기적으로 갱신)
  LatLng? departurePosition;       // 출발 좌표
  LatLng? lastGeocodedPosition;    // 마지막으로 지오코딩한 좌표
  int lastGeocodedAtMs = 0;        // 마지막 지오코딩 시각

  int get uniqueObjectCount => uniqueObjectKeys.length;

  void absorb({
    required List<DetectedObject> objects,
    required bool moving,
    required double speedKph,
    required int nowMs,
  }) {
    lastUpdatedAtMs = nowMs;
    peakSpeedKph = max(peakSpeedKph, speedKph);
    peakObjectCount = max(peakObjectCount, objects.length);
    if (moving) {
      if (movingStartedAtMs == 0) {
        movingStartedAtMs = nowMs;
      }
      peakMovingObjectCount = max(peakMovingObjectCount, objects.length);
    }

    for (int index = 0; index < objects.length; index++) {
      uniqueObjectKeys.add(_objectKey(objects[index], index));
    }
  }

  static String _objectKey(DetectedObject object, int index) {
    final int detectedId = object.detectedObjectId ?? 0;
    if (detectedId > 0) {
      return 'det:$detectedId';
    }

    final int objectId = object.objectId ?? 0;
    if (objectId > 0) {
      return 'obj:$objectId';
    }

    final int type = object.objectType ?? 0;
    final int seq = object.msgSeq ?? 0;
    final int ts = object.timeStampMs ?? 0;
    final String x = ((object.positionX ?? 0.0) * 10).round().toString();
    final String y = ((object.positionY ?? 0.0) * 10).round().toString();
    return 'fallback:$type:$seq:$ts:$x:$y:$index';
  }
}

class ObjectTrackingData {
  LatLng? targetPosition;
  LatLng? displayPosition;
  double targetHeading;
  double displayHeading;
  int lastSeenMs;

  ObjectTrackingData()
      : targetPosition = null,
        displayPosition = null,
        targetHeading = 0.0,
        displayHeading = 0.0,
        lastSeenMs = 0;
}

class _InfraSnapshot {
  final InfraInfo info;
  final LatLng position;
  final int objectCount;

  const _InfraSnapshot({
    required this.info,
    required this.position,
    required this.objectCount,
  });
}

Color getObjectTypeColor(int t) {
  switch (t) {
    case 1:
      return const Color(0xFF1565C0);
    case 2:
      return const Color(0xFFE65100);
    case 3:
      return const Color(0xFF2E7D32);
    case 4:
      return const Color(0xFFE8A000);
    case 5:
      return const Color(0xFFC62828);
    default:
      return const Color(0xFF757575);
  }
}

String getObjectTypeName(int t) {
  switch (t) {
    case 1:
      return '승용차';
    case 2:
      return '트럭';
    case 3:
      return '버스';
    case 4:
      return '보행자';
    case 5:
      return '이륜차';
    default:
      return '미확인';
  }
}

String getObjectTypeNameKorean(int t) {
  switch (t) {
    case 1:
      return '승용차';
    case 2:
      return '트럭';
    case 3:
      return '버스';
    case 4:
      return '보행자';
    case 5:
      return '이륜차';
    default:
      return '미확인';
  }
}

String getObjectTypeEmoji(int t) {
  switch (t) {
    case 1:
      return '\u{1F697}';
    case 2:
      return '\u{1F69A}';
    case 3:
      return '\u{1F68C}';
    case 4:
      return '\u{1F6B6}';
    case 5:
      return '\u{1F3CD}';
    default:
      return '\u2753';
  }
}

double getObjectTypeHue(int t) {
  switch (t) {
    case 1:
      return BitmapDescriptor.hueAzure;
    case 2:
      return BitmapDescriptor.hueOrange;
    case 3:
      return BitmapDescriptor.hueGreen;
    case 4:
      return BitmapDescriptor.hueYellow;
    case 5:
      return BitmapDescriptor.hueRed;
    default:
      return BitmapDescriptor.hueRose;
  }
}

String getObjectTypeShortLabel(int t) {
  switch (t) {
    case 1:
      return '승용차';
    case 2:
      return '트럭';
    case 3:
      return '버스';
    case 4:
      return '보행자';
    case 5:
      return '이륜차';
    default:
      return '미확인';
  }
}

class InfraVehicleMapPanel extends StatefulWidget {
  const InfraVehicleMapPanel({super.key});

  @override
  State<InfraVehicleMapPanel> createState() => InfraVehicleMapPanelState();
}

class InfraVehicleMapPanelState extends State<InfraVehicleMapPanel>
    with WidgetsBindingObserver {
  static const double _sidePanelExpandedWidth = 190.0;
  static const double _sidePanelCollapsedWidth = 34.0;
  static const double _liveTrackingPanelWidth = 300.0;
  static const double _liveTrackingPanelMinContentWidth = 520.0;
  static const Duration _sidePanelAnimationDuration = Duration(
    milliseconds: 280,
  );
  static const CameraPosition _initialCamera = CameraPosition(
      target: LatLng(kiapiCenterLat, kiapiCenterLon), zoom: 15.5);
  static const double _minCameraZoom = 13.0;
  static const double _maxCameraZoom = 20.0;
  static const double _objectMinSeparationMeters = 14.0;
  static const double _objectSeparationRingStepMeters = 6.0;
  static const int _objectSeparationSlots = 8;

  GoogleMapController? _mapController;
  // GoogleMap DOM 요소가 준비된 후에만 마커 업데이트 허용
  // → streams.dart _target! null-check 예외 방지
  bool _mapReady = false;
  bool _mapMounted = false;

  late final VehicleController _vehicleCtrl;
  late final InfraController _infraCtrl;
  late final ObjectController _objectCtrl;
  // 마지막으로 동기화한 dashboard entity type (변경 감지용)
  FmsEntityType? _lastDashEntityType;

  bool _disposed = false;
  bool _realtimeEnabled = true;
  final Set<int> _visibleObjectTypes = <int>{0, 1, 2, 3, 4, 5};
  bool _objectsBarExpanded = false;
  bool _isSidePanelCollapsed = false;
  // 감지 객체 마커 표시 여부 (ON/OFF 버튼으로 제어)
  bool _showDetectedObjects = true;

  MapEntityType _entityType = MapEntityType.vehicle;
  int? _selectedVehicleId;
  int? _selectedInfraId;
  int _selectedStationIdx = 0;
  bool _showWaypoints = false;

  Map<int, VehicleTrackingData> _tracked = <int, VehicleTrackingData>{};
  final Map<String, ObjectTrackingData> _trackedObjects =
      <String, ObjectTrackingData>{};
  _VehicleLiveTrackingSession? _selectedVehicleSession;

  InfraInfo? _infraInfo;
  List<DetectedObject> _infraObjects = <DetectedObject>[];
  LatLng? _infraMarkerPos;
  Map<int, _InfraSnapshot> _infraSnapshots = <int, _InfraSnapshot>{};

  Set<Marker> _markers = <Marker>{};
  Set<Polyline> _polylines = <Polyline>{};

  Set<Marker> _staticMarkers = <Marker>{};
  bool _staticMarkersBuilt = false;

  // 레지스트리에 등록됐지만 텔레메트리가 없는 오프라인 장치 목록
  List<Map<String, dynamic>> _offlineVehicles = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _offlineInfras = <Map<String, dynamic>>[];
  int _lastRegistryFetchMs = 0;

  BitmapDescriptor? _vehicleIcon;
  BitmapDescriptor? _vehicleSelectedIcon;
  BitmapDescriptor? _vehicleMovingIcon;
  BitmapDescriptor? _vehicleMovingSelectedIcon;
  BitmapDescriptor? _infraIcon;
  BitmapDescriptor? _infraBlinkIcon;
  BitmapDescriptor? _infraOfflineIcon;
  BitmapDescriptor? _infraOfflineSelectedIcon;
  List<BitmapDescriptor> _stationIcons = <BitmapDescriptor>[];
  List<BitmapDescriptor> _stationSelectedIcons = <BitmapDescriptor>[];

  Map<int, BitmapDescriptor> _objectIcons = <int, BitmapDescriptor>{};
  int _objectIconSizePx = 52;
  int _lastRequestedObjectIconSizePx = 52;
  bool _objectIconResizeInFlight = false;

  // 적응형 마커 크기: 차량/인프라/스테이션 아이콘도 동일 scale 기준으로 조정
  int _vehicleIconSizePx = 64;

  // ── car.png 헤딩별 회전 아이콘 캐시 (15° 버킷 = 최대 24종) ─────────────────
  // Web에서 icon 변경 시 BitmapDescriptor.bytes 재변환으로 인한 깜빡임 발생
  // → bucket을 5°에서 15°로 확대하여 회전당 icon switch 횟수 1/3로 감소
  static const int _carBucketDeg = 15;

  // 차량별 마지막으로 사용한 bucket 기록 → hysteresis 적용
  // Per-vehicle last-used bucket → hysteresis to prevent icon flicker
  // 다음 bucket 으로 전환되려면 최소 _bucketHysteresisSteps 만큼 차이가 나야 함
  // Must change by >= _bucketHysteresisSteps buckets to switch icon
  static const int _bucketHysteresisSteps = 2; // 2 * 15° = 30° threshold
  final Map<int, int> _vehicleLastBucket = <int, int>{};
  static const double _vehicleMovingMarkerScale = 1.18;
  final Map<String, BitmapDescriptor> _carIconNormal =
      <String, BitmapDescriptor>{};
  final Map<String, BitmapDescriptor> _carIconSelected =
      <String, BitmapDescriptor>{};
  final Set<String> _carIconPending = <String>{};
  ui.Image? _carSrcImg; // 원본 PNG (1회 로드)
  bool _carSrcLoading = false;
  int _carSrcSizePx = 0; // 캐시된 크기

  Timer? _dbPollTimer;
  static const int _dbPollIntervalMs = 1000; // 650 → 1000ms로 완화
  bool _tabVisible = true; // TickerMode 기반 탭 가시성
  // 부하시험 대비 상향(기존 120 → 차량 300 / 인프라 100). 시뮬레이터가 최대 255대
  // 차량 + 30 인프라를 발행하므로 120 제한 시 나머지가 오프라인(빨강)으로 표시됐음.
  static const int _vehicleStatusFetchLimit = 300;
  static const int _infraStatusFetchLimit = 100;
  // 6초 grace 는 클라이언트-서버 시계 드리프트 + 백엔드 지연 + interpolation buffer
  // 합산 시 경계선에 걸려 마커가 online/offline 사이에서 깜빡이는 버그 발생
  // → 30초로 확대하여 안정적 가시성 확보
  // 6 sec grace was too tight: combined client-server clock drift + backend lag could
  // push tsMs near the boundary, causing marker flip-flop online/offline → visible flicker
  // 30 sec grace fully tolerates any reasonable drift/lag/interp buffer
  static const int _vehicleOnlineGraceMs = 30000;
  static const int _infraOnlineGraceMs = 30000;
  Timer? _infraBlinkTimer;
  static const int _infraBlinkIntervalMs = 550;
  bool _infraBlinkOn = true;

  Timer? _interpTimer;
  static const int _interpIntervalMs = 16;
  static const double _convergenceThreshold = 0.0000002;
  static const double _convergenceHeadingDeg = 0.3;
  static const double _teleportDistM = 2000.0;
  static const double _serverPositionUpdateMinMeters = 0.35;
  static const double _vehiclePredictMinSpeedMps = 0.3;
  static const int _vehiclePredictFreshPacketMs = 1200;
  // 예측 지연 추정(고정): 실측 age(now-ts)는 폴링 지터로 흔들려 예측량이 변하고,
  // 그 결과 마커가 뒤로 튄다. 갱신 경로에선 안정적 고정값을 써서 후진 점프를 막는다.
  static const int _vehiclePredictStableDelayMs = 1000;
  static const int _vehiclePredictStartAfterMs = 80;
  static const int _vehiclePredictMaxAgeMs = 4200;
  static const double _vehiclePredictMaxSeconds = 1.6;
  static const double _vehiclePredictMaxDistanceMeters = 20.0;
  static const int _vehicleRetainSpeedMs = 2500;
  static const double _vehicleFollowSpeedGain = 1.2;
  static const double _vehicleMinCatchupSpeedMps = 1.2;
  static const double _vehicleMinMoveStepMeters = 0.05;
  static const double _vehicleMaxMoveStepMeters = 3.0;
  static const double _vehicleMaxTurnRateDegPerSec = 260.0;
  static const double _vehicleRollbackGuardMeters = 10.0;
  static const double _vehicleRollbackMaxHeadingDeltaDeg = 120.0;
  static const double _vehicleRollbackClampMeters = 1.4;
  static const double _objectPosLerpFactor = 0.18;
  static const double _objectHeadLerpFactor = 0.16;
  static const double _objectConvergenceThreshold = 0.0000001;
  static const double _objectConvergenceHeadingDeg = 0.5;
  static const double _objectTeleportDistM = 1500.0;
  static const int _objectTrackingExpiryMs = 12000;
  static const double _objectRelativeMaxAbsMeters = 20000.0;
  static const double _objectAbsoluteParentMaxDistanceMeters = 2000.0;

  int _lastMarkerRebuildMs = 0;
  // Web에서 100대 마커 빈번한 position 갱신 시 깜빡임 발생 (Google Maps JS marker setter)
  // 200ms = 5 FPS marker update → 차량 12m/s 기준 2.4m 점프 (시각적 허용 범위)
  // 깜빡임 1000 events/sec → 500 events/sec (절반 감소)
  static const int _markerRebuildThrottleMs = 200;
  // 위치/방향 변화가 임계값 미만이면 Marker 재생성 스킵
  // Skip marker recreation if position/heading change is below threshold
  static const double _markerPositionDeltaMeters = 0.5;
  static const double _markerHeadingDeltaDeg = 5.0;
  // 차량별 마지막으로 렌더링된 Marker (캐시)
  // Per-vehicle last rendered Marker (cache to skip rebuild)
  final Map<int, Marker> _lastVehicleMarker = <int, Marker>{};
  final Map<int, LatLng> _lastVehicleMarkerPos = <int, LatLng>{};
  final Map<int, double> _lastVehicleMarkerHeading = <int, double>{};

  // ── CRITICAL: 차량별 stable icon 참조 / Per-vehicle STABLE icon reference ──
  // google_maps_flutter_web 는 icon 참조가 바뀌면 PNG 를 다시 로드 → 빈 프레임 → 깜빡임
  // 한 번 정해진 icon 은 EXACT match 가 들어올 때까지 절대 바꾸지 않음
  // google_maps_flutter_web reloads <img> if icon ref differs → empty frame → FLICKER
  // Once assigned, NEVER swap to "nearest" — only swap to EXACT match when available
  final Map<int, BitmapDescriptor> _vehicleIconRef = <int, BitmapDescriptor>{};
  final Map<int, String> _vehicleIconKey = <int, String>{};

  // ============================================================================
  // FLUTTER OVERLAY 차량 렌더 (google_maps_flutter_web 깜빡임 최종 해결책)
  // Flutter Stack overlay rendered on TOP of plugin markers — covers the flickering
  // <img> elements so user only sees stable Flutter widgets. Plugin markers still
  // exist underneath but are visually hidden by overlay icons.
  //
  // 플래그 끄면 (false) 즉시 기존 동작으로 복귀
  // Set _useVehicleOverlay = false for instant rollback to old marker-only behavior.
  // ============================================================================
  static const bool _useVehicleOverlay = true;
  final ValueNotifier<OverlayCameraSnapshot> _overlayCamera =
      ValueNotifier<OverlayCameraSnapshot>(OverlayCameraSnapshot.empty);
  Size _overlayContainerSize = Size.zero;
  EdgeInsets _overlayPadding = EdgeInsets.zero;
  final Map<int, bool> _lastVehicleMarkerSelected = <int, bool>{};
  int _markerSeq = 0;
  bool _initialMarkersBuilt = false;
  int _lastInterpStepMs = 0;

  bool _cameraFollows = false;
  bool _cameraFollowsInfra = false;

  // 오토팔로우 ON/OFF (외부에서 GlobalKey로 호출 가능)
  bool get isAutoFollowOn => _cameraFollows || _cameraFollowsInfra;
  void toggleAutoFollow() {
    final bool currentlyOn = _cameraFollows || _cameraFollowsInfra;
    setState(() {
      _cameraFollows = !currentlyOn;
      _cameraFollowsInfra = !currentlyOn;
    });
  }

  int _lastCameraMoveMs = 0;
  static const int _cameraCooldownMs = 3000;
  static const int _followCameraThrottleMs = 250;
  int _lastVehicleFollowMs = 0;
  int _lastInfraFollowMs = 0;
  double _currentMapZoom = _initialCamera.zoom;
  double _lastBuiltZoom = _initialCamera.zoom;
  LatLng _currentCameraTarget = _initialCamera.target;
  Size? _lastMapViewportSize;
  Timer? _mapViewportRefreshTimer;

  List<LatLng> _routePoints = <LatLng>[];
  Map<String, List<LatLng>> _routeCache = <String, List<LatLng>>{};

  int _consecutiveErrorCount = 0;
  bool _vehiclePollInFlight = false;
  bool _infraPollInFlight = false;
  int _vehiclePollStartedMs = 0;
  int _infraPollStartedMs = 0;
  static const int _pollInFlightStuckMs = 12000;

  bool _vehicleObjectsRefreshInFlight = false;
  int _lastVehicleObjectsRefreshMs = 0;
  static const int _vehicleObjectsRefreshMinIntervalMs = 450;

  final Map<int, List<DetectedObject>> _objectsCacheByVehicleInfoId =
      <int, List<DetectedObject>>{};
  final Map<int, int> _objectsCacheTimestampMs = <int, int>{};

  bool _isVehicleOnline(int vehicleId, {int? nowMs}) {
    final VehicleTrackingData? tracking = _tracked[vehicleId];
    if (tracking == null) {
      return false;
    }

    final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final int tsMs = tracking.vehicleInfo?.timeStampMs ?? 0;
    if (tsMs > 0) {
      return (now - tsMs).abs() <= _vehicleOnlineGraceMs;
    }

    if (tracking.lastUpdateMs > 0) {
      return (now - tracking.lastUpdateMs).abs() <= _vehicleOnlineGraceMs;
    }

    return false;
  }

  bool _isInfraStatusFresh(int tsMs, {int? nowMs}) {
    if (tsMs <= 0) {
      return false;
    }
    final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return (now - tsMs).abs() <= _infraOnlineGraceMs;
  }

  Map<String, dynamic>? _registryVehicleById(int vehicleId) {
    for (final Map<String, dynamic> reg in _offlineVehicles) {
      final int rid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (rid == vehicleId) {
        return reg;
      }
    }
    return null;
  }

  LatLng? _trackedVehiclePosition(int vehicleId) {
    final VehicleTrackingData? tracking = _tracked[vehicleId];
    final LatLng? position =
        tracking?.displayPosition ?? tracking?.targetPosition;
    if (position == null) {
      return null;
    }
    if (!geo.isValidLatLng(position.latitude, position.longitude)) {
      return null;
    }
    return position;
  }

  LatLng? _registryVehiclePosition(int vehicleId) {
    final Map<String, dynamic>? regEntry = _registryVehicleById(vehicleId);
    if (regEntry == null) {
      return null;
    }
    final double? lat =
        double.tryParse(regEntry['location_lat']?.toString() ?? '');
    final double? lng =
        double.tryParse(regEntry['location_lng']?.toString() ?? '');
    if (lat == null || lng == null) {
      return null;
    }
    if (!geo.isValidLatLng(lat, lng)) {
      return null;
    }
    return LatLng(lat, lng);
  }

  LatLng? _resolvedVehiclePosition(int vehicleId, {int? nowMs}) {
    final LatLng? trackedPosition = _trackedVehiclePosition(vehicleId);
    if (trackedPosition != null) {
      return trackedPosition;
    }

    return _registryVehiclePosition(vehicleId);
  }

  String _vehicleName(int vehicleId) {
    final Map<String, dynamic>? regEntry = _registryVehicleById(vehicleId);
    final String name = regEntry?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty && name != '-') {
      return name;
    }
    return '차량 $vehicleId';
  }

  String _vehicleLocationLabel(int vehicleId) {
    final Map<String, dynamic>? regEntry = _registryVehicleById(vehicleId);
    final String location = regEntry?['location_address']?.toString().trim() ??
        regEntry?['home_station']?.toString().trim() ??
        '';
    if (location.isNotEmpty && location != '-') {
      return location;
    }
    return '위치 정보 없음';
  }

  Set<int> _allKnownVehicleIds() {
    final Set<int> ids = <int>{};
    for (final Vehicle v in _vehicleCtrl.vehicles) {
      if (v.vehicleId != null && v.vehicleId! > 0) {
        ids.add(v.vehicleId!);
      }
    }
    ids.addAll(_tracked.keys);
    for (final Map<String, dynamic> reg in _offlineVehicles) {
      final int id = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (id > 0) {
        ids.add(id);
      }
    }
    if (_selectedVehicleId != null && _selectedVehicleId! > 0) {
      ids.add(_selectedVehicleId!);
    }
    return ids;
  }

  Vehicle? _vehicleById(int vehicleId) {
    for (final Vehicle vehicle in _vehicleCtrl.vehicles) {
      if (vehicle.vehicleId == vehicleId) {
        return vehicle;
      }
    }
    return null;
  }

  void _resetSelectedVehicleSession(int vehicleId, {int? nowMs}) {
    _selectedVehicleSession = _VehicleLiveTrackingSession(
      vehicleId: vehicleId,
      startedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // 카카오 역지오코딩 — 현재 위치명 및 출발지 갱신
  static const double _geocodeMinDistanceM = 200.0;   // 200m 이상 이동 시 갱신
  static const int    _geocodeMinIntervalMs = 30000;  // 최소 30초 간격

  Future<String?> _geocodePosition(LatLng pos) async {
    try {
      final Uri uri = buildApiUri('/api/activity/geocode');
      final http.Response resp = await http.post(
        uri,
        headers: _getAuthHeaders(),
        body: '{"latitude":${pos.latitude},"longitude":${pos.longitude}}',
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(resp.body);
      return decoded?['body']?['location_name']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeUpdateGeocode({required int nowMs}) async {
    final _VehicleLiveTrackingSession? session = _selectedVehicleSession;
    if (session == null) return;

    final VehicleTrackingData? tracking = _tracked[session.vehicleId];
    final LatLng? currentPos = tracking?.displayPosition;
    if (currentPos == null) return;

    final LatLng? lastPos = session.lastGeocodedPosition;
    final bool tooSoon = (nowMs - session.lastGeocodedAtMs) < _geocodeMinIntervalMs;

    // 출발지 아직 미설정 → 즉시 지오코딩
    final bool needDeparture = session.departurePosition == null;
    // 충분한 거리 이동 + 시간 경과
    final bool movedFar = lastPos != null &&
        geo.haversineMeters(lastPos.latitude, lastPos.longitude,
            currentPos.latitude, currentPos.longitude) >= _geocodeMinDistanceM;

    if (!needDeparture && (tooSoon || (!movedFar))) return;

    final String? name = await _geocodePosition(currentPos);
    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    setState(() {
      session.currentLocationName = name;
      session.lastGeocodedPosition = currentPos;
      session.lastGeocodedAtMs = nowMs;
      if (needDeparture) {
        session.departureLocationName = name;
        session.departurePosition = currentPos;
      }
    });
  }

  void _updateSelectedVehicleSession({required int nowMs}) {
    final int? vehicleId = _selectedVehicleId;
    if (vehicleId == null || vehicleId <= 0) {
      return;
    }

    final VehicleTrackingData? tracking = _tracked[vehicleId];
    if (tracking == null) {
      return;
    }

    if (_selectedVehicleSession == null ||
        _selectedVehicleSession!.vehicleId != vehicleId) {
      _resetSelectedVehicleSession(vehicleId, nowMs: nowMs);
    }

    final double speedMps =
        tracking.vehicleInfo?.velocityMps ?? tracking.retainedSpeedMps;
    final double speedKph = tracking.vehicleInfo?.velocityKph ?? speedMps * 3.6;

    _selectedVehicleSession!.absorb(
      objects: tracking.objects,
      moving: speedMps >= _vehiclePredictMinSpeedMps || speedKph >= 1.0,
      speedKph: speedKph,
      nowMs: nowMs,
    );

    // 역지오코딩 비동기 갱신 (30초 간격 / 200m 이상 이동 시)
    unawaited(_maybeUpdateGeocode(nowMs: nowMs));
  }

  // 외부(tab_dashboard 등)에서 GlobalKey로 차량 선택 가능한 공개 메서드
  void selectVehicle(int vehicleId, {LatLng? focusPosition}) {
    _selectVehicle(vehicleId, focusPosition: focusPosition);
  }

  void _selectVehicle(
    int vehicleId, {
    LatLng? focusPosition,
    bool? followLive,
  }) {
    if (_disposed || !mounted) {
      return;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final bool live = followLive ?? _isVehicleOnline(vehicleId, nowMs: nowMs);
    final bool changed = _selectedVehicleId != vehicleId;

    setState(() {
      _selectedVehicleId = vehicleId;
      _cameraFollows = live;
      _cameraFollowsInfra = false;
      if (changed) {
        _resetSelectedVehicleSession(vehicleId, nowMs: nowMs);
      }
    });
    trackingPanelActive.value = true;

    final LatLng? targetPosition =
        focusPosition ?? _resolvedVehiclePosition(vehicleId, nowMs: nowMs);
    if (targetPosition != null) {
      _moveCameraTo(targetPosition, zoom: 16.9);
    }

    _forceRebuildMarkers();
    if (live) {
      _maybeFollowSelectedVehicle();
    }
  }

  void _clearSelectedVehicle() {
    if (_disposed || !mounted) {
      return;
    }
    if (_selectedVehicleId == null) {
      return;
    }

    setState(() {
      _selectedVehicleId = null;
      _cameraFollows = false;
      _cameraFollowsInfra = false;
      _selectedVehicleSession = null;
    });
    trackingPanelActive.value = false;
    _forceRebuildMarkers();
  }

  bool _shouldShowVehicleTrackingPanel(double contentWidth) {
    return _entityType == MapEntityType.vehicle &&
        _selectedVehicleId != null &&
        contentWidth >= _liveTrackingPanelMinContentWidth;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TabBarView가 비활성 탭에 TickerMode(enabled:false)를 설정한다.
    // 설정 탭으로 이동 시 지도 DB 폴링을 일시 중지하여 불필요한 API 요청을 막는다.
    final bool nowVisible = TickerMode.of(context);
    if (nowVisible == _tabVisible) return;
    _tabVisible = nowVisible;
    if (_tabVisible) {
      // 탭이 다시 보일 때 폴링 재개
      if (!_disposed && mounted && _realtimeEnabled) {
        _recoverRealtimePolling();
      }
    } else {
      // 탭이 숨겨질 때 폴링 일시 중지 (interpTimer는 유지)
      _dbPollTimer?.cancel();
      _dbPollTimer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vehicleCtrl = Get.isRegistered<VehicleController>()
        ? Get.find<VehicleController>()
        : Get.put(VehicleController());
    _infraCtrl = Get.isRegistered<InfraController>()
        ? Get.find<InfraController>()
        : Get.put(InfraController());
    _objectCtrl = Get.isRegistered<ObjectController>()
        ? Get.find<ObjectController>()
        : Get.put(ObjectController());

    // DashboardController와 entity type 동기화
    if (Get.isRegistered<DashboardController>()) {
      final FmsEntityType dashType =
          Get.find<DashboardController>().currentEntityType;
      _lastDashEntityType = dashType;
      _entityType = dashType == FmsEntityType.infra
          ? MapEntityType.infra
          : MapEntityType.vehicle;
    }

    _startInterpolationTimer();
    _startInfraBlinkTimer();
    _initAsync();
    // GoogleMap은 첫 프레임 이후 마운트 — DOM 요소 준비 전 이벤트 리스너 등록 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) {
        setState(() => _mapMounted = true);
      }
    });
  }

  // DashboardController entity type 변경 시 지도를 동기화한다
  void _syncEntityTypeFromDashboard(FmsEntityType dashType) {
    final MapEntityType wanted = dashType == FmsEntityType.infra
        ? MapEntityType.infra
        : MapEntityType.vehicle;
    if (wanted == _entityType || _disposed || !mounted) return;
    setState(() {
      _entityType = wanted;
      _cameraFollows = false;
      _cameraFollowsInfra = false;
      _markers = <Marker>{};
      _polylines = <Polyline>{};
      _infraInfo = null;
      _infraObjects = <DetectedObject>[];
      _infraMarkerPos = null;
      _infraSnapshots = <int, _InfraSnapshot>{};
    });
    if (wanted == MapEntityType.infra) {
      _cameraFollowsInfra = true;
      _buildInfraMarkers();
      if (_selectedInfraId != null && _infraMarkerPos != null) {
        _moveCameraTo(_infraMarkerPos!, zoom: 16.9);
      } else {
        _fitAllInfraMarkersInView();
      }
      _maybeFollowSelectedInfra();
    } else {
      _forceRebuildMarkers();
      if (_selectedVehicleId != null) {
        final LatLng? pos = _resolvedVehiclePosition(_selectedVehicleId!);
        if (pos != null) {
          _moveCameraTo(pos, zoom: 16.6);
        }
      }
    }
    _pollStatusData();
  }

  bool _isObjectTypeVisible(int objectType) {
    final int safeType = objectType.clamp(0, 5);
    return _visibleObjectTypes.contains(safeType);
  }

  void _toggleObjectTypeVisibility(int objectType) {
    final int safeType = objectType.clamp(0, 5);
    setState(() {
      if (_visibleObjectTypes.contains(safeType)) {
        if (_visibleObjectTypes.length == 1) {
          return;
        }
        _visibleObjectTypes.remove(safeType);
      } else {
        _visibleObjectTypes.add(safeType);
      }
    });
    if (_entityType == MapEntityType.vehicle) {
      _forceRebuildMarkers();
    } else {
      _buildInfraMarkers();
    }
  }

  void _toggleSidePanel() {
    if (_disposed || !mounted) {
      return;
    }

    setState(() {
      _isSidePanelCollapsed = !_isSidePanelCollapsed;
    });

    _scheduleMapViewportRefresh(
      delay: _sidePanelAnimationDuration + const Duration(milliseconds: 60),
    );
  }

  void _handleMapViewportSizeChanged(Size nextSize) {
    final Size? previousSize = _lastMapViewportSize;

    if (previousSize != null &&
        (previousSize.width - nextSize.width).abs() < 1 &&
        (previousSize.height - nextSize.height).abs() < 1) {
      return;
    }

    _lastMapViewportSize = nextSize;
    _scheduleMapViewportRefresh();
  }

  void _scheduleMapViewportRefresh({
    Duration delay = const Duration(milliseconds: 180),
  }) {
    _mapViewportRefreshTimer?.cancel();
    _mapViewportRefreshTimer = Timer(delay, () {
      if (_disposed || !mounted) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !mounted) {
          return;
        }

        _refreshMapViewport();
      });
    });
  }

  LatLng _preferredCameraTarget() {
    if (geo.isValidLatLng(
      _currentCameraTarget.latitude,
      _currentCameraTarget.longitude,
    )) {
      return _currentCameraTarget;
    }

    if (_entityType == MapEntityType.vehicle) {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_selectedVehicleId != null) {
        final LatLng? selectedPosition =
            _resolvedVehiclePosition(_selectedVehicleId!, nowMs: nowMs);
        if (selectedPosition != null &&
            geo.isValidLatLng(
              selectedPosition.latitude,
              selectedPosition.longitude,
            )) {
          return selectedPosition;
        }
      }

      for (final int vehicleId in _allKnownVehicleIds()) {
        final LatLng? position =
            _resolvedVehiclePosition(vehicleId, nowMs: nowMs);
        if (position != null &&
            geo.isValidLatLng(position.latitude, position.longitude)) {
          return position;
        }
      }
    } else if (_infraMarkerPos != null &&
        geo.isValidLatLng(
          _infraMarkerPos!.latitude,
          _infraMarkerPos!.longitude,
        )) {
      return _infraMarkerPos!;
    }

    return _initialCamera.target;
  }

  void _refreshMapViewport() {
    if (_mapController == null) {
      return;
    }

    final LatLng target = _preferredCameraTarget();
    final double zoom = _currentMapZoom.clamp(_minCameraZoom, _maxCameraZoom);

    _moveCameraTo(target, zoom: zoom);
  }

  void _resetObjectTypeVisibility() {
    setState(() {
      _visibleObjectTypes
        ..clear()
        ..addAll(<int>{0, 1, 2, 3, 4, 5});
    });
    if (_entityType == MapEntityType.vehicle) {
      _forceRebuildMarkers();
    } else {
      _buildInfraMarkers();
    }
  }

  void _selectStation(int idx) {
    if (_disposed || !mounted) return;

    final int safeIdx = idx.clamp(0, kiapiRoadWaypoints.length - 1);
    final KiapiWaypointData wp = kiapiRoadWaypoints[safeIdx];

    setState(() {
      _selectedStationIdx = safeIdx;
      _staticMarkersBuilt = false;
    });

    _rebuildStaticMarkers();

    if (_entityType == MapEntityType.vehicle) {
      _rebuildMarkersThrottled();
    } else {
      _buildInfraMarkers();
    }

    _moveCameraTo(LatLng(wp.lat, wp.lon), zoom: 16.2);
  }

  // 라이브 추적 패널 스크롤 컨트롤러
  final ScrollController _panelScrollCtrl = ScrollController();

  // 사이드 패널(차량/인프라 목록) 스크롤 컨트롤러
  final ScrollController _sideListScrollCtrl = ScrollController();

  // 마우스가 추적 패널 위에 있을 때 지도 스크롤 비활성화용 플래그
  bool _panelHovered = false;

  // 추적 패널 표시 여부 — tab_dashboard 등 외부에서 구독 가능
  final ValueNotifier<bool> trackingPanelActive = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _disposed = true;
    _panelScrollCtrl.dispose();
    _sideListScrollCtrl.dispose();
    trackingPanelActive.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _dbPollTimer?.cancel();
    _infraBlinkTimer?.cancel();
    _interpTimer?.cancel();
    _mapViewportRefreshTimer?.cancel();
    _mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !mounted) return;
    if (state == AppLifecycleState.resumed) {
      _recoverRealtimePolling();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _vehiclePollInFlight = false;
      _infraPollInFlight = false;
    }
  }

  Future<void> _initAsync() async {
    // Fix: 마커 생성과 초기 데이터 로드를 병렬 실행하여 초기화 지연 최소화.
    // 기존에는 _createCustomMarkers()가 완료될 때까지(웹에서 최대 2초) 데이터 로드가
    // 블로킹되어 첫 위치 표시가 크게 지연되었음.
    await Future.wait(<Future<void>>[
      _createCustomMarkers(),
      _initData(),
    ]);
    if (_disposed) return;

    _startDbPolling();
    _forceRebuildMarkers();

    // 차량 아이콘 prewarm: 모든 heading bucket 미리 생성 → 주행 중 깜빡임 방지
    // Background prewarm — no await so it doesn't block startup
    unawaited(_prewarmCarIcons());
  }

  Future<void> _initData() async {
    if (!_vehicleCtrl.hasToken) {
      await _waitForToken();
    }
    if (_disposed) return;
    await _vehicleCtrl.reqLoadVehicles();
    if (_disposed) return;

    _selectedInfraId = 0;

    // 레지스트리 오프라인 장치 초기 로드 (telemetry 없는 등록 장치용)
    unawaited(_fetchRegistryDevices());

    await _pollStatusData();

    if (!_disposed && mounted) setState(() {});
  }

  // 30초마다 device_registry를 조회해 오프라인 장치 목록 갱신
  Future<void> _fetchRegistryDevices() async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRegistryFetchMs < 30000) return;
    _lastRegistryFetchMs = now;
    try {
      final List<Map<String, dynamic>> all =
          await DeviceRegistryRepository().requestList();
      if (_disposed || !mounted) return;
      setState(() {
        _offlineVehicles =
            all.where((d) => d['device_type'] == 'vehicle').toList();
        _offlineInfras = all.where((d) => d['device_type'] == 'infra').toList();
      });
    } catch (_) {}
  }

  Future<void> _waitForToken() async {
    for (int i = 0; i < 300; i++) {
      if (_disposed) return;
      if (_vehicleCtrl.hasToken) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _startDbPolling() {
    _dbPollTimer?.cancel();
    _dbPollTimer = Timer.periodic(
      const Duration(milliseconds: _dbPollIntervalMs),
      (_) => _pollStatusData(),
    );
  }

  void _recoverRealtimePolling() {
    if (_disposed || !mounted || !_realtimeEnabled) {
      return;
    }
    _vehiclePollInFlight = false;
    _infraPollInFlight = false;

    // 탭이 숨겨진 동안 interpTimer가 멈춰서 displayPosition이 뒤쳐짐.
    // 복귀 시 즉시 targetPosition으로 스냅하여 지연 없이 현재 위치를 표시한다.
    for (final VehicleTrackingData t in _tracked.values) {
      if (t.targetPosition != null) {
        t.displayPosition = t.targetPosition;
        t.displayHeading = t.targetHeading;
      }
    }
    for (final ObjectTrackingData ot in _trackedObjects.values) {
      if (ot.targetPosition != null) {
        ot.displayPosition = ot.targetPosition;
        ot.displayHeading = ot.targetHeading;
      }
    }

    _startDbPolling();
    if (_interpTimer == null || !_interpTimer!.isActive) {
      _startInterpolationTimer();
    }
    if (_infraBlinkTimer == null || !_infraBlinkTimer!.isActive) {
      _startInfraBlinkTimer();
    }
    unawaited(_pollStatusData());
  }

  void _startInfraBlinkTimer() {
    _infraBlinkTimer?.cancel();
    _infraBlinkTimer = Timer.periodic(
        const Duration(milliseconds: _infraBlinkIntervalMs), (_) {
      if (_disposed || !mounted) return;
      _infraBlinkOn = !_infraBlinkOn;
      if (_entityType == MapEntityType.infra) {
        _buildInfraMarkers();
      }
    });
  }

  Future<void> _pollStatusData() async {
    if (_disposed || !mounted || !_realtimeEnabled || !_tabVisible) return;

    // 30초 주기로 레지스트리 오프라인 장치 갱신
    unawaited(_fetchRegistryDevices());

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_entityType == MapEntityType.vehicle) {
      if (_vehiclePollInFlight) {
        if (nowMs - _vehiclePollStartedMs < _pollInFlightStuckMs) {
          return;
        }
        _vehiclePollInFlight = false;
      }

      _vehiclePollInFlight = true;
      _vehiclePollStartedMs = nowMs;
      try {
        // 차량 상태와 인프라 상태를 동시에 조회 (차량 뷰에서도 인프라 마커 표시)
        await Future.wait(<Future<void>>[
          _fetchVehicleStatusFromDb(),
          _fetchInfraStatusFromDb(),
        ]);
      } finally {
        _vehiclePollInFlight = false;
      }
    } else {
      if (_infraPollInFlight) {
        if (nowMs - _infraPollStartedMs < _pollInFlightStuckMs) {
          return;
        }
        _infraPollInFlight = false;
      }

      _infraPollInFlight = true;
      _infraPollStartedMs = nowMs;
      try {
        // 인프라 뷰에서도 차량 데이터 조회 (지도에 차량 마커 표시)
        await Future.wait(<Future<void>>[
          _fetchVehicleStatusFromDb(),
          _fetchInfraStatusFromDb(),
        ]);
      } finally {
        _infraPollInFlight = false;
      }
    }
  }

  Future<List<DetectedObject>> _fetchDetectedObjectsByVehicleInfoId(
      int vehicleInfoId,
      {int? vehicleTimestampMs}) async {
    try {
      final Uri uri = buildApiUri('/api/detectedObjects/byVehicleInfo');

      final Map<String, dynamic> requestBody = <String, dynamic>{
        'vehicle_info_id': vehicleInfoId,
        'latest_only': true,
      };

      if (vehicleTimestampMs != null && vehicleTimestampMs > 0) {
        requestBody['vehicle_time_stamp_ms'] = vehicleTimestampMs;
      }

      final http.Response resp = await http
          .post(
            uri,
            headers: _getAuthHeaders(),
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode != 200) {
        return <DetectedObject>[];
      }

      final dynamic decoded = jsonDecode(resp.body);
      return _parseDetectedObjectsResponse(decoded);
    } catch (_) {
      return <DetectedObject>[];
    }
  }

  /// 여러 차량의 탐지 객체를 **단일 배치 요청**으로 가져온다.
  /// 차량마다 byVehicleInfo 를 호출하면 100대 = 100요청 → 브라우저 연결풀(6개)
  /// 포화로 테이블/차트 요청이 굶주림. byMultipleVehicles 로 1요청에 처리.
  /// 반환: { vehicleId: [DetectedObject...] }
  Future<Map<int, List<DetectedObject>>> _fetchDetectedObjectsBatchByVehicleIds(
      List<int> vehicleIds) async {
    final Map<int, List<DetectedObject>> result = <int, List<DetectedObject>>{};
    if (vehicleIds.isEmpty) {
      return result;
    }
    try {
      final Uri uri = buildApiUri('/api/detectedObjects/byMultipleVehicles');
      final http.Response resp = await http
          .post(
            uri,
            headers: _getAuthHeaders(),
            body: jsonEncode(<String, dynamic>{
              'vehicle_ids': vehicleIds,
              'latest_only': true,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        return result;
      }
      final dynamic decoded = jsonDecode(resp.body);
      dynamic grouped = decoded;
      if (decoded is Map && decoded['body'] != null) {
        grouped = decoded['body'];
      }
      if (grouped is Map) {
        grouped.forEach((dynamic key, dynamic value) {
          final int vid = int.tryParse(key.toString()) ?? 0;
          if (vid > 0) {
            result[vid] = _parseDetectedObjectsResponse(value);
          }
        });
      }
      return result;
    } catch (_) {
      return result;
    }
  }

  Future<List<DetectedObject>> _fetchDetectedObjectsByInfraInfoId(
      int infraInfoId) async {
    try {
      final Uri uri = buildApiUri('/api/detectedObjects/byInfraInfo');
      final http.Response resp = await http
          .post(
            uri,
            headers: _getAuthHeaders(),
            body: jsonEncode(<String, dynamic>{
              'infra_info_id': infraInfoId,
              'limit': 500,
              'offset': 0,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        return <DetectedObject>[];
      }
      final dynamic decoded = jsonDecode(resp.body);
      return _parseDetectedObjectsResponse(decoded);
    } catch (_) {
      return <DetectedObject>[];
    }
  }

  List<DetectedObject> _parseDetectedObjectsResponse(dynamic decoded) {
    if (decoded is List) {
      return _parseObjectsFromJson(decoded);
    }

    if (decoded is Map<String, dynamic>) {
      final dynamic body = decoded['body'];
      if (body is Map<String, dynamic>) {
        final dynamic items = body['items'] ?? body['data'] ?? body['list'];
        if (items is List) {
          return _parseObjectsFromJson(items);
        }
      }
      if (body is List) {
        return _parseObjectsFromJson(body);
      }

      final dynamic data = decoded['data'];
      if (data is List) {
        return _parseObjectsFromJson(data);
      }

      final dynamic items = decoded['items'];
      if (items is List) {
        return _parseObjectsFromJson(items);
      }
    }

    return <DetectedObject>[];
  }

  Future<void> _fetchVehicleStatusFromDb() async {
    try {
      final Uri uri = buildApiUri('/api/vehicle/status');

      final http.Response resp = await http
          .post(
            uri,
            headers: _getAuthHeaders(),
            body: jsonEncode(<String, dynamic>{
              'limit': _vehicleStatusFetchLimit,
              'offset': 0,
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (resp.statusCode != 200) {
        _consecutiveErrorCount++;
        if (kDebugMode)
          debugPrint('[POLL] Vehicle status HTTP ${resp.statusCode}');
        return;
      }

      _consecutiveErrorCount = 0;

      final dynamic decoded = jsonDecode(resp.body);

      List<dynamic> vehicleList = <dynamic>[];

      if (decoded is Map<String, dynamic>) {
        final dynamic body = decoded['body'];
        if (body is Map<String, dynamic>) {
          final dynamic items = body['items'];
          if (items is List) {
            vehicleList = items;
          }
        } else if (body is List) {
          vehicleList = body;
        } else if (decoded.containsKey('data') && decoded['data'] is List) {
          vehicleList = decoded['data'] as List;
        }
      } else if (decoded is List) {
        vehicleList = decoded;
      }

      final int nowMs = DateTime.now().millisecondsSinceEpoch;

      // Fix: vehicle_id당 가장 최신 레코드만 남긴다.
      // 상태 API가 limit=120으로 여러 레코드를 반환할 때, 첫 번째로 처리되는 레코드가
      // 오래된 위치를 displayPosition에 고정시켜 수 초간의 마커 지연을 만들었음.
      // 최신 timestamp만 처리하면 displayPosition이 항상 현재 위치로 초기화된다.
      final Map<int, Map<String, dynamic>> latestPerVehicle =
          <int, Map<String, dynamic>>{};
      for (final dynamic raw in vehicleList) {
        if (raw is! Map<String, dynamic>) continue;
        final int vId =
            _parseInt(raw['vehicle_id']) ?? _parseInt(raw['vehicleId']) ?? 0;
        if (vId <= 0) continue;
        final int rawTsMs = _parseInt(raw['time_stamp_ms']) ??
            _parseInt(raw['timeStampMs']) ??
            0;
        final Map<String, dynamic>? existing = latestPerVehicle[vId];
        if (existing == null) {
          latestPerVehicle[vId] = raw;
        } else {
          final int existingTs = _parseInt(existing['time_stamp_ms']) ??
              _parseInt(existing['timeStampMs']) ??
              0;
          if (rawTsMs > existingTs) latestPerVehicle[vId] = raw;
        }
      }
      final List<Map<String, dynamic>> effectiveVehicleList =
          latestPerVehicle.values.toList();

      final Map<int, int> vehicleIdToVehicleInfoId = <int, int>{};
      final Map<int, int> vehicleIdToTimestampMs = <int, int>{};

      for (final dynamic item in effectiveVehicleList) {
        if (item is! Map<String, dynamic>) continue;
        final Map<String, dynamic> v = item;

        final int vehicleId =
            _parseInt(v['vehicle_id']) ?? _parseInt(v['vehicleId']) ?? 0;
        if (vehicleId <= 0) continue;

        final double rawX = _parseDouble(v['pos_x_m']) ??
            _parseDouble(v['position_x']) ??
            _parseDouble(v['positionX']) ??
            0.0;
        final double rawY = _parseDouble(v['pos_y_m']) ??
            _parseDouble(v['position_y']) ??
            _parseDouble(v['positionY']) ??
            0.0;

        final LatLng vehicleLatLng = _convertRawToLatLng(rawX, rawY);
        if (!geo.isValidLatLng(vehicleLatLng.latitude, vehicleLatLng.longitude))
          continue;

        final double heading = geo.normalizeHeadingDegrees(
            _parseDouble(v['heading_deg']) ??
                _parseDouble(v['orientation_heading']) ??
                _parseDouble(v['orientationHeading']) ??
                0.0);

        final VehicleTrackingData tracking =
            _tracked[vehicleId] ?? VehicleTrackingData();
        final LatLng? previousTargetPosition =
            tracking.targetPosition ?? tracking.displayPosition;
        final int previousPacketMs = tracking.lastPacketMs;
        final int previousTelemetryTsMs =
            tracking.vehicleInfo?.timeStampMs ?? 0;

        final int tsMs = _parseInt(v['time_stamp_ms']) ??
            _parseInt(v['timeStampMs']) ??
            _parseInt(v['time_stamp']) ??
            nowMs;
        final bool hasFreshTelemetry =
            tsMs > 0 && tsMs != previousTelemetryTsMs;

        // out-of-order 보호: 이미 표시한 것보다 오래된 timestamp 레코드면 마커가
        // 뒤로 점프하므로 무시한다(외부 시뮬레이터/파이프라인 재정렬로 과거 데이터가
        // 늦게 도착하는 경우). 마지막으로 표시한 시점 이후 데이터만 반영.
        if (tsMs > 0 &&
            previousTelemetryTsMs > 0 &&
            tsMs < previousTelemetryTsMs) {
          continue;
        }

        final double kph = _parseDouble(v['kph']) ??
            _parseDouble(v['velocity_kph']) ??
            _parseDouble(v['velocityKph']) ??
            0.0;
        double mps = _parseDouble(v['mps']) ??
            _parseDouble(v['velocity_mps']) ??
            _parseDouble(v['velocityMps']) ??
            kph / 3.6;

        if (hasFreshTelemetry &&
            mps < _vehiclePredictMinSpeedMps &&
            previousTargetPosition != null &&
            previousPacketMs > 0) {
          final int packetDtMs = max(1, nowMs - previousPacketMs);
          final double packetDtSec = packetDtMs / 1000.0;
          final double traveledMeters = geo.haversineMeters(
            previousTargetPosition.latitude,
            previousTargetPosition.longitude,
            vehicleLatLng.latitude,
            vehicleLatLng.longitude,
          );
          final double inferredMps = traveledMeters / packetDtSec;
          if (inferredMps >= (_vehiclePredictMinSpeedMps * 0.6)) {
            mps = inferredMps;
          }
        }

        if (hasFreshTelemetry) {
          final bool canRetainPreviousSpeed =
              tracking.retainedSpeedMps >= _vehiclePredictMinSpeedMps &&
                  previousPacketMs > 0 &&
                  (nowMs - previousPacketMs) <= _vehicleRetainSpeedMs;
          if (mps < _vehiclePredictMinSpeedMps && canRetainPreviousSpeed) {
            mps = tracking.retainedSpeedMps * 0.92;
          }

          if (mps >= _vehiclePredictMinSpeedMps) {
            tracking.retainedSpeedMps = tracking.retainedSpeedMps <= 0.0
                ? mps
                : (tracking.retainedSpeedMps * 0.6 + mps * 0.4);
          } else {
            tracking.retainedSpeedMps = 0.0;
          }
        } else {
          // 같은 timestamp 반복 (backend 캐시 응답 등) — 속도를 0 으로 만들지 않음
          // Same timestamp repeated (e.g. backend cache response) — keep speed
          // 이전 속도/payload 의 속도 중 큰 값 유지
          if (kph >= 1.0 || mps >= _vehiclePredictMinSpeedMps) {
            // payload 자체에 유효 속도 있음 — 그대로 사용
          } else if (tracking.retainedSpeedMps >= _vehiclePredictMinSpeedMps) {
            mps = tracking.retainedSpeedMps;
          }
        }
        mps = mps.clamp(0.0, 90.0);

        final int navsat = _parseInt(v['navsat']) ?? 4;
        final double posZ = _parseDouble(v['pos_z_m']) ??
            _parseDouble(v['position_z']) ??
            _parseDouble(v['positionZ']) ??
            0.0;

        final int vehicleInfoId = _parseInt(v['id']) ?? 0;

        final VehicleInfo vInfo = VehicleInfo(
          id: vehicleInfoId,
          vehicleId: vehicleId,
          msgId: _parseInt(v['msg_id']) ?? _parseInt(v['msgId']),
          msgSeq: _parseInt(v['msg_seq']) ?? _parseInt(v['msgSeq']),
          msgLength: _parseInt(v['msg_length']) ?? _parseInt(v['msgLength']),
          timeStampMs: tsMs,
          navsat: navsat,
          // payload 의 실제 속도를 항상 사용 (캐시된 동일 timestamp 도 유효한 값 포함)
          // Always use the actual speed from payload — even for repeated timestamps from cache
          velocityKph: max(kph, mps * 3.6),
          velocityMps: mps,
          positionX: vehicleLatLng.latitude,
          positionY: vehicleLatLng.longitude,
          positionZ: posZ,
          orientationHeading: heading,
          accelX: _parseDouble(v['accel_x_mps2']) ?? _parseDouble(v['accelX']),
          accelY: _parseDouble(v['accel_y_mps2']) ?? _parseDouble(v['accelY']),
          accelZ: _parseDouble(v['accel_z_mps2']) ?? _parseDouble(v['accelZ']),
          transmissionGear:
              _parseInt(v['transmission_gear']) ?? _parseInt(v['gear']),
          signalLight: _parseInt(v['signal_light']) ?? _parseInt(v['signal']),
          steerAngle:
              _parseDouble(v['angle_deg']) ?? _parseDouble(v['steer_angle']),
          pedalAccel:
              _parseDouble(v['accel_pct']) ?? _parseDouble(v['pedal_accel']),
          brake: _parseDouble(v['brake_pct']) ?? _parseDouble(v['brake']),
          numberOfObjects: _parseInt(v['number_of_objects']) ?? 0,
        );

        if (hasFreshTelemetry) {
          tracking.lastPacketMs = nowMs;
        }
        tracking.vehicleInfo = vInfo;

        if (!tracking.hasReceivedFirstPosition) {
          // 파이프라인 지연 보정 (시뮬레이터 → DB → HTTP poll 합산 약 800-1200ms).
          // DB에서 읽은 위치(vehicleLatLng)는 tsMs 시점 기준이므로,
          // 현재 시각(nowMs)까지 경과한 만큼 차량 속도 × 방향으로 예측 보정.
          // 이렇게 하면 맵을 열었을 때 마커가 실제 위치 근처에서 시작한다.
          LatLng initialPos = vehicleLatLng;
          // 데이터가 실제로 신선한 경우에만 파이프라인 보정 적용.
          // 시뮬레이터가 정지된 상태에서 오래된 레코드를 hasFreshTelemetry=true로
          // 처리할 때, 잘못된 전방 보정으로 마커가 엉뚱한 위치로 이동하는 것을 방지.
          if (mps >= _vehiclePredictMinSpeedMps &&
              tsMs > 0 &&
              (nowMs - tsMs).abs() <= _vehicleOnlineGraceMs) {
            final int dataAgeMs = (nowMs - tsMs).clamp(0, 2500);
            if (dataAgeMs > 80) {
              final double fwdMeters = (mps * (dataAgeMs / 1000.0))
                  .clamp(0.0, _vehiclePredictMaxDistanceMeters);
              if (fwdMeters > 0.5) {
                initialPos = _offsetLatLngByMeters(
                  origin: vehicleLatLng,
                  distanceMeters: fwdMeters,
                  bearingDegrees: heading,
                );
              }
            }
          }
          tracking.targetPosition = initialPos;
          tracking.displayPosition = initialPos;
          tracking.targetHeading = heading;
          tracking.displayHeading = heading;
          tracking.hasReceivedFirstPosition = true;
          tracking.lastUpdateMs = nowMs;
        } else {
          bool hasMotionUpdate = false;
          final double dist = geo.haversineMeters(
            (tracking.targetPosition ?? vehicleLatLng).latitude,
            (tracking.targetPosition ?? vehicleLatLng).longitude,
            vehicleLatLng.latitude,
            vehicleLatLng.longitude,
          );
          if (dist >= _serverPositionUpdateMinMeters) {
            // 파이프라인 지연 보정: 시뮬레이터 → MQTT → DB → HTTP poll = 약 500-1500ms.
            // DB에서 읽은 위치는 tsMs 기준이므로 nowMs까지 경과한 만큼 속도×방향으로 보정.
            // 이렇게 하면 targetPosition이 항상 "현재" 위치에 가까워져 지연이 사라진다.
            LatLng correctedPos = vehicleLatLng;
            // 파이프라인 지연 보정은 데이터가 실제 신선한 경우에만 적용.
            // hasFreshTelemetry=true여도 tsMs가 오래됐다면 (시뮬레이터 정지 상태)
            // 전방 보정을 적용하면 마커가 멀리 이동했다가 되돌아오는 버그 발생.
            if (hasFreshTelemetry &&
                mps >= _vehiclePredictMinSpeedMps &&
                tsMs > 0 &&
                (nowMs - tsMs).abs() <= _vehicleOnlineGraceMs) {
              // 실측 age 대신 안정적 고정 지연 → 예측 전진량이 일정해져 마커가
              // 폴링 지터로 뒤로 튀지 않음(움직이는 중에만 적용되므로 정지 시엔 영향 없음).
              const int dataAgeMs = _vehiclePredictStableDelayMs;
              if (dataAgeMs > 80) {
                final double fwdMeters = (mps * (dataAgeMs / 1000.0))
                    .clamp(0.0, _vehiclePredictMaxDistanceMeters);
                if (fwdMeters > 0.3) {
                  correctedPos = _offsetLatLngByMeters(
                    origin: vehicleLatLng,
                    distanceMeters: fwdMeters,
                    bearingDegrees: heading,
                  );
                }
              }
            }
            tracking.targetPosition = correctedPos;
            hasMotionUpdate = true;
          }
          final double headingDelta =
              geo.shortestAngleDelta(tracking.targetHeading, heading);
          if (headingDelta.abs() >= 0.5) {
            tracking.targetHeading = geo.normalizeHeadingDegrees(
              tracking.targetHeading + headingDelta * 0.55,
            );
            hasMotionUpdate = true;
          }
          if (hasMotionUpdate) {
            tracking.lastUpdateMs = nowMs;
          }
        }

        _tracked[vehicleId] = tracking;

        if (vehicleInfoId > 0) {
          vehicleIdToVehicleInfoId[vehicleId] = vehicleInfoId;
          vehicleIdToTimestampMs[vehicleId] = tsMs;
        }
      }

      for (final MapEntry<int, int> entry in vehicleIdToVehicleInfoId.entries) {
        final int vehicleId = entry.key;
        final int vehicleInfoId = entry.value;
        final int tsMs = vehicleIdToTimestampMs[vehicleId] ?? 0;
        final int cachedTs = _objectsCacheTimestampMs[vehicleInfoId] ?? -1;
        if (cachedTs == tsMs &&
            _objectsCacheByVehicleInfoId.containsKey(vehicleInfoId)) {
          _tracked[vehicleId]?.objects =
              _objectsCacheByVehicleInfoId[vehicleInfoId] ?? <DetectedObject>[];
        }
      }

      _updateSelectedVehicleSession(nowMs: nowMs);
      _syncVehicleObjectTargets(nowMs: nowMs);
      _pruneExpiredObjectTargets(nowMs: nowMs);
      _rebuildMarkersThrottled();

      _scheduleVehicleObjectsRefresh(
        vehicleIdToVehicleInfoId: Map<int, int>.from(vehicleIdToVehicleInfoId),
        vehicleIdToTimestampMs: Map<int, int>.from(vehicleIdToTimestampMs),
      );
    } catch (e) {
      _consecutiveErrorCount++;
      if (kDebugMode)
        debugPrint(
            '[POLL] Vehicle status error ($e), consecutive: $_consecutiveErrorCount');
    }
  }

  void _scheduleVehicleObjectsRefresh({
    required Map<int, int> vehicleIdToVehicleInfoId,
    required Map<int, int> vehicleIdToTimestampMs,
  }) {
    if (_disposed || !mounted) {
      return;
    }
    if (_vehicleObjectsRefreshInFlight) {
      return;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastVehicleObjectsRefreshMs <
        _vehicleObjectsRefreshMinIntervalMs) {
      return;
    }
    _lastVehicleObjectsRefreshMs = nowMs;
    _vehicleObjectsRefreshInFlight = true;

    unawaited(_refreshVehicleObjects(
      vehicleIdToVehicleInfoId: vehicleIdToVehicleInfoId,
      vehicleIdToTimestampMs: vehicleIdToTimestampMs,
    ).whenComplete(() {
      _vehicleObjectsRefreshInFlight = false;
    }));
  }

  Future<void> _refreshVehicleObjects({
    required Map<int, int> vehicleIdToVehicleInfoId,
    required Map<int, int> vehicleIdToTimestampMs,
  }) async {
    try {
      final List<int> vehicleIdsToFetch = <int>[];
      for (final MapEntry<int, int> entry in vehicleIdToVehicleInfoId.entries) {
        final int vehicleId = entry.key;
        final int vehicleInfoId = entry.value;
        final int tsMs = vehicleIdToTimestampMs[vehicleId] ?? 0;
        final int cachedTs = _objectsCacheTimestampMs[vehicleInfoId] ?? -1;
        final bool needsFetch =
            !_objectsCacheByVehicleInfoId.containsKey(vehicleInfoId) ||
                cachedTs != tsMs;

        if (needsFetch) {
          vehicleIdsToFetch.add(vehicleId);
        } else {
          _tracked[vehicleId]?.objects =
              _objectsCacheByVehicleInfoId[vehicleInfoId] ?? <DetectedObject>[];
        }
      }

      // ── 배치 조회: N대 차량을 1회 요청으로 / single batch request ──
      // 기존엔 차량마다 byVehicleInfo 호출(100대 → 100요청 + CORS preflight)로
      // 브라우저 연결풀(6개)이 포화되어 테이블/차트 요청이 굶주려 타임아웃났음.
      // byMultipleVehicles 로 1요청(필요 시 500개씩 분할)에 처리.
      const int batchCap = 500; // 서버 안전 상한과 동일
      for (int i = 0; i < vehicleIdsToFetch.length; i += batchCap) {
        if (_disposed || !mounted) {
          break;
        }
        final int end = min(i + batchCap, vehicleIdsToFetch.length);
        final List<int> chunk = vehicleIdsToFetch.sublist(i, end);
        final Map<int, List<DetectedObject>> grouped =
            await _fetchDetectedObjectsBatchByVehicleIds(chunk);
        for (final int vehicleId in chunk) {
          final int vehicleInfoId = vehicleIdToVehicleInfoId[vehicleId] ?? 0;
          final int tsMs = vehicleIdToTimestampMs[vehicleId] ?? 0;
          final List<DetectedObject> objects =
              grouped[vehicleId] ?? <DetectedObject>[];
          if (vehicleInfoId > 0) {
            _objectsCacheByVehicleInfoId[vehicleInfoId] = objects;
            _objectsCacheTimestampMs[vehicleInfoId] = tsMs;
          }
          _tracked[vehicleId]?.objects = objects;
        }
      }

      if (_disposed || !mounted) {
        return;
      }

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      _updateSelectedVehicleSession(nowMs: nowMs);
      _syncVehicleObjectTargets(nowMs: nowMs);
      _pruneExpiredObjectTargets(nowMs: nowMs);
      _rebuildMarkersThrottled();
    } catch (_) {}
  }

  Future<void> _fetchInfraStatusFromDb() async {
    try {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final Uri uri = buildApiUri('/api/infra/status');

      final http.Response resp = await http
          .post(
            uri,
            headers: _getAuthHeaders(),
            body: jsonEncode(<String, dynamic>{
              'limit': _infraStatusFetchLimit,
              'offset': 0,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) {
        _consecutiveErrorCount++;
        if (kDebugMode)
          debugPrint('[POLL] Infra status HTTP ${resp.statusCode}');
        return;
      }

      _consecutiveErrorCount = 0;

      final dynamic decoded = jsonDecode(resp.body);

      List<dynamic> infraList = <dynamic>[];

      if (decoded is Map<String, dynamic>) {
        final dynamic body = decoded['body'];
        if (body is Map<String, dynamic>) {
          final dynamic items = body['items'];
          if (items is List) {
            infraList = items;
          }
        } else if (body is List) {
          infraList = body;
        } else if (decoded.containsKey('data') && decoded['data'] is List) {
          infraList = decoded['data'] as List;
        }
      } else if (decoded is List) {
        infraList = decoded;
      }

      final Map<int, Map<String, dynamic>> latestPerInfra =
          <int, Map<String, dynamic>>{};
      for (final dynamic item in infraList) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final Map<String, dynamic> inf = item;
        final int infraId =
            _parseInt(inf['infra_id']) ?? _parseInt(inf['infraId']) ?? 0;
        if (infraId <= 0) {
          continue;
        }

        final int tsMs = _parseInt(inf['time_stamp_ms']) ??
            _parseInt(inf['timeStampMs']) ??
            -1;
        final int rowId = _parseInt(inf['id']) ?? -1;
        final Map<String, dynamic>? existing = latestPerInfra[infraId];
        if (existing == null) {
          latestPerInfra[infraId] = inf;
          continue;
        }

        final int existingTsMs = _parseInt(existing['time_stamp_ms']) ??
            _parseInt(existing['timeStampMs']) ??
            -1;
        final int existingRowId = _parseInt(existing['id']) ?? -1;
        final bool isNewer = tsMs > existingTsMs ||
            (tsMs == existingTsMs && rowId > existingRowId);
        if (isNewer) {
          latestPerInfra[infraId] = inf;
        }
      }

      final Map<int, _InfraSnapshot> nextInfraSnapshots =
          <int, _InfraSnapshot>{};
      for (final MapEntry<int, Map<String, dynamic>> entry
          in latestPerInfra.entries) {
        final Map<String, dynamic> raw = entry.value;
        final int infraId = entry.key;
        final int tsMs = _parseInt(raw['time_stamp_ms']) ??
            _parseInt(raw['timeStampMs']) ??
            0;
        if (!_isInfraStatusFresh(tsMs, nowMs: nowMs)) {
          continue;
        }
        final int infraInfoId =
            _parseInt(raw['id']) ?? _parseInt(raw['infra_info_id']) ?? 0;
        final int objectCount = _parseInt(raw['number_of_objects']) ?? 0;
        final LatLng infraPos = _resolveInfraPosition(infraId);

        nextInfraSnapshots[infraId] = _InfraSnapshot(
          info: InfraInfo(
            id: infraInfoId,
            infraId: infraId,
            timeStampMs: tsMs,
            numberOfObjects: objectCount,
          ),
          position: infraPos,
          objectCount: objectCount,
        );
      }

      Map<String, dynamic>? selectedInfraRaw;
      if (_selectedInfraId != null && _selectedInfraId! > 0) {
        final Map<String, dynamic>? candidate =
            latestPerInfra[_selectedInfraId!];
        final int candidateTsMs = _parseInt(candidate?['time_stamp_ms']) ??
            _parseInt(candidate?['timeStampMs']) ??
            0;
        if (_isInfraStatusFresh(candidateTsMs, nowMs: nowMs)) {
          selectedInfraRaw = candidate;
        }
      }

      if (selectedInfraRaw == null &&
          (_selectedInfraId == null || _selectedInfraId! <= 0) &&
          latestPerInfra.isNotEmpty) {
        int newestTsMs = -1;
        int newestRowId = -1;
        for (final Map<String, dynamic> inf in latestPerInfra.values) {
          final int tsMs = _parseInt(inf['time_stamp_ms']) ??
              _parseInt(inf['timeStampMs']) ??
              -1;
          if (!_isInfraStatusFresh(tsMs, nowMs: nowMs)) {
            continue;
          }
          final int rowId = _parseInt(inf['id']) ?? -1;
          final bool isNewer =
              tsMs > newestTsMs || (tsMs == newestTsMs && rowId > newestRowId);
          if (selectedInfraRaw == null || isNewer) {
            selectedInfraRaw = inf;
            newestTsMs = tsMs;
            newestRowId = rowId;
          }
        }
      }

      _infraSnapshots = nextInfraSnapshots;

      if (selectedInfraRaw == null) {
        if ((_selectedInfraId ?? 0) > 0) {
          final _InfraSnapshot? selectedSnapshot =
              _infraSnapshots[_selectedInfraId!];
          _infraInfo = selectedSnapshot?.info;
          _infraMarkerPos = selectedSnapshot?.position ??
              _resolveInfraPosition(_selectedInfraId!);
        } else {
          _infraInfo = null;
          _infraMarkerPos = null;
        }
        _infraObjects = <DetectedObject>[];
        _syncInfraObjectTargets(nowMs: nowMs);
        _pruneExpiredObjectTargets(nowMs: nowMs);
        if (_entityType == MapEntityType.infra) {
          _buildInfraMarkers();
          _maybeFollowSelectedInfra();
        } else {
          _rebuildMarkersThrottled();
        }
        return;
      }

      final int infraId = _parseInt(selectedInfraRaw['infra_id']) ??
          _parseInt(selectedInfraRaw['infraId']) ??
          0;
      final int tsMs = _parseInt(selectedInfraRaw['time_stamp_ms']) ??
          _parseInt(selectedInfraRaw['timeStampMs']) ??
          0;
      final int infraInfoId = _parseInt(selectedInfraRaw['id']) ??
          _parseInt(selectedInfraRaw['infra_info_id']) ??
          0;

      final int declaredObjectCount =
          _parseInt(selectedInfraRaw['number_of_objects']) ?? 0;
      final int? selectedMsgSeq = _parseInt(selectedInfraRaw['msg_seq']);

      List<DetectedObject> objects = _parseObjectsFromJson(
          selectedInfraRaw['objects'] ??
              selectedInfraRaw['detected_objects'] ??
              selectedInfraRaw['detectedObjects']);
      objects = _keepLatestObjectBatch(
        objects,
        expectedCount: declaredObjectCount > 0 ? declaredObjectCount : null,
        preferredMsgSeq: selectedMsgSeq,
      );

      if (objects.isEmpty && infraInfoId > 0 && declaredObjectCount > 0) {
        objects = await _fetchDetectedObjectsByInfraInfoId(infraInfoId);
        objects = _keepLatestObjectBatch(
          objects,
          expectedCount: declaredObjectCount,
          preferredMsgSeq: selectedMsgSeq,
        );
      }

      final LatLng infraPos = _resolveInfraPosition(infraId);
      final InfraInfo selectedInfo = InfraInfo(
        id: infraInfoId,
        infraId: infraId,
        timeStampMs: tsMs,
        numberOfObjects:
            _parseInt(selectedInfraRaw['number_of_objects']) ?? objects.length,
      );
      _infraSnapshots[infraId] = _InfraSnapshot(
        info: selectedInfo,
        position: infraPos,
        objectCount: max(objects.length, declaredObjectCount),
      );

      _selectedInfraId = infraId;
      _infraInfo = selectedInfo;
      _infraObjects = objects;
      _infraMarkerPos = infraPos;

      _syncInfraObjectTargets(nowMs: nowMs);
      _pruneExpiredObjectTargets(nowMs: nowMs);

      if (_entityType == MapEntityType.infra) {
        _buildInfraMarkers();
        _maybeFollowSelectedInfra();
      } else {
        _rebuildMarkersThrottled();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[POLL] Infra status error: $e');
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Map<String, dynamic>? _registryInfraById(int infraId) {
    for (final Map<String, dynamic> reg in _offlineInfras) {
      final int rid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (rid == infraId) {
        return reg;
      }
    }
    return null;
  }

  LatLng _fallbackInfraPosition(int infraId) {
    final int safeInfraId = infraId <= 0 ? 1 : infraId;
    final double distanceMeters = 25.0 + ((safeInfraId % 4) * 18.0);
    final double bearingDegrees = ((safeInfraId * 67) % 360).toDouble();
    return _offsetLatLngByMeters(
      origin: const LatLng(kiapiInfraLat, kiapiInfraLon),
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
    );
  }

  // 오프라인/stale 차량이 station 마커 위에 겹치면 20m 옆으로 이동 (vehicleId 기반 방향)
  LatLng _avoidStationOverlap(LatLng pos, int vehicleId) {
    for (final KiapiWaypointData wp in kiapiRoadWaypoints) {
      final double dist = geo.haversineMeters(
          pos.latitude, pos.longitude, wp.lat, wp.lon);
      if (dist < 25.0) {
        final double bearing = (vehicleId % 8) * 45.0;
        return _offsetLatLngByMeters(
            origin: pos, distanceMeters: 20.0, bearingDegrees: bearing);
      }
    }
    return pos;
  }

  // 모든 인프라 마커가 보이도록 카메라 조정
  void _fitAllInfraMarkersInView() {
    if (_mapController == null) return;
    final List<LatLng> positions = <LatLng>[];
    for (final _InfraSnapshot s in _infraSnapshots.values) {
      positions.add(s.position);
    }
    for (final Map<String, dynamic> reg in _offlineInfras) {
      final int iid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (iid > 0 && !_infraSnapshots.containsKey(iid)) {
        positions.add(_resolveInfraPosition(iid));
      }
    }
    if (positions.isEmpty) {
      _moveCameraTo(const LatLng(kiapiCenterLat, kiapiCenterLon), zoom: 15.5);
      return;
    }
    if (positions.length == 1) {
      _moveCameraTo(positions.first, zoom: 16.9);
      return;
    }
    double minLat = positions.first.latitude, maxLat = positions.first.latitude;
    double minLon = positions.first.longitude, maxLon = positions.first.longitude;
    for (final LatLng p in positions) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.003, minLon - 0.003),
          northeast: LatLng(maxLat + 0.003, maxLon + 0.003),
        ),
        60,
      ),
    );
  }

  /// 지도에서 현재 추적 중인 차량의 표시 위치를 반환.
  /// 인프라 마커와 감지 객체를 차량 근방에 배치하는 데 사용된다.
  LatLng? _nearestTrackedVehiclePos() {
    for (final VehicleTrackingData t in _tracked.values) {
      final LatLng? pos = t.displayPosition ?? t.targetPosition;
      if (pos != null && geo.isValidLatLng(pos.latitude, pos.longitude)) {
        return pos;
      }
    }
    return null;
  }

  /// 인프라 위치 결정: device_registry 좌표 사용 (RSU는 고정 설치물)
  LatLng _resolveInfraPosition(int infraId) {
    // device_registry 등록 위치 사용
    final Map<String, dynamic>? regEntry = _registryInfraById(infraId);
    if (regEntry != null) {
      final double? lat =
          double.tryParse(regEntry['location_lat']?.toString() ?? '');
      final double? lng =
          double.tryParse(regEntry['location_lng']?.toString() ?? '');
      if (lat != null && lng != null && geo.isValidLatLng(lat, lng)) {
        return LatLng(lat, lng);
      }
    }
    return _fallbackInfraPosition(infraId);
  }

  String _infraName(int infraId) {
    final Map<String, dynamic>? regEntry = _registryInfraById(infraId);
    final String name = regEntry?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty && name != '-') {
      return name;
    }
    return '인프라 $infraId';
  }

  // ignore: unused_element
  String _infraSnippet(int infraId) {
    final Map<String, dynamic>? regEntry = _registryInfraById(infraId);
    final String location = regEntry?['location_address']?.toString().trim() ??
        regEntry?['home_station']?.toString().trim() ??
        '';
    if (location.isNotEmpty && location != '-') {
      return location;
    }
    return '위치 미등록';
  }

  Set<int> _allKnownInfraIds() {
    final Set<int> ids = _infraSnapshots.keys.toSet();
    for (final Map<String, dynamic> reg in _offlineInfras) {
      final int id = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (id > 0) {
        ids.add(id);
      }
    }
    if (_selectedInfraId != null && _selectedInfraId! > 0) {
      ids.add(_selectedInfraId!);
    }
    return ids;
  }

  String _infraLocationLabel(int infraId) {
    final Map<String, dynamic>? regEntry = _registryInfraById(infraId);
    final String location = regEntry?['location_address']?.toString().trim() ??
        regEntry?['home_station']?.toString().trim() ??
        '';
    if (location.isNotEmpty && location != '-') {
      return location;
    }
    return '위치 정보 없음';
  }

  LatLng _convertRawToLatLng(double rawX, double rawY) {
    if (geo.isValidUtmCoordinate(rawX, rawY)) {
      final geo.Wgs84Coordinate wgs = geo.convertUtmZone52NToWgs84(
          eastingMeters: rawX, northingMeters: rawY);
      return LatLng(wgs.latitudeDegrees, wgs.longitudeDegrees);
    }
    if (geo.isValidLatLng(rawX, rawY)) return LatLng(rawX, rawY);
    if (geo.isValidLatLng(rawY, rawX)) return LatLng(rawY, rawX);
    return LatLng(rawX, rawY);
  }

  List<DetectedObject> _parseObjectsFromJson(dynamic objList) {
    final List<DetectedObject> result = <DetectedObject>[];
    if (objList is! List) return result;

    for (int i = 0; i < objList.length; i++) {
      final dynamic o = objList[i];
      if (o is! Map<String, dynamic>) continue;

      final double? rawX = _parseDouble(o['position_x']) ??
          _parseDouble(o['positionX']) ??
          _parseDouble(o['pos_x']);
      final double? rawY = _parseDouble(o['position_y']) ??
          _parseDouble(o['positionY']) ??
          _parseDouble(o['pos_y']);
      if (rawX == null || rawY == null) continue;

      final int oType = _parseInt(o['object_type']) ??
          _parseInt(o['objectType']) ??
          _parseInt(o['type']) ??
          0;

      result.add(DetectedObject(
        detectedObjectId: _parseInt(o['id']) ?? i,
        sourceKind: o['source_kind']?.toString(),
        vehicleInfoId: _parseInt(o['vehicle_info_id']),
        infraInfoId: _parseInt(o['infra_info_id']),
        objectId: _parseInt(o['object_id']) ?? _parseInt(o['objectId']) ?? i,
        msgId: _parseInt(o['msg_id']),
        msgSeq: _parseInt(o['msg_seq']),
        age: _parseInt(o['age']) ?? 0,
        score: _parseDouble(o['score']) ?? 0.0,
        objectType: oType,
        width: _parseDouble(o['width']) ?? 0.0,
        depth: _parseDouble(o['depth']) ?? 0.0,
        height: _parseDouble(o['height']) ?? 0.0,
        positionX: rawX,
        positionY: rawY,
        positionZ: _parseDouble(o['position_z']) ??
            _parseDouble(o['positionZ']) ??
            0.0,
        orientationHeading: _parseDouble(o['orientation_heading']) ??
            _parseDouble(o['orientationHeading']) ??
            _parseDouble(o['heading']) ??
            0.0,
      ));
    }
    return result;
  }

  List<DetectedObject> _extractLatestContiguousBatchByMsgSeq(
    List<DetectedObject> objects, {
    int? preferredMsgSeq,
  }) {
    if (objects.isEmpty) {
      return objects;
    }

    int? targetMsgSeq = preferredMsgSeq;
    if (targetMsgSeq == null) {
      for (int index = objects.length - 1; index >= 0; index--) {
        final int? seq = objects[index].msgSeq;
        if (seq != null) {
          targetMsgSeq = seq;
          break;
        }
      }
    }
    if (targetMsgSeq == null) {
      return objects;
    }

    final List<DetectedObject> reversedBatch = <DetectedObject>[];
    bool started = false;
    for (int index = objects.length - 1; index >= 0; index--) {
      final DetectedObject obj = objects[index];
      if (obj.msgSeq == targetMsgSeq) {
        reversedBatch.add(obj);
        started = true;
      } else if (started) {
        break;
      }
    }

    if (reversedBatch.isEmpty) {
      return objects;
    }
    return reversedBatch.reversed.toList();
  }

  List<DetectedObject> _keepLatestObjectBatch(
    List<DetectedObject> objects, {
    int? expectedCount,
    int? preferredMsgSeq,
  }) {
    if (objects.isEmpty) {
      return objects;
    }

    List<DetectedObject> batch = _extractLatestContiguousBatchByMsgSeq(
      objects,
      preferredMsgSeq: preferredMsgSeq,
    );

    final int? safeExpected =
        expectedCount != null && expectedCount > 0 ? expectedCount : null;
    if (safeExpected != null && batch.length > safeExpected) {
      batch = batch.sublist(batch.length - safeExpected);
    }

    return batch;
  }

  String _vehicleObjectTrackingKey(
      int vehicleId, DetectedObject object, int fallbackIndex) {
    final int identity =
        object.objectId ?? object.detectedObjectId ?? fallbackIndex;
    return 'v:$vehicleId:$identity';
  }

  String _infraObjectTrackingKey(DetectedObject object, int fallbackIndex) {
    final int identity =
        object.objectId ?? object.detectedObjectId ?? fallbackIndex;
    return 'i:$identity';
  }

  void _upsertTrackedObjectTarget({
    required String trackingKey,
    required LatLng targetPosition,
    required double targetHeading,
    required int nowMs,
  }) {
    final ObjectTrackingData tracking =
        _trackedObjects[trackingKey] ?? ObjectTrackingData();
    tracking.targetPosition = targetPosition;
    tracking.targetHeading = geo.normalizeHeadingDegrees(targetHeading);
    tracking.lastSeenMs = nowMs;

    if (tracking.displayPosition == null) {
      tracking.displayPosition = targetPosition;
      tracking.displayHeading = tracking.targetHeading;
    }

    _trackedObjects[trackingKey] = tracking;
  }

  void _syncVehicleObjectTargets({required int nowMs}) {
    for (final MapEntry<int, VehicleTrackingData> entry in _tracked.entries) {
      final int vehicleId = entry.key;
      // Fix: 객체 좌표 해석 시 displayPosition(스무딩된 지연 위치) 대신
      // targetPosition(DB에서 수신한 실제 위치)을 부모 기준점으로 사용.
      // 상대좌표 객체의 경우 displayPosition을 기준으로 하면 차량 위치가 따라잡기
      // 전에 객체 마커가 틀린 위치에 나타나는 오프셋 오류가 발생함.
      final LatLng? parentPosition =
          entry.value.targetPosition ?? entry.value.displayPosition;
      if (parentPosition == null) {
        continue;
      }
      final List<DetectedObject> objects = entry.value.objects;
      for (int objectIndex = 0; objectIndex < objects.length; objectIndex++) {
        final DetectedObject object = objects[objectIndex];
        final LatLng? resolvedPosition = _resolveObjectPositionFromRaw(
          parentPosition: parentPosition,
          rawX: object.positionX,
          rawY: object.positionY,
        );
        if (resolvedPosition == null) {
          continue;
        }
        final String key =
            _vehicleObjectTrackingKey(vehicleId, object, objectIndex);
        _upsertTrackedObjectTarget(
          trackingKey: key,
          targetPosition: resolvedPosition,
          targetHeading: object.orientationHeading ?? 0.0,
          nowMs: nowMs,
        );
      }
    }
  }

  void _syncInfraObjectTargets({required int nowMs}) {
    // 추적 중인 차량이 있으면 차량의 현재 표시 위치를 기준점으로 사용.
    // 이렇게 하면 인프라 감지 객체들이 항상 차량 근방에 그려진다.
    final LatLng? vehiclePos = _nearestTrackedVehiclePos();
    final LatLng parentPosition = vehiclePos ??
        _infraMarkerPos ??
        const LatLng(kiapiInfraLat, kiapiInfraLon);
    for (int objectIndex = 0;
        objectIndex < _infraObjects.length;
        objectIndex++) {
      final DetectedObject object = _infraObjects[objectIndex];
      final LatLng? resolvedPosition = _resolveObjectPositionFromRaw(
        parentPosition: parentPosition,
        rawX: object.positionX,
        rawY: object.positionY,
      );
      if (resolvedPosition == null) {
        continue;
      }
      final String key = _infraObjectTrackingKey(object, objectIndex);
      _upsertTrackedObjectTarget(
        trackingKey: key,
        targetPosition: resolvedPosition,
        targetHeading: object.orientationHeading ?? 0.0,
        nowMs: nowMs,
      );
    }
  }

  void _pruneExpiredObjectTargets({required int nowMs}) {
    _trackedObjects.removeWhere((String _, ObjectTrackingData tracking) =>
        nowMs - tracking.lastSeenMs > _objectTrackingExpiryMs);
  }

  LatLng _resolveVehiclePredictedTarget({
    required VehicleTrackingData tracking,
    required int nowMs,
  }) {
    final LatLng? baseTarget = tracking.targetPosition;
    if (baseTarget == null) {
      return const LatLng(kiapiCenterLat, kiapiCenterLon);
    }
    if (tracking.lastPacketMs <= 0) {
      return baseTarget;
    }
    if ((nowMs - tracking.lastPacketMs) > _vehiclePredictFreshPacketMs) {
      return baseTarget;
    }

    double speedMps = (tracking.vehicleInfo?.velocityMps ?? 0.0).abs();
    if (speedMps < _vehiclePredictMinSpeedMps &&
        tracking.retainedSpeedMps >= _vehiclePredictMinSpeedMps &&
        (nowMs - tracking.lastPacketMs) <= _vehicleRetainSpeedMs) {
      speedMps = tracking.retainedSpeedMps * 0.9;
    }
    if (speedMps < _vehiclePredictMinSpeedMps) {
      return baseTarget;
    }

    final int startMs = tracking.lastPacketMs > 0
        ? tracking.lastPacketMs
        : tracking.lastUpdateMs;
    final int elapsedMs = nowMs - startMs;
    if (elapsedMs <= _vehiclePredictStartAfterMs) {
      return baseTarget;
    }
    final int clampedElapsedMs = elapsedMs.clamp(0, _vehiclePredictMaxAgeMs);

    final double predictionSeconds =
        (clampedElapsedMs / 1000.0).clamp(0.0, _vehiclePredictMaxSeconds);
    final double predictionDistanceMeters = (speedMps * predictionSeconds)
        .clamp(0.0, _vehiclePredictMaxDistanceMeters);

    if (predictionDistanceMeters <= 0.05) {
      return baseTarget;
    }

    return _offsetLatLngByMeters(
      origin: baseTarget,
      distanceMeters: predictionDistanceMeters,
      bearingDegrees: tracking.targetHeading,
    );
  }

  void _startInterpolationTimer() {
    _interpTimer?.cancel();
    _lastInterpStepMs = 0;
    _interpTimer = Timer.periodic(
      const Duration(milliseconds: _interpIntervalMs),
      (_) => _interpolateStep(),
    );
  }

  void _interpolateStep() {
    if (_disposed || !mounted || !_realtimeEnabled) return;
    // ★ 2026-06-11: 인프라 뷰에서도 차량이 움직이도록 — 차량/객체 둘 다 없을 때만 스킵.
    //   (이전: 인프라 모드는 _trackedObjects 비면 무조건 return → 차량 정지 버그)
    if (_tracked.isEmpty && _trackedObjects.isEmpty) {
      return;
    }

    bool anyChanged = false;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int previousInterpMs = _lastInterpStepMs;
    _lastInterpStepMs = nowMs;
    final double interpDeltaSeconds = previousInterpMs > 0
        ? ((nowMs - previousInterpMs) / 1000.0).clamp(0.010, 0.080)
        : (_interpIntervalMs / 1000.0);

    // 차량 이동 보간은 두 모드(차량/인프라) 모두에서 수행 → 인프라 뷰에서도 차량이 달림
    if (_tracked.isNotEmpty) {
      for (final MapEntry<int, VehicleTrackingData> entry in _tracked.entries) {
        final int vid = entry.key;
        final VehicleTrackingData tracking = entry.value;
        if (tracking.targetPosition == null ||
            tracking.displayPosition == null) {
          continue;
        }
        if (!_isVehicleOnline(vid, nowMs: nowMs)) {
          tracking.retainedSpeedMps = 0.0;
          final LatLng? targetPos = tracking.targetPosition;
          if (targetPos != null && tracking.displayPosition != targetPos) {
            tracking.displayPosition = targetPos;
            anyChanged = true;
          }
          continue;
        }

        final LatLng current = tracking.displayPosition!;
        double speedMps = (tracking.vehicleInfo?.velocityMps ?? 0.0).abs();
        if (speedMps < _vehiclePredictMinSpeedMps &&
            tracking.retainedSpeedMps >= _vehiclePredictMinSpeedMps &&
            (nowMs - tracking.lastPacketMs) <= _vehicleRetainSpeedMs) {
          speedMps = tracking.retainedSpeedMps;
        }

        // 브로커 정지 상태 (속도=0, 유지 속도=0) → 즉시 targetPosition으로 스냅.
        // _vehicleMinCatchupSpeedMps로 천천히 이동하면 시뮬레이터 정지 후
        // 수십 초간 마커가 계속 움직이는 버그 발생.
        if (speedMps < _vehiclePredictMinSpeedMps &&
            tracking.retainedSpeedMps < _vehiclePredictMinSpeedMps) {
          final LatLng stoppedTarget = tracking.targetPosition!;
          bool changed = false;
          if (tracking.displayPosition != stoppedTarget) {
            tracking.displayPosition = stoppedTarget;
            changed = true;
          }
          final double headDeltaStopped = geo.shortestAngleDelta(
              tracking.displayHeading, tracking.targetHeading);
          if (headDeltaStopped.abs() >= _convergenceHeadingDeg) {
            tracking.displayHeading = tracking.targetHeading;
            changed = true;
          }
          if (changed) anyChanged = true;
          continue;
        }

        LatLng target = _resolveVehiclePredictedTarget(
          tracking: tracking,
          nowMs: nowMs,
        );

        if (speedMps >= _vehiclePredictMinSpeedMps) {
          final double targetDistance = geo.haversineMeters(
            current.latitude,
            current.longitude,
            target.latitude,
            target.longitude,
          );
          if (targetDistance > 0.05 &&
              targetDistance <= _vehicleRollbackGuardMeters) {
            final double bearingToTarget = geo.bearingBetween(
              current.latitude,
              current.longitude,
              target.latitude,
              target.longitude,
            );
            final double headingDeltaToTarget = geo
                .shortestAngleDelta(tracking.displayHeading, bearingToTarget)
                .abs();
            if (headingDeltaToTarget > _vehicleRollbackMaxHeadingDeltaDeg) {
              target = _offsetLatLngByMeters(
                origin: current,
                distanceMeters:
                    min(_vehicleRollbackClampMeters, targetDistance * 0.4),
                bearingDegrees: tracking.displayHeading,
              );
            }
          }
        }

        final double latDiff = (target.latitude - current.latitude).abs();
        final double lonDiff = (target.longitude - current.longitude).abs();
        final double headDelta = geo.shortestAngleDelta(
            tracking.displayHeading, tracking.targetHeading);

        final bool posConverged =
            latDiff < _convergenceThreshold && lonDiff < _convergenceThreshold;
        final bool headConverged = headDelta.abs() < _convergenceHeadingDeg;

        if (posConverged && headConverged) continue;

        final double dist = geo.haversineMeters(
          current.latitude,
          current.longitude,
          target.latitude,
          target.longitude,
        );

        if (dist > _teleportDistM) {
          tracking.displayPosition = target;
          tracking.displayHeading = tracking.targetHeading;
          anyChanged = true;
          continue;
        }

        if (dist > 0.04) {
          final double followSpeedMps = max(
            speedMps * _vehicleFollowSpeedGain,
            _vehicleMinCatchupSpeedMps,
          );
          final double stepMeters = (followSpeedMps * interpDeltaSeconds)
              .clamp(_vehicleMinMoveStepMeters, _vehicleMaxMoveStepMeters);
          if (dist <= stepMeters) {
            tracking.displayPosition = target;
          } else {
            final double bearingToTarget = geo.bearingBetween(
              current.latitude,
              current.longitude,
              target.latitude,
              target.longitude,
            );
            tracking.displayPosition = _offsetLatLngByMeters(
              origin: current,
              distanceMeters: stepMeters,
              bearingDegrees: bearingToTarget,
            );
          }
          anyChanged = true;
        }

        if (!headConverged) {
          final double maxTurnDeg =
              _vehicleMaxTurnRateDegPerSec * interpDeltaSeconds;
          if (headDelta.abs() <= maxTurnDeg) {
            tracking.displayHeading = tracking.targetHeading;
          } else {
            tracking.displayHeading = geo.normalizeHeadingDegrees(
              tracking.displayHeading +
                  (headDelta.isNegative ? -maxTurnDeg : maxTurnDeg),
            );
          }
          anyChanged = true;
        }
      }
    }

    for (final MapEntry<String, ObjectTrackingData> entry
        in _trackedObjects.entries) {
      final bool isVehicleObject = entry.key.startsWith('v:');
      final bool isInfraObject = entry.key.startsWith('i:');
      if (_entityType == MapEntityType.vehicle && !isVehicleObject) {
        continue;
      }
      if (_entityType == MapEntityType.infra && !isInfraObject) {
        continue;
      }

      final ObjectTrackingData tracking = entry.value;
      if (tracking.targetPosition == null || tracking.displayPosition == null) {
        continue;
      }

      final LatLng target = tracking.targetPosition!;
      final LatLng current = tracking.displayPosition!;

      final double latDiff = (target.latitude - current.latitude).abs();
      final double lonDiff = (target.longitude - current.longitude).abs();
      final double headDelta = geo.shortestAngleDelta(
          tracking.displayHeading, tracking.targetHeading);

      final bool posConverged = latDiff < _objectConvergenceThreshold &&
          lonDiff < _objectConvergenceThreshold;
      final bool headConverged = headDelta.abs() < _objectConvergenceHeadingDeg;
      if (posConverged && headConverged) {
        continue;
      }

      final double dist = geo.haversineMeters(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );

      if (dist > _objectTeleportDistM) {
        tracking.displayPosition = target;
        tracking.displayHeading = tracking.targetHeading;
        anyChanged = true;
        continue;
      }

      if (dist < 0.35) {
        tracking.displayPosition = target;
        tracking.displayHeading = tracking.targetHeading;
        anyChanged = true;
        continue;
      }

      final double factor = dist > 120.0
          ? 0.08
          : dist > 50.0
              ? 0.10
              : dist > 15.0
                  ? 0.14
                  : _objectPosLerpFactor;
      tracking.displayPosition = LatLng(
        current.latitude + (target.latitude - current.latitude) * factor,
        current.longitude + (target.longitude - current.longitude) * factor,
      );
      tracking.displayHeading = geo.normalizeHeadingDegrees(
        tracking.displayHeading + headDelta * _objectHeadLerpFactor,
      );
      anyChanged = true;
    }

    if (anyChanged) {
      if (_entityType == MapEntityType.vehicle) {
        _rebuildMarkersThrottled();
        _maybeFollowSelectedVehicle();
        // Flutter overlay 도 같이 갱신 — ValueNotifier fire 만으로 충분
        // 같은 카메라 값을 다시 할당하면 ValueNotifier 가 발화 → overlay rebuild
        if (_useVehicleOverlay) {
          final OverlayCameraSnapshot s = _overlayCamera.value;
          _overlayCamera.value = OverlayCameraSnapshot(
            target: s.target,
            zoom: s.zoom,
            bearing: s.bearing,
            containerSize: s.containerSize,
            padding: s.padding,
          );
        }
      } else {
        // ★ 인프라 뷰: 차량은 overlay 로 부드럽게 이동(깜빡임 없음) → _overlayCamera fire.
        if (_useVehicleOverlay) {
          final OverlayCameraSnapshot s = _overlayCamera.value;
          _overlayCamera.value = OverlayCameraSnapshot(
            target: s.target,
            zoom: s.zoom,
            bearing: s.bearing,
            containerSize: s.containerSize,
            padding: s.padding,
          );
        }
        // detected object 가 있을 때만 plugin marker 재생성(throttle). 객체 없으면
        // infra 마커는 정적이므로 재생성 불필요 → 깜빡임 완전 제거.
        if (_trackedObjects.isNotEmpty) {
          final int nowThrottle = DateTime.now().millisecondsSinceEpoch;
          if (nowThrottle - _lastInfraInterpRebuildMs >= 80) {
            _lastInfraInterpRebuildMs = nowThrottle;
            _buildInfraMarkers();
          }
        }
        _maybeFollowSelectedInfra();
      }
    }
  }

  // 인프라 뷰 차량 이동 보간 시 마커 재생성 throttle 타임스탬프
  int _lastInfraInterpRebuildMs = 0;

  void _forceRebuildMarkers() {
    _lastMarkerRebuildMs = 0;
    _initialMarkersBuilt = false;
    _rebuildMarkersThrottled();
    _maybeFollowSelectedVehicle();
  }

  void _rebuildStaticMarkers() {
    final Set<Marker> staticMarkers = <Marker>{};

    for (int i = 0; i < kiapiRoadWaypoints.length; i++) {
      final KiapiWaypointData wp = kiapiRoadWaypoints[i];

      staticMarkers.add(Marker(
        markerId: MarkerId('station_$i'),
        position: LatLng(wp.lat, wp.lon),
        icon: i == _selectedStationIdx
            ? _stationSelectedIconFor(i)
            : _stationIconFor(i),
        anchor: const Offset(0.5, 0.95),
        zIndex: 300.0,
        infoWindow: InfoWindow.noText,
        onTap: () => _selectStation(i),
      ));
    }

    _staticMarkers = staticMarkers;
    _staticMarkersBuilt = true;
  }

  void _rebuildMarkersThrottled() {
    if (_disposed || !mounted || !_mapReady) return;
    if (_entityType != MapEntityType.vehicle) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_initialMarkersBuilt &&
        now - _lastMarkerRebuildMs < _markerRebuildThrottleMs) {
      return;
    }
    _lastMarkerRebuildMs = now;

    final Set<Marker> newMarkers = <Marker>{};

    final BitmapDescriptor offlineIcon = _vehicleIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    final BitmapDescriptor selectedOfflineIcon = _vehicleSelectedIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    // ★ Flutter overlay 가 활성화되면 라이브 차량 마커는 overlay 가 그림.
    //   플러그인 마커는 건너뛰고 detected_object 만 처리 (객체 토글에 따라).
    //   이렇게 하면 plugin <img> reload flicker 가 완전히 사라짐 + zoom 시 크기
    //   변화 안 함 (Flutter widget 은 zoom 과 무관하게 고정 크기).
    // When overlay is on, plugin vehicle markers are skipped entirely.
    // Only detected object markers remain on the plugin layer (when enabled).
    final bool skipPluginVehicleMarkers = _useVehicleOverlay;

    for (final MapEntry<int, VehicleTrackingData> entry in _tracked.entries) {
      final int vid = entry.key;
      final bool isLive = _isVehicleOnline(vid, nowMs: now);
      if (!isLive) continue;
      final VehicleTrackingData t = entry.value;
      final LatLng? pos = t.displayPosition ?? t.targetPosition;
      if (pos == null) continue;
      if (!geo.isValidLatLng(pos.latitude, pos.longitude)) continue;

      final bool isSel = vid == _selectedVehicleId;
      _markerSeq++;
      final double heading = geo.normalizeHeadingDegrees(t.displayHeading);
      final double speedKph =
          (t.vehicleInfo?.velocityKph ?? (t.retainedSpeedMps * 3.6)).abs();
      final bool isMoving =
          speedKph >= 1.0 || t.retainedSpeedMps >= _vehiclePredictMinSpeedMps;
      final int markerSizePx = _liveVehicleMarkerSizePx(moving: isMoving);

      // Hysteresis: heading 이 30° 이상 변할 때만 icon 교체 → 깜빡임 방지
      // Apply hysteresis: switch icon only when heading changed by >= 30°
      final double stableHeading = _stableHeadingForVehicle(vid, heading);

      // ── STABLE ICON RESOLUTION (마커 깜빡임 핵심 해결책) ──
      // google_maps_flutter_web 는 BitmapDescriptor 참조가 바뀔 때마다 <img> 를 다시 로드 →
      // 빈 프레임 → flicker. 따라서 EXACT match 캐시 hit 이 들어올 때까지 절대 icon 을 바꾸지 않음.
      // The web plugin reloads <img> on icon reference change → empty frame → FLICKER.
      // So: NEVER swap icon until EXACT cache match arrives. Hold stable reference per vehicle.
      final int bucketDeg = _carBucket(stableHeading);
      final String wantKey = '${bucketDeg}_${markerSizePx}_${isSel ? 1 : 0}';
      final BitmapDescriptor icon = _resolveStableVehicleIcon(
        vid: vid,
        bucketDeg: bucketDeg,
        sizePx: markerSizePx,
        selected: isSel,
        wantKey: wantKey,
      );

      // ★ Flutter overlay 활성화 시 플러그인 vehicle 마커 완전 스킵
      // → Web <img> reload flicker 사라짐 + 줌 시 마커 크기 불변
      // Detected object 마커는 아래 루프에서 계속 처리 (overlay 가 그리지 않음)
      // When overlay is on, skip plugin vehicle marker entirely (no flash, no scale-with-zoom)
      if (!skipPluginVehicleMarkers) {
        // ── Reuse Marker via copyWith when only position changed (icon ref stable) ──
        final Marker? prev = _lastVehicleMarker[vid];
        final bool? lastSel = _lastVehicleMarkerSelected[vid];
        Marker resolvedMarker;
        if (prev != null && identical(prev.icon, icon) && lastSel == isSel) {
          resolvedMarker = prev.copyWith(positionParam: pos);
        } else {
          resolvedMarker = Marker(
            markerId: MarkerId('vehicle_$vid'),
            position: pos,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            rotation: 0,
            flat: true,
            zIndex: isSel ? 1000.0 : 900.0,
            infoWindow: InfoWindow(
              title: _vehicleName(vid),
              snippet: _vehicleLocationLabel(vid),
            ),
            onTap: () => _selectVehicle(
              vid,
              focusPosition: pos,
              followLive: true,
            ),
          );
        }
        final Marker freshMarker = resolvedMarker;
        newMarkers.add(freshMarker);
        _lastVehicleMarker[vid] = freshMarker;
        _lastVehicleMarkerPos[vid] = pos;
        _lastVehicleMarkerHeading[vid] = stableHeading;
        _lastVehicleMarkerSelected[vid] = isSel;
      }

      if (_showDetectedObjects) {
        for (int oi = 0; oi < t.objects.length; oi++) {
          final DetectedObject obj = t.objects[oi];
          final LatLng? rawResolvedObjectPos = _resolveObjectPositionFromRaw(
            parentPosition: pos,
            rawX: obj.positionX,
            rawY: obj.positionY,
          );
          if (rawResolvedObjectPos == null) continue;

          final int oType = obj.objectType ?? 0;
          if (!_isObjectTypeVisible(oType)) continue;

          final String trackingKey = _vehicleObjectTrackingKey(vid, obj, oi);
          final ObjectTrackingData? objectTracking =
              _trackedObjects[trackingKey];
          final LatLng trackedObjectPos =
              objectTracking?.displayPosition ?? rawResolvedObjectPos;
          final double oHeading =
              objectTracking?.displayHeading ?? (obj.orientationHeading ?? 0.0);
          final LatLng renderedObjectPos = _resolveRenderedObjectPosition(
            parentPosition: pos,
            objectPosition: trackedObjectPos,
            objectIndex: oi,
          );

          newMarkers.add(Marker(
            markerId: MarkerId('obj_v${vid}_$oi'),
            position: renderedObjectPos,
            icon: _objectIconFor(oType),
            anchor: const Offset(0.5, 0.5),
            rotation: geo.normalizeHeadingDegrees(oHeading),
            flat: true,
            zIndexInt: 1100 + oi,
            infoWindow: InfoWindow.noText,
          ));
        }
      }
    }

    // 레지스트리에 등록됐지만 라이브 telemetry가 없는 차량 → 오프라인 마커
    for (final Map<String, dynamic> reg in _offlineVehicles) {
      final int vid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (vid <= 0) continue;
      if (_isVehicleOnline(vid, nowMs: now)) continue;
      final LatLng? rawPosition = _resolvedVehiclePosition(vid, nowMs: now);
      if (rawPosition == null) continue;
      final LatLng markerPosition = _avoidStationOverlap(rawPosition, vid);
      final bool isSelected = vid == _selectedVehicleId;
      newMarkers.add(Marker(
        markerId: MarkerId('offline_vehicle_$vid'),
        position: markerPosition,
        icon: isSelected ? selectedOfflineIcon : offlineIcon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: isSelected ? 860 : 200,
        infoWindow: InfoWindow(
          title: _vehicleName(vid),
          snippet: _vehicleLocationLabel(vid),
        ),
        onTap: () => _selectVehicle(
          vid,
          focusPosition: markerPosition,
          followLive: false,
        ),
      ));
    }

    for (final MapEntry<int, VehicleTrackingData> entry in _tracked.entries) {
      final int vid = entry.key;
      if (_isVehicleOnline(vid, nowMs: now)) continue;
      if (_registryVehicleById(vid) != null) continue;
      final LatLng? rawPosition = _trackedVehiclePosition(vid);
      if (rawPosition == null) continue;
      final LatLng markerPosition = _avoidStationOverlap(rawPosition, vid);
      final bool isSelected = vid == _selectedVehicleId;
      newMarkers.add(Marker(
        markerId: MarkerId('stale_vehicle_$vid'),
        position: markerPosition,
        icon: isSelected ? selectedOfflineIcon : offlineIcon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: isSelected ? 855 : 190,
        infoWindow: InfoWindow(
          title: _vehicleName(vid),
          snippet: _vehicleLocationLabel(vid),
        ),
        onTap: () => _selectVehicle(
          vid,
          focusPosition: markerPosition,
          followLive: false,
        ),
      ));
    }

    // 차량 뷰 인프라 마커: 실제 등록 위치에 모든 인프라 표시 (RSU는 고정 설치물)
    {
      final BitmapDescriptor liveInfraIcon = _infraIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      final BitmapDescriptor offlineInfraMarkerIcon = _infraOfflineIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      final Set<int> liveInfraIds = _infraSnapshots.keys.toSet();

      for (final MapEntry<int, _InfraSnapshot> entry in _infraSnapshots.entries) {
        final int infraId = entry.key;
        final _InfraSnapshot snapshot = entry.value;
        newMarkers.add(Marker(
          markerId: MarkerId('vi_infra_$infraId'),
          position: snapshot.position,
          icon: liveInfraIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 600,
          infoWindow: InfoWindow(
            title: _infraName(infraId),
            snippet: _infraLocationLabel(infraId),
          ),
        ));
      }

      for (final Map<String, dynamic> reg in _offlineInfras) {
        final int iid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
        if (iid <= 0 || liveInfraIds.contains(iid)) continue;
        final LatLng markerPosition = _resolveInfraPosition(iid);
        newMarkers.add(Marker(
          markerId: MarkerId('vi_offline_infra_$iid'),
          position: markerPosition,
          icon: offlineInfraMarkerIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 400,
          infoWindow: InfoWindow(
            title: _infraName(iid),
            snippet: _infraLocationLabel(iid),
          ),
        ));
      }
    }

    if (!_staticMarkersBuilt) {
      _rebuildStaticMarkers();
    }

    setState(() {
      _markers = newMarkers.union(_staticMarkers);
      _initialMarkersBuilt = true;
    });
  }

  void _buildInfraMarkers() {
    if (_disposed || !mounted || !_mapReady) return;

    final Set<Marker> newMarkers = <Marker>{};

    final BitmapDescriptor selectedInfraIcon = _infraBlinkOn
        ? (_infraIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen))
        : (_infraBlinkIcon ??
            _infraIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow));
    final BitmapDescriptor liveInfraIcon = _infraIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final BitmapDescriptor selectedOfflineInfraIcon =
        _infraOfflineSelectedIcon ??
            _infraOfflineIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    final BitmapDescriptor offlineInfraIcon = _infraOfflineIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    final int selectedInfraId =
        (_selectedInfraId != null && _selectedInfraId! > 0)
            ? _selectedInfraId!
            : (_infraInfo?.infraId ?? 0);
    final Set<int> liveInfraIds = _infraSnapshots.keys.toSet();

    for (final MapEntry<int, _InfraSnapshot> entry in _infraSnapshots.entries) {
      final int infraId = entry.key;
      final _InfraSnapshot snapshot = entry.value;
      final bool isSelected = infraId == selectedInfraId;
      newMarkers.add(
        Marker(
          markerId: MarkerId('infra_$infraId'),
          position: snapshot.position,
          icon: isSelected ? selectedInfraIcon : liveInfraIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: isSelected ? 900 : 850,
          infoWindow: InfoWindow(
            title: _infraName(infraId),
            snippet: _infraLocationLabel(infraId),
          ),
          onTap: () {
            if (!mounted || _disposed) return;
            setState(() {
              _selectedInfraId = infraId;
              _infraInfo = snapshot.info;
              _infraMarkerPos = snapshot.position;
              _infraObjects = <DetectedObject>[];
              _cameraFollows = false;
              _cameraFollowsInfra = true;
            });
            _buildInfraMarkers();
            _moveCameraTo(snapshot.position, zoom: 16.9);
            _maybeFollowSelectedInfra();
            unawaited(_pollStatusData());
          },
        ),
      );
    }

    final LatLng infraBasePos = _infraMarkerPos ??
        (_selectedInfraId != null && _selectedInfraId! > 0
            ? _resolveInfraPosition(_selectedInfraId!)
            : const LatLng(kiapiInfraLat, kiapiInfraLon));

    if (_showDetectedObjects) {
      for (int i = 0; i < _infraObjects.length; i++) {
        final DetectedObject obj = _infraObjects[i];
        final LatLng? rawResolvedObjectPos = _resolveObjectPositionFromRaw(
          parentPosition: infraBasePos,
          rawX: obj.positionX,
          rawY: obj.positionY,
        );
        if (rawResolvedObjectPos == null) continue;

        final int oType = obj.objectType ?? 0;
        if (!_isObjectTypeVisible(oType)) continue;
        final String trackingKey = _infraObjectTrackingKey(obj, i);
        final ObjectTrackingData? objectTracking = _trackedObjects[trackingKey];
        final LatLng trackedObjectPos =
            objectTracking?.displayPosition ?? rawResolvedObjectPos;
        final double oHeading =
            objectTracking?.displayHeading ?? (obj.orientationHeading ?? 0.0);
        final LatLng renderedObjectPos = _resolveRenderedObjectPosition(
          parentPosition: infraBasePos,
          objectPosition: trackedObjectPos,
          objectIndex: i,
        );

        newMarkers.add(Marker(
          markerId: MarkerId('infra_obj_$i'),
          position: renderedObjectPos,
          icon: _objectIconFor(oType),
          anchor: const Offset(0.5, 0.5),
          rotation: geo.normalizeHeadingDegrees(oHeading),
          flat: true,
          zIndexInt: 1100 + i,
          infoWindow: InfoWindow.noText,
        ));
      }
    }

    // 레지스트리에 등록됐지만 라이브 telemetry가 없는 인프라 → 오프라인 마커
    for (final Map<String, dynamic> reg in _offlineInfras) {
      final int iid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      if (iid <= 0) continue;
      if (liveInfraIds.contains(iid)) continue;
      final bool isSelected = iid == selectedInfraId;
      final LatLng markerPosition = _resolveInfraPosition(iid);
      newMarkers.add(Marker(
        markerId: MarkerId('offline_infra_$iid'),
        position: markerPosition,
        icon: isSelected ? selectedOfflineInfraIcon : offlineInfraIcon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: isSelected ? 860 : 200,
        infoWindow: InfoWindow(
          title: _infraName(iid),
          snippet: _infraLocationLabel(iid),
        ),
        onTap: () {
          if (!mounted || _disposed) return;
          setState(() {
            _selectedInfraId = iid;
            _infraInfo = null;
            _infraMarkerPos = markerPosition;
            _infraObjects = <DetectedObject>[];
            _cameraFollows = false;
            _cameraFollowsInfra = true;
          });
          _buildInfraMarkers();
          _moveCameraTo(markerPosition, zoom: 16.9);
          _maybeFollowSelectedInfra();
          unawaited(_pollStatusData());
        },
      ));
    }

    // ★ 2026-06-11: 온라인 차량은 VehicleMarkerOverlay(Flutter overlay)로 렌더 →
    //   plugin marker 80ms 재생성으로 인한 깜빡임 제거. 오프라인 차량만 plugin marker.
    {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final BitmapDescriptor vehicleOfflineIcon = _vehicleIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);

      for (final Map<String, dynamic> reg in _offlineVehicles) {
        final int vid = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
        if (vid <= 0 || _isVehicleOnline(vid, nowMs: nowMs)) continue;
        final LatLng? rawPos = _resolvedVehiclePosition(vid, nowMs: nowMs);
        if (rawPos == null) continue;
        final LatLng markerPosition = _avoidStationOverlap(rawPos, vid);
        newMarkers.add(Marker(
          markerId: MarkerId('iv_offline_vehicle_$vid'),
          position: markerPosition,
          icon: vehicleOfflineIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 200,
          infoWindow: InfoWindow(title: _vehicleName(vid)),
        ));
      }
    }

    if (!_staticMarkersBuilt) {
      _rebuildStaticMarkers();
    }

    setState(() {
      _markers = newMarkers.union(_staticMarkers);
    });
  }

  BitmapDescriptor _stationIconFor(int idx) {
    if (_stationIcons.isNotEmpty && idx < _stationIcons.length) {
      return _stationIcons[idx];
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }

  BitmapDescriptor _stationSelectedIconFor(int idx) {
    if (_stationSelectedIcons.isNotEmpty &&
        idx < _stationSelectedIcons.length) {
      return _stationSelectedIcons[idx];
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  BitmapDescriptor _objectIconFor(int objectType) {
    final int safeType = objectType.clamp(0, 5);
    return _objectIcons[safeType] ??
        _objectIcons[0] ??
        BitmapDescriptor.defaultMarkerWithHue(getObjectTypeHue(objectType));
  }

  int _totalObjectCount() {
    int total = 0;
    for (final VehicleTrackingData t in _tracked.values) {
      total += t.objects.length;
    }
    return total;
  }

  String _currentStationShortLabel() {
    final int idx = _selectedStationIdx.clamp(0, kiapiRoadWaypoints.length - 1);
    return kiapiRoadWaypoints[idx].shortLabel;
  }

  String _currentStationName() {
    final int idx = _selectedStationIdx.clamp(0, kiapiRoadWaypoints.length - 1);
    return kiapiRoadWaypoints[idx].name;
  }

  Map<int, int> _objectCountsByType() {
    final Map<int, int> counts = <int, int>{};
    final List<DetectedObject> source = _entityType == MapEntityType.vehicle
        ? _tracked.values.expand((VehicleTrackingData t) => t.objects).toList()
        : _infraObjects;

    for (final DetectedObject obj in source) {
      final int type = (obj.objectType ?? 0).clamp(0, 5);
      counts[type] = (counts[type] ?? 0) + 1;
    }
    for (int i = 0; i <= 5; i++) {
      counts[i] = counts[i] ?? 0;
    }
    return counts;
  }

  LatLng _offsetLatLngByMeters({
    required LatLng origin,
    required double distanceMeters,
    required double bearingDegrees,
  }) {
    const double earthRadiusMeters = 6378137.0;
    final double angularDistance = distanceMeters / earthRadiusMeters;
    final double bearingRad =
        geo.degreesToRadians(geo.normalizeHeadingDegrees(bearingDegrees));
    final double lat1 = geo.degreesToRadians(origin.latitude);
    final double lon1 = geo.degreesToRadians(origin.longitude);

    final double sinLat1 = sin(lat1);
    final double cosLat1 = cos(lat1);
    final double sinAngularDistance = sin(angularDistance);
    final double cosAngularDistance = cos(angularDistance);

    final double lat2 = asin(sinLat1 * cosAngularDistance +
        cosLat1 * sinAngularDistance * cos(bearingRad));
    final double lon2 = lon1 +
        atan2(
          sin(bearingRad) * sinAngularDistance * cosLat1,
          cosAngularDistance - sinLat1 * sin(lat2),
        );

    return LatLng(geo.radiansToDegrees(lat2), geo.radiansToDegrees(lon2));
  }

  LatLng _offsetLatLngByEastNorthMeters({
    required LatLng origin,
    required double offsetXMeters,
    required double offsetYMeters,
  }) {
    final double distanceMeters =
        sqrt((offsetXMeters * offsetXMeters) + (offsetYMeters * offsetYMeters));
    if (distanceMeters <= 0.0001) {
      return origin;
    }
    final double bearingDegrees = geo.normalizeHeadingDegrees(
      geo.radiansToDegrees(atan2(offsetXMeters, offsetYMeters)),
    );
    return _offsetLatLngByMeters(
      origin: origin,
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
    );
  }

  LatLng? _resolveObjectPositionFromRaw({
    required LatLng parentPosition,
    required double? rawX,
    required double? rawY,
  }) {
    if (rawX == null || rawY == null) {
      return null;
    }

    if (geo.isValidUtmCoordinate(rawX, rawY)) {
      final geo.Wgs84Coordinate wgs = geo.convertUtmZone52NToWgs84(
        eastingMeters: rawX,
        northingMeters: rawY,
      );
      return LatLng(wgs.latitudeDegrees, wgs.longitudeDegrees);
    }

    if (geo.isValidLatLng(rawX, rawY)) {
      final LatLng asLatLng = LatLng(rawX, rawY);
      final double distToParent = geo.haversineMeters(
        parentPosition.latitude,
        parentPosition.longitude,
        asLatLng.latitude,
        asLatLng.longitude,
      );
      if (distToParent <= _objectAbsoluteParentMaxDistanceMeters) {
        return asLatLng;
      }
    }

    if (geo.isValidLatLng(rawY, rawX)) {
      final LatLng swappedLatLng = LatLng(rawY, rawX);
      final double distToParent = geo.haversineMeters(
        parentPosition.latitude,
        parentPosition.longitude,
        swappedLatLng.latitude,
        swappedLatLng.longitude,
      );
      if (distToParent <= _objectAbsoluteParentMaxDistanceMeters) {
        return swappedLatLng;
      }
    }

    if (rawX.abs() <= _objectRelativeMaxAbsMeters &&
        rawY.abs() <= _objectRelativeMaxAbsMeters) {
      return _offsetLatLngByEastNorthMeters(
        origin: parentPosition,
        offsetXMeters: rawX,
        offsetYMeters: rawY,
      );
    }

    return null;
  }

  LatLng _resolveRenderedObjectPosition({
    required LatLng parentPosition,
    required LatLng objectPosition,
    required int objectIndex,
  }) {
    final double distanceMeters = geo.haversineMeters(
      parentPosition.latitude,
      parentPosition.longitude,
      objectPosition.latitude,
      objectPosition.longitude,
    );
    if (distanceMeters >= _objectMinSeparationMeters) {
      return objectPosition;
    }

    final int safeSlots =
        _objectSeparationSlots <= 0 ? 8 : _objectSeparationSlots;
    final int slot = objectIndex % safeSlots;
    final int ring = objectIndex ~/ safeSlots;

    final double baseBearing = distanceMeters > 0.5
        ? geo.bearingBetween(
            parentPosition.latitude,
            parentPosition.longitude,
            objectPosition.latitude,
            objectPosition.longitude,
          )
        : (360.0 / safeSlots) * slot;
    final double targetDistance =
        _objectMinSeparationMeters + (ring * _objectSeparationRingStepMeters);

    return _offsetLatLngByMeters(
      origin: parentPosition,
      distanceMeters: targetDistance,
      bearingDegrees: baseBearing,
    );
  }

  void _moveCameraTo(LatLng pos, {double? zoom}) {
    if (_mapController == null ||
        !geo.isValidLatLng(pos.latitude, pos.longitude)) {
      return;
    }
    final double targetZoom =
        (zoom ?? _currentMapZoom).clamp(_minCameraZoom, _maxCameraZoom);
    _currentCameraTarget = pos;
    _currentMapZoom = targetZoom;

    // 웹에서 GoogleMap padding이 적용되지 않아 수동으로 카메라 타깃 보정:
    // 추적 패널(오른쪽 324px)이 열려있으면 카메라를 동쪽으로 절반만큼 이동시켜
    // 마커가 가시 영역(패널 왼쪽) 중앙에 오도록 한다.
    LatLng cameraTarget = pos;
    if (_entityType == MapEntityType.vehicle && _selectedVehicleId != null) {
      const double panelHalfPx = (_liveTrackingPanelWidth + 24) / 2.0;
      // zoom 레벨 Z 에서 1픽셀 = 1.4063 / 2^Z 경도도 (cosine이 분자분모에서 상쇄됨)
      final double lngPerPixel = 1.4063 / pow(2.0, targetZoom);
      cameraTarget = LatLng(pos.latitude, pos.longitude + panelHalfPx * lngPerPixel);
    }

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: cameraTarget, zoom: targetZoom),
      ),
    );
  }

  Future<void> _loadRoutePolyline(int fromStationIdx, int toStationIdx) async {
    return;
  }

  void _applyRoutePolyline() {
    if (_disposed || !mounted) return;
    setState(() {
      _polylines = <Polyline>{};
    });
  }

  // ============================================================================
  // Flutter Overlay 헬퍼 / Flutter overlay helpers
  // ============================================================================

  /// onCameraMove / LayoutBuilder 에서 호출 — 오버레이 카메라 스냅샷 갱신
  void _updateOverlayCamera({
    LatLng? target,
    double? zoom,
    double? bearing,
    Size? containerSize,
    EdgeInsets? padding,
  }) {
    if (!_useVehicleOverlay) return;
    final old = _overlayCamera.value;
    final newSnap = OverlayCameraSnapshot(
      target: target ?? old.target,
      zoom: zoom ?? (old.zoom > 0 ? old.zoom : _currentMapZoom),
      bearing: bearing ?? old.bearing,
      containerSize: containerSize ?? _overlayContainerSize,
      padding: padding ?? _overlayPadding,
    );
    // ValueNotifier 는 == 비교 안 함 (참조 비교) → 항상 fire
    _overlayCamera.value = newSnap;
  }

  /// _tracked 맵 → OverlayVehicle 리스트 (online 차량만)
  /// Build overlay vehicle list from tracked online vehicles
  List<OverlayVehicle> _buildOverlayVehicles() {
    if (!_useVehicleOverlay) return const <OverlayVehicle>[];
    // ★ 2026-06-11: 인프라 뷰에서도 차량을 overlay 로 렌더 → plugin marker 깜빡임 제거.
    //   (이전: 인프라 뷰는 _buildInfraMarkers 가 80ms마다 차량 plugin marker 재생성 → flash)
    final int now = DateTime.now().millisecondsSinceEpoch;
    final list = <OverlayVehicle>[];
    for (final MapEntry<int, VehicleTrackingData> entry in _tracked.entries) {
      final int vid = entry.key;
      if (!_isVehicleOnline(vid, nowMs: now)) continue;
      final VehicleTrackingData t = entry.value;
      final LatLng? pos = t.displayPosition ?? t.targetPosition;
      if (pos == null) continue;
      if (!geo.isValidLatLng(pos.latitude, pos.longitude)) continue;
      list.add(OverlayVehicle(
        id: vid,
        position: pos,
        headingDeg: geo.normalizeHeadingDegrees(t.displayHeading),
        selected: vid == _selectedVehicleId,
        online: true,
      ));
    }
    return list;
  }

  // ── car.png 회전 아이콘 시스템 ────────────────────────────────────────────

  /// 차량별 안정적인 icon 참조 결정 — google_maps_flutter_web 깜빡임 해결의 핵심
  /// Per-vehicle STABLE icon resolution — the actual flicker fix.
  ///
  /// 규칙 (Rules):
  /// 1) EXACT 캐시 hit (wantKey 가 캐시에 있음) → 즉시 사용 + 저장
  /// 2) EXACT 미스이지만 이 차량에 이미 할당된 icon 이 있음 → 이전 icon 유지
  ///    (절대 _findNearestCarIcon 으로 switching → 매 호출마다 다른 ref → flicker)
  /// 3) 신규 차량 → 일반 fallback 사용, 비동기 빌드 트리거
  /// 4) 모든 경우 비동기 build 트리거하여 EXACT 가 준비되면 다음 rebuild 에서 swap
  ///
  /// 1) EXACT hit -> use it
  /// 2) EXACT miss but vehicle already has an assigned icon -> KEEP IT (never swap to nearest)
  /// 3) First-time -> use generic fallback
  /// 4) Always trigger async build so EXACT becomes available later
  BitmapDescriptor _resolveStableVehicleIcon({
    required int vid,
    required int bucketDeg,
    required int sizePx,
    required bool selected,
    required String wantKey,
  }) {
    final String cacheKey = _carCacheKey(bucketDeg, sizePx);
    final Map<String, BitmapDescriptor> cache =
        selected ? _carIconSelected : _carIconNormal;

    // (1) EXACT match 가 캐시에 있음 → 사용 + 차량에 영구 할당
    final BitmapDescriptor? exact = cache[cacheKey];
    if (exact != null) {
      _vehicleIconRef[vid] = exact;
      _vehicleIconKey[vid] = wantKey;
      return exact;
    }

    // (2) 이 차량이 이미 어떤 icon 을 사용 중이면 그대로 유지 (절대 swap 안 함)
    //     비동기 빌드는 트리거 → 다음 rebuild 에서 EXACT 사용 가능
    final BitmapDescriptor? held = _vehicleIconRef[vid];
    if (held != null) {
      _triggerCarBucketBuild(bucketDeg, sizePx);
      return held;
    }

    // (3) 신규 차량 → fallback (일반 _vehicleIcon 또는 default marker)
    final BitmapDescriptor fallback = selected
        ? (_vehicleSelectedIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure))
        : (_vehicleIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue));
    _vehicleIconRef[vid] = fallback;
    _vehicleIconKey[vid] = 'fallback';
    _triggerCarBucketBuild(bucketDeg, sizePx);
    return fallback;
  }

  /// 캐시 미스 시 비동기 build 를 안전하게 트리거 (중복 방지)
  /// Safely trigger async build of a missing icon bucket
  void _triggerCarBucketBuild(int bucketDeg, int sizePx) {
    final String cacheKey = _carCacheKey(bucketDeg, sizePx);
    if (_carIconPending.contains(cacheKey)) return;
    _carIconPending.add(cacheKey);
    if (_carSrcImg != null) {
      unawaited(_buildCarIconForBucket(bucketDeg, sizePx: sizePx));
    } else {
      unawaited(_loadCarSrc(sizePx).then((_) {
        if (!_disposed && mounted) {
          unawaited(_buildCarIconForBucket(bucketDeg, sizePx: sizePx));
        }
      }));
    }
  }

  // 헤딩을 5° 버킷으로 정규화 (0~359)
  static int _carBucket(double deg) =>
      (((deg / _carBucketDeg).round() * _carBucketDeg) % 360).toInt();

  /// Hysteresis: heading 이 _bucketHysteresisSteps * _carBucketDeg (30°) 이상
  /// 차이 나야만 새 bucket 으로 전환 → 미세한 회전에서 icon switch 방지
  /// Heading must change by >= 30° to switch bucket → no flicker on small turns
  double _stableHeadingForVehicle(int vehicleId, double newHeading) {
    final int newBucket = _carBucket(newHeading);
    final int? lastBucket = _vehicleLastBucket[vehicleId];
    if (lastBucket == null) {
      _vehicleLastBucket[vehicleId] = newBucket;
      return newBucket.toDouble();
    }
    // 두 bucket 간 각도 차 (0..180)
    int delta = (newBucket - lastBucket).abs();
    if (delta > 180) delta = 360 - delta;
    // 변화량이 threshold 이상일 때만 bucket 갱신
    if (delta >= _bucketHysteresisSteps * _carBucketDeg) {
      _vehicleLastBucket[vehicleId] = newBucket;
      return newBucket.toDouble();
    }
    return lastBucket.toDouble();
  }

  static String _carCacheKey(int bucketDeg, int sizePx) => '$bucketDeg@$sizePx';

  int _liveVehicleMarkerSizePx({required bool moving}) {
    if (!moving) return _vehicleIconSizePx;
    return (_vehicleIconSizePx * _vehicleMovingMarkerScale)
        .round()
        .clamp(_vehicleIconSizePx + 2, 76);
  }

  // car.png 원본 1회 로드 (크기 변경 시 캐시 전체 무효화)
  Future<void> _loadCarSrc(int sizePx) async {
    if (_carSrcImg != null && _carSrcSizePx >= sizePx) return;
    if (_carSrcLoading) return;
    _carSrcLoading = true;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/car.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: sizePx,
        targetHeight: sizePx,
      );
      final ui.FrameInfo f = await codec.getNextFrame();
      _carSrcImg?.dispose();
      _carSrcImg = f.image;
      _carSrcSizePx = sizePx;
      _carIconNormal.clear();
      _carIconSelected.clear();
      _carIconPending.clear();
    } catch (_) {
      // 로드 실패 시 폴백 사용
    } finally {
      _carSrcLoading = false;
    }
  }

  // 특정 헤딩으로 회전된 BitmapDescriptor 비동기 생성 후 캐시에 저장
  Future<void> _buildCarIconForBucket(int bucketDeg,
      {required int sizePx}) async {
    final String cacheKey = _carCacheKey(bucketDeg, sizePx);
    final ui.Image? src = _carSrcImg;
    if (src == null) {
      _carIconPending.remove(cacheKey);
      return;
    }

    final double s = sizePx.toDouble();
    final double rad = bucketDeg * pi / 180.0;

    Future<BitmapDescriptor> render(bool sel) async {
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final Canvas canvas = Canvas(rec);
      // 투명 배경 보장
      canvas.drawColor(Colors.transparent, BlendMode.clear);

      // 선택 시 파란 글로우 링
      if (sel) {
        canvas.drawCircle(
          Offset(s / 2, s / 2),
          s * 0.46,
          Paint()
            ..color = const Color(0x553A8BFF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
      }
      // 바닥 그림자
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s / 2 + s * 0.02, s / 2 + s * 0.06),
          width: s * 0.44,
          height: s * 0.13,
        ),
        Paint()
          ..color = const Color(0x44000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // 헤딩 방향으로 회전 후 car.png 렌더링
      final double drawSize = s * (sel ? 0.88 : 0.84);
      canvas.save();
      canvas.translate(s / 2, s / 2);
      canvas.rotate(rad);
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: drawSize, height: drawSize),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      final ui.Image img = await rec.endRecording().toImage(sizePx, sizePx);
      final ByteData? bytes =
          await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bytes == null) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }
      return BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: s,
        height: s,
      );
    }

    final BitmapDescriptor normal = await render(false);
    final BitmapDescriptor selected = await render(true);

    if (_disposed || !mounted) {
      _carIconPending.remove(cacheKey);
      return;
    }
    _carIconNormal[cacheKey] = normal;
    _carIconSelected[cacheKey] = selected;
    _carIconPending.remove(cacheKey);
    // ★ _forceRebuildMarkers 호출 제거 (workflow 진단 결과):
    //   - throttle 우회 → 매 icon build 마다 강제 setState → flicker
    //   - 새 icon 은 다음 _rebuildMarkersThrottled tick (≤200ms) 에서 자동 채택됨
    //   - 그때 _resolveStableVehicleIcon 이 EXACT match 발견 → 부드러운 swap
    // ★ Removed _forceRebuildMarkers call (per workflow diagnosis):
    //   - It bypassed the throttle, forcing setState per icon build → flicker.
    //   - The next throttled rebuild (≤200ms) will auto-pick up the new exact icon
    //     via _resolveStableVehicleIcon, producing a smooth single swap.
  }

  bool _isPrewarming = false;

  /// 모든 bucket 미리 생성 (앱 시작 시 한 번) → 주행 중 cache miss 없음
  /// Pre-warm all heading buckets at startup → no cache miss during driving
  Future<void> _prewarmCarIcons() async {
    if (_carSrcImg == null) {
      await _loadCarSrc(_vehicleIconSizePx);
    }
    if (_carSrcImg == null) return;
    // prewarm 중에는 _buildCarIconForBucket 이 마커를 rebuild 하지 않도록
    _isPrewarming = true;
    try {
      // 두 가지 크기 모두 미리 생성 / Both sizes (stopped + moving)
      final List<int> sizes = <int>[
        _vehicleIconSizePx,
        _liveVehicleMarkerSizePx(moving: true),
      ];
      for (final int sz in sizes) {
        for (int b = 0; b < 360; b += _carBucketDeg) {
          if (_disposed || !mounted) return;
          final String key = _carCacheKey(b, sz);
          if (_carIconNormal.containsKey(key)) continue;
          if (_carIconPending.contains(key)) continue;
          _carIconPending.add(key);
          await _buildCarIconForBucket(b, sizePx: sz);
          // 짧은 yield → 메인 스레드 차단 방지 / yield to avoid blocking main thread
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      _isPrewarming = false;
      // prewarm 완료 후 단 한 번만 rebuild
      // Single rebuild after prewarm completes
      if (!_disposed && mounted) _forceRebuildMarkers();
    }
  }

  // 마커 빌드(동기)에서 호출: 캐시 히트 → 반환 / 미스 → 백그라운드 생성 후 폴백 반환
  BitmapDescriptor _carIconFor(
    double heading, {
    required bool selected,
    required int sizePx,
  }) {
    final int bucketDeg = _carBucket(heading);
    final String cacheKey = _carCacheKey(bucketDeg, sizePx);
    final Map<String, BitmapDescriptor> cache =
        selected ? _carIconSelected : _carIconNormal;

    // 정확한 매칭 / Exact match
    if (cache.containsKey(cacheKey)) return cache[cacheKey]!;

    // 캐시 미스 → 비동기 생성 트리거 (중복 방지)
    if (!_carIconPending.contains(cacheKey)) {
      _carIconPending.add(cacheKey);
      if (_carSrcImg != null) {
        unawaited(_buildCarIconForBucket(bucketDeg, sizePx: sizePx));
      } else {
        unawaited(_loadCarSrc(sizePx).then((_) {
          if (!_disposed && mounted) {
            unawaited(_buildCarIconForBucket(bucketDeg, sizePx: sizePx));
          }
        }));
      }
    }

    // ── 가까운 캐시 매칭 (depo 마커 깜빡임 방지) / Nearest cached match ──
    // 동일 sizePx 에서 heading 이 가장 가까운 이미 생성된 아이콘을 사용
    // 정확한 bucket 이 빌드되는 동안 기본 마커 대신 비슷한 방향의 차 아이콘 표시
    final BitmapDescriptor? nearest = _findNearestCarIcon(
      cache: cache,
      targetBucketDeg: bucketDeg,
      targetSizePx: sizePx,
    );
    if (nearest != null) return nearest;

    // 정말로 캐시가 비어있는 첫 프레임에만 폴백 사용
    final bool useMovingFallback = sizePx > _vehicleIconSizePx;
    return selected
        ? ((useMovingFallback ? _vehicleMovingSelectedIcon : null) ??
            _vehicleSelectedIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure))
        : ((useMovingFallback ? _vehicleMovingIcon : null) ??
            _vehicleIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue));
  }

  /// 캐시에서 가장 가까운 bucketDeg + sizePx 매치 찾기
  /// Find the closest cached car icon by bucketDeg + sizePx
  BitmapDescriptor? _findNearestCarIcon({
    required Map<String, BitmapDescriptor> cache,
    required int targetBucketDeg,
    required int targetSizePx,
  }) {
    if (cache.isEmpty) return null;
    BitmapDescriptor? best;
    int bestScore = 0x7fffffff;
    for (final MapEntry<String, BitmapDescriptor> e in cache.entries) {
      final List<String> parts = e.key.split('@');
      if (parts.length != 2) continue;
      final int? bd = int.tryParse(parts[0]);
      final int? sp = int.tryParse(parts[1]);
      if (bd == null || sp == null) continue;
      // 각도 차 (0..180)
      int dBucket = (bd - targetBucketDeg).abs();
      if (dBucket > 180) dBucket = 360 - dBucket;
      // 크기 차이는 큰 페널티 (크기 다른 아이콘은 마지막 수단)
      final int dSize = (sp - targetSizePx).abs() * 4;
      final int score = dBucket + dSize;
      if (score < bestScore) {
        bestScore = score;
        best = e.value;
      }
    }
    return best;
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<BitmapDescriptor> _canvasMarker({
    required int sizePx,
    required void Function(Canvas c, double s) painter,
  }) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final Canvas canvas = Canvas(rec);
    painter(canvas, sizePx.toDouble());
    final ui.Image img = await rec.endRecording().toImage(sizePx, sizePx);
    final ByteData? bytes =
        await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('marker image bytes null');
    // 신버전 google_maps_flutter에서 width/height 필수
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: sizePx.toDouble(),
      height: sizePx.toDouble(),
    );
  }

  // 직사각형 캔버스 마커 (pin 등 비정방형 마커용)
  Future<BitmapDescriptor> _canvasMarkerWH({
    required int widthPx,
    required int heightPx,
    required void Function(Canvas c, double w, double h) painter,
  }) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final Canvas canvas = Canvas(rec);
    painter(canvas, widthPx.toDouble(), heightPx.toDouble());
    final ui.Image img =
        await rec.endRecording().toImage(widthPx, heightPx);
    final ByteData? bytes =
        await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('marker image bytes null');
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: widthPx.toDouble(),
      height: heightPx.toDouble(),
    );
  }

  // station.svg 디자인 기반 핀 마커 (원형 헤드 + 아래 포인트)
  // SVG viewBox 0 0 128 160 비율 유지
  void _paintStationPin(
      Canvas c, double w, double h, String label, bool selected) {
    final Color pinColor =
        selected ? const Color(0xFFFFC107) : const Color(0xFFFF4A4A);
    final Color pinDark =
        selected ? const Color(0xFFFF8F00) : const Color(0xFFE03A3A);
    final Color innerBg = Colors.white;
    final Color labelColor = selected
        ? const Color(0xFF1F1F1F)
        : const Color(0xFF7B1FA2);

    // SVG 비율 그대로 적용 (128x160 → w x h)
    final double cx = w / 2;
    final double headCy = h * (62.0 / 160.0);
    final double innerR = w * (36.0 / 128.0);

    // 핀 외형 경로 (SVG path 그대로 스케일)
    final Path pinPath = Path()
      ..moveTo(cx, h * (8.0 / 160.0))
      ..cubicTo(
        w * (34.0 / 128.0), h * (8.0 / 160.0),
        w * (10.0 / 128.0), h * (32.0 / 160.0),
        w * (10.0 / 128.0), h * (62.0 / 160.0),
      )
      ..cubicTo(
        w * (10.0 / 128.0), h * (75.0 / 160.0),
        w * (15.0 / 128.0), h * (87.0 / 160.0),
        w * (24.0 / 128.0), h * (97.0 / 160.0),
      )
      ..lineTo(cx, h * (152.0 / 160.0))
      ..lineTo(w * (104.0 / 128.0), h * (97.0 / 160.0))
      ..cubicTo(
        w * (113.0 / 128.0), h * (87.0 / 160.0),
        w * (118.0 / 128.0), h * (75.0 / 160.0),
        w * (118.0 / 128.0), h * (62.0 / 160.0),
      )
      ..cubicTo(
        w * (118.0 / 128.0), h * (32.0 / 160.0),
        w * (94.0 / 128.0), h * (8.0 / 160.0),
        cx, h * (8.0 / 160.0),
      )
      ..close();

    // 그림자
    c.drawPath(
      pinPath.shift(const Offset(1.5, 2.0)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 핀 본체
    c.drawPath(pinPath, Paint()..color = pinColor);

    // 아래쪽 어두운 부분 (SVG E03A3A 영역)
    final Path darkPath = Path()
      ..moveTo(cx, h * (152.0 / 160.0))
      ..lineTo(w * (104.0 / 128.0), h * (97.0 / 160.0))
      ..cubicTo(
        w * (108.0 / 128.0), h * (91.0 / 160.0),
        w * (112.0 / 128.0), h * (83.0 / 160.0),
        w * (114.0 / 128.0), h * (75.0 / 160.0),
      )
      ..lineTo(cx, h * (90.0 / 160.0))
      ..lineTo(w * (14.0 / 128.0), h * (75.0 / 160.0))
      ..cubicTo(
        w * (16.0 / 128.0), h * (83.0 / 160.0),
        w * (20.0 / 128.0), h * (91.0 / 160.0),
        w * (24.0 / 128.0), h * (97.0 / 160.0),
      )
      ..lineTo(cx, h * (152.0 / 160.0))
      ..close();
    c.drawPath(darkPath, Paint()..color = pinDark);

    // 내부 흰 원
    c.drawCircle(Offset(cx, headCy), innerR, Paint()..color = innerBg);

    // 스테이션 레이블 텍스트
    final double fs = innerR * (label.length <= 2 ? 0.7 : 0.52);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: labelColor,
          fontSize: max(8, fs),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: innerR * 2);
    tp.paint(c, Offset(cx - tp.width / 2, headCy - tp.height / 2));
  }

  // car.png를 BitmapDescriptor로 변환
  // Canvas 없이 PNG 원본 바이트를 직접 전달 → 투명 배경이 검게 되는 문제 없음
  // 회전은 Marker.rotation: displayHeading 으로 Google Maps가 처리
  Future<BitmapDescriptor> _vehicleAssetMarker({
    required int sizePx,
    bool selected = false,
  }) async {
    try {
      final ByteData assetBytes =
          await rootBundle.load('assets/images/car.png');
      final double displaySize =
          selected ? (sizePx * 1.18).toDouble() : sizePx.toDouble();
      return BitmapDescriptor.bytes(
        assetBytes.buffer.asUint8List(),
        width: displaySize,
        height: displaySize,
      );
    } catch (_) {
      // 폴백: 캔버스 직접 그리기
      return _canvasMarker(
        sizePx: sizePx,
        painter: (Canvas c, double s) {
          _paintVehicleMarkerBase(
            c,
            s,
            startColor:
                selected ? const Color(0xFF1565C0) : const Color(0xFF2E8BFF),
            endColor:
                selected ? const Color(0xFF0B3D91) : const Color(0xFF0D5AC2),
            accentColor:
                selected ? const Color(0xFF64B5F6) : const Color(0xFF90CAF9),
            selected: selected,
          );
          _paintVehicleGlyphModern(c, s);
        },
      );
    }
  }

  void _paintShadow(Canvas c, double s, double r) {
    c.drawCircle(
      Offset(s / 2 + 1.5, s / 2 + 2.0),
      r,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _paintBg(Canvas c, double s, double r, Color col) {
    c.drawCircle(Offset(s / 2, s / 2), r, Paint()..color = col);
    c.drawCircle(
      Offset(s / 2, s / 2),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, s * 0.05),
    );
  }

  void _paintText(Canvas c, double s, String txt, double fs, Color col) {
    final TextPainter tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: txt,
        style: TextStyle(
          color: col,
          fontSize: fs,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
    tp.layout();
    tp.paint(c, Offset((s - tp.width) / 2, (s - tp.height) / 2));
  }

  void _paintDirectionArrow(Canvas c, double s) {
    final double cx = s / 2;
    final double top = s * 0.08;
    final Paint arrowPaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.fill;
    final Path arrow = Path()
      ..moveTo(cx, top)
      ..lineTo(cx - s * 0.10, top + s * 0.12)
      ..lineTo(cx + s * 0.10, top + s * 0.12)
      ..close();
    c.drawPath(arrow, arrowPaint);
  }

  // ── 차량 마커 베이스: 그림자 + selected 글로우 (배경 없음) ─────────────────
  void _paintVehicleMarkerBase(
    Canvas c,
    double s, {
    required Color startColor,
    required Color endColor,
    required Color accentColor,
    bool selected = false,
  }) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double u = s / 64.0;

    // selected: 파란 글로우
    if (selected) {
      c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 24 * u, height: 40 * u),
        Paint()
          ..color = startColor.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // 차체 그림자
    c.drawOval(
      Rect.fromCenter(
          center: Offset(cx + 1.5 * u, cy + 2 * u),
          width: 20 * u,
          height: 38 * u),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  // ── 실사풍 탑뷰 차량: 차체/루프/유리/휠/라이트 ─────────────────────────────
  void _paintVehicleGlyphModern(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double u = s / 64.0;

    // ── 차체 (흰색) ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 20 * u, height: 36 * u),
        Radius.circular(5 * u),
      ),
      Paint()..color = Colors.white,
    );

    // ── 보닛 (앞) ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 13 * u), width: 18 * u, height: 10 * u),
        Radius.circular(4.5 * u),
      ),
      Paint()..color = const Color(0xFFEDEDED),
    );

    // ── 트렁크 (뒤) ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 13 * u), width: 18 * u, height: 10 * u),
        Radius.circular(4.5 * u),
      ),
      Paint()..color = const Color(0xFFE8E8E8),
    );

    // ── 루프/실내 (어두운 남색) ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 1.5 * u), width: 16 * u, height: 17 * u),
        Radius.circular(3 * u),
      ),
      Paint()..color = const Color(0xFF1B2540),
    );

    // ── 앞유리 ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 9.5 * u), width: 14 * u, height: 3.5 * u),
        Radius.circular(1.5 * u),
      ),
      Paint()..color = const Color(0xFF4A82B5),
    );

    // ── 뒷유리 ──
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 6 * u), width: 12 * u, height: 3 * u),
        Radius.circular(1.5 * u),
      ),
      Paint()..color = const Color(0xFF4A82B5),
    );

    // ── 사이드미러 ──
    final Paint mirrorP = Paint()..color = const Color(0xFFCCCCCC);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - 11 * u, cy - 8 * u),
            width: 3.5 * u,
            height: 2.5 * u),
        Radius.circular(u),
      ),
      mirrorP,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 11 * u, cy - 8 * u),
            width: 3.5 * u,
            height: 2.5 * u),
        Radius.circular(u),
      ),
      mirrorP,
    );

    // ── 휠 아치 (연회색) ──
    final Paint archP = Paint()..color = const Color(0xFFBBBBBB);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 11 * u, cy - 10 * u),
            width: 7 * u,
            height: 9 * u),
        archP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 11 * u, cy - 10 * u),
            width: 7 * u,
            height: 9 * u),
        archP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 11 * u, cy + 10 * u),
            width: 7 * u,
            height: 9 * u),
        archP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 11 * u, cy + 10 * u),
            width: 7 * u,
            height: 9 * u),
        archP);

    // ── 타이어 (검정) ──
    final Paint tireP = Paint()..color = const Color(0xFF2A2A2A);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 11 * u, cy - 10 * u),
            width: 5 * u,
            height: 7 * u),
        tireP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 11 * u, cy - 10 * u),
            width: 5 * u,
            height: 7 * u),
        tireP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 11 * u, cy + 10 * u),
            width: 5 * u,
            height: 7 * u),
        tireP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 11 * u, cy + 10 * u),
            width: 5 * u,
            height: 7 * u),
        tireP);

    // ── 헤드라이트 (앞, 크림색) ──
    final Paint hlP = Paint()..color = const Color(0xFFFFF8DC);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - 6 * u, cy - 17.5 * u),
            width: 5 * u,
            height: 2.5 * u),
        Radius.circular(u),
      ),
      hlP,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 6 * u, cy - 17.5 * u),
            width: 5 * u,
            height: 2.5 * u),
        Radius.circular(u),
      ),
      hlP,
    );

    // ── 테일라이트 (뒤, 빨간색) ──
    final Paint tlP = Paint()..color = const Color(0xFFE53935);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - 6 * u, cy + 17.5 * u),
            width: 5 * u,
            height: 2.5 * u),
        Radius.circular(u),
      ),
      tlP,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 6 * u, cy + 17.5 * u),
            width: 5 * u,
            height: 2.5 * u),
        Radius.circular(u),
      ),
      tlP,
    );
  }

  // ignore: unused_element
  void _paintVehicleGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 56;
    final Paint p = Paint()..color = Colors.white;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 2 * sc), width: 24 * sc, height: 14 * sc),
        Radius.circular(3 * sc),
      ),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 6 * sc), width: 17 * sc, height: 10 * sc),
        Radius.circular(3 * sc),
      ),
      p,
    );

    final Paint wheelPaint = Paint()..color = const Color(0x88000000);
    c.drawCircle(Offset(cx - 8 * sc, cy + 9 * sc), 3 * sc, wheelPaint);
    c.drawCircle(Offset(cx + 8 * sc, cy + 9 * sc), 3 * sc, wheelPaint);
  }

  void _paintInfraMarkerBase(
    Canvas c,
    double s, {
    required Color startColor,
    required Color endColor,
    required Color accentColor,
    bool blinking = false,
  }) {
    final Offset center = Offset(s / 2, s / 2);
    final double radius = s * 0.40;

    _paintShadow(c, s, radius);

    if (blinking) {
      c.drawCircle(
        center,
        radius + s * 0.08,
        Paint()..color = accentColor.withValues(alpha: 0.24),
      );
    }

    Path hexPath(double r) {
      final Path path = Path();
      for (int i = 0; i < 6; i++) {
        final double angle = -pi / 2 + i * (pi / 3);
        final Offset p = Offset(
          center.dx + cos(angle) * r,
          center.dy + sin(angle) * r,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      return path;
    }

    final Path outerHex = hexPath(radius);
    c.drawPath(
      outerHex,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - radius, center.dy - radius),
          Offset(center.dx + radius, center.dy + radius),
          <Color>[startColor, endColor],
        ),
    );
    c.drawPath(
      outerHex,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, s * 0.052),
    );

    c.drawPath(
      hexPath(radius * 0.70),
      Paint()
        ..color = accentColor.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.1, s * 0.024),
    );
  }

  void _paintInfraGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 56;

    final Paint mastPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, s * 0.058)
      ..strokeCap = StrokeCap.round;
    final Paint fillPaint = Paint()..color = Colors.white;
    final Paint wavePaint = Paint()
      ..color = const Color(0xFFE0F7FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.6, s * 0.038)
      ..strokeCap = StrokeCap.round;

    final double mastTopY = cy - 11.5 * sc;
    final double mastBottomY = cy + 8.0 * sc;
    c.drawLine(Offset(cx, mastTopY), Offset(cx, mastBottomY), mastPaint);

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + 10.7 * sc),
          width: 16.0 * sc,
          height: 6.4 * sc,
        ),
        Radius.circular(2.0 * sc),
      ),
      fillPaint,
    );

    c.drawCircle(Offset(cx, mastTopY - 1.8 * sc), 3.0 * sc, fillPaint);
    c.drawArc(
      Rect.fromCircle(
          center: Offset(cx, mastTopY - 1.8 * sc), radius: 8.3 * sc),
      -pi * 0.28,
      pi * 0.56,
      false,
      wavePaint,
    );
    c.drawArc(
      Rect.fromCircle(
          center: Offset(cx, mastTopY - 1.8 * sc), radius: 12.2 * sc),
      -pi * 0.28,
      pi * 0.56,
      false,
      wavePaint,
    );

    c.drawCircle(
      Offset(cx - 6.6 * sc, cy + 10.7 * sc),
      1.0 * sc,
      Paint()..color = const Color(0xFF80DEEA),
    );
    c.drawCircle(
      Offset(cx + 6.6 * sc, cy + 10.7 * sc),
      1.0 * sc,
      Paint()..color = const Color(0xFF80DEEA),
    );
  }

  void _paintObjectCarGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;

    // 차체
    final Paint bodyP = Paint()..color = Colors.white;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 1 * sc), width: 20 * sc, height: 11 * sc),
        Radius.circular(2.5 * sc),
      ),
      bodyP,
    );
    // 루프 (어두운)
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 4.5 * sc), width: 13 * sc, height: 7 * sc),
        Radius.circular(2 * sc),
      ),
      Paint()..color = const Color(0xFF222244),
    );
    // 앞유리
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 7 * sc), width: 11 * sc, height: 3 * sc),
        Radius.circular(1 * sc),
      ),
      Paint()..color = const Color(0xFF3D5A80),
    );
    // 휠 아치 (살구색)
    final Paint archP = Paint()..color = const Color(0xFFFFB3A0);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 8 * sc, cy - 7 * sc),
            width: 5 * sc,
            height: 6 * sc),
        archP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 8 * sc, cy - 7 * sc),
            width: 5 * sc,
            height: 6 * sc),
        archP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 8 * sc, cy + 7 * sc),
            width: 5 * sc,
            height: 6 * sc),
        archP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 8 * sc, cy + 7 * sc),
            width: 5 * sc,
            height: 6 * sc),
        archP);
    // 타이어
    final Paint tireP = Paint()..color = const Color(0xFF222222);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 8 * sc, cy - 7 * sc),
            width: 3.5 * sc,
            height: 4.5 * sc),
        tireP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 8 * sc, cy - 7 * sc),
            width: 3.5 * sc,
            height: 4.5 * sc),
        tireP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 8 * sc, cy + 7 * sc),
            width: 3.5 * sc,
            height: 4.5 * sc),
        tireP);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 8 * sc, cy + 7 * sc),
            width: 3.5 * sc,
            height: 4.5 * sc),
        tireP);
    // 헤드라이트
    c.drawRect(
        Rect.fromCenter(
            center: Offset(cx - 5 * sc, cy - 12 * sc),
            width: 4 * sc,
            height: 2 * sc),
        Paint()..color = const Color(0xFFFFF9C4));
    c.drawRect(
        Rect.fromCenter(
            center: Offset(cx + 5 * sc, cy - 12 * sc),
            width: 4 * sc,
            height: 2 * sc),
        Paint()..color = const Color(0xFFFFF9C4));
  }

  void _paintObjectTruckGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;
    final Paint p = Paint()..color = Colors.white;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - 2 * sc, cy - 1 * sc),
            width: 16 * sc,
            height: 13 * sc),
        Radius.circular(1.5 * sc),
      ),
      p,
    );

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 10 * sc, cy + 1 * sc),
            width: 8 * sc,
            height: 10 * sc),
        Radius.circular(2 * sc),
      ),
      p,
    );

    final Paint gp = Paint()..color = const Color(0x44000000);
    c.drawRect(
        Rect.fromCenter(
            center: Offset(cx + 10 * sc, cy - 2 * sc),
            width: 5 * sc,
            height: 5 * sc),
        gp);

    final Paint wp = Paint()..color = const Color(0x77000000);
    c.drawCircle(Offset(cx - 6 * sc, cy + 7.5 * sc), 2.5 * sc, wp);
    c.drawCircle(Offset(cx + 10 * sc, cy + 7.5 * sc), 2.5 * sc, wp);
  }

  void _paintObjectBusGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;
    final Paint p = Paint()..color = Colors.white;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 1 * sc), width: 22 * sc, height: 14 * sc),
        Radius.circular(3 * sc),
      ),
      p,
    );

    final Paint gp = Paint()..color = const Color(0x44000000);
    for (double xOff = -7; xOff <= 7; xOff += 4.7) {
      c.drawRect(
          Rect.fromCenter(
              center: Offset(cx + xOff * sc, cy - 3.5 * sc),
              width: 3.5 * sc,
              height: 5 * sc),
          gp);
    }

    final Paint wp = Paint()..color = const Color(0x77000000);
    c.drawCircle(Offset(cx - 7 * sc, cy + 7.5 * sc), 2.5 * sc, wp);
    c.drawCircle(Offset(cx + 7 * sc, cy + 7.5 * sc), 2.5 * sc, wp);
  }

  void _paintObjectPedestrianGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;
    final Paint p = Paint()..color = Colors.white;

    c.drawCircle(Offset(cx, cy - 8 * sc), 4 * sc, p);

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 1 * sc), width: 8 * sc, height: 12 * sc),
        Radius.circular(2 * sc),
      ),
      p,
    );

    final Paint lp = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * sc
      ..strokeCap = StrokeCap.round;

    c.drawLine(
        Offset(cx - 5 * sc, cy - 3 * sc), Offset(cx - 8 * sc, cy + 3 * sc), lp);
    c.drawLine(
        Offset(cx + 5 * sc, cy - 3 * sc), Offset(cx + 8 * sc, cy + 3 * sc), lp);

    c.drawLine(Offset(cx - 2 * sc, cy + 7 * sc),
        Offset(cx - 4 * sc, cy + 14 * sc), lp);
    c.drawLine(Offset(cx + 2 * sc, cy + 7 * sc),
        Offset(cx + 4 * sc, cy + 14 * sc), lp);
  }

  void _paintObjectMotorcycleGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;

    final Paint wheelStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * sc;
    c.drawCircle(Offset(cx - 7 * sc, cy + 5 * sc), 5 * sc, wheelStroke);
    c.drawCircle(Offset(cx + 7 * sc, cy + 5 * sc), 5 * sc, wheelStroke);

    final Paint framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * sc
      ..strokeCap = StrokeCap.round;
    c.drawLine(
        Offset(cx - 7 * sc, cy + 5 * sc), Offset(cx, cy - 3 * sc), framePaint);
    c.drawLine(
        Offset(cx + 7 * sc, cy + 5 * sc), Offset(cx, cy - 3 * sc), framePaint);

    c.drawCircle(
        Offset(cx, cy - 8 * sc), 3.5 * sc, Paint()..color = Colors.white);

    c.drawLine(Offset(cx + 7 * sc, cy + 5 * sc),
        Offset(cx + 10 * sc, cy - 2 * sc), framePaint);
  }

  void _paintObjectUnknownGlyph(Canvas c, double s) {
    _paintText(c, s, '?', max(14, s * 0.50), Colors.white);
  }

  void _paintObjectGlyph(Canvas c, double s, int objectType) {
    switch (objectType) {
      case 1:
        _paintObjectCarGlyph(c, s);
        break;
      case 2:
        _paintObjectTruckGlyph(c, s);
        break;
      case 3:
        _paintObjectBusGlyph(c, s);
        break;
      case 4:
        _paintObjectPedestrianGlyph(c, s);
        break;
      case 5:
        _paintObjectMotorcycleGlyph(c, s);
        break;
      default:
        _paintObjectUnknownGlyph(c, s);
        break;
    }
  }

  int _resolveObjectIconSizePx({
    required double mapWidth,
    required double mapHeight,
  }) {
    // 업계 표준 기준: zoom 15 = 44px (Uber/Kakao T 수준), 지수 0.22로 완만하게 스케일
    // zoom 13 → ~33px, zoom 15 → 44px, zoom 17 → ~59px(clamp 58), zoom 19+ → 60px(clamp)
    const double refZoom = 15.0;
    const double refBase = 44.0;
    final double zoomFactor =
        pow(2.0, (_currentMapZoom - refZoom) * 0.22).toDouble();
    return (refBase * zoomFactor).round().clamp(28, 60);
  }

  void _scheduleAdaptiveObjectIconUpdate({
    required double mapWidth,
    required double mapHeight,
  }) {
    if (_disposed || !mounted) return;
    if (mapWidth <= 0 || mapHeight <= 0) return;

    final int desiredSize = _resolveObjectIconSizePx(
      mapWidth: mapWidth,
      mapHeight: mapHeight,
    );
    if (desiredSize == _objectIconSizePx ||
        desiredSize == _lastRequestedObjectIconSizePx) {
      return;
    }

    _lastRequestedObjectIconSizePx = desiredSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      unawaited(_rebuildObjectIconsWithSize(desiredSize));
    });
  }

  Future<void> _rebuildObjectIconsWithSize(int sizePx) async {
    if (_objectIconResizeInFlight) return;
    if (sizePx == _objectIconSizePx && sizePx == _vehicleIconSizePx) return;

    _objectIconResizeInFlight = true;
    try {
      // 객체(감지): 차량의 62% — 시각 계층상 가장 작은 3차 엔티티
      // zoom 15 → ~27px, zoom 17 → ~36px(clamp), max 36px
      final int oPx = (sizePx * 0.62).round().clamp(20, 36);
      final Map<int, BitmapDescriptor> icons = <int, BitmapDescriptor>{};
      for (int t = 0; t <= 5; t++) {
        final Color typeColor = getObjectTypeColor(t);
        icons[t] = await _canvasMarker(
          sizePx: oPx,
          painter: (Canvas c, double s) {
            final double r = s * 0.44;
            _paintShadow(c, s, r);
            _paintBg(c, s, r, typeColor);
            _paintDirectionArrow(c, s);
            _paintObjectGlyph(c, s, t);
          },
        );
      }

      // 차량/인프라/스테이션: sizePx(=베이스 44px 기준)로 비례 계산
      final int vPx = sizePx.clamp(36, 60); // 차량
      final int vsPx = (sizePx * 1.15).round().clamp(42, 68); // 차량 선택: 15% 더 큼
      final int iPx = (sizePx * 0.82).round().clamp(26, 48); // 인프라: 차량의 82%
      final int stPx = (sizePx * 0.78).round().clamp(24, 46); // 스테이션
      final int stsPx = (sizePx * 0.82).round().clamp(26, 48); // 스테이션 선택

      final int vmPx =
          (vPx * _vehicleMovingMarkerScale).round().clamp(vPx + 2, 76);
      final int vmsPx = (vmPx * 1.08).round().clamp(vmPx + 2, 82);
      final BitmapDescriptor newVehicleIcon =
          await _vehicleAssetMarker(sizePx: vPx);
      final BitmapDescriptor newVehicleSelectedIcon =
          await _vehicleAssetMarker(sizePx: vsPx, selected: true);
      final BitmapDescriptor newVehicleMovingIcon =
          await _vehicleAssetMarker(sizePx: vmPx);
      final BitmapDescriptor newVehicleMovingSelectedIcon =
          await _vehicleAssetMarker(sizePx: vmsPx, selected: true);
      final BitmapDescriptor newInfraIcon = await _canvasMarker(
        sizePx: iPx,
        painter: (Canvas c, double s) {
          _paintInfraMarkerBase(
            c,
            s,
            startColor: const Color(0xFF0097A7),
            endColor: const Color(0xFF006064),
            accentColor: const Color(0xFF80DEEA),
          );
          _paintInfraGlyph(c, s);
        },
      );
      final BitmapDescriptor newInfraBlinkIcon = await _canvasMarker(
        sizePx: iPx,
        painter: (Canvas c, double s) {
          _paintInfraMarkerBase(
            c,
            s,
            startColor: const Color(0xFF26A69A),
            endColor: const Color(0xFF00796B),
            accentColor: const Color(0xFFB2DFDB),
            blinking: true,
          );
          _paintInfraGlyph(c, s);
        },
      );

      final List<BitmapDescriptor> newStationIcons = <BitmapDescriptor>[];
      final List<BitmapDescriptor> newStationSelectedIcons =
          <BitmapDescriptor>[];
      for (int i = 0; i < kiapiRoadWaypoints.length; i++) {
        final String lbl = kiapiRoadWaypoints[i].shortLabel;
        final int pinH = (stPx * 160 / 128).round();
        final int pinSH = (stsPx * 160 / 128).round();
        newStationIcons.add(await _canvasMarkerWH(
          widthPx: stPx,
          heightPx: pinH,
          painter: (Canvas c, double w, double h) =>
              _paintStationPin(c, w, h, lbl, false),
        ));
        newStationSelectedIcons.add(await _canvasMarkerWH(
          widthPx: stsPx,
          heightPx: pinSH,
          painter: (Canvas c, double w, double h) =>
              _paintStationPin(c, w, h, lbl, true),
        ));
      }

      if (_disposed || !mounted) return;
      setState(() {
        _objectIcons = icons;
        _objectIconSizePx = sizePx;
        _vehicleIconSizePx = vPx;
        _vehicleIcon = newVehicleIcon;
        _vehicleSelectedIcon = newVehicleSelectedIcon;
        _vehicleMovingIcon = newVehicleMovingIcon;
        _vehicleMovingSelectedIcon = newVehicleMovingSelectedIcon;
        _infraIcon = newInfraIcon;
        _infraBlinkIcon = newInfraBlinkIcon;
        _stationIcons = newStationIcons;
        _stationSelectedIcons = newStationSelectedIcons;
        _staticMarkersBuilt = false;
      });

      _rebuildStaticMarkers();
      if (_entityType == MapEntityType.vehicle) {
        _forceRebuildMarkers();
      } else {
        _buildInfraMarkers();
      }
    } catch (_) {
      if (_disposed || !mounted) return;
      final Map<int, BitmapDescriptor> fallback = <int, BitmapDescriptor>{};
      for (int t = 0; t <= 5; t++) {
        fallback[t] =
            BitmapDescriptor.defaultMarkerWithHue(getObjectTypeHue(t));
      }
      setState(() {
        _objectIcons = fallback;
        _objectIconSizePx = sizePx;
      });
      if (_entityType == MapEntityType.vehicle) {
        _forceRebuildMarkers();
      } else {
        _buildInfraMarkers();
      }
    } finally {
      _objectIconResizeInFlight = false;
    }
  }

  Future<void> _createCustomMarkers() async {
    try {
      _vehicleIcon = await _vehicleAssetMarker(sizePx: 56);
      _vehicleSelectedIcon =
          await _vehicleAssetMarker(sizePx: 64, selected: true);

      _infraIcon = await _canvasMarker(
          sizePx: 56,
          painter: (Canvas c, double s) {
            _paintInfraMarkerBase(
              c,
              s,
              startColor: const Color(0xFF0097A7),
              endColor: const Color(0xFF006064),
              accentColor: const Color(0xFF80DEEA),
            );
            _paintInfraGlyph(c, s);
          });

      _infraBlinkIcon = await _canvasMarker(
          sizePx: 56,
          painter: (Canvas c, double s) {
            _paintInfraMarkerBase(
              c,
              s,
              startColor: const Color(0xFF26A69A),
              endColor: const Color(0xFF00796B),
              accentColor: const Color(0xFFB2DFDB),
              blinking: true,
            );
            _paintInfraGlyph(c, s);
          });

      // 오프라인 인프라 마커: 회색 톤 육각형
      _infraOfflineIcon = await _canvasMarker(
          sizePx: 56,
          painter: (Canvas c, double s) {
            _paintInfraMarkerBase(
              c,
              s,
              startColor: const Color(0xFF607D8B),
              endColor: const Color(0xFF37474F),
              accentColor: const Color(0xFF90A4AE),
            );
            _paintInfraGlyph(c, s);
          });

      // 선택된 오프라인 인프라 마커: 밝은 회색 톤
      _infraOfflineSelectedIcon = await _canvasMarker(
          sizePx: 56,
          painter: (Canvas c, double s) {
            _paintInfraMarkerBase(
              c,
              s,
              startColor: const Color(0xFF78909C),
              endColor: const Color(0xFF455A64),
              accentColor: const Color(0xFFB0BEC5),
              blinking: true,
            );
            _paintInfraGlyph(c, s);
          });

      _stationIcons = <BitmapDescriptor>[];
      _stationSelectedIcons = <BitmapDescriptor>[];

      for (int i = 0; i < kiapiRoadWaypoints.length; i++) {
        final String lbl = kiapiRoadWaypoints[i].shortLabel;
        _stationIcons.add(await _canvasMarkerWH(
          widthPx: 42,
          heightPx: (42 * 160 / 128).round(),
          painter: (Canvas c, double w, double h) =>
              _paintStationPin(c, w, h, lbl, false),
        ));
        _stationSelectedIcons.add(await _canvasMarkerWH(
          widthPx: 44,
          heightPx: (44 * 160 / 128).round(),
          painter: (Canvas c, double w, double h) =>
              _paintStationPin(c, w, h, lbl, true),
        ));
      }

      _objectIcons = <int, BitmapDescriptor>{};
      for (int t = 0; t <= 5; t++) {
        final Color typeColor = getObjectTypeColor(t);
        _objectIcons[t] = await _canvasMarker(
            sizePx: _objectIconSizePx,
            painter: (Canvas c, double s) {
              final double r = s * 0.44;
              _paintShadow(c, s, r);
              _paintBg(c, s, r, typeColor);
              _paintDirectionArrow(c, s);
              _paintObjectGlyph(c, s, t);
            });
      }

      _staticMarkersBuilt = false;
      _rebuildStaticMarkers();
      _forceRebuildMarkers();

      if (kDebugMode) debugPrint('[MAP] Custom markers created');
    } catch (e) {
      if (kDebugMode) debugPrint('[MAP] Marker creation fallback: $e');

      _vehicleIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _vehicleSelectedIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _infraIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _infraBlinkIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

      _stationIcons = List<BitmapDescriptor>.generate(
        kiapiRoadWaypoints.length,
        (_) =>
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );
      _infraOfflineIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      _infraOfflineSelectedIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _objectIcons = <int, BitmapDescriptor>{};
      for (int t = 0; t <= 5; t++) {
        _objectIcons[t] =
            BitmapDescriptor.defaultMarkerWithHue(getObjectTypeHue(t));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        _buildContent(context),
        // DashboardController entity type 변경을 감지하는 숨김 위젯 (0px)
        if (Get.isRegistered<DashboardController>())
          GetBuilder<DashboardController>(
            builder: (DashboardController dashCtrl) {
              final FmsEntityType dashType = dashCtrl.currentEntityType;
              if (dashType != _lastDashEntityType) {
                _lastDashEntityType = dashType;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _syncEntityTypeFromDashboard(dashType);
                });
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4F8),
      child: Row(
        children: <Widget>[
          _buildSidePanel(),
          AnimatedContainer(
            duration: _sidePanelAnimationDuration,
            curve: Curves.easeInOutCubic,
            width: _isSidePanelCollapsed ? 6 : 10,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      _handleMapViewportSizeChanged(
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                      _scheduleAdaptiveObjectIconUpdate(
                        mapWidth: constraints.maxWidth,
                        mapHeight: constraints.maxHeight,
                      );
                      final bool showTrackingPanel =
                          _shouldShowVehicleTrackingPanel(
                        constraints.maxWidth,
                      );

                      // Flutter Overlay: 컨테이너 크기 + 추적패널 padding 캡쳐
                      final EdgeInsets gmapPadding = EdgeInsets.only(
                        right: showTrackingPanel
                            ? _liveTrackingPanelWidth + 24
                            : 0,
                      );
                      _overlayContainerSize =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      _overlayPadding = gmapPadding;
                      // 다음 프레임에 갱신 (build 도중 ValueNotifier 변경 금지)
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_disposed && mounted) {
                          _updateOverlayCamera(
                            containerSize: _overlayContainerSize,
                            padding: _overlayPadding,
                          );
                        }
                      });

                      return Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: !_mapMounted
                                ? const SizedBox.expand()
                                : GoogleMap(
                                    initialCameraPosition: _initialCamera,
                                    onMapCreated: (GoogleMapController ctrl) {
                                      if (_disposed || !mounted) {
                                        return;
                                      }

                                      _mapController = ctrl;
                                      _mapReady = true;
                                      // 오버레이 카메라 초기값 (initialCamera 로부터)
                                      _updateOverlayCamera(
                                        target: _initialCamera.target,
                                        zoom: _initialCamera.zoom,
                                        bearing: _initialCamera.bearing,
                                      );
                                      if (_entityType == MapEntityType.infra) {
                                        _buildInfraMarkers();
                                      } else {
                                        _forceRebuildMarkers();
                                      }
                                    },
                                    onCameraMoveStarted: () {
                                      _lastCameraMoveMs =
                                          DateTime.now().millisecondsSinceEpoch;
                                    },
                                    onCameraMove: (CameraPosition pos) {
                                      _currentCameraTarget = pos.target;
                                      _currentMapZoom = pos.zoom;
                                      // Flutter 오버레이용 카메라 스냅샷 갱신
                                      _updateOverlayCamera(
                                        target: pos.target,
                                        zoom: pos.zoom,
                                        bearing: pos.bearing,
                                      );
                                      // 줌 변화가 0.3 이상이면 마커 아이콘 크기 재계산
                                      if ((_currentMapZoom - _lastBuiltZoom)
                                              .abs() >=
                                          0.3) {
                                        _lastBuiltZoom = _currentMapZoom;
                                        final Size? vp = _lastMapViewportSize;
                                        if (vp != null) {
                                          _scheduleAdaptiveObjectIconUpdate(
                                            mapWidth: vp.width,
                                            mapHeight: vp.height,
                                          );
                                        }
                                      }
                                    },
                                    markers: _markers,
                                    polylines: _polylines,
                                    padding: EdgeInsets.only(
                                      right: showTrackingPanel
                                          ? _liveTrackingPanelWidth + 24
                                          : 0,
                                    ),
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    compassEnabled: false,
                                    // 추적 패널 호버 중 지도 스크롤 비활성화 (어두운 오버레이 방지)
                                    scrollGesturesEnabled: !_panelHovered,
                                    rotateGesturesEnabled: true,
                                    tiltGesturesEnabled: false,
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    mapType: MapType.normal,
                                  ),
                          ),
                          // ============================================================
                          // FLUTTER VEHICLE OVERLAY (google_maps_flutter_web 깜빡임 회피)
                          // ClipRRect 로 지도 경계 밖으로 새는 마커 차단
                          // Wrap in ClipRRect matching map borderRadius so markers
                          // that project outside the visible map area (e.g. into the
                          // vehicle sidebar on the left) are clipped properly.
                          // ============================================================
                          if (_useVehicleOverlay && _mapMounted)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: IgnorePointer(
                                  ignoring: false,
                                  child: VehicleMarkerOverlay(
                                    vehicles: _buildOverlayVehicles(),
                                    cameraSnapshot: _overlayCamera,
                                    onVehicleTap: (int vid, LatLng pos) {
                                      _selectVehicle(
                                        vid,
                                        focusPosition: pos,
                                        followLive: true,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          // Positioned(bottom: 10, left: 10, child: _buildLegend()),
                          Positioned(
                            bottom: 10,
                            right: showTrackingPanel
                                ? _liveTrackingPanelWidth + 22
                                : 10,
                            child: _buildStats(),
                          ),
                          // 팔로우·지도닫기 버튼: 추적 패널 바로 왼쪽에 위치
                          Positioned(
                            top: 12,
                            right: showTrackingPanel
                                ? _liveTrackingPanelWidth + 12
                                : 12,
                            child: _buildMapOverlayButtons(
                              constraints.maxWidth,
                            ),
                          ),
                          if (_realtimeEnabled &&
                              _tracked.isEmpty &&
                              _infraInfo == null)
                            Positioned(
                              top: 56,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: Colors.green.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 3,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Receiving data...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF616161),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (showTrackingPanel)
                            Positioned(
                              top: 12,
                              right: 12,
                              bottom: 12,
                              // MouseRegion: 패널 호버 → 지도 scrollGestures 비활성화
                              child: MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _panelHovered = true),
                                onExit: (_) =>
                                    setState(() => _panelHovered = false),
                                child: Listener(
                                  onPointerSignal: (PointerSignalEvent event) {
                                    if (event is PointerScrollEvent &&
                                        _panelScrollCtrl.hasClients) {
                                      final double delta = event.scrollDelta.dy;
                                      final double maxExtent = _panelScrollCtrl
                                          .position.maxScrollExtent;
                                      final double next =
                                          (_panelScrollCtrl.offset + delta)
                                              .clamp(0.0, maxExtent);
                                      _panelScrollCtrl.jumpTo(next);
                                    }
                                  },
                                  child: _buildVehicleTrackingPanel(),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                _buildDetectedObjectsBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _maybeFollowSelectedVehicle() {
    if (!_cameraFollows) return;
    if (_mapController == null) return;
    if (_entityType != MapEntityType.vehicle) return;
    if (_selectedVehicleId == null) return;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!_isVehicleOnline(_selectedVehicleId!, nowMs: nowMs)) return;

    final VehicleTrackingData? tracking = _tracked[_selectedVehicleId!];
    if (tracking == null) return;

    final LatLng? position =
        tracking.displayPosition ?? tracking.targetPosition;
    if (position == null) return;
    if (!geo.isValidLatLng(position.latitude, position.longitude)) return;

    if (nowMs - _lastVehicleFollowMs < _followCameraThrottleMs) return;
    _lastVehicleFollowMs = nowMs;
    _moveCameraTo(position, zoom: 18);
  }

  void _maybeFollowSelectedInfra() {
    if (!_cameraFollowsInfra) return;
    if (_mapController == null) return;
    if (_entityType != MapEntityType.infra) return;

    final LatLng? position = _infraMarkerPos;
    if (position == null) return;
    if (!geo.isValidLatLng(position.latitude, position.longitude)) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastInfraFollowMs < _followCameraThrottleMs) return;
    _lastInfraFollowMs = nowMs;
    _moveCameraTo(position, zoom: 18);
  }

  Widget _buildSidePanelToggleButton({
    required bool collapsed,
  }) {
    final bool showLabel = !collapsed;
    final Color backgroundColor =
        collapsed ? const Color(0xFF1976D2) : Colors.white;
    final Color borderColor =
        collapsed ? const Color(0xFF1976D2) : const Color(0xFFD5E1EE);
    final Color iconColor = collapsed ? Colors.white : const Color(0xFF1565C0);

    return Semantics(
      button: true,
      label: collapsed ? '패널 펼치기' : '패널 숨기기',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggleSidePanel,
            child: AnimatedContainer(
              duration: _sidePanelAnimationDuration,
              curve: Curves.easeInOutCubic,
              height: 32,
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 10 : 0,
              ),
              constraints: BoxConstraints(
                minWidth: showLabel ? 82 : 28,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 18,
                    color: iconColor,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: showLabel
                        ? Padding(
                            key:
                                const ValueKey<String>('side-panel-hide-label'),
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '숨기기',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF455A64),
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey<String>('side-panel-icon-only'),
                            width: 0,
                            height: 0,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSidePanelContent() {
    return SizedBox(
      width: _sidePanelExpandedWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _entityType == MapEntityType.vehicle ? '차량' : '인프라',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
                const Spacer(),
                _buildSidePanelToggleButton(collapsed: false),
              ],
            ),
          ),
          Expanded(
            child: Listener(
              onPointerSignal: (PointerSignalEvent event) {
                if (event is PointerScrollEvent &&
                    _sideListScrollCtrl.hasClients) {
                  final double delta = event.scrollDelta.dy;
                  final double maxExtent =
                      _sideListScrollCtrl.position.maxScrollExtent;
                  final double next =
                      (_sideListScrollCtrl.offset + delta).clamp(0.0, maxExtent);
                  _sideListScrollCtrl.jumpTo(next);
                }
              },
              child: _entityType == MapEntityType.vehicle
                  ? _buildVehicleList()
                  : _buildInfraList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    final bool collapsed = _isSidePanelCollapsed;

    return AnimatedContainer(
      duration: _sidePanelAnimationDuration,
      curve: Curves.easeInOutCubic,
      width: collapsed ? _sidePanelCollapsedWidth : _sidePanelExpandedWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: collapsed ? 0.0 : 1.0),
              duration: _sidePanelAnimationDuration,
              curve: Curves.easeInOutCubic,
              builder: (
                BuildContext context,
                double value,
                Widget? child,
              ) {
                final double visibleFactor = value.clamp(0.0, 1.0);

                return IgnorePointer(
                  ignoring: visibleFactor < 0.95,
                  child: Opacity(
                    opacity: visibleFactor,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: max(visibleFactor, 0.0001),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: _sidePanelExpandedWidth,
                          maxWidth: _sidePanelExpandedWidth,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: _buildExpandedSidePanelContent(),
            ),
            if (collapsed)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildSidePanelToggleButton(collapsed: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleList() {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final List<int> sorted = _allKnownVehicleIds().toList()..sort();

    if (sorted.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('No vehicles',
              style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        ),
      );
    }

    return ListView.builder(
      controller: _sideListScrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sorted.length,
      itemBuilder: (BuildContext ctx, int idx) {
        final int vid = sorted[idx];
        final bool sel = _selectedVehicleId == vid;
        final bool live = _isVehicleOnline(vid, nowMs: nowMs);
        final LatLng? targetPosition =
            _resolvedVehiclePosition(vid, nowMs: nowMs);
        String speed = '';
        int objCount = 0;
        if (_tracked.containsKey(vid)) {
          final VehicleTrackingData t = _tracked[vid]!;
          final double kph = t.vehicleInfo?.velocityKph ?? 0.0;
          speed = live
              ? ((kph < 1.0) ? '정지' : '${kph.toStringAsFixed(0)} kph')
              : '오프라인';
          objCount = live ? t.objects.length : 0;
        } else {
          speed = '오프라인';
        }

        return InkWell(
          onTap: () {
            if (sel) return;
            _selectVehicle(
              vid,
              focusPosition: targetPosition,
              followLive: live,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFE3F2FD) : Colors.white,
              border: Border(
                left: BorderSide(
                  color: sel ? const Color(0xFF1976D2) : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        sel ? const Color(0xFF1976D2) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.directions_car,
                    size: 16,
                    color: sel ? Colors.white : const Color(0xFF616161),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _vehicleName(vid),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel
                              ? const Color(0xFF1976D2)
                              : const Color(0xFF424242),
                        ),
                      ),
                      // ignore: dead_code
                      if (false)
                        Text(
                          '차량 $vid',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? const Color(0xFF1976D2)
                                : const Color(0xFF424242),
                          ),
                        ),
                      if (speed.isNotEmpty)
                        Text(
                          '차량 $vid | $speed | 객체 $objCount',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9E9E9E)),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: live
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfraList() {
    final List<int> infraIds = _allKnownInfraIds().toList()..sort();

    if (infraIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            '등록된 인프라가 없습니다',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _sideListScrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: infraIds.length,
      itemBuilder: (BuildContext context, int index) {
        final int infraId = infraIds[index];
        final bool selected = _selectedInfraId == infraId;
        final _InfraSnapshot? snapshot = _infraSnapshots[infraId];
        final bool live = snapshot != null;
        final int objectCount =
            selected ? _infraObjects.length : (snapshot?.objectCount ?? 0);
        final LatLng targetPosition =
            snapshot?.position ?? _resolveInfraPosition(infraId);

        return InkWell(
          onTap: () {
            if (!mounted || _disposed) return;
            setState(() {
              _selectedInfraId = infraId;
              _infraInfo = snapshot?.info;
              _infraMarkerPos = targetPosition;
              _infraObjects = <DetectedObject>[];
              _cameraFollows = false;
              _cameraFollowsInfra = true;
            });
            _buildInfraMarkers();
            _moveCameraTo(targetPosition, zoom: 16.0);
            _maybeFollowSelectedInfra();
            unawaited(_pollStatusData());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE8F5E9) : Colors.white,
              border: Border(
                left: BorderSide(
                  color:
                      selected ? const Color(0xFF43A047) : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF43A047)
                        : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.cell_tower,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFF616161),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _infraName(infraId),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF424242),
                        ),
                      ),
                      Text(
                        '인프라 $infraId | ${live ? "온라인" : "오프라인"} | 객체 $objectCount개',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: live
                        ? const Color(0xFF43A047)
                        : const Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _normalizeLabel(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '');
  }

  KiapiWaypointData? _waypointFromLabel(String? rawLabel) {
    final String label = _normalizeLabel(rawLabel ?? '');
    if (label.isEmpty || label == '-') {
      return null;
    }

    for (final KiapiWaypointData waypoint in kiapiRoadWaypoints) {
      final String name = _normalizeLabel(waypoint.name);
      final String shortLabel = _normalizeLabel(waypoint.shortLabel);
      if (label.contains(name) ||
          label.contains(shortLabel) ||
          name.contains(label) ||
          shortLabel.contains(label)) {
        return waypoint;
      }
    }
    return null;
  }

  KiapiWaypointData? _nearestWaypointTo(LatLng? position) {
    if (position == null) {
      return null;
    }

    KiapiWaypointData? best;
    double bestDistance = double.infinity;
    for (final KiapiWaypointData waypoint in kiapiRoadWaypoints) {
      final double distance = geo.haversineMeters(
        position.latitude,
        position.longitude,
        waypoint.lat,
        waypoint.lon,
      );
      if (distance < bestDistance) {
        best = waypoint;
        bestDistance = distance;
      }
    }
    return best;
  }

  ({KiapiWaypointData? waypoint, double? distanceMeters}) _waypointForHeading({
    required LatLng origin,
    required double headingDegrees,
    KiapiWaypointData? exclude,
  }) {
    KiapiWaypointData? bestWaypoint;
    double? bestDistance;
    double bestScore = double.infinity;

    void consider({required bool directionalOnly}) {
      for (final KiapiWaypointData waypoint in kiapiRoadWaypoints) {
        if (exclude != null && waypoint.name == exclude.name) {
          continue;
        }

        final double distance = geo.haversineMeters(
          origin.latitude,
          origin.longitude,
          waypoint.lat,
          waypoint.lon,
        );
        final double bearing = geo.bearingBetween(
          origin.latitude,
          origin.longitude,
          waypoint.lat,
          waypoint.lon,
        );
        final double delta =
            geo.shortestAngleDelta(headingDegrees, bearing).abs();
        if (directionalOnly && delta > 105.0) {
          continue;
        }

        final double score = distance + delta * 18.0;
        if (score < bestScore) {
          bestScore = score;
          bestWaypoint = waypoint;
          bestDistance = distance;
        }
      }
    }

    consider(directionalOnly: true);
    if (bestWaypoint == null) {
      consider(directionalOnly: false);
    }

    return (waypoint: bestWaypoint, distanceMeters: bestDistance);
  }

  Map<int, int> _countObjectTypes(List<DetectedObject> objects) {
    final Map<int, int> counts = <int, int>{};
    for (final DetectedObject object in objects) {
      final int type = (object.objectType ?? 0).clamp(0, 5);
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  String _formatDistanceCompact(double? meters) {
    if (meters == null || !meters.isFinite) {
      return '--';
    }
    if (meters >= 1000.0) {
      final double km = meters / 1000.0;
      return km >= 10.0
          ? '${km.toStringAsFixed(0)} km'
          : '${km.toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatDurationCompact(Duration? duration) {
    if (duration == null) {
      return '--';
    }

    if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes.remainder(60)}분';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}분 ${duration.inSeconds.remainder(60)}초';
    }
    return '${max(1, duration.inSeconds)}초';
  }

  String _formatTimeSinceMs(int? epochMs) {
    if (epochMs == null || epochMs <= 0) {
      return '--';
    }

    final int diffMs = max(0, DateTime.now().millisecondsSinceEpoch - epochMs);
    final Duration diff = Duration(milliseconds: diffMs);
    if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    }
    return '${max(1, diff.inSeconds)}초 전';
  }

  String _formatHeadingLabel(double headingDegrees) {
    const List<String> directions = <String>[
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW',
    ];
    final double normalized = geo.normalizeHeadingDegrees(headingDegrees);
    final int index = ((normalized + 22.5) ~/ 45) % directions.length;
    return '${normalized.round()}° ${directions[index]}';
  }

  String _vehicleTypeLabel(Vehicle? vehicle) {
    final String type = vehicle?.vehicleType?.trim() ?? '';
    return type.isEmpty ? 'Vehicle' : type;
  }

  String _vehicleModelLabel(Vehicle? vehicle) {
    final List<String> parts = <String>[];
    final String make = vehicle?.make?.trim() ?? '';
    final String model = vehicle?.modelName?.trim() ?? '';
    if (make.isNotEmpty) {
      parts.add(make);
    }
    if (model.isNotEmpty && model != make) {
      parts.add(model);
    }
    return parts.isEmpty ? '--' : parts.join(' ');
  }

  Widget _buildTrackingMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF132238),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E7C8F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingDetailRow(
    String label,
    String value, {
    Color valueColor = const Color(0xFF1F2D3D),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B8794),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF132238),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTrackingStageRow({
    required String label,
    required String value,
    required Color accent,
    required bool showConnector,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 18,
          child: Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: accent.withValues(alpha: 0.22),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6E7C8F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF132238),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingInfoPill({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6E7C8F),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectTypeChip(int type, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: getObjectTypeColor(type).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: getObjectTypeColor(type).withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        '${getObjectTypeNameKorean(type)} $count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: getObjectTypeColor(type),
        ),
      ),
    );
  }

  Widget _buildVehicleTrackingPanel() {
    final int? vehicleId = _selectedVehicleId;
    if (vehicleId == null) {
      return const SizedBox.shrink();
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final bool live = _isVehicleOnline(vehicleId, nowMs: nowMs);
    final VehicleTrackingData? tracking = _tracked[vehicleId];
    final Vehicle? vehicle = _vehicleById(vehicleId);
    final Map<String, dynamic>? regEntry = _registryVehicleById(vehicleId);
    final LatLng? currentPosition =
        _resolvedVehiclePosition(vehicleId, nowMs: nowMs);
    final LatLng? basePosition = _registryVehiclePosition(vehicleId);

    final double speedKph = tracking?.vehicleInfo?.velocityKph ?? 0.0;
    final double speedMps =
        tracking?.vehicleInfo?.velocityMps ?? tracking?.retainedSpeedMps ?? 0.0;
    final double heading = geo.normalizeHeadingDegrees(
      tracking?.displayHeading ??
          tracking?.targetHeading ??
          tracking?.vehicleInfo?.orientationHeading ??
          0.0,
    );
    final bool moving =
        live && (speedMps >= _vehiclePredictMinSpeedMps || speedKph >= 1.0);

    final String homeStation =
        regEntry?['home_station']?.toString().trim() ?? '';
    final String registryAddress =
        regEntry?['location_address']?.toString().trim() ?? '';
    final String baseLabel = homeStation.isNotEmpty && homeStation != '-'
        ? homeStation
        : registryAddress.isNotEmpty && registryAddress != '-'
            ? registryAddress
            : _vehicleLocationLabel(vehicleId);

    // ── 역지오코딩 기반 실시간 위치 라벨 ──────────────────────
    final _VehicleLiveTrackingSession? geoSession =
        _selectedVehicleSession?.vehicleId == vehicleId
            ? _selectedVehicleSession
            : null;
    final String? liveCurrentName  = geoSession?.currentLocationName;
    final String? liveDepartureName = geoSession?.departureLocationName;

    // 현재 위치: 역지오코딩 이름 우선, 없으면 가장 가까운 스테이션
    final KiapiWaypointData? currentWaypoint =
        _nearestWaypointTo(currentPosition ?? basePosition);
    final String routeCurrentLabel = liveCurrentName ??
        currentWaypoint?.name ?? baseLabel;

    // 출발지: 역지오코딩 이름 우선, 없으면 registry home station
    final String routeFromLabel = liveDepartureName ??
        (moving
            ? (currentWaypoint?.name ?? baseLabel)
            : baseLabel);

    final KiapiWaypointData? baseWaypoint =
        _waypointFromLabel(baseLabel) ?? _nearestWaypointTo(basePosition);
    final ({KiapiWaypointData? waypoint, double? distanceMeters}) nextWaypoint =
        currentPosition != null
            ? _waypointForHeading(
                origin: currentPosition,
                headingDegrees: heading,
                exclude: _nearestWaypointTo(currentPosition),
              )
            : (waypoint: baseWaypoint, distanceMeters: null);

    double? remainingMeters = nextWaypoint.distanceMeters;
    if (remainingMeters == null &&
        currentPosition != null &&
        nextWaypoint.waypoint != null) {
      remainingMeters = geo.haversineMeters(
        currentPosition.latitude,
        currentPosition.longitude,
        nextWaypoint.waypoint!.lat,
        nextWaypoint.waypoint!.lon,
      );
    }
    final Duration? eta = moving && remainingMeters != null
        ? Duration(
            seconds: max(1, (remainingMeters / max(speedMps, 0.1)).round()),
          )
        : null;

    final List<DetectedObject> currentObjects =
        tracking?.objects ?? <DetectedObject>[];
    final Map<int, int> typeCounts = _countObjectTypes(currentObjects);
    final int currentObjectCount =
        max(currentObjects.length, tracking?.vehicleInfo?.numberOfObjects ?? 0);
    final _VehicleLiveTrackingSession? session =
        _selectedVehicleSession != null &&
                _selectedVehicleSession!.vehicleId == vehicleId
            ? _selectedVehicleSession
            : null;
    final int sessionSeenCount =
        session?.uniqueObjectCount ?? currentObjectCount;

    const List<String> headingDirections = <String>[
      '북',
      '북동',
      '동',
      '남동',
      '남',
      '남서',
      '서',
      '북서',
    ];
    final int headingIndex =
        ((heading + 22.5) ~/ 45) % headingDirections.length;
    final String headingLabel =
        '${heading.round()}° ${headingDirections[headingIndex]}';

    final String stateLabel = !live
        ? '오프라인'
        : moving
            ? '이동 중'
            : '대기 중';
    final Color stateColor = !live
        ? const Color(0xFFE53935)
        : moving
            ? const Color(0xFF2E7D32)
            : const Color(0xFFF9A825);
    final String subtitle = _vehicleModelLabel(vehicle);
    final String lastTelemetry =
        _formatTimeSinceMs(tracking?.vehicleInfo?.timeStampMs);
    final String routeSummaryLabel = routeFromLabel == routeCurrentLabel
        ? routeCurrentLabel
        : '$routeFromLabel → $routeCurrentLabel';

    final List<Widget> objectTypeChips = <Widget>[
      for (final MapEntry<int, int> entry in typeCounts.entries)
        if (entry.value > 0) _buildObjectTypeChip(entry.key, entry.value),
    ];

    return Container(
      width: _liveTrackingPanelWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E5F2)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxHeight < 760;
          final double gap = compact ? 10 : 12;
          final double metricWidth = (constraints.maxWidth - 32 - gap) / 2;
          final double metricHeight = compact ? 88 : 96;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '실시간 추적',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6E7C8F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _vehicleName(vehicleId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF122033),
                            ),
                          ),
                          Text(
                            subtitle == '--' ? '#$vehicleId' : subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7B8794),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '추적 닫기',
                      onPressed: _clearSelectedVehicle,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: stateColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: stateColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '마지막 패킷 $lastTelemetry',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B8794),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    SizedBox(
                      width: metricWidth,
                      height: metricHeight,
                      child: _buildTrackingMetricCard(
                        icon: Icons.speed_rounded,
                        label: '속도',
                        value:
                            live ? '${speedKph.toStringAsFixed(0)} kph' : '--',
                        accent: const Color(0xFF1565C0),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      height: metricHeight,
                      child: _buildTrackingMetricCard(
                        icon: Icons.schedule_rounded,
                        label: '다음 ETA',
                        value: _formatDurationCompact(eta),
                        accent: const Color(0xFF2E7D32),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      height: metricHeight,
                      child: _buildTrackingMetricCard(
                        icon: Icons.search_rounded,
                        label: '실시간 객체',
                        value: '$currentObjectCount',
                        accent: const Color(0xFFEF6C00),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      height: metricHeight,
                      child: _buildTrackingMetricCard(
                        icon: Icons.analytics_outlined,
                        label: '세션 누적',
                        value: '$sessionSeenCount',
                        accent: const Color(0xFF6A1B9A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                // 스크롤 가능한 섹션 영역 (Listener로 맵 스크롤 차단)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _panelScrollCtrl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildTrackingSection(
                          title: '실시간 위치',
                          icon: Icons.location_on_rounded,
                          children: <Widget>[
                            _buildTrackingStageRow(
                              label: '출발',
                              value: routeFromLabel,
                              accent: const Color(0xFF2E7D32),
                              showConnector: true,
                            ),
                            _buildTrackingStageRow(
                              label: '현재',
                              value: routeCurrentLabel,
                              accent: const Color(0xFF1976D2),
                              showConnector: false,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                _buildTrackingInfoPill(
                                  label: '예상 경로',
                                  value: routeSummaryLabel,
                                  accent: const Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 8),
                                _buildTrackingInfoPill(
                                  label: '남은 거리',
                                  value:
                                      _formatDistanceCompact(remainingMeters),
                                  accent: const Color(0xFF2E7D32),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _buildTrackingInfoPill(
                                  label: '예상 시간',
                                  value: _formatDurationCompact(eta),
                                  accent: const Color(0xFFEF6C00),
                                ),
                                const SizedBox(width: 8),
                                _buildTrackingInfoPill(
                                  label: '방향',
                                  value: headingLabel,
                                  accent: const Color(0xFF6A1B9A),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        _buildTrackingSection(
                          title: '감지된 객체',
                          icon: Icons.search_rounded,
                          children: <Widget>[
                            if (objectTypeChips.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: objectTypeChips,
                              )
                            else
                              const Text(
                                '최근 패킷에 감지된 객체가 없습니다.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7B8794),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: gap),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetectedObjectsBar() {
    Widget buildStationChip(int idx) {
      final KiapiWaypointData wp = kiapiRoadWaypoints[idx];
      final bool selected = _selectedStationIdx == idx;

      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _selectStation(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1976D2).withValues(alpha: 0.10)
                : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1976D2).withValues(alpha: 0.55)
                  : const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1976D2).withValues(alpha: 0.18)
                      : const Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  wp.shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? const Color(0xFF1976D2)
                        : const Color(0xFF616161),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildTypeBadge({
      required int type,
      required IconData icon,
    }) {
      final Color color = getObjectTypeColor(type);
      final String label = getObjectTypeShortLabel(type);
      final bool enabled = _visibleObjectTypes.contains(type);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              enabled ? color.withValues(alpha: 0.12) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.60)
                : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon,
                size: 13, color: enabled ? color : const Color(0xFF9E9E9E)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color:
                    enabled ? const Color(0xFF212121) : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> stationChips = <Widget>[
      for (int i = 0; i < kiapiRoadWaypoints.length; i++)
        Tooltip(
          message: kiapiRoadWaypoints[i].name,
          child: buildStationChip(i),
        ),
    ];

    final List<Widget> objectBadges = <Widget>[
      buildTypeBadge(type: 1, icon: Icons.directions_car),
      buildTypeBadge(type: 2, icon: Icons.local_shipping),
      buildTypeBadge(type: 3, icon: Icons.directions_bus),
      buildTypeBadge(type: 4, icon: Icons.directions_walk),
      buildTypeBadge(type: 5, icon: Icons.two_wheeler),
      buildTypeBadge(type: 0, icon: Icons.help_outline),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          // 구간 아이콘
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child:
                Icon(Icons.place_outlined, size: 13, color: Color(0xFFBDBDBD)),
          ),
          ...stationChips,
          // 구분선 칩
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: const Color(0xFFE0E0E0),
          ),
          ...objectBadges,
        ],
      ),
    );
  }

  void _toggleDetectedObjects() {
    _showDetectedObjects = !_showDetectedObjects;
    if (_entityType == MapEntityType.infra) {
      _buildInfraMarkers();
    } else {
      _forceRebuildMarkers();
    }
  }

  // 팔로우·지도닫기 오버레이 버튼 (지도 Stack 내부에 배치)
  Widget _buildMapOverlayButtons(double panelWidth) {
    // DashboardController 없으면 숨김
    if (!Get.isRegistered<DashboardController>())
      return const SizedBox.shrink();
    final DashboardController dash = Get.find<DashboardController>();
    // ★ 2026-06-11: 전체지도 모드에서도 버튼 노출 (이전엔 숨김 → 큰 지도에 버튼 없음 버그).
    //   전체지도일 때 '지도 닫기'는 전체화면 해제(분할 뷰 복귀), 분할 뷰일 땐 지도 패널 닫기.
    final bool fullMap = dash.isFullMapMode;

    // 480px 미만이면 텍스트 없이 아이콘만 표시
    final bool compact = panelWidth < 480;
    final bool on = isAutoFollowOn;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 오토팔로우 토글 버튼
        GestureDetector(
          onTap: toggleAutoFollow,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: on ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  on ? Icons.my_location : Icons.location_disabled_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(width: 5),
                  Text(
                    on ? '팔로우 ON' : '팔로우 OFF',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'pretendard',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 감지 객체 ON/OFF 버튼
        GestureDetector(
          onTap: _toggleDetectedObjects,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _showDetectedObjects
                  ? const Color(0xFF00897B)
                  : const Color(0xFF757575),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _showDetectedObjects
                      ? Icons.visibility
                      : Icons.visibility_off_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(width: 5),
                  Text(
                    _showDetectedObjects ? '객체 ON' : '객체 OFF',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'pretendard',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 지도 닫기 버튼 — Material InkWell + opaque hit test 로 overlay 우선순위 확보
        Material(
          color: const Color(0xFF005CB2),
          borderRadius: BorderRadius.circular(20),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              // 전체지도 모드: 전체화면 해제(분할 뷰 복귀). 분할 뷰: 지도 패널 닫기.
              if (fullMap) {
                dash.disableFullMapMode();
              } else {
                dash.disableMapView();
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 11,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF005CB2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.map_outlined, size: 14, color: Colors.white),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: 5),
                    const Text(
                      '지도 닫기',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'pretendard',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final int totalObj = _entityType == MapEntityType.vehicle
        ? _totalObjectCount()
        : _infraObjects.length;
    final int vCount = _tracked.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_consecutiveErrorCount >= 3) ...<Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            const Text('오프라인',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.red)),
            const SizedBox(width: 10),
          ],
          if (_entityType == MapEntityType.vehicle) ...<Widget>[
            const Icon(Icons.directions_car,
                size: 14, color: Color(0xFF1976D2)),
            const SizedBox(width: 4),
            Text('$vCount',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF424242))),
            const SizedBox(width: 10),
          ],
          const Icon(Icons.visibility, size: 12, color: Color(0xFFFF9800)),
          const SizedBox(width: 4),
          Text('객체 $totalObj',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF424242))),
        ],
      ),
    );
  }
}
