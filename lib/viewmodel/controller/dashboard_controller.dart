// dashboard_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../model/infra_model.dart';
import '../../model/object_model.dart';
import '../../model/vehicle_model.dart';
import 'dashboard_objects_status_controller.dart';
import 'helper/dashboard_fields_helper.dart';
import 'helper/dashboard_format_helper.dart';
import 'infra_controller.dart';
import 'user_controller.dart';
import 'vehicle_controller.dart';

export 'helper/dashboard_format_helper.dart' show ObjectTypeUi;

enum FmsEntityType { vehicle, infra }

enum AutoUpdateInterval {
  manual,
  oneSecond,
  threeSeconds,
  fiveSeconds,
}

class DashboardController extends GetxController {
  late final VehicleController _vehicleCtrl;
  late final InfraController _infraCtrl;

  VoidCallback? onGridUpdateNeeded;

  FmsEntityType currentEntityType = FmsEntityType.vehicle;
  bool isMapView = true; // 최초 로드 시 지도 항상 표시

  bool initialLoading = true;
  bool isLoading = false;
  bool firstDataArrived = false;
  bool isExporting = false;
  bool isFullMapMode = false;

  // 객체 현황 패널 상태/로직은 DashboardObjectsStatusController 로 이관 ─────
  // View 호환을 위해 아래 getter/method 들이 위임자 역할을 한다.
  DashboardObjectsStatusController get _statusCtrl =>
      Get.find<DashboardObjectsStatusController>();

  int currentPage = 1;
  int totalCount = 0;
  int rowsPerPage = 18;

  // ── 키셋 커서 페이지네이션 상태 ─────────────────────────────────────────
  // useKeysetPagination = true 일 때 cursorStack 으로 Next/Prev 만 지원한다.
  // cursorStack[i] = i번째 페이지로 점프하기 위해 사용한 cursor (마지막 row history_id).
  // 1페이지면 stack 은 비어있음.
  // TODO: 임의 페이지 점프 (jump-to-page) 는 keyset 모드에서 지원되지 않음 →
  //       UI 에서 입력값을 "근사치" 표시로 안내하거나 비활성화한다.
  // ★ 2026-06-10: 하이브리드 모드 — 100M+ 행 스케일 대응.
  //   - Chevron Next/Prev → cursor (15ms 어느 깊이든 일정)
  //   - 페이지 번호 클릭 / Jump → cursorStack 비우고 offset fallback (깊으면 느림)
  //   - page 1 auto-refresh → cursor 비어있으면 offset=0 → 빠름
  //   실측: page 1=45ms, page 1k=4.7s(offset), keyset deep=15ms.
  //   100M 행 도달 시 page jump 깊으면 매우 느려지지만 chevron 은 항상 빠름.
  bool useKeysetPagination = true;
  final List<int> _cursorStack = <int>[];

  // 현재 페이지 마지막 row 의 history_id (Next 클릭 시 cursor 로 사용)
  int? _lastSeenHistoryId;
  // 현재 페이지 첫 row 의 history_id (Prev 클릭 시 fallback 으로 사용)
  int? _firstSeenHistoryId;

  bool get hasNextPage {
    if (useKeysetPagination) {
      // 다음 페이지가 있는지 = 마지막 페이지가 아닌지
      return currentPage < totalPages && _lastSeenHistoryId != null;
    }
    return currentPage < totalPages;
  }

  bool get hasPrevPage {
    if (useKeysetPagination) return currentPage > 1;
    return currentPage > 1;
  }

  // 외부에서 디버깅/표시용으로 노출 (현재 페이지의 첫/마지막 row history_id).
  int? get firstSeenHistoryId => _firstSeenHistoryId;
  int? get lastSeenHistoryId => _lastSeenHistoryId;

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

  // ── 객체 현황 패널 위임자 (DashboardObjectsStatusController) ─────────────
  bool get isObjectsStatusOpen => _statusCtrl.isObjectsStatusOpen;
  bool get objectsStatusLoading => _statusCtrl.objectsStatusLoading;
  List<DetectedObject> get objectsStatusItems => _statusCtrl.objectsStatusItems;
  int get objectsStatusPage => _statusCtrl.objectsStatusPage;
  int get objectsStatusRowsPerPage => _statusCtrl.objectsStatusRowsPerPage;
  int get objectsStatusTotalCount => _statusCtrl.objectsStatusTotalCount;
  int get objectsStatusTotalPages => _statusCtrl.objectsStatusTotalPages;
  bool get isObjectsLiveMode => _statusCtrl.isObjectsLiveMode;

