//ivis.3tier.frontend/lib/viewmodel/controller/object_controller.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../model/object_model.dart';
import '../repository/object_repository.dart';
import 'user_controller.dart';

enum DetectedObjectScope {
  vehicleInfo,
  infraInfo,
}

class ObjectController extends GetxController {
  // 생산 코드는 ObjectRepository()를 사용하고,
  // 테스트에서는 FakeObjectRepository를 주입한다.
  final ObjectRepository repositoryInternal;

  ObjectController({ObjectRepository? repository})
      : repositoryInternal = repository ?? ObjectRepository();

  List<DetectedObject> detectedObjectsInternal = <DetectedObject>[];
  bool isLoadingInternal = false;
  int pageLimitInternal = 200;
  int pageOffsetInternal = 0;
  int totalCountInternal = 0;
  DetectedObjectScope scopeInternal = DetectedObjectScope.vehicleInfo;
  int? currentVehicleIdInternal;
  int? currentInfraIdInternal;

  List<DetectedObject> get detectedObjects {
    return detectedObjectsInternal;
  }

  bool get isLoading {
    return isLoadingInternal;
  }

  int get pageLimit {
    return pageLimitInternal;
  }

  int get pageOffset {
    return pageOffsetInternal;
  }

  int get totalCount {
    return totalCountInternal;
  }

  DetectedObjectScope get scope {
    return scopeInternal;
  }

  int? get currentVehicleId {
    return currentVehicleIdInternal;
  }

  int? get currentInfraId {
    return currentInfraIdInternal;
  }

  ObjectRepository get repository {
    return repositoryInternal;
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

  bool get canGoPrevious {
    if (isLoadingInternal) {
      return false;
    }
    return pageOffsetInternal > 0;
  }

  bool get canGoNext {
    if (isLoadingInternal) {
      return false;
    }
    if (totalCountInternal <= 0) {
      return detectedObjectsInternal.length >= pageLimitInternal;
    }
    return (pageOffsetInternal + detectedObjectsInternal.length) <
        totalCountInternal;
  }

  int get currentPageNumber {
    if (pageLimitInternal <= 0) {
      return 1;
    }
    return (pageOffsetInternal ~/ pageLimitInternal) + 1;
  }

  int get totalPages {
    if (totalCountInternal <= 0 || pageLimitInternal <= 0) {
      return 1;
    }
    final int pages =
        (totalCountInternal + pageLimitInternal - 1) ~/ pageLimitInternal;
    return max(1, pages);
  }

  // 차량 번호(vehicle_id)로 조회 대상 지정 (0 도 유효한 번호)
  Future<void> setVehicleInfoRow(int vehicleId) async {
    scopeInternal = DetectedObjectScope.vehicleInfo;
    currentVehicleIdInternal = vehicleId;
    currentInfraIdInternal = null;
    pageOffsetInternal = 0;
    totalCountInternal = 0;
    detectedObjectsInternal = <DetectedObject>[];
    update();
    await loadPage(offset: 0, limit: pageLimitInternal);
  }

  // 인프라 번호(infra_id)로 조회 대상 지정 (0 도 유효한 번호)
  Future<void> setInfraInfoRow(int infraId) async {
    scopeInternal = DetectedObjectScope.infraInfo;
    currentInfraIdInternal = infraId;
    currentVehicleIdInternal = null;
    pageOffsetInternal = 0;
    totalCountInternal = 0;
    detectedObjectsInternal = <DetectedObject>[];
    update();
    await loadPage(offset: 0, limit: pageLimitInternal);
  }

  Future<void> loadPage({
    required int offset,
    required int limit,
  }) async {
    if (!hasToken) {
      detectedObjectsInternal = <DetectedObject>[];
      totalCountInternal = 0;
      pageOffsetInternal = 0;
      update();
      return;
    }

    final bool isVehicleScope =
        scopeInternal == DetectedObjectScope.vehicleInfo;
    if (isVehicleScope && currentVehicleIdInternal == null) {
      detectedObjectsInternal = <DetectedObject>[];
      totalCountInternal = 0;
      pageOffsetInternal = 0;
      update();
      return;
    }
    if (!isVehicleScope && currentInfraIdInternal == null) {
      detectedObjectsInternal = <DetectedObject>[];
      totalCountInternal = 0;
      pageOffsetInternal = 0;
      update();
      return;
    }

    isLoadingInternal = true;
    update();

    try {
      DetectedObjectResult? result;

      if (isVehicleScope) {
        final int vehicleId = currentVehicleIdInternal!;
        result = await repositoryInternal.requestByVehicleInfo(
          vehicleId: vehicleId,
          limit: limit,
          offset: offset,
        );
      } else {
        final int infraId = currentInfraIdInternal!;
        result = await repositoryInternal.requestByInfraInfo(
          infraId: infraId,
          limit: limit,
          offset: offset,
        );
      }

      if (result != null) {
        detectedObjectsInternal = result.items;
        totalCountInternal = result.totalCount;
        pageOffsetInternal = offset;
        pageLimitInternal = limit;
      } else {
        detectedObjectsInternal = <DetectedObject>[];
        totalCountInternal = 0;
        pageOffsetInternal = 0;
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('ObjectController.loadPage error: $exception');
      }
      detectedObjectsInternal = <DetectedObject>[];
      totalCountInternal = 0;
      pageOffsetInternal = 0;
    } finally {
      isLoadingInternal = false;
      update();
    }
  }

  Future<DetectedObjectResult?> fetchByVehicleInfo({
    required int vehicleId,
    int offset = 0,
    int limit = 200,
    bool latestOnly = false,
    int? vehicleTimeStampMs,
    int? msgSeq,
    int? expectedObjectCount,
  }) async {
    if (!hasToken) {
      return null;
    }

    try {
      return await repositoryInternal.requestByVehicleInfo(
        vehicleId: vehicleId,
        limit: limit,
        offset: offset,
        latestOnly: latestOnly,
        vehicleTimeStampMs: vehicleTimeStampMs,
        msgSeq: msgSeq,
        expectedObjectCount: expectedObjectCount,
      );
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('ObjectController.fetchByVehicleInfo error: $exception');
      }
      return null;
    }
  }

