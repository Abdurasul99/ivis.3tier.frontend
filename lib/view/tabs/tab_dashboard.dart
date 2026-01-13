import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../model/infra_model.dart';
import '../../model/object_model.dart';
import '../../viewmodel/controller/infra_controller.dart';
import '../../viewmodel/controller/object_controller.dart';
import '../../viewmodel/controller/vehicle_controller.dart';

enum FmsEntityType { vehicle, infra }

class _PageResult {
  final List<Map<String, dynamic>> rows;
  final int totalCount;
  const _PageResult(this.rows, this.totalCount);
}

class _ObjectPageResult {
  final List<Map<String, dynamic>> rows;
  final bool hasNext;
  final int totalCount;
  final int offset;
  final int limit;
  const _ObjectPageResult(this.rows, this.hasNext, this.totalCount, this.offset, this.limit);
}

class TabDashboard extends StatefulWidget {
  const TabDashboard({super.key});

  @override
  State<TabDashboard> createState() => _TabDashboardState();
}

class _TabDashboardState extends State<TabDashboard> with AutomaticKeepAliveClientMixin<TabDashboard> {
  static FmsEntityType _lastEntityType = FmsEntityType.vehicle;

  late final VehicleController vehicleController;
  late final InfraController infraController;
  late final ObjectController objectController;

  late FmsEntityType currentEntityType;

  bool initialLoading = true;
  bool isLoading = false;

  int currentPage = 1;
  int totalCount = 0;

  String vehicleIdFilter = 'ALL';
  String infraIdFilter = 'ALL';

  int rowsPerPage = 18;

  List<Map<String, dynamic>> pageRows = <Map<String, dynamic>>[];

  PlutoGridStateManager? gridStateManager;
  bool gridReady = false;

  List<String> cachedFields = <String>[];
  List<PlutoColumn> cachedColumns = <PlutoColumn>[];
  List<PlutoRow> cachedGridRows = <PlutoRow>[];

  int loadRequestId = 0;
  bool firstDataArrived = false;

  @override
  bool get wantKeepAlive => true;

  int get totalPages {
    final int safeTotal = totalCount < 0 ? 0 : totalCount;
    final int pages = (safeTotal + rowsPerPage - 1) ~/ rowsPerPage;
    return pages < 1 ? 1 : pages;
  }

  @override
  void initState() {
    super.initState();
    currentEntityType = _lastEntityType;
    vehicleController =
        Get.isRegistered<VehicleController>() ? Get.find<VehicleController>() : Get.put(VehicleController());
    infraController = Get.isRegistered<InfraController>() ? Get.find<InfraController>() : Get.put(InfraController());
    objectController =
        Get.isRegistered<ObjectController>() ? Get.find<ObjectController>() : Get.put(ObjectController());

    cachedFields = getStableFieldsForEntity(currentEntityType);
    cachedColumns = buildPlutoColumns(cachedFields);
    cachedGridRows = buildPlaceholderRows(text: 'Loading...', fields: cachedFields);

    Future<void>.microtask(() async {
      try {
        await waitForTokenReady();
        await vehicleController.reqLoadVehicles();
        if (currentEntityType == FmsEntityType.infra) {
          await ensureInfraIdentifiersLoaded();
        }
        await loadPage(1, resetFilters: true, force: true);
      } finally {
        if (!mounted) return;
        setState(() {
          initialLoading = false;
        });
      }
    });
  }

  List<String> getStableFieldsForEntity(FmsEntityType type) {
    if (type == FmsEntityType.vehicle) return getPreferredVehicleColumns();
    return getPreferredInfraColumns();
  }

