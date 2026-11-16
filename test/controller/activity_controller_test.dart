// test/controller/activity_controller_test.dart
//
// ActivityController / ActivityChartsController tests with fake repositories
// (no HTTP). Covers: device id 0 in the catalog, per-chart periods kept by the
// background refresh, and stale responses dropped when the selection changes.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/viewmodel/controller/activity_charts_controller.dart';
import 'package:ivis/viewmodel/controller/activity_controller.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/repository/activity_repository.dart';
import 'package:ivis/viewmodel/repository/device_registry_repository.dart';

import '../mocks/fake_repositories.dart';

// Returns a future the test completes by hand, to control response order.
typedef Gate = Future<void> Function(int id, int days);

class _FakeActivityRepository extends ActivityRepository {
  // Gates keyed by what the request asked for; absent key = answer at once.
  final Map<int, Completer<void>> globalChartGates = <int, Completer<void>>{};
  final Map<int, Completer<void>> deviceChartGates = <int, Completer<void>>{};
  final Map<int, Completer<void>> feedGates = <int, Completer<void>>{};
  final Map<String, Completer<void>> usageGates = <String, Completer<void>>{};
  final List<int> globalChartCalls = <int>[];

  @override
  Future<({List<ActivityEventItem> items, int totalCount})> requestEvents({
    int? vehicleId,
    int? deviceId,
    String? deviceType,
    int? minSeverity,
    int? fromMs,
    int? toMs,
    int limit = 50,
    int offset = 0,
  }) async {
    final int severity = minSeverity ?? 1;
    if (deviceType == null) await feedGates[severity]?.future;
    // totalCount echoes the severity so tests can tell responses apart.
    return (items: <ActivityEventItem>[], totalCount: severity);
  }

  @override
  Future<List<ActivityChartDay>> requestChartData({
    int days = 30,
    String? deviceType,
    int? deviceId,
    int? fromMs,
    int? toMs,
  }) async {
    if (fromMs != null) return <ActivityChartDay>[];
    if (deviceType == null) {
      globalChartCalls.add(days);
      await globalChartGates[days]?.future;
    } else {
      await deviceChartGates[days]?.future;
    }
    // total echoes the requested days.
    return <ActivityChartDay>[
      ActivityChartDay(dateKst: 'd$days', total: days, byType: const <String, int>{}),
    ];
  }

  @override
  Future<DistanceStatsResult> requestDistanceStats({
    int days = 30,
    int? vehicleId,
    bool includeRuntime = false,
  }) async {
    return DistanceStatsResult(
      vehicles: const <VehicleDistanceStat>[],
      fleetDaily: const <DailyDistancePoint>[],
      fleetTotalKm: days.toDouble(),
    );
  }

  @override
  Future<UsageStatsResult> requestUsageStats({String period = 'day'}) async {
    await usageGates[period]?.future;
    return UsageStatsResult(
      period: period,
      items: const <UsagePeriodItem>[],
      totalM: 0,
      totalKm: 0,
    );
  }
}

class _FakeRegistryRepository extends DeviceRegistryRepository {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> requestList({String? deviceType}) async => rows;
}

class _FakeVehicleStatsRepository extends FakeVehicleRepository {
  Gate? operationGate;
  Gate? objectGate;
  final List<int> operationDays = <int>[];
  final List<int> objectDays = <int>[];

