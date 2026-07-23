// dashboard_objects_status_controller.dart
// 객체 현황 패널 전용 컨트롤러: DashboardController 에서 분리한 독립 GetX 컨트롤러.
// 패널 열림/닫힘, LIVE 모드, 페이지 이동, 행 클릭 시 객체 표시, DB fetch 등을 담당한다.

import 'dart:async';

import 'package:get/get.dart';

import '../../model/object_model.dart';
import 'dashboard_controller.dart';
import 'helper/dashboard_format_helper.dart';
import 'object_controller.dart';

class DashboardObjectsStatusController extends GetxController {
  late final ObjectController _objectCtrl;

  // ── 상태 ────────────────────────────────────────────────────────────────
  bool isObjectsStatusOpen = false; // 행 클릭 시 자동으로 열림
  bool objectsStatusLoading = false;
  int _objectsStatusRequestSerial = 0;
  List<DetectedObject> objectsStatusItems = <DetectedObject>[];
  int objectsStatusPage = 1;
  int objectsStatusRowsPerPage = 500;
  int objectsStatusTotalCount = 0;

  // LIVE 모드: DB에서 최신 객체를 타이머와 연동해 실시간 표시
  bool isObjectsLiveMode = false;

  // LIVE 모드 전용 1초 타이머 — detected_object(현재 테이블)에서 최신 객체를
  // 메인 테이블 새로고침과 무관하게 매초 독립적으로 폴링해 렌더링한다.
  Timer? _liveTimer;
  static const Duration _liveInterval = Duration(seconds: 1);

  // 클릭으로 선택된 행
  Map<String, dynamic>? _selectedPageRow;

  int get objectsStatusTotalPages {
    final int safe = objectsStatusTotalCount < 0 ? 0 : objectsStatusTotalCount;
    final int pages =
        (safe + objectsStatusRowsPerPage - 1) ~/ objectsStatusRowsPerPage;
    return pages < 1 ? 1 : pages;
  }

  @override
  void onInit() {
    super.onInit();
    _objectCtrl = Get.find<ObjectController>();
  }

