// test/mocks/fake_repositories.dart
//
// GetX Builder 아키텍처 모킹 테스트용 Fake Repository 구현체.
// HTTP 없이 미리 설정한 데이터를 반환하거나 예외를 던져 컨트롤러 로직을 검증한다.
//
// 사용법:
//   final fake = FakeVehicleRepository();
//   fake.vehicleListResult = [Vehicle(vehicleId: 1)];
//   final ctrl = Get.put(VehicleController(repository: fake));

import 'package:ivis/model/infra_model.dart';
import 'package:ivis/model/object_model.dart';
import 'package:ivis/model/vehicle_model.dart';
import 'package:ivis/viewmodel/repository/infra_repository.dart';
import 'package:ivis/viewmodel/repository/object_repository.dart';
import 'package:ivis/viewmodel/repository/vehicle_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FakeVehicleRepository — VehicleRepository 대체 구현체
// ─────────────────────────────────────────────────────────────────────────────
class FakeVehicleRepository extends VehicleRepository {
  // 각 메서드가 반환할 값 (테스트에서 설정)
  List<Vehicle> vehicleListResult = <Vehicle>[];
  Vehicle? vehicleByIdResult;
  VehicleInfo? latestInfoResult;
  VehicleInfoResult? statusResult;
  VehicleInfoHistoryResult? historyResult;

  // true 로 설정하면 모든 요청이 예외를 던진다 (오류 처리 테스트용)
  bool shouldThrow = false;

  @override
  Future<List<Vehicle>> requestVehicleList() async {
    if (shouldThrow) throw Exception('FakeVehicleRepository: 네트워크 오류');
    return vehicleListResult;
  }

  @override
  Future<Vehicle?> requestVehicleById(int vehicleId) async {
    if (shouldThrow) throw Exception('FakeVehicleRepository: 네트워크 오류');
    return vehicleByIdResult;
  }

  @override
  Future<VehicleInfo?> requestLatestVehicleInfo(int vehicleId) async {
    if (shouldThrow) throw Exception('FakeVehicleRepository: 네트워크 오류');
    return latestInfoResult;
  }

  @override
  Future<VehicleInfoResult?> requestVehicleStatus({
    int? vehicleId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
    int? cursorId,
    String? cursorDirection,
  }) async {
    if (shouldThrow) throw Exception('FakeVehicleRepository: 네트워크 오류');
    return statusResult;
  }

  @override
  Future<VehicleInfoHistoryResult?> requestVehicleHistory({
    int? vehicleId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
    int? cursorId,
    String? cursorDirection,
  }) async {
    if (shouldThrow) throw Exception('FakeVehicleRepository: 네트워크 오류');
    return historyResult;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeInfraRepository — InfraRepository 대체 구현체
// ─────────────────────────────────────────────────────────────────────────────
class FakeInfraRepository extends InfraRepository {
  List<int> identifiersResult = <int>[];
  InfraInfo? latestInfoResult;
  InfraInfoResult? statusResult;
  InfraInfoHistoryResult? historyResult;

  bool shouldThrow = false;

  @override
  Future<List<int>> requestInfraIdentifiers() async {
    if (shouldThrow) throw Exception('FakeInfraRepository: 네트워크 오류');
    return identifiersResult;
  }

  @override
  Future<InfraInfo?> requestLatestInfraInfo(int infraId) async {
    if (shouldThrow) throw Exception('FakeInfraRepository: 네트워크 오류');
    return latestInfoResult;
  }

  @override
  Future<InfraInfoResult?> requestInfraStatus({
    int? infraId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
    int? cursorId,
    String? cursorDirection,
  }) async {
    if (shouldThrow) throw Exception('FakeInfraRepository: 네트워크 오류');
    return statusResult;
  }

  @override
  Future<InfraInfoHistoryResult?> requestInfraHistory({
    int? infraId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
    int? cursorId,
    String? cursorDirection,
  }) async {
    if (shouldThrow) throw Exception('FakeInfraRepository: 네트워크 오류');
    return historyResult;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeObjectRepository — ObjectRepository 대체 구현체
// ─────────────────────────────────────────────────────────────────────────────
class FakeObjectRepository extends ObjectRepository {
  DetectedObjectResult? byVehicleInfoResult;
  DetectedObjectResult? byInfraInfoResult;

  bool shouldThrow = false;

  @override
  Future<DetectedObjectResult?> requestByVehicleInfo({
    required int vehicleId,
    int limit = 50000,
    int offset = 0,
    bool latestOnly = false,
    int? vehicleTimeStampMs,
    int? msgSeq,
    int? expectedObjectCount,
  }) async {
    if (shouldThrow) throw Exception('FakeObjectRepository: 네트워크 오류');
    return byVehicleInfoResult;
  }

  @override
  Future<DetectedObjectResult?> requestByInfraInfo({
    required int infraId,
    int limit = 200,
    int offset = 0,
    bool latestOnly = false,
    int? infraTimeStampMs,
    int? msgSeq,
    int? expectedObjectCount,
  }) async {
    if (shouldThrow) throw Exception('FakeObjectRepository: 네트워크 오류');
    return byInfraInfoResult;
  }
}
