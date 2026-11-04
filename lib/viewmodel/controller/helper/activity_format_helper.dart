// activity_format_helper.dart
// ActivityController용 순수 유틸: KST 시간 변환, 문자열 정리, 레지스트리 라벨 추출

import '../../../i18n/app_locale.dart';

class ActivityFormatHelper {
  const ActivityFormatHelper._();

  static const Duration kstOffset = Duration(hours: 9);

  // null/공백/'-'/'null' 문자열은 빈 문자열로 정규화
  static String cleanString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text == '-' || text.toLowerCase() == 'null') return '';
    return text;
  }

  // 임의 값을 int? 로 안전 변환
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  // 임의 값을 double? 로 안전 변환
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // 이벤트 시각으로부터 상대 시간 라벨 ("방금 전", "3분 전", "3m ago" 등)
  static String relativeTimeFromMs(int ms) {
    final DateTime eventTime =
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    final Duration diff = DateTime.now().difference(eventTime);

    if (diff.inSeconds < 10) return l10n('방금 전', 'Just now');
    if (diff.inSeconds < 60) {
      return l10n('${diff.inSeconds}초 전', '${diff.inSeconds}s ago');
    }
    if (diff.inMinutes < 60) {
      return l10n('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
    }
    if (diff.inHours < 24) {
      return l10n('${diff.inHours}시간 전', '${diff.inHours}h ago');
    }
    return l10n('${diff.inDays}일 전', '${diff.inDays}d ago');
  }

  // KST 자정의 epoch ms (UTC 자정 - KST 오프셋)
  static int kstMidnightEpochMs(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day)
            .millisecondsSinceEpoch -
        kstOffset.inMilliseconds;
  }

  static DateTime nowKst() {
    return DateTime.now().toUtc().add(kstOffset);
  }

  static String todayKstStr() {
    return formatDate(nowKst());
  }

  // "2026-03-17" 포맷
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 이번 달 KST 시작/끝 epoch ms
  static ({int fromMs, int toMs}) currentMonthKstWindow() => monthKstWindow(nowKst());

  // First day of the current KST month (year/month only).
  static DateTime currentMonthStartKst() {
    final DateTime now = nowKst();
    return DateTime(now.year, now.month);
  }

  // KST start/end epoch ms of the month that contains [month].
  static ({int fromMs, int toMs}) monthKstWindow(DateTime month) {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime nextMonth = DateTime(month.year, month.month + 1, 1);
    return (
      fromMs: kstMidnightEpochMs(start),
      toMs: kstMidnightEpochMs(nextMonth) - 1,
    );
  }

  // 특정 날짜의 KST 자정~다음날 자정 직전 epoch ms
  static ({int fromMs, int toMs}) kstDayWindow(DateTime date) {
    final DateTime start = DateTime(date.year, date.month, date.day);
    final DateTime nextDay = start.add(const Duration(days: 1));
    return (
      fromMs: kstMidnightEpochMs(start),
      toMs: kstMidnightEpochMs(nextDay) - 1,
    );
  }

  // 디바이스 레지스트리에서 (device_type, device_id) 행 찾기
  static Map<String, dynamic>? registryEntry(
    List<Map<String, dynamic>> registryRows,
    String? deviceType,
    int? deviceId,
  ) {
    if (deviceType == null || deviceId == null) return null;
    for (final Map<String, dynamic> row in registryRows) {
      final String rowType = row['device_type']?.toString() ?? '';
      final int? rowId = parseInt(row['device_id']);
      if (rowType == deviceType && rowId == deviceId) {
        return row;
      }
    }
    return null;
  }

  // 레지스트리에서 위치 라벨 추출 (location_address > home_station > '')
  static String registryLocationLabel(
    List<Map<String, dynamic>> registryRows,
    String? deviceType,
    int? deviceId,
  ) {
    final Map<String, dynamic>? reg =
        registryEntry(registryRows, deviceType, deviceId);
    final String locationAddress = cleanString(reg?['location_address']);
    final String homeStation = cleanString(reg?['home_station']);
    if (locationAddress.isNotEmpty) return locationAddress;
    if (homeStation.isNotEmpty) return homeStation;
    return '';
  }
}