  // 부모(DashboardController)도 함께 갱신 — View 의 GetBuilder<DashboardController>
  // 가 isObjectsStatusOpen 등을 읽고 있어서 같이 리빌드 되어야 한다.
  void _notify() {
    update();
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().update();
    }
  }

  FmsEntityType get _currentEntityType {
    if (!Get.isRegistered<DashboardController>()) return FmsEntityType.vehicle;
    return Get.find<DashboardController>().currentEntityType;
  }

  // ── 패널 토글/리셋 ──────────────────────────────────────────────────────
  void toggleObjectsStatus() {
    isObjectsStatusOpen = !isObjectsStatusOpen;
    if (isObjectsStatusOpen) {
      resetState();
      objectsStatusLoading = false;
      _notify();
    } else {
      _objectsStatusRequestSerial += 1;
      _notify();
    }
  }

  // 객체 현황 패널 상태 초기화 (선택 행도 함께 해제)
  // DashboardController.initialize / loadPage / changeEntityType 에서도 호출.
  void resetState({bool notify = false}) {
    objectsStatusItems = <DetectedObject>[];
    objectsStatusPage = 1;
    objectsStatusTotalCount = 0;
    _selectedPageRow = null;
    if (notify) _notify();
  }

  // initialize 직후 호출: 패널은 닫혀있되 로딩 상태도 해제
  void resetForInitialize() {
    resetState();
    objectsStatusLoading = false;
    _notify();
  }

  // entity 변경 시 호출: 열려있던 패널만 초기화 (닫혀있으면 노옵)
  void resetIfOpen() {
    if (!isObjectsStatusOpen) return;
    resetState();
    objectsStatusLoading = false;
  }

  // LIVE 모드 토글
  void toggleObjectsLiveMode() {
    isObjectsLiveMode = !isObjectsLiveMode;
    if (isObjectsLiveMode) {
      _selectedPageRow = null;
      objectsStatusItems = <DetectedObject>[];
      objectsStatusLoading = true;
      isObjectsStatusOpen = true;
      _notify();
      _fetchObjectsStatus(page: 1);
      _startLiveTimer(); // 매초 detected_object 폴링 시작
    } else {
      _stopLiveTimer();
      _objectsStatusRequestSerial += 1; // 진행 중인 fetch 취소
      objectsStatusItems = <DetectedObject>[];
      objectsStatusTotalCount = 0;
      objectsStatusLoading = false;
      _notify();
    }
  }

  // LIVE 모드 전용 1초 폴링 타이머 시작 — 메인 테이블 새로고침 설정/페이지와 무관하게
  // detected_object(현재 테이블)에서 최신 객체를 매초 독립적으로 가져온다.
  void _startLiveTimer() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(_liveInterval, (_) {
      if (!isObjectsLiveMode || !isObjectsStatusOpen) {
        _stopLiveTimer();
        return;
      }
      if (objectsStatusLoading) return; // 직전 요청 진행 중이면 이번 틱 스킵
      _fetchObjectsStatus();
    });
  }

  void _stopLiveTimer() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  @override
  void onClose() {
    _stopLiveTimer();
    super.onClose();
  }

  // 선택된 행이 있으면 해당 행 objects 갱신, LIVE 모드면 DB 조회, 없으면 빈 상태
  void refreshOrFetchObjectsStatus(List<Map<String, dynamic>> currentRows) {
    if (isObjectsLiveMode) {
      _fetchObjectsStatus();
      return;
    }
    if (_selectedPageRow != null) {
      final int selectedId =
          DashboardFormatHelper.parseIntValue(_selectedPageRow!['history_id']);
      for (final Map<String, dynamic> row in currentRows) {
        if (DashboardFormatHelper.parseIntValue(row['history_id']) ==
            selectedId) {
          unawaited(showObjectsStatusFromRow(row));
          return;
        }
      }
      _selectedPageRow = null;
    }
    // 선택된 행 없음 → 패널 비우기 (이미 열려있어도 내용만 비움)
    objectsStatusItems = <DetectedObject>[];
    objectsStatusTotalCount = 0;
    objectsStatusLoading = false;
    _notify();
  }

  void changeObjectsStatusPage(int page) {
    if (!isObjectsStatusOpen || objectsStatusLoading) return;
    final int target = page.clamp(1, objectsStatusTotalPages);
    if (target == objectsStatusPage) return;
    objectsStatusPage = target;
    objectsStatusItems = <DetectedObject>[];
    objectsStatusLoading = true;
    _notify();
    _fetchObjectsStatus(page: target);
  }

  void refreshObjectsStatus() {
    if (!isObjectsStatusOpen || objectsStatusLoading) return;
    if (_selectedPageRow != null) {
      // 선택된 행의 objects 재표시 (필요 시 REST fallback 포함)
      unawaited(showObjectsStatusFromRow(_selectedPageRow!));
      return;
    }
    // 선택된 행 없음 → 빈 상태 유지
    objectsStatusItems = <DetectedObject>[];
    objectsStatusTotalCount = 0;
    objectsStatusLoading = false;
    _notify();
  }

  // 클릭한 행의 객체 현황 패널 표시.
  // 이력 목록 API(vehicle/infra history) 응답에는 objects 가 embed 되어 오지 않으므로
  // (row['objects'] 는 항상 빈 배열) — 우선 즉시 표시 가능한 것을 보여준 뒤,
  // number_of_objects > 0 인데 embed 된 데이터가 없으면 REST로 실제 감지 객체를 조회한다.
  // serial 증가로 진행 중인 이전 비동기 결과가 이후 클릭/닫힘을 덮어쓰지 못하게 차단.
  Future<void> showObjectsStatusFromRow(Map<String, dynamic> row) async {
    isObjectsLiveMode = false; // 행 클릭 시 LIVE 모드 해제
    _selectedPageRow = row;
    final int requestSerial = ++_objectsStatusRequestSerial;

    final List<DetectedObject> embeddedObjects = parseDetectedObjectsFromRaw(
      row['objects'] ?? row['detected_objects'] ?? row['detectedObjects'],
    );

    final int expectedCount =
        DashboardFormatHelper.parseIntValue(row['number_of_objects'])
            .clamp(0, 1000);

    // detected_object_id DESC → 가장 최신 expectedCount 개만 표시
    // msg_seq 필터는 DB에서 null이 많아 신뢰성이 낮아 제거
    final List<DetectedObject> sortedEmbedded =
        List<DetectedObject>.from(embeddedObjects)
          ..sort((DetectedObject a, DetectedObject b) =>
              (b.detectedObjectId ?? 0).compareTo(a.detectedObjectId ?? 0));

    final List<DetectedObject> immediateResult = expectedCount > 0
        ? sortedEmbedded.take(expectedCount).toList()
        : sortedEmbedded;

    objectsStatusItems = immediateResult;
    objectsStatusTotalCount = immediateResult.length;
    isObjectsStatusOpen = true;
    objectsStatusLoading = immediateResult.isEmpty && expectedCount > 0;
    _notify();

    if (immediateResult.isEmpty && expectedCount > 0) {
      final List<DetectedObject> fetched = await loadObjectsForRowWithFallback(
        row: row,
        fallbackObjectItems: embeddedObjects,
      );
      // 이후 다른 행 클릭/패널 닫힘으로 이 요청이 이미 무효화됐으면 무시
      if (requestSerial != _objectsStatusRequestSerial) return;
      objectsStatusItems = fetched;
      objectsStatusTotalCount = fetched.length;
      objectsStatusLoading = false;
      _notify();
    }
  }

  Future<void> _fetchObjectsStatus({int? page}) async {
    if (!isObjectsStatusOpen) return;
    final int requestSerial = ++_objectsStatusRequestSerial;
    final String sourceKind =
        _currentEntityType == FmsEntityType.vehicle ? 'vehicle' : 'infra';
    final int targetPage = (page ?? objectsStatusPage).clamp(1, 1000000);
    final int offset = (targetPage - 1) * objectsStatusRowsPerPage;
    objectsStatusLoading = true;
    try {
      final DetectedObjectResult result =
          await _objectCtrl.repositoryInternal.requestLatestStatus(
        limit: objectsStatusRowsPerPage,
        offset: offset,
        sourceKind: sourceKind,
      );
      if (!isObjectsStatusOpen ||
          requestSerial != _objectsStatusRequestSerial) {
        return;
      }
      final String currentSourceKind =
          _currentEntityType == FmsEntityType.vehicle ? 'vehicle' : 'infra';
      if (sourceKind != currentSourceKind) return;
      objectsStatusTotalCount = result.totalCount;
      objectsStatusPage = targetPage.clamp(1, objectsStatusTotalPages);
      objectsStatusItems = result.items
          .where((DetectedObject item) =>
              (item.sourceKind ?? '').trim().toLowerCase() == sourceKind)
          .toList();
    } catch (_) {
      if (requestSerial == _objectsStatusRequestSerial) {
        objectsStatusItems = <DetectedObject>[];
        objectsStatusTotalCount = 0;
      }
    } finally {
      if (requestSerial == _objectsStatusRequestSerial) {
        objectsStatusLoading = false;
        _notify();
      }
    }
  }

  // ── 객체 파싱/정규화 (상태없음) ────────────────────────────────────────
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
    final int rowTimeStampMs =
        DashboardFormatHelper.parseIntValue(rawTimeStamp);
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
    final int rowMsgSeq = DashboardFormatHelper.parseIntValue(rawMsgSeq);
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
    final int? rowMsgSeq = rawMsgSeq == null
        ? null
        : DashboardFormatHelper.parseIntValue(rawMsgSeq);
    final int expectedObjectCount =
        DashboardFormatHelper.parseIntValue(row['number_of_objects']);
    final int? expectedCountForRequest =
        expectedObjectCount > 0 ? expectedObjectCount : null;

    if (_currentEntityType == FmsEntityType.vehicle) {
      final int vehicleInfoId =
          DashboardFormatHelper.parseIntValue(row['vehicle_info_id']);
      if (vehicleInfoId <= 0) return <DetectedObject>[];
      final int vehicleId =
          DashboardFormatHelper.parseIntValue(row['vehicle_id']);
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
      final int infraInfoId =
          DashboardFormatHelper.parseIntValue(row['infra_info_id']);
      if (infraInfoId <= 0) return <DetectedObject>[];
      final int infraId = DashboardFormatHelper.parseIntValue(row['infra_id']);
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
    final int declaredObjectCount =
        DashboardFormatHelper.parseIntValue(row['number_of_objects']);
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

    final int rowTimeStampMs = DashboardFormatHelper.parseIntValue(
        row['time_stamp_ms'] ?? row['time_stamp']);
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
