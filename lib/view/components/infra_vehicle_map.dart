import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    final String base = parsed.path.endsWith('/') ? parsed.path.substring(0, parsed.path.length - 1) : parsed.path;
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
  KiapiWaypointData(lat: 35.8714, lon: 128.5960, name: 'Station 0 - Daegu Station', shortLabel: 'S0'),
  KiapiWaypointData(lat: 35.8683, lon: 128.6057, name: 'Station 1 - Dongdaegu', shortLabel: 'S1'),
  KiapiWaypointData(lat: 35.8537, lon: 128.6286, name: 'Station 2 - Suseong', shortLabel: 'S2'),
  KiapiWaypointData(lat: 35.8620, lon: 128.6150, name: 'Station 3 - Beomeo', shortLabel: 'S3'),
  KiapiWaypointData(lat: 35.8750, lon: 128.6100, name: 'Station 4 - Chilseong', shortLabel: 'S4'),
];

const double kiapiCenterLat = 35.8714;
const double kiapiCenterLon = 128.5960;
const double kiapiInfraLat = 35.8714;
const double kiapiInfraLon = 128.5960;

class VehicleTrackingData {
  LatLng? targetPosition;
  LatLng? displayPosition;
  double targetHeading;
  double displayHeading;
  bool hasReceivedFirstPosition;
  VehicleInfo? vehicleInfo;
  List<DetectedObject> objects;
  int lastUpdateMs;

  VehicleTrackingData()
      : targetPosition = null,
        displayPosition = null,
        targetHeading = 0.0,
        displayHeading = 0.0,
        hasReceivedFirstPosition = false,
        vehicleInfo = null,
        objects = <DetectedObject>[],
        lastUpdateMs = 0;
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
      return '오토바이';
    default:
      return '알 수 없음';
  }
}

String getObjectTypeNameKorean(int t) {
  switch (t) {
    case 1:
      return '\uC2B9\uC6A9\uCC28';
    case 2:
      return '\uD2B8\uB7ED';
    case 3:
      return '\uBC84\uC2A4';
    case 4:
      return '\uBCF4\uD589\uC790';
    case 5:
      return '\uC774\uB968\uCC28';
    default:
      return '\uBBF8\uD655\uC778';
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
      return '오토바이';
    default:
      return '알 수 없음';
  }
}

class InfraVehicleMapPanel extends StatefulWidget {
  const InfraVehicleMapPanel({super.key});

  @override
  State<InfraVehicleMapPanel> createState() => _InfraVehicleMapPanelState();
}

class _InfraVehicleMapPanelState extends State<InfraVehicleMapPanel> {
  static const CameraPosition _initialCamera = CameraPosition(target: LatLng(kiapiCenterLat, kiapiCenterLon), zoom: 14);

  GoogleMapController? _mapController;

  late final VehicleController _vehicleCtrl;
  late final InfraController _infraCtrl;
  late final ObjectController _objectCtrl;

  bool _disposed = false;
  bool _realtimeEnabled = true;
  final Set<int> _visibleObjectTypes = <int>{0, 1, 2, 3, 4, 5};
  bool _objectsBarExpanded = false;

  MapEntityType _entityType = MapEntityType.vehicle;
  int? _selectedVehicleId;
  int? _selectedInfraId;
  int _selectedStationIdx = 0;
  bool _showWaypoints = false;

  Map<int, VehicleTrackingData> _tracked = <int, VehicleTrackingData>{};

  InfraInfo? _infraInfo;
  List<DetectedObject> _infraObjects = <DetectedObject>[];
  LatLng? _infraMarkerPos;

  Set<Marker> _markers = <Marker>{};
  Set<Polyline> _polylines = <Polyline>{};

  Set<Marker> _staticMarkers = <Marker>{};
  bool _staticMarkersBuilt = false;

  BitmapDescriptor? _vehicleIcon;
  BitmapDescriptor? _vehicleSelectedIcon;
  BitmapDescriptor? _infraIcon;
  List<BitmapDescriptor> _stationIcons = <BitmapDescriptor>[];
  List<BitmapDescriptor> _stationSelectedIcons = <BitmapDescriptor>[];
  List<BitmapDescriptor> _stationLabelIcons = <BitmapDescriptor>[];
  List<BitmapDescriptor> _stationSelectedLabelIcons = <BitmapDescriptor>[];

  Map<int, BitmapDescriptor> _objectIcons = <int, BitmapDescriptor>{};

  Timer? _dbPollTimer;
  static const int _dbPollIntervalMs = 2000;

  Timer? _interpTimer;
  static const int _interpIntervalMs = 16;
  static const double _posLerpFactor = 0.08;
  static const double _headLerpFactor = 0.10;
  static const double _convergenceThreshold = 0.0000002;
  static const double _convergenceHeadingDeg = 0.3;
  static const double _teleportDistM = 2000.0;

  int _lastMarkerRebuildMs = 0;
  static const int _markerRebuildThrottleMs = 60;
  int _markerSeq = 0;
  bool _initialMarkersBuilt = false;

  bool _cameraFollows = false;
  int _lastCameraMoveMs = 0;
  static const int _cameraCooldownMs = 3000;

  List<LatLng> _routePoints = <LatLng>[];
  Map<String, List<LatLng>> _routeCache = <String, List<LatLng>>{};

  int _consecutiveErrorCount = 0;

  final Map<int, List<DetectedObject>> _objectsCacheByVehicleInfoId = <int, List<DetectedObject>>{};
  final Map<int, int> _objectsCacheTimestampMs = <int, int>{};

  @override
  void initState() {
    super.initState();
    _vehicleCtrl = Get.isRegistered<VehicleController>() ? Get.find<VehicleController>() : Get.put(VehicleController());
    _infraCtrl = Get.isRegistered<InfraController>() ? Get.find<InfraController>() : Get.put(InfraController());
    _objectCtrl = Get.isRegistered<ObjectController>() ? Get.find<ObjectController>() : Get.put(ObjectController());

    _startInterpolationTimer();
    _initAsync();
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

    _moveCameraTo(LatLng(wp.lat, wp.lon));
  }