  Future<DetectedObjectResult?> fetchByInfraInfo({
    required int infraId,
    int offset = 0,
    int limit = 200,
    bool latestOnly = false,
    int? infraTimeStampMs,
    int? msgSeq,
    int? expectedObjectCount,
  }) async {
    if (!hasToken) {
      return null;
    }

    try {
      return await repositoryInternal.requestByInfraInfo(
        infraId: infraId,
        limit: limit,
        offset: offset,
        latestOnly: latestOnly,
        infraTimeStampMs: infraTimeStampMs,
        msgSeq: msgSeq,
        expectedObjectCount: expectedObjectCount,
      );
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('ObjectController.fetchByInfraInfo error: $exception');
      }
      return null;
    }
  }

  Future<void> goPrevious() async {
    if (!canGoPrevious) {
      return;
    }
    final int nextOffset = max(0, pageOffsetInternal - pageLimitInternal);
    await loadPage(offset: nextOffset, limit: pageLimitInternal);
  }

  Future<void> goNext() async {
    if (!canGoNext) {
      return;
    }
    final int nextOffset = pageOffsetInternal + pageLimitInternal;
    await loadPage(offset: nextOffset, limit: pageLimitInternal);
  }

  void reset() {
    detectedObjectsInternal = <DetectedObject>[];
    isLoadingInternal = false;
    pageLimitInternal = 200;
    pageOffsetInternal = 0;
    totalCountInternal = 0;
    scopeInternal = DetectedObjectScope.vehicleInfo;
    currentVehicleIdInternal = null;
    currentInfraIdInternal = null;
    update();
  }
}
