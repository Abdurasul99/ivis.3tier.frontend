import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../model/object_model.dart';
import '../../model/infra_model.dart';
import '../../model/vehicle_model.dart';
import '../../view/components/infra_vehicle_map.dart';
import '../../viewmodel/controller/infra_controller.dart';
import '../../viewmodel/controller/object_controller.dart';
import '../../viewmodel/controller/vehicle_controller.dart';

enum FmsEntityType { vehicle, infra }

enum AutoUpdateInterval {
  manual,
  oneSecond,
  threeSeconds,
  fiveSeconds,
}

class TabDashboard extends StatefulWidget {
  const TabDashboard({super.key});

  @override
  State<TabDashboard> createState() {
    return _TabDashboardState();
  }
}

class ObjectTypeUi {
  final String label;
  final IconData iconData;
  const ObjectTypeUi({required this.label, required this.iconData});
}

class _TabDashboardState extends State<TabDashboard> with AutomaticKeepAliveClientMixin<TabDashboard> {
  static FmsEntityType _lastEntityType = FmsEntityType.vehicle;
  static Set<String> _lastVisibleVehicleFields = <String>{};
  static Set<String> _lastVisibleInfraFields = <String>{};

  late final VehicleController _vehicleController;
  late final InfraController _infraController;
  late final ObjectController _objectController;

  FmsEntityType _currentEntityType = FmsEntityType.vehicle;
  bool _isMapView = false;

  bool _initialLoading = true;
  bool _isLoading = false;

  int _currentPage = 1;
  int _totalCount = 0;
  int _rowsPerPage = 18;

  String _vehicleIdFilter = 'ALL';
  String _infraIdFilter = 'ALL';

  List<Map<String, dynamic>> _pageRows = <Map<String, dynamic>>[];

  PlutoGridStateManager? _gridStateManager;
  bool _gridReady = false;

  List<String> _allVehicleFields = <String>[];
  List<String> _allInfraFields = <String>[];

  Set<String> _visibleVehicleFields = <String>{};
  Set<String> _visibleInfraFields = <String>{};

  List<String> _cachedFields = <String>[];
  List<PlutoColumn> _cachedColumns = <PlutoColumn>[];

  int _loadRequestId = 0;
  bool _firstDataArrived = false;

  StreamSubscription<PlutoGridEvent>? _gridEventSubscription;

  AutoUpdateInterval _currentUpdateInterval = AutoUpdateInterval.manual;
  Timer? _autoUpdateTimer;

  String? _activeFilterColumn;
  String? _activeFilterValue;

  @override
  bool get wantKeepAlive => true;

  int get _totalPages {
    final int safeTotal = _totalCount < 0 ? 0 : _totalCount;
    final int pages = (safeTotal + _rowsPerPage - 1) ~/ _rowsPerPage;
    if (pages < 1) {
      return 1;
    }
    return pages;
  }

  Set<String> get _currentVisibleFields {
    if (_currentEntityType == FmsEntityType.vehicle) {
      return _visibleVehicleFields;
    }
    return _visibleInfraFields;
  }

  List<String> get _currentAllFields {
    if (_currentEntityType == FmsEntityType.vehicle) {
      return _allVehicleFields;
    }
    return _allInfraFields;
  }

  int _parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  int _parseIntOrFallback(dynamic value, int fallbackValue) {
    if (value == null) {
      return fallbackValue;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallbackValue;
    }
    return int.tryParse(value.toString()) ?? fallbackValue;
  }

  String _formatCellValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      return value.toString();
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  ObjectTypeUi _objectTypeUi(int? objectType) {
    final int value = objectType ?? -1;
    if (value == 0) {
      return const ObjectTypeUi(label: '미확인', iconData: Icons.help_outline);
    }
    if (value == 1) {
      return const ObjectTypeUi(label: '승용차', iconData: Icons.directions_car_filled);
    }
    if (value == 2) {
      return const ObjectTypeUi(label: '트럭', iconData: Icons.local_shipping);
    }
    if (value == 3) {
      return const ObjectTypeUi(label: '버스', iconData: Icons.directions_bus_filled);
    }
    if (value == 4) {
      return const ObjectTypeUi(label: '보행자', iconData: Icons.directions_walk);
    }
    if (value == 5) {
      return const ObjectTypeUi(label: '이륜차', iconData: Icons.two_wheeler);
    }
    return const ObjectTypeUi(label: '정의되지 않음', iconData: Icons.question_mark);
  }

