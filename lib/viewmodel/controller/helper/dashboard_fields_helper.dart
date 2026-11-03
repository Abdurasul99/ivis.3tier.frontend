// dashboard_fields_helper.dart
// Dashboard 컬럼/필드 정의 + 행 데이터 날짜 분리 파생 필드 유틸

import '../dashboard_controller.dart' show FmsEntityType;

class DashboardFieldsHelper {
  const DashboardFieldsHelper._();

  // 엔티티별(차량/인프라) 전체 컬럼 목록
  static List<String> getFieldsForEntity(FmsEntityType type) {
    if (type == FmsEntityType.vehicle) {
      return <String>[
        'history_id',
        'vehicle_id',
        'msg_id',
        'msg_seq',
        'msg_length',
        'changed_at_date',
        'changed_at_time',
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
        'created_ts_date',
        'created_ts_time',
        'updated_ts_date',
        'updated_ts_time',
      ];
    }
    return <String>[
      'history_id',
      'infra_id',
      'msg_id',
      'msg_seq',
      'msg_length',
      'changed_at_date',
      'changed_at_time',
      'time_stamp_ms',
      'number_of_objects',
      'created_ts_date',
      'created_ts_time',
      'updated_ts_date',
      'updated_ts_time',
    ];
  }

  // 감지 객체 테이블 컬럼 목록
  static List<String> getObjectFields() {
    return <String>[
      'detected_object_id',
      'source_kind',
      'vehicle_id',
      'infra_id',
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

  // "2026-03-17T12:34:56.123" → {'date': '2026-03-17', 'time': '12:34:56'}
  static Map<String, String> splitDateTimeValue(dynamic value) {
    if (value == null) return <String, String>{'date': '', 'time': ''};
    final String raw = value.toString().trim();
    final RegExpMatch? match = RegExp(
      r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})',
    ).firstMatch(raw);
    if (match == null) return <String, String>{'date': raw, 'time': ''};
    return <String, String>{'date': match.group(1)!, 'time': match.group(2)!};
  }

  // 행 데이터에 changed_at/created_ts/updated_ts 의 _date/_time 파생 필드 추가
  static Map<String, dynamic> enrichRowDateTimeFields(
      Map<String, dynamic> row) {
    final Map<String, dynamic> enriched = Map<String, dynamic>.from(row);
    for (final String field in <String>[
      'changed_at',
      'created_ts',
      'updated_ts'
    ]) {
      if (enriched.containsKey(field)) {
        final Map<String, String> parts = splitDateTimeValue(enriched[field]);
        enriched['${field}_date'] = parts['date'];
        enriched['${field}_time'] = parts['time'];
      }
    }
    return enriched;
  }
}
