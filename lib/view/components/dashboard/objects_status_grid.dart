// objects_status_grid.dart
// ── 객체 현황 PlutoGrid 패널 ─────────────────────────────────────────────────
// DashboardController.objectsStatusItems 를 직접 PlutoGrid 테이블로 표시한다.
// object_type 컬럼은 아이콘 renderer로 표시.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../model/object_model.dart';
import '../../../viewmodel/controller/dashboard_controller.dart';

class ObjectsStatusGrid extends StatefulWidget {
  final DashboardController controller;

  const ObjectsStatusGrid({super.key, required this.controller});

  @override
  State<ObjectsStatusGrid> createState() => _ObjectsStatusGridState();
}

class _ObjectsStatusGridState extends State<ObjectsStatusGrid> {
  PlutoGridStateManager? _stateManager;
  List<DetectedObject> _syncedItems = <DetectedObject>[];

  // ── 타입별 표시 정보 ────────────────────────────────────────────────────────
  static const List<String> _typeLabels = <String>[
    '미확인',
    '승용차',
    '트럭',
    '버스',
    '보행자',
    '이륜차',
  ];
  static const List<IconData> _typeIcons = <IconData>[
    Icons.help_outline,
    Icons.directions_car,
    Icons.local_shipping,
    Icons.directions_bus,
    Icons.directions_walk,
    Icons.two_wheeler,
  ];
  static const List<Color> _typeColors = <Color>[
    Color(0xFF757575),
    Color(0xFF1976D2),
    Color(0xFFE65100),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
  ];

  Color _sourceKindColor(String label) {
    if (label == '차량') return const Color(0xFF1565C0);
    if (label == '인프라') return const Color(0xFF2E7D32);
    return const Color(0xFF757575);
  }

