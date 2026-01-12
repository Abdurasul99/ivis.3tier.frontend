import 'package:flutter/material.dart';

String _formatCellValue(dynamic value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  if (value is String) return value;
  return value.toString();
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _getPreferredVehicleColumns() {
  return <String>[
    'id',
    'msg_seq',
    'msg_length',
    'time_stamp_ms',
    'time_stamp',
    'vehicle_id',
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
    'created_at',
    'updated_at',
  ];
}

List<String> _getPreferredInfraColumns() {
  return <String>[
    'history_id',
    'infra_info_id',
    'changed_at',
    'msg_seq',
    'msg_length',
    'time_stamp_ms',
    'time_stamp',
    'infra_id',
    'number_of_objects',
    'created_at',
    'updated_at',
  ];
}

List<String> _getPreferredObjectColumns() {
  return <String>[
    'detected_object_id',
    'source_kind',
    'vehicle_info_id',
    'infra_info_id',
    'object_id',
    'age',
    'score',
    'number_of_objects',
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
    'msg_seq',
    'msg_length',
    'time_stamp_ms',
    'time_stamp',
    'changed_at',
    'history_id',
  ];
}

List<String> _buildColumnsFromRow(
  Map<String, dynamic> row,
  List<String> preferred,
) {
  final List<String> result = <String>[];
  final Set<String> keys = row.keys.toSet();

  for (final String name in preferred) {
    if (keys.contains(name)) {
      result.add(name);
    }
  }

  for (final String name in keys) {
    if (!result.contains(name)) {
      result.add(name);
    }
  }

  return result;
}

int _getObjectCountFromRow(Map<String, dynamic> row) {
  if (row.containsKey('number_of_objects')) {
    return _parseInt(row['number_of_objects']);
  }
  return 0;
}

Widget _buildObjectCountPanel(Map<String, dynamic> row) {
  final int count = _getObjectCountFromRow(row);
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 260,
        maxHeight: 180,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Detected objects',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildRowSummaryCard(String entityType, Map<String, dynamic> row) {
  String idText;
  String primaryLabel;
  String primaryValue;

  if (entityType == 'infra') {
    idText = _formatCellValue(row['history_id']);
    primaryLabel = 'Infra info ID';
    primaryValue = _formatCellValue(row['infra_info_id']);
  } else if (entityType == 'vehicle') {
    idText = _formatCellValue(row['id']);
    primaryLabel = 'Vehicle ID';
    primaryValue = _formatCellValue(row['vehicle_id']);
  } else {
    idText = _formatCellValue(row['detected_object_id'] ?? row['object_id']);
    primaryLabel = 'Object ID';
    primaryValue = _formatCellValue(row['object_id']);
  }

  final String ts = _formatCellValue(
    row['time_stamp_ms'] ?? row['time_stamp'] ?? row['created_at'] ?? row['created_ts'],
  );

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Row(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Message ID',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              idText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
            ),
          ],
        ),
        const SizedBox(width: 32),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              primaryLabel,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              primaryValue.isEmpty ? '-' : primaryValue,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF424242),
              ),
            ),
          ],
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Timestamp',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ts.isEmpty ? '-' : ts,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildRowDetailTable(String entityType, Map<String, dynamic> row) {
  List<String> columns;
  if (entityType == 'vehicle') {
    final List<String> preferred = _getPreferredVehicleColumns();
    columns = <String>[];
    for (final String name in preferred) {
      if (row.containsKey(name)) {
        columns.add(name);
      }
    }
  } else if (entityType == 'infra') {
    final List<String> preferred = _getPreferredInfraColumns();
    columns = <String>[];
    for (final String name in preferred) {
      if (row.containsKey(name)) {
        columns.add(name);
      }
    }
  } else {
    columns = _buildColumnsFromRow(row, _getPreferredObjectColumns());
  }

  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF9F9F9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Scrollbar(
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
                width: 140,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF616161),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
            ],
          );
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(
            height: 16,
            color: Color(0xFFE0E0E0),
          );
        },
      ),
    ),
  );
}

Future<void> showDataViewDialog(
  BuildContext context,
  String entityType,
  Map<String, dynamic> row,
) async {
  String titleText = 'Message';
  if (entityType == 'vehicle') {
    titleText = 'Vehicle message';
  } else if (entityType == 'infra') {
    titleText = 'Infra message';
  } else {
    titleText = 'Detected object';
  }

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final Size size = MediaQuery.of(context).size;

      Widget contentChild;
      if (entityType == 'detectedObject') {
        contentChild = Column(
          children: <Widget>[
            _buildRowSummaryCard(entityType, row),
            const SizedBox(height: 16),
            Expanded(
              child: _buildRowDetailTable(entityType, row),
            ),
          ],
        );
      } else {
        contentChild = Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Column(
                children: <Widget>[
                  _buildRowSummaryCard(entityType, row),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildRowDetailTable(entityType, row),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: _buildObjectCountPanel(row),
            ),
          ],
        );
      }

      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: <Widget>[
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
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: size.width * 0.6,
          height: size.height * 0.55,
          child: contentChild,
        ),
      );
    },
  );
}
