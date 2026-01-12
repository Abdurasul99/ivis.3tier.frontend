import 'dart:math';
import 'package:get/get.dart';

import '../../model/object_model.dart';
import '../repository/object_repository.dart';
import 'user_controller.dart';

enum DetectedObjectScope { vehicleInfo, infraInfo }

class ObjectController extends GetxController {
  final ObjectRepository objectRepository = ObjectRepository();

  List<DetectedObject> detectedObjects = <DetectedObject>[];

  bool isLoading = false;

  int pageLimit = 200;
  int pageOffset = 0;
  int totalCount = 0;

  DetectedObjectScope scope = DetectedObjectScope.vehicleInfo;

  int? currentVehicleInfoRowId;
  int? currentInfraInfoRowId;

  bool get hasToken {
    try {
      return (Get.find<UserController>().accessToken ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setVehicleInfoRow(int vehicleInfoRowId) async {
    scope = DetectedObjectScope.vehicleInfo;
    currentVehicleInfoRowId = vehicleInfoRowId;
    currentInfraInfoRowId = null;
    pageOffset = 0;
    totalCount = 0;
    detectedObjects = <DetectedObject>[];
    update();
    await loadPage(offset: 0, limit: pageLimit);
  }

  Future<void> setInfraInfoRow(int infraInfoRowId) async {
    scope = DetectedObjectScope.infraInfo;
    currentInfraInfoRowId = infraInfoRowId;
    currentVehicleInfoRowId = null;
    pageOffset = 0;
    totalCount = 0;
    detectedObjects = <DetectedObject>[];
    update();
    await loadPage(offset: 0, limit: pageLimit);
  }

  Future<void> loadPage({required int offset, required int limit}) async {
    if (!hasToken) {
      detectedObjects = <DetectedObject>[];
      totalCount = 0;
      pageOffset = 0;
      update();
      return;
    }

    isLoading = true;
    update();

    try {
      if (scope == DetectedObjectScope.vehicleInfo) {
        final int? vehicleInfoRowId = currentVehicleInfoRowId;
        if (vehicleInfoRowId == null) {
          detectedObjects = <DetectedObject>[];
          totalCount = 0;
          pageOffset = 0;
          return;
        }

        final Map<String, dynamic> meta = await objectRepository.requestByVehicleInfoWithMeta(
          vehicleInfoId: vehicleInfoRowId,
          limit: limit,
          offset: offset,
        );

        final dynamic itemsDynamic = meta['items'];
        final dynamic totalDynamic = meta['totalCount'];

        detectedObjects = itemsDynamic is List<DetectedObject> ? itemsDynamic : <DetectedObject>[];
        totalCount = totalDynamic is int ? totalDynamic : int.tryParse(totalDynamic?.toString() ?? '') ?? 0;
        pageOffset = offset;
        pageLimit = limit;
        return;
      }

      final int? infraInfoRowId = currentInfraInfoRowId;
      if (infraInfoRowId == null) {
        detectedObjects = <DetectedObject>[];
        totalCount = 0;
        pageOffset = 0;
        return;
      }

      final Map<String, dynamic> meta = await objectRepository.requestByInfraInfoWithMeta(
        infraInfoId: infraInfoRowId,
        limit: limit,
        offset: offset,
      );

      final dynamic itemsDynamic = meta['items'];
      final dynamic totalDynamic = meta['totalCount'];

      detectedObjects = itemsDynamic is List<DetectedObject> ? itemsDynamic : <DetectedObject>[];
      totalCount = totalDynamic is int ? totalDynamic : int.tryParse(totalDynamic?.toString() ?? '') ?? 0;
      pageOffset = offset;
      pageLimit = limit;
    } finally {
      isLoading = false;
      update();
    }
  }

  bool get canGoPrevious {
    return !isLoading && pageOffset > 0;
  }

  bool get canGoNext {
    if (isLoading) return false;
    if (totalCount <= 0) return detectedObjects.length >= pageLimit;
    return (pageOffset + detectedObjects.length) < totalCount;
  }

  int get currentPageNumber {
    if (pageLimit <= 0) return 1;
    return (pageOffset ~/ pageLimit) + 1;
  }

  int get totalPages {
    if (totalCount <= 0 || pageLimit <= 0) return 1;
    final int pages = (totalCount + pageLimit - 1) ~/ pageLimit;
    return max(1, pages);
  }

  Future<void> goPrevious() async {
    if (!canGoPrevious) return;
    final int nextOffset = max(0, pageOffset - pageLimit);
    await loadPage(offset: nextOffset, limit: pageLimit);
  }

  Future<void> goNext() async {
    if (!canGoNext) return;
    final int nextOffset = pageOffset + pageLimit;
    await loadPage(offset: nextOffset, limit: pageLimit);
  }
}
