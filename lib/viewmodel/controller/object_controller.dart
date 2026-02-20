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
  final ObjectRepository repositoryInternal = ObjectRepository();

  List<DetectedObject> detectedObjectsInternal = <DetectedObject>[];
  bool isLoadingInternal = false;
  int pageLimitInternal = 200;
  int pageOffsetInternal = 0;
  int totalCountInternal = 0;
  DetectedObjectScope scopeInternal = DetectedObjectScope.vehicleInfo;
  int? currentVehicleInfoIdInternal;
  int? currentInfraInfoIdInternal;

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

  int? get currentVehicleInfoId {
    return currentVehicleInfoIdInternal;
  }

  int? get currentInfraInfoId {
    return currentInfraInfoIdInternal;
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
    return (pageOffsetInternal + detectedObjectsInternal.length) < totalCountInternal;
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
    final int pages = (totalCountInternal + pageLimitInternal - 1) ~/ pageLimitInternal;
    return max(1, pages);
  }

  Future<void> setVehicleInfoRow(int vehicleInfoId) async {
    scopeInternal = DetectedObjectScope.vehicleInfo;
    currentVehicleInfoIdInternal = vehicleInfoId;
    currentInfraInfoIdInternal = null;
    pageOffsetInternal = 0;
    totalCountInternal = 0;
    detectedObjectsInternal = <DetectedObject>[];
    update();
    await loadPage(offset: 0, limit: pageLimitInternal);
  }

  Future<void> setInfraInfoRow(int infraInfoId) async {
    scopeInternal = DetectedObjectScope.infraInfo;
    currentInfraInfoIdInternal = infraInfoId;
    currentVehicleInfoIdInternal = null;
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

    final bool isVehicleScope = scopeInternal == DetectedObjectScope.vehicleInfo;
    if (isVehicleScope && currentVehicleInfoIdInternal == null) {
      detectedObjectsInternal = <DetectedObject>[];
      totalCountInternal = 0;
      pageOffsetInternal = 0;
      update();
      return;
    }
    if (!isVehicleScope && currentInfraInfoIdInternal == null) {
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
        final int vehicleInfoId = currentVehicleInfoIdInternal!;
        result = await repositoryInternal.requestByVehicleInfo(
          vehicleInfoId: vehicleInfoId,
          limit: limit,
          offset: offset,
        );
      } else {
        final int infraInfoId = currentInfraInfoIdInternal!;
        result = await repositoryInternal.requestByInfraInfo(
          infraInfoId: infraInfoId,
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
    required int vehicleInfoId,
    int offset = 0,
    int limit = 200,
  }) async {
    if (!hasToken) {
      return null;
    }

    try {
      return await repositoryInternal.requestByVehicleInfo(
        vehicleInfoId: vehicleInfoId,
        limit: limit,
        offset: offset,
      );
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('ObjectController.fetchByVehicleInfo error: $exception');
      }
      return null;
    }
  }

  Future<DetectedObjectResult?> fetchByInfraInfo({
    required int infraInfoId,
    int offset = 0,
    int limit = 200,
  }) async {
    if (!hasToken) {
      return null;
    }

    try {
      return await repositoryInternal.requestByInfraInfo(
        infraInfoId: infraInfoId,
        limit: limit,
        offset: offset,
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
    currentVehicleInfoIdInternal = null;
    currentInfraInfoIdInternal = null;
    update();
  }
}
