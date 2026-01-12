import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:ivis/model/infra_model.dart';
import 'package:ivis/model/object_model.dart';

class RobotStatusGrid extends StatefulWidget {
  final List<Message?> data;
  final bool isVehicleScope;
  final ValueChanged<int?> onSelect;

  const RobotStatusGrid({
    super.key,
    required this.data,
    required this.isVehicleScope,
    required this.onSelect,
  });

  @override
  State<RobotStatusGrid> createState() => _RobotStatusGridState();
}

class _RobotStatusGridState extends State<RobotStatusGrid> {
  static const Color primaryBlue = Color(0xFF005FB8);
  static const Color gridBorder = Color(0xFFE6EEF5);

  late final List<PlutoColumn> vehicleColumns;
  late final List<PlutoColumn> infraColumns;

  late Set<String> visibleVehicleFields;
  late Set<String> visibleInfraFields;

  PlutoGridStateManager? stateManager;
  int? selectedRowId;

  @override
  void initState() {
    super.initState();
    vehicleColumns = _buildVehicleColumns();
    infraColumns = _buildInfraColumns();
    visibleVehicleFields = vehicleColumns.map((PlutoColumn column) => column.field).toSet();
    visibleInfraFields = infraColumns.map((PlutoColumn column) => column.field).toSet();
  }

  List<PlutoColumn> _buildVehicleColumns() {
    return <PlutoColumn>[
      _numberColumn('id', 'Row ID', width: 90),
      _numberColumn('vehicleId', 'Vehicle ID', width: 110),
      _textColumn('timeStampIso8601', 'Timestamp', width: 210),
      _numberColumn('positionXMeters', 'Pos X (m)'),
      _numberColumn('positionYMeters', 'Pos Y (m)'),
      _numberColumn('positionZMeters', 'Pos Z (m)'),
      _numberColumn('headingDegrees', 'Heading (deg)'),
      _numberColumn('speedMetersPerSecond', 'Speed (m/s)'),
      _numberColumn('speedKilometersPerHour', 'Speed (km/h)'),
      _numberColumn('accelerationXMps2', 'Accel X'),
      _numberColumn('accelerationYMps2', 'Accel Y'),
      _numberColumn('accelerationZMps2', 'Accel Z'),
      _numberColumn('gyroXDps', 'Gyro X'),
      _numberColumn('gyroYDps', 'Gyro Y'),
      _numberColumn('gyroZDps', 'Gyro Z'),
      _numberColumn('transmissionGear', 'Gear'),
      _numberColumn('signalLight', 'Signal'),
      _numberColumn('steeringAngleDegrees', 'Steer Angle'),
      _numberColumn('steeringTorqueNewtonMeters', 'Steer Torque'),
      _numberColumn('acceleratorPedalPercent', 'Accel %'),
      _numberColumn('brakePedalPercent', 'Brake %'),
      _numberColumn('numberOfObjects', '#Objects'),
    ];
  }

  List<PlutoColumn> _buildInfraColumns() {
    return <PlutoColumn>[
      _numberColumn('id', 'Row ID', width: 90),
      _numberColumn('infraId', 'Infra ID', width: 110),
      _textColumn('timeStampIso8601', 'Timestamp', width: 210),
      _numberColumn('positionXMeters', 'Pos X (m)'),
      _numberColumn('positionYMeters', 'Pos Y (m)'),
      _numberColumn('positionZMeters', 'Pos Z (m)'),
      _numberColumn('headingDegrees', 'Heading (deg)'),
      _numberColumn('speedMetersPerSecond', 'Speed (m/s)'),
      _numberColumn('speedKilometersPerHour', 'Speed (km/h)'),
      _numberColumn('accelerationXMps2', 'Accel X'),
      _numberColumn('accelerationYMps2', 'Accel Y'),
      _numberColumn('accelerationZMps2', 'Accel Z'),
      _numberColumn('gyroXDps', 'Gyro X'),
      _numberColumn('gyroYDps', 'Gyro Y'),
      _numberColumn('gyroZDps', 'Gyro Z'),
      _numberColumn('numberOfObjects', '#Objects'),
    ];
  }

