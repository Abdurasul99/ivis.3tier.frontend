import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../model/infra_model.dart';
import '../../model/vehicle_model.dart';
import '../../utils/geo_utils.dart' as geo;
import '../controller/infra_controller.dart';
import '../controller/user_controller.dart';
import '../controller/vehicle_controller.dart';
import '../controller/live_status_controller.dart';
import '../repository/activity_repository.dart';
import '../repository/device_registry_repository.dart';
import '../repository/infra_repository.dart';
import '../repository/vehicle_repository.dart';
import '../repository/weather_repository.dart';
import 'activity_charts_controller.dart';
import 'helper/activity_format_helper.dart';

export '../controller/live_status_controller.dart' show DeviceStatus;

class ActivityCatalogItem {
  final String deviceType;
  final int deviceId;
  final String title;
  final String subtitle;
  final String location;

  const ActivityCatalogItem({
    required this.deviceType,
    required this.deviceId,
    required this.title,
    required this.subtitle,
    required this.location,
  });
}

class ActivityController extends GetxController {
  ActivityController();

  static const Duration _unreadPollInterval = Duration(seconds: 5);
  static const Duration _chartRefreshInterval = Duration(seconds: 60);
  static const Duration _onlineWindow = Duration(minutes: 5);

  final ActivityRepository _repo = ActivityRepository();
  final DeviceRegistryRepository _registryRepo = DeviceRegistryRepository();
  final VehicleRepository _vehicleRepo = VehicleRepository();
  final InfraRepository _infraRepo = InfraRepository();
  final WeatherRepository _weatherRepo = WeatherRepository();

  List<ActivityEventItem> feedEvents = <ActivityEventItem>[];
  int feedTotal = 0;
  bool isFeedLoading = false;
  int feedMinSeverity = 1;

  int unreadCount = 0;
  bool isUnreadPolling = false;

  List<ActivityEventItem> bellEvents = <ActivityEventItem>[];
  bool isBellOpen = false;

  // 전역 차트(이벤트/거리/이용량) 상태/로직은 ActivityChartsController 로 이관 ──
  // View 호환을 위해 아래 getter/method 들이 위임자 역할을 한다.
  ActivityChartsController get _chartsCtrl =>
      Get.find<ActivityChartsController>();

  List<ActivityChartDay> get chartDays => _chartsCtrl.chartDays;
  bool get isChartLoading => _chartsCtrl.isChartLoading;
  DistanceStatsResult? get distanceStats => _chartsCtrl.distanceStats;
  bool get isDistanceLoading => _chartsCtrl.isDistanceLoading;
  int get chartDays_ => _chartsCtrl.chartDays_;
  UsageStatsResult? get usageStats => _chartsCtrl.usageStats;
  bool get isUsageLoading => _chartsCtrl.isUsageLoading;
  String get usagePeriod => _chartsCtrl.usagePeriod;

  List<String> kstDateLabels(int days) => _chartsCtrl.kstDateLabels(days);
  List<ActivityChartDay> chartDaysSlice(int days) =>
      _chartsCtrl.chartDaysSlice(days);
  int get todayEventCount => _chartsCtrl.todayEventCount;
  int get todayOverspeedCount => _chartsCtrl.todayOverspeedCount;

  List<Map<String, dynamic>> registryRows = <Map<String, dynamic>>[];
  bool isCatalogLoading = false;

  String? selectedDeviceType;
  int? selectedDeviceId;

  List<ActivityEventItem> deviceFeedEvents = <ActivityEventItem>[];
  bool isDeviceFeedLoading = false;

  List<ActivityChartDay> deviceChartDays = <ActivityChartDay>[];
  bool isDeviceChartLoading = false;
  List<ActivityChartDay> calendarMonthDays = <ActivityChartDay>[];
  bool isCalendarMonthLoading = false;
  DateTime? selectedCalendarDate;
  List<ActivityEventItem> selectedCalendarDayEvents = <ActivityEventItem>[];
  int selectedCalendarDayTotal = 0;
  bool isCalendarDayLoading = false;

  VehicleInfo? selectedVehicleInfo;
  InfraInfo? selectedInfraInfo;
  // 차량 일별 운행 통계 [{ date_kst, operation_time_min, avg_kph, max_kph }]
  List<Map<String, dynamic>> vehicleDailyOperationStats = <Map<String, dynamic>>[];
  bool isOperationStatsLoading = false;
  // 인프라 일별 감지 객체 합계 데이터 [{ date_kst, total_objects }]
  List<Map<String, dynamic>> infraDailyObjectCounts = <Map<String, dynamic>>[];
  bool isInfraObjectChartLoading = false;
  // 차량 일별 감지 객체 합계 데이터 [{ date_kst, total_objects }]
  List<Map<String, dynamic>> vehicleDailyObjectCounts = <Map<String, dynamic>>[];
  bool isVehicleObjectChartLoading = false;
  // 인프라별 전체 감지 객체 합계 [{ infra_id, total_objects }] - 비교 차트용
  List<Map<String, dynamic>> infraTotalByInfra = <Map<String, dynamic>>[];
  bool isInfraTotalChartLoading = false;
  DistanceStatsResult? selectedDeviceDistanceStats;
  DistanceStatsResult? selectedDeviceDistanceChartStats;
  bool isDeviceDistanceChartLoading = false;
  String selectedDeviceDistanceChartPeriod = 'daily';
  // 운행시간 차트 전용 기간 선택 (거리 차트와 독립)
  String selectedOperationChartPeriod = 'daily';
  // 인프라 감지 객체 차트 전용 기간 선택
  String selectedInfraObjectChartPeriod = 'daily';
  // 차량 감지 객체 차트 전용 기간 선택
  String selectedVehicleObjectChartPeriod = 'daily';
  String selectedVehicleChartMetric = 'distance';
  bool isDeviceSummaryLoading = false;
  ActivityWeatherSummary? selectedWeather;
  bool isWeatherLoading = false;
  String? _weatherCacheKey;
  DateTime? _weatherFetchedAt;
  int _distanceChartRequestId = 0;
  // 마지막 디바이스 분석 갱신 시각 (오프라인 디바이스 갱신 간격 제어)
  DateTime? _lastDeviceAnalyticsAt;
  // 오프라인 디바이스는 10분에 한 번만 갱신
  static const Duration _offlineRefreshInterval = Duration(minutes: 10);

