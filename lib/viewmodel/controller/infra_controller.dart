//ivis.3tier.frontend/lib/viewmodel/controller/infra_controller.dart
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../model/infra_model.dart';
import '../repository/infra_repository.dart';
import 'user_controller.dart';

class InfraController extends GetxController {
  final InfraRepository repository;

  InfraController({InfraRepository? repository})
      : repository = repository ?? InfraRepository();

  bool isLoadingInternal = false;
  List<int> infraIdentifiersInternal = <int>[];
  int? selectedInfraIdInternal;

  List<InfraInfoHistory> historyItemsInternal = <InfraInfoHistory>[];
  int historyTotalCountInternal = 0;
  int historyOffsetInternal = 0;
  int historyLimitInternal = 18;
  // 마지막 이력 로드 실패 여부 — 실패 시 기존 데이터 유지 (빈 테이블 방지).
  bool historyLoadFailedInternal = false;

  List<InfraInfo> statusItemsInternal = <InfraInfo>[];
  int statusTotalCountInternal = 0;
  int statusOffsetInternal = 0;
  int statusLimitInternal = 100;

  InfraInfo? latestInfraInfoInternal;

  int? fromEpochMsInternal;
  int? toEpochMsInternal;

  bool get isLoading {
    return isLoadingInternal;
  }

  List<int> get infraIdentifiers {
    return infraIdentifiersInternal;
  }

  int? get selectedInfraId {
    return selectedInfraIdInternal;
  }

  List<InfraInfoHistory> get historyItems {
    return historyItemsInternal;
  }

  int get historyTotalCount {
    return historyTotalCountInternal;
  }

  int get historyOffset {
    return historyOffsetInternal;
  }

  int get historyLimit {
    return historyLimitInternal;
  }

  List<InfraInfo> get statusItems {
    return statusItemsInternal;
  }

  int get statusTotalCount {
    return statusTotalCountInternal;
  }

  int get statusOffset {
    return statusOffsetInternal;
  }

  int get statusLimit {
    return statusLimitInternal;
  }

  InfraInfo? get latestInfraInfo {
    return latestInfraInfoInternal;
  }

  int? get fromEpochMs {
    return fromEpochMsInternal;
  }

  int? get toEpochMs {
    return toEpochMsInternal;
  }

  bool get hasToken {
    try {
      final UserController userController = Get.find<UserController>();
      final String? token = userController.accessToken;
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void setSelectedInfraId(int? infraId) {
    selectedInfraIdInternal = infraId;
    update();
  }

  void setDateRange(int? fromMs, int? toMs) {
    fromEpochMsInternal = fromMs;
    toEpochMsInternal = toMs;
  }

  Future<void> reqLoadInfraIdentifiers() async {
    if (!hasToken) {
      infraIdentifiersInternal = <int>[];
      update();
      return;
    }

    try {
      final List<int> identifierList = await repository.requestInfraIdentifiers();
      infraIdentifiersInternal = identifierList.toSet().toList()..sort();
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('InfraController.reqLoadInfraIdentifiers error: $exception');
      }
      infraIdentifiersInternal = <int>[];
    }

    update();
  }

  Future<void> reqLoadLatestInfraInfo(int infraId) async {
    if (!hasToken) {
      latestInfraInfoInternal = null;
      update();
      return;
    }

    try {
      latestInfraInfoInternal = await repository.requestLatestInfraInfo(infraId);
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('InfraController.reqLoadLatestInfraInfo error: $exception');
      }
      latestInfraInfoInternal = null;
    }

    update();
  }

  Future<void> reqLoadHistory({
    int? infraId,
    int offset = 0,
    int limit = 18,
    String? searchText,
    String? searchColumnName,
    // ── 키셋 커서 (신규) ─ cursorId 지정 시 offset 무시 ──
    int? cursorId,
    String? cursorDirection,
  }) async {
    if (!hasToken) {
      historyItemsInternal = <InfraInfoHistory>[];
      historyTotalCountInternal = 0;
      historyOffsetInternal = 0;
      update();
      return;
    }

    isLoadingInternal = true;
    update();

    try {
      final InfraInfoHistoryResult? result = await repository.requestInfraHistory(
        infraId: infraId,
        fromEpochMs: fromEpochMsInternal,
        toEpochMs: toEpochMsInternal,
        limit: limit,
        offset: offset,
        searchText: searchText,
        searchColumnName: searchColumnName,
        cursorId: cursorId,
        cursorDirection: cursorDirection,
      );

      if (result != null) {
        historyItemsInternal = result.items;
        historyTotalCountInternal = result.totalCount;
        historyOffsetInternal = offset;
        historyLimitInternal = limit;
        historyLoadFailedInternal = false;
      } else {
        // 요청 실패(타임아웃/오류) — 기존 데이터 유지 (빈 테이블 방지).
        historyLoadFailedInternal = true;
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('InfraController.reqLoadHistory error: $exception');
      }
      // 예외 시에도 기존 데이터 유지.
      historyLoadFailedInternal = true;
    } finally {
      isLoadingInternal = false;
      update();
    }
  }

  Future<void> reqLoadStatus({
    int? infraId,
    int offset = 0,
    int limit = 100,
    String? searchText,
    String? searchColumnName,
    // ── 키셋 커서 (신규) ─ cursorId 지정 시 offset 무시 ──
    int? cursorId,
    String? cursorDirection,
  }) async {
    if (!hasToken) {
      statusItemsInternal = <InfraInfo>[];
      statusTotalCountInternal = 0;
      statusOffsetInternal = 0;
      update();
      return;
    }

    isLoadingInternal = true;
    update();

    try {
      final InfraInfoResult? result = await repository.requestInfraStatus(
        infraId: infraId,
        fromEpochMs: fromEpochMsInternal,
        toEpochMs: toEpochMsInternal,
        limit: limit,
        offset: offset,
        searchText: searchText,
        searchColumnName: searchColumnName,
        cursorId: cursorId,
        cursorDirection: cursorDirection,
      );

      if (result != null) {
        statusItemsInternal = result.items;
        statusTotalCountInternal = result.totalCount;
        statusOffsetInternal = offset;
        statusLimitInternal = limit;
      } else {
        statusItemsInternal = <InfraInfo>[];
        statusTotalCountInternal = 0;
        statusOffsetInternal = 0;
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('InfraController.reqLoadStatus error: $exception');
      }
      statusItemsInternal = <InfraInfo>[];
      statusTotalCountInternal = 0;
      statusOffsetInternal = 0;
    } finally {
      isLoadingInternal = false;
      update();
    }
  }

  void clearHistory() {
    historyItemsInternal = <InfraInfoHistory>[];
    historyTotalCountInternal = 0;
    historyOffsetInternal = 0;
    latestInfraInfoInternal = null;
    update();
  }

  void clearStatus() {
    statusItemsInternal = <InfraInfo>[];
    statusTotalCountInternal = 0;
    statusOffsetInternal = 0;
    update();
  }

  void reset() {
    isLoadingInternal = false;
    infraIdentifiersInternal = <int>[];
    selectedInfraIdInternal = null;
    historyItemsInternal = <InfraInfoHistory>[];
    historyTotalCountInternal = 0;
    historyOffsetInternal = 0;
    historyLimitInternal = 18;
    statusItemsInternal = <InfraInfo>[];
    statusTotalCountInternal = 0;
    statusOffsetInternal = 0;
    statusLimitInternal = 100;
    latestInfraInfoInternal = null;
    fromEpochMsInternal = null;
    toEpochMsInternal = null;
    update();
  }
}