  List<PlutoRow> _buildVehicleRows() {
    return widget.data.map((Message? message) {
      final Message? m = message;
      return PlutoRow(
        cells: <String, PlutoCell>{
          'id': PlutoCell(value: m?.id),
          'vehicleId': PlutoCell(value: m?.vehicleId),
          'timeStampIso8601': PlutoCell(value: m?.timeStampIso8601 ?? ''),
          'positionXMeters': PlutoCell(value: m?.positionXMeters),
          'positionYMeters': PlutoCell(value: m?.positionYMeters),
          'positionZMeters': PlutoCell(value: m?.positionZMeters),
          'headingDegrees': PlutoCell(value: m?.headingDegrees),
          'speedMetersPerSecond': PlutoCell(value: m?.speedMetersPerSecond),
          'speedKilometersPerHour': PlutoCell(value: m?.speedKilometersPerHour),
          'accelerationXMps2': PlutoCell(value: m?.accelerationXMps2),
          'accelerationYMps2': PlutoCell(value: m?.accelerationYMps2),
          'accelerationZMps2': PlutoCell(value: m?.accelerationZMps2),
          'gyroXDps': PlutoCell(value: m?.gyroXDps),
          'gyroYDps': PlutoCell(value: m?.gyroYDps),
          'gyroZDps': PlutoCell(value: m?.gyroZDps),
          'transmissionGear': PlutoCell(value: m?.transmissionGear),
          'signalLight': PlutoCell(value: m?.signalLight),
          'steeringAngleDegrees': PlutoCell(value: m?.steeringAngleDegrees),
          'steeringTorqueNewtonMeters': PlutoCell(value: m?.steeringTorqueNewtonMeters),
          'acceleratorPedalPercent': PlutoCell(value: m?.acceleratorPedalPercent),
          'brakePedalPercent': PlutoCell(value: m?.brakePedalPercent),
          'numberOfObjects': PlutoCell(value: m?.numberOfObjects),
        },
      );
    }).toList();
  }

  List<PlutoRow> _buildInfraRows() {
    return widget.data.map((Message? message) {
      final Message? m = message;
      return PlutoRow(
        cells: <String, PlutoCell>{
          'id': PlutoCell(value: m?.id),
          'infraId': PlutoCell(value: m?.infraId),
          'timeStampIso8601': PlutoCell(value: m?.timeStampIso8601 ?? ''),
          'positionXMeters': PlutoCell(value: m?.positionXMeters),
          'positionYMeters': PlutoCell(value: m?.positionYMeters),
          'positionZMeters': PlutoCell(value: m?.positionZMeters),
          'headingDegrees': PlutoCell(value: m?.headingDegrees),
          'speedMetersPerSecond': PlutoCell(value: m?.speedMetersPerSecond),
          'speedKilometersPerHour': PlutoCell(value: m?.speedKilometersPerHour),
          'accelerationXMps2': PlutoCell(value: m?.accelerationXMps2),
          'accelerationYMps2': PlutoCell(value: m?.accelerationYMps2),
          'accelerationZMps2': PlutoCell(value: m?.accelerationZMps2),
          'gyroXDps': PlutoCell(value: m?.gyroXDps),
          'gyroYDps': PlutoCell(value: m?.gyroYDps),
          'gyroZDps': PlutoCell(value: m?.gyroZDps),
          'numberOfObjects': PlutoCell(value: m?.numberOfObjects),
        },
      );
    }).toList();
  }

