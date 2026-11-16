// test/controller/dashboard_controller_load_test.dart
//
// DashboardController.loadPage / DashboardObjectsStatusController behaviour
// with fake repositories (no HTTP):
//   - a failed history request must not be shown as a loaded page
//   - a user action wins over a background refresh still in flight
//   - the objects panel survives the table auto-refresh
//   - closing the panel ends LIVE mode

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/model/object_model.dart';
import 'package:ivis/model/vehicle_model.dart';
import 'package:ivis/viewmodel/controller/dashboard_controller.dart';
import 'package:ivis/viewmodel/controller/dashboard_objects_status_controller.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/object_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';

import '../mocks/fake_repositories.dart';

// One recorded history request.
class _HistoryCall {
  _HistoryCall(this.vehicleId, this.offset, this.cursorId);
  final int? vehicleId;
  final int offset;
  final int? cursorId;
}

// Records every history request. With [gated] each request waits until the
// test completes its completer, so overlapping requests can be ordered.
class _ScriptedVehicleRepository extends FakeVehicleRepository {
  final List<_HistoryCall> calls = <_HistoryCall>[];
  final List<Completer<VehicleInfoHistoryResult?>> gates =
      <Completer<VehicleInfoHistoryResult?>>[];
  bool gated = false;

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
    calls.add(_HistoryCall(vehicleId, offset, cursorId));
    if (gated) {
      final Completer<VehicleInfoHistoryResult?> gate =
          Completer<VehicleInfoHistoryResult?>();
      gates.add(gate);
      return gate.future;
    }
    if (shouldThrow) throw Exception('scripted failure');
    return historyResult;
  }
}

// Object repository whose per-row fetch waits for the test, and whose LIVE
// query never touches HTTP.
class _GatedObjectRepository extends FakeObjectRepository {
  int vehicleInfoCalls = 0;
  Completer<DetectedObjectResult?>? gate;

  @override
  Future<DetectedObjectResult?> requestByVehicleInfo({
    required int vehicleId,
    int limit = 50000,
    int offset = 0,
    bool latestOnly = false,
    int? vehicleTimeStampMs,
    int? msgSeq,
    int? expectedObjectCount,
  }) {
    vehicleInfoCalls++;
    gate = Completer<DetectedObjectResult?>();
    return gate!.future;
  }

  @override
  Future<DetectedObjectResult> requestLatestStatus({
    required String sourceKind,
    int limit = 12,
    int offset = 0,
  }) async {
    return DetectedObjectResult();
  }
}

// A page of history rows with ids first..first+count-1.
VehicleInfoHistoryResult _page(int first, {int count = 18, int total = 54}) {
  return VehicleInfoHistoryResult(
    totalCount: total,
    items: <VehicleInfoHistory>[
      for (int i = 0; i < count; i++) VehicleInfoHistory(historyId: first + i),
    ],
  );
}