  Future<void> waitForTokenReady() async {
    if (vehicleController.hasToken) return;
    for (int index = 0; index < 300; index++) {
      if (vehicleController.hasToken) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    if (value is String) return value;
    return value.toString();
  }

  List<Map<String, dynamic>> mapDynamicList(List<dynamic> rawList) {
    final List<Map<String, dynamic>> mapped = <Map<String, dynamic>>[];
    for (final dynamic element in rawList) {
      if (element == null) continue;
      try {
        if (element is Map<String, dynamic>) {
          mapped.add(element);
        } else if (element is Message) {
          final Map<String, dynamic> jsonMap = element.toJson();
          if (jsonMap.isNotEmpty) mapped.add(jsonMap);
        } else if (element is DetectedObject) {
          final Map<String, dynamic> jsonMap = element.toJson();
          if (jsonMap.isNotEmpty) mapped.add(jsonMap);
        } else if (element is Map) {
          final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(element);
          if (jsonMap.isNotEmpty) mapped.add(jsonMap);
        }
      } catch (_) {}
    }
    return mapped;
  }

  Future<void> ensureInfraIdentifiersLoaded() async {
    if (!infraController.hasToken) return;
    try {
      await infraController.reqLoadInfraIdentifiers();
    } catch (_) {}
    if (!mounted) return;
    if (infraIdFilter != 'ALL') {
      final bool exists =
          infraController.infraIdentifiers.any((int identifier) => identifier.toString() == infraIdFilter);
      if (!exists) {
        setState(() {
          infraIdFilter = 'ALL';
          currentPage = 1;
        });
      }
    }
  }

  Future<_PageResult> fetchPage(int page) async {
    final int offset = (page - 1) * rowsPerPage;
    final int limit = rowsPerPage;

    Map<String, dynamic> meta;

    if (currentEntityType == FmsEntityType.vehicle) {
      int? vehicleId;
      if (vehicleIdFilter != 'ALL') {
        vehicleId = int.tryParse(vehicleIdFilter);
      }
      meta = await infraController.fetchVehicleHistoryPageWithMeta(
        vehicleId: vehicleId,
        offset: offset,
        limit: limit,
      );
    } else {
      int? infraId;
      if (infraIdFilter != 'ALL') {
        infraId = int.tryParse(infraIdFilter);
      }
      meta = await infraController.fetchInfraHistoryPageWithMeta(
        infraId: infraId,
        offset: offset,
        limit: limit,
      );
    }

    final dynamic itemsDynamic = meta['items'];
    final dynamic totalDynamic = meta['totalCount'];

    final List<dynamic> items = itemsDynamic is List ? itemsDynamic : <dynamic>[];
    final int resolvedTotalCount = parseInt(totalDynamic);

    final List<Map<String, dynamic>> mappedRows = mapDynamicList(items);
    final int safeTotal = resolvedTotalCount > 0 ? resolvedTotalCount : (offset + mappedRows.length);

    return _PageResult(mappedRows, safeTotal);
  }

  Future<void> loadPage(int page, {bool resetFilters = false, bool force = false}) async {
    if (isLoading) return;

    if (!vehicleController.hasToken) {
      await waitForTokenReady();
      if (!vehicleController.hasToken) return;
    }

    if (resetFilters) {
      vehicleIdFilter = 'ALL';
      infraIdFilter = 'ALL';
      currentPage = 1;
    }

    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final int targetPage = force ? page : page.clamp(1, safeTotalPages);
    if (!force && targetPage == currentPage) return;

    final int requestId = ++loadRequestId;

    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    updateGrid();

    try {
      final _PageResult pageResult = await fetchPage(targetPage);

      if (!mounted) return;
      if (requestId != loadRequestId) return;

      final int resolvedTotalCount = pageResult.totalCount < 0 ? 0 : pageResult.totalCount;

      final int maxPage = (resolvedTotalCount + rowsPerPage - 1) ~/ rowsPerPage;
      final int safeMaxPage = maxPage < 1 ? 1 : maxPage;

      int finalPage = targetPage;
      _PageResult finalResult = pageResult;

      if (finalPage > safeMaxPage) {
        finalPage = safeMaxPage;
        finalResult = await fetchPage(finalPage);
      }

      if (!mounted) return;
      if (requestId != loadRequestId) return;

      setState(() {
        totalCount = resolvedTotalCount;
        currentPage = finalPage < 1 ? 1 : finalPage;
        pageRows = finalResult.rows;
        firstDataArrived = true;
      });

      updateGrid();
    } catch (exception) {
      if (kDebugMode) debugPrint('loadPage error: $exception');
    } finally {
      if (!mounted) return;
      if (requestId != loadRequestId) return;
      setState(() {
        isLoading = false;
      });
      updateGrid();
    }
  }

  List<String> getPreferredVehicleColumns() {
    return <String>[
      'id',
      'vehicle_info_id',
      'msg_seq',
      'msg_length',
      'time_stamp',
      'time_stamp_ms',
      'vehicle_id',
      'navsat',
      'velocity_kph',
      'velocity_mps',
      'position_x',
      'position_y',
      'position_z',
      'orientation_heading',
      'accel_x',
      'accel_y',
      'accel_z',
      'rot_rate_x',
      'rot_rate_y',
      'rot_rate_z',
      'transmission_gear',
      'signal_light',
      'steer_angle',
      'steer_torque',
      'pedal_accel',
      'brake',
      'number_of_objects',
      'created_ts',
      'updated_ts',
    ];
  }

  List<String> getPreferredInfraColumns() {
    return <String>[
      'history_id',
      'infra_info_id',
      'changed_at',
      'msg_seq',
      'msg_length',
      'time_stamp',
      'time_stamp_ms',
      'infra_id',
      'number_of_objects',
      'created_ts',
      'updated_ts',
    ];
  }

  List<String> getPreferredObjectGridColumns() {
    return <String>[
      'detected_object_id',
      'source_kind',
      'vehicle_info_id',
      'infra_info_id',
      'object_id',
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
      'time_stamp_ms',
      'msg_seq',
      'msg_length',
    ];
  }

  List<String> mergeFields(List<String> keys, List<String> preferred) {
    final Set<String> keySet = keys.toSet();
    final List<String> out = <String>[];
    for (final String preferredField in preferred) {
      if (keySet.contains(preferredField)) out.add(preferredField);
    }
    for (final String key in keys) {
      if (!out.contains(key)) out.add(key);
    }
    if (out.isEmpty) return <String>['id'];
    return out;
  }

  String resolveFieldValue(String field, Map<String, dynamic> row) {
    if (field == 'infra_info_id') {
      return formatCellValue(row['infra_info_id'] ?? row['id'] ?? row['history_id']);
    }
    if (field == 'vehicle_info_id') {
      return formatCellValue(row['vehicle_info_id'] ?? row['id']);
    }
    return formatCellValue(row[field]);
  }

  TextStyle cellTextStyle(String field, String value) {
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
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64));
      case 'pos_x_m':
      case 'pos_y_m':
      case 'pos_z_m':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF6C00));
      default:
        return const TextStyle(fontSize: 12, color: Color(0xFF212121));
    }
  }

  List<PlutoColumn> buildPlutoColumns(List<String> fields) {
    return fields.map((String field) {
      return PlutoColumn(
        title: field,
        field: field,
        type: PlutoColumnType.text(),
        enableSorting: false,
        enableColumnDrag: false,
        enableContextMenu: false,
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
              style: cellTextStyle(context.column.field, value),
            ),
          );
        },
      );
    }).toList();
  }

  List<PlutoRow> buildPlutoRows(List<Map<String, dynamic>> data, List<String> fields) {
    return data.map((Map<String, dynamic> row) {
      final Map<String, PlutoCell> cells = <String, PlutoCell>{};
      for (final String field in fields) {
        cells[field] = PlutoCell(value: resolveFieldValue(field, row));
      }
      return PlutoRow(cells: cells);
    }).toList();
  }

  List<PlutoRow> buildPlaceholderRows({required String text, required List<String> fields}) {
    final List<String> safeFields = fields.isEmpty ? <String>['id'] : fields;
    final Map<String, PlutoCell> cells = <String, PlutoCell>{};
    for (int index = 0; index < safeFields.length; index++) {
      final String field = safeFields[index];
      cells[field] = PlutoCell(value: index == 0 ? text : '');
    }
    return <PlutoRow>[PlutoRow(cells: cells)];
  }

  void updateGrid() {
    if (!gridReady || gridStateManager == null) {
      return;
    }

    final PlutoGridStateManager manager = gridStateManager!;
    try {
      manager.setShowLoading(isLoading && !firstDataArrived);

      if (isLoading && !firstDataArrived) {
        return;
      }

      List<PlutoRow> rowsToInsert;
      if (pageRows.isEmpty) {
        rowsToInsert = <PlutoRow>[];
      } else {
        rowsToInsert = buildPlutoRows(pageRows, cachedFields);
      }

      manager.removeAllRows();
      if (rowsToInsert.isNotEmpty) {
        manager.appendRows(rowsToInsert);
      }
      manager.notifyListeners();
    } catch (exception) {
      if (kDebugMode) debugPrint('updateGrid error: $exception');
    }
  }

  Future<void> refreshCurrent() async {
    if (isLoading) return;
    if (currentEntityType == FmsEntityType.infra) {
      await ensureInfraIdentifiersLoaded();
    }
    await loadPage(currentPage, force: true);
  }

  void changePage(int page) {
    if (isLoading || initialLoading) return;
    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final int target = page.clamp(1, safeTotalPages);
    if (target == currentPage) return;
    loadPage(target);
  }

  List<int> buildVisiblePages() {
    final int safeTotalPages = totalPages < 1 ? 1 : totalPages;
    if (safeTotalPages <= 1) return <int>[1];

    final Set<int> pages = <int>{1, safeTotalPages, currentPage, currentPage - 1, currentPage + 1};
    pages.removeWhere((int page) => page < 1 || page > safeTotalPages);

    final List<int> sorted = pages.toList()..sort();
    return sorted;
  }

  Widget pageButton({required Widget child, required VoidCallback? onPressed, bool selected = false}) {
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

  Widget buildPaginationBar() {
    final int currentPageSafe = currentPage < 1 ? 1 : currentPage;
    final List<int> visiblePages = buildVisiblePages();

    final bool canGoPrev = !(isLoading || initialLoading) && currentPageSafe > 1;
    final bool canGoNext = !(isLoading || initialLoading) && currentPageSafe < totalPages;

    final List<Widget> pager = <Widget>[
      pageButton(
        child: const Icon(Icons.chevron_left, size: 22),
        onPressed: canGoPrev ? () => changePage(currentPageSafe - 1) : null,
      ),
      const SizedBox(width: 10),
    ];

    for (int index = 0; index < visiblePages.length; index++) {
      final int pageNumber = visiblePages[index];

      if (index > 0) {
        final int previous = visiblePages[index - 1];
        if (pageNumber - previous > 1) {
          pager.add(
            pageButton(
              child: const Text('...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              onPressed: null,
            ),
          );
          pager.add(const SizedBox(width: 10));
        }
      }

      final bool selected = pageNumber == currentPageSafe;

      pager.add(
        pageButton(
          selected: selected,
          child: Text(
            pageNumber.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF2E2E2E),
            ),
          ),
          onPressed: (!(isLoading || initialLoading) && !selected) ? () => changePage(pageNumber) : null,
        ),
      );
      pager.add(const SizedBox(width: 10));
    }

    pager.add(
      pageButton(
        child: const Icon(Icons.chevron_right, size: 22),
        onPressed: canGoNext ? () => changePage(currentPageSafe + 1) : null,
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

  Widget buildEntitySegment() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          buildEntityChip(FmsEntityType.vehicle, 'Vehicle'),
          buildEntityChip(FmsEntityType.infra, 'Infra'),
        ],
      ),
    );
  }

  Widget buildEntityChip(FmsEntityType type, String label) {
    final bool isSelected = currentEntityType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        if (isLoading) return;
        if (currentEntityType == type) return;
        if (!mounted) return;

        setState(() {
          currentEntityType = type;
          _lastEntityType = type;
          vehicleIdFilter = 'ALL';
          infraIdFilter = 'ALL';
          currentPage = 1;
          totalCount = 0;
          pageRows = <Map<String, dynamic>>[];
          firstDataArrived = false;
          gridReady = false;
          gridStateManager = null;
          cachedFields = getStableFieldsForEntity(type);
          cachedColumns = buildPlutoColumns(cachedFields);
          cachedGridRows = buildPlaceholderRows(text: 'Loading...', fields: cachedFields);
        });

        if (type == FmsEntityType.infra) {
          await ensureInfraIdentifiersLoaded();
        }

        await loadPage(1, resetFilters: true, force: true);
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

  Widget buildFilters() {
    final ThemeData baseTheme = Theme.of(context);
    final ThemeData dropdownTheme = baseTheme.copyWith(
      canvasColor: Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(surface: Colors.white),
    );

    if (currentEntityType == FmsEntityType.vehicle) {
      final List<String> vehicleIds = vehicleController.vehicles.map((vehicle) => '${vehicle.vehicleId}').toList();
      vehicleIds.sort((String left, String right) => (int.tryParse(left) ?? 0).compareTo(int.tryParse(right) ?? 0));

      return Row(
        children: <Widget>[
          const Text('Vehicle:', style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
          const SizedBox(width: 8),
          Theme(
            data: dropdownTheme,
            child: DropdownButton<String>(
              value: vehicleIdFilter,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(fontSize: 13, color: Color(0xFF212121), fontWeight: FontWeight.w600),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: 'ALL', child: Text('전체')),
                ...vehicleIds.map((String vehicleIdText) =>
                    DropdownMenuItem<String>(value: vehicleIdText, child: Text(vehicleIdText))),
              ],
              onChanged: (String? value) async {
                if (value == null) return;
                if (!mounted) return;
                if (isLoading) return;
                setState(() {
                  vehicleIdFilter = value;
                  currentPage = 1;
                });
                await loadPage(1, force: true);
              },
            ),
          ),
        ],
      );
    }

    if (currentEntityType == FmsEntityType.infra) {
      final List<String> sortedIds = infraController.infraIdentifiers
          .map((int value) => value.toString())
          .toSet()
          .toList()
        ..sort((String left, String right) => (int.tryParse(left) ?? 0).compareTo(int.tryParse(right) ?? 0));

      return Row(
        children: <Widget>[
          const Text('Infra:', style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
          const SizedBox(width: 8),
          Theme(
            data: dropdownTheme,
            child: DropdownButton<String>(
              value: infraIdFilter,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(fontSize: 13, color: Color(0xFF212121), fontWeight: FontWeight.w600),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(value: 'ALL', child: Text('전체')),
                ...sortedIds.map(
                    (String infraIdText) => DropdownMenuItem<String>(value: infraIdText, child: Text(infraIdText))),
              ],
              onChanged: (String? value) async {
                if (value == null) return;
                if (!mounted) return;
                if (isLoading) return;
                setState(() {
                  infraIdFilter = value;
                  currentPage = 1;
                });
                await loadPage(1, force: true);
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget buildToolbar() {
    final int currentPageSafe = currentPage < 1 ? 1 : currentPage;
    final int totalPagesSafe = totalPages < 1 ? 1 : totalPages;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          buildEntitySegment(),
          const SizedBox(width: 16),
          buildFilters(),
          const Spacer(),
          Text(
            'Total: $totalCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (isLoading || initialLoading) ? const Color(0xFF9E9E9E) : const Color(0xFF424242),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$currentPageSafe/$totalPagesSafe',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: (isLoading || initialLoading) ? const Color(0xFF9E9E9E) : const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: isLoading ? null : () => refreshCurrent(),
            child: const Text('업데이트', style: TextStyle(fontSize: 13, color: Color(0xFF1565C0))),
          ),
        ],
      ),
    );
  }

  Future<_ObjectPageResult> loadObjectsPageForRow(Map<String, dynamic> row, int offset, int limit) async {
    if (!objectController.hasToken) {
      return _ObjectPageResult(<Map<String, dynamic>>[], false, 0, offset, limit);
    }

    int readIntFromAnyKey(Map<String, dynamic> map, List<String> keys) {
      for (final String key in keys) {
        final dynamic value = map[key];
        if (value != null) {
          final int parsed = parseInt(value);
          if (parsed > 0) return parsed;
        }
      }
      return 0;
    }

    List<Map<String, dynamic>> uniqueObjects(List<Map<String, dynamic>> items) {
      final Set<int> seenObjectIds = <int>{};
      final Set<int> seenDetectedIds = <int>{};
      final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];

      for (final Map<String, dynamic> element in items) {
        final int objectId = parseInt(element['object_id'] ?? element['objectId']);
        if (objectId > 0) {
          if (seenObjectIds.contains(objectId)) continue;
          seenObjectIds.add(objectId);
          out.add(element);
          continue;
        }

        final int detectedId = parseInt(element['detected_object_id'] ?? element['detectedObjectId']);
        if (detectedId <= 0) continue;
        if (seenDetectedIds.contains(detectedId)) continue;
        seenDetectedIds.add(detectedId);
        out.add(element);
      }

      return out;
    }

    List<Map<String, dynamic>> sortObjects(List<Map<String, dynamic>> items) {
      items.sort((Map<String, dynamic> left, Map<String, dynamic> right) {
        final int leftObjectId = parseInt(left['object_id'] ?? left['objectId']);
        final int rightObjectId = parseInt(right['object_id'] ?? right['objectId']);
        if (leftObjectId != rightObjectId) return leftObjectId.compareTo(rightObjectId);

        final int leftDetectedId = parseInt(left['detected_object_id'] ?? left['detectedObjectId']);
        final int rightDetectedId = parseInt(right['detected_object_id'] ?? right['detectedObjectId']);
        return leftDetectedId.compareTo(rightDetectedId);
      });
      return items;
    }

    try {
      final int expectedCount = parseInt(row['number_of_objects']);

      if (currentEntityType == FmsEntityType.vehicle) {
        final int vehicleInfoId = parseInt(row['vehicle_info_id'] ?? row['id']);
        if (vehicleInfoId <= 0) {
          return _ObjectPageResult(<Map<String, dynamic>>[], false, 0, offset, limit);
        }

        final Map<String, dynamic> meta = await objectController.objectRepository.requestByVehicleInfoWithMeta(
          vehicleInfoId: vehicleInfoId,
          limit: limit,
          offset: offset,
        );

        final int metaTotal = parseInt(meta['totalCount'] ?? meta['total']);
        final List<DetectedObject> objects = meta['items'] is List<DetectedObject> ? meta['items'] : <DetectedObject>[];

        final List<Map<String, dynamic>> mapped = objects
            .map((DetectedObject element) => element.toJson())
            .where((Map<String, dynamic> element) => element.isNotEmpty)
            .toList();

        final List<Map<String, dynamic>> filtered = mapped.where((Map<String, dynamic> element) {
          final int elementVehicleInfoId = readIntFromAnyKey(element, <String>['vehicle_info_id', 'vehicleInfoId']);
          if (elementVehicleInfoId <= 0) return false;
          return elementVehicleInfoId == vehicleInfoId;
        }).toList();

        final List<Map<String, dynamic>> unique = sortObjects(uniqueObjects(filtered));

        final int safeTotal = metaTotal > 0 ? metaTotal : (expectedCount > 0 ? expectedCount : unique.length);
        final bool hasNext = metaTotal > 0 ? (offset + limit) < metaTotal : false;

        return _ObjectPageResult(unique, hasNext, safeTotal, offset, limit);
      } else {
        final int infraInfoId = parseInt(row['infra_info_id'] ?? row['id'] ?? row['history_id']);
        if (infraInfoId <= 0) {
          return _ObjectPageResult(<Map<String, dynamic>>[], false, 0, offset, limit);
        }

        final Map<String, dynamic> meta = await objectController.objectRepository.requestByInfraInfoWithMeta(
          infraInfoId: infraInfoId,
          limit: limit,
          offset: offset,
        );

        final int metaTotal = parseInt(meta['totalCount'] ?? meta['total']);
        final List<DetectedObject> objects = meta['items'] is List<DetectedObject> ? meta['items'] : <DetectedObject>[];

        final List<Map<String, dynamic>> mapped = objects
            .map((DetectedObject element) => element.toJson())
            .where((Map<String, dynamic> element) => element.isNotEmpty)
            .toList();

        final List<Map<String, dynamic>> filtered = mapped.where((Map<String, dynamic> element) {
          final int elementInfraInfoId = readIntFromAnyKey(element, <String>['infra_info_id', 'infraInfoId']);
          if (elementInfraInfoId <= 0) return false;
          return elementInfraInfoId == infraInfoId;
        }).toList();

        final List<Map<String, dynamic>> unique = sortObjects(uniqueObjects(filtered));

        final int safeTotal = metaTotal > 0 ? metaTotal : (expectedCount > 0 ? expectedCount : unique.length);
        final bool hasNext = metaTotal > 0 ? (offset + limit) < metaTotal : false;

        return _ObjectPageResult(unique, hasNext, safeTotal, offset, limit);
      }
    } catch (_) {
      return _ObjectPageResult(<Map<String, dynamic>>[], false, 0, offset, limit);
    }
  }

  TextStyle valueTextStyleForObjectField(String field, String value) {
    switch (field) {
      case 'source_kind':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32));
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
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 241, 151, 33));
      case 'object_id':
      case 'detected_object_id':
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF37474F));
      default:
        return const TextStyle(fontSize: 12, color: Color(0xFF212121));
    }
  }

  Widget buildObjectCountPanel(int count) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200, maxHeight: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFE082), width: 1),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x22FFC107),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    Icon(
                      Icons.visibility_rounded,
                      size: 18,
                      color: Color(0xFF7C3AED),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Detected objects',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFB300),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget objectCard({required int index, required Map<String, dynamic> obj, required List<String> fields}) {
    const Color purple = Color(0xFF7C3AED);
    final String headerText = 'Object ${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D7FF), width: 1),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x1A7C3AED), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: <Widget>[
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF6F0FF),
                border: Border(left: BorderSide(color: purple, width: 6)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                      width: 10, height: 10, decoration: const BoxDecoration(color: purple, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text(
                    headerText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: purple),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                children: fields.map((String field) {
                  final String value = formatCellValue(obj[field]);
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF757575)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(value.isEmpty ? '-' : value, style: valueTextStyleForObjectField(field, value)),
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

  Widget buildObjectsTablePanel(List<Map<String, dynamic>> objectRows) {
    if (objectRows.isEmpty) {
      return const Center(
        child: Text('No objects for this message', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
      );
    }
    final List<String> fields = mergeFields(objectRows.first.keys.toList(), getPreferredObjectGridColumns());
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: ListView.builder(
        itemCount: objectRows.length,
        itemBuilder: (BuildContext context, int index) {
          return objectCard(index: index, obj: objectRows[index], fields: fields);
        },
      ),
    );
  }

  Widget buildRowSummaryCard(Map<String, dynamic> row) {
    final bool isInfra = currentEntityType == FmsEntityType.infra;
    final String messageIdText = isInfra
        ? formatCellValue(row['infra_info_id'] ?? row['id'] ?? row['history_id'])
        : formatCellValue(row['vehicle_info_id'] ?? row['id'] ?? row['vehicle_info_id']);
    final String primaryLabel = isInfra ? 'Infra ID' : 'Vehicle ID';
    final String primaryValue = isInfra ? formatCellValue(row['infra_id']) : formatCellValue(row['vehicle_id']);
    final String timeStampValue =
        formatCellValue(row['time_stamp'] ?? row['time_stamp_ms'] ?? row['created_ts'] ?? row['created_at']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7D7FF), width: 1),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x147C3AED), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Message ID',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E))),
              const SizedBox(height: 6),
              Text(messageIdText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
            ],
          ),
          const SizedBox(width: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(primaryLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E))),
              const SizedBox(height: 6),
              Text(
                primaryValue.isEmpty ? '-' : primaryValue,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF424242)),
              ),
            ],
          ),
          const SizedBox(width: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Timestamp',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9E9E9E))),
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

  Widget buildRowDetailTable(Map<String, dynamic> row) {
    final List<String> columns = mergeFields(row.keys.toList(), cachedFields);

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
          final String value = formatCellValue(row[name]);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 160,
                child: Text(name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF616161))),
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
        separatorBuilder: (BuildContext context, int index) => const Divider(height: 16, color: Color(0xFFE0E0E0)),
      ),
    );
  }

  Future<void> openRowDetails(Map<String, dynamic> row) async {
    final String titleText = currentEntityType == FmsEntityType.vehicle ? 'Vehicle message' : 'Infra message';
    const int objectLimit = 200;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final Size size = MediaQuery.of(context).size;
        bool started = false;
        bool objectsLoading = true;

        _ObjectPageResult objectPage = const _ObjectPageResult(<Map<String, dynamic>>[], false, 0, 0, objectLimit);

        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            Future<void> startLoadIfNeeded() async {
              if (started) return;
              started = true;
              final _ObjectPageResult first = await loadObjectsPageForRow(row, 0, objectLimit);
              setDialogState(() {
                objectPage = first;
                objectsLoading = false;
              });
            }

            startLoadIfNeeded();

            final int expectedCount = parseInt(row['number_of_objects']);
            final int totalObjects = expectedCount > 0 ? expectedCount : objectPage.rows.length;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Row(
                children: <Widget>[
                  SvgPicture.asset('assets/images/ivis.svg', height: 28),
                  const SizedBox(width: 12),
                  Text(titleText,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
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
                          buildRowSummaryCard(row),
                          const SizedBox(height: 16),
                          Expanded(child: buildRowDetailTable(row)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: <Widget>[
                          buildObjectCountPanel(totalObjects),
                          const SizedBox(height: 12),
                          Expanded(
                            child: objectsLoading
                                ? const Center(
                                    child: Text('Loading objects...',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                                  )
                                : buildObjectsTablePanel(objectPage.rows),
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

  Widget buildPlutoGrid(double availableHeight) {
    const double columnHeight = 44;
    const double scrollbarThickness = 12;
    const double verticalBorders = 2;
    final double bodyHeight = availableHeight - columnHeight - scrollbarThickness - verticalBorders;

    final double rowHeight = (bodyHeight / rowsPerPage).floorToDouble().clamp(22, 60);

    final PlutoGrid grid = PlutoGrid(
      key: ValueKey<String>('dashboard_grid_${currentEntityType.name}'),
      columns: List<PlutoColumn>.from(cachedColumns, growable: true),
      rows: <PlutoRow>[],
      onLoaded: (PlutoGridOnLoadedEvent event) {
        gridStateManager = event.stateManager;
        gridReady = true;
        try {
          event.stateManager.setSelectingMode(PlutoGridSelectingMode.row);
          event.stateManager.setShowLoading(isLoading && !firstDataArrived);
        } catch (_) {}
        if (mounted) {
          setState(() {});
        }
        updateGrid();
      },
      onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) async {
        final int index = event.rowIdx;
        if (index < 0 || index >= pageRows.length) return;
        await openRowDetails(pageRows[index]);
      },
      configuration: PlutoGridConfiguration(
        scrollbar: const PlutoGridScrollbarConfig(
          isAlwaysShown: false,
          scrollbarThickness: scrollbarThickness,
        ),
        style: PlutoGridStyleConfig(
          rowHeight: rowHeight,
          columnHeight: columnHeight,
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
          buildToolbar(),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double availableHeight = constraints.maxHeight;
                  return buildPlutoGrid(availableHeight);
                },
              ),
            ),
          ),
          buildPaginationBar(),
        ],
      ),
    );
  }
}