  String _getObjectTypeNameKorean(int? type) {
    switch (type) {
      case 0:
        return '미확인';
      case 1:
        return '승용차';
      case 2:
        return '트럭';
      case 3:
        return '버스';
      case 4:
        return '보행자';
      case 5:
        return '이륜차';
      default:
        return '미확인';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentEntityType = _lastEntityType;

    _vehicleController =
        Get.isRegistered<VehicleController>() ? Get.find<VehicleController>() : Get.put(VehicleController());
    _infraController = Get.isRegistered<InfraController>() ? Get.find<InfraController>() : Get.put(InfraController());
    _objectController =
        Get.isRegistered<ObjectController>() ? Get.find<ObjectController>() : Get.put(ObjectController());

    _allVehicleFields = _getFieldsForEntity(FmsEntityType.vehicle);
    _allInfraFields = _getFieldsForEntity(FmsEntityType.infra);

    if (_lastVisibleVehicleFields.isEmpty) {
      _visibleVehicleFields = Set<String>.from(_allVehicleFields);
    } else {
      _visibleVehicleFields = Set<String>.from(_lastVisibleVehicleFields);
    }

    if (_lastVisibleInfraFields.isEmpty) {
      _visibleInfraFields = Set<String>.from(_allInfraFields);
    } else {
      _visibleInfraFields = Set<String>.from(_lastVisibleInfraFields);
    }

    _rebuildCachedColumns();

    Future<void>.microtask(() async {
      try {
        await _waitForTokenReady();
        await _vehicleController.reqLoadVehicles();
        if (_currentEntityType == FmsEntityType.infra) {
          await _infraController.reqLoadInfraIdentifiers();
        }
        await _loadPage(1, resetFilters: true, force: true);
      } finally {
        if (!mounted) {
          return;
        }
        setState(() {
          _initialLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    _gridEventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _waitForTokenReady() async {
    if (_vehicleController.hasToken) {
      return;
    }
    for (int index = 0; index < 300; index++) {
      if (_vehicleController.hasToken) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _startAutoUpdate(AutoUpdateInterval interval) {
    _autoUpdateTimer?.cancel();

    if (interval == AutoUpdateInterval.manual) {
      return;
    }

    Duration duration;
    switch (interval) {
      case AutoUpdateInterval.oneSecond:
        duration = const Duration(seconds: 1);
        break;
      case AutoUpdateInterval.threeSeconds:
        duration = const Duration(seconds: 3);
        break;
      case AutoUpdateInterval.fiveSeconds:
        duration = const Duration(seconds: 5);
        break;
      case AutoUpdateInterval.manual:
        return;
    }

    _autoUpdateTimer = Timer.periodic(duration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isMapView) {
        return;
      }
      _refreshCurrent();
    });
  }

  void _changeUpdateInterval(AutoUpdateInterval newInterval) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUpdateInterval = newInterval;
    });
    _startAutoUpdate(newInterval);
  }

  List<String> _getFieldsForEntity(FmsEntityType type) {
    if (type == FmsEntityType.vehicle) {
      return <String>[
        'history_id',
        'vehicle_info_id',
        'vehicle_id',
        'msg_id',
        'msg_seq',
        'msg_length',
        'changed_at',
        'time_stamp_ms',
        'navsat',
        'kph',
        'mps',
        'pos_x_m',
        'pos_y_m',
        'pos_z_m',
        'heading_deg',
        'accel_x_mps2',
        'accel_y_mps2',
        'accel_z_mps2',
        'gyro_x_dps',
        'gyro_y_dps',
        'gyro_z_dps',
        'transmission_gear',
        'signal_light',
        'angle_deg',
        'torque_nm',
        'accel_pct',
        'brake_pct',
        'number_of_objects',
        'created_ts',
        'updated_ts',
      ];
    }
    return <String>[
      'history_id',
      'infra_info_id',
      'infra_id',
      'msg_id',
      'msg_seq',
      'msg_length',
      'changed_at',
      'time_stamp_ms',
      'number_of_objects',
      'created_ts',
      'updated_ts',
    ];
  }

  List<String> _getObjectFields() {
    return <String>[
      'detected_object_id',
      'source_kind',
      'vehicle_info_id',
      'infra_info_id',
      'object_id',
      'object_type',
      'msg_id',
      'msg_seq',
      'age',
      'score',
      'width',
      'depth',
      'height',
      'position_x',
      'position_y',
      'position_z',
      'orientation_heading',
      'linear_velocity_x',
      'linear_velocity_y',
      'linear_velocity_z',
      'rotation_rate_x',
      'rotation_rate_y',
      'rotation_rate_z',
      'created_ts',
      'updated_ts',
    ];
  }

  void _rebuildCachedColumns() {
    final List<String> allFields = _currentAllFields;
    final Set<String> visibleFields = _currentVisibleFields;
    _cachedFields = allFields.where((String field) => visibleFields.contains(field)).toList();
    _cachedColumns = _buildPlutoColumns(_cachedFields);
  }

  void _applyColumnFilter(Set<String> newVisibleFields) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_currentEntityType == FmsEntityType.vehicle) {
        _visibleVehicleFields = Set<String>.from(newVisibleFields);
        _lastVisibleVehicleFields = Set<String>.from(_visibleVehicleFields);
      } else {
        _visibleInfraFields = Set<String>.from(newVisibleFields);
        _lastVisibleInfraFields = Set<String>.from(_visibleInfraFields);
      }

      _rebuildCachedColumns();
      _gridReady = false;
      _gridStateManager = null;
    });
  }