  Timer? _unreadTimer;
  Timer? _dataTimer;

  // 선택된 디바이스가 온라인인지 확인 (LiveStatusController 캐시 우선)
  bool get _isSelectedDeviceOnline {
    final int? deviceId = selectedDeviceId;
    final String? deviceType = selectedDeviceType;
    if (deviceId == null || deviceType == null) return false;
    if (Get.isRegistered<LiveStatusController>()) {
      return Get.find<LiveStatusController>().isDeviceOnline(
        deviceType: deviceType,
        deviceId: deviceId,
        window: _onlineWindow,
      );
    }
    return false;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });

    _unreadTimer = Timer.periodic(_unreadPollInterval, (_) => _pollUnread());
    _dataTimer = Timer.periodic(_chartRefreshInterval, (_) async {
      // 글로벌 차트는 로딩 인디케이터 없이 백그라운드 갱신
      await refreshCharts(silent: true);
      if (selectedDeviceId != null && selectedDeviceType != null) {
        // 오프라인 디바이스: 마지막 갱신으로부터 10분 경과 시에만 갱신
        final bool shouldRefresh = _isSelectedDeviceOnline ||
            _lastDeviceAnalyticsAt == null ||
            DateTime.now().difference(_lastDeviceAnalyticsAt!) >= _offlineRefreshInterval;
        if (shouldRefresh) {
          await refreshSelectedDeviceAnalytics(silent: true);
          _lastDeviceAnalyticsAt = DateTime.now();
        }
      }
    });
  }

  @override
  void onClose() {
    _unreadTimer?.cancel();
    _dataTimer?.cancel();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    await _pollUnread();
    await refreshCatalog();
    await refreshFeed();
    await Future.wait(<Future<void>>[
      refreshCharts(),
      refreshUsageStats(),
    ]);
    if (selectedDeviceId == null) {
      await _autoSelectFirstDevice();
    } else {
      await refreshSelectedDeviceAnalytics();
    }
  }

  Future<void> _pollUnread() async {
    final String token = Get.find<UserController>().accessToken ?? '';
    if (token.isEmpty || isUnreadPolling) return;

    isUnreadPolling = true;
    try {
      unreadCount = await _repo.requestUnreadCount();
      update(); // Update of GetX state after unread count is updated
    } finally {
      isUnreadPolling = false;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait(<Future<void>>[
      refreshCatalog(),
      refreshFeed(),
      refreshCharts(),
      refreshUsageStats(),
      if (selectedDeviceId != null && selectedDeviceType != null) refreshSelectedDeviceAnalytics(),
    ]);
  }

  Future<void> refreshCatalog() async {
    final String token = Get.find<UserController>().accessToken ?? '';
    if (token.isEmpty || isCatalogLoading) return;

    isCatalogLoading = true;
    update();
    try {
      final List<Future<void>> futures = <Future<void>>[
        _loadRegistryRows(),
      ];

      // 항상 최신 목록 가져오기 — isEmpty 조건 제거 (삭제 후에도 즉시 반영)
      if (Get.isRegistered<VehicleController>()) {
        futures.add(Get.find<VehicleController>().reqLoadVehicles().then((_) {}));
      }
      if (Get.isRegistered<InfraController>()) {
        futures.add(Get.find<InfraController>().reqLoadInfraIdentifiers());
      }

      await Future.wait(futures);
      _ensureSelectedDeviceStillExists();
    } finally {
      isCatalogLoading = false;
      update();
    }
  }

  Future<void> _loadRegistryRows() async {
    registryRows = await _registryRepo.requestList();
  }

  Future<void> refreshFeed() async {
    final String token = Get.find<UserController>().accessToken ?? '';
    if (token.isEmpty || isFeedLoading) return;

    isFeedLoading = true;
    update();

    try {
      final result = await _repo.requestEvents(
        limit: 30,
        offset: 0,
        minSeverity: feedMinSeverity > 1 ? feedMinSeverity : null,
      );
      feedEvents = result.items;
      feedTotal = result.totalCount;
    } finally {
      isFeedLoading = false;
      update();
    }
  }

  Future<void> refreshCharts({bool silent = false}) =>
      _chartsCtrl.refreshCharts(silent: silent);

  Future<void> refreshSelectedDeviceAnalytics({bool silent = false}) async {
    final String token = Get.find<UserController>().accessToken ?? '';
    final String? deviceType = selectedDeviceType;
    final int? deviceId = selectedDeviceId;

    if (token.isEmpty || deviceType == null || deviceId == null) return;

    final String selectionKey = '$deviceType:$deviceId';
    final ({int fromMs, int toMs}) calendarWindow = _currentMonthKstWindow();
    final int distanceChartDays = _distanceChartDaysForPeriod(selectedDeviceDistanceChartPeriod);
    final int distanceChartRequestId = ++_distanceChartRequestId;
    if (!silent) {
      isDeviceFeedLoading = true;
      isDeviceChartLoading = true;
      isDeviceDistanceChartLoading = deviceType == 'vehicle';
      isDeviceSummaryLoading = true;
      isCalendarMonthLoading = true;
      update();
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repo.requestEvents(
          deviceType: deviceType,
          deviceId: deviceId,
          limit: 50,
          offset: 0,
        ),
        _repo.requestChartData(
          days: chartDays_,
          deviceType: deviceType,
          deviceId: deviceId,
        ),
        if (deviceType == 'vehicle')
          _repo.requestDistanceStats(
            days: chartDays_,
            vehicleId: deviceId,
            // 거리 데이터만 로드 — runtime은 unawaited(_loadVehicleDailyOperationStats)가 별도 처리
          )
        else
          Future<DistanceStatsResult?>.value(null),
        if (deviceType == 'vehicle')
          _vehicleRepo.requestLatestVehicleInfo(deviceId)
        else
          _infraRepo.requestLatestInfraInfo(deviceId),
        _repo.requestChartData(
          deviceType: deviceType,
          deviceId: deviceId,
          fromMs: calendarWindow.fromMs,
          toMs: calendarWindow.toMs,
        ),
        if (deviceType == 'vehicle' && distanceChartDays != chartDays_)
          _repo.requestDistanceStats(
            days: distanceChartDays,
            vehicleId: deviceId,
          )
        else
          Future<DistanceStatsResult?>.value(null),
      ]);

      if (selectionKey != '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}') {
        return;
      }

      final feedResult = results[0] as ({List<ActivityEventItem> items, int totalCount});
      deviceFeedEvents = feedResult.items;
      deviceChartDays = results[1] as List<ActivityChartDay>;
      final DistanceStatsResult? summaryDistance = results[2] as DistanceStatsResult?;
      final DistanceStatsResult? chartDistance = results[5] as DistanceStatsResult?;
      selectedDeviceDistanceStats = summaryDistance;

      if (deviceType == 'vehicle') {
        selectedVehicleInfo = results[3] as VehicleInfo?;
        selectedInfraInfo = null;
        if (distanceChartRequestId == _distanceChartRequestId) {
          selectedDeviceDistanceChartStats = chartDistance ?? summaryDistance;
        }
        unawaited(_loadVehicleDailyOperationStats(deviceId, distanceChartDays, silent: silent));
        unawaited(_loadVehicleDailyObjectCounts(deviceId, distanceChartDays, silent: silent));
      } else {
        selectedInfraInfo = results[3] as InfraInfo?;
        selectedVehicleInfo = null;
        selectedDeviceDistanceStats = null;
        if (distanceChartRequestId == _distanceChartRequestId) {
          selectedDeviceDistanceChartStats = null;
        }
        // 인프라 선택 시 일별 감지 객체 합계 + 전체 인프라 비교 데이터 비동기 로드
        unawaited(_loadInfraDailyObjectCounts(deviceId, chartDays_, silent: silent));
        unawaited(loadInfraTotalByInfra(days: chartDays_, silent: silent));
      }
      calendarMonthDays = results[4] as List<ActivityChartDay>;

      unawaited(refreshSelectedDeviceWeather(force: true));
    } finally {
      isDeviceFeedLoading = false;
      isDeviceChartLoading = false;
      if (distanceChartRequestId == _distanceChartRequestId) {
        isDeviceDistanceChartLoading = false;
      }
      isDeviceSummaryLoading = false;
      isCalendarMonthLoading = false;
      update();
    }
  }

  Future<void> selectDevice(String deviceType, int deviceId) async {
    selectedDeviceType = deviceType;
    selectedDeviceId = deviceId;
    deviceFeedEvents = <ActivityEventItem>[];
    deviceChartDays = <ActivityChartDay>[];
    calendarMonthDays = <ActivityChartDay>[];
    selectedVehicleInfo = null;
    selectedInfraInfo = null;
    vehicleDailyOperationStats = <Map<String, dynamic>>[];
    vehicleDailyObjectCounts = <Map<String, dynamic>>[];
    infraDailyObjectCounts = <Map<String, dynamic>>[];
    infraTotalByInfra = <Map<String, dynamic>>[];
    selectedDeviceDistanceStats = null;
    selectedDeviceDistanceChartStats = null;
    isDeviceDistanceChartLoading = false;
    _distanceChartRequestId++;
    selectedCalendarDate = null;
    selectedCalendarDayEvents = <ActivityEventItem>[];
    selectedCalendarDayTotal = 0;
    isCalendarDayLoading = false;
    _resetSelectedWeather();
    // 각 차트 기간 초기화
    selectedOperationChartPeriod = 'daily';
    selectedVehicleObjectChartPeriod = 'daily';
    selectedInfraObjectChartPeriod = 'daily';
    _lastDeviceAnalyticsAt = null; // 디바이스 전환 시 즉시 갱신 허용
    update();
    await refreshSelectedDeviceAnalytics();
  }

  void clearDeviceSelection() {
    selectedDeviceType = null;
    selectedDeviceId = null;
    deviceFeedEvents = <ActivityEventItem>[];
    deviceChartDays = <ActivityChartDay>[];
    calendarMonthDays = <ActivityChartDay>[];
    selectedVehicleInfo = null;
    selectedInfraInfo = null;
    vehicleDailyOperationStats = <Map<String, dynamic>>[];
    vehicleDailyObjectCounts = <Map<String, dynamic>>[];
    infraDailyObjectCounts = <Map<String, dynamic>>[];
    infraTotalByInfra = <Map<String, dynamic>>[];
    selectedDeviceDistanceStats = null;
    selectedDeviceDistanceChartStats = null;
    isDeviceDistanceChartLoading = false;
    _distanceChartRequestId++;
    selectedCalendarDate = null;
    selectedCalendarDayEvents = <ActivityEventItem>[];
    selectedCalendarDayTotal = 0;
    isCalendarDayLoading = false;
    _resetSelectedWeather();
    // 각 차트 기간 초기화
    selectedOperationChartPeriod = 'daily';
    selectedVehicleObjectChartPeriod = 'daily';
    selectedInfraObjectChartPeriod = 'daily';
    update();
  }

  Future<void> _autoSelectFirstDevice() async {
    if (vehicleCatalog.isNotEmpty) {
      final ActivityCatalogItem first = vehicleCatalog.first;
      await selectDevice(first.deviceType, first.deviceId);
      return;
    }
    if (infraCatalog.isNotEmpty) {
      final ActivityCatalogItem first = infraCatalog.first;
      await selectDevice(first.deviceType, first.deviceId);
    }
  }

  void _ensureSelectedDeviceStillExists() {
    final bool exists = [...vehicleCatalog, ...infraCatalog].any(
      (ActivityCatalogItem item) =>
          item.deviceType == selectedDeviceType && item.deviceId == selectedDeviceId,
    );

    if (!exists) {
      selectedDeviceType = null;
      selectedDeviceId = null;
      deviceFeedEvents = <ActivityEventItem>[];
      deviceChartDays = <ActivityChartDay>[];
      calendarMonthDays = <ActivityChartDay>[];
      selectedVehicleInfo = null;
      selectedInfraInfo = null;
      selectedDeviceDistanceStats = null;
      selectedDeviceDistanceChartStats = null;
      isDeviceDistanceChartLoading = false;
      _distanceChartRequestId++;
      selectedCalendarDate = null;
      selectedCalendarDayEvents = <ActivityEventItem>[];
      selectedCalendarDayTotal = 0;
      isCalendarDayLoading = false;
      _resetSelectedWeather();
    }
  }

  List<ActivityCatalogItem> get vehicleCatalog {
    final Set<int> ids = <int>{};
    for (final Map<String, dynamic> row in registryRows) {
      if ((row['device_type']?.toString() ?? '') == 'vehicle') {
        final int? id = _parseInt(row['device_id']);
        if (id != null && id > 0) ids.add(id);
      }
    }

    if (Get.isRegistered<VehicleController>()) {
      for (final Vehicle vehicle in Get.find<VehicleController>().vehicles) {
        final int? id = vehicle.vehicleId;
        if (id != null && id > 0) ids.add(id);
      }
    }

    final List<int> sortedIds = ids.toList()..sort();
    return sortedIds.map((int id) => _buildCatalogItem('vehicle', id)).toList();
  }

  List<ActivityCatalogItem> get infraCatalog {
    final Set<int> ids = <int>{};
    for (final Map<String, dynamic> row in registryRows) {
      if ((row['device_type']?.toString() ?? '') == 'infra') {
        final int? id = _parseInt(row['device_id']);
        if (id != null && id > 0) ids.add(id);
      }
    }

    if (Get.isRegistered<InfraController>()) {
      ids.addAll(Get.find<InfraController>().infraIdentifiers.where((int id) => id > 0));
    }

    final List<int> sortedIds = ids.toList()..sort();
    return sortedIds.map((int id) => _buildCatalogItem('infra', id)).toList();
  }

  ActivityCatalogItem _buildCatalogItem(String deviceType, int deviceId) {
    final Map<String, dynamic>? reg = _registryEntry(deviceType, deviceId);
    final String registeredName = _cleanString(reg?['name']);
    final String location = _registryLocationLabel(deviceType, deviceId);

    if (deviceType == 'vehicle') {
      Vehicle? vehicle;
      if (Get.isRegistered<VehicleController>()) {
        for (final Vehicle item in Get.find<VehicleController>().vehicles) {
          if (item.vehicleId == deviceId) {
            vehicle = item;
            break;
          }
        }
      }

      final List<String> detailParts = <String>[
        if (_cleanString(vehicle?.vehicleType).isNotEmpty) _cleanString(vehicle?.vehicleType),
        if (_cleanString(vehicle?.modelName).isNotEmpty) _cleanString(vehicle?.modelName),
      ];

      return ActivityCatalogItem(
        deviceType: deviceType,
        deviceId: deviceId,
        title:
            registeredName.isNotEmpty ? registeredName : l10n('차량 $deviceId', 'Vehicle $deviceId'),
        subtitle: detailParts.isNotEmpty
            ? detailParts.join(' / ')
            : l10n('차량 텔레메트리', 'Vehicle telemetry'),
        location: location,
      );
    }

    return ActivityCatalogItem(
      deviceType: deviceType,
      deviceId: deviceId,
      title: registeredName.isNotEmpty ? registeredName : l10n('인프라 $deviceId', 'Infra $deviceId'),
      subtitle: l10n('인프라 노드', 'Infrastructure node'),
      location: location,
    );
  }

  ActivityCatalogItem? get selectedCatalogItem {
    final String? deviceType = selectedDeviceType;
    final int? deviceId = selectedDeviceId;
    if (deviceType == null || deviceId == null) return null;

    final List<ActivityCatalogItem> source =
        deviceType == 'vehicle' ? vehicleCatalog : infraCatalog;
    for (final ActivityCatalogItem item in source) {
      if (item.deviceType == deviceType && item.deviceId == deviceId) {
        return item;
      }
    }
    return null;
  }

  Map<String, dynamic>? get selectedRegistryEntry {
    final String? deviceType = selectedDeviceType;
    final int? deviceId = selectedDeviceId;
    if (deviceType == null || deviceId == null) return null;
    return _registryEntry(deviceType, deviceId);
  }

  String get selectedDeviceTitle {
    final ActivityCatalogItem? item = selectedCatalogItem;
    if (item != null) return item.title;
    if (selectedDeviceType == 'vehicle') {
      return l10n('차량 ${selectedDeviceId ?? '-'}', 'Vehicle ${selectedDeviceId ?? '-'}');
    }
    if (selectedDeviceType == 'infra') {
      return l10n('인프라 ${selectedDeviceId ?? '-'}', 'Infra ${selectedDeviceId ?? '-'}');
    }
    return l10n('활동 분석', 'Activity Analytics');
  }

  String get selectedDeviceSubtitle {
    final ActivityCatalogItem? item = selectedCatalogItem;
    if (item != null) return item.subtitle;
    return selectedDeviceType == 'vehicle'
        ? l10n('차량 분석', 'Vehicle analytics')
        : selectedDeviceType == 'infra'
            ? l10n('인프라 분석', 'Infrastructure analytics')
            : l10n('디바이스를 선택하세요', 'Select a device');
  }

  String get selectedLocationLabel {
    // 1순위: 카카오 역지오코딩으로 얻은 실시간 차량 위치명
    final String? liveLocation = selectedWeather?.locationName;
    if (liveLocation != null && liveLocation.isNotEmpty) return liveLocation;
    // 2순위: device_registry 등록 주소 (고정값)
    final String location = _registryLocationLabel(selectedDeviceType, selectedDeviceId);
    return location.isEmpty ? l10n('등록된 위치 없음', 'No registered location') : location;
  }

  double? get selectedLatitude {
    final Map<String, dynamic>? reg = selectedRegistryEntry;
    final double? regLat = _parseDouble(reg?['location_lat']);
    final double? regLng = _parseDouble(reg?['location_lng']);

    if (selectedDeviceType == 'vehicle') {
      final double? rawX = selectedVehicleInfo?.positionX;
      final double? rawY = selectedVehicleInfo?.positionY;
      if (rawX != null && rawY != null) {
        if (geo.isValidUtmCoordinate(rawX, rawY)) {
          final geo.Wgs84Coordinate wgs = geo.convertUtmZone52NToWgs84(
            eastingMeters: rawX,
            northingMeters: rawY,
          );
          return wgs.latitudeDegrees;
        }
        if (geo.isValidLatLng(rawX, rawY)) return rawX;
        if (geo.isValidLatLng(rawY, rawX)) return rawY;
      }
    }

    if (regLat != null && regLng != null && geo.isValidLatLng(regLat, regLng)) {
      return regLat;
    }
    return null;
  }

  double? get selectedLongitude {
    final Map<String, dynamic>? reg = selectedRegistryEntry;
    final double? regLat = _parseDouble(reg?['location_lat']);
    final double? regLng = _parseDouble(reg?['location_lng']);

    if (selectedDeviceType == 'vehicle') {
      final double? rawX = selectedVehicleInfo?.positionX;
      final double? rawY = selectedVehicleInfo?.positionY;
      if (rawX != null && rawY != null) {
        if (geo.isValidUtmCoordinate(rawX, rawY)) {
          final geo.Wgs84Coordinate wgs = geo.convertUtmZone52NToWgs84(
            eastingMeters: rawX,
            northingMeters: rawY,
          );
          return wgs.longitudeDegrees;
        }
        if (geo.isValidLatLng(rawX, rawY)) return rawY;
        if (geo.isValidLatLng(rawY, rawX)) return rawX;
      }
    }

    if (regLat != null && regLng != null && geo.isValidLatLng(regLat, regLng)) {
      return regLng;
    }
    return null;
  }

  String get selectedCoordinateLabel {
    final double? lat = selectedLatitude;
    final double? lng = selectedLongitude;
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }

    if (selectedDeviceType == 'vehicle') {
      final double? rawX = selectedVehicleInfo?.positionX;
      final double? rawY = selectedVehicleInfo?.positionY;
      if (rawX != null && rawY != null) {
        return 'UTM ${rawX.toStringAsFixed(1)}, ${rawY.toStringAsFixed(1)}';
      }
    }

    return l10n('좌표 정보 없음', 'Coordinates unavailable');
  }

  int? get selectedLastSeenMs {
    final int? deviceId = selectedDeviceId;
    final String? deviceType = selectedDeviceType;
    if (deviceId != null && deviceType != null && Get.isRegistered<LiveStatusController>()) {
      final int? cached = Get.find<LiveStatusController>()
          .latestTimestampMs(deviceType: deviceType, deviceId: deviceId);
      if (cached != null) return cached;
    }
    if (deviceId != null && deviceType == 'vehicle') {
      return selectedVehicleInfo?.timeStampMs ?? selectedVehicleInfo?.timeStamp;
    }
    if (deviceId != null && deviceType == 'infra') {
      return selectedInfraInfo?.timeStampMs ?? selectedInfraInfo?.timeStamp;
    }
    return deviceFeedEvents.isNotEmpty ? deviceFeedEvents.first.occurredAtMs : null;
  }

  bool get selectedIsOnline {
    final int? lastSeen = selectedLastSeenMs;
    if (lastSeen == null) return false;
    final Duration age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSeen, isUtc: true).toLocal(),
    );
    return age <= _onlineWindow;
  }

  String get selectedLastSeenLabel {
    final int? lastSeen = selectedLastSeenMs;
    if (lastSeen == null) return l10n('최근 텔레메트리 없음', 'No recent telemetry');
    return _relativeTimeFromMs(lastSeen);
  }

  double? get selectedSpeedKph => selectedVehicleInfo?.velocityKph;
  double? get selectedHeadingDeg => selectedVehicleInfo?.orientationHeading;
  int? get selectedObjectCount => selectedDeviceType == 'vehicle'
      ? selectedVehicleInfo?.numberOfObjects
      : selectedInfraInfo?.numberOfObjects;
  int? get selectedNavsat => selectedVehicleInfo?.navsat;

  VehicleDistanceStat? get selectedVehicleDistance {
    if (selectedDeviceType != 'vehicle' || selectedDeviceId == null) {
      return null;
    }

    final List<VehicleDistanceStat> candidates =
        selectedDeviceDistanceStats?.vehicles ?? distanceStats?.vehicles ?? <VehicleDistanceStat>[];

    for (final VehicleDistanceStat stat in candidates) {
      if (stat.vehicleId == selectedDeviceId) return stat;
    }
    return null;
  }

  VehicleDistanceStat? get selectedVehicleDistanceChart {
    if (selectedDeviceType != 'vehicle' || selectedDeviceId == null) {
      return null;
    }

    final List<VehicleDistanceStat> candidates = selectedDeviceDistanceChartStats?.vehicles ??
        selectedDeviceDistanceStats?.vehicles ??
        distanceStats?.vehicles ??
        <VehicleDistanceStat>[];

    for (final VehicleDistanceStat stat in candidates) {
      if (stat.vehicleId == selectedDeviceId) return stat;
    }
    return null;
  }

  Future<void> setSelectedDeviceDistanceChartPeriod(String period) async {
    final String normalized = _normalizeDistanceChartPeriod(period);
    if (selectedDeviceDistanceChartPeriod == normalized) return;
    selectedDeviceDistanceChartPeriod = normalized;
    update();
    await refreshSelectedDeviceDistanceChart();
  }

  // 운행시간 차트 전용 기간 변경 (거리 차트와 독립적으로 동작)
  Future<void> setSelectedOperationChartPeriod(String period) async {
    final String normalized = _normalizeDistanceChartPeriod(period);
    if (selectedOperationChartPeriod == normalized) return;
    selectedOperationChartPeriod = normalized;
    update();
    final int? deviceId = selectedDeviceId;
    if (deviceId == null || selectedDeviceType != 'vehicle') return;
    final int days = _distanceChartDaysForPeriod(normalized);
    await _loadVehicleDailyOperationStats(deviceId, days);
  }

  // 인프라 감지 객체 차트 전용 기간 변경
  Future<void> setSelectedInfraObjectChartPeriod(String period) async {
    final String normalized = _normalizeDistanceChartPeriod(period);
    if (selectedInfraObjectChartPeriod == normalized) return;
    selectedInfraObjectChartPeriod = normalized;
    update();
    final int? deviceId = selectedDeviceId;
    if (deviceId == null || selectedDeviceType != 'infra') return;
    final int days = _distanceChartDaysForPeriod(normalized);
    await _loadInfraDailyObjectCounts(deviceId, days);
  }

  // 차량 감지 객체 차트 전용 기간 변경
  Future<void> setSelectedVehicleObjectChartPeriod(String period) async {
    final String normalized = _normalizeDistanceChartPeriod(period);
    if (selectedVehicleObjectChartPeriod == normalized) return;
    selectedVehicleObjectChartPeriod = normalized;
    update();
    final int? deviceId = selectedDeviceId;
    if (deviceId == null || selectedDeviceType != 'vehicle') return;
    final int days = _distanceChartDaysForPeriod(normalized);
    await _loadVehicleDailyObjectCounts(deviceId, days);
  }

  void setSelectedVehicleChartMetric(String metric) {
    final String normalized = _normalizeVehicleChartMetric(metric);
    if (selectedVehicleChartMetric == normalized) return;
    selectedVehicleChartMetric = normalized;
    update();
  }

  Future<void> refreshSelectedDeviceDistanceChart() async {
    final String token = Get.find<UserController>().accessToken ?? '';
    final String? deviceType = selectedDeviceType;
    final int? deviceId = selectedDeviceId;

    if (deviceType != 'vehicle' || deviceId == null) {
      selectedDeviceDistanceChartStats = null;
      isDeviceDistanceChartLoading = false;
      update();
      return;
    }
    if (token.isEmpty) return;

    final int days = _distanceChartDaysForPeriod(selectedDeviceDistanceChartPeriod);
    if (days == chartDays_ && selectedDeviceDistanceStats != null) {
      selectedDeviceDistanceChartStats = selectedDeviceDistanceStats;
      isDeviceDistanceChartLoading = false;
      update();
      return;
    }

    final int requestId = ++_distanceChartRequestId;
    final String selectionKey = '$deviceType:$deviceId:$selectedDeviceDistanceChartPeriod';

    isDeviceDistanceChartLoading = true;
    update();

    unawaited(_loadVehicleDailyOperationStats(deviceId, days));

    try {
      final DistanceStatsResult result = await _repo.requestDistanceStats(
        days: days,
        vehicleId: deviceId,
      );

      if (requestId != _distanceChartRequestId) return;
      if (selectionKey !=
          '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}:$selectedDeviceDistanceChartPeriod') {
        return;
      }

      selectedDeviceDistanceChartStats = result;
    } finally {
      if (requestId == _distanceChartRequestId &&
          selectionKey ==
              '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}:$selectedDeviceDistanceChartPeriod') {
        isDeviceDistanceChartLoading = false;
        update();
      }
    }
  }

  int _distanceChartDaysForPeriod(String period) =>
      _chartsCtrl.distanceChartDaysForPeriod(period);

  String _normalizeDistanceChartPeriod(String period) =>
      _chartsCtrl.normalizeDistanceChartPeriod(period);

  String _normalizeVehicleChartMetric(String metric) {
    switch (metric) {
      case 'time':
      case 'runtime':
        return 'time';
      case 'distance':
      default:
        return 'distance';
    }
  }

  // 차량 일별 운행 통계 로드
  Future<void> _loadVehicleDailyOperationStats(int vehicleId, int days,
      {bool silent = false}) async {
    if (!silent) {
      isOperationStatsLoading = true;
      update();
    }
    try {
      vehicleDailyOperationStats = await _vehicleRepo.requestDailyOperationStats(
        vehicleId: vehicleId,
        days: days,
      );
    } finally {
      isOperationStatsLoading = false;
      update();
    }
  }

  // 인프라 일별 감지 객체 합계 로드
  Future<void> _loadInfraDailyObjectCounts(int infraId, int days, {bool silent = false}) async {
    if (!silent) {
      isInfraObjectChartLoading = true;
      update();
    }
    try {
      infraDailyObjectCounts = await _infraRepo.requestInfraDailyObjectCounts(
        infraId: infraId,
        days: days,
      );
    } finally {
      isInfraObjectChartLoading = false;
      update();
    }
  }

  // 차량 일별 감지 객체 합계 로드
  Future<void> _loadVehicleDailyObjectCounts(int vehicleId, int days, {bool silent = false}) async {
    if (!silent) {
      isVehicleObjectChartLoading = true;
      update();
    }
    try {
      vehicleDailyObjectCounts = await _vehicleRepo.requestVehicleDailyObjectCounts(
        vehicleId: vehicleId,
        days: days,
      );
    } finally {
      isVehicleObjectChartLoading = false;
      update();
    }
  }

  // 인프라별 전체 감지 객체 합계 로드 (비교 차트용)
  Future<void> loadInfraTotalByInfra({int days = 30, bool silent = false}) async {
    if (!silent) {
      isInfraTotalChartLoading = true;
      update();
    }
    try {
      infraTotalByInfra = await _infraRepo.requestInfraTotalByInfra(days: days);
    } finally {
      isInfraTotalChartLoading = false;
      update();
    }
  }

  Future<void> refreshSelectedDeviceWeather({bool force = false}) async {
    final String? deviceType = selectedDeviceType;
    final int? deviceId = selectedDeviceId;
    final double? latitude = selectedLatitude;
    final double? longitude = selectedLongitude;

    if (deviceType == null || deviceId == null || latitude == null || longitude == null) {
      if (selectedWeather != null ||
          isWeatherLoading ||
          _weatherCacheKey != null ||
          _weatherFetchedAt != null) {
        _resetSelectedWeather();
        update();
      }
      return;
    }

    final String selectionKey = '$deviceType:$deviceId';
    final String cacheKey =
        '$selectionKey:${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}';

    if (!force &&
        selectedWeather != null &&
        _weatherCacheKey == cacheKey &&
        _weatherFetchedAt != null &&
        DateTime.now().difference(_weatherFetchedAt!) < const Duration(minutes: 15)) {
      return;
    }

    if (isWeatherLoading) return;

    isWeatherLoading = true;
    update();

    try {
      final ActivityWeatherSummary? result = await _weatherRepo.requestWeather(
        latitude: latitude,
        longitude: longitude,
      );

      if (selectionKey != '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}') {
        return;
      }

      selectedWeather = result;
      if (result != null) {
        _weatherCacheKey = cacheKey;
        _weatherFetchedAt = DateTime.now();
      } else {
        _weatherCacheKey = null;
        _weatherFetchedAt = null;
      }
    } finally {
      if (selectionKey == '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}') {
        isWeatherLoading = false;
        update();
      }
    }
  }

  List<ActivityChartDay> deviceChartDaysSlice(int days) {
    final Map<String, ActivityChartDay> byDate = <String, ActivityChartDay>{
      for (final ActivityChartDay day in deviceChartDays) day.dateKst: day,
    };

    return kstDateLabels(days).map((String date) {
      return byDate[date] ?? ActivityChartDay(dateKst: date, total: 0, byType: <String, int>{});
    }).toList();
  }

  int get selectedEventCount {
    int total = 0;
    for (final ActivityChartDay day in deviceChartDays) {
      total += day.total;
    }
    return total;
  }

  int get selectedWarningCount {
    int total = 0;
    for (final ActivityChartDay day in deviceChartDays) {
      total += (day.byType['high_speed'] ?? 0);
      total += (day.byType['emergency_stop'] ?? 0);
    }
    return total;
  }

  int get calendarMonthTotalEvents {
    int total = 0;
    for (final ActivityChartDay day in calendarMonthDays) {
      total += day.total;
    }
    return total;
  }

  int get calendarMonthActiveDaysCount {
    int total = 0;
    for (final ActivityChartDay day in calendarMonthDays) {
      if (day.total > 0) total++;
    }
    return total;
  }

  int calendarEventCountForDate(DateTime date) {
    final String key = _formatDate(date);
    for (final ActivityChartDay day in calendarMonthDays) {
      if (day.dateKst == key) return day.total;
    }
    return 0;
  }

  bool isSelectedCalendarDate(DateTime date) {
    final DateTime? current = selectedCalendarDate;
    if (current == null) return false;
    return current.year == date.year && current.month == date.month && current.day == date.day;
  }

  Future<void> openCalendarDayTicket(DateTime date) async {
    final String? deviceType = selectedDeviceType;
    final int? deviceId = selectedDeviceId;
    final String token = Get.find<UserController>().accessToken ?? '';
    if (token.isEmpty || deviceType == null || deviceId == null) return;

    final DateTime normalized = DateTime(date.year, date.month, date.day);
    final String selectionKey = '$deviceType:$deviceId';
    selectedCalendarDate = normalized;
    selectedCalendarDayEvents = <ActivityEventItem>[];
    selectedCalendarDayTotal = 0;
    isCalendarDayLoading = true;
    update();

    try {
      final ({int fromMs, int toMs}) window = _kstDayWindow(normalized);
      final result = await _repo.requestEvents(
        deviceType: deviceType,
        deviceId: deviceId,
        fromMs: window.fromMs,
        toMs: window.toMs,
        limit: 200,
        offset: 0,
      );

      if (selectionKey != '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}') {
        return;
      }
      if (!isSelectedCalendarDate(normalized)) {
        return;
      }

      selectedCalendarDayEvents = result.items;
      selectedCalendarDayTotal = result.totalCount;
    } finally {
      if (selectionKey == '${selectedDeviceType ?? ''}:${selectedDeviceId ?? ''}' &&
          isSelectedCalendarDate(normalized)) {
        isCalendarDayLoading = false;
        update();
      }
    }
  }

  void closeCalendarDayTicket() {
    selectedCalendarDate = null;
    selectedCalendarDayEvents = <ActivityEventItem>[];
    selectedCalendarDayTotal = 0;
    isCalendarDayLoading = false;
    update();
  }

  void setFeedSeverity(int severity) {
    if (feedMinSeverity == severity) return;
    feedMinSeverity = severity;
    refreshFeed();
  }

  // 전역 차트 기간 변경 + (선택 디바이스 있으면) 디바이스 차트도 같이 갱신
  void setChartPeriod(int days) {
    if (!_chartsCtrl.setGlobalChartPeriod(days)) return;
    if (selectedDeviceId != null && selectedDeviceType != null) {
      refreshSelectedDeviceAnalytics();
    }
  }

  Future<void> refreshUsageStats() => _chartsCtrl.refreshUsageStats();
  void setUsagePeriod(String period) => _chartsCtrl.setUsagePeriod(period);

  Future<void> openBell() async {
    isBellOpen = true;
    update();
    try {
      final result = await _repo.requestEvents(minSeverity: 2, limit: 16, offset: 0);
      bellEvents = result.items;
    } finally {
      update();
    }
  }

  void closeBell() {
    isBellOpen = false;
    update();
  }

  Future<void> markRead(int id) async {
    final ActivityEventItem? target = _findEvent(id);
    if (target == null || target.isRead) return;

    await _repo.requestMarkRead(id);
    _setEventReadState(id, true);
    if (target.severity >= 2 && unreadCount > 0) {
      unreadCount--;
    }
    update();
  }

  Future<void> markAllRead() async {
    await _repo.requestMarkAllRead();
    feedEvents =
        feedEvents.map((ActivityEventItem event) => _copyEvent(event, isRead: true)).toList();
    bellEvents =
        bellEvents.map((ActivityEventItem event) => _copyEvent(event, isRead: true)).toList();
    deviceFeedEvents =
        deviceFeedEvents.map((ActivityEventItem event) => _copyEvent(event, isRead: true)).toList();
    unreadCount = 0;
    update();
  }

  ActivityEventItem? _findEvent(int id) {
    for (final ActivityEventItem event in feedEvents) {
      if (event.id == id) return event;
    }
    for (final ActivityEventItem event in bellEvents) {
      if (event.id == id) return event;
    }
    for (final ActivityEventItem event in deviceFeedEvents) {
      if (event.id == id) return event;
    }
    return null;
  }

  void _setEventReadState(int id, bool isRead) {
    feedEvents = feedEvents.map((ActivityEventItem event) {
      return event.id == id ? _copyEvent(event, isRead: isRead) : event;
    }).toList();

    bellEvents = bellEvents.map((ActivityEventItem event) {
      return event.id == id ? _copyEvent(event, isRead: isRead) : event;
    }).toList();

    deviceFeedEvents = deviceFeedEvents.map((ActivityEventItem event) {
      return event.id == id ? _copyEvent(event, isRead: isRead) : event;
    }).toList();
  }

  ActivityEventItem _copyEvent(ActivityEventItem event, {required bool isRead}) {
    return ActivityEventItem(
      id: event.id,
      deviceType: event.deviceType,
      deviceId: event.deviceId,
      eventType: event.eventType,
      severity: event.severity,
      title: event.title,
      subtitle: event.subtitle,
      stationName: event.stationName,
      speedKph: event.speedKph,
      isRead: isRead,
      occurredAtMs: event.occurredAtMs,
    );
  }

  Map<String, dynamic>? _registryEntry(String? deviceType, int? deviceId) =>
      ActivityFormatHelper.registryEntry(registryRows, deviceType, deviceId);

  String _registryLocationLabel(String? deviceType, int? deviceId) =>
      ActivityFormatHelper.registryLocationLabel(
          registryRows, deviceType, deviceId);

  String _cleanString(dynamic value) =>
      ActivityFormatHelper.cleanString(value);

  int? _parseInt(dynamic value) => ActivityFormatHelper.parseInt(value);

  double? _parseDouble(dynamic value) =>
      ActivityFormatHelper.parseDouble(value);

  void _resetSelectedWeather() {
    selectedWeather = null;
    isWeatherLoading = false;
    _weatherCacheKey = null;
    _weatherFetchedAt = null;
  }

  String _relativeTimeFromMs(int ms) =>
      ActivityFormatHelper.relativeTimeFromMs(ms);

  ({int fromMs, int toMs}) _currentMonthKstWindow() =>
      ActivityFormatHelper.currentMonthKstWindow();

  ({int fromMs, int toMs}) _kstDayWindow(DateTime date) =>
      ActivityFormatHelper.kstDayWindow(date);

  String _formatDate(DateTime date) => ActivityFormatHelper.formatDate(date);
}