  void toggleObjectsStatus() => _statusCtrl.toggleObjectsStatus();
  void toggleObjectsLiveMode() => _statusCtrl.toggleObjectsLiveMode();
  void changeObjectsStatusPage(int page) =>
      _statusCtrl.changeObjectsStatusPage(page);
  void refreshObjectsStatus() => _statusCtrl.refreshObjectsStatus();
  void showObjectsStatusFromRow(Map<String, dynamic> row) =>
      unawaited(_statusCtrl.showObjectsStatusFromRow(row));
  List<DetectedObject> parseDetectedObjectsFromRaw(dynamic rawValue) =>
      _statusCtrl.parseDetectedObjectsFromRaw(rawValue);
  List<DetectedObject> normalizeObjectsForRow(
    List<DetectedObject> inputObjects,
    Map<String, dynamic> row, {
    bool strictRowMatch = false,
  }) =>
      _statusCtrl.normalizeObjectsForRow(inputObjects, row,
          strictRowMatch: strictRowMatch);
  Future<List<DetectedObject>> requestNormalizedObjectsForRow({
    required Map<String, dynamic> row,
    required bool latestOnly,
    int? rowTimeStampMs,
    int limit = 1000,
    bool strictRowMatch = false,
  }) =>
      _statusCtrl.requestNormalizedObjectsForRow(
        row: row,
        latestOnly: latestOnly,
        rowTimeStampMs: rowTimeStampMs,
        limit: limit,
        strictRowMatch: strictRowMatch,
      );
  Future<List<DetectedObject>> loadObjectsForRowWithFallback({
    required Map<String, dynamic> row,
    required List<DetectedObject> fallbackObjectItems,
  }) =>
      _statusCtrl.loadObjectsForRowWithFallback(
        row: row,
        fallbackObjectItems: fallbackObjectItems,
      );

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
    // 행 클릭 전에는 빈 상태 — DB 전체 조회 불필요
    _statusCtrl.resetForInitialize();
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
      // 필터 변경 시 cursor 스택 초기화
      _cursorStack.clear();
      _lastSeenHistoryId = null;
      _firstSeenHistoryId = null;
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
        if (isObjectsStatusOpen) {
          _statusCtrl.refreshOrFetchObjectsStatus(cached.rows);
        }
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

