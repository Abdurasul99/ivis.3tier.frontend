// dashboard_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/infra_model.dart';
import '../../model/object_model.dart';
import '../../model/vehicle_model.dart';
import 'infra_controller.dart';
import 'object_controller.dart';
import 'user_controller.dart';
import 'vehicle_controller.dart';

enum FmsEntityType { vehicle, infra }

enum AutoUpdateInterval {
  manual,
  oneSecond,
  threeSeconds,
  fiveSeconds,
}

class ObjectTypeUi {
  final String label;
  final IconData iconData;
  const ObjectTypeUi({required this.label, required this.iconData});
}

class DashboardController extends GetxController {
  late final VehicleController _vehicleCtrl;
  late final InfraController _infraCtrl;
  late final ObjectController _objectCtrl;

  VoidCallback? onGridUpdateNeeded;

  FmsEntityType currentEntityType = FmsEntityType.vehicle;
  bool isMapView = true; // 최초 로드 시 지도 항상 표시

  bool initialLoading = true;
  bool isLoading = false;
  bool firstDataArrived = false;
  bool isExporting = false;
  bool isFullMapMode = false;

  int currentPage = 1;
  int totalCount = 0;
  int rowsPerPage = 18;

  String vehicleIdFilter = 'ALL';
  String infraIdFilter = 'ALL';
  String? activeFilterColumn;
  String? activeFilterValue;

  // 날짜 범위 필터
  DateTime? dateFrom;
  DateTime? dateTo;

  int _loadRequestId = 0;

  // ── 페이지 캐시 ──────────────────────────────────────────────────────────
  // 같은 필터/엔티티 조건으로 이미 로드한 페이지를 30초 동안 재사용한다.
  // force:true (새로고침, 필터 변경, 엔티티 변경) 시 전체 무효화.
  final Map<String, _PageCacheEntry> _pageCache = <String, _PageCacheEntry>{};
  static const int _pageCacheMaxEntries = 6;

  String _buildCacheKey(int page) =>
      '${currentEntityType.name}|$vehicleIdFilter|$infraIdFilter'
      '|${activeFilterColumn ?? ""}|${activeFilterValue ?? ""}'
      '|${dateFrom?.millisecondsSinceEpoch ?? ""}|${dateTo?.millisecondsSinceEpoch ?? ""}|$page';

  void _invalidatePageCache() => _pageCache.clear();

  void _putPageCache(int page, List<Map<String, dynamic>> rows, int total) {
    if (_pageCache.length >= _pageCacheMaxEntries) {
      _pageCache.remove(_pageCache.keys.first);
    }
    _pageCache[_buildCacheKey(page)] =
        _PageCacheEntry(rows: rows, totalCount: total);
  }

  _PageCacheEntry? _getPageCache(int page) {
    final _PageCacheEntry? entry = _pageCache[_buildCacheKey(page)];
    if (entry == null) return null;
    if (entry.isStale) {
      _pageCache.remove(_buildCacheKey(page));
      return null;
    }
    return entry;
  }
  // ────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> pageRows = <Map<String, dynamic>>[];
  AutoUpdateInterval currentUpdateInterval = AutoUpdateInterval.manual;
  Timer? _autoUpdateTimer;

  List<String> allVehicleFields = <String>[];
  List<String> allInfraFields = <String>[];
  Set<String> visibleVehicleFields = <String>{};
  Set<String> visibleInfraFields = <String>{};
  List<String> cachedFields = <String>[];
  int get totalPages {
    final int safe = totalCount < 0 ? 0 : totalCount;
    final int pages = (safe + rowsPerPage - 1) ~/ rowsPerPage;
    return pages < 1 ? 1 : pages;
  }

  Set<String> get currentVisibleFields {
    return currentEntityType == FmsEntityType.vehicle
        ? visibleVehicleFields
        : visibleInfraFields;
  }

  List<String> get currentAllFields {
    return currentEntityType == FmsEntityType.vehicle
        ? allVehicleFields
        : allInfraFields;
  }

