import 'dart:async';

import 'package:get/get.dart';

import '../../model/infra_model.dart';
import '../../model/vehicle_model.dart';
import '../controller/infra_controller.dart';
import '../controller/vehicle_controller.dart';
import '../repository/infra_repository.dart';
import '../repository/vehicle_repository.dart';

enum DeviceStatus { moving, idle, offline, unknown }

class LiveStatusController extends GetxController {
  final VehicleRepository _vehicleRepo = VehicleRepository();
  final InfraRepository _infraRepo = InfraRepository();

  final Map<int, VehicleInfo> vehicleLiveCache = <int, VehicleInfo>{};
  final Map<int, InfraInfo> infraLiveCache = <int, InfraInfo>{};

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    // 즉시 첫 갱신, 이후 5초마다
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> _refresh() async {
    // ★ 2026-06-11: 100대 × 개별 /latest 요청(110 병렬) → HTTP/1.1 브라우저
    //   동시연결 6개 제한으로 pending 누적(ERR_INSUFFICIENT_RESOURCES) 발생.
    //   배치 엔드포인트(/status, limit 1000)로 전체를 한 번에 받아 2개 요청으로 축소.
    final List<Future<void>> fetches = <Future<void>>[];

    if (Get.isRegistered<VehicleController>()) {
      fetches.add(
        _vehicleRepo.requestAllLatestVehicleInfo().then((List<VehicleInfo> list) {
          for (final VehicleInfo info in list) {
            final int? id = info.vehicleId;
            if (id != null) vehicleLiveCache[id] = info;
          }
        }).catchError((Object _) {}),
      );
    }

    if (Get.isRegistered<InfraController>()) {
      fetches.add(
        _infraRepo.requestAllLatestInfraInfo().then((List<InfraInfo> list) {
          for (final InfraInfo info in list) {
            final int? id = info.infraId;
            if (id != null) infraLiveCache[id] = info;
          }
        }).catchError((Object _) {}),
      );
    }

    if (fetches.isEmpty) return;
    await Future.wait(fetches);
    // 사이드바만 갱신 — 차트 GetBuilder는 건드리지 않음
    update();
  }

  DeviceStatus vehicleDeviceStatus(int vehicleId) {
    final VehicleInfo? info = vehicleLiveCache[vehicleId];
    if (info == null) return DeviceStatus.unknown;
    final int? lastMs = info.timeStampMs ?? info.timeStamp;
    if (lastMs == null) return DeviceStatus.unknown;
    final Duration age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true).toLocal(),
    );
    if (age > const Duration(seconds: 10)) return DeviceStatus.offline;
    final double kph = info.velocityKph ?? 0;
    return kph >= 1.0 ? DeviceStatus.moving : DeviceStatus.idle;
  }

  DeviceStatus infraDeviceStatus(int infraId) {
    final InfraInfo? info = infraLiveCache[infraId];
    if (info == null) return DeviceStatus.unknown;
    final int? lastMs = info.timeStampMs ?? info.timeStamp;
    if (lastMs == null) return DeviceStatus.unknown;
    final Duration age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true).toLocal(),
    );
    if (age > const Duration(seconds: 10)) return DeviceStatus.offline;
    return DeviceStatus.moving;
  }

  int? latestTimestampMs({required String deviceType, required int deviceId}) {
    if (deviceType == 'vehicle') {
      final VehicleInfo? info = vehicleLiveCache[deviceId];
      return info?.timeStampMs ?? info?.timeStamp;
    }
    if (deviceType == 'infra') {
      final InfraInfo? info = infraLiveCache[deviceId];
      return info?.timeStampMs ?? info?.timeStamp;
    }
    return null;
  }

  bool isDeviceOnline({
    required String deviceType,
    required int deviceId,
    Duration window = const Duration(minutes: 5),
  }) {
    final int? tsMs = latestTimestampMs(deviceType: deviceType, deviceId: deviceId);
    if (tsMs == null) return false;
    return DateTime.now()
            .toUtc()
            .difference(DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true)) <
        window;
  }
}
