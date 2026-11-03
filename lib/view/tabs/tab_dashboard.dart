// tab_dashboard.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../i18n/app_locale.dart';
import '../../model/object_model.dart';
import '../../view/components/dashboard/objects_status_grid.dart';
import '../../view/components/infra_vehicle_map.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../../viewmodel/controller/helper/dashboard_format_helper.dart';
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
  // _updateGrid 실행 중 탭 이벤트 무시 플래그
  bool _suppressRowTap = false;

  List<PlutoColumn> _cachedColumns = <PlutoColumn>[];

  String _lastCachedFieldsKey = '';

  final LogRepository _logRepository = LogRepository();
  _MapPanelPlacement _mapPanelPlacement = _MapPanelPlacement.right;
  double _tablePanelRatio = 0.33; // 3패널 기본: 테이블 33%
  bool _isDialogOpen = false;

  // 데이터 다운로드 대상 날짜 (하루 단위)
  DateTime? _exportDay;
  final GlobalKey _dayBtnKey = GlobalKey(); // 다운로드 날짜 버튼 위치(달력 앵커)

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

      _suppressRowTap = true;
      try {
        manager.removeAllRows();
        if (rowsToInsert.isNotEmpty) {
          manager.appendRows(rowsToInsert);
        }
        manager.notifyListeners();
      } catch (exception) {
        if (kDebugMode) {
          debugPrint('_updateGrid error: $exception');
        }
      } finally {
        _suppressRowTap = false;
      }
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('_updateGrid outer error: $exception');
      }
    }
  }

  // 셀 탭 → 해당 행 index로 pageRows 조회 후 객체 현황 패널 갱신
  void _onRowTapped(int rowIdx) {
    // _updateGrid 실행 중이거나 로딩 중이면 무시
    if (_suppressRowTap || _controller.isLoading || !_gridReady) return;
    if (rowIdx < 0 || rowIdx >= _controller.pageRows.length) return;
    final Map<String, dynamic> pageRow = _controller.pageRows[rowIdx];
    // 차량 모드: 지도 라이브 추적
    if (_controller.currentEntityType != FmsEntityType.infra) {
      // Vehicle 0 is a real device (spec uint8 0-255)
      final int? vehicleId =
          DashboardFormatHelper.deviceIdOrNull(pageRow['vehicle_id']);
      if (vehicleId != null) {
        _mapPanelKey.currentState?.selectVehicle(vehicleId);
      }
    }
    // 객체 현황 패널 갱신
    _controller.showObjectsStatusFromRow(pageRow);
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


  // ── 더블클릭 다이얼로그 ─────────────────────────────────────────────────────

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
    final bool forceZero = expectedCountFromRow <= 0;

    setState(() => _isDialogOpen = true);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;
        bool started = false;
        Map<String, dynamic> currentRow = Map<String, dynamic>.from(row);
        final List<DetectedObject> fallbackItems =
            _controller.normalizeObjectsForRow(
          _controller.parseDetectedObjectsFromRaw(
              row['objects'] ?? row['detected_objects'] ?? row['detectedObjects']),
          row,
          strictRowMatch: true,
        );
        List<DetectedObject> objectItems =
            forceZero ? <DetectedObject>[] : List<DetectedObject>.from(fallbackItems);
        bool objectsLoading = !forceZero;

        return StatefulBuilder(
          builder: (BuildContext ctx,
              void Function(void Function()) setDialogState) {
            Future<void> startLoad() async {
              if (started) return;
              started = true;
              if (forceZero) return;
              final List<DetectedObject> loaded =
                  await _controller.loadObjectsForRowWithFallback(
                row: currentRow,
                fallbackObjectItems: fallbackItems,
              );
              if (!ctx.mounted) return;
              setDialogState(() {
                objectItems = loaded;
                objectsLoading = false;
              });
            }

            startLoad();
            final int total = forceZero
                ? 0
                : (objectsLoading
                    ? expectedCountFromRow.clamp(0, 99999)
                    : objectItems.length);

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
                  Text(titleText,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121))),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
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
                      child: _buildDialogObjectsPanel(
                        objectItems: objectItems,
                        totalCount: total,
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

  // ── 다이얼로그 전용 헬퍼 위젯들 ──────────────────────────────────────────────

  Widget _buildEntityStatusBar(Map<String, dynamic> row, bool isInfra) {
    if (isInfra) {
      return Container(
        color: const Color(0xFFF0FAF8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: const <Widget>[
          Icon(Icons.router_rounded, size: 13, color: Color(0xFF00897B)),
          SizedBox(width: 6),
          Text('고정 위치',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00897B))),
        ]),
      );
    }
    final double posX = double.tryParse(
            _controller.formatCellValue(row['pos_x_m'] ?? row['position_x'])) ??
        0.0;
    final double posY = double.tryParse(
            _controller.formatCellValue(row['pos_y_m'] ?? row['position_y'])) ??
        0.0;
    // 속도는 mps(초속, m/s)×3.6 으로 계산한다. KIAPI 는 kph 칸을 event_flag 로 쓰므로
    // 실제 속도가 아니다. mps 가 없을 때만 kph 를 쓴다.
    final double? mpsVal = double.tryParse(
        _controller.formatCellValue(row['mps'] ?? row['velocity_mps']));
    final double kphVal = mpsVal != null
        ? mpsVal * 3.6
        : (double.tryParse(_controller
                .formatCellValue(row['kph'] ?? row['velocity_kph'])) ??
            0.0);
    final bool isMoving = kphVal > 0.5;
    final bool hasPosition = posX > 1000 && posY > 1000;
    return Container(
      color: const Color(0xFFF3F7FF),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(children: <Widget>[
        Icon(
          isMoving ? Icons.directions_car_filled : Icons.local_parking_rounded,
          size: 13,
          color: isMoving ? const Color(0xFF1565C0) : const Color(0xFF78909C),
        ),
        const SizedBox(width: 6),
        Text(
          isMoving ? '이동 중 ${kphVal.toStringAsFixed(0)} km/h' : '정지',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMoving
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF78909C)),
        ),
        if (hasPosition) ...<Widget>[
          const SizedBox(width: 10),
          const Icon(Icons.location_on_rounded,
              size: 12, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 3),
          Text(
            'E${posX.toStringAsFixed(0)} N${posY.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          ),
        ],
      ]),
    );
  }

  Widget _buildRowSummaryCard(Map<String, dynamic> row) {
    final bool isInfra = _controller.currentEntityType == FmsEntityType.infra;
    final String historyIdText = _controller.formatCellValue(row['history_id']);
    final String primaryLabel = isInfra ? '인프라 ID' : '차량 ID';
    final String primaryValue = isInfra
        ? _controller.formatCellValue(row['infra_id'])
        : _controller.formatCellValue(row['vehicle_id']);
    final String msgIdValue = _controller.formatCellValue(row['msg_id']);
    final String dateText =
        _controller.formatCellValue(row['changed_at_date'] ?? '');
    final String timeText =
        _controller.formatCellValue(row['changed_at_time'] ?? '');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Text('HISTORY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF90CAF9),
                    letterSpacing: 1.2)),
            const Spacer(),
            if (dateText.isNotEmpty)
              Text('$dateText $timeText',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF90CAF9))),
          ]),
          const SizedBox(height: 4),
          Text('#$historyIdText',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: <Widget>[
            _chip(primaryLabel, primaryValue, const Color(0xFF388E3C)),
            _chip('MSG ID', msgIdValue, const Color(0xFFE65100)),
          ]),
          const SizedBox(height: 10),
          _buildEntityStatusBar(row, isInfra),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFBBDEFB),
                  fontWeight: FontWeight.w600)),
          Text(value.isEmpty ? '—' : value,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildRowDetailTable(Map<String, dynamic> row) {
    final List<String> columns = _controller.currentAllFields;
    const List<String> idFields = <String>[
      'history_id',
      'vehicle_id', 'infra_id', 'msg_id', 'msg_seq', 'msg_length',
    ];
    const List<String> posFields = <String>[
      'pos_x_m', 'pos_y_m', 'pos_z_m', 'heading_deg', 'navsat',
    ];
    const List<String> velFields = <String>[
      'kph', 'mps', 'accel_x_mps2', 'accel_y_mps2', 'accel_z_mps2',
      'gyro_x_dps', 'gyro_y_dps', 'gyro_z_dps',
    ];
    final Map<String, List<String>> grouped = <String, List<String>>{
      '식별': <String>[],
      '위치': <String>[],
      '속도/IMU': <String>[],
      '기타': <String>[],
    };
    for (final String f in columns) {
      if (idFields.contains(f)) {
        grouped['식별']!.add(f);
      } else if (posFields.contains(f)) {
        grouped['위치']!.add(f);
      } else if (velFields.contains(f)) {
        grouped['속도/IMU']!.add(f);
      } else {
        grouped['기타']!.add(f);
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: grouped.entries
            .where((MapEntry<String, List<String>> e) => e.value.isNotEmpty)
            .expand((MapEntry<String, List<String>> e) => <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Text(e.key,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1565C0),
                            letterSpacing: 0.8)),
                  ),
                  ...e.value.asMap().entries.map((MapEntry<int, String> entry) {
                    final String field = entry.value;
                    final String value =
                        _controller.formatCellValue(row[field]);
                    return Container(
                      color: entry.key.isEven
                          ? Colors.white
                          : const Color(0xFFF7F9FF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Row(children: <Widget>[
                        SizedBox(
                          width: 130,
                          child: Text(field,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          child: Text(
                            value.isEmpty ? '—' : value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: value.isEmpty
                                  ? const Color(0xFFBDBDBD)
                                  : const Color(0xFF212121),
                            ),
                          ),
                        ),
                      ]),
                    );
                  }),
                ])
            .toList(),
      ),
    );
  }

  Widget _buildDialogObjectsPanel({
    required List<DetectedObject> objectItems,
    required int totalCount,
    required bool isLoading,
  }) {
    final int safeTotal = totalCount < 0 ? 0 : totalCount;
    final List<String> fields = _controller.getObjectFields();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBDEFB)),
          ),
          child: Row(children: <Widget>[
            const Icon(Icons.radar_rounded, size: 18, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            const Text('감지 객체',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: safeTotal > 0
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFBDBDBD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$safeTotal',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1565C0))),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: isLoading
              ? const Center(
                  child: Text('불러오는 중...',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E))))
              : objectItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
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
                        return _buildDialogObjectCard(
                            index: index, obj: obj, fields: fields);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDialogObjectCard({
    required int index,
    required Map<String, dynamic> obj,
    required List<String> fields,
  }) {
    final int objectTypeValue =
        _controller.parseIntOrFallback(obj['object_type'], -1);
    final ObjectTypeUi typeUi = _controller.objectTypeUi(objectTypeValue);
    const List<Color> typeColors = <Color>[
      Color(0xFF757575), Color(0xFF1565C0), Color(0xFFE65100),
      Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFFC62828),
    ];
    final Color typeColor = objectTypeValue >= 0 &&
            objectTypeValue < typeColors.length
        ? typeColors[objectTypeValue]
        : const Color(0xFF757575);

    const List<String> skipInBody = <String>[
      'detected_object_id', 'object_type', 'source_kind',
      'vehicle_id', 'infra_id',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(
                      color: typeColor.withValues(alpha: 0.2))),
            ),
            child: Row(children: <Widget>[
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(typeUi.iconData, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(typeUi.label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: fields
                  .where((String f) => !skipInBody.contains(f))
                  .map((String field) {
                final String value =
                    _controller.formatCellValue(obj[field]);
                return SizedBox(
                  width: 160,
                  child: Row(children: <Widget>[
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
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 차량 프리셋 정의
  static const Map<String, List<String>> _vehiclePresets =
      <String, List<String>>{
    '기본': <String>[
      'history_id',
      'vehicle_id',
      'changed_at_date',
      'changed_at_time',
      'kph',
      'mps',
      'number_of_objects'
    ],
    '내비게이션': <String>[
      'history_id',
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
    if (_exportDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('먼저 다운로드할 날짜를 선택해 주세요.'))),
      );
      return;
    }

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

      // 2026-08-10: 선택한 기간에 데이터가 없으면 내려받지 않고 안내만 한다.
      //   이전에는 서버가 헤더만 있는 빈 CSV(61바이트)를 만들고 프런트가 그대로
      //   내려받아, 사용자가 "Export ready: 0 rows" 와 함께 빈 파일을 받았다.
      if (exportResult.rowCount == 0 || exportResult.fileName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // 노란색 경고 배경 — 밝은 배경이라 기본 흰색 글자는 읽히지 않으므로
              // 글자색을 어둡게 지정한다.
              content: Text(
                t('선택한 기간에 데이터가 없습니다. 다른 날짜를 선택해 주세요.'),
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: const Color(0xFFFFD400),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      await _logRepository.downloadLogFile(
        exportResult.fileName,
        exp: exportResult.downloadExp,
        sig: exportResult.downloadSig,
      );

      if (mounted) {
        final bool cut = exportResult.truncated;
        final String msg = cut
            ? t('최대 ${exportResult.rowCount}행까지만 내보냈습니다. 기간을 좁히거나 차량을 선택해 주세요.')
            : 'Export ready: ${exportResult.rowCount} rows, ${exportResult.columnCount} columns.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: cut ? const Color(0xFFC8860D) : null,
            duration: Duration(seconds: cut ? 6 : 3),
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

  // 날짜/시간 컬럼 목록 (헤더 파란 달력 버튼 + 날짜 범위 피커)
  static const Set<String> _dateColumns = <String>{
    'changed_at_date',
    'changed_at_time',
    'created_ts_date',
    'created_ts_time',
    'updated_ts_date',
    'updated_ts_time',
  };

  // 컬럼별 필터 힌트 텍스트 맵
  static const Map<String, String> _filterHints = <String, String>{
    // ID 컬럼: 정확한 값 검색
    'history_id': '# 검색',
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
                      onTapDown: (TapDownDetails d) =>
                          _openColumnDateRangePicker(field, d.globalPosition),
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
                return;
              }
              // 셀 탭 이벤트 → 객체 현황 패널에 해당 행의 내장 objects 표시
              // onSelected는 normal 모드에서 발동하지 않으므로 여기서 처리
              if (gridEvent is PlutoGridCellGestureEvent &&
                  gridEvent.gestureType.isOnTapUp) {
                _onRowTapped(gridEvent.rowIdx);
              }
            });
          } catch (_) {}
          if (mounted) setState(() {});
          _updateGrid();
        },
        onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) async {
          final Map<String, dynamic>? selectedRow =
              _resolvePageRowFromGridEvent(event);
          if (selectedRow == null) return;
          await _openRowDetails(selectedRow);
        },
        configuration: PlutoGridConfiguration(
          columnSize: const PlutoGridColumnSizeConfig(
            // 컬럼을 화면폭에 맞춰 줄이지 않고(=scale 제거) 지정 너비 유지 →
            // 전체 컬럼 폭이 화면보다 넓으면 가로 스크롤이 생긴다.
            autoSizeMode: PlutoAutoSizeMode.none,
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
    final bool statusOpen = _controller.isObjectsStatusOpen;

    if (isBottom) {
      final double statusPanelWidth = statusOpen
          ? _statusPanelWidthWithin(constraints.maxWidth - 268.0)
          : 0.0;
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
          // 테이블+페이지네이션 + (객체 현황 패널 오른쪽에 배치)
          SizedBox(
            height: tableHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
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
                if (statusOpen) ...<Widget>[
                  _buildStatusResizeHandle(inverted: true),
                  SizedBox(
                    width: statusPanelWidth,
                    child: _buildObjectsStatusPanel(),
                  ),
                ],
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
    final double statusPanelWidth = statusOpen
        ? _statusPanelWidthWithin(available - tableWidth - 128.0)
        : 0.0;
    // 객체 현황 패널이 열려있을 때 차지하는 가로 공간 (패널 + 간격)
    final double statusPaneTotal = statusPanelWidth + 8.0;
    // 객체 현황 패널이 열려있으면 지도 너비에서 차감
    final double mapWidth =
        (available - tableWidth - (statusOpen ? statusPaneTotal : 0))
            .clamp(120.0, double.infinity);

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
    final Widget? statusPane = statusOpen
        ? SizedBox(
            width: statusPanelWidth,
            child: _buildObjectsStatusPanel(),
          )
        : null;

    return Row(
      children: <Widget>[
        if (mapOnLeft) ...<Widget>[
          mapPane,
          if (statusPane != null) ...<Widget>[
            _buildStatusResizeHandle(inverted: true),
            statusPane,
          ],
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
          if (statusPane != null) ...<Widget>[
            statusPane,
            _buildStatusResizeHandle(),
          ],
          mapPane,
        ],
      ],
    );
  }

  // ── 객체 현황 패널 (3번째 컬럼) ─────────────────────────────────────────────
  double _statusPanelWidth = 0.0; // 0 = 첫 빌드 시 화면 33%로 자동 계산
  static const double _statusPanelMinWidth = 420.0;
  static const double _statusPanelMaxWidth = 1200.0;

  void _resizeStatusPanel(double dragDeltaX) {
    setState(() {
      _statusPanelWidth = (_statusPanelWidth + dragDeltaX)
          .clamp(_statusPanelMinWidth, _statusPanelMaxWidth);
    });
  }

  double _statusPanelWidthWithin(double maxAvailableWidth) {
    final double safeMax = math.max(320.0, maxAvailableWidth);
    final double upper = math.min(_statusPanelMaxWidth, safeMax);
    final double lower = math.min(_statusPanelMinWidth, upper);
    // 0이면 첫 빌드 → 가용 너비의 50% (나머지 절반은 지도)
    if (_statusPanelWidth <= 0.0) {
      _statusPanelWidth = (safeMax * 0.50).clamp(lower, upper);
    }
    return _statusPanelWidth.clamp(lower, upper);
  }

  // 드래그로 크기를 조절하는 handle
  // inverted=true: handle이 패널 왼쪽 (지도가 왼쪽) → 드래그 방향 반전
  Widget _buildStatusResizeHandle({bool inverted = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          _resizeStatusPanel(inverted ? -details.delta.dx : details.delta.dx);
        },
        child: Container(
          width: 8,
          color: const Color(0xFFD0D7E2),
        ),
      ),
    );
  }

  // ObjectsStatusGrid StatefulWidget을 래핑하는 헬퍼
  Widget _buildObjectsStatusPanel() {
    return ObjectsStatusGrid(controller: _controller);
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
    // 키셋 모드: 임의 페이지 번호 클릭 / jump-to-page 는 정확한 동작을
    // 보장할 수 없으므로 비활성화하고 Next/Prev 만 노출한다.
    final bool isKeyset = _controller.useKeysetPagination;

    final bool canGoPrev =
        !(_controller.isLoading || _controller.initialLoading) &&
            (isKeyset ? _controller.hasPrevPage : currentPageSafe > 1);
    final bool canGoNext =
        !(_controller.isLoading || _controller.initialLoading) &&
            (isKeyset
                ? _controller.hasNextPage
                : currentPageSafe < _controller.totalPages);

    final List<Widget> pager = <Widget>[
      _buildPageButton(
        child: const Icon(Icons.chevron_left, size: 22),
        onPressed: canGoPrev
            ? () {
                if (isKeyset) {
                  _controller.loadPrevPage();
                } else {
                  _controller.changePage(currentPageSafe - 1);
                }
              }
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
      // 하이브리드 모드 — 페이지 번호 클릭은 항상 활성화.
      // 키셋 모드여도 changePage 가 내부에서 cursorStack 을 비우고 offset 으로 fallback.
      // (깊은 페이지는 느릴 수 있지만 동작은 보장)
      final bool canTapPageNumber = !(_controller.isLoading ||
              _controller.initialLoading) &&
          !selected;
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
          onPressed: canTapPageNumber
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
            ? () {
                if (isKeyset) {
                  _controller.loadNextPage();
                } else {
                  _controller.changePage(currentPageSafe + 1);
                }
              }
            : null,
      ),
    );

    // 하이브리드 모드 — jump-to-page 항상 활성화
    // (changePage 내부에서 cursorStack 비우고 offset 으로 안전하게 처리)
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
                // 하이브리드 모드 — 항상 현재 페이지 hint 표시
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

  // 클릭 위치(anchor) 근처에 뜨는 달력 팝업 (중앙 모달 아님). 흰색+파랑.
  Future<List<DateTime?>?> _showAnchoredCalendar(
    Offset anchor, {
    required CalendarDatePicker2Type type,
    List<DateTime?> initial = const <DateTime?>[],
  }) {
    const double w = 300;
    const double h = 366;
    final Size scr = MediaQuery.of(context).size;
    double left = anchor.dx - w / 2;
    double top = anchor.dy + 10; // 클릭 아래
    if (left + w > scr.width - 8) left = scr.width - w - 8;
    if (left < 8) left = 8;
    if (top + h > scr.height - 8) top = anchor.dy - h - 10; // 공간 없으면 위로
    if (top < 8) top = 8;

    return showDialog<List<DateTime?>>(
      context: context,
      barrierColor: Colors.transparent, // 어두운 배경 없이 팝업처럼
      builder: (BuildContext ctx) {
        return Stack(
          children: <Widget>[
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 10,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: w,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: type,
                        selectedDayHighlightColor: const Color(0xFF005CB2),
                        selectedRangeHighlightColor: const Color(0xFFBBDEFB),
                        dayTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF212121)),
                        selectedDayTextStyle: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700),
                        todayTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF005CB2), fontWeight: FontWeight.w700),
                        weekdayLabelTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500),
                        controlsTextStyle: const TextStyle(fontSize: 14, color: Color(0xFF212121), fontWeight: FontWeight.w600),
                        lastMonthIcon: const Icon(Icons.chevron_left, color: Color(0xFF424242)),
                        nextMonthIcon: const Icon(Icons.chevron_right, color: Color(0xFF424242)),
                      ),
                      value: List<DateTime?>.from(initial),
                      onValueChanged: (List<DateTime?> dates) {
                        if (type == CalendarDatePicker2Type.single) {
                          if (dates.isNotEmpty && dates[0] != null) {
                            Navigator.of(ctx).pop(dates);
                          }
                        } else {
                          // range: 시작·종료 둘 다 선택되면 닫기
                          if (dates.length >= 2 && dates[0] != null && dates[1] != null) {
                            Navigator.of(ctx).pop(dates);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 특정 컬럼의 날짜 범위 달력 피커를 열고 PlutoGrid 필터에 적용
  Future<void> _openColumnDateRangePicker(String field, Offset anchor) async {
    final List<DateTime?>? results = await _showAnchoredCalendar(
      anchor,
      type: CalendarDatePicker2Type.range,
      initial: <DateTime?>[null, null],
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

  // 데이터 다운로드 기간 선택 버튼 (다운로드 버튼 좌측)
  Widget _buildPeriodButton() {
    final String label = _exportDay != null
        ? DateFormat('yyyy-MM-dd').format(_exportDay!)
        : t('날짜 선택');
    return SizedBox(
      key: _dayBtnKey,
      height: 32,
      child: OutlinedButton.icon(
        onPressed: _controller.isExporting ? null : _pickExportDay,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF005CB2),
          side: const BorderSide(color: Color(0xFF005CB2), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        icon: const Icon(Icons.calendar_today, size: 15, color: Color(0xFF005CB2)),
        label: Text(label),
      ),
    );
  }

  // 하루 선택 → 그 날짜(00:00 ~ 23:59:59.999)만 export 대상으로 설정
  Future<void> _pickExportDay() async {
    // 다운로드 날짜 버튼 위치 기준으로 달력 팝업을 띄움 (중앙 모달 아님)
    Offset anchor = const Offset(120, 120);
    final RenderObject? ro = _dayBtnKey.currentContext?.findRenderObject();
    if (ro is RenderBox) {
      final Offset p = ro.localToGlobal(Offset.zero);
      anchor = Offset(p.dx + ro.size.width / 2, p.dy + ro.size.height);
    }
    final List<DateTime?>? r = await _showAnchoredCalendar(
      anchor,
      type: CalendarDatePicker2Type.single,
      initial: <DateTime?>[_exportDay],
    );
    if (r == null || r.isEmpty || r[0] == null) return;
    final DateTime picked = r[0]!;

    // 선택한 하루만 export 대상 (하루 = 제한된 양 → 시스템 부담 최소)
    final DateTime from = DateTime(picked.year, picked.month, picked.day);
    final DateTime to =
        DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    final int fromMs = from.millisecondsSinceEpoch;
    final int toMs = to.millisecondsSinceEpoch;

    _controller.vehicleCtrl.setDateRange(fromMs, toMs);
    _controller.infraCtrl.setDateRange(fromMs, toMs);

    if (mounted) {
      setState(() {
        _exportDay = picked;
      });
    }
  }

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
            _buildPeriodButton(),
            const SizedBox(width: 8),
            _buildDataDownloadButton(),
            const SizedBox(width: 8),
            // 객체 현황 패널 토글
            Tooltip(
              message:
                  _controller.isObjectsStatusOpen ? '객체 현황 닫기' : '객체 현황 표시',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _controller.isObjectsStatusOpen
                      ? const Color(0xFFE3F2FD)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.radar_rounded,
                    color: _controller.isObjectsStatusOpen
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF9E9E9E),
                    size: 22,
                  ),
                  onPressed: () => _controller.toggleObjectsStatus(),
                ),
              ),
            ),
            const SizedBox(width: 4),
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
                          // 지도 없는 모드: 객체 현황 패널이 열리면 우측에 병렬 배치
                          if (controller.isObjectsStatusOpen) {
                            final double statusPanelWidth =
                                _statusPanelWidthWithin(
                                    constraints.maxWidth - 288.0);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    children: <Widget>[
                                      Expanded(
                                          child: _buildPlutoGrid(
                                              constraints.maxHeight - 64)),
                                      _buildPaginationBar(),
                                    ],
                                  ),
                                ),
                                _buildStatusResizeHandle(inverted: true),
                                SizedBox(
                                  width: statusPanelWidth,
                                  child: _buildObjectsStatusPanel(),
                                ),
                              ],
                            );
                          }
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