  VehicleController get vehicleCtrl => _vehicleCtrl;
  InfraController get infraCtrl => _infraCtrl;

  @override
  void onInit() {
    super.onInit();
    _vehicleCtrl = Get.find<VehicleController>();
    _infraCtrl = Get.find<InfraController>();
    _objectCtrl = Get.find<ObjectController>();
    allVehicleFields = _getFieldsForEntity(FmsEntityType.vehicle);
    allInfraFields = _getFieldsForEntity(FmsEntityType.infra);
    visibleVehicleFields = Set<String>.from(allVehicleFields);
    visibleInfraFields = Set<String>.from(allInfraFields);
    _rebuildCachedFields();
  }

  @override
  void onClose() {
    _autoUpdateTimer?.cancel();
    super.onClose();
  }

  Future<void> initialize() async {
    await _waitForTokenReady();
    _vehicleCtrl.reqLoadVehicles();
    if (currentEntityType == FmsEntityType.infra) {
      _infraCtrl.reqLoadInfraIdentifiers();
    }
    await loadPage(1, resetFilters: true, force: true);
    initialLoading = false;
    update();
  }

  Future<void> _waitForTokenReady() async {
    if (!_vehicleCtrl.hasToken) {
      try {
        await Get.find<UserController>().ensureAccessTokenLoaded();
      } catch (_) {}
    }
    if (_vehicleCtrl.hasToken) return;
    for (int i = 0; i < 300; i++) {
      if (_vehicleCtrl.hasToken) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> loadPage(
    int page, {
    bool resetFilters = false,
    bool force = false,
    String? searchText,
    String? searchColumn,
  }) async {
    // force:true (필터 변경, 새로고침) 는 로딩 중에도 허용:
    // _loadRequestId 체크가 이전 요청의 결과를 자동으로 버림
    if (isLoading && !force) return;

    if (!_vehicleCtrl.hasToken) {
      await _waitForTokenReady();
      if (!_vehicleCtrl.hasToken) return;
    }

    if (resetFilters) {
      vehicleIdFilter = 'ALL';
      infraIdFilter = 'ALL';
      currentPage = 1;
      activeFilterColumn = null;
      activeFilterValue = null;
      dateFrom = null;
      dateTo = null;
      _vehicleCtrl.setDateRange(null, null);
      _infraCtrl.setDateRange(null, null);
      _invalidatePageCache();
    }

    // force:true 이면 캐시 무효화 (새로고침, 필터 변경, 엔티티 변경 시)
    if (force) _invalidatePageCache();

    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final int targetPage = force ? page : page.clamp(1, safeTotalPages);
    if (!force && targetPage == currentPage) return;

    // 캐시에서 먼저 확인 (force:false 이고 페이지 이동 시)
    if (!force) {
      final _PageCacheEntry? cached = _getPageCache(targetPage);
      if (cached != null) {
        totalCount = cached.totalCount;
        currentPage = targetPage;
        pageRows = cached.rows;
        firstDataArrived = true;
        update();
        onGridUpdateNeeded?.call();
        return;
      }
    }

    final int requestId = ++_loadRequestId;

    isLoading = true;
    update();
    onGridUpdateNeeded?.call();

    try {
      final int offset = (targetPage - 1) * rowsPerPage;
      final int limit = rowsPerPage;
      final String? searchTextParam = searchText ??
          (activeFilterColumn != null &&
                  activeFilterValue != null &&
                  activeFilterValue!.trim().isNotEmpty
              ? activeFilterValue!.trim()
              : null);
      final String? searchColumnParam = searchColumn ?? activeFilterColumn;

      List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      int resolvedTotalCount = 0;

      if (currentEntityType == FmsEntityType.vehicle) {
        final int? vehicleId =
            vehicleIdFilter != 'ALL' ? int.tryParse(vehicleIdFilter) : null;
        await _vehicleCtrl.reqLoadHistory(
          vehicleId: vehicleId,
          offset: offset,
          limit: limit,
          searchText: searchTextParam,
          searchColumnName: searchColumnParam,
        );
        rows = _vehicleCtrl.historyItems
            .map((VehicleInfoHistory item) =>
                _enrichRowDateTimeFields(item.toJson()))
            .toList();
        resolvedTotalCount = _vehicleCtrl.historyTotalCount;
      } else {
        final int? infraId =
            infraIdFilter != 'ALL' ? int.tryParse(infraIdFilter) : null;
        await _infraCtrl.reqLoadHistory(
          infraId: infraId,
          offset: offset,
          limit: limit,
          searchText: searchTextParam,
          searchColumnName: searchColumnParam,
        );
        rows = _infraCtrl.historyItems
            .map((InfraInfoHistory item) =>
                _enrichRowDateTimeFields(item.toJson()))
            .toList();
        resolvedTotalCount = _infraCtrl.historyTotalCount;
      }

      if (requestId != _loadRequestId) return;
      final int maxPage = (resolvedTotalCount + rowsPerPage - 1) ~/ rowsPerPage;
      final int safeMaxPage = maxPage < 1 ? 1 : maxPage;
      int finalPage = targetPage;

      if (finalPage > safeMaxPage) {
        finalPage = safeMaxPage;
        final int newOffset = (finalPage - 1) * rowsPerPage;
        if (currentEntityType == FmsEntityType.vehicle) {
          final int? vehicleId =
              vehicleIdFilter != 'ALL' ? int.tryParse(vehicleIdFilter) : null;
          await _vehicleCtrl.reqLoadHistory(
            vehicleId: vehicleId,
            offset: newOffset,
            limit: limit,
            searchText: searchTextParam,
            searchColumnName: searchColumnParam,
          );
          rows = _vehicleCtrl.historyItems
              .map((VehicleInfoHistory item) =>
                  _enrichRowDateTimeFields(item.toJson()))
              .toList();
        } else {
          final int? infraId =
              infraIdFilter != 'ALL' ? int.tryParse(infraIdFilter) : null;
          await _infraCtrl.reqLoadHistory(
            infraId: infraId,
            offset: newOffset,
            limit: limit,
            searchText: searchTextParam,
            searchColumnName: searchColumnParam,
          );
          rows = _infraCtrl.historyItems
              .map((InfraInfoHistory item) =>
                  _enrichRowDateTimeFields(item.toJson()))
              .toList();
        }
      }

      if (requestId != _loadRequestId) return;

      totalCount = resolvedTotalCount;
      currentPage = finalPage < 1 ? 1 : finalPage;
      pageRows = rows;
      firstDataArrived = true;
      // 로드한 결과를 캐시에 저장
      _putPageCache(currentPage, rows, resolvedTotalCount);
      update();
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('DashboardController.loadPage error: $exception');
      }
    } finally {
      if (requestId == _loadRequestId) {
        isLoading = false;
        update();
        onGridUpdateNeeded?.call();
      }
    }
  }

  Future<void> refreshCurrent() async {
    if (isLoading) return;
    if (currentEntityType == FmsEntityType.infra) {
      await _infraCtrl.reqLoadInfraIdentifiers();
    }
    await loadPage(currentPage, force: true);
  }

  void changePage(int page) {
    if (isLoading || initialLoading) return;
    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final int target = page.clamp(1, safeTotalPages);
    if (target == currentPage) return;
    loadPage(target);
  }

  Future<void> changeEntityType(FmsEntityType type) async {
    if (currentEntityType == type) return;
    currentEntityType = type;
    vehicleIdFilter = 'ALL';
    infraIdFilter = 'ALL';
    currentPage = 1;
    totalCount = 0;
    pageRows = <Map<String, dynamic>>[];
    firstDataArrived = false;
    activeFilterColumn = null;
    activeFilterValue = null;
    _rebuildCachedFields();
    update();

    if (type == FmsEntityType.infra) {
      await _infraCtrl.reqLoadInfraIdentifiers();
    }
    await loadPage(1, resetFilters: true, force: true);
  }

  void enableMapView() {
    if (isMapView) return;
    isMapView = true;
    update();
  }

  void disableMapView() {
    if (!isMapView) return;
    isMapView = false;
    update();
  }

  // 지도 전체 화면 모드
  void enableFullMapMode() {
    if (isFullMapMode) return;
    isFullMapMode = true;
    update();
  }

  void disableFullMapMode() {
    if (!isFullMapMode) return;
    isFullMapMode = false;
    update();
  }

  void changeUpdateInterval(AutoUpdateInterval interval) {
    currentUpdateInterval = interval;
    _startAutoUpdate(interval);
    update();
  }

  void _startAutoUpdate(AutoUpdateInterval interval) {
    _autoUpdateTimer?.cancel();
    if (interval == AutoUpdateInterval.manual) return;

    Duration duration;
    switch (interval) {
      case AutoUpdateInterval.oneSecond:
        duration = const Duration(seconds: 1);
        break;
      case AutoUpdateInterval.threeSeconds:
        duration = const Duration(seconds: 3);
        break;
      case AutoUpdateInterval.fiveSeconds:
        duration = const Duration(seconds: 5);
        break;
      case AutoUpdateInterval.manual:
        return;
    }

    _autoUpdateTimer = Timer.periodic(duration, (Timer timer) {
      refreshCurrent();
    });
  }

  void applyColumnFilter(Set<String> newVisibleFields) {
    if (currentEntityType == FmsEntityType.vehicle) {
      visibleVehicleFields = Set<String>.from(newVisibleFields);
    } else {
      visibleInfraFields = Set<String>.from(newVisibleFields);
    }
    _rebuildCachedFields();
    update();
  }

  void applyActiveFilter(String? column, String? value) {
    final String? newColumn =
        (value != null && value.trim().isNotEmpty) ? column : null;
    final String? newValue =
        (value != null && value.trim().isNotEmpty) ? value.trim() : null;

    if (newColumn == activeFilterColumn && newValue == activeFilterValue) {
      return;
    }
    activeFilterColumn = newColumn;
    activeFilterValue = newValue;
    currentPage = 1;
    loadPage(1, force: true, searchText: newValue, searchColumn: newColumn);
  }

  void clearActiveFilter() {
    if (activeFilterColumn == null && activeFilterValue == null) return;
    activeFilterColumn = null;
    activeFilterValue = null;
    currentPage = 1;
    loadPage(1, force: true);
  }

  Future<void> setVehicleIdFilter(String vehicleId) async {
    if (isLoading) return;
    vehicleIdFilter = vehicleId;
    currentPage = 1;
    update();
    await loadPage(1, force: true);
  }

  Future<void> setInfraIdFilter(String infraId) async {
    if (isLoading) return;
    infraIdFilter = infraId;
    currentPage = 1;
    update();
    await loadPage(1, force: true);
  }

  Future<void> setDateRangeFilter(DateTime? from, DateTime? to) async {
    if (isLoading) return;
    dateFrom = from;
    dateTo = to;
    // 날짜 범위를 epoch ms로 변환해 각 컨트롤러에 전달
    final int? fromMs = from != null
        ? DateTime(from.year, from.month, from.day).millisecondsSinceEpoch
        : null;
    final int? toMs = to != null
        ? DateTime(to.year, to.month, to.day, 23, 59, 59, 999)
            .millisecondsSinceEpoch
        : null;
    _vehicleCtrl.setDateRange(fromMs, toMs);
    _infraCtrl.setDateRange(fromMs, toMs);
    currentPage = 1;
    _invalidatePageCache();
    update();
    await loadPage(1, force: true);
  }

  bool get hasDateRangeFilter => dateFrom != null || dateTo != null;

  void setExporting(bool value) {
    isExporting = value;
    update();
  }

  Map<String, String?> get activeSearchParams {
    if (activeFilterColumn != null &&
        activeFilterValue != null &&
        activeFilterValue!.trim().isNotEmpty) {
      return <String, String?>{
        'text': activeFilterValue!.trim(),
        'column': activeFilterColumn,
      };
    }
    return <String, String?>{'text': null, 'column': null};
  }

  int? get selectedVehicleIdForExport {
    if (currentEntityType != FmsEntityType.vehicle) return null;
    if (vehicleIdFilter == 'ALL') return null;
    return int.tryParse(vehicleIdFilter);
  }

  int? get selectedInfraIdForExport {
    if (currentEntityType != FmsEntityType.infra) return null;
    if (infraIdFilter == 'ALL') return null;
    return int.tryParse(infraIdFilter);
  }

  List<int> buildVisiblePages() {
    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    if (safeTotalPages <= 1) return <int>[1];

    final Set<int> pages = <int>{
      1,
      safeTotalPages,
      currentPage,
      currentPage - 1,
      currentPage + 1,
    };
    pages.removeWhere((int page) => page < 1 || page > safeTotalPages);
    return pages.toList()..sort();
  }

  void _rebuildCachedFields() {
    cachedFields = currentAllFields
        .where((String field) => currentVisibleFields.contains(field))
        .toList();
  }

  List<String> _getFieldsForEntity(FmsEntityType type) {
    if (type == FmsEntityType.vehicle) {
      return <String>[
        'history_id',
        'vehicle_info_id',
        'vehicle_id',
        'msg_id',
        'msg_seq',
        'msg_length',
        'changed_at_date',
        'changed_at_time',
        'time_stamp_ms',
        'navsat',
        'kph',
        'mps',
        'pos_x_m',
        'pos_y_m',
        'pos_z_m',
        'heading_deg',
        'accel_x_mps2',
        'accel_y_mps2',
        'accel_z_mps2',
        'gyro_x_dps',
        'gyro_y_dps',
        'gyro_z_dps',
        'transmission_gear',
        'signal_light',
        'angle_deg',
        'torque_nm',
        'accel_pct',
        'brake_pct',
        'number_of_objects',
        'created_ts_date',
        'created_ts_time',
        'updated_ts_date',
        'updated_ts_time',
      ];
    }
    return <String>[
      'history_id',
      'infra_info_id',
      'infra_id',
      'msg_id',
      'msg_seq',
      'msg_length',
      'changed_at_date',
      'changed_at_time',
      'time_stamp_ms',
      'number_of_objects',
      'created_ts_date',
      'created_ts_time',
      'updated_ts_date',
      'updated_ts_time',
    ];
  }

  // 행 데이터에 날짜/시간 분리 파생 필드 추가 (외부에서 호출 가능)
  Map<String, dynamic> enrichRowDateTimeFields(Map<String, dynamic> row) {
    return _enrichRowDateTimeFields(row);
  }

  // "2026-03-17T12:34:56.123" → {'date': '2026-03-17', 'time': '12:34:56'}
  Map<String, String> _splitDateTimeValue(dynamic value) {
    if (value == null) return <String, String>{'date': '', 'time': ''};
    final String raw = value.toString().trim();
    // YYYY-MM-DD(T|space)HH:MM:SS 패턴 확인
    final RegExpMatch? match = RegExp(
      r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})',
    ).firstMatch(raw);
    if (match == null) return <String, String>{'date': raw, 'time': ''};
    return <String, String>{'date': match.group(1)!, 'time': match.group(2)!};
  }

  // 행 데이터에 날짜/시간 분리 파생 필드 추가
  Map<String, dynamic> _enrichRowDateTimeFields(Map<String, dynamic> row) {
    final Map<String, dynamic> enriched = Map<String, dynamic>.from(row);
    for (final String field in <String>[
      'changed_at',
      'created_ts',
      'updated_ts'
    ]) {
      if (enriched.containsKey(field)) {
        final Map<String, String> parts = _splitDateTimeValue(enriched[field]);
        enriched['${field}_date'] = parts['date'];
        enriched['${field}_time'] = parts['time'];
      }
    }
    return enriched;
  }

  List<String> getObjectFields() {
    return <String>[
      'detected_object_id',
      'source_kind',
      'vehicle_info_id',
      'infra_info_id',
      'object_id',
      'object_type',
      'msg_id',
      'msg_seq',
      'age',
      'score',
      'width',
      'depth',
      'height',
      'position_x',
      'position_y',
      'position_z',
      'orientation_heading',
      'linear_velocity_x',
      'linear_velocity_y',
      'linear_velocity_z',
      'rotation_rate_x',
      'rotation_rate_y',
      'rotation_rate_z',
      'created_ts',
      'updated_ts',
    ];
  }

  int parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  int parseIntOrFallback(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  String formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    if (value is String) return _formatDateTimeString(value);
    return value.toString();
  }

  // "2026-03-17T12:34:56.123456" → "2026-03-17 12:34:56" 형태로 정규화
  String _formatDateTimeString(String value) {
    final String trimmed = value.trim();
    // 날짜+시간 패턴인지 확인 (YYYY-MM-DD T/공백 HH:MM:SS)
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}').hasMatch(trimmed)) {
      return trimmed;
    }
    return trimmed
        .replaceFirst('T', ' ')
        .replaceFirst(RegExp(r'\.\d+'), '')
        .replaceFirst('Z', '')
        .trim();
  }

  ObjectTypeUi objectTypeUi(int? objectType) {
    final int value = objectType ?? -1;
    if (value == 0) {
      return const ObjectTypeUi(label: '미확인', iconData: Icons.help_outline);
    }
    if (value == 1) {
      return const ObjectTypeUi(
          label: '승용차', iconData: Icons.directions_car_filled);
    }
    if (value == 2) {
      return const ObjectTypeUi(label: '트럭', iconData: Icons.local_shipping);
    }
    if (value == 3) {
      return const ObjectTypeUi(
          label: '버스', iconData: Icons.directions_bus_filled);
    }
    if (value == 4) {
      return const ObjectTypeUi(label: '보행자', iconData: Icons.directions_walk);
    }
    if (value == 5) {
      return const ObjectTypeUi(label: '이륜차', iconData: Icons.two_wheeler);
    }
    return const ObjectTypeUi(label: '미확인', iconData: Icons.question_mark);
  }

  String getObjectTypeNameKorean(int? type) {
    switch (type) {
      case 0:
        return '미확인';
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

  List<DetectedObject> parseDetectedObjectsFromRaw(dynamic rawValue) {
    if (rawValue is! List) return <DetectedObject>[];
    final List<DetectedObject> parsed = <DetectedObject>[];
    for (final dynamic element in rawValue) {
      if (element is Map) {
        try {
          parsed
              .add(DetectedObject.fromJson(Map<String, dynamic>.from(element)));
        } catch (_) {}
      }
    }
    return parsed;
  }

  List<DetectedObject> normalizeObjectsForRow(
    List<DetectedObject> inputObjects,
    Map<String, dynamic> row, {
    bool strictRowMatch = false,
  }) {
    if (inputObjects.isEmpty) return <DetectedObject>[];

    final Map<int, DetectedObject> uniqueByDetectedId = <int, DetectedObject>{};
    final List<DetectedObject> noDetectedIdObjects = <DetectedObject>[];

    for (final DetectedObject object in inputObjects) {
      final int detectedId = object.detectedObjectId ?? -1;
      if (detectedId > 0) {
        final DetectedObject? existing = uniqueByDetectedId[detectedId];
        if (existing == null) {
          uniqueByDetectedId[detectedId] = object;
          continue;
        }
        final int existingMsgSeq = existing.msgSeq ?? -1;
        final int candidateMsgSeq = object.msgSeq ?? -1;
        if (candidateMsgSeq >= existingMsgSeq) {
          uniqueByDetectedId[detectedId] = object;
        }
        continue;
      }
      noDetectedIdObjects.add(object);
    }

    List<DetectedObject> normalized = <DetectedObject>[
      ...uniqueByDetectedId.values,
      ...noDetectedIdObjects,
    ];

    final dynamic rawTimeStamp = row['time_stamp_ms'] ?? row['time_stamp'];
    final int rowTimeStampMs = parseIntValue(rawTimeStamp);
    final bool hasRowTimeStamp = rawTimeStamp != null && rowTimeStampMs > 0;
    if (hasRowTimeStamp) {
      final List<DetectedObject> matched = normalized
          .where((DetectedObject o) => (o.timeStampMs ?? -1) == rowTimeStampMs)
          .toList();
      if (matched.isNotEmpty) {
        normalized = matched;
      } else if (strictRowMatch) {
        return <DetectedObject>[];
      }
    }

    final dynamic rawMsgSeq = row['msg_seq'];
    final int rowMsgSeq = parseIntValue(rawMsgSeq);
    final bool hasRowMsgSeq = rawMsgSeq != null;
    if (hasRowMsgSeq) {
      final List<DetectedObject> matched = normalized
          .where((DetectedObject o) => (o.msgSeq ?? -1) == rowMsgSeq)
          .toList();
      if (matched.isNotEmpty) {
        normalized = matched;
      } else if (strictRowMatch) {
        return <DetectedObject>[];
      }
    }

    normalized.sort((DetectedObject left, DetectedObject right) {
      final int leftObjectId =
          left.objectId ?? left.detectedObjectId ?? (1 << 30);
      final int rightObjectId =
          right.objectId ?? right.detectedObjectId ?? (1 << 30);
      final int byObjectId = leftObjectId.compareTo(rightObjectId);
      if (byObjectId != 0) return byObjectId;
      final int leftDetectedId = left.detectedObjectId ?? -1;
      final int rightDetectedId = right.detectedObjectId ?? -1;
      return leftDetectedId.compareTo(rightDetectedId);
    });

    return normalized;
  }

  Future<List<DetectedObject>> requestNormalizedObjectsForRow({
    required Map<String, dynamic> row,
    required bool latestOnly,
    int? rowTimeStampMs,
    int limit = 1000,
    bool strictRowMatch = false,
  }) async {
    DetectedObjectResult? result;
    final dynamic rawMsgSeq = row['msg_seq'];
    final int? rowMsgSeq = rawMsgSeq == null ? null : parseIntValue(rawMsgSeq);
    final int expectedObjectCount = parseIntValue(row['number_of_objects']);
    final int? expectedCountForRequest =
        expectedObjectCount > 0 ? expectedObjectCount : null;

    if (currentEntityType == FmsEntityType.vehicle) {
      final int vehicleInfoId = parseIntValue(row['vehicle_info_id']);
      if (vehicleInfoId <= 0) return <DetectedObject>[];
      final int vehicleId = parseIntValue(row['vehicle_id']);
      result = await _objectCtrl.fetchByVehicleInfo(
        vehicleInfoId: vehicleInfoId,
        offset: 0,
        limit: limit,
        latestOnly: latestOnly,
        vehicleTimeStampMs: rowTimeStampMs,
        vehicleId: vehicleId > 0 ? vehicleId : null,
        msgSeq: rowMsgSeq,
        expectedObjectCount: expectedCountForRequest,
      );
    } else {
      final int infraInfoId = parseIntValue(row['infra_info_id']);
      if (infraInfoId <= 0) return <DetectedObject>[];
      final int infraId = parseIntValue(row['infra_id']);
      result = await _objectCtrl.fetchByInfraInfo(
        infraInfoId: infraInfoId,
        offset: 0,
        limit: limit,
        latestOnly: latestOnly,
        infraTimeStampMs: rowTimeStampMs,
        infraId: infraId > 0 ? infraId : null,
        msgSeq: rowMsgSeq,
        expectedObjectCount: expectedCountForRequest,
      );
    }

    if (result == null || result.items.isEmpty) return <DetectedObject>[];
    return normalizeObjectsForRow(
      result.items,
      row,
      strictRowMatch: strictRowMatch,
    );
  }

  Future<List<DetectedObject>> loadObjectsForRowWithFallback({
    required Map<String, dynamic> row,
    required List<DetectedObject> fallbackObjectItems,
  }) async {
    final int declaredObjectCount = parseIntValue(row['number_of_objects']);
    final List<DetectedObject> strictFallback = normalizeObjectsForRow(
      fallbackObjectItems,
      row,
      strictRowMatch: true,
    );
    final List<DetectedObject> looseFallback = normalizeObjectsForRow(
      fallbackObjectItems,
      row,
      strictRowMatch: false,
    );

    if (declaredObjectCount <= 0) {
      return looseFallback;
    }

    final int rowTimeStampMs =
        parseIntValue(row['time_stamp_ms'] ?? row['time_stamp']);
    final int? strictTimestamp = rowTimeStampMs > 0 ? rowTimeStampMs : null;

    int detailLimit = 1000;
    if (declaredObjectCount > 0 && declaredObjectCount < 1000) {
      final int boosted = declaredObjectCount * 5;
      if (boosted > detailLimit) detailLimit = boosted;
    }
    if (detailLimit > 2000) detailLimit = 2000;

    Future<List<DetectedObject>> fetchAttempt({
      required bool latestOnly,
      required int? timestampMs,
      required bool strictRowMatch,
    }) async {
      return requestNormalizedObjectsForRow(
        row: row,
        latestOnly: latestOnly,
        rowTimeStampMs: timestampMs,
        limit: detailLimit,
        strictRowMatch: strictRowMatch,
      );
    }

    if (strictTimestamp != null) {
      List<DetectedObject> resolved = await fetchAttempt(
        latestOnly: true,
        timestampMs: strictTimestamp,
        strictRowMatch: true,
      );
      if (resolved.isNotEmpty) return resolved;

      for (int attempt = 0; attempt < 2; attempt++) {
        await Future<void>.delayed(Duration(milliseconds: 250 + attempt * 300));
        resolved = await fetchAttempt(
          latestOnly: true,
          timestampMs: strictTimestamp,
          strictRowMatch: true,
        );
        if (resolved.isNotEmpty) return resolved;
      }

      resolved = await fetchAttempt(
        latestOnly: false,
        timestampMs: null,
        strictRowMatch: false,
      );
      if (resolved.isNotEmpty) return resolved;

      resolved = await fetchAttempt(
        latestOnly: true,
        timestampMs: null,
        strictRowMatch: false,
      );
      if (resolved.isNotEmpty) return resolved;

      return looseFallback.isNotEmpty ? looseFallback : strictFallback;
    }

    List<DetectedObject> resolved = await fetchAttempt(
      latestOnly: true,
      timestampMs: null,
      strictRowMatch: false,
    );
    if (resolved.isNotEmpty) return resolved;

    resolved = await fetchAttempt(
      latestOnly: false,
      timestampMs: null,
      strictRowMatch: false,
    );
    if (resolved.isNotEmpty) return resolved;

    for (int attempt = 0; attempt < 2; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 250 + attempt * 300));
      resolved = await fetchAttempt(
        latestOnly: true,
        timestampMs: null,
        strictRowMatch: false,
      );
      if (resolved.isNotEmpty) return resolved;
      resolved = await fetchAttempt(
        latestOnly: false,
        timestampMs: null,
        strictRowMatch: false,
      );
      if (resolved.isNotEmpty) return resolved;
    }

    return looseFallback;
  }
}

// 페이지 캐시 항목: 로드한 행 목록과 총 개수를 30초 동안 보관한다
class _PageCacheEntry {
  final List<Map<String, dynamic>> rows;
  final int totalCount;
  final DateTime _timestamp;

  _PageCacheEntry({required this.rows, required this.totalCount})
      : _timestamp = DateTime.now();

  bool get isStale => DateTime.now().difference(_timestamp).inSeconds > 30;
}
