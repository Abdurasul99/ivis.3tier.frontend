// tab_dashboard.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../i18n/app_locale.dart';
import '../../model/infra_model.dart';
import '../../model/object_model.dart';
import '../../model/vehicle_model.dart';
import '../../utils/geo_utils.dart';
import '../../view/components/infra_vehicle_map.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/repository/log_repository.dart';

class _ExportSortSpec {
  final String field;
  final PlutoColumnSort direction;

  const _ExportSortSpec({
    required this.field,
    required this.direction,
  });
}

enum _MapPanelPlacement {
  left,
  right,
  bottom,
}

class TabDashboard extends StatefulWidget {
  const TabDashboard({super.key});

  @override
  State<TabDashboard> createState() {
    return _TabDashboardState();
  }
}

class _TabDashboardState extends State<TabDashboard>
    with AutomaticKeepAliveClientMixin<TabDashboard> {
  late final DashboardController _controller;

  PlutoGridStateManager? _gridStateManager;
  bool _gridReady = false;
  StreamSubscription<PlutoGridEvent>? _gridEventSubscription;

  List<PlutoColumn> _cachedColumns = <PlutoColumn>[];

  String _lastCachedFieldsKey = '';

  final LogRepository _logRepository = LogRepository();
  _MapPanelPlacement _mapPanelPlacement = _MapPanelPlacement.right;
  double _tablePanelRatio = 0.60;
  bool _isDialogOpen = false;

  // Jump-to-page 입력 컨트롤러
  final TextEditingController _jumpPageController = TextEditingController();
  final FocusNode _jumpPageFocusNode = FocusNode();

  // 지도 패널 GlobalKey (오토팔로우 토글 등 상태 접근용)
  final GlobalKey<InfraVehicleMapPanelState> _mapPanelKey =
      GlobalKey<InfraVehicleMapPanelState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : Get.put(DashboardController());
    _controller.onGridUpdateNeeded = _updateGrid;
    _rebuildCachedColumns();
    Future<void>.microtask(() async {
      try {
        await _controller.initialize();
      } finally {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _gridEventSubscription?.cancel();
    if (_controller.onGridUpdateNeeded == _updateGrid) {
      _controller.onGridUpdateNeeded = null;
    }
    _jumpPageController.dispose();
    _jumpPageFocusNode.dispose();
    super.dispose();
  }

  void _rebuildCachedColumns() {
    _cachedColumns = _buildPlutoColumns(_controller.cachedFields);
    _lastCachedFieldsKey = _controller.cachedFields.join(',');
  }

  void _updateGrid() {
    if (!_gridReady || _gridStateManager == null) return;

    final PlutoGridStateManager manager = _gridStateManager!;
    try {
      manager.setShowLoading(
          _controller.isLoading && !_controller.firstDataArrived);

      if (_controller.isLoading && !_controller.firstDataArrived) return;

      final List<PlutoRow> rowsToInsert = _controller.pageRows.isEmpty
          ? <PlutoRow>[]
          : _buildPlutoRows(_controller.pageRows, _controller.cachedFields);

      manager.removeAllRows();
      if (rowsToInsert.isNotEmpty) {
        manager.appendRows(rowsToInsert);
      }
      manager.notifyListeners();
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('_updateGrid error: $exception');
      }
    }
  }

  void _onColumnFilterChanged() {
    // isLoading 중에도 필터 변경을 무시하지 않음:
    // 로딩 중 사용자가 필터를 변경하면 이전 요청은 버리고 새 필터로 다시 요청해야 함
    if (!_gridReady || !mounted) return;
    _handleColumnFilterChange();
  }

  Map<String, String?> _buildServerSearchParamsFromFilters() {
    if (_controller.activeFilterColumn != null &&
        _controller.activeFilterValue != null &&
        _controller.activeFilterValue!.trim().isNotEmpty) {
      return <String, String?>{
        'text': _controller.activeFilterValue!.trim(),
        'column': _controller.activeFilterColumn,
      };
    }

    if (_gridStateManager == null) {
      return <String, String?>{'text': null, 'column': null};
    }

    final PlutoGridStateManager manager = _gridStateManager!;
    if (manager.filterRows.isEmpty) {
      return <String, String?>{'text': null, 'column': null};
    }

    for (final PlutoRow filterRow in manager.filterRows) {
      final PlutoCell? columnFieldCell =
          filterRow.cells[FilterHelper.filterFieldColumn];
      final PlutoCell? valueCell =
          filterRow.cells[FilterHelper.filterFieldValue];

      if (columnFieldCell == null || valueCell == null) continue;

      final String field = columnFieldCell.value.toString();
      final String value = valueCell.value.toString().trim();
      if (value.isEmpty) continue;

      return <String, String?>{'text': value, 'column': field};
    }

    return <String, String?>{'text': null, 'column': null};
  }

  void _handleColumnFilterChange() {
    if (_gridStateManager == null) return;
    final PlutoGridStateManager manager = _gridStateManager!;

    if (manager.filterRows.isEmpty) {
      _controller.clearActiveFilter();
      return;
    }

    String? newFilterColumn;
    String? newFilterValue;

    for (final PlutoRow filterRow in manager.filterRows) {
      final PlutoCell? columnFieldCell =
          filterRow.cells[FilterHelper.filterFieldColumn];
      final PlutoCell? valueCell =
          filterRow.cells[FilterHelper.filterFieldValue];

      if (columnFieldCell == null || valueCell == null) continue;

      final String field = columnFieldCell.value.toString();
      final String value = valueCell.value.toString().trim();
      if (value.isEmpty) continue;

      newFilterColumn = field;
      newFilterValue = value;
      break;
    }

    _controller.applyActiveFilter(newFilterColumn, newFilterValue);
  }

  Map<String, dynamic>? _resolvePageRowFromGridEvent(
      PlutoGridOnRowDoubleTapEvent event) {
    final int historyIdFromGrid =
        _controller.parseIntValue(event.row.cells['history_id']?.value);
    if (historyIdFromGrid > 0) {
      for (final Map<String, dynamic> row in _controller.pageRows) {
        if (_controller.parseIntValue(row['history_id']) == historyIdFromGrid) {
          return row;
        }
      }
    }

    final int fallbackIndex = event.rowIdx;
    if (fallbackIndex >= 0 && fallbackIndex < _controller.pageRows.length) {
      return _controller.pageRows[fallbackIndex];
    }
    return null;
  }

  Future<void> _openRowDetails(Map<String, dynamic> row) async {
    final bool isInfraEntity =
        _controller.currentEntityType == FmsEntityType.infra;
    final String titleText = isInfraEntity ? '인프라 이력' : '차량 이력';

    final int expectedCountFromRow =
        _controller.parseIntValue(row['number_of_objects']);
    final bool forceZeroDetectedObjects = expectedCountFromRow <= 0;

    setState(() => _isDialogOpen = true);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;
        bool started = false;

        // 현재 표시 중인 행 데이터 (실시간 모드에서 갱신됨)
        Map<String, dynamic> currentRow = Map<String, dynamic>.from(row);

        final List<DetectedObject> fallbackObjectItems =
            _controller.normalizeObjectsForRow(
          _controller.parseDetectedObjectsFromRaw(row['objects'] ??
              row['detected_objects'] ??
              row['detectedObjects']),
          row,
          strictRowMatch: true,
        );
        List<DetectedObject> objectItems = forceZeroDetectedObjects
            ? <DetectedObject>[]
            : List<DetectedObject>.from(fallbackObjectItems);
        bool objectsLoading = !forceZeroDetectedObjects;

        // 실시간 모드 상태
        bool liveMode = false;
        Timer? liveTimer;
        bool liveUpdating = false;

        void cancelLive() {
          liveTimer?.cancel();
          liveTimer = null;
          liveMode = false;
          liveUpdating = false;
        }

        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
            // 초기 객체 로드 (최초 1회)
            Future<void> startLoadIfNeeded() async {
              if (started) return;
              started = true;
              if (forceZeroDetectedObjects) return;

              final List<DetectedObject> loadedObjectItems =
                  await _controller.loadObjectsForRowWithFallback(
                row: currentRow,
                fallbackObjectItems: fallbackObjectItems,
              );

              if (!context.mounted) return;

              setDialogState(() {
                objectItems = loadedObjectItems;
                objectsLoading = false;
              });
            }

            // 실시간 최신 데이터 가져오기
            Future<void> fetchLiveUpdate() async {
              if (liveUpdating || !context.mounted) return;
              liveUpdating = true;

              try {
                Map<String, dynamic>? freshRow;

                if (isInfraEntity) {
                  final int infraId =
                      _controller.parseIntValue(currentRow['infra_id']);
                  if (infraId > 0) {
                    final InfraInfoHistoryResult? result = await _controller
                        .infraCtrl.repository
                        .requestInfraHistory(
                      infraId: infraId,
                      limit: 1,
                      offset: 0,
                    );
                    if (result != null && result.items.isNotEmpty) {
                      freshRow = _controller
                          .enrichRowDateTimeFields(result.items.first.toJson());
                    }
                  }
                } else {
                  final int vehicleId =
                      _controller.parseIntValue(currentRow['vehicle_id']);
                  if (vehicleId > 0) {
                    final VehicleInfoHistoryResult? result = await _controller
                        .vehicleCtrl.repository
                        .requestVehicleHistory(
                      vehicleId: vehicleId,
                      limit: 1,
                      offset: 0,
                    );
                    if (result != null && result.items.isNotEmpty) {
                      freshRow = _controller
                          .enrichRowDateTimeFields(result.items.first.toJson());
                    }
                  }
                }

                if (!context.mounted || freshRow == null) return;

                // 새 행의 객체 목록 가져오기
                final int newObjectCount =
                    _controller.parseIntValue(freshRow['number_of_objects']);
                List<DetectedObject> newObjects = <DetectedObject>[];
                if (newObjectCount > 0) {
                  final List<DetectedObject> freshFallbackObjectItems =
                      _controller.normalizeObjectsForRow(
                    _controller.parseDetectedObjectsFromRaw(
                      freshRow['objects'] ??
                          freshRow['detected_objects'] ??
                          freshRow['detectedObjects'],
                    ),
                    freshRow,
                    strictRowMatch: true,
                  );
                  newObjects = await _controller.loadObjectsForRowWithFallback(
                    row: freshRow,
                    fallbackObjectItems: freshFallbackObjectItems,
                  );
                }

                if (!context.mounted) return;

                setDialogState(() {
                  currentRow = freshRow!;
                  objectItems = newObjects;
                  objectsLoading = false;
                });
              } finally {
                liveUpdating = false;
              }
            }

            startLoadIfNeeded();

            final int loadedCount = objectItems.length;
            final int totalObjects = forceZeroDetectedObjects
                ? 0
                : (objectsLoading
                    ? (expectedCountFromRow < 0 ? 0 : expectedCountFromRow)
                    : loadedCount);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Row(
                children: <Widget>[
                  SvgPicture.asset('assets/images/ivis.svg', height: 28),
                  const SizedBox(width: 12),
                  Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const Spacer(),
                  // 실시간 갱신 토글 버튼
                  Tooltip(
                    message: liveMode ? '실시간 갱신 중지' : '실시간 갱신 시작',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: liveMode
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            if (liveMode) {
                              cancelLive();
                            } else {
                              liveMode = true;
                              fetchLiveUpdate();
                              liveTimer = Timer.periodic(
                                  const Duration(seconds: 2), (_) {
                                fetchLiveUpdate();
                              });
                            }
                          });
                        },
                        icon: Icon(
                          liveMode
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: liveMode
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF9E9E9E),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      cancelLive();
                      Navigator.of(dialogContext).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: size.width * 0.70,
                height: size.height * 0.70,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: <Widget>[
                          _buildRowSummaryCard(currentRow),
                          const SizedBox(height: 16),
                          Expanded(child: _buildRowDetailTable(currentRow)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: _buildObjectsPanel(
                        objectItems: objectItems,
                        totalCount: totalObjects,
                        isLoading: objectsLoading,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() => _isDialogOpen = false);
  }

  // 차량 프리셋 정의
  static const Map<String, List<String>> _vehiclePresets =
      <String, List<String>>{
    '기본': <String>[
      'history_id',
      'vehicle_info_id',
      'vehicle_id',
      'changed_at_date',
      'changed_at_time',
      'kph',
      'mps',
      'number_of_objects'
    ],
    '내비게이션': <String>[
      'history_id',
      'vehicle_info_id',
      'vehicle_id',
      'changed_at_date',
      'changed_at_time',
      'pos_x_m',
      'pos_y_m',
      'pos_z_m',
      'heading_deg',
      'kph',
      'mps',
      'navsat'
    ],
    'IMU': <String>[
      'history_id',
      'vehicle_info_id',
      'vehicle_id',
      'changed_at_date',
      'changed_at_time',
      'accel_x_mps2',
      'accel_y_mps2',
      'accel_z_mps2',
      'gyro_x_dps',
      'gyro_y_dps',
      'gyro_z_dps',
      'heading_deg'
    ],
    '제어': <String>[
      'history_id',
      'vehicle_info_id',
      'vehicle_id',
      'changed_at_date',
      'changed_at_time',
      'transmission_gear',
      'signal_light',
      'angle_deg',
      'torque_nm',
      'accel_pct',
      'brake_pct'
    ],
  };

  // 인프라 프리셋 정의
  static const Map<String, List<String>> _infraPresets = <String, List<String>>{
    '기본': <String>[
      'history_id',
      'infra_info_id',
      'infra_id',
      'changed_at_date',
      'changed_at_time',
      'number_of_objects'
    ],
  };

  void _openColumnFilterDialog() {
    final List<String> allFields =
        List<String>.from(_controller.currentAllFields);
    Set<String> tempVisibleFields =
        Set<String>.from(_controller.currentVisibleFields);
    final Map<String, List<String>> presets =
        _controller.currentEntityType == FmsEntityType.vehicle
            ? _vehiclePresets
            : _infraPresets;

    // 컬럼 카테고리 정의 (아이콘 + 색상)
    final TextEditingController searchCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
            final int visibleCount = tempVisibleFields.length;
            final int totalCount = allFields.length;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: EdgeInsets.zero,
              contentPadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.view_column_rounded,
                        size: 24, color: Color(0xFF1976D2)),
                    const SizedBox(width: 12),
                    const Text('컬럼 선택',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$visibleCount / $totalCount',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1976D2))),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close,
                          size: 22, color: Color(0xFF757575)),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 420,
                height: 480,
                child: Column(
                  children: <Widget>[
                    // 전체/최소 버튼
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                          color: Color(0xFFFAFAFA),
                          border: Border(
                              bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                      child: Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() {
                              if (tempVisibleFields.length ==
                                  allFields.length) {
                                tempVisibleFields = <String>{allFields.first};
                              } else {
                                tempVisibleFields = Set<String>.from(allFields);
                              }
                            }),
                            icon: Icon(
                              tempVisibleFields.length == allFields.length
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 18,
                              color: const Color(0xFF1976D2),
                            ),
                            label: Text(
                                tempVisibleFields.length == allFields.length
                                    ? '전체 해제'
                                    : '전체 선택'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(color: Color(0xFF1976D2)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() =>
                                tempVisibleFields = <String>{allFields.first}),
                            icon: const Icon(Icons.clear_all,
                                size: 18, color: Color(0xFF757575)),
                            label: const Text('최소 선택'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF757575),
                              side: const BorderSide(color: Color(0xFFBDBDBD)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 프리셋
                    if (presets.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: const BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            const Text('프리셋:',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF757575))),
                            ...presets.entries
                                .map((MapEntry<String, List<String>> entry) {
                              final bool isActive = tempVisibleFields.length ==
                                      entry.value.length &&
                                  tempVisibleFields.containsAll(entry.value);
                              return InkWell(
                                onTap: () => setDialogState(() =>
                                    tempVisibleFields =
                                        Set<String>.from(entry.value)),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF1976D2)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: isActive
                                            ? const Color(0xFF1976D2)
                                            : const Color(0xFFBDBDBD)),
                                  ),
                                  child: Text(entry.key,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isActive
                                              ? Colors.white
                                              : const Color(0xFF424242))),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    // 컬럼 목록
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: allFields.length,
                        itemBuilder: (BuildContext ctx, int index) {
                          final String field = allFields[index];
                          final bool isVisible =
                              tempVisibleFields.contains(field);
                          final bool isOnlyOne =
                              isVisible && tempVisibleFields.length == 1;
                          return InkWell(
                            onTap: () {
                              if (isOnlyOne) return;
                              setDialogState(() {
                                if (isVisible)
                                  tempVisibleFields.remove(field);
                                else
                                  tempVisibleFields.add(field);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isVisible
                                          ? const Color(0xFF1976D2)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: isVisible
                                              ? const Color(0xFF1976D2)
                                              : const Color(0xFFBDBDBD),
                                          width: 2),
                                    ),
                                    child: isVisible
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(field,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isVisible
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isVisible
                                                ? const Color(0xFF212121)
                                                : const Color(0xFF757575))),
                                  ),
                                  if (isOnlyOne)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: const Text('Min',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFE65100))),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 푸터
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              top: BorderSide(color: Color(0xFFE0E0E0)))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF757575),
                              side: const BorderSide(color: Color(0xFFBDBDBD)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('취소',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              _controller.applyColumnFilter(tempVisibleFields);
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('적용',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => searchCtrl.dispose());
  }

  // ----------------------------------------------------------------------------
  // Export helpers
  // ----------------------------------------------------------------------------

  List<String> _resolveExportColumns() {
    const List<String> mandatoryExportFields = <String>[
      'payload_crc_ok',
      'payload_bytes_hex',
    ];

    final List<String> ordered = _controller.currentAllFields
        .where(
            (String field) => _controller.currentVisibleFields.contains(field))
        .toList(growable: true);

    for (final String required in mandatoryExportFields) {
      if (!ordered.contains(required)) {
        ordered.add(required);
      }
    }

    return ordered;
  }

  _ExportSortSpec? _resolveCurrentSortSpec() {
    final PlutoGridStateManager? manager = _gridStateManager;
    if (manager == null) return null;

    for (final PlutoColumn column in manager.columns) {
      if (column.sort == PlutoColumnSort.ascending ||
          column.sort == PlutoColumnSort.descending) {
        return _ExportSortSpec(field: column.field, direction: column.sort);
      }
    }
    return null;
  }

  String? _resolveSortDirectionForExport(_ExportSortSpec? sortSpec) {
    if (sortSpec == null) return null;
    return sortSpec.direction == PlutoColumnSort.ascending ? 'asc' : 'desc';
  }

  Future<void> _downloadFilteredTableData() async {
    if (_controller.isExporting) return;
    if (!mounted) return;

    _controller.setExporting(true);

    try {
      final Map<String, String?> searchParams =
          _buildServerSearchParamsFromFilters();
      final _ExportSortSpec? currentSortSpec = _resolveCurrentSortSpec();

      final String entityTypeText =
          _controller.currentEntityType == FmsEntityType.vehicle
              ? 'vehicle'
              : 'infra';

      final int? fromEpochMs =
          _controller.currentEntityType == FmsEntityType.vehicle
              ? _controller.vehicleCtrl.fromEpochMs
              : _controller.infraCtrl.fromEpochMs;
      final int? toEpochMs =
          _controller.currentEntityType == FmsEntityType.vehicle
              ? _controller.vehicleCtrl.toEpochMs
              : _controller.infraCtrl.toEpochMs;

      final HistoryExportResult exportResult =
          await _logRepository.exportHistoryFile(
        entityType: entityTypeText,
        visibleColumns: _resolveExportColumns(),
        searchText: searchParams['text'],
        searchColumnName: searchParams['column'],
        vehicleId: _controller.selectedVehicleIdForExport,
        infraId: _controller.selectedInfraIdForExport,
        fromEpochMs: fromEpochMs,
        toEpochMs: toEpochMs,
        sortColumn: currentSortSpec?.field,
        sortDirection: _resolveSortDirectionForExport(currentSortSpec),
      );

      await _logRepository.downloadLogFile(exportResult.fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export ready: ${exportResult.rowCount} rows, ${exportResult.columnCount} columns.',
            ),
          ),
        );
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('_downloadFilteredTableData error: $exception');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      _controller.setExporting(false);
    }
  }

  TextStyle _cellTextStyle(String field, String value) {
    if (value.isEmpty) {
      return const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E));
    }
    switch (field) {
      case 'number_of_objects':
        final int numericValue = int.tryParse(value) ?? 0;
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: numericValue >= 20
              ? const Color(0xFFD32F2F)
              : numericValue >= 10
                  ? const Color(0xFFF9A825)
                  : const Color(0xFF2E7D32),
        );
      case 'msg_id':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1565C0));
      case 'msg_length':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6A1B9A));
      case 'msg_seq':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1565C0));
      case 'vehicle_id':
      case 'infra_id':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32));
      case 'time_stamp_ms':
      case 'time_stamp':
      case 'updated_ts':
      case 'created_ts':
      case 'changed_at':
      case 'changed_at_date':
      case 'changed_at_time':
      case 'created_ts_date':
      case 'created_ts_time':
      case 'updated_ts_date':
      case 'updated_ts_time':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF455A64));
      case 'pos_x_m':
      case 'pos_y_m':
      case 'pos_z_m':
      case 'position_x':
      case 'position_y':
      case 'position_z':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFEF6C00));
      default:
        return const TextStyle(fontSize: 12, color: Color(0xFF212121));
    }
  }

  TextStyle _objectFieldTextStyle(String field, String value) {
    switch (field) {
      case 'source_kind':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32));
      case 'msg_id':
      case 'msg_seq':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1565C0));
      case 'score':
        final double numericValue = double.tryParse(value) ?? 0;
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: numericValue >= 0.8
              ? const Color(0xFF2E7D32)
              : numericValue >= 0.5
                  ? const Color(0xFFF9A825)
                  : const Color(0xFFC62828),
        );
      case 'width':
      case 'height':
      case 'depth':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1565C0));
      case 'age':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6A1B9A));
      case 'linear_velocity_x':
      case 'linear_velocity_y':
      case 'linear_velocity_z':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF19721));
      case 'object_type':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6A1B9A));
      case 'object_id':
      case 'detected_object_id':
        return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF37474F));
      default:
        return const TextStyle(fontSize: 12, color: Color(0xFF212121));
    }
  }

  // 컬럼별 기본 너비 (픽셀)
  static const Map<String, double> _columnWidths = <String, double>{
    // ID / 시퀀스
    'history_id': 90,
    'vehicle_info_id': 110,
    'infra_info_id': 110,
    'vehicle_id': 90,
    'infra_id': 90,
    'msg_id': 90,
    'msg_seq': 90,
    'msg_length': 90,
    // 날짜/시간 — 데이터값 + 필터 범위 텍스트 여유 확보
    'changed_at_date': 230,
    'changed_at_time': 175,
    'created_ts_date': 230,
    'created_ts_time': 175,
    'updated_ts_date': 230,
    'updated_ts_time': 175,
    // 타임스탬프
    'time_stamp_ms': 130,
    // 속도
    'kph': 90,
    'mps': 90,
    // 좌표
    'pos_x_m': 110,
    'pos_y_m': 110,
    'pos_z_m': 110,
    // IMU
    'heading_deg': 100,
    'accel_x_mps2': 110,
    'accel_y_mps2': 110,
    'accel_z_mps2': 110,
    'gyro_x_dps': 100,
    'gyro_y_dps': 100,
    'gyro_z_dps': 100,
    // 제어
    'transmission_gear': 110,
    'signal_light': 100,
    'angle_deg': 100,
    'torque_nm': 100,
    'accel_pct': 90,
    'brake_pct': 90,
    'number_of_objects': 110,
    'navsat': 90,
  };

  // 날짜 컬럼 목록 (헤더 달력 버튼 + YYYY-MM-DD ~ YYYY-MM-DD 힌트)
  static const Set<String> _dateColumns = <String>{
    'changed_at_date',
    'created_ts_date',
    'updated_ts_date',
  };

  // 컬럼별 필터 힌트 텍스트 맵
  static const Map<String, String> _filterHints = <String, String>{
    // ID 컬럼: 정확한 값 검색
    'history_id': '# 검색',
    'vehicle_info_id': '차량 정보 ID',
    'infra_info_id': '인프라 정보 ID',
    'vehicle_id': '차량 ID',
    'infra_id': '인프라 ID',
    'msg_id': 'MSG ID',
    // 날짜·시간 컬럼: 범위 형식
    'changed_at_date': 'YYYY-MM-DD ~ YYYY-MM-DD',
    'changed_at_time': 'HH:MM:SS ~ HH:MM:SS',
    'created_ts_date': 'YYYY-MM-DD ~ YYYY-MM-DD',
    'created_ts_time': 'HH:MM:SS ~ HH:MM:SS',
    'updated_ts_date': 'YYYY-MM-DD ~ YYYY-MM-DD',
    'updated_ts_time': 'HH:MM:SS ~ HH:MM:SS',
    // 숫자 컬럼: 단일 값 또는 min~max 범위
    'msg_seq': '예) 1~100',
    'msg_length': '예) 100~500',
    'time_stamp_ms': '예) 1700000000~1800000000',
    'navsat': '예) 0~5',
    'kph': '예) 30~80',
    'mps': '예) 8~20',
    'pos_x_m': '예) 350000~360000',
    'pos_y_m': '예) 4100000~4200000',
    'pos_z_m': '예) 0~100',
    'heading_deg': '예) 0~180',
    'accel_x_mps2': '예) -5~5',
    'accel_y_mps2': '예) -5~5',
    'accel_z_mps2': '예) -5~5',
    'gyro_x_dps': '예) -10~10',
    'gyro_y_dps': '예) -10~10',
    'gyro_z_dps': '예) -10~10',
    'transmission_gear': '예) 1~6',
    'signal_light': '예) 0~3',
    'angle_deg': '예) -30~30',
    'torque_nm': '예) 0~100',
    'accel_pct': '예) 0~100',
    'brake_pct': '예) 0~100',
    'number_of_objects': '예) 0~10',
  };

  List<PlutoColumn> _buildPlutoColumns(List<String> fields) {
    return fields.map((String field) {
      final bool isDate = _dateColumns.contains(field);

      // 날짜 컬럼 헤더: 필드명 + 파란 달력 아이콘 버튼
      final InlineSpan? titleSpan = isDate
          ? TextSpan(
              children: <InlineSpan>[
                TextSpan(text: field),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openColumnDateRangePicker(field),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null;

      return PlutoColumn(
        title: field,
        field: field,
        type: PlutoColumnType.text(),
        titleSpan: titleSpan,
        enableSorting: true,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableFilterMenuItem: true,
        enableDropToResize: false,
        width: _columnWidths[field] ?? 120,
        minWidth: _columnWidths[field] ?? 120,
        titleTextAlign: PlutoColumnTextAlign.center,
        textAlign: PlutoColumnTextAlign.center,
        filterHintText: _filterHints[field],
        renderer: (PlutoColumnRendererContext context) {
          final String value = context.cell.value?.toString() ?? '';
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cellTextStyle(context.column.field, value),
            ),
          );
        },
      );
    }).toList();
  }

  List<PlutoRow> _buildPlutoRows(
      List<Map<String, dynamic>> data, List<String> fields) {
    return data.map((Map<String, dynamic> row) {
      final Map<String, PlutoCell> cells = <String, PlutoCell>{};
      for (final String field in fields) {
        cells[field] =
            PlutoCell(value: _controller.formatCellValue(row[field]));
      }
      return PlutoRow(cells: cells);
    }).toList();
  }

  Widget _buildPlutoGrid(double availableHeight) {
    const double columnHeight = 44;
    const double columnFilterHeight = 46;
    const double scrollbarThickness = 12;
    const double verticalBorders = 2;
    final double bodyHeight = availableHeight -
        columnHeight -
        columnFilterHeight -
        scrollbarThickness -
        verticalBorders;
    final double rowHeight =
        (bodyHeight / _controller.rowsPerPage).floorToDouble().clamp(22, 60);

    final String gridKey =
        'dashboard_grid_${_controller.currentEntityType.name}_${_controller.cachedFields.join(",")}';

    return SizedBox(
      height: availableHeight,
      child: PlutoGrid(
        key: ValueKey<String>(gridKey),
        columns: List<PlutoColumn>.from(_cachedColumns, growable: true),
        rows: <PlutoRow>[],
        onLoaded: (PlutoGridOnLoadedEvent event) {
          _gridStateManager = event.stateManager;
          _gridReady = true;
          final PlutoGridStateManager manager = event.stateManager;
          try {
            manager.setSelectingMode(PlutoGridSelectingMode.row);
            manager.setShowLoading(
                _controller.isLoading && !_controller.firstDataArrived);
            manager.setShowColumnFilter(true);
            manager.setFilterOnlyEvent(true);
            _gridEventSubscription?.cancel();
            _gridEventSubscription =
                manager.eventManager?.listener((PlutoGridEvent gridEvent) {
              if (gridEvent is PlutoGridSetColumnFilterEvent) {
                _onColumnFilterChanged();
              }
            });
          } catch (_) {}
          if (mounted) setState(() {});
          _updateGrid();
        },
        onSelected: (PlutoGridOnSelectedEvent event) {
          // 차량 모드에서 행 단일 클릭 → 지도 라이브 추적 패널 표시
          if (_controller.currentEntityType != FmsEntityType.infra &&
              event.row != null) {
            final int vehicleId = _controller.parseIntValue(
              event.row!.cells['vehicle_id']?.value,
            );
            if (vehicleId > 0) {
              _mapPanelKey.currentState?.selectVehicle(vehicleId);
            }
          }
        },
        onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) async {
          final Map<String, dynamic>? selectedRow =
              _resolvePageRowFromGridEvent(event);
          if (selectedRow == null) return;
          await _openRowDetails(selectedRow);
        },
        configuration: PlutoGridConfiguration(
          columnSize: const PlutoGridColumnSizeConfig(
            autoSizeMode: PlutoAutoSizeMode.scale,
          ),
          localeText: const PlutoGridLocaleText(
            filterContains: '검색',
            filterEquals: '일치',
            filterStartsWith: '시작',
            filterEndsWith: '끝',
          ),
          columnFilter: const PlutoGridColumnFilterConfig(
            filters: FilterHelper.defaultFilters,
            debounceMilliseconds: 300,
          ),
          scrollbar: const PlutoGridScrollbarConfig(
            isAlwaysShown: true,
            draggableScrollbar: true,
            scrollbarThickness: 8,
            scrollbarThicknessWhileDragging: 12,
          ),
          style: PlutoGridStyleConfig(
            rowHeight: rowHeight,
            columnHeight: columnHeight,
            columnFilterHeight: columnFilterHeight,
            gridBorderColor: const Color(0xFFE0E0E0),
            borderColor: const Color(0xFFE0E0E0),
            oddRowColor: const Color(0xFFFFFFFF),
            evenRowColor: const Color(0xFFF7FFF8),
            activatedBorderColor: const Color(0xFF43A047),
            activatedColor: const Color(0x1A66BB6A),
            // 검색 필터 행: 포커스 전/후 색상
            cellColorInEditState: const Color(0xFFEFF6FF),
            cellColorInReadOnlyState: const Color(0xFFF3F4F6),
            inactivatedBorderColor: const Color(0xFFD1D5DB),
            defaultColumnFilterPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
      ),
    );
  }

  _MapPanelPlacement _effectiveMapPlacement(double availableWidth) {
    final bool shouldForceBottom = availableWidth < 1200 &&
        (_mapPanelPlacement == _MapPanelPlacement.left ||
            _mapPanelPlacement == _MapPanelPlacement.right);
    if (shouldForceBottom) {
      return _MapPanelPlacement.bottom;
    }
    return _mapPanelPlacement;
  }

  double _normalizedTableRatio({
    required double totalExtent,
    required bool verticalSplit,
  }) {
    final double minPaneExtent = verticalSplit ? 220 : 360;
    if (totalExtent <= (minPaneExtent * 2)) {
      return 0.5;
    }

    final double minRatio = minPaneExtent / totalExtent;
    final double maxRatio = 1 - minRatio;
    return _tablePanelRatio.clamp(minRatio, maxRatio);
  }

  void _resizeHorizontalSplit({
    required double totalWidth,
    required bool mapOnLeft,
    required double dragDeltaX,
  }) {
    const double minPaneWidth = 360;
    final double minRatio = minPaneWidth / totalWidth;
    final double maxRatio = 1 - minRatio;
    if (minRatio >= maxRatio) {
      setState(() {
        _tablePanelRatio = 0.5;
      });
      return;
    }

    final double signedDelta = mapOnLeft ? -dragDeltaX : dragDeltaX;
    final double currentTableWidth = _tablePanelRatio * totalWidth;
    final double nextTableWidth = currentTableWidth + signedDelta;
    final double nextRatio = nextTableWidth / totalWidth;

    setState(() {
      _tablePanelRatio = nextRatio.clamp(minRatio, maxRatio);
    });
  }

  void _resizeVerticalSplit({
    required double totalHeight,
    required double dragDeltaY,
  }) {
    const double minPaneHeight = 220;
    final double minRatio = minPaneHeight / totalHeight;
    final double maxRatio = 1 - minRatio;
    if (minRatio >= maxRatio) {
      setState(() {
        _tablePanelRatio = 0.5;
      });
      return;
    }

    final double currentTableHeight = _tablePanelRatio * totalHeight;
    final double nextTableHeight = currentTableHeight + dragDeltaY;
    final double nextRatio = nextTableHeight / totalHeight;

    setState(() {
      _tablePanelRatio = nextRatio.clamp(minRatio, maxRatio);
    });
  }

  Widget _buildVerticalResizeHandle({
    required double totalWidth,
    required bool mapOnLeft,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          _resizeHorizontalSplit(
            totalWidth: totalWidth,
            mapOnLeft: mapOnLeft,
            dragDeltaX: details.delta.dx,
          );
        },
        child: Container(
          width: 8,
          color: const Color(0xFFD0D7E2),
        ),
      ),
    );
  }

  Widget _buildHorizontalResizeHandle({
    required double totalHeight,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (DragUpdateDetails details) {
          _resizeVerticalSplit(
            totalHeight: totalHeight,
            dragDeltaY: details.delta.dy,
          );
        },
        child: Container(
          height: 8,
          color: const Color(0xFFD0D7E2),
        ),
      ),
    );
  }

  Widget _buildMapPanel() {
    // 버튼(팔로우·지도닫기)은 infra_vehicle_map.dart 내부 Stack에서 직접 배치
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: AbsorbPointer(
            absorbing: _isDialogOpen,
            child: InfraVehicleMapPanel(key: _mapPanelKey),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitBody(BoxConstraints constraints) {
    final _MapPanelPlacement placement =
        _effectiveMapPlacement(constraints.maxWidth);
    final bool isBottom = placement == _MapPanelPlacement.bottom;

    if (isBottom) {
      final double ratio = _normalizedTableRatio(
        totalExtent: constraints.maxHeight,
        verticalSplit: true,
      );
      const double paginationH = 64.0;
      final double available = constraints.maxHeight - 8;
      final double tableHeight = available * ratio;
      final double mapHeight = available - tableHeight;

      return Column(
        children: <Widget>[
          // 테이블+페이지네이션을 tableHeight 안에 함께 배치 (지도 영역과 분리)
          SizedBox(
            height: tableHeight,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: tableHeight - paginationH,
                  child: _buildPlutoGrid(tableHeight - paginationH),
                ),
                _buildPaginationBar(),
              ],
            ),
          ),
          _buildHorizontalResizeHandle(totalHeight: constraints.maxHeight),
          SizedBox(
            height: mapHeight,
            child: _buildMapPanel(),
          ),
        ],
      );
    }

    final bool mapOnLeft = placement == _MapPanelPlacement.left;
    final double ratio = _normalizedTableRatio(
      totalExtent: constraints.maxWidth,
      verticalSplit: false,
    );
    final double available = constraints.maxWidth - 8;
    final double tableWidth = available * ratio;
    final double mapWidth = available - tableWidth;

    // 테이블 영역 하단에만 페이지네이션 배치 (지도 영역은 침범하지 않음)
    const double paginationH = 64.0;
    final Widget tablePane = SizedBox(
      width: tableWidth,
      child: Column(
        children: <Widget>[
          Expanded(child: _buildPlutoGrid(constraints.maxHeight - paginationH)),
          _buildPaginationBar(),
        ],
      ),
    );
    final Widget mapPane = SizedBox(
      width: mapWidth,
      child: _buildMapPanel(),
    );

    return Row(
      children: <Widget>[
        if (mapOnLeft) ...<Widget>[
          mapPane,
          _buildVerticalResizeHandle(
            totalWidth: constraints.maxWidth,
            mapOnLeft: true,
          ),
          tablePane,
        ] else ...<Widget>[
          tablePane,
          _buildVerticalResizeHandle(
            totalWidth: constraints.maxWidth,
            mapOnLeft: false,
          ),
          mapPane,
        ],
      ],
    );
  }

  /// 차량/인프라 이동 상태 + 스테이션 위치 표시 바
  Widget _buildEntityStatusBar(Map<String, dynamic> row, bool isInfra) {
    if (isInfra) {
      return Container(
        color: const Color(0xFFF0FAF8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: <Widget>[
          const Icon(Icons.router_rounded, size: 13, color: Color(0xFF00897B)),
          const SizedBox(width: 6),
          const Text('고정 위치',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00897B))),
        ]),
      );
    }

    // UTM 좌표 파싱
    final double posX = double.tryParse(
            _controller.formatCellValue(row['pos_x_m'] ?? row['position_x'])) ??
        0.0;
    final double posY = double.tryParse(
            _controller.formatCellValue(row['pos_y_m'] ?? row['position_y'])) ??
        0.0;
    final double kphVal = double.tryParse(
            _controller.formatCellValue(row['kph'] ?? row['velocity_kph'])) ??
        0.0;
    final double headingVal = double.tryParse(_controller.formatCellValue(
            row['heading_deg'] ?? row['orientation_heading'])) ??
        0.0;

    final bool isMoving = kphVal > 0.5;
    final bool hasPosition = posX > 1000 && posY > 1000;

    String nearestName = '';
    String directionName = '';
    double nearestDistM = 0;

    if (hasPosition) {
      // 스테이션 UTM 좌표 변환
      final List<({String name, double x, double y})> stUtm =
          kiapiRoadWaypoints.map((KiapiWaypointData wp) {
        final Utm52NCoordinate u = convertWgs84ToUtmZone52N(
          latitudeDegrees: wp.lat,
          longitudeDegrees: wp.lon,
        );
        return (name: wp.name, x: u.eastingMeters, y: u.northingMeters);
      }).toList();

      // 가장 가까운 스테이션
      int nearestIdx = 0;
      double nearestDistSq = double.infinity;
      for (int i = 0; i < stUtm.length; i++) {
        final double dx = stUtm[i].x - posX;
        final double dy = stUtm[i].y - posY;
        final double dSq = dx * dx + dy * dy;
        if (dSq < nearestDistSq) {
          nearestDistSq = dSq;
          nearestIdx = i;
          nearestDistM = math.sqrt(dSq);
        }
      }
      nearestName = stUtm[nearestIdx].name;

      // 이동 중이면 헤딩 방향에 가장 가까운 스테이션 찾기
      if (isMoving) {
        double minDiff = 361.0;
        for (int i = 0; i < stUtm.length; i++) {
          if (i == nearestIdx) continue;
          final double dx = stUtm[i].x - posX;
          final double dy = stUtm[i].y - posY;
          // UTM에서 bearing: x=East, y=North → atan2(dx, dy) = 북기준 시계방향
          final double bearing =
              (math.atan2(dx, dy) * 180.0 / math.pi + 360.0) % 360.0;
          double diff = (bearing - headingVal).abs();
          if (diff > 180) diff = 360.0 - diff;
          if (diff < minDiff) {
            minDiff = diff;
            directionName = stUtm[i].name;
          }
        }
      }
    }

    final Color movingColor =
        isMoving ? const Color(0xFF2E7D32) : const Color(0xFF616161);
    final Color movingBg =
        isMoving ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5);

    return Container(
      color: const Color(0xFFF8FAFE),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: <Widget>[
          // 이동/정지 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: movingBg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: movingColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isMoving ? '이동 중' : '정지',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: movingColor),
              ),
              if (isMoving) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  '${kphVal.toStringAsFixed(0)} km/h',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: movingColor.withOpacity(0.8)),
                ),
              ],
            ]),
          ),
          if (nearestName.isNotEmpty) ...<Widget>[
            const SizedBox(width: 10),
            Container(width: 1, height: 16, color: const Color(0xFFCFD8DC)),
            const SizedBox(width: 10),
            const Icon(Icons.location_on_rounded,
                size: 13, color: Color(0xFF1565C0)),
            const SizedBox(width: 4),
            Text(
              '${nearestDistM < 300 ? '도착' : '근처'}: $nearestName',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1565C0)),
            ),
          ],
          if (directionName.isNotEmpty) ...<Widget>[
            const SizedBox(width: 10),
            Container(width: 1, height: 16, color: const Color(0xFFCFD8DC)),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded,
                size: 13, color: Color(0xFF6A1B9A)),
            const SizedBox(width: 4),
            Text(
              '$directionName 방향',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6A1B9A)),
            ),
          ],
          if (!hasPosition) ...<Widget>[
            const SizedBox(width: 10),
            const Icon(Icons.gps_off_rounded,
                size: 13, color: Color(0xFF9E9E9E)),
            const SizedBox(width: 4),
            const Text('위치 없음',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildRowSummaryCard(Map<String, dynamic> row) {
    final bool isInfra = _controller.currentEntityType == FmsEntityType.infra;
    final String historyIdText = _controller.formatCellValue(row['history_id']);
    final String statusIdText = isInfra
        ? _controller.formatCellValue(row['infra_info_id'])
        : _controller.formatCellValue(row['vehicle_info_id']);
    final String primaryLabel = isInfra ? '인프라 ID' : '차량 ID';
    final String primaryValue = isInfra
        ? _controller.formatCellValue(row['infra_id'])
        : _controller.formatCellValue(row['vehicle_id']);
    final String msgIdValue = _controller.formatCellValue(row['msg_id']);
    final String dateText =
        _controller.formatCellValue(row['changed_at_date'] ?? '');
    final String timeText =
        _controller.formatCellValue(row['changed_at_time'] ?? '');
    final String rawTs = _controller.formatCellValue(
        row['time_stamp_ms'] ?? row['time_stamp'] ?? row['changed_at']);
    final String tsDisplay = (dateText.isNotEmpty && timeText.isNotEmpty)
        ? '$dateText  $timeText'
        : rawTs;

    Widget _chip(String label, String value, Color textColor, Color bgColor) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: textColor.withOpacity(0.65),
                    letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(value.isEmpty ? '-' : value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x401565C0), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── 파란 헤더 ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF1565C0), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: <Widget>[
                  // History ID — главный идентификатор
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('HISTORY',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.65),
                              letterSpacing: 1.2)),
                      const SizedBox(height: 3),
                      Text('#$historyIdText',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                  Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: 1,
                      height: 40,
                      color: Colors.white24),
                  _chip(
                      'STATUS ID', statusIdText, Colors.white, Colors.white12),
                  const SizedBox(width: 8),
                  _chip(primaryLabel, primaryValue, const Color(0xFFA5D6A7),
                      const Color(0x281B5E20)),
                  const SizedBox(width: 8),
                  _chip('MSG ID', msgIdValue, const Color(0xFF90CAF9),
                      Colors.white12),
                  const Spacer(),
                  if (tsDisplay.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.schedule_rounded,
                            size: 13, color: Colors.white.withOpacity(0.65)),
                        const SizedBox(width: 5),
                        Text(tsDisplay,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.85))),
                      ],
                    ),
                ],
              ),
            ),
            // ── 상태 바 (이동/정지 + 스테이션) ───────────────────
            _buildEntityStatusBar(row, isInfra),
          ],
        ),
      ),
    );
  }

  Widget _buildRowDetailTable(Map<String, dynamic> row) {
    final List<String> columns = _controller.currentAllFields;

    // 필드를 카테고리로 분류
    const List<String> idFields = <String>[
      'history_id',
      'vehicle_info_id',
      'infra_info_id',
      'vehicle_id',
      'infra_id',
      'msg_id',
      'msg_seq',
      'msg_length',
    ];
    const List<String> posFields = <String>[
      'pos_x_m',
      'pos_y_m',
      'pos_z_m',
      'heading_deg',
      'position_x',
      'position_y',
      'position_z',
    ];
    const List<String> velocityFields = <String>[
      'kph',
      'mps',
      'velocity_kph',
      'velocity_mps',
      'accel_x_mps2',
      'accel_y_mps2',
      'accel_z_mps2',
    ];

    String _category(String field) {
      if (idFields.contains(field)) return '식별';
      if (posFields.contains(field)) return '위치';
      if (velocityFields.contains(field)) return '속도';
      return '기타';
    }

    Color _valueColor(String field, String value) {
      if (idFields.contains(field)) return const Color(0xFF1565C0);
      if (posFields.contains(field)) return const Color(0xFF2E7D32);
      if (velocityFields.contains(field)) return const Color(0xFFF57F17);
      if (field == 'navsat') {
        final int v = int.tryParse(value) ?? 0;
        return v >= 4 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
      }
      return const Color(0xFF212121);
    }

    final Map<String, List<String>> grouped = <String, List<String>>{};
    for (final String col in columns) {
      final String cat = _category(col);
      grouped.putIfAbsent(cat, () => <String>[]).add(col);
    }
    // Порядок категорий
    final List<String> catOrder = <String>['식별', '위치', '속도', '기타'];
    final List<String> orderedCols = <String>[];
    for (final String cat in catOrder) {
      if (grouped.containsKey(cat)) orderedCols.addAll(grouped[cat]!);
    }

    const Map<String, IconData> catIcons = <String, IconData>{
      '식별': Icons.fingerprint_rounded,
      '위치': Icons.place_rounded,
      '속도': Icons.speed_rounded,
      '기타': Icons.more_horiz_rounded,
    };
    const Map<String, Color> catColors = <String, Color>{
      '식별': Color(0xFF1565C0),
      '위치': Color(0xFF2E7D32),
      '속도': Color(0xFFF57F17),
      '기타': Color(0xFF757575),
    };

    String? lastCat;
    final List<Widget> items = <Widget>[];
    for (int i = 0; i < orderedCols.length; i++) {
      final String name = orderedCols[i];
      final String rawValue = _controller.formatCellValue(row[name]);
      final String value =
          (name == 'accel_pct' || name == 'brake_pct') && rawValue.isNotEmpty
              ? '$rawValue%'
              : rawValue;
      final String cat = _category(name);

      // 섹션 헤더
      if (cat != lastCat) {
        lastCat = cat;
        if (items.isNotEmpty) items.add(const SizedBox(height: 4));
        items.add(Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: <Widget>[
              Icon(catIcons[cat] ?? Icons.circle,
                  size: 13, color: catColors[cat]),
              const SizedBox(width: 6),
              Text(cat,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: catColors[cat],
                      letterSpacing: 0.8)),
            ],
          ),
        ));
      }

      // 행
      final bool isEven = i % 2 == 0;
      items.add(Container(
        color: isEven ? const Color(0xFFF5F7FA) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 148,
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575))),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _valueColor(name, value),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF0)),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: items,
        ),
      ),
    );
  }

  // 객체 패널: 헤더(타이틀 + 카운트 뱃지) + 카드 목록을 하나의 위젯으로 통합
  Widget _buildObjectsPanel({
    required List<DetectedObject> objectItems,
    required int totalCount,
    required bool isLoading,
  }) {
    final int safeTotal = totalCount < 0 ? 0 : totalCount;
    final List<String> fields = _controller.getObjectFields();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── 헤더 바 ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBDEFB)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.radar_rounded,
                  size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              const Text('감지 객체',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1565C0))),
              const SizedBox(width: 10),
              // 카운트 뱃지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: safeTotal > 0
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$safeTotal',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1565C0)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── 카드 목록 ────────────────────────────────────────────
        Expanded(
          child: isLoading
              ? const Center(
                  child: Text('불러오는 중...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                )
              : objectItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Icon(Icons.search_off_rounded,
                              size: 40, color: Color(0xFFBDBDBD)),
                          SizedBox(height: 8),
                          Text('감지된 객체가 없습니다.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF9E9E9E))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: objectItems.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> obj =
                            objectItems[index].toJson();
                        return _buildObjectCard(
                            index: index, obj: obj, fields: fields);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildObjectCard({
    required int index,
    required Map<String, dynamic> obj,
    required List<String> fields,
  }) {
    final int objectTypeValue =
        _controller.parseIntOrFallback(obj['object_type'], -1);
    final ObjectTypeUi objectTypeUi = _controller.objectTypeUi(objectTypeValue);

    // 타입별 색상 (0=미확인, 1=승용차, 2=트럭, 3=버스, 4=보행자, 5=이륜차)
    const List<Color> typeColors = <Color>[
      Color(0xFF757575), // 미확인
      Color(0xFF1976D2), // 승용차
      Color(0xFFE65100), // 트럭
      Color(0xFF2E7D32), // 버스
      Color(0xFF6A1B9A), // 보행자
      Color(0xFFC62828), // 이륜차
    ];
    final Color typeColor =
        (objectTypeValue >= 0 && objectTypeValue < typeColors.length)
            ? typeColors[objectTypeValue]
            : const Color(0xFF1565C0);
    final Color typeBg = typeColor.withValues(alpha: 0.08);

    // score 파싱 → 프로그레스 바 (0~1 범위만 유효, 101~255/100 초과값은 무효)
    final String scoreRaw = _controller.formatCellValue(obj['score']);
    final double scoreVal = double.tryParse(scoreRaw) ?? -1;
    final bool hasScore = scoreVal >= 0 && scoreVal <= 1.0;
    final Color scoreColor = scoreVal >= 0.8
        ? const Color(0xFF2E7D32)
        : scoreVal >= 0.5
            ? const Color(0xFFF57F17)
            : const Color(0xFFC62828);

    // 핵심 필드 분리 — 상단 요약 행에 표시
    const List<String> topFields = <String>['width', 'height', 'depth', 'age'];
    const List<String> skipInBody = <String>[
      'object_type',
      'score',
      'width',
      'height',
      'depth',
      'age',
      'detected_object_id',
      'object_id',
    ];

    Widget metricBadge(String label, String value, Color color) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9E9E9E))),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '—' : value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── 카드 헤더 ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: typeBg,
                border: Border(left: BorderSide(color: typeColor, width: 4)),
              ),
              child: Row(
                children: <Widget>[
                  // 번호
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  // 객체 타입 뱃지
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(objectTypeUi.iconData,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(objectTypeUi.label,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Score 프로그레스 바
                  if (hasScore) ...<Widget>[
                    Text('score',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E9E9E))),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 60,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: scoreVal.clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${(scoreVal * 100).round()}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scoreColor)),
                  ],
                ],
              ),
            ),
            // ── 핵심 지표 (width/height/depth/age) ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: topFields.map((String f) {
                  final String v = _controller.formatCellValue(obj[f]);
                  final bool isSizeMm =
                      f == 'width' || f == 'height' || f == 'depth';
                  final String display =
                      (v.isNotEmpty && isSizeMm) ? '$v mm' : v;
                  return Expanded(
                    child: metricBadge(
                      f,
                      display,
                      f == 'age'
                          ? const Color(0xFF6A1B9A)
                          : const Color(0xFF1565C0),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(
                height: 14,
                indent: 14,
                endIndent: 14,
                color: Color(0xFFEEEEEE)),
            // ── 나머지 필드 2열 그리드 ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: fields
                    .where((String f) => !skipInBody.contains(f))
                    .map((String field) {
                  final String value = _controller.formatCellValue(obj[field]);
                  return SizedBox(
                    width: 160,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(field,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9E9E9E))),
                        ),
                        const SizedBox(width: 4),
                        Text(value.isEmpty ? '—' : value,
                            style: _objectFieldTextStyle(field, value)
                                .copyWith(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------------
  // UI utilities - page buttons / widget builders

  Widget _buildPageButton({
    required Widget child,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected ? const Color(0xFF2F80ED) : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF2E2E2E),
          disabledForegroundColor: const Color(0xFFBDBDBD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color:
                  selected ? const Color(0xFF2F80ED) : const Color(0xFFE0E0E0),
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildPaginationBar() {
    final int currentPageSafe =
        _controller.currentPage < 1 ? 1 : _controller.currentPage;
    final List<int> visiblePages = _controller.buildVisiblePages();

    final bool canGoPrev =
        !(_controller.isLoading || _controller.initialLoading) &&
            currentPageSafe > 1;
    final bool canGoNext =
        !(_controller.isLoading || _controller.initialLoading) &&
            currentPageSafe < _controller.totalPages;

    final List<Widget> pager = <Widget>[
      _buildPageButton(
        child: const Icon(Icons.chevron_left, size: 22),
        onPressed: canGoPrev
            ? () => _controller.changePage(currentPageSafe - 1)
            : null,
      ),
      const SizedBox(width: 10),
    ];

    for (int i = 0; i < visiblePages.length; i++) {
      final int pageNumber = visiblePages[i];

      if (i > 0) {
        final int previous = visiblePages[i - 1];
        if (pageNumber - previous > 1) {
          pager.add(_buildPageButton(
            child: const Text('...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            onPressed: null,
          ));
          pager.add(const SizedBox(width: 10));
        }
      }

      final bool selected = pageNumber == currentPageSafe;
      pager.add(
        _buildPageButton(
          selected: selected,
          child: Text(
            pageNumber.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF2E2E2E),
            ),
          ),
          onPressed: (!(_controller.isLoading || _controller.initialLoading) &&
                  !selected)
              ? () => _controller.changePage(pageNumber)
              : null,
        ),
      );
      pager.add(const SizedBox(width: 10));
    }

    pager.add(
      _buildPageButton(
        child: const Icon(Icons.chevron_right, size: 22),
        onPressed: canGoNext
            ? () => _controller.changePage(currentPageSafe + 1)
            : null,
      ),
    );

    final bool canJump = !(_controller.isLoading || _controller.initialLoading);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFF5F5F5),
      child: Row(
        children: <Widget>[
          const Spacer(),
          Row(children: pager),
          const Spacer(),
          // Jump-to-page 입력
          SizedBox(
            width: 44,
            height: 32,
            child: TextField(
              controller: _jumpPageController,
              focusNode: _jumpPageFocusNode,
              enabled: canJump,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '$currentPageSafe',
                hintStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: Color(0xFF1976D2), width: 1.5),
                ),
              ),
              onSubmitted: (String value) {
                final int? page = int.tryParse(value.trim());
                if (page != null &&
                    page >= 1 &&
                    page <= _controller.totalPages) {
                  _controller.changePage(page);
                }
                _jumpPageController.clear();
                _jumpPageFocusNode.unfocus();
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '/ ${_controller.totalPages}',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ????????????????????????????????????????????????????????????????????????????????????????????
  // UI ?????- ?????  // ????????????????????????????????????????????????????????????????????????????????????????????

  // 차량/인프라 모드에서 지도 split 패널을 켜고 끄는 버튼 (오른쪽 상단 고정)
  Widget _buildMapToggleButton() {
    final bool mapShown = _controller.isMapView;
    return GestureDetector(
      onTap: () {
        if (mapShown) {
          _controller.disableMapView();
        } else {
          _controller.enableMapView();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: mapShown ? const Color(0xFF005CB2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mapShown ? const Color(0xFF005CB2) : const Color(0xFFD0D7E2),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.map_outlined,
              size: 14,
              color: mapShown ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 5),
            Text(
              mapShown ? '지도 닫기' : '지도 열기',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'pretendard',
                fontWeight: FontWeight.w500,
                color: mapShown ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntitySegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 엔티티 선택
          _buildEntityChip(FmsEntityType.vehicle, '차량',
              icon: Icons.directions_car_rounded),
          const SizedBox(width: 2),
          _buildEntityChip(FmsEntityType.infra, '인프라',
              icon: Icons.cell_tower_rounded),
          // 구분선
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color(0xFFCDD0D5),
          ),
          // 지도 모드 토글
          _buildMapChip(),
          if (_controller.isMapView && !_controller.isFullMapMode) ...<Widget>[
            const SizedBox(width: 2),
            _buildMapPlacementChip(),
          ],
        ],
      ),
    );
  }

  Widget _buildEntityChip(FmsEntityType type, String label, {IconData? icon}) {
    final bool isSelected = _controller.currentEntityType == type;

    return GestureDetector(
      onTap: () async {
        if (_controller.isLoading) return;
        if (!mounted) return;
        // 전체지도 모드일 때는 엔티티만 전환 (지도 유지)
        if (!_controller.isFullMapMode) {
          _controller.disableFullMapMode();
        }
        if (_controller.currentEntityType == type) return;
        _gridStateManager = null;
        await _controller.changeEntityType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005CB2) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF005CB2).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'pretendard',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapChip() {
    final bool isSelected = _controller.isFullMapMode;

    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        if (isSelected) {
          _controller.disableFullMapMode();
        } else {
          _controller.enableFullMapMode();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005CB2) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF005CB2).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.map_outlined,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 5),
            Text(
              '지도',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'pretendard',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카테고리별 컬럼 칩 Wrap (다크 다이얼로그용)
  Widget _buildColumnChipWrap(
    List<String> fields,
    Set<String> visibleFields,
    List<String> allFields,
    Color? accentColor,
    void Function(void Function()) setDialogState,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: fields.map((String field) {
        final bool isVisible = visibleFields.contains(field);
        final bool isOnlyOne = isVisible && visibleFields.length == 1;
        final Color chipColor = accentColor ?? const Color(0xFF3D5AFE);
        return GestureDetector(
          onTap: () {
            if (isOnlyOne) return;
            setDialogState(() {
              if (isVisible) {
                visibleFields.remove(field);
              } else {
                visibleFields.add(field);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isVisible
                  ? chipColor.withValues(alpha: 0.1)
                  : const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isVisible
                    ? chipColor.withValues(alpha: 0.5)
                    : const Color(0xFFDDE1EA),
                width: isVisible ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (isVisible)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child:
                        Icon(Icons.check_rounded, size: 12, color: chipColor),
                  ),
                Text(
                  field,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isVisible ? FontWeight.w600 : FontWeight.w400,
                    color: isVisible ? chipColor : const Color(0xFF78909C),
                  ),
                ),
                if (isOnlyOne) ...<Widget>[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF8F00),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('MIN',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _placementIcon(_MapPanelPlacement placement) {
    switch (placement) {
      case _MapPanelPlacement.left:
        return Icons.align_horizontal_left_outlined;
      case _MapPanelPlacement.right:
        return Icons.align_horizontal_right_outlined;
      case _MapPanelPlacement.bottom:
        return Icons.align_vertical_bottom_outlined;
    }
  }

  String _placementLabel(_MapPanelPlacement placement) {
    switch (placement) {
      case _MapPanelPlacement.left:
        return '왼쪽';
      case _MapPanelPlacement.right:
        return '오른쪽';
      case _MapPanelPlacement.bottom:
        return '아래';
    }
  }

  Widget _buildMapPlacementChip() {
    final ThemeData baseTheme = Theme.of(context);
    final ThemeData whiteMenuTheme = baseTheme.copyWith(
      canvasColor: Colors.white,
      cardColor: Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Colors.white,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
      ),
    );

    return Theme(
      data: whiteMenuTheme,
      child: PopupMenuButton<_MapPanelPlacement>(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 8,
        menuPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        onSelected: (_MapPanelPlacement selected) {
          setState(() {
            _mapPanelPlacement = selected;
          });
        },
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<_MapPanelPlacement>>[
            PopupMenuItem<_MapPanelPlacement>(
              value: _MapPanelPlacement.right,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: const Text('지도 오른쪽'),
              ),
            ),
            PopupMenuItem<_MapPanelPlacement>(
              value: _MapPanelPlacement.bottom,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: const Text('지도 아래'),
              ),
            ),
            PopupMenuItem<_MapPanelPlacement>(
              value: _MapPanelPlacement.left,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: const Text('지도 왼쪽'),
              ),
            ),
          ];
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFDDE8F5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _placementIcon(_mapPanelPlacement),
                size: 15,
                color: const Color(0xFF005CB2),
              ),
              const SizedBox(width: 5),
              Text(
                _placementLabel(_mapPanelPlacement),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'pretendard',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF005CB2),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Color(0xFF005CB2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnFilterButton() {
    final int visibleCount = _controller.currentVisibleFields.length;
    final int totalCount = _controller.currentAllFields.length;

    return InkWell(
      onTap: _openColumnFilterDialog,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.view_column_rounded,
                size: 18, color: Color(0xFF1976D2)),
            const SizedBox(width: 8),
            const Text(
              'Columns',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$visibleCount/$totalCount',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUpdateIntervalLabel(AutoUpdateInterval interval) {
    switch (interval) {
      case AutoUpdateInterval.manual:
        return t('수동');
      case AutoUpdateInterval.oneSecond:
        return l10n('1초 자동', 'Auto 1s');
      case AutoUpdateInterval.threeSeconds:
        return l10n('3초 자동', 'Auto 3s');
      case AutoUpdateInterval.fiveSeconds:
        return l10n('5초 자동', 'Auto 5s');
    }
  }

  Widget _buildManualRefreshButton() {
    return InkWell(
      onTap: (_controller.isLoading || _controller.initialLoading)
          ? null
          : _controller.refreshCurrent,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (_controller.isLoading || _controller.initialLoading)
              ? const Color(0xFFF5F5F5)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (_controller.isLoading || _controller.initialLoading)
                ? const Color(0xFFE0E0E0)
                : const Color(0xFF1976D2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.refresh,
              size: 18,
              color: (_controller.isLoading || _controller.initialLoading)
                  ? const Color(0xFF9E9E9E)
                  : const Color(0xFF1976D2),
            ),
            const SizedBox(width: 8),
            Text(
              t('새로고침'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: (_controller.isLoading || _controller.initialLoading)
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return PopupMenuButton<AutoUpdateInterval>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<AutoUpdateInterval>>[
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.manual,
            child: Row(
              children: <Widget>[
                Icon(
                  _controller.currentUpdateInterval == AutoUpdateInterval.manual
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: _controller.currentUpdateInterval ==
                          AutoUpdateInterval.manual
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                Text(t('수동'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.oneSecond,
            child: Row(
              children: <Widget>[
                Icon(
                  _controller.currentUpdateInterval ==
                          AutoUpdateInterval.oneSecond
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: _controller.currentUpdateInterval ==
                          AutoUpdateInterval.oneSecond
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                Text(l10n('1초 자동', 'Auto 1s'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.threeSeconds,
            child: Row(
              children: <Widget>[
                Icon(
                  _controller.currentUpdateInterval ==
                          AutoUpdateInterval.threeSeconds
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: _controller.currentUpdateInterval ==
                          AutoUpdateInterval.threeSeconds
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                Text(l10n('3초 자동', 'Auto 3s'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.fiveSeconds,
            child: Row(
              children: <Widget>[
                Icon(
                  _controller.currentUpdateInterval ==
                          AutoUpdateInterval.fiveSeconds
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: _controller.currentUpdateInterval ==
                          AutoUpdateInterval.fiveSeconds
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                Text(l10n('5초 자동', 'Auto 5s'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ];
      },
      onSelected: (AutoUpdateInterval interval) {
        _controller.changeUpdateInterval(interval);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _controller.currentUpdateInterval != AutoUpdateInterval.manual
              ? const Color(0xFFE3F2FD)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _controller.currentUpdateInterval != AutoUpdateInterval.manual
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.refresh,
              size: 18,
              color:
                  _controller.currentUpdateInterval != AutoUpdateInterval.manual
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF616161),
            ),
            const SizedBox(width: 8),
            Text(
              _getUpdateIntervalLabel(_controller.currentUpdateInterval),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _controller.currentUpdateInterval !=
                        AutoUpdateInterval.manual
                    ? const Color(0xFF1976D2)
                    : const Color(0xFF424242),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color:
                  _controller.currentUpdateInterval != AutoUpdateInterval.manual
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF616161),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final ThemeData baseTheme = Theme.of(context);
    final ThemeData dropdownTheme = baseTheme.copyWith(
      canvasColor: Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(surface: Colors.white),
    );

    if (_controller.currentEntityType == FmsEntityType.vehicle) {
      final List<String> vehicleIds = _controller.vehicleCtrl.vehicles
          .map((v) => '${v.vehicleId}')
          .toList();
      vehicleIds.sort((String a, String b) =>
          _controller.parseIntValue(a).compareTo(_controller.parseIntValue(b)));

      return Row(
        children: <Widget>[
          Text('${t('차량')} ID:',
              style: const TextStyle(fontSize: 12, color: Color(0xFF616161))),
          const SizedBox(width: 8),
          Theme(
            data: dropdownTheme,
            child: DropdownButton<String>(
              value: _controller.vehicleIdFilter,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF212121),
                  fontWeight: FontWeight.w600),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                    value: 'ALL', child: Text('ALL')),
                ...vehicleIds.map((String id) =>
                    DropdownMenuItem<String>(value: id, child: Text(id))),
              ],
              onChanged: (String? value) async {
                if (value == null) return;
                if (!mounted) return;
                await _controller.setVehicleIdFilter(value);
              },
            ),
          ),
        ],
      );
    }

    if (_controller.currentEntityType == FmsEntityType.infra) {
      final List<String> sortedIds = _controller.infraCtrl.infraIdentifiers
          .map((int v) => v.toString())
          .toSet()
          .toList();
      sortedIds.sort((String a, String b) =>
          _controller.parseIntValue(a).compareTo(_controller.parseIntValue(b)));

      return Row(
        children: <Widget>[
          Text('${t('인프라')} ID:',
              style: const TextStyle(fontSize: 12, color: Color(0xFF616161))),
          const SizedBox(width: 8),
          Theme(
            data: dropdownTheme,
            child: DropdownButton<String>(
              value: _controller.infraIdFilter,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF212121),
                  fontWeight: FontWeight.w600),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                    value: 'ALL', child: Text('ALL')),
                ...sortedIds.map((String id) =>
                    DropdownMenuItem<String>(value: id, child: Text(id))),
              ],
              onChanged: (String? value) async {
                if (value == null) return;
                if (!mounted) return;
                await _controller.setInfraIdFilter(value);
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // 특정 컬럼의 날짜 범위 달력 피커를 열고 PlutoGrid 필터에 적용
  Future<void> _openColumnDateRangePicker(String field) async {
    final List<DateTime?>? results = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.range,
        selectedDayHighlightColor: const Color(0xFF1565C0),
        selectedRangeHighlightColor: const Color(0xFFBBDEFB),
        dayTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF212121)),
        selectedDayTextStyle: const TextStyle(
            fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
        todayTextStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w700),
        weekdayLabelTextStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9E9E9E),
            fontWeight: FontWeight.w500),
        controlsTextStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF212121),
            fontWeight: FontWeight.w600),
        lastMonthIcon: const Icon(Icons.chevron_left, color: Color(0xFF424242)),
        nextMonthIcon:
            const Icon(Icons.chevron_right, color: Color(0xFF424242)),
        okButton: Text(t('적용'),
            style: const TextStyle(
                color: Color(0xFF1565C0), fontWeight: FontWeight.w700)),
        cancelButton:
            Text(t('취소'), style: const TextStyle(color: Color(0xFF757575))),
      ),
      dialogSize: const Size(340, 420),
      value: <DateTime?>[null, null],
      borderRadius: BorderRadius.circular(16),
      dialogBackgroundColor: Colors.white,
    );

    if (results == null || !mounted) return;

    final DateTime? newFrom = results.isNotEmpty ? results[0] : null;
    final DateTime? newTo = results.length > 1 ? results[1] : null;
    if (newFrom == null) return;

    final String fromStr = DateFormat('yyyy-MM-dd').format(newFrom);
    final String toStr = DateFormat('yyyy-MM-dd').format(newTo ?? newFrom);
    final String filterValue = '$fromStr~$toStr';

    // PlutoGrid 필터에 해당 컬럼으로 날짜 범위 텍스트 설정
    if (_gridStateManager != null) {
      _gridStateManager!.setFilterWithFilterRows(<PlutoRow>[
        FilterHelper.createFilterRow(
          columnField: field,
          filterType: const PlutoFilterTypeContains(),
          filterValue: filterValue,
        ),
      ]);
    }
  }

  // 달력 아이콘 버튼 위젯 (날짜 컬럼 필터 행 우측에 삽입)

  Widget _buildDataDownloadButton() {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: _controller.isExporting ? null : _downloadFilteredTableData,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF005CB2),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9BB6D9),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        icon: _controller.isExporting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.download, size: 16, color: Colors.white),
        label: Text(_controller.isExporting ? t('내보내는 중...') : t('데이터 다운로드')),
      ),
    );
  }

  Widget _buildToolbar() {
    final int currentPageSafe =
        _controller.currentPage < 1 ? 1 : _controller.currentPage;
    final int totalPagesSafe =
        _controller.totalPages < 1 ? 1 : _controller.totalPages;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          _buildEntitySegment(),
          if (!_controller.isFullMapMode) ...<Widget>[
            const SizedBox(width: 16),
            _buildFilters(),
            const SizedBox(width: 16),
            _buildColumnFilterButton(),
          ],
          const Spacer(),
          // 전체지도 모드에서는 우측 패널 숨김
          if (!_controller.isFullMapMode) ...<Widget>[
            _buildDataDownloadButton(),
            const SizedBox(width: 8),
            if (!_controller.isMapView) _buildMapToggleButton(),
            if (!_controller.isMapView) const SizedBox(width: 8),
            const SizedBox(width: 4),
            Text(
              l10n('전체 ${_controller.totalCount}',
                  'Total ${_controller.totalCount}'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: (_controller.isLoading || _controller.initialLoading)
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF424242),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$currentPageSafe/$totalPagesSafe',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: (_controller.isLoading || _controller.initialLoading)
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 10),
            _buildManualRefreshButton(),
            const SizedBox(width: 10),
            _buildUpdateButton(),
          ],
        ],
      ),
    );
  }

  // ????????????????????????????????????????????????????????????????????????????????????????????
  // build
  // ????????????????????????????????????????????????????????????????????????????????????????????

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => GetBuilder<DashboardController>(
        builder: (DashboardController controller) {
          final String fieldsKey = controller.cachedFields.join(',');
          if (fieldsKey != _lastCachedFieldsKey) {
            _rebuildCachedColumns();
            _gridReady = false;
            _gridStateManager = null;
          }

          return Container(
            color: const Color(0xFFF0F4F8),
            child: Column(
              children: <Widget>[
                _buildToolbar(),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        if (controller.isFullMapMode) {
                          return _buildMapPanel();
                        }
                        if (!controller.isMapView) {
                          return Column(
                            children: <Widget>[
                              Expanded(
                                  child: _buildPlutoGrid(
                                      constraints.maxHeight - 64)),
                              _buildPaginationBar(),
                            ],
                          );
                        }
                        return _buildSplitBody(constraints);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