  @override
  void dispose() {
    _disposed = true;
    _dbPollTimer?.cancel();
    _interpTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initAsync() async {
    await _createCustomMarkers();
    if (_disposed) return;

    await _initData();
    if (_disposed) return;

    _startDbPolling();
    _forceRebuildMarkers();
  }

  Future<void> _initData() async {
    if (!_vehicleCtrl.hasToken) {
      await _waitForToken();
    }
    if (_disposed) return;
    await _vehicleCtrl.reqLoadVehicles();
    if (_disposed) return;

    _selectedInfraId = 0;

    await _pollStatusData();

    if (!_disposed && mounted) setState(() {});
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

  Future<void> _pollStatusData() async {
    if (_disposed || !mounted || !_realtimeEnabled) return;

    if (_entityType == MapEntityType.vehicle) {
      await _fetchVehicleStatusFromDb();
    } else {
      await _fetchInfraStatusFromDb();
    }
  }

  Future<List<DetectedObject>> _fetchDetectedObjectsByVehicleInfoId(int vehicleInfoId,
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
              'limit': 1000,
              'offset': 0,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) {
        if (kDebugMode) debugPrint('[POLL] Vehicle status HTTP ${resp.statusCode}');
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

      final Map<int, int> vehicleIdToVehicleInfoId = <int, int>{};
      final Map<int, int> vehicleIdToTimestampMs = <int, int>{};

      for (final dynamic item in vehicleList) {
        if (item is! Map<String, dynamic>) continue;
        final Map<String, dynamic> v = item;

        final int vehicleId = _parseInt(v['vehicle_id']) ?? _parseInt(v['vehicleId']) ?? 0;
        if (vehicleId <= 0) continue;

        final double rawX =
            _parseDouble(v['pos_x_m']) ?? _parseDouble(v['position_x']) ?? _parseDouble(v['positionX']) ?? 0.0;
        final double rawY =
            _parseDouble(v['pos_y_m']) ?? _parseDouble(v['position_y']) ?? _parseDouble(v['positionY']) ?? 0.0;

        final LatLng vehicleLatLng = _convertRawToLatLng(rawX, rawY);
        if (!geo.isValidLatLng(vehicleLatLng.latitude, vehicleLatLng.longitude)) continue;

        final double heading = geo.normalizeHeadingDegrees(_parseDouble(v['heading_deg']) ??
            _parseDouble(v['orientation_heading']) ??
            _parseDouble(v['orientationHeading']) ??
            0.0);

        final double kph =
            _parseDouble(v['kph']) ?? _parseDouble(v['velocity_kph']) ?? _parseDouble(v['velocityKph']) ?? 0.0;
        final double mps =
            _parseDouble(v['mps']) ?? _parseDouble(v['velocity_mps']) ?? _parseDouble(v['velocityMps']) ?? kph / 3.6;

        final int navsat = _parseInt(v['navsat']) ?? 4;
        final int tsMs =
            _parseInt(v['time_stamp_ms']) ?? _parseInt(v['timeStampMs']) ?? _parseInt(v['time_stamp']) ?? nowMs;
        final double posZ =
            _parseDouble(v['pos_z_m']) ?? _parseDouble(v['position_z']) ?? _parseDouble(v['positionZ']) ?? 0.0;

        final int vehicleInfoId = _parseInt(v['id']) ?? 0;

        final VehicleInfo vInfo = VehicleInfo(
          id: vehicleInfoId,
          vehicleId: vehicleId,
          timeStampMs: tsMs,
          navsat: navsat,
          velocityKph: kph,
          velocityMps: mps,
          positionX: vehicleLatLng.latitude,
          positionY: vehicleLatLng.longitude,
          positionZ: posZ,
          orientationHeading: heading,
          numberOfObjects: _parseInt(v['number_of_objects']) ?? 0,
        );

        VehicleTrackingData tracking = _tracked[vehicleId] ?? VehicleTrackingData();
        tracking.vehicleInfo = vInfo;

        if (!tracking.hasReceivedFirstPosition) {
          tracking.targetPosition = vehicleLatLng;
          tracking.displayPosition = vehicleLatLng;
          tracking.targetHeading = heading;
          tracking.displayHeading = heading;
          tracking.hasReceivedFirstPosition = true;
          tracking.lastUpdateMs = nowMs;
        } else {
          final double dist = geo.haversineMeters(
            (tracking.targetPosition ?? vehicleLatLng).latitude,
            (tracking.targetPosition ?? vehicleLatLng).longitude,
            vehicleLatLng.latitude,
            vehicleLatLng.longitude,
          );
          if (dist >= 0.2) {
            tracking.targetPosition = vehicleLatLng;
            tracking.lastUpdateMs = nowMs;
          }
          final double hDelta = geo.shortestAngleDelta(tracking.targetHeading, heading).abs();
          if (hDelta >= 0.5) {
            tracking.targetHeading = heading;
          }
        }

        _tracked[vehicleId] = tracking;

        if (vehicleInfoId > 0) {
          vehicleIdToVehicleInfoId[vehicleId] = vehicleInfoId;
          vehicleIdToTimestampMs[vehicleId] = tsMs;
        }
      }

      final List<int> vehicleIdsToFetch = <int>[];
      for (final MapEntry<int, int> entry in vehicleIdToVehicleInfoId.entries) {
        final int vehicleId = entry.key;
        final int vehicleInfoId = entry.value;
        final int tsMs = vehicleIdToTimestampMs[vehicleId] ?? 0;

        final int cachedTs = _objectsCacheTimestampMs[vehicleInfoId] ?? -1;
        final bool needsFetch = !_objectsCacheByVehicleInfoId.containsKey(vehicleInfoId) || cachedTs != tsMs;

        if (needsFetch) {
          vehicleIdsToFetch.add(vehicleId);
        } else {
          _tracked[vehicleId]?.objects = _objectsCacheByVehicleInfoId[vehicleInfoId] ?? <DetectedObject>[];
        }
      }

      Future<void> runChunk(List<int> chunk) async {
        final List<Future<void>> futures = <Future<void>>[];
        for (final int vehicleId in chunk) {
          final int vehicleInfoId = vehicleIdToVehicleInfoId[vehicleId] ?? 0;
          final int tsMs = vehicleIdToTimestampMs[vehicleId] ?? 0;
          if (vehicleInfoId <= 0) continue;

          futures.add(() async {
            final List<DetectedObject> objects =
                await _fetchDetectedObjectsByVehicleInfoId(vehicleInfoId, vehicleTimestampMs: tsMs);
            _objectsCacheByVehicleInfoId[vehicleInfoId] = objects;
            _objectsCacheTimestampMs[vehicleInfoId] = tsMs;
            final VehicleTrackingData? tracking = _tracked[vehicleId];
            if (tracking != null) {
              tracking.objects = objects;
            }
          }());
        }
        await Future.wait(futures);
      }

      const int maxConcurrency = 6;
      for (int i = 0; i < vehicleIdsToFetch.length; i += maxConcurrency) {
        if (_disposed) break;
        final int end = min(i + maxConcurrency, vehicleIdsToFetch.length);
        await runChunk(vehicleIdsToFetch.sublist(i, end));
      }

      _rebuildMarkersThrottled();
    } catch (e) {
      _consecutiveErrorCount++;
      if (kDebugMode) debugPrint('[POLL] Vehicle status error ($e), consecutive: $_consecutiveErrorCount');
    }
  }

  Future<void> _fetchInfraStatusFromDb() async {
    try {
      final Uri uri = buildApiUri('/api/infra/status');

      final http.Response resp = await http
          .post(
            uri,
            headers: _getAuthHeaders(),
            body: jsonEncode(<String, dynamic>{
              'limit': 1000,
              'offset': 0,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) {
        if (kDebugMode) debugPrint('[POLL] Infra status HTTP ${resp.statusCode}');
        return;
      }

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

      for (final dynamic item in infraList) {
        if (item is! Map<String, dynamic>) continue;
        final Map<String, dynamic> inf = item;

        final int infraId = _parseInt(inf['infra_id']) ?? _parseInt(inf['infraId']) ?? 0;
        final int tsMs = _parseInt(inf['time_stamp_ms']) ?? _parseInt(inf['timeStampMs']) ?? 0;
        final List<DetectedObject> objects =
            _parseObjectsFromJson(inf['objects'] ?? inf['detected_objects'] ?? inf['detectedObjects']);

        LatLng? nextInfraPos;
        final double? rawInfraX =
            _parseDouble(inf['pos_x_m']) ?? _parseDouble(inf['position_x']) ?? _parseDouble(inf['positionX']);
        final double? rawInfraY =
            _parseDouble(inf['pos_y_m']) ?? _parseDouble(inf['position_y']) ?? _parseDouble(inf['positionY']);

        if (rawInfraX != null && rawInfraY != null) {
          final LatLng converted = _convertRawToLatLng(rawInfraX, rawInfraY);
          if (geo.isValidLatLng(converted.latitude, converted.longitude)) {
            nextInfraPos = converted;
          }
        }

        if (nextInfraPos == null && objects.isNotEmpty) {
          double latSum = 0.0;
          double lonSum = 0.0;
          int validCount = 0;
          for (final DetectedObject obj in objects) {
            final double? lat = obj.positionX;
            final double? lon = obj.positionY;
            if (lat == null || lon == null) continue;
            if (!geo.isValidLatLng(lat, lon)) continue;
            latSum += lat;
            lonSum += lon;
            validCount++;
          }
          if (validCount > 0) {
            nextInfraPos = LatLng(latSum / validCount, lonSum / validCount);
          }
        }

        _infraInfo = InfraInfo(
          id: _parseInt(inf['id']) ?? 0,
          infraId: infraId,
          timeStampMs: tsMs,
          numberOfObjects: _parseInt(inf['number_of_objects']) ?? objects.length,
        );
        _infraObjects = objects;
        if (nextInfraPos != null) {
          _infraMarkerPos = nextInfraPos;
        }
      }

      _buildInfraMarkers();
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

  LatLng _convertRawToLatLng(double rawX, double rawY) {
    if (rawX > 1000 && rawY > 1000) {
      if (geo.isValidUtmCoordinate(rawX, rawY)) {
        final geo.Wgs84Coordinate wgs = geo.convertUtmZone52NToWgs84(eastingMeters: rawX, northingMeters: rawY);
        return LatLng(wgs.latitudeDegrees, wgs.longitudeDegrees);
      }
    }
    return LatLng(rawX, rawY);
  }

  List<DetectedObject> _parseObjectsFromJson(dynamic objList) {
    final List<DetectedObject> result = <DetectedObject>[];
    if (objList is! List) return result;

    for (int i = 0; i < objList.length; i++) {
      final dynamic o = objList[i];
      if (o is! Map<String, dynamic>) continue;

      final double rawX =
          _parseDouble(o['position_x']) ?? _parseDouble(o['positionX']) ?? _parseDouble(o['pos_x']) ?? 0.0;
      final double rawY =
          _parseDouble(o['position_y']) ?? _parseDouble(o['positionY']) ?? _parseDouble(o['pos_y']) ?? 0.0;
      final LatLng objLatLng = _convertRawToLatLng(rawX, rawY);
      if (!geo.isValidLatLng(objLatLng.latitude, objLatLng.longitude)) continue;

      final int oType = _parseInt(o['object_type']) ?? _parseInt(o['objectType']) ?? _parseInt(o['type']) ?? 0;

      result.add(DetectedObject(
        detectedObjectId: _parseInt(o['id']) ?? i,
        objectId: _parseInt(o['object_id']) ?? _parseInt(o['objectId']) ?? i,
        age: _parseInt(o['age']) ?? 0,
        score: _parseDouble(o['score']) ?? 0.0,
        objectType: oType,
        width: _parseDouble(o['width']) ?? 0.0,
        depth: _parseDouble(o['depth']) ?? 0.0,
        height: _parseDouble(o['height']) ?? 0.0,
        positionX: objLatLng.latitude,
        positionY: objLatLng.longitude,
        positionZ: _parseDouble(o['position_z']) ?? _parseDouble(o['positionZ']) ?? 0.0,
        orientationHeading: _parseDouble(o['orientation_heading']) ??
            _parseDouble(o['orientationHeading']) ??
            _parseDouble(o['heading']) ??
            0.0,
      ));
    }
    return result;
  }

  void _startInterpolationTimer() {
    _interpTimer?.cancel();
    _interpTimer = Timer.periodic(
      const Duration(milliseconds: _interpIntervalMs),
      (_) => _interpolateStep(),
    );
  }

  void _interpolateStep() {
    if (_disposed || !mounted || !_realtimeEnabled) return;
    if (_entityType != MapEntityType.vehicle) return;
    if (_tracked.isEmpty) return;

    bool anyChanged = false;

    for (final VehicleTrackingData tracking in _tracked.values) {
      if (tracking.targetPosition == null || tracking.displayPosition == null) continue;

      final LatLng target = tracking.targetPosition!;
      final LatLng current = tracking.displayPosition!;

      final double latDiff = (target.latitude - current.latitude).abs();
      final double lonDiff = (target.longitude - current.longitude).abs();
      final double headDelta = geo.shortestAngleDelta(tracking.displayHeading, tracking.targetHeading);

      final bool posConverged = latDiff < _convergenceThreshold && lonDiff < _convergenceThreshold;
      final bool headConverged = headDelta.abs() < _convergenceHeadingDeg;

      if (posConverged && headConverged) continue;

      final double dist = geo.haversineMeters(current.latitude, current.longitude, target.latitude, target.longitude);

      if (dist > _teleportDistM) {
        tracking.displayPosition = target;
        tracking.displayHeading = tracking.targetHeading;
        anyChanged = true;
        continue;
      }

      if (dist < 0.5) {
        if (!posConverged) {
          tracking.displayPosition = target;
          anyChanged = true;
        }
        if (!headConverged) {
          tracking.displayHeading = tracking.targetHeading;
          anyChanged = true;
        }
        continue;
      }

      final double factor = dist > 200.0
          ? 0.04
          : dist > 100.0
              ? 0.06
              : dist > 30.0
                  ? 0.08
                  : dist > 5.0
                      ? _posLerpFactor
                      : 0.20;

      final double newLat = current.latitude + (target.latitude - current.latitude) * factor;
      final double newLon = current.longitude + (target.longitude - current.longitude) * factor;
      tracking.displayPosition = LatLng(newLat, newLon);
      anyChanged = true;

      if (!headConverged) {
        if (headDelta.abs() < 2.0) {
          tracking.displayHeading = tracking.targetHeading;
        } else {
          tracking.displayHeading = geo.normalizeHeadingDegrees(tracking.displayHeading + headDelta * _headLerpFactor);
        }
      }
    }
    if (anyChanged) {
      _rebuildMarkersThrottled();
      _maybeFollowSelectedVehicle();
    }
  }

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
        icon: i == _selectedStationIdx ? _stationSelectedIconFor(i) : _stationIconFor(i),
        anchor: const Offset(0.5, 0.5),
        zIndex: 300.0,
        infoWindow: InfoWindow.noText,
        onTap: () => _selectStation(i),
      ));

      staticMarkers.add(Marker(
        markerId: MarkerId('station_label_$i'),
        position: LatLng(wp.lat, wp.lon),
        icon: i == _selectedStationIdx ? _stationSelectedLabelIconFor(i) : _stationLabelIconFor(i),
        anchor: const Offset(0.5, 1.22),
        zIndex: 301.0,
        infoWindow: InfoWindow.noText,
      ));
    }

    _staticMarkers = staticMarkers;
    _staticMarkersBuilt = true;
  }

  void _rebuildMarkersThrottled() {
    if (_disposed || !mounted) return;
    if (_entityType != MapEntityType.vehicle) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_initialMarkersBuilt && now - _lastMarkerRebuildMs < _markerRebuildThrottleMs) {
      return;
    }
    _lastMarkerRebuildMs = now;

    final Set<Marker> newMarkers = <Marker>{};

    final BitmapDescriptor normalIcon = _vehicleIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    final BitmapDescriptor selIcon =
        _vehicleSelectedIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    for (final MapEntry<int, VehicleTrackingData> entry in _tracked.entries) {
      final int vid = entry.key;
      final VehicleTrackingData t = entry.value;
      final LatLng? pos = t.displayPosition ?? t.targetPosition;
      if (pos == null) continue;
      if (!geo.isValidLatLng(pos.latitude, pos.longitude)) continue;

      final bool isSel = vid == _selectedVehicleId;
      _markerSeq++;

      newMarkers.add(Marker(
        markerId: MarkerId('vehicle_$vid'),
        position: pos,
        icon: isSel ? selIcon : normalIcon,
        anchor: const Offset(0.5, 0.5),
        rotation: geo.normalizeHeadingDegrees(t.displayHeading),
        flat: true,
        zIndex: isSel ? 1000.0 : 900.0,
        infoWindow: InfoWindow.noText,
        onTap: () {
          if (_disposed || !mounted) return;
          setState(() {
            _selectedVehicleId = vid;
          });
          _moveCameraTo(pos);
        },
      ));

      for (int oi = 0; oi < t.objects.length; oi++) {
        final DetectedObject obj = t.objects[oi];
        final double? oLat = obj.positionX;
        final double? oLon = obj.positionY;
        if (oLat == null || oLon == null) continue;
        if (!geo.isValidLatLng(oLat, oLon)) continue;

        final int oType = obj.objectType ?? 0;
        if (!_isObjectTypeVisible(oType)) continue;

        final double oHeading = obj.orientationHeading ?? 0.0;

        newMarkers.add(Marker(
          markerId: MarkerId('obj_v${vid}_$oi'),
          position: LatLng(oLat, oLon),
          icon: _objectIconFor(oType),
          anchor: const Offset(0.5, 0.5),
          rotation: geo.normalizeHeadingDegrees(oHeading),
          flat: true,
          zIndex: 1100.0 + oi.toDouble(),
          infoWindow: InfoWindow.noText,
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
    if (_disposed || !mounted) return;

    final Set<Marker> newMarkers = <Marker>{};

    final BitmapDescriptor iIcon = _infraIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

    newMarkers.add(Marker(
      markerId: const MarkerId('infra_fixed'),
      position: _infraMarkerPos ?? const LatLng(kiapiInfraLat, kiapiInfraLon),
      icon: iIcon,
      anchor: const Offset(0.5, 0.5),
      zIndex: 900.0,
      infoWindow: InfoWindow.noText,
    ));

    for (int i = 0; i < _infraObjects.length; i++) {
      final DetectedObject obj = _infraObjects[i];
      final double? oLat = obj.positionX;
      final double? oLon = obj.positionY;
      if (oLat == null || oLon == null) continue;
      if (!geo.isValidLatLng(oLat, oLon)) continue;

      final int oType = obj.objectType ?? 0;
      if (!_isObjectTypeVisible(oType)) continue;
      final double oHeading = obj.orientationHeading ?? 0.0;

      newMarkers.add(Marker(
        markerId: MarkerId('infra_obj_$i'),
        position: LatLng(oLat, oLon),
        icon: _objectIconFor(oType),
        anchor: const Offset(0.5, 0.5),
        rotation: geo.normalizeHeadingDegrees(oHeading),
        flat: true,
        zIndex: 1100.0 + i.toDouble(),
        infoWindow: InfoWindow.noText,
      ));
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

  BitmapDescriptor _stationLabelIconFor(int idx) {
    if (_stationLabelIcons.isNotEmpty && idx < _stationLabelIcons.length) {
      return _stationLabelIcons[idx];
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }

  BitmapDescriptor _stationSelectedIconFor(int idx) {
    if (_stationSelectedIcons.isNotEmpty && idx < _stationSelectedIcons.length) {
      return _stationSelectedIcons[idx];
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  BitmapDescriptor _stationSelectedLabelIconFor(int idx) {
    if (_stationSelectedLabelIcons.isNotEmpty && idx < _stationSelectedLabelIcons.length) {
      return _stationSelectedLabelIcons[idx];
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

  void _moveCameraTo(LatLng pos) {
    if (_mapController != null && geo.isValidLatLng(pos.latitude, pos.longitude)) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
    }
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

  Future<BitmapDescriptor> _canvasMarker({
    required int sizePx,
    required void Function(Canvas c, double s) painter,
  }) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final Canvas canvas = Canvas(rec);
    painter(canvas, sizePx.toDouble());
    final ui.Image img = await rec.endRecording().toImage(sizePx, sizePx);
    final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('marker image bytes null');
    return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _textLabelMarker({
    required String text,
    required Color bgColor,
    required Color textColor,
    double fontSize = 13.0,
    double paddingH = 10.0,
    double paddingV = 6.0,
    double borderRadius = 8.0,
  }) async {
    final TextPainter tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    tp.layout();

    final int w = (tp.width + paddingH * 2).ceil();
    final int h = (tp.height + paddingV * 2 + 8).ceil();

    final ui.PictureRecorder rec = ui.PictureRecorder();
    final Canvas canvas = Canvas(rec);

    final RRect rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble() - 8),
      Radius.circular(borderRadius),
    );
    final Paint bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(rr, bgPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rr, borderPaint);

    final Path arrow = Path()
      ..moveTo(w / 2 - 5, h.toDouble() - 8)
      ..lineTo(w / 2.0, h.toDouble())
      ..lineTo(w / 2 + 5, h.toDouble() - 8)
      ..close();
    canvas.drawPath(arrow, bgPaint);

    tp.paint(canvas, Offset(paddingH, paddingV));

    final ui.Image img = await rec.endRecording().toImage(w, h);
    final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('label marker bytes null');
    return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
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

  void _paintVehicleGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 56;
    final Paint p = Paint()..color = Colors.white;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 2 * sc), width: 24 * sc, height: 14 * sc),
        Radius.circular(3 * sc),
      ),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 6 * sc), width: 17 * sc, height: 10 * sc),
        Radius.circular(3 * sc),
      ),
      p,
    );

    final Paint wheelPaint = Paint()..color = const Color(0x88000000);
    c.drawCircle(Offset(cx - 8 * sc, cy + 9 * sc), 3 * sc, wheelPaint);
    c.drawCircle(Offset(cx + 8 * sc, cy + 9 * sc), 3 * sc, wheelPaint);
  }

  void _paintInfraGlyphClean(Canvas canvas, double size) {
    final double centerX = size / 2;
    final double centerY = size / 2;
    final double scale = size / 44;

    final Paint strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * scale
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double mastTopY = centerY - 11 * scale;
    final double mastBottomY = centerY + 10 * scale;

    canvas.drawLine(
      Offset(centerX, mastTopY),
      Offset(centerX, mastBottomY),
      strokePaint,
    );

    final RRect base = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 12 * scale),
        width: 14 * scale,
        height: 6.5 * scale,
      ),
      Radius.circular(2.2 * scale),
    );
    canvas.drawRRect(base, fillPaint);