  Widget _plainCell(
    PlutoColumnRendererContext ctx, {
    FontWeight fontWeight = FontWeight.w600,
    Color color = const Color(0xFF424242),
    TextAlign textAlign = TextAlign.center,
  }) {
    final String value = ctx.cell.value?.toString() ?? '';
    final String display = value.isEmpty ? '—' : value;
    return Tooltip(
      message: display,
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: textAlign == TextAlign.right
              ? Alignment.centerRight
              : textAlign == TextAlign.left
                  ? Alignment.centerLeft
                  : Alignment.center,
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 11,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // ── PlutoGrid 컬럼 정의 ─────────────────────────────────────────────────────
  List<PlutoColumn> _buildColumns() {
    PlutoColumn col({
      required String title,
      required String field,
      double width = 70,
      double minWidth = 56,
      PlutoColumnTextAlign align = PlutoColumnTextAlign.center,
      PlutoColumnRenderer? renderer,
    }) {
      return PlutoColumn(
        title: title,
        field: field,
        type: PlutoColumnType.text(),
        width: width,
        minWidth: minWidth,
        titleTextAlign: PlutoColumnTextAlign.center,
        textAlign: align,
        enableSorting: true,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableFilterMenuItem: false,
        enableDropToResize: true,
        renderer: renderer,
      );
    }

    return <PlutoColumn>[
      col(
        title: '타입',
        field: 'object_type',
        width: 56,
        minWidth: 52,
        renderer: (PlutoColumnRendererContext ctx) {
          final int typeVal =
              int.tryParse(ctx.cell.value?.toString() ?? '') ?? -1;
          final bool valid = typeVal >= 0 && typeVal < _typeIcons.length;
          return Center(
            child: Tooltip(
              message: valid ? _typeLabels[typeVal] : '미확인',
              child: Icon(
                valid ? _typeIcons[typeVal] : Icons.help_outline,
                size: 18,
                color: valid ? _typeColors[typeVal] : const Color(0xFF9E9E9E),
              ),
            ),
          );
        },
      ),
      col(
        title: '분류',
        field: 'type_label',
        width: 76,
        align: PlutoColumnTextAlign.left,
        renderer: (PlutoColumnRendererContext ctx) {
          final String label = ctx.cell.value?.toString() ?? '—';
          final int typeVal = _typeLabels.indexOf(label);
          final Color color = (typeVal >= 0 && typeVal < _typeColors.length)
              ? _typeColors[typeVal]
              : const Color(0xFF757575);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      col(
        title: '객체 ID',
        field: 'object_id',
        width: 78,
        renderer: (PlutoColumnRendererContext ctx) => _plainCell(ctx),
      ),
      col(
        title: '소스',
        field: 'source_kind',
        width: 70,
        renderer: (PlutoColumnRendererContext ctx) {
          final String label = ctx.cell.value?.toString() ?? '미확인';
          final Color color = _sourceKindColor(label);
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          );
        },
      ),
      col(
        title: '소유 장치',
        field: 'source_entity',
        width: 112,
        align: PlutoColumnTextAlign.left,
        renderer: (PlutoColumnRendererContext ctx) {
          final String value = ctx.cell.value?.toString() ?? '';
          final Color color = value.startsWith('인프라')
              ? const Color(0xFF2E7D32)
              : value.startsWith('차량')
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF757575);
          return _plainCell(
            ctx,
            fontWeight: FontWeight.w800,
            color: color,
            textAlign: TextAlign.left,
          );
        },
      ),
      col(
        title: 'Info ID',
        field: 'source_info_id',
        width: 86,
        renderer: (PlutoColumnRendererContext ctx) => _plainCell(ctx),
      ),
      col(
        title: '신뢰도',
        field: 'score',
        width: 76,
        renderer: (PlutoColumnRendererContext ctx) {
          final double? val = double.tryParse(ctx.cell.value?.toString() ?? '');
          final bool valid = val != null && val >= 0 && val <= 1.0;
          final Color color = !valid
              ? const Color(0xFF9E9E9E)
              : val >= 0.8
                  ? const Color(0xFF2E7D32)
                  : val >= 0.5
                      ? const Color(0xFFF57F17)
                      : const Color(0xFFC62828);
          return Center(
            child: Text(
              valid ? val.toStringAsFixed(2) : '—',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          );
        },
      ),
      col(
        title: 'X (m)',
        field: 'pos_x',
        width: 92,
        align: PlutoColumnTextAlign.right,
        renderer: (PlutoColumnRendererContext ctx) =>
            _plainCell(ctx, textAlign: TextAlign.right),
      ),
      col(
        title: 'Y (m)',
        field: 'pos_y',
        width: 92,
        align: PlutoColumnTextAlign.right,
        renderer: (PlutoColumnRendererContext ctx) =>
            _plainCell(ctx, textAlign: TextAlign.right),
      ),
      col(
        title: '폭(mm)',
        field: 'width',
        width: 86,
        align: PlutoColumnTextAlign.right,
        renderer: (PlutoColumnRendererContext ctx) =>
            _plainCell(ctx, textAlign: TextAlign.right),
      ),
      col(
        title: '높이(mm)',
        field: 'height',
        width: 86,
        align: PlutoColumnTextAlign.right,
        renderer: (PlutoColumnRendererContext ctx) =>
            _plainCell(ctx, textAlign: TextAlign.right),
      ),
      col(
        title: '깊이(mm)',
        field: 'depth',
        width: 86,
        align: PlutoColumnTextAlign.right,
        renderer: (PlutoColumnRendererContext ctx) =>
            _plainCell(ctx, textAlign: TextAlign.right),
      ),
    ];
  }

  // ── PlutoGrid 행 빌드 ────────────────────────────────────────────────────────
  List<PlutoRow> _buildRows(List<DetectedObject> items) {
    String fmt(double? v) => v != null ? v.toStringAsFixed(2) : '';

    return items.map((DetectedObject obj) {
      final int typeVal = obj.objectType ?? -1;
      final bool valid = typeVal >= 0 && typeVal < _typeLabels.length;
      final String normalizedSourceKind =
          (obj.sourceKind ?? '').trim().toLowerCase();
      final bool isVehicleSource = normalizedSourceKind == 'vehicle' ||
          (normalizedSourceKind.isEmpty &&
              obj.vehicleInfoId != null &&
              obj.vehicleInfoId! > 0);
      final bool isInfraSource = normalizedSourceKind == 'infra' ||
          (normalizedSourceKind.isEmpty &&
              obj.infraInfoId != null &&
              obj.infraInfoId! > 0);
      final String sourceKindLabel = isVehicleSource
          ? '차량'
          : isInfraSource
              ? '인프라'
              : '미확인';
      final int? sourceEntityId = isVehicleSource
          ? obj.vehicleId
          : (isInfraSource ? obj.infraId : null);
      final String sourceEntityLabel =
          sourceEntityId != null && sourceEntityId > 0
              ? '$sourceKindLabel $sourceEntityId'
              : '';
      final int sourceInfoId = isVehicleSource
          ? (obj.vehicleInfoId ?? 0)
          : isInfraSource
              ? (obj.infraInfoId ?? 0)
              : 0;
      return PlutoRow(cells: <String, PlutoCell>{
        'object_type': PlutoCell(value: typeVal.toString()),
        'type_label': PlutoCell(value: valid ? _typeLabels[typeVal] : '미확인'),
        'object_id': PlutoCell(
            value: obj.objectId != null && obj.objectId! > 0
                ? obj.objectId.toString()
                : ''),
        'source_kind': PlutoCell(value: sourceKindLabel),
        'source_entity': PlutoCell(value: sourceEntityLabel),
        'source_info_id':
            PlutoCell(value: sourceInfoId > 0 ? sourceInfoId.toString() : ''),
        'score': PlutoCell(
            value: (obj.score != null && obj.score! >= 0 && obj.score! <= 1.0)
                ? obj.score!.toStringAsFixed(3)
                : ''),
        'pos_x': PlutoCell(value: fmt(obj.positionX)),
        'pos_y': PlutoCell(value: fmt(obj.positionY)),
        'width': PlutoCell(value: fmt(obj.width)),
        'height': PlutoCell(value: fmt(obj.height)),
        'depth': PlutoCell(value: fmt(obj.depth)),
      });
    }).toList();
  }

  // ── PlutoGrid 데이터 동기화 ─────────────────────────────────────────────────
  void _syncGrid(List<DetectedObject> items) {
    if (_stateManager == null) return;
    if (identical(_syncedItems, items)) return;
    _syncedItems = items;
    final List<PlutoRow> rows = _buildRows(items);
    _stateManager!.removeAllRows();
    if (rows.isNotEmpty) {
      _stateManager!.appendRows(rows);
    }
    _stateManager!.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: <Widget>[
            GetBuilder<DashboardController>(
              builder: (DashboardController ctrl) {
                final List<DetectedObject> items = ctrl.objectsStatusItems;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _syncGrid(items);
                });
                return _buildHeader(ctrl, items);
              },
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  PlutoGrid(
                    columns: _buildColumns(),
                    rows: _buildRows(widget.controller.objectsStatusItems),
                    onLoaded: (PlutoGridOnLoadedEvent event) {
                      _stateManager = event.stateManager;
                      _syncedItems = widget.controller.objectsStatusItems;
                    },
                    configuration: PlutoGridConfiguration(
                      columnSize: const PlutoGridColumnSizeConfig(
                        autoSizeMode: PlutoAutoSizeMode.none,
                      ),
                      scrollbar: const PlutoGridScrollbarConfig(
                        isAlwaysShown: false,
                        draggableScrollbar: true,
                        scrollbarThickness: 6,
                        scrollbarThicknessWhileDragging: 8,
                      ),
                      style: PlutoGridStyleConfig(
                        rowHeight: 36,
                        columnHeight: 38,
                        gridBorderColor: const Color(0xFFE0E0E0),
                        borderColor: const Color(0xFFEEEEEE),
                        oddRowColor: Colors.white,
                        evenRowColor: const Color(0xFFF7FFF8),
                        activatedBorderColor: const Color(0xFF43A047),
                        activatedColor: const Color(0x1A66BB6A),
                        columnTextStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF616161)),
                        cellTextStyle: const TextStyle(
                            fontSize: 11, color: Color(0xFF424242)),
                      ),
                    ),
                  ),
                  GetBuilder<DashboardController>(
                    builder: (DashboardController ctrl) {
                      if (ctrl.objectsStatusLoading ||
                          ctrl.objectsStatusItems.isNotEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Positioned.fill(
                        child: Container(
                          color: Colors.white,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.touch_app_rounded,
                                    size: 36, color: Color(0xFFBDBDBD)),
                                SizedBox(height: 10),
                                Text(
                                  '행을 클릭하면 해당 패킷의\n감지 객체가 표시됩니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9E9E9E)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DashboardController ctrl, List<DetectedObject> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        border: const Border(bottom: BorderSide(color: Color(0xFFBBDEFB))),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.radar_rounded, size: 16, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          const Text(
            '객체 현황',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1565C0)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: items.isNotEmpty
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFBDBDBD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${ctrl.objectsStatusTotalCount}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
          ),
          if (ctrl.objectsStatusLoading) ...<Widget>[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1565C0)),
            ),
          ],
          const Spacer(),
          // LIVE 스위치 — 타이머와 연동해 DB에서 실시간 최신 객체 표시
          GestureDetector(
            onTap: ctrl.toggleObjectsLiveMode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ctrl.isObjectsLiveMode
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (ctrl.isObjectsLiveMode)
                    const SizedBox(
                      width: 7,
                      height: 7,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white),
                    )
                  else
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBDBDBD),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ctrl.isObjectsLiveMode
                          ? Colors.white
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                ctrl.objectsStatusLoading ? null : ctrl.refreshObjectsStatus,
            icon: const Icon(Icons.refresh, size: 16),
            color: const Color(0xFF1565C0),
            disabledColor: const Color(0xFFBDBDBD),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => ctrl.toggleObjectsStatus(),
            child: const Icon(Icons.close, size: 16, color: Color(0xFF757575)),
          ),
        ],
      ),
    );
  }
}