  @override
  Future<List<Map<String, dynamic>>> requestDailyOperationStats({
    required int vehicleId,
    int days = 30,
  }) async {
    operationDays.add(days);
    await operationGate?.call(vehicleId, days);
    return <Map<String, dynamic>>[
      <String, dynamic>{'vehicle_id': vehicleId, 'days': days},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> requestVehicleDailyObjectCounts({
    required int vehicleId,
    int days = 30,
  }) async {
    objectDays.add(days);
    await objectGate?.call(vehicleId, days);
    return <Map<String, dynamic>>[
      <String, dynamic>{'vehicle_id': vehicleId, 'days': days},
    ];
  }
}

class _FakeInfraStatsRepository extends FakeInfraRepository {
  Gate? objectGate;
  final Map<int, Completer<void>> totalGates = <int, Completer<void>>{};
  final List<int> objectDays = <int>[];

  @override
  Future<List<Map<String, dynamic>>> requestInfraDailyObjectCounts({
    required int infraId,
    int days = 30,
  }) async {
    objectDays.add(days);
    await objectGate?.call(infraId, days);
    return <Map<String, dynamic>>[
      <String, dynamic>{'infra_id': infraId, 'days': days},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> requestInfraTotalByInfra({int days = 30}) async {
    await totalGates[days]?.future;
    return <Map<String, dynamic>>[
      <String, dynamic>{'days': days},
    ];
  }
}

// Lets pending microtasks / unawaited loaders run to completion.
Future<void> _settle() async {
  for (int i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeActivityRepository activityRepo;
  late _FakeRegistryRepository registryRepo;
  late _FakeVehicleStatsRepository vehicleRepo;
  late _FakeInfraStatsRepository infraRepo;
  late ActivityChartsController charts;
  late ActivityController ctrl;

  setUp(() {
    Get.testMode = true;
    Get.put(UserController()).accessTokenForTest = 'fake_token_for_test';

    activityRepo = _FakeActivityRepository();
    registryRepo = _FakeRegistryRepository();
    vehicleRepo = _FakeVehicleStatsRepository();
    infraRepo = _FakeInfraStatsRepository();

    charts = Get.put(ActivityChartsController(repository: activityRepo));
    // Not registered in Get on purpose: onInit would start the poll timers.
    ctrl = ActivityController(
      repository: activityRepo,
      registryRepository: registryRepo,
      vehicleRepository: vehicleRepo,
      infraRepository: infraRepo,
    );
  });

  tearDown(() {
    Get.deleteAll();
  });

  group('device id 0', () {
    test('vehicle 0 and infra 0 from the registry are listed in the catalog', () {
      ctrl.registryRows = <Map<String, dynamic>>[
        <String, dynamic>{'device_type': 'vehicle', 'device_id': 0},
        <String, dynamic>{'device_type': 'vehicle', 'device_id': '7'},
        <String, dynamic>{'device_type': 'vehicle', 'device_id': -1},
        <String, dynamic>{'device_type': 'vehicle', 'device_id': null},
        <String, dynamic>{'device_type': 'infra', 'device_id': 0},
        <String, dynamic>{'device_type': 'infra', 'device_id': 132},
      ];

      expect(ctrl.vehicleCatalog.map((ActivityCatalogItem e) => e.deviceId), <int>[0, 7]);
      expect(ctrl.infraCatalog.map((ActivityCatalogItem e) => e.deviceId), <int>[0, 132]);
    });

    test('infra 0 reported by InfraController is listed', () {
      final InfraController infraCtrl = Get.put(InfraController(repository: infraRepo));
      infraCtrl.infraIdentifiersInternal = <int>[0, 5];

      expect(ctrl.infraCatalog.map((ActivityCatalogItem e) => e.deviceId), <int>[0, 5]);
    });

    test('catalog refresh keeps a selected device with id 0', () async {
      registryRepo.rows = <Map<String, dynamic>>[
        <String, dynamic>{'device_type': 'vehicle', 'device_id': 0},
      ];
      ctrl.selectedDeviceType = 'vehicle';
      ctrl.selectedDeviceId = 0;

      await ctrl.refreshCatalog();

      expect(ctrl.selectedDeviceType, 'vehicle');
      expect(ctrl.selectedDeviceId, 0);
      expect(ctrl.selectedCatalogItem?.deviceId, 0);
    });
  });

  group('per-chart period survives the background refresh', () {
    test('vehicle charts reload with their own selected periods', () async {
      await ctrl.selectDevice('vehicle', 0);
      await _settle();
      await ctrl.setSelectedOperationChartPeriod('weekly');
      await ctrl.setSelectedVehicleObjectChartPeriod('monthly');
      vehicleRepo.operationDays.clear();
      vehicleRepo.objectDays.clear();

      await ctrl.refreshSelectedDeviceAnalytics(silent: true);
      await _settle();

      expect(vehicleRepo.operationDays, <int>[84]);
      expect(vehicleRepo.objectDays, <int>[365]);
      expect(ctrl.vehicleDailyOperationStats.single['days'], 84);
      expect(ctrl.vehicleDailyObjectCounts.single['days'], 365);
    });

    test('infra object chart reloads with its own selected period', () async {
      await ctrl.selectDevice('infra', 0);
      await _settle();
      await ctrl.setSelectedInfraObjectChartPeriod('weekly');
      infraRepo.objectDays.clear();

      await ctrl.refreshSelectedDeviceAnalytics(silent: true);
      await _settle();

      expect(infraRepo.objectDays, <int>[84]);
      expect(ctrl.infraDailyObjectCounts.single['days'], 84);
    });

    test('changing the distance period does not reload the operation chart with it',
        () async {
      await ctrl.selectDevice('vehicle', 3);
      await _settle();
      await ctrl.setSelectedOperationChartPeriod('weekly');
      vehicleRepo.operationDays.clear();

      await ctrl.setSelectedDeviceDistanceChartPeriod('yearly');
      await _settle();

      expect(vehicleRepo.operationDays, everyElement(84));
      expect(ctrl.vehicleDailyOperationStats.single['days'], 84);
    });
  });

  group('stale responses are dropped', () {
    test('slower response for an older period does not overwrite the newer one',
        () async {
      await ctrl.selectDevice('vehicle', 1);
      await _settle();
      final Completer<void> weekly = Completer<void>();
      final Completer<void> monthly = Completer<void>();
      vehicleRepo.operationGate = (int id, int days) =>
          days == 84 ? weekly.future : (days == 365 ? monthly.future : Future<void>.value());

      final Future<void> first = ctrl.setSelectedOperationChartPeriod('weekly');
      final Future<void> second = ctrl.setSelectedOperationChartPeriod('monthly');
      monthly.complete();
      await second;
      expect(ctrl.vehicleDailyOperationStats.single['days'], 365);
      expect(ctrl.isOperationStatsLoading, isFalse);

      weekly.complete();
      await first;

      expect(ctrl.selectedOperationChartPeriod, 'monthly');
      expect(ctrl.vehicleDailyOperationStats.single['days'], 365);
      expect(ctrl.isOperationStatsLoading, isFalse);
    });

    test('response for the previous device is not shown after switching device',
        () async {
      await ctrl.selectDevice('vehicle', 1);
      await _settle();
      final Completer<void> slow = Completer<void>();
      vehicleRepo.objectGate =
          (int id, int days) => id == 1 && days == 84 ? slow.future : Future<void>.value();

      final Future<void> old = ctrl.setSelectedVehicleObjectChartPeriod('weekly');
      await ctrl.selectDevice('vehicle', 2);
      await _settle();
      slow.complete();
      await old;

      expect(ctrl.vehicleDailyObjectCounts.single['vehicle_id'], 2);
      expect(ctrl.isVehicleObjectChartLoading, isFalse);
    });

    test('infra loaders drop an outdated response', () async {
      await ctrl.selectDevice('infra', 0);
      await _settle();
      final Completer<void> slowDaily = Completer<void>();
      infraRepo.objectGate =
          (int id, int days) => days == 84 ? slowDaily.future : Future<void>.value();
      infraRepo.totalGates[7] = Completer<void>();

      final Future<void> oldDaily = ctrl.setSelectedInfraObjectChartPeriod('weekly');
      await ctrl.setSelectedInfraObjectChartPeriod('monthly');
      final Future<void> oldTotal = ctrl.loadInfraTotalByInfra(days: 7);
      await ctrl.loadInfraTotalByInfra(days: 30);
      slowDaily.complete();
      infraRepo.totalGates[7]!.complete();
      await oldDaily;
      await oldTotal;

      expect(ctrl.infraDailyObjectCounts.single['days'], 365);
      expect(ctrl.infraTotalByInfra.single['days'], 30);
      expect(ctrl.isInfraObjectChartLoading, isFalse);
      expect(ctrl.isInfraTotalChartLoading, isFalse);
    });

    test('device analytics for an older global period do not overwrite the newer',
        () async {
      await ctrl.selectDevice('vehicle', 1);
      await _settle();
      activityRepo.deviceChartGates[30] = Completer<void>();

      final Future<void> old = ctrl.refreshSelectedDeviceAnalytics();
      charts.chartDays_ = 7;
      await ctrl.refreshSelectedDeviceAnalytics();
      expect(ctrl.deviceChartDays.single.total, 7);
      expect(ctrl.isDeviceChartLoading, isFalse);

      activityRepo.deviceChartGates[30]!.complete();
      await old;

      expect(ctrl.deviceChartDays.single.total, 7);
      expect(ctrl.isDeviceChartLoading, isFalse);
    });
  });

  group('selection changed while loading', () {
    test('global chart period changed mid-load loads and shows the new period',
        () async {
      activityRepo.globalChartGates[30] = Completer<void>();
      final Future<void> old = charts.refreshCharts();
      expect(charts.isChartLoading, isTrue);

      expect(charts.setGlobalChartPeriod(7), isTrue);
      await _settle();
      expect(activityRepo.globalChartCalls, <int>[30, 7]);
      expect(charts.chartDays.single.total, 7);
      expect(charts.isChartLoading, isFalse);

      activityRepo.globalChartGates[30]!.complete();
      await old;

      expect(charts.chartDays.single.total, 7);
      expect(charts.distanceStats?.fleetTotalKm, 7);
      expect(charts.isChartLoading, isFalse);
      expect(charts.isDistanceLoading, isFalse);
    });

    test('duplicate refresh of the same period is still skipped', () async {
      activityRepo.globalChartGates[30] = Completer<void>();
      final Future<void> first = charts.refreshCharts();
      await charts.refreshCharts();

      expect(activityRepo.globalChartCalls, <int>[30]);

      activityRepo.globalChartGates[30]!.complete();
      await first;
      expect(charts.isChartLoading, isFalse);
    });

    test('usage period changed mid-load shows the new period', () async {
      activityRepo.usageGates['day'] = Completer<void>();
      final Future<void> old = charts.refreshUsageStats();

      charts.setUsagePeriod('month');
      await _settle();
      expect(charts.usageStats?.period, 'month');

      activityRepo.usageGates['day']!.complete();
      await old;

      expect(charts.usageStats?.period, 'month');
      expect(charts.isUsageLoading, isFalse);
    });

    test('feed severity changed mid-load shows the new filter', () async {
      activityRepo.feedGates[1] = Completer<void>();
      final Future<void> old = ctrl.refreshFeed();
      expect(ctrl.isFeedLoading, isTrue);

      ctrl.setFeedSeverity(3);
      await _settle();
      expect(ctrl.feedTotal, 3);

      activityRepo.feedGates[1]!.complete();
      await old;

      expect(ctrl.feedMinSeverity, 3);
      expect(ctrl.feedTotal, 3);
      expect(ctrl.isFeedLoading, isFalse);
    });
  });
}