      // 키셋 모드: 1페이지 이외에는 cursorStack 의 마지막 cursor 사용.
      // 키셋 모드라도 1페이지(cursorStack 비어있음)는 offset=0 으로 조회.
      // TODO: 임의 페이지 jump 시에는 offset 으로 fallback (근사치) — 키셋은
      //       Next/Prev 만 정확하게 지원한다.
      final bool useCursor =
          useKeysetPagination && _cursorStack.isNotEmpty;
      final int? cursorIdParam = useCursor ? _cursorStack.last : null;
      const String cursorDirParam = 'next';

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
          cursorId: cursorIdParam,
          cursorDirection: useCursor ? cursorDirParam : null,
        );
        rows = _vehicleCtrl.historyItems
            .map((VehicleInfoHistory item) =>
                DashboardFieldsHelper.enrichRowDateTimeFields(item.toJson()))
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
          cursorId: cursorIdParam,
          cursorDirection: useCursor ? cursorDirParam : null,
        );
        rows = _infraCtrl.historyItems
            .map((InfraInfoHistory item) =>
                DashboardFieldsHelper.enrichRowDateTimeFields(item.toJson()))
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
                  DashboardFieldsHelper.enrichRowDateTimeFields(item.toJson()))
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
                  DashboardFieldsHelper.enrichRowDateTimeFields(item.toJson()))
              .toList();
        }
      }

      if (requestId != _loadRequestId) return;

      totalCount = resolvedTotalCount;
      currentPage = finalPage < 1 ? 1 : finalPage;
      pageRows = rows;
      firstDataArrived = true;
      // 현재 페이지의 첫/마지막 row history_id 를 기록 (Next/Prev 커서로 사용)
      _updateSeenHistoryIds(rows);
      // 로드한 결과를 캐시에 저장
      _putPageCache(currentPage, rows, resolvedTotalCount);
      if (isObjectsStatusOpen) _statusCtrl.refreshOrFetchObjectsStatus(rows);
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
    // isLoading 중이면 스킵 — 동시 요청 시 _loadRequestId 경쟁으로 isLoading이
    // 영구 true가 되는 버그 방지 (직전 요청이 완료되면 다음 틱에 정상 실행)
    if (isLoading) return;
    if (currentEntityType == FmsEntityType.infra) {
      await _infraCtrl.reqLoadInfraIdentifiers();
    }
    await loadPage(currentPage, force: true);
  }

  // 디바이스 관리에서 기기 삭제 후 대시보드로 복귀했을 때 호출:
  // 차량/인프라 목록(레지스트리)을 다시 로드해 삭제된 기기가 사이드바·지도에
  // 남지 않도록 즉시 반영한다. (map 은 _vehicleCtrl.vehicles / GetBuilder<DashboardController> 로 갱신됨)
  Future<void> refreshDeviceLists() async {
    await _vehicleCtrl.reqLoadVehicles();
    await _infraCtrl.reqLoadInfraIdentifiers();
    update();
  }

  void changePage(int page) {
    if (isLoading || initialLoading) return;
    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final int target = page.clamp(1, safeTotalPages);
    if (target == currentPage) return;
    // 키셋 모드: 임의 페이지 jump 대신 1페이지로 리셋 후 offset 모드로 근사 조회.
    // (안전한 동작을 보장하기 위해 cursorStack 초기화)
    if (useKeysetPagination) {
      _cursorStack.clear();
      // 임의 페이지 점프는 키셋으로는 불가능하므로 cursor 미사용 — loadPage 내부에서
      // _cursorStack.isEmpty 이므로 offset 모드로 fallback (근사 페이지).
    }
    loadPage(target);
  }

  // ── 키셋 커서 Next/Prev API ─────────────────────────────────────────────
  // Next: 현재 페이지 마지막 row history_id 를 cursorStack 에 push 하고 다음 페이지 로드.
  // Prev: cursorStack 에서 pop 한 뒤 그 이전 cursor 로 다시 로드.
  Future<void> loadNextPage() async {
    if (isLoading || initialLoading) return;
    if (!useKeysetPagination) {
      // 백워드 호환: offset 모드면 기존 changePage 사용
      changePage(currentPage + 1);
      return;
    }
    if (_lastSeenHistoryId == null) return;
    if (currentPage >= totalPages) return;
    _cursorStack.add(_lastSeenHistoryId!);
    final int nextPage = currentPage + 1;
    await loadPage(nextPage, force: true);
  }

  Future<void> loadPrevPage() async {
    if (isLoading || initialLoading) return;
    if (!useKeysetPagination) {
      changePage(currentPage - 1);
      return;
    }
    if (currentPage <= 1) return;
    if (_cursorStack.isNotEmpty) _cursorStack.removeLast();
    final int prevPage = currentPage - 1;
    await loadPage(prevPage, force: true);
  }

  // 현재 페이지의 첫/마지막 row history_id 를 기록한다.
  // 다음/이전 페이지 요청 시 keyset cursor 로 사용.
  void _updateSeenHistoryIds(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      _firstSeenHistoryId = null;
      _lastSeenHistoryId = null;
      return;
    }
    _firstSeenHistoryId = _extractHistoryId(rows.first);
    _lastSeenHistoryId = _extractHistoryId(rows.last);
  }

  int? _extractHistoryId(Map<String, dynamic> row) {
    final dynamic v = row['history_id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // 필터/엔티티 변경 시 cursor 스택 + seen IDs 를 리셋한다.
  // (cursor 는 동일 정렬/필터 조건에서만 유효하므로 변경되면 무효화)
  void _resetCursorState() {
    _cursorStack.clear();
    _lastSeenHistoryId = null;
    _firstSeenHistoryId = null;
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
    _resetCursorState();
    _statusCtrl.resetIfOpen();
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
      // ★ 100M+ 행 스케일 보호: page 1 일 때만 auto-refresh.
      //   딥 페이지의 데이터는 히스토리라 변하지 않음 → polling 의미 없음 + 비용 큼
      //   (OFFSET 5M 은 60초 이상 — DB 연결 고갈 위험).
      if (currentPage != 1) return;
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
    _resetCursorState();
    loadPage(1, force: true, searchText: newValue, searchColumn: newColumn);
  }

  void clearActiveFilter() {
    if (activeFilterColumn == null && activeFilterValue == null) return;
    activeFilterColumn = null;
    activeFilterValue = null;
    currentPage = 1;
    _resetCursorState();
    loadPage(1, force: true);
  }

  Future<void> setVehicleIdFilter(String vehicleId) async {
    if (isLoading) return;
    vehicleIdFilter = vehicleId;
    currentPage = 1;
    _resetCursorState();
    update();
    await loadPage(1, force: true);
  }

  Future<void> setInfraIdFilter(String infraId) async {
    if (isLoading) return;
    infraIdFilter = infraId;
    currentPage = 1;
    _resetCursorState();
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
    _resetCursorState();
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

  List<String> _getFieldsForEntity(FmsEntityType type) =>
      DashboardFieldsHelper.getFieldsForEntity(type);

  // 행 데이터에 날짜/시간 분리 파생 필드 추가 (외부에서 호출 가능)
  Map<String, dynamic> enrichRowDateTimeFields(Map<String, dynamic> row) =>
      DashboardFieldsHelper.enrichRowDateTimeFields(row);

  List<String> getObjectFields() => DashboardFieldsHelper.getObjectFields();

  int parseIntValue(dynamic value) =>
      DashboardFormatHelper.parseIntValue(value);

  int parseIntOrFallback(dynamic value, int fallback) =>
      DashboardFormatHelper.parseIntOrFallback(value, fallback);

  String formatCellValue(dynamic value) =>
      DashboardFormatHelper.formatCellValue(value);

  ObjectTypeUi objectTypeUi(int? objectType) =>
      DashboardFormatHelper.objectTypeUi(objectType);

  String getObjectTypeNameKorean(int? type) =>
      DashboardFormatHelper.getObjectTypeNameKorean(type);
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