  PlutoColumn _textColumn(String field, String title, {double width = 120}) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.text(),
      width: width,
      minWidth: width,
      enableColumnDrag: false,
      enableDropToResize: true,
      readOnly: true,
    );
  }

  PlutoColumn _numberColumn(String field, String title, {double width = 110}) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.number(),
      width: width,
      minWidth: width,
      enableColumnDrag: false,
      enableDropToResize: true,
      readOnly: true,
    );
  }

  Future<void> _openColumnSelector() async {
    final bool vehicleScope = widget.isVehicleScope;
    final List<PlutoColumn> allColumns = vehicleScope ? vehicleColumns : infraColumns;
    final Set<String> currentVisibleFields = Set<String>.from(
      vehicleScope ? visibleVehicleFields : visibleInfraFields,
    );

    final Set<String>? result = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        Set<String> tempVisible = Set<String>.from(currentVisibleFields);

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Select columns',
            style: TextStyle(
              fontFamily: 'pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: StatefulBuilder(
              builder: (BuildContext context, void Function(void Function()) setStateDialog) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: allColumns.map((PlutoColumn column) {
                      final bool isChecked = tempVisible.contains(column.field);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: primaryBlue,
                        checkColor: Colors.white,
                        value: isChecked,
                        onChanged: (bool? value) {
                          setStateDialog(() {
                            if (value == true) {
                              tempVisible.add(column.field);
                            } else {
                              if (tempVisible.length > 1) {
                                tempVisible.remove(column.field);
                              }
                            }
                          });
                        },
                        title: Text(
                          column.title,
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(tempVisible);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (vehicleScope) {
          visibleVehicleFields = result;
        } else {
          visibleInfraFields = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool vehicleScope = widget.isVehicleScope;
    final Set<String> visibleFields = vehicleScope ? visibleVehicleFields : visibleInfraFields;
    final List<PlutoColumn> baseColumns = vehicleScope ? vehicleColumns : infraColumns;
    final List<PlutoColumn> columns =
        baseColumns.where((PlutoColumn column) => visibleFields.contains(column.field)).toList();
    final List<PlutoRow> rows = vehicleScope ? _buildVehicleRows() : _buildInfraRows();

    return Column(
      children: <Widget>[
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: <Widget>[
              Text(
                vehicleScope ? 'Vehicle messages' : 'Infra messages',
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: selectedRowId == null ? null : () => widget.onSelect(selectedRowId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.bubble_chart, size: 18),
                label: const Text(
                  'Detected objects',
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _openColumnSelector,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.view_column, size: 18),
                label: const Text(
                  'Columns',
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PlutoGrid(
            key: ValueKey<String>(
              '${vehicleScope ? 'vehicle' : 'infra'}-${visibleFields.join(',')}',
            ),
            columns: columns,
            rows: rows,
            onLoaded: (PlutoGridOnLoadedEvent event) {
              stateManager = event.stateManager;
              stateManager!.setShowColumnFilter(true);
            },
            onSelected: (PlutoGridOnSelectedEvent event) {
              final int? rowIndex = event.rowIdx;
              if (rowIndex == null || rowIndex < 0 || rowIndex >= widget.data.length) {
                setState(() {
                  selectedRowId = null;
                });
                widget.onSelect(null);
                return;
              }
              final Message? selected = widget.data[rowIndex];
              setState(() {
                selectedRowId = selected?.id;
              });
              widget.onSelect(selectedRowId);
            },
            configuration: PlutoGridConfiguration(
              columnSize: const PlutoGridColumnSizeConfig(
                autoSizeMode: PlutoAutoSizeMode.scale,
                resizeMode: PlutoResizeMode.pushAndPull,
              ),
              style: PlutoGridStyleConfig(
                gridBorderColor: gridBorder,
                gridBackgroundColor: const Color(0xFFF8FAFF),
                rowHeight: 40,
                columnHeight: 42,
                columnFilterHeight: 34,
                activatedBorderColor: primaryBlue,
                activatedColor: const Color(0xFFE4F0FF),
                gridBorderRadius: BorderRadius.circular(0),
                evenRowColor: Colors.white,
                oddRowColor: const Color(0xFFF2F5FB),
                cellTextStyle: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 13,
                  color: Color(0xFF111827),
                ),
                columnTextStyle: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
                iconColor: const Color(0xFF6B7280),
              ),
              columnFilter: PlutoGridColumnFilterConfig(
                resolveDefaultColumnFilter: (column, resolver) {
                  return resolver<PlutoFilterTypeContains>()!;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DetectedObjectGrid extends StatefulWidget {
  final List<DetectedObject> data;

  const DetectedObjectGrid({
    super.key,
    required this.data,
  });

  @override
  State<DetectedObjectGrid> createState() => _DetectedObjectGridState();
}

class _DetectedObjectGridState extends State<DetectedObjectGrid> {
  static const Color primaryBlue = Color(0xFF005FB8);
  static const Color gridBorder = Color(0xFFE6EEF5);

  late final List<PlutoColumn> columns;
  PlutoGridStateManager? stateManager;

  @override
  void initState() {
    super.initState();
    columns = _buildColumns();
  }

  List<PlutoColumn> _buildColumns() {
    return <PlutoColumn>[
      _numberColumn('detectedObjectId', 'ID', width: 80),
      _textColumn('sourceKind', 'Source', width: 80),
      _numberColumn('vehicleInfoId', 'Vehicle Row ID', width: 120),
      _numberColumn('infraInfoId', 'Infra Row ID', width: 120),
      _numberColumn('objectId', 'Object ID', width: 100),
      _numberColumn('score', 'Score', width: 90),
      _numberColumn('width', 'Width', width: 90),
      _numberColumn('depth', 'Depth', width: 90),
      _numberColumn('height', 'Height', width: 90),
      _numberColumn('positionX', 'Pos X', width: 100),
      _numberColumn('positionY', 'Pos Y', width: 100),
      _numberColumn('positionZ', 'Pos Z', width: 100),
      _numberColumn('linearVelocityX', 'Vel X', width: 100),
      _numberColumn('linearVelocityY', 'Vel Y', width: 100),
      _numberColumn('linearVelocityZ', 'Vel Z', width: 100),
      _numberColumn('rotationRateX', 'Rot X', width: 100),
      _numberColumn('rotationRateY', 'Rot Y', width: 100),
      _numberColumn('rotationRateZ', 'Rot Z', width: 100),
    ];
  }

  List<PlutoRow> _buildRows() {
    return widget.data.map((DetectedObject object) {
      return PlutoRow(
        cells: <String, PlutoCell>{
          'detectedObjectId': PlutoCell(value: object.detectedObjectId),
          'sourceKind': PlutoCell(value: object.sourceKind ?? ''),
          'vehicleInfoId': PlutoCell(value: object.vehicleInfoId),
          'infraInfoId': PlutoCell(value: object.infraInfoId),
          'objectId': PlutoCell(value: object.objectId),
          'score': PlutoCell(value: object.score),
          'width': PlutoCell(value: object.width),
          'depth': PlutoCell(value: object.depth),
          'height': PlutoCell(value: object.height),
          'positionX': PlutoCell(value: object.positionX),
          'positionY': PlutoCell(value: object.positionY),
          'positionZ': PlutoCell(value: object.positionZ),
          'linearVelocityX': PlutoCell(value: object.linearVelocityX),
          'linearVelocityY': PlutoCell(value: object.linearVelocityY),
          'linearVelocityZ': PlutoCell(value: object.linearVelocityZ),
          'rotationRateX': PlutoCell(value: object.rotationRateX),
          'rotationRateY': PlutoCell(value: object.rotationRateY),
          'rotationRateZ': PlutoCell(value: object.rotationRateZ),
        },
      );
    }).toList();
  }

  PlutoColumn _textColumn(String field, String title, {double width = 120}) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.text(),
      width: width,
      minWidth: width,
      enableColumnDrag: false,
      enableDropToResize: true,
      readOnly: true,
    );
  }

  PlutoColumn _numberColumn(String field, String title, {double width = 110}) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.number(),
      width: width,
      minWidth: width,
      enableColumnDrag: false,
      enableDropToResize: true,
      readOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PlutoRow> rows = _buildRows();

    return Column(
      children: <Widget>[
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.white,
          child: const Text(
            'Detected objects',
            style: TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: PlutoGrid(
            columns: columns,
            rows: rows,
            onLoaded: (PlutoGridOnLoadedEvent event) {
              stateManager = event.stateManager;
              stateManager!.setShowColumnFilter(true);
            },
            configuration: PlutoGridConfiguration(
              columnSize: const PlutoGridColumnSizeConfig(
                autoSizeMode: PlutoAutoSizeMode.scale,
                resizeMode: PlutoResizeMode.pushAndPull,
              ),
              style: PlutoGridStyleConfig(
                gridBorderColor: gridBorder,
                gridBackgroundColor: const Color(0xFFF8FAFF),
                rowHeight: 38,
                columnHeight: 40,
                columnFilterHeight: 32,
                activatedBorderColor: primaryBlue,
                activatedColor: const Color(0xFFE4F0FF),
                gridBorderRadius: BorderRadius.circular(0),
                evenRowColor: Colors.white,
                oddRowColor: const Color(0xFFF2F5FB),
                cellTextStyle: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 13,
                  color: Color(0xFF111827),
                ),
                columnTextStyle: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
                iconColor: const Color(0xFF6B7280),
              ),
              columnFilter: PlutoGridColumnFilterConfig(
                resolveDefaultColumnFilter: (column, resolver) {
                  return resolver<PlutoFilterTypeContains>()!;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
