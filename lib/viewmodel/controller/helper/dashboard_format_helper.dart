// dashboard_format_helper.dart
// Dashboard 표시용 포맷 헬퍼: 정수/셀 값 파싱, 객체 타입 라벨/아이콘 매핑

import 'package:flutter/material.dart';

import '../../../i18n/app_locale.dart';

class ObjectTypeUi {
  final String label;
  final IconData iconData;
  const ObjectTypeUi({required this.label, required this.iconData});
}

class DashboardFormatHelper {
  const DashboardFormatHelper._();

  // 임의 값을 int로 안전 변환 (null/실패 시 0)
  static int parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  /// Device number (vehicle_id / infra_id, spec uint8 0–255; 0 is a real device).
  /// null when the value is missing or not a valid device number — never 0 by default.
  static int? deviceIdOrNull(dynamic value) {
    if (value == null) return null;
    final int? id = value is int
        ? value
        : (value is num ? (value == value.roundToDouble() ? value.toInt() : null) : int.tryParse(value.toString().trim()));
    return (id != null && id >= 0 && id <= 255) ? id : null;
  }

  // 임의 값을 int로 변환하되 실패 시 지정 fallback 반환
  static int parseIntOrFallback(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  // 셀 표시값 정규화 (날짜 문자열은 'YYYY-MM-DD HH:MM:SS'로)
  static String formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    if (value is String) return formatDateTimeString(value);
    return value.toString();
  }

  // "2026-03-17T12:34:56.123456" → "2026-03-17 12:34:56" 형태로 정규화
  static String formatDateTimeString(String value) {
    final String trimmed = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}').hasMatch(trimmed)) {
      return trimmed;
    }
    return trimmed
        .replaceFirst('T', ' ')
        .replaceFirst(RegExp(r'\.\d+'), '')
        .replaceFirst('Z', '')
        .trim();
  }

  // 객체 타입(0~5) → 라벨 + 아이콘
  static ObjectTypeUi objectTypeUi(int? objectType) {
    final int value = objectType ?? -1;
    if (value == 0) {
      return ObjectTypeUi(label: t('미확인'), iconData: Icons.help_outline);
    }
    if (value == 1) {
      return ObjectTypeUi(label: t('승용차'), iconData: Icons.directions_car_filled);
    }
    if (value == 2) {
      return ObjectTypeUi(label: t('트럭'), iconData: Icons.local_shipping);
    }
    if (value == 3) {
      return ObjectTypeUi(label: t('버스'), iconData: Icons.directions_bus_filled);
    }
    if (value == 4) {
      return ObjectTypeUi(label: t('보행자'), iconData: Icons.directions_walk);
    }
    if (value == 5) {
      return ObjectTypeUi(label: t('이륜차'), iconData: Icons.two_wheeler);
    }
    return ObjectTypeUi(label: t('미확인'), iconData: Icons.question_mark);
  }

  // Object type (0-5) name via t(): Korean by default, English in English mode
  static String getObjectTypeNameKorean(int? type) {
    switch (type) {
      case 0:
        return t('미확인');
      case 1:
        return t('승용차');
      case 2:
        return t('트럭');
      case 3:
        return t('버스');
      case 4:
        return t('보행자');
      case 5:
        return t('이륜차');
      default:
        return t('미확인');
    }
  }
}