List<int?> _ids(DashboardController ctrl) => ctrl.pageRows
    .map((Map<String, dynamic> row) => row['history_id'] as int?)
    .toList();

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _ScriptedVehicleRepository vehicleRepo;
  late _GatedObjectRepository objectRepo;
  late DashboardController ctrl;
  late DashboardObjectsStatusController statusCtrl;

  setUp(() {
    Get.testMode = true;
    vehicleRepo = _ScriptedVehicleRepository();
    objectRepo = _GatedObjectRepository();
    final UserController userCtrl = Get.put(UserController());
    userCtrl.accessTokenForTest = 'fake_token_for_test';
    Get.put(VehicleController(repository: vehicleRepo));
    Get.put(InfraController(repository: FakeInfraRepository()));
    Get.put(ObjectController(repository: objectRepo));
    statusCtrl = Get.put(DashboardObjectsStatusController());
    ctrl = Get.put(DashboardController());
    ctrl.initialLoading = false;
  });

  tearDown(() {
    Get.deleteAll();
  });

  group('loadPage - failed history request', () {
    test('null result keeps page, rows and cursor, and raises the error flag',
        () async {
      // Arrange - page 1, then page 2 loaded normally
      vehicleRepo.historyResult = _page(1);
      await ctrl.loadPage(1, force: true);
      vehicleRepo.historyResult = _page(19);
      await ctrl.loadNextPage();
      expect(ctrl.currentPage, 2);
      expect(ctrl.historyLoadFailed, isFalse);
      final List<int?> page2Ids = _ids(ctrl);

      // Act - the request for page 3 fails (timeout / server error)
      vehicleRepo.historyResult = null;
      await ctrl.loadNextPage();

      // Assert - nothing moved, the failure is visible
      expect(ctrl.currentPage, 2);
      expect(_ids(ctrl), page2Ids);
      expect(ctrl.lastSeenHistoryId, 36);
      expect(ctrl.historyLoadFailed, isTrue);
      expect(ctrl.isLoading, isFalse);

      // Act - retry succeeds
      vehicleRepo.historyResult = _page(37);
      await ctrl.loadNextPage();

      // Assert - page 3 was asked with page 2's cursor, not a duplicate one
      expect(vehicleRepo.calls.last.cursorId, 36);
      expect(ctrl.currentPage, 3);
      expect(_ids(ctrl).first, 37);
      expect(ctrl.historyLoadFailed, isFalse);

      // Act - back: the stack holds exactly one cursor per loaded page
      vehicleRepo.historyResult = _page(19);
      await ctrl.loadPrevPage();
      expect(vehicleRepo.calls.last.cursorId, 18);
      expect(ctrl.currentPage, 2);
    });

    test('exception keeps the page and raises the error flag', () async {
      // Arrange
      vehicleRepo.historyResult = _page(1);
      await ctrl.loadPage(1, force: true);

      // Act
      vehicleRepo.shouldThrow = true;
      await ctrl.loadNextPage();

      // Assert
      expect(ctrl.currentPage, 1);
      expect(_ids(ctrl).first, 1);
      expect(ctrl.historyLoadFailed, isTrue);
    });

    test('failed page is not cached: a later jump asks the server again',
        () async {
      // Arrange
      vehicleRepo.historyResult = _page(1);
      await ctrl.loadPage(1, force: true);
      vehicleRepo.historyResult = null;
      ctrl.changePage(3);
      await _settle();
      expect(ctrl.currentPage, 1);
      expect(ctrl.historyLoadFailed, isTrue);
      final int callsAfterFailure = vehicleRepo.calls.length;

      // Act
      vehicleRepo.historyResult = _page(37);
      ctrl.changePage(3);
      await _settle();

      // Assert
      expect(vehicleRepo.calls.length, callsAfterFailure + 1);
      expect(ctrl.currentPage, 3);
      expect(_ids(ctrl).first, 37);
      expect(ctrl.historyLoadFailed, isFalse);
    });

    test('failed refresh keeps the rows; the next good one clears the flag',
        () async {
      // Arrange
      vehicleRepo.historyResult = _page(1);
      await ctrl.loadPage(1, force: true);

      // Act / Assert - failure
      vehicleRepo.historyResult = null;
      await ctrl.refreshCurrent();
      expect(ctrl.historyLoadFailed, isTrue);
      expect(_ids(ctrl).first, 1);
      expect(ctrl.totalCount, 54);

      // Act / Assert - recovery
      vehicleRepo.historyResult = _page(1);
      await ctrl.refreshCurrent();
      expect(ctrl.historyLoadFailed, isFalse);
    });
  });

  group('user action during a background refresh', () {
    test('filter change is not dropped and its result wins', () async {
      // Arrange - page 1 loaded, then a background refresh hangs
      vehicleRepo.historyResult = _page(1);
      await ctrl.loadPage(1, force: true);
      vehicleRepo.gated = true;
      final Future<void> background = ctrl.refreshCurrent();
      await _settle();
      expect(ctrl.isLoading, isTrue);

      // Act - the user picks vehicle 0 while the refresh is still running
      final Future<void> user = ctrl.setVehicleIdFilter('0');
      await _settle();
      expect(vehicleRepo.gates.length, 2);
      vehicleRepo.gates[1].complete(_page(100, count: 3, total: 3));
      await user;
      // the superseded background answer arrives last
      vehicleRepo.gates[0].complete(_page(1));
      await background;

      // Assert - id 0 is a real device and went to the server as 0
      expect(ctrl.vehicleIdFilter, '0');
      expect(vehicleRepo.calls.last.vehicleId, 0);
      expect(_ids(ctrl), <int?>[100, 101, 102]);
      expect(ctrl.totalCount, 3);
      expect(ctrl.isLoading, isFalse);
    });

    test('page click is not dropped and its result wins', () async {
      // Arrange
      vehicleRepo.historyResult = _page(1);
      await ctrl.loadPage(1, force: true);
      vehicleRepo.gated = true;
      final Future<void> background = ctrl.refreshCurrent();
      await _settle();

      // Act
      final Future<void> user = ctrl.loadNextPage();
      await _settle();
      vehicleRepo.gates[1].complete(_page(19));
      await user;
      vehicleRepo.gates[0].complete(_page(1));
      await background;

      // Assert
      expect(vehicleRepo.calls.last.cursorId, 18);
      expect(ctrl.currentPage, 2);
      expect(_ids(ctrl).first, 19);
      expect(ctrl.isLoading, isFalse);
    });
  });

  group('objects panel during table auto-refresh', () {
    Map<String, dynamic> row(int historyId) => <String, dynamic>{
          'history_id': historyId,
          'vehicle_id': 0,
          'number_of_objects': 2,
        };

    DetectedObjectResult twoObjects() => DetectedObjectResult(
          totalCount: 2,
          items: <DetectedObject>[
            DetectedObject.fromJson(
                <String, dynamic>{'detected_object_id': 1, 'object_type': 1}),
            DetectedObject.fromJson(
                <String, dynamic>{'detected_object_id': 2, 'object_type': 4}),
          ],
        );

    test('a tick does not restart the fetch running for the selected row',
        () async {
      // Arrange - row clicked, its fetch is in flight
      unawaited(statusCtrl.showObjectsStatusFromRow(row(7)));
      await _settle();
      expect(objectRepo.vehicleInfoCalls, 1);
      expect(statusCtrl.objectsStatusLoading, isTrue);

      // Act - auto-refresh brings a new copy of the same row
      statusCtrl.refreshOrFetchObjectsStatus(<Map<String, dynamic>>[row(7)]);
      await _settle();

      // Assert - same request still pending, nothing restarted
      expect(objectRepo.vehicleInfoCalls, 1);
      expect(statusCtrl.objectsStatusLoading, isTrue);

      // Act - the original fetch answers
      objectRepo.gate!.complete(twoObjects());
      await _settle();

      // Assert - its result is used, not discarded
      expect(statusCtrl.objectsStatusItems.length, 2);
      expect(statusCtrl.objectsStatusLoading, isFalse);
    });

    test('loaded list stays through ticks, also when the row left the page',
        () async {
      // Arrange - row clicked and loaded
      unawaited(statusCtrl.showObjectsStatusFromRow(row(7)));
      await _settle();
      objectRepo.gate!.complete(twoObjects());
      await _settle();
      final List<DetectedObject> shown = statusCtrl.objectsStatusItems;
      expect(shown.length, 2);

      // Act - tick with the row still on the page
      statusCtrl.refreshOrFetchObjectsStatus(<Map<String, dynamic>>[row(7)]);
      await _settle();

      // Assert - not blanked, not reloaded
      expect(identical(statusCtrl.objectsStatusItems, shown), isTrue);
      expect(statusCtrl.objectsStatusLoading, isFalse);
      expect(objectRepo.vehicleInfoCalls, 1);

      // Act - tick after newer rows pushed it off page 1
      statusCtrl.refreshOrFetchObjectsStatus(
          <Map<String, dynamic>>[row(8), row(9)]);
      await _settle();

      // Assert - selection and list are kept
      expect(identical(statusCtrl.objectsStatusItems, shown), isTrue);
      expect(statusCtrl.isObjectsStatusOpen, isTrue);
      expect(objectRepo.vehicleInfoCalls, 1);

      // Act - manual refresh still reloads the kept selection
      statusCtrl.refreshObjectsStatus();
      await _settle();
      expect(objectRepo.vehicleInfoCalls, 2);
      objectRepo.gate!.complete(twoObjects());
      await _settle();
    });

    test('clicking another row replaces the running fetch', () async {
      // Arrange
      unawaited(statusCtrl.showObjectsStatusFromRow(row(7)));
      await _settle();
      final Completer<DetectedObjectResult?> firstGate = objectRepo.gate!;

      // Act
      unawaited(statusCtrl.showObjectsStatusFromRow(row(8)));
      await _settle();
      expect(objectRepo.vehicleInfoCalls, 2);
      firstGate.complete(DetectedObjectResult(
        totalCount: 1,
        items: <DetectedObject>[
          DetectedObject.fromJson(
              <String, dynamic>{'detected_object_id': 99, 'object_type': 1}),
        ],
      ));
      objectRepo.gate!.complete(twoObjects());
      await _settle();

      // Assert - only the second row's objects are shown
      expect(statusCtrl.objectsStatusItems.length, 2);
      expect(statusCtrl.objectsStatusLoading, isFalse);
    });
  });

  group('LIVE mode and panel close', () {
    test('closing the panel ends LIVE mode', () async {
      // Arrange
      statusCtrl.toggleObjectsLiveMode();
      await _settle();
      expect(statusCtrl.isObjectsLiveMode, isTrue);
      expect(statusCtrl.isObjectsStatusOpen, isTrue);

      // Act - close, then reopen
      statusCtrl.toggleObjectsStatus();
      expect(statusCtrl.isObjectsStatusOpen, isFalse);
      expect(statusCtrl.isObjectsLiveMode, isFalse);
      statusCtrl.toggleObjectsStatus();

      // Assert - reopened panel does not claim LIVE without a poller
      expect(statusCtrl.isObjectsStatusOpen, isTrue);
      expect(statusCtrl.isObjectsLiveMode, isFalse);
    });
  });
}
