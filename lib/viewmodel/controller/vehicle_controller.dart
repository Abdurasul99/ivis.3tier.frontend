//ivis.3tier.frontend/lib/viewmodel/controller/vehicle_controller.dart

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../model/vehicle_model.dart';
import '../repository/vehicle_repository.dart';
import 'user_controller.dart';

class VehicleController extends GetxController {
  // 생산 코드는 VehicleRepository()를 사용하고,
  // 테스트에서는 FakeVehicleRepository를 주입한다.
  final VehicleRepository repository;

  VehicleController({VehicleRepository? repository})
      : repository = repository ?? VehicleRepository();

  bool isLoadingInternal = false;
  List<Vehicle> vehiclesInternal = <Vehicle>[];
  Vehicle? selectedVehicleInternal;

  List<VehicleInfoHistory> historyItemsInternal = <VehicleInfoHistory>[];
  int historyTotalCountInternal = 0;
  int historyOffsetInternal = 0;
  int historyLimitInternal = 18;

  List<VehicleInfo> statusItemsInternal = <VehicleInfo>[];
  int statusTotalCountInternal = 0;
  int statusOffsetInternal = 0;
  int statusLimitInternal = 100;

  VehicleInfo? latestVehicleInfoInternal;

  int? fromEpochMsInternal;
  int? toEpochMsInternal;

  bool get isLoading {
    return isLoadingInternal;
  }

  List<Vehicle> get vehicles {
    return vehiclesInternal;
  }

  Vehicle? get selectedVehicle {
    return selectedVehicleInternal;
  }

  int? get selectedVehicleId {
    return selectedVehicleInternal?.vehicleId;
  }

  List<VehicleInfoHistory> get historyItems {
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

  List<VehicleInfo> get statusItems {
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

  VehicleInfo? get latestVehicleInfo {
    return latestVehicleInfoInternal;
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

  void setDateRange(int? fromMs, int? toMs) {
    fromEpochMsInternal = fromMs;
    toEpochMsInternal = toMs;
  }

  Future<bool> reqLoadVehicles() async {
    if (!hasToken) {
      vehiclesInternal = <Vehicle>[];
      selectedVehicleInternal = null;
      update();
      return false;
    }

    isLoadingInternal = true;
    update();

    try {
      final List<Vehicle> result = await repository.requestVehicleList();
      vehiclesInternal = result;

      if (vehiclesInternal.isNotEmpty && selectedVehicleInternal == null) {
        selectedVehicleInternal = vehiclesInternal.first;
      }

      isLoadingInternal = false;
      update();
      return true;
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('VehicleController.reqLoadVehicles error: $exception');
      }
      vehiclesInternal = <Vehicle>[];
      selectedVehicleInternal = null;
      isLoadingInternal = false;
      update();
      return false;
    }
  }

  Future<Vehicle?> reqGetVehicleById(int vehicleId) async {
    if (!hasToken) {
      return null;
    }

    try {
      return await repository.requestVehicleById(vehicleId);
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('VehicleController.reqGetVehicleById error: $exception');
      }
      return null;
    }
  }

  Future<void> reqLoadLatestVehicleInfo(int vehicleId) async {
    if (!hasToken) {
      latestVehicleInfoInternal = null;
      update();
      return;
    }

    try {
      latestVehicleInfoInternal = await repository.requestLatestVehicleInfo(vehicleId);
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('VehicleController.reqLoadLatestVehicleInfo error: $exception');
      }
      latestVehicleInfoInternal = null;
    }

    update();
  }

  Future<void> reqLoadHistory({
    int? vehicleId,
    int offset = 0,
    int limit = 18,
    String? searchText,
    String? searchColumnName,
  }) async {
    if (!hasToken) {
      historyItemsInternal = <VehicleInfoHistory>[];
      historyTotalCountInternal = 0;
      historyOffsetInternal = 0;
      update();
      return;
    }

    isLoadingInternal = true;
    update();

    try {
      final VehicleInfoHistoryResult? result = await repository.requestVehicleHistory(
        vehicleId: vehicleId,
        fromEpochMs: fromEpochMsInternal,
        toEpochMs: toEpochMsInternal,
        limit: limit,
        offset: offset,
        searchText: searchText,
        searchColumnName: searchColumnName,
      );

      if (result != null) {
        historyItemsInternal = result.items;
        historyTotalCountInternal = result.totalCount;
        historyOffsetInternal = offset;
        historyLimitInternal = limit;
      } else {
        historyItemsInternal = <VehicleInfoHistory>[];
        historyTotalCountInternal = 0;
        historyOffsetInternal = 0;
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('VehicleController.reqLoadHistory error: $exception');
      }
      historyItemsInternal = <VehicleInfoHistory>[];
      historyTotalCountInternal = 0;
      historyOffsetInternal = 0;
    } finally {
      isLoadingInternal = false;
      update();
    }
  }

  Future<void> reqLoadStatus({
    int? vehicleId,
    int offset = 0,
    int limit = 100,
    String? searchText,
    String? searchColumnName,
  }) async {
    if (!hasToken) {
      statusItemsInternal = <VehicleInfo>[];
      statusTotalCountInternal = 0;
      statusOffsetInternal = 0;
      update();
      return;
    }

    isLoadingInternal = true;
    update();

    try {
      final VehicleInfoResult? result = await repository.requestVehicleStatus(
        vehicleId: vehicleId,
        fromEpochMs: fromEpochMsInternal,
        toEpochMs: toEpochMsInternal,
        limit: limit,
        offset: offset,
        searchText: searchText,
        searchColumnName: searchColumnName,
      );

      if (result != null) {
        statusItemsInternal = result.items;
        statusTotalCountInternal = result.totalCount;
        statusOffsetInternal = offset;
        statusLimitInternal = limit;
      } else {
        statusItemsInternal = <VehicleInfo>[];
        statusTotalCountInternal = 0;
        statusOffsetInternal = 0;
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('VehicleController.reqLoadStatus error: $exception');
      }
      statusItemsInternal = <VehicleInfo>[];
      statusTotalCountInternal = 0;
      statusOffsetInternal = 0;
    } finally {
      isLoadingInternal = false;
      update();
    }
  }

  void selectVehicle(Vehicle vehicle) {
    selectedVehicleInternal = vehicle;
    update();
  }

  void clearSelection() {
    selectedVehicleInternal = null;
    update();
  }

  void clearHistory() {
    historyItemsInternal = <VehicleInfoHistory>[];
    historyTotalCountInternal = 0;
    historyOffsetInternal = 0;
    latestVehicleInfoInternal = null;
    update();
  }

  void clearStatus() {
    statusItemsInternal = <VehicleInfo>[];
    statusTotalCountInternal = 0;
    statusOffsetInternal = 0;
    update();
  }

  void reset() {
    isLoadingInternal = false;
    vehiclesInternal = <Vehicle>[];
    selectedVehicleInternal = null;
    historyItemsInternal = <VehicleInfoHistory>[];
    historyTotalCountInternal = 0;
    historyOffsetInternal = 0;
    historyLimitInternal = 18;
    statusItemsInternal = <VehicleInfo>[];
    statusTotalCountInternal = 0;
    statusOffsetInternal = 0;
    statusLimitInternal = 100;
    latestVehicleInfoInternal = null;
    fromEpochMsInternal = null;
    toEpochMsInternal = null;
    update();
  }
}