  Map<String, String?> _buildServerSearchParamsFromFilters() {
    if (_activeFilterColumn != null && _activeFilterValue != null && _activeFilterValue!.trim().isNotEmpty) {
      return <String, String?>{
        'text': _activeFilterValue!.trim(),
        'column': _activeFilterColumn,
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
      final PlutoCell? columnFieldCell = filterRow.cells[FilterHelper.filterFieldColumn];
      final PlutoCell? valueCell = filterRow.cells[FilterHelper.filterFieldValue];

      if (columnFieldCell == null || valueCell == null) {
        continue;
      }

      final String field = columnFieldCell.value.toString();
      final String value = valueCell.value.toString().trim();

      if (value.isEmpty) {
        continue;
      }

      return <String, String?>{
        'text': value,
        'column': field,
      };
    }

    return <String, String?>{'text': null, 'column': null};
  }

  void _handleColumnFilterChange() {
    if (_gridStateManager == null) {
      return;
    }

    final PlutoGridStateManager manager = _gridStateManager!;

    if (manager.filterRows.isEmpty) {
      if (_activeFilterColumn != null || _activeFilterValue != null) {
        _activeFilterColumn = null;
        _activeFilterValue = null;
        _currentPage = 1;
        _loadPage(1, force: true);
      }
      return;
    }

    String? newFilterColumn;
    String? newFilterValue;

    for (final PlutoRow filterRow in manager.filterRows) {
      final PlutoCell? columnFieldCell = filterRow.cells[FilterHelper.filterFieldColumn];
      final PlutoCell? valueCell = filterRow.cells[FilterHelper.filterFieldValue];

      if (columnFieldCell == null || valueCell == null) {
        continue;
      }

      final String field = columnFieldCell.value.toString();
      final String value = valueCell.value.toString().trim();

      if (value.isEmpty) {
        continue;
      }

      newFilterColumn = field;
      newFilterValue = value;
      break;
    }

    if (newFilterColumn != _activeFilterColumn || newFilterValue != _activeFilterValue) {
      _activeFilterColumn = newFilterColumn;
      _activeFilterValue = newFilterValue;
      _currentPage = 1;
      _loadPage(1, force: true);
    }
  }

  Future<void> _loadPage(int page, {bool resetFilters = false, bool force = false}) async {
    if (_isLoading) {
      return;
    }

    if (!_vehicleController.hasToken) {
      await _waitForTokenReady();
      if (!_vehicleController.hasToken) {
        return;
      }
    }

    if (resetFilters) {
      _vehicleIdFilter = 'ALL';
      _infraIdFilter = 'ALL';
      _currentPage = 1;
      _activeFilterColumn = null;
      _activeFilterValue = null;
    }

    final int safeTotalPages = _totalPages < 1 ? 1 : _totalPages;
    final int targetPage = force ? page : page.clamp(1, safeTotalPages);
    if (!force && targetPage == _currentPage) {
      return;
    }

    final int requestId = ++_loadRequestId;

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    _updateGrid();

    try {
      final int offset = (targetPage - 1) * _rowsPerPage;
      final int limit = _rowsPerPage;

      List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      int resolvedTotalCount = 0;

      final Map<String, String?> searchParams =
          resetFilters ? <String, String?>{'text': null, 'column': null} : _buildServerSearchParamsFromFilters();
      final String? searchTextForRequest = searchParams['text'];
      final String? searchColumnNameForRequest = searchParams['column'];

      if (_currentEntityType == FmsEntityType.vehicle) {
        int? vehicleId;
        if (_vehicleIdFilter != 'ALL') {
          vehicleId = int.tryParse(_vehicleIdFilter);
        }

        await _vehicleController.reqLoadHistory(
          vehicleId: vehicleId,
          offset: offset,
          limit: limit,
          searchText: searchTextForRequest,
          searchColumnName: searchColumnNameForRequest,
        );

        rows = _vehicleController.historyItems.map((VehicleInfoHistory item) => item.toJson()).toList();
        resolvedTotalCount = _vehicleController.historyTotalCount;
      } else {
        int? infraId;
        if (_infraIdFilter != 'ALL') {
          infraId = int.tryParse(_infraIdFilter);
        }

        await _infraController.reqLoadHistory(
          infraId: infraId,
          offset: offset,
          limit: limit,
          searchText: searchTextForRequest,
          searchColumnName: searchColumnNameForRequest,
        );

        rows = _infraController.historyItems.map((InfraInfoHistory item) => item.toJson()).toList();
        resolvedTotalCount = _infraController.historyTotalCount;
      }

      if (!mounted) {
        return;
      }
      if (requestId != _loadRequestId) {
        return;
      }

      final int maxPage = (resolvedTotalCount + _rowsPerPage - 1) ~/ _rowsPerPage;
      final int safeMaxPage = maxPage < 1 ? 1 : maxPage;

      int finalPage = targetPage;
      if (finalPage > safeMaxPage) {
        finalPage = safeMaxPage;

        final int newOffset = (finalPage - 1) * _rowsPerPage;

        if (_currentEntityType == FmsEntityType.vehicle) {
          int? vehicleId;
          if (_vehicleIdFilter != 'ALL') {
            vehicleId = int.tryParse(_vehicleIdFilter);
          }
          await _vehicleController.reqLoadHistory(
            vehicleId: vehicleId,
            offset: newOffset,
            limit: limit,
            searchText: searchTextForRequest,
            searchColumnName: searchColumnNameForRequest,
          );
          rows = _vehicleController.historyItems.map((VehicleInfoHistory item) => item.toJson()).toList();
        } else {
          int? infraId;
          if (_infraIdFilter != 'ALL') {
            infraId = int.tryParse(_infraIdFilter);
          }
          await _infraController.reqLoadHistory(
            infraId: infraId,
            offset: newOffset,
            limit: limit,
            searchText: searchTextForRequest,
            searchColumnName: searchColumnNameForRequest,
          );
          rows = _infraController.historyItems.map((InfraInfoHistory item) => item.toJson()).toList();
        }
      }

      if (!mounted) {
        return;
      }
      if (requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _totalCount = resolvedTotalCount;
        _currentPage = finalPage < 1 ? 1 : finalPage;
        _pageRows = rows;
        _firstDataArrived = true;
      });

      _updateGrid();
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('_loadPage error: $exception');
      }
    } finally {
      if (!mounted) {
        return;
      }
      if (requestId != _loadRequestId) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _updateGrid();
    }
  }

  void _updateGrid() {
    if (!_gridReady || _gridStateManager == null) {
      return;
    }

    final PlutoGridStateManager manager = _gridStateManager!;
    try {
      manager.setShowLoading(_isLoading && !_firstDataArrived);

      if (_isLoading && !_firstDataArrived) {
        return;
      }

      List<PlutoRow> rowsToInsert;
      if (_pageRows.isEmpty) {
        rowsToInsert = <PlutoRow>[];
      } else {
        rowsToInsert = _buildPlutoRows(_pageRows, _cachedFields);
      }

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

  Future<void> _refreshCurrent() async {
    if (_isLoading) {
      return;
    }
    if (_currentEntityType == FmsEntityType.infra) {
      await _infraController.reqLoadInfraIdentifiers();
    }
    await _loadPage(_currentPage, force: true);
  }

  void _changePage(int page) {
    if (_isLoading || _initialLoading) {
      return;
    }
    final int safeTotalPages = _totalPages < 1 ? 1 : _totalPages;
    final int target = page.clamp(1, safeTotalPages);
    if (target == _currentPage) {
      return;
    }
    _loadPage(target);
  }

  List<int> _buildVisiblePages() {
    final int safeTotalPages = _totalPages < 1 ? 1 : _totalPages;
    if (safeTotalPages <= 1) {
      return <int>[1];
    }

    final Set<int> pages = <int>{
      1,
      safeTotalPages,
      _currentPage,
      _currentPage - 1,
      _currentPage + 1,
    };
    pages.removeWhere((int page) => page < 1 || page > safeTotalPages);

    final List<int> sorted = pages.toList()..sort();
    return sorted;
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
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1565C0));
      case 'msg_length':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6A1B9A));
      case 'msg_seq':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0));
      case 'vehicle_id':
      case 'infra_id':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32));
      case 'time_stamp_ms':
      case 'time_stamp':
      case 'updated_ts':
      case 'created_ts':
      case 'changed_at':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64));
      case 'pos_x_m':
      case 'pos_y_m':
      case 'pos_z_m':
      case 'position_x':
      case 'position_y':
      case 'position_z':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF6C00));
      default:
        return const TextStyle(fontSize: 12, color: Color(0xFF212121));
    }
  }

  TextStyle _objectFieldTextStyle(String field, String value) {
    switch (field) {
      case 'source_kind':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32));
      case 'msg_id':
      case 'msg_seq':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1565C0));
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
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0));
      case 'age':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6A1B9A));
      case 'linear_velocity_x':
      case 'linear_velocity_y':
      case 'linear_velocity_z':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF19721));
      case 'object_type':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6A1B9A));
      case 'object_id':
      case 'detected_object_id':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF37474F));
      default:
        return const TextStyle(fontSize: 12, color: Color(0xFF212121));
    }
  }

  List<PlutoColumn> _buildPlutoColumns(List<String> fields) {
    return fields.map((String field) {
      return PlutoColumn(
        title: field,
        field: field,
        type: PlutoColumnType.text(),
        enableSorting: true,
        enableColumnDrag: false,
        enableContextMenu: true,
        enableFilterMenuItem: true,
        enableDropToResize: true,
        minWidth: 120,
        titleTextAlign: PlutoColumnTextAlign.center,
        textAlign: PlutoColumnTextAlign.center,
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

  List<PlutoRow> _buildPlutoRows(List<Map<String, dynamic>> data, List<String> fields) {
    return data.map((Map<String, dynamic> row) {
      final Map<String, PlutoCell> cells = <String, PlutoCell>{};
      for (final String field in fields) {
        cells[field] = PlutoCell(value: _formatCellValue(row[field]));
      }
      return PlutoRow(cells: cells);
    }).toList();
  }

  void _openColumnFilterDialog() {
    final List<String> allFields = List<String>.from(_currentAllFields);
    Set<String> tempVisibleFields = Set<String>.from(_currentVisibleFields);

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            final int visibleCount = tempVisibleFields.length;
            final int totalCount = allFields.length;

            final bool isAllSelected = tempVisibleFields.length == allFields.length;
            final bool isAllCleared = tempVisibleFields.length == 1 && tempVisibleFields.contains(allFields.first);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: EdgeInsets.zero,
              contentPadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.view_column_rounded, size: 24, color: Color(0xFF1976D2)),
                    const SizedBox(width: 12),
                    const Text(
                      '컬럼 필터',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$visibleCount / $totalCount',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.close, size: 22, color: Color(0xFF757575)),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFAFA),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                tempVisibleFields = Set<String>.from(allFields);
                              });
                            },
                            icon: Icon(
                              isAllSelected ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: const Color(0xFF1976D2),
                            ),
                            label: const Text('전체 선택'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(color: Color(0xFF1976D2)),
                              backgroundColor: isAllSelected ? const Color(0xFFE3F2FD) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                tempVisibleFields = <String>{allFields.first};
                              });
                            },
                            icon: Icon(
                              isAllCleared ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: const Color(0xFF1976D2),
                            ),
                            label: const Text('전체 해제'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(color: Color(0xFF1976D2)),
                              backgroundColor: isAllCleared ? const Color(0xFFE3F2FD) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: allFields.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String field = allFields[index];
                          final bool isVisible = tempVisibleFields.contains(field);
                          final bool isOnlyOne = tempVisibleFields.length == 1 && isVisible;

                          return InkWell(
                            onTap: isOnlyOne
                                ? null
                                : () {
                                    setDialogState(() {
                                      if (tempVisibleFields.contains(field)) {
                                        if (tempVisibleFields.length > 1) {
                                          tempVisibleFields.remove(field);
                                        }
                                      } else {
                                        tempVisibleFields.add(field);
                                      }
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: index < allFields.length - 1 ? const Color(0xFFF5F5F5) : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isVisible ? const Color(0xFF1976D2) : Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isVisible ? const Color(0xFF1976D2) : const Color(0xFFBDBDBD),
                                        width: 2,
                                      ),
                                    ),
                                    child: isVisible
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      field,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isVisible ? FontWeight.w600 : FontWeight.w400,
                                        color: isVisible ? const Color(0xFF212121) : const Color(0xFF757575),
                                      ),
                                    ),
                                  ),
                                  if (isOnlyOne)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '필수',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF757575),
                              side: const BorderSide(color: Color(0xFFBDBDBD)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              _applyColumnFilter(tempVisibleFields);
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '확인',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
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
    );
  }

  Future<void> _openRowDetails(Map<String, dynamic> row) async {
    final String titleText = _currentEntityType == FmsEntityType.vehicle ? '차량 히스토리' : '인프라 히스토리';
    int apiObjectTotalCount = 0;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;
        bool started = false;
        bool objectsLoading = true;

        List<DetectedObject> objectItems = <DetectedObject>[];

        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            Future<void> startLoadIfNeeded() async {
              if (started) {
                return;
              }
              started = true;

              DetectedObjectResult? result;

              if (_currentEntityType == FmsEntityType.vehicle) {
                final int vehicleInfoId = _parseInt(row['vehicle_info_id']);
                if (vehicleInfoId > 0) {
                  result = await _objectController.fetchByVehicleInfo(
                    vehicleInfoId: vehicleInfoId,
                    offset: 0,
                    limit: 1000,
                  );
                }
              } else {
                final int infraInfoId = _parseInt(row['infra_info_id']);
                if (infraInfoId > 0) {
                  result = await _objectController.fetchByInfraInfo(
                    infraInfoId: infraInfoId,
                    offset: 0,
                    limit: 1000,
                  );
                }
              }

              setDialogState(() {
                if (result != null) {
                  objectItems = result.items;
                  apiObjectTotalCount = result.totalCount;
                }
                objectsLoading = false;
              });
            }

            startLoadIfNeeded();

            final int expectedCount = _parseInt(row['number_of_objects']);
            final int loadedCount = objectItems.length;

            int totalObjects;
            if (apiObjectTotalCount > 0) {
              totalObjects = apiObjectTotalCount;
            } else if (expectedCount > 0) {
              totalObjects = expectedCount;
            } else {
              totalObjects = loadedCount;
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                          _buildRowSummaryCard(row),
                          const SizedBox(height: 16),
                          Expanded(child: _buildRowDetailTable(row)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: <Widget>[
                          _buildObjectCountPanel(
                            totalCount: totalObjects,
                            expectedCount: expectedCount,
                            loadedCount: loadedCount,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: objectsLoading
                                ? const Center(
                                    child: Text(
                                      '오브젝트 로딩 중...',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                    ),
                                  )
                                : _buildObjectsTablePanel(objectItems),
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
    );
  }

  Widget _buildRowSummaryCard(Map<String, dynamic> row) {
    final bool isInfra = _currentEntityType == FmsEntityType.infra;
    final String historyIdText = _formatCellValue(row['history_id']);
    final String statusIdText =
        isInfra ? _formatCellValue(row['infra_info_id']) : _formatCellValue(row['vehicle_info_id']);
    final String primaryLabel = isInfra ? '인프라 ID' : '차량 ID';
    final String primaryValue = isInfra ? _formatCellValue(row['infra_id']) : _formatCellValue(row['vehicle_id']);
    final String msgIdValue = _formatCellValue(row['msg_id']);
    final String timeStampValue = _formatCellValue(row['time_stamp_ms'] ?? row['time_stamp'] ?? row['changed_at']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBDEFB), width: 1),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x141976D2), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '히스토리 ID',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 6),
              Text(
                historyIdText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '상태 ID',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 6),
              Text(
                statusIdText.isEmpty ? '-' : statusIdText,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF424242)),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                primaryLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 6),
              Text(
                primaryValue.isEmpty ? '-' : primaryValue,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '메시지 ID',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 6),
              Text(
                msgIdValue.isEmpty ? '-' : msgIdValue,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1565C0)),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '타임스탬프',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 6),
                Text(
                  timeStampValue.isEmpty ? '-' : timeStampValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF37474F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowDetailTable(Map<String, dynamic> row) {
    final List<String> columns = _currentAllFields;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: columns.length,
        itemBuilder: (BuildContext context, int index) {
          final String name = columns[index];
          final String value = _formatCellValue(row[name]);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 160,
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF616161)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF212121)),
                ),
              ),
            ],
          );
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(height: 16, color: Color(0xFFE0E0E0));
        },
      ),
    );
  }

  Widget _buildObjectCountPanel({
    required int totalCount,
    required int expectedCount,
    required int loadedCount,
  }) {
    final int safeTotal = totalCount < 0 ? 0 : totalCount;
    final int safeLoaded = loadedCount < 0 ? 0 : loadedCount;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 170),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFE082), width: 1),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x22FFC107), blurRadius: 12, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF1976D2)),
                  SizedBox(width: 8),
                  Text(
                    '감지된 객체',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1976D2),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                safeTotal.toString(),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFB300),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '예상: $expectedCount',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D4C41)),
              ),
              const SizedBox(height: 4),
              Text(
                '로드됨: $safeLoaded / $safeTotal',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF455A64)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectsTablePanel(List<DetectedObject> objectItems) {
    if (objectItems.isEmpty) {
      return const Center(
        child: Text(
          '이 메시지에 대한 객체가 없습니다',
          style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
      );
    }

    final List<String> fields = _getObjectFields();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: ListView.builder(
        itemCount: objectItems.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> obj = objectItems[index].toJson();
          return _buildObjectCard(index: index, obj: obj, fields: fields);
        },
      ),
    );
  }

  Widget _buildObjectCard({
    required int index,
    required Map<String, dynamic> obj,
    required List<String> fields,
  }) {
    const Color blueColor = Color(0xFF1976D2);
    final String headerText = '객체 ${index + 1}';

    final int objectTypeValue = _parseIntOrFallback(obj['object_type'], -1);
    final ObjectTypeUi objectTypeUi = _objectTypeUi(objectTypeValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBDEFB), width: 1),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x1A1976D2), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: <Widget>[
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F2FD),
                border: Border(left: BorderSide(color: blueColor, width: 6)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: blueColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    headerText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: blueColor),
                  ),
                  const Spacer(),
                  Icon(objectTypeUi.iconData, size: 18, color: blueColor),
                  const SizedBox(width: 6),
                  Text(
                    objectTypeUi.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: blueColor),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                children: fields.map((String field) {
                  final String value = _formatCellValue(obj[field]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 170,
                          child: Text(
                            field,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value.isEmpty ? '-' : value,
                            style: _objectFieldTextStyle(field, value),
                          ),
                        ),
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

  Widget _buildPageButton({
    required Widget child,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selected ? const Color(0xFF2F80ED) : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF2E2E2E),
          disabledForegroundColor: const Color(0xFFBDBDBD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? const Color(0xFF2F80ED) : const Color(0xFFE0E0E0),
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildPaginationBar() {
    final int currentPageSafe = _currentPage < 1 ? 1 : _currentPage;
    final List<int> visiblePages = _buildVisiblePages();

    final bool canGoPrev = !(_isLoading || _initialLoading) && currentPageSafe > 1;
    final bool canGoNext = !(_isLoading || _initialLoading) && currentPageSafe < _totalPages;

    final List<Widget> pager = <Widget>[
      _buildPageButton(
        child: const Icon(Icons.chevron_left, size: 22),
        onPressed: canGoPrev ? () => _changePage(currentPageSafe - 1) : null,
      ),
      const SizedBox(width: 10),
    ];

    for (int index = 0; index < visiblePages.length; index++) {
      final int pageNumber = visiblePages[index];

      if (index > 0) {
        final int previous = visiblePages[index - 1];
        if (pageNumber - previous > 1) {
          pager.add(
            _buildPageButton(
              child: const Text(
                '...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onPressed: null,
            ),
          );
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
          onPressed: (!(_isLoading || _initialLoading) && !selected) ? () => _changePage(pageNumber) : null,
        ),
      );
      pager.add(const SizedBox(width: 10));
    }

    pager.add(
      _buildPageButton(
        child: const Icon(Icons.chevron_right, size: 22),
        onPressed: canGoNext ? () => _changePage(currentPageSafe + 1) : null,
      ),
    );

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFF5F5F5),
      child: Row(
        children: <Widget>[
          const Spacer(),
          Row(children: pager),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildEntitySegment() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildEntityChip(FmsEntityType.vehicle, '차량'),
          _buildEntityChip(FmsEntityType.infra, '인프라'),
          _buildMapChip(),
        ],
      ),
    );
  }

  Widget _buildEntityChip(FmsEntityType type, String label) {
    final bool isSelected = !_isMapView && _currentEntityType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        if (_isLoading) {
          return;
        }
        if (_currentEntityType == type && !_isMapView) {
          return;
        }
        if (!mounted) {
          return;
        }

        setState(() {
          _isMapView = false;
          _currentEntityType = type;
          _lastEntityType = type;
          _vehicleIdFilter = 'ALL';
          _infraIdFilter = 'ALL';
          _currentPage = 1;
          _totalCount = 0;
          _pageRows = <Map<String, dynamic>>[];
          _firstDataArrived = false;
          _gridReady = false;
          _gridStateManager = null;
          _activeFilterColumn = null;
          _activeFilterValue = null;
          _rebuildCachedColumns();
        });

        if (type == FmsEntityType.infra) {
          await _infraController.reqLoadInfraIdentifiers();
        }

        await _loadPage(1, resetFilters: true, force: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF424242),
          ),
        ),
      ),
    );
  }

  Widget _buildMapChip() {
    final bool isSelected = _isMapView;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        if (!mounted) {
          return;
        }
        if (isSelected) {
          return;
        }
        setState(() {
          _isMapView = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.map_outlined,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF424242),
            ),
            const SizedBox(width: 6),
            Text(
              '지도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF424242),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnFilterButton() {
    final int visibleCount = _currentVisibleFields.length;
    final int totalCount = _currentAllFields.length;

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
            const Icon(Icons.view_column_rounded, size: 18, color: Color(0xFF1976D2)),
            const SizedBox(width: 8),
            const Text(
              '컬럼',
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
        return '수동';
      case AutoUpdateInterval.oneSecond:
        return '1초';
      case AutoUpdateInterval.threeSeconds:
        return '3초';
      case AutoUpdateInterval.fiveSeconds:
        return '5초';
    }
  }

  Widget _buildManualRefreshButton() {
    return InkWell(
      onTap: (_isLoading || _initialLoading) ? null : _refreshCurrent,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (_isLoading || _initialLoading) ? const Color(0xFFF5F5F5) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (_isLoading || _initialLoading) ? const Color(0xFFE0E0E0) : const Color(0xFF1976D2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.refresh,
              size: 18,
              color: (_isLoading || _initialLoading) ? const Color(0xFF9E9E9E) : const Color(0xFF1976D2),
            ),
            const SizedBox(width: 8),
            Text(
              '새로고침',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: (_isLoading || _initialLoading) ? const Color(0xFF9E9E9E) : const Color(0xFF1976D2),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      elevation: 8,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<AutoUpdateInterval>>[
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.manual,
            child: Row(
              children: <Widget>[
                Icon(
                  _currentUpdateInterval == AutoUpdateInterval.manual ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: _currentUpdateInterval == AutoUpdateInterval.manual
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                const Text(
                  '수동',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.oneSecond,
            child: Row(
              children: <Widget>[
                Icon(
                  _currentUpdateInterval == AutoUpdateInterval.oneSecond ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: _currentUpdateInterval == AutoUpdateInterval.oneSecond
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                const Text(
                  '1초 자동',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.threeSeconds,
            child: Row(
              children: <Widget>[
                Icon(
                  _currentUpdateInterval == AutoUpdateInterval.threeSeconds
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: _currentUpdateInterval == AutoUpdateInterval.threeSeconds
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                const Text(
                  '3초 자동',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<AutoUpdateInterval>(
            value: AutoUpdateInterval.fiveSeconds,
            child: Row(
              children: <Widget>[
                Icon(
                  _currentUpdateInterval == AutoUpdateInterval.fiveSeconds ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: _currentUpdateInterval == AutoUpdateInterval.fiveSeconds
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 10),
                const Text(
                  '5초 자동',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ];
      },
      onSelected: (AutoUpdateInterval interval) {
        _changeUpdateInterval(interval);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _currentUpdateInterval != AutoUpdateInterval.manual ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _currentUpdateInterval != AutoUpdateInterval.manual ? const Color(0xFF1976D2) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.refresh,
              size: 18,
              color: _currentUpdateInterval != AutoUpdateInterval.manual
                  ? const Color(0xFF1976D2)
                  : const Color(0xFF616161),
            ),
            const SizedBox(width: 8),
            Text(
              _getUpdateIntervalLabel(_currentUpdateInterval),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _currentUpdateInterval != AutoUpdateInterval.manual
                    ? const Color(0xFF1976D2)
                    : const Color(0xFF424242),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: _currentUpdateInterval != AutoUpdateInterval.manual
                  ? const Color(0xFF1976D2)
                  : const Color(0xFF616161),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    if (_isMapView) {
      return const SizedBox.shrink();
    }

    final ThemeData baseTheme = Theme.of(context);
    final ThemeData dropdownTheme = baseTheme.copyWith(
      canvasColor: Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(surface: Colors.white),
    );

    if (_currentEntityType == FmsEntityType.vehicle) {
      final List<String> vehicleIds =
          _vehicleController.vehicles.map((Vehicle vehicle) => '${vehicle.vehicleId}').toList();
      vehicleIds.sort((String left, String right) {
        return _parseInt(left).compareTo(_parseInt(right));
      });

      return Row(
        children: <Widget>[
          const Text(
            '차량:',
            style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
          ),
          const SizedBox(width: 8),
          Theme(
            data: dropdownTheme,
            child: DropdownButton<String>(
              value: _vehicleIdFilter,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF212121),
                fontWeight: FontWeight.w600,
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: 'ALL', child: Text('전체')),
                ...vehicleIds.map((String vehicleIdText) {
                  return DropdownMenuItem<String>(
                    value: vehicleIdText,
                    child: Text(vehicleIdText),
                  );
                }),
              ],
              onChanged: (String? value) async {
                if (value == null) {
                  return;
                }
                if (!mounted) {
                  return;
                }
                if (_isLoading) {
                  return;
                }
                setState(() {
                  _vehicleIdFilter = value;
                  _currentPage = 1;
                });
                await _loadPage(1, force: true);
              },
            ),
          ),
        ],
      );
    }

    if (_currentEntityType == FmsEntityType.infra) {
      final List<String> sortedIds =
          _infraController.infraIdentifiers.map((int value) => value.toString()).toSet().toList();
      sortedIds.sort((String left, String right) {
        return _parseInt(left).compareTo(_parseInt(right));
      });

      return Row(
        children: <Widget>[
          const Text(
            '인프라:',
            style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
          ),
          const SizedBox(width: 8),
          Theme(
            data: dropdownTheme,
            child: DropdownButton<String>(
              value: _infraIdFilter,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF212121),
                fontWeight: FontWeight.w600,
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: 'ALL', child: Text('전체')),
                ...sortedIds.map((String infraIdText) {
                  return DropdownMenuItem<String>(
                    value: infraIdText,
                    child: Text(infraIdText),
                  );
                }),
              ],
              onChanged: (String? value) async {
                if (value == null) {
                  return;
                }
                if (!mounted) {
                  return;
                }
                if (_isLoading) {
                  return;
                }
                setState(() {
                  _infraIdFilter = value;
                  _currentPage = 1;
                });
                await _loadPage(1, force: true);
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _onColumnFilterChanged() {
    if (!_gridReady) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (_isLoading) {
      return;
    }
    _handleColumnFilterChange();
  }

  Widget _buildToolbar() {
    final int currentPageSafe = _currentPage < 1 ? 1 : _currentPage;
    final int totalPagesSafe = _totalPages < 1 ? 1 : _totalPages;

    if (_isMapView) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            _buildEntitySegment(),
            const Spacer(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          _buildEntitySegment(),
          const SizedBox(width: 16),
          _buildFilters(),
          const SizedBox(width: 16),
          _buildColumnFilterButton(),
          const Spacer(),
          Text(
            '총: $_totalCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (_isLoading || _initialLoading) ? const Color(0xFF9E9E9E) : const Color(0xFF424242),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$currentPageSafe/$totalPagesSafe',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: (_isLoading || _initialLoading) ? const Color(0xFF9E9E9E) : const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 10),
          _buildManualRefreshButton(),
          const SizedBox(width: 10),
          _buildUpdateButton(),
        ],
      ),
    );
  }

  Widget _buildPlutoGrid(double availableHeight) {
    const double columnHeight = 44;
    const double columnFilterHeight = 46;
    const double scrollbarThickness = 12;
    const double verticalBorders = 2;
    final double bodyHeight =
        availableHeight - columnHeight - columnFilterHeight - scrollbarThickness - verticalBorders;
    final double rowHeight = (bodyHeight / _rowsPerPage).floorToDouble().clamp(22, 60);
    final PlutoGrid grid = PlutoGrid(
      key: ValueKey<String>('dashboard_grid_${_currentEntityType.name}_${_cachedFields.length}'),
      columns: List<PlutoColumn>.from(_cachedColumns, growable: true),
      rows: <PlutoRow>[],
      onLoaded: (PlutoGridOnLoadedEvent event) {
        _gridStateManager = event.stateManager;
        _gridReady = true;
        final PlutoGridStateManager manager = event.stateManager;
        try {
          manager.setSelectingMode(PlutoGridSelectingMode.row);
          manager.setShowLoading(_isLoading && !_firstDataArrived);
          manager.setShowColumnFilter(true);
          manager.setFilterOnlyEvent(true);
          _gridEventSubscription?.cancel();
          _gridEventSubscription = manager.eventManager?.listener((PlutoGridEvent gridEvent) {
            if (gridEvent is PlutoGridSetColumnFilterEvent) {
              _onColumnFilterChanged();
            }
          });
        } catch (_) {}
        if (mounted) {
          setState(() {});
        }
        _updateGrid();
      },
      onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) async {
        final int index = event.rowIdx;
        if (index < 0 || index >= _pageRows.length) {
          return;
        }
        await _openRowDetails(_pageRows[index]);
      },
      configuration: PlutoGridConfiguration(
        columnFilter: const PlutoGridColumnFilterConfig(
          filters: FilterHelper.defaultFilters,
          debounceMilliseconds: 300,
        ),
        scrollbar: const PlutoGridScrollbarConfig(
          isAlwaysShown: false,
          scrollbarThickness: scrollbarThickness,
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
        ),
      ),
    );

    return SizedBox(
      height: availableHeight,
      child: grid,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: <Widget>[
          _buildToolbar(),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _isMapView
                  ? const InfraVehicleMapPanel()
                  : LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double availableHeight = constraints.maxHeight;
                        return _buildPlutoGrid(availableHeight);
                      },
                    ),
            ),
          ),
          if (!_isMapView) _buildPaginationBar(),
        ],
      ),
    );
  }
}