    canvas.drawCircle(Offset(centerX, mastTopY - 1.5 * scale), 3.0 * scale, fillPaint);

    final Rect wave1 = Rect.fromCircle(center: Offset(centerX, mastTopY - 1.5 * scale), radius: 8.0 * scale);
    final Rect wave2 = Rect.fromCircle(center: Offset(centerX, mastTopY - 1.5 * scale), radius: 12.0 * scale);

    canvas.drawArc(wave1, -pi * 0.20, pi * 0.40, false, strokePaint);
    canvas.drawArc(wave2, -pi * 0.20, pi * 0.40, false, strokePaint);
  }

  void _paintInfraGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 56;
    final Paint p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * sc
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx, cy - 14 * sc), Offset(cx, cy + 14 * sc), p);
    final Paint fp = Paint()..color = Colors.white;
    c.drawCircle(Offset(cx, cy - 16 * sc), 3.5 * sc, fp);
    c.drawArc(Rect.fromCircle(center: Offset(cx, cy - 16 * sc), radius: 10 * sc), -pi * 0.15, pi * 0.30, false, p);
    c.drawArc(Rect.fromCircle(center: Offset(cx, cy - 16 * sc), radius: 15 * sc), -pi * 0.15, pi * 0.30, false, p);
  }

  void _paintObjectCarGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;
    final Paint p = Paint()..color = Colors.white;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 1 * sc), width: 20 * sc, height: 11 * sc),
        Radius.circular(2.5 * sc),
      ),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 5.5 * sc), width: 14 * sc, height: 8 * sc),
        Radius.circular(2.5 * sc),
      ),
      p,
    );

    final Paint wp = Paint()..color = const Color(0x77000000);
    c.drawCircle(Offset(cx - 7 * sc, cy + 7 * sc), 2.5 * sc, wp);
    c.drawCircle(Offset(cx + 7 * sc, cy + 7 * sc), 2.5 * sc, wp);

    final Paint gp = Paint()..color = const Color(0x44000000);
    c.drawRect(Rect.fromCenter(center: Offset(cx - 3.5 * sc, cy - 5.5 * sc), width: 5 * sc, height: 5 * sc), gp);
    c.drawRect(Rect.fromCenter(center: Offset(cx + 3.5 * sc, cy - 5.5 * sc), width: 5 * sc, height: 5 * sc), gp);
  }

  void _paintObjectTruckGlyph(Canvas c, double s) {
    final double cx = s / 2;
    final double cy = s / 2;
    final double sc = s / 48;
    final Paint p = Paint()..color = Colors.white;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 2 * sc, cy - 1 * sc), width: 16 * sc, height: 13 * sc),
        Radius.circular(1.5 * sc),
      ),
      p,
    );

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 10 * sc, cy + 1 * sc), width: 8 * sc, height: 10 * sc),
        Radius.circular(2 * sc),
      ),
      p,
    );

    final Paint gp = Paint()..color = const Color(0x44000000);
    c.drawRect(Rect.fromCenter(center: Offset(cx + 10 * sc, cy - 2 * sc), width: 5 * sc, height: 5 * sc), gp);

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
        Rect.fromCenter(center: Offset(cx, cy - 1 * sc), width: 22 * sc, height: 14 * sc),
        Radius.circular(3 * sc),
      ),
      p,
    );

    final Paint gp = Paint()..color = const Color(0x44000000);
    for (double xOff = -7; xOff <= 7; xOff += 4.7) {
      c.drawRect(Rect.fromCenter(center: Offset(cx + xOff * sc, cy - 3.5 * sc), width: 3.5 * sc, height: 5 * sc), gp);
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
        Rect.fromCenter(center: Offset(cx, cy + 1 * sc), width: 8 * sc, height: 12 * sc),
        Radius.circular(2 * sc),
      ),
      p,
    );

    final Paint lp = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * sc
      ..strokeCap = StrokeCap.round;

    c.drawLine(Offset(cx - 5 * sc, cy - 3 * sc), Offset(cx - 8 * sc, cy + 3 * sc), lp);
    c.drawLine(Offset(cx + 5 * sc, cy - 3 * sc), Offset(cx + 8 * sc, cy + 3 * sc), lp);

    c.drawLine(Offset(cx - 2 * sc, cy + 7 * sc), Offset(cx - 4 * sc, cy + 14 * sc), lp);
    c.drawLine(Offset(cx + 2 * sc, cy + 7 * sc), Offset(cx + 4 * sc, cy + 14 * sc), lp);
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
    c.drawLine(Offset(cx - 7 * sc, cy + 5 * sc), Offset(cx, cy - 3 * sc), framePaint);
    c.drawLine(Offset(cx + 7 * sc, cy + 5 * sc), Offset(cx, cy - 3 * sc), framePaint);

    c.drawCircle(Offset(cx, cy - 8 * sc), 3.5 * sc, Paint()..color = Colors.white);

    c.drawLine(Offset(cx + 7 * sc, cy + 5 * sc), Offset(cx + 10 * sc, cy - 2 * sc), framePaint);
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

  Future<void> _createCustomMarkers() async {
    try {
      _vehicleIcon = await _canvasMarker(
          sizePx: 44,
          painter: (Canvas c, double s) {
            final double r = s * 0.44;
            _paintShadow(c, s, r);
            _paintBg(c, s, r, const Color(0xFF1976D2));
            _paintDirectionArrow(c, s);
            _paintVehicleGlyph(c, s);
          });

      _vehicleSelectedIcon = await _canvasMarker(
          sizePx: 52,
          painter: (Canvas c, double s) {
            final double r = s * 0.46;
            _paintShadow(c, s, r);
            _paintBg(c, s, r, const Color(0xFF0D47A1));
            _paintDirectionArrow(c, s);
            _paintVehicleGlyph(c, s);
          });

      _infraIcon = await _canvasMarker(
          sizePx: 34,
          painter: (Canvas c, double s) {
            final double r = s * 0.44;
            _paintShadow(c, s, r);
            _paintBg(c, s, r, const Color(0xFF43A047));
            _paintInfraGlyph(c, s);
          });

      _stationIcons = <BitmapDescriptor>[];
      _stationSelectedIcons = <BitmapDescriptor>[];

      for (int i = 0; i < kiapiRoadWaypoints.length; i++) {
        _stationIcons.add(await _canvasMarker(
          sizePx: 42,
          painter: (Canvas c, double s) {
            final double r = s * 0.44;
            _paintShadow(c, s, r);
            _paintBg(c, s, r, const Color(0xFF7B1FA2));
            _paintText(c, s, kiapiRoadWaypoints[i].shortLabel, max(15, s * 0.34), Colors.white);
          },
        ));

        _stationSelectedIcons.add(await _canvasMarker(
          sizePx: 44,
          painter: (Canvas c, double s) {
            final double r = s * 0.44;
            _paintShadow(c, s, r);
            _paintBg(c, s, r, const Color(0xFFFFC107));
            _paintText(c, s, kiapiRoadWaypoints[i].shortLabel, max(15, s * 0.34), const Color(0xFF1F1F1F));
          },
        ));
      }

      _stationLabelIcons = <BitmapDescriptor>[];
      _stationSelectedLabelIcons = <BitmapDescriptor>[];

      for (int i = 0; i < kiapiRoadWaypoints.length; i++) {
        _stationLabelIcons.add(await _textLabelMarker(
          text: kiapiRoadWaypoints[i].name,
          bgColor: const Color(0xFF7B1FA2),
          textColor: Colors.white,
          fontSize: 13.0,
          paddingH: 14.0,
          paddingV: 8.0,
          borderRadius: 10.0,
        ));

        _stationSelectedLabelIcons.add(await _textLabelMarker(
          text: kiapiRoadWaypoints[i].name,
          bgColor: const Color(0xFFFFC107),
          textColor: const Color(0xFF1F1F1F),
          fontSize: 13.0,
          paddingH: 14.0,
          paddingV: 8.0,
          borderRadius: 10.0,
        ));
      }

      _objectIcons = <int, BitmapDescriptor>{};
      for (int t = 0; t <= 5; t++) {
        final Color typeColor = getObjectTypeColor(t);
        _objectIcons[t] = await _canvasMarker(
            sizePx: 52,
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

      _vehicleIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _vehicleSelectedIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _infraIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

      _stationIcons = List<BitmapDescriptor>.generate(
        kiapiRoadWaypoints.length,
        (_) => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );
      _stationLabelIcons = List<BitmapDescriptor>.generate(
        kiapiRoadWaypoints.length,
        (_) => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );

      _objectIcons = <int, BitmapDescriptor>{};
      for (int t = 0; t <= 5; t++) {
        _objectIcons[t] = BitmapDescriptor.defaultMarkerWithHue(getObjectTypeHue(t));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4F8),
      child: Row(
        children: <Widget>[
          _buildSidePanel(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMap(
                            initialCameraPosition: _initialCamera,
                            onMapCreated: (GoogleMapController ctrl) {
                              _mapController = ctrl;
                              if (_entityType == MapEntityType.infra) {
                                _buildInfraMarkers();
                              } else {
                                _forceRebuildMarkers();
                              }
                            },
                            onCameraMoveStarted: () {
                              _lastCameraMoveMs = DateTime.now().millisecondsSinceEpoch;
                            },
                            markers: _markers,
                            polylines: _polylines,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            compassEnabled: false,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: false,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapType: MapType.normal,
                          )),
                      Positioned(top: 10, left: 10, child: _buildEntitySegment()),
                      // Positioned(bottom: 10, left: 10, child: _buildLegend()),
                      Positioned(bottom: 10, right: 10, child: _buildStats()),
                      if (_realtimeEnabled && _tracked.isEmpty && _infraInfo == null)
                        Positioned(
                          top: 56,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
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
                                        color: Colors.green.withValues(alpha: 0.5),
                                        blurRadius: 3,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Polling database for data...',
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
                    ],
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

    final VehicleTrackingData? tracking = _tracked[_selectedVehicleId!];
    if (tracking == null) return;

    final LatLng? position = tracking.displayPosition ?? tracking.targetPosition;
    if (position == null) return;
    if (!geo.isValidLatLng(position.latitude, position.longitude)) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    if (nowMs - _lastCameraMoveMs < _cameraCooldownMs) return;

    _lastCameraMoveMs = nowMs;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16),
      ),
    );
  }

  Widget _buildEntitySegment() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildEntityChip(MapEntityType.vehicle, '\uCC28\uB7C9 (Vehicle)'),
          _buildEntityChip(MapEntityType.infra, '\uC778\uD504\uB77C (Infra)'),
        ],
      ),
    );
  }

  Widget _buildEntityChip(MapEntityType type, String label) {
    final bool sel = _entityType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (_entityType == type || _disposed || !mounted) return;
        setState(() {
          _entityType = type;
          _cameraFollows = false;
          _markers = <Marker>{};
          _polylines = <Polyline>{};
          _infraInfo = null;
          _infraObjects = <DetectedObject>[];
          _infraMarkerPos = null;
        });

        if (type == MapEntityType.infra) {
          _buildInfraMarkers();
          _moveCameraTo(const LatLng(kiapiCenterLat, kiapiCenterLon));
        } else {
          _forceRebuildMarkers();
          if (_selectedVehicleId != null && _tracked.containsKey(_selectedVehicleId)) {
            final LatLng? pos = _tracked[_selectedVehicleId!]!.displayPosition;
            if (pos != null) _moveCameraTo(pos);
          }
        }
        _pollStatusData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : const Color(0xFF424242),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
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
                Expanded(
                  child: Text(
                    _entityType == MapEntityType.vehicle ? 'Vehicles' : 'Infrastructure',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
                if (_realtimeEnabled)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _entityType == MapEntityType.vehicle ? _buildVehicleList() : _buildInfraList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    final Set<int> allIds = <int>{};
    for (final Vehicle v in _vehicleCtrl.vehicles) {
      if (v.vehicleId != null) allIds.add(v.vehicleId!);
    }
    allIds.addAll(_tracked.keys);
    final List<int> sorted = allIds.toList()..sort();

    if (sorted.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('No vehicles', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sorted.length,
      itemBuilder: (BuildContext ctx, int idx) {
        final int vid = sorted[idx];
        final bool sel = _selectedVehicleId == vid;
        final bool live = _tracked.containsKey(vid);
        String speed = '';
        int objCount = 0;
        if (live) {
          final VehicleTrackingData t = _tracked[vid]!;
          final double kph = t.vehicleInfo?.velocityKph ?? 0.0;
          speed = (kph < 1.0) ? 'STOP' : '${kph.toStringAsFixed(0)} kph';
          objCount = t.objects.length;
        }

        return InkWell(
          onTap: () {
            if (sel) return;

            setState(() {
              _selectedVehicleId = vid;
              _cameraFollows = true;
              double _currentZoom = 14.0;
            });

            _lastCameraMoveMs = DateTime.now().millisecondsSinceEpoch;

            if (live) {
              final LatLng? pos = _tracked[vid]!.displayPosition ?? _tracked[vid]!.targetPosition;
              if (pos != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: pos, zoom: 18.5),
                  ),
                );
              }
            }

            _forceRebuildMarkers();
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
                    color: sel ? const Color(0xFF1976D2) : const Color(0xFFE0E0E0),
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
                        'Vehicle $vid',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? const Color(0xFF1976D2) : const Color(0xFF424242),
                        ),
                      ),
                      if (speed.isNotEmpty)
                        Text(
                          '$speed | $objCount obj',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                        ),
                    ],
                  ),
                ),
                if (live)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: <Widget>[
        InkWell(
          onTap: () {
            if (!mounted || _disposed) return;
            setState(() {
              _selectedInfraId = 0;
              _infraInfo = null;
              _infraObjects = <DetectedObject>[];
              _infraMarkerPos = null;
              _markers = <Marker>{};
            });
            _buildInfraMarkers();
            _moveCameraTo(const LatLng(kiapiCenterLat, kiapiCenterLon));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              border: Border(left: BorderSide(color: Color(0xFF43A047), width: 4)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.cell_tower, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'KIAPI Sensor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (_infraObjects.isNotEmpty)
                        Text(
                          '${_infraObjects.length} objects',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
            color: selected ? const Color(0xFF1976D2).withValues(alpha: 0.10) : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFF1976D2).withValues(alpha: 0.55) : const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1976D2).withValues(alpha: 0.18) : const Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  wp.shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected ? const Color(0xFF1976D2) : const Color(0xFF616161),
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
          color: enabled ? color.withValues(alpha: 0.12) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.60) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: enabled ? color : const Color(0xFF9E9E9E)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: enabled ? const Color(0xFF212121) : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> stationChips = <Widget>[
      for (int i = 0; i < kiapiRoadWaypoints.length; i++) ...<Widget>[
        Tooltip(
          message: kiapiRoadWaypoints[i].name,
          child: buildStationChip(i),
        ),
        if (i != kiapiRoadWaypoints.length - 1) const SizedBox(width: 6),
      ],
    ];

    final List<Widget> objectBadges = <Widget>[
      buildTypeBadge(type: 1, icon: Icons.directions_car),
      const SizedBox(width: 6),
      buildTypeBadge(type: 2, icon: Icons.local_shipping),
      const SizedBox(width: 6),
      buildTypeBadge(type: 3, icon: Icons.directions_bus),
      const SizedBox(width: 6),
      buildTypeBadge(type: 4, icon: Icons.directions_walk),
      const SizedBox(width: 6),
      buildTypeBadge(type: 5, icon: Icons.two_wheeler),
      const SizedBox(width: 6),
      buildTypeBadge(type: 0, icon: Icons.help_outline),
    ];

    final int visibleCount = _entityType == MapEntityType.vehicle ? _totalObjectCount() : _infraObjects.length;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.place_outlined, size: 14, color: Color(0xFF757575)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: ClipRect(
                    child: Row(
                      children: <Widget>[
                        ...stationChips,
                        const SizedBox(width: 10),
                        Container(width: 1, height: 22, color: const Color(0xFFE0E0E0)),
                        const SizedBox(width: 10),
                        ...objectBadges,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // const SizedBox(width: 10),
          // Text(
          //   '$visibleCount',
          //   style: const TextStyle(
          //     fontSize: 11,
          //     fontWeight: FontWeight.w900,
          //     color: Color(0xFF757575),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _legendItem(Icons.directions_car, const Color(0xFF1976D2), 'Vehicle'),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 2),
            child: Text('Detected Objects:',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF757575))),
          ),
          _legendItem(Icons.directions_car, const Color(0xFF1565C0), '1: Car (\uC2B9\uC6A9\uCC28)', small: true),
          _legendItem(Icons.local_shipping, const Color(0xFFE65100), '2: Truck (\uD2B8\uB7ED)', small: true),
          _legendItem(Icons.directions_bus, const Color(0xFF2E7D32), '3: Bus (\uBC84\uC2A4)', small: true),
          _legendItem(Icons.directions_walk, const Color(0xFFE8A000), '4: Pedestrian (\uBCF4\uD589\uC790)',
              small: true),
          _legendItem(Icons.two_wheeler, const Color(0xFFC62828), '5: Motorcycle (\uC774\uB968\uCC28)', small: true),
          _legendItem(Icons.help_outline, const Color(0xFF757575), '0: Unknown (\uBBF8\uD655\uC778)', small: true),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label, {bool small = false}) {
    final double iSz = small ? 10 : 12;
    final double bSz = small ? 14 : 18;
    final double fSz = small ? 9 : 11;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: small ? 1.5 : 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: bSz,
            height: bSz,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: Icon(icon, size: iSz, color: Colors.white),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: fSz,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final int totalObj = _entityType == MapEntityType.vehicle ? _totalObjectCount() : _infraObjects.length;
    final int vCount = _tracked.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_consecutiveErrorCount >= 3) ...<Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            const Text('OFFLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
            const SizedBox(width: 10),
          ],
          if (_entityType == MapEntityType.vehicle) ...<Widget>[
            const Icon(Icons.directions_car, size: 14, color: Color(0xFF1976D2)),
            const SizedBox(width: 4),
            Text('$vCount',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF424242))),
            const SizedBox(width: 10),
          ],
          const Icon(Icons.visibility, size: 12, color: Color(0xFFFF9800)),
          const SizedBox(width: 4),
          Text('$totalObj obj',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF424242))),
        ],
      ),
    );
  }
}
