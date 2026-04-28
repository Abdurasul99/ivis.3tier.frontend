part of 'tab_activity.dart';

// ─────────────────────────────────────────────
// 공통 패널 위젯 (charts + calendar 양쪽에서 사용)
// ─────────────────────────────────────────────

Widget _panel({
  required String title,
  required String subtitle,
  required bool loading,
  required Widget child,
}) {
  return Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 8)),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title,
                style: const TextStyle(
                    fontFamily: 'gm-medium',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _text)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontFamily: 'pretendard', fontSize: 12, color: _muted)),
          ]),
        ),
        if (loading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
      ]),
      const SizedBox(height: 18),
      child,
    ]),
  );
}

Widget _emptyPanel(String label) {
  return Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.insights_rounded, color: _primary),
      ),
      const SizedBox(height: 12),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'pretendard', fontSize: 13, color: _muted)),
    ]),
  );
}

// ─────────────────────────────────────────────
// 이동거리 집계 데이터 포인트
// ─────────────────────────────────────────────

class _DistanceChartPoint {
  final String axisLabel;
  final String tooltipLabel;
  final double meters;

  const _DistanceChartPoint({
    required this.axisLabel,
    required this.tooltipLabel,
    required this.meters,
  });

  String get label => axisLabel;
  double get km => meters / 1000;
}

List<_DistanceChartPoint> _aggregateDistanceChartPoints(
  List<DailyDistancePoint> daily,
  String period,
) {
  if (daily.isEmpty) return <_DistanceChartPoint>[];

  final String normalized = _normalizeDistanceChartPeriod(period);
  if (normalized == 'daily') {
    return daily
        .map(
          (DailyDistancePoint d) => _DistanceChartPoint(
            axisLabel: _mmdd(d.dateKst),
            tooltipLabel: d.dateKst,
            meters: d.distanceM,
          ),
        )
        .toList();
  }

  final Map<String, double> meterMap = <String, double>{};
  final Map<String, String> axisLabelMap = <String, String>{};
  final Map<String, String> tooltipLabelMap = <String, String>{};

  for (final DailyDistancePoint d in daily) {
    final DateTime dt = DateTime.parse(d.dateKst);
    late final String key;
    late final String axisLabel;
    late final String tooltipLabel;

    if (normalized == 'weekly') {
      final DateTime monday = dt.subtract(Duration(days: dt.weekday - 1));
      key = _dateSortKey(monday);
      axisLabel = _mmdd(_yyyyMmDd(monday));
      tooltipLabel = _yyyyMmDd(monday);
    } else if (normalized == 'monthly') {
      key = '${dt.year}${dt.month.toString().padLeft(2, '0')}';
      axisLabel = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      tooltipLabel = axisLabel;
    } else {
      key = dt.year.toString();
      axisLabel = dt.year.toString();
      tooltipLabel = axisLabel;
    }

    meterMap[key] = (meterMap[key] ?? 0) + d.distanceM;
    axisLabelMap[key] = axisLabel;
    tooltipLabelMap[key] = tooltipLabel;
  }

  final List<String> sortedKeys = meterMap.keys.toList()..sort();
  return sortedKeys
      .map(
        (String key) => _DistanceChartPoint(
          axisLabel: axisLabelMap[key]!,
          tooltipLabel: tooltipLabelMap[key]!,
          meters: meterMap[key]!,
        ),
      )
      .toList();
}

String _normalizeDistanceChartPeriod(String period) {
  switch (period) {
    case 'day':
      return 'daily';
    case 'week':
      return 'weekly';
    case 'month':
      return 'monthly';
    case 'year':
      return 'yearly';
    case 'daily':
    case 'weekly':
    case 'monthly':
    case 'yearly':
      return period;
    default:
      return 'daily';
  }
}

String _dateSortKey(DateTime date) {
  return '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

String _yyyyMmDd(DateTime date) {
  return '${date.year}'
      '-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';
}

({String value, String unit}) _distanceDisplayParts(double meters) {
  if (meters >= 1000) {
    final double km = meters / 1000;
    final int digits = km >= 100
        ? 0
        : km >= 10
            ? 1
            : 2;
    return (value: km.toStringAsFixed(digits), unit: 'km');
  }

  return (value: meters.round().toString(), unit: 'm');
}

({String value, String unit}) _durationDisplayPartsV3(double seconds) {
  final double safeSeconds = seconds.isFinite ? math.max(0, seconds) : 0;
  if (safeSeconds >= 86400) {
    final double days = safeSeconds / 86400;
    return (
      value: days.toStringAsFixed(days >= 10 ? 0 : 1),
      unit: 'd',
    );
  }
  if (safeSeconds >= 3600) {
    final double hours = safeSeconds / 3600;
    return (
      value: hours.toStringAsFixed(hours >= 10 ? 0 : 1),
      unit: 'h',
    );
  }
  if (safeSeconds >= 60) {
    return (
      value: (safeSeconds / 60).round().toString(),
      unit: 'm',
    );
  }
  return (value: safeSeconds.round().toString(), unit: 's');
}

String _formatDistanceMeters(double meters) {
  final ({String value, String unit}) parts = _distanceDisplayParts(meters);
  return '${parts.value} ${parts.unit}';
}

String _formatDurationCompact(double seconds) {
  final int safeSeconds = seconds.isFinite ? math.max(0, seconds).round() : 0;
  final int days = safeSeconds ~/ 86400;
  final int hours = (safeSeconds % 86400) ~/ 3600;
  final int minutes = (safeSeconds % 3600) ~/ 60;
  final int secs = safeSeconds % 60;

  if (days > 0) {
    return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  }
  if (hours > 0) {
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }
  if (minutes > 0) {
    return secs > 0 && minutes < 10 ? '${minutes}m ${secs}s' : '${minutes}m';
  }
  return '${secs}s';
}

class _VehicleMetricChartPointV3 {
  final String axisLabel;
  final String tooltipLabel;
  final double distanceM;
  final double operationSec;
  final double movingSec;

  const _VehicleMetricChartPointV3({
    required this.axisLabel,
    required this.tooltipLabel,
    required this.distanceM,
    required this.operationSec,
    required this.movingSec,
  });

  double get distanceKm => distanceM / 1000;
  double get operationHours => operationSec / 3600;
  double get movingHours => movingSec / 3600;
}

List<_VehicleMetricChartPointV3> _aggregateVehicleChartPointsV3(
  List<DailyDistancePoint> daily,
  String period,
) {
  if (daily.isEmpty) return <_VehicleMetricChartPointV3>[];

  final String normalized = _normalizeDistanceChartPeriod(period);
  if (normalized == 'daily') {
    return daily
        .map(
          (DailyDistancePoint d) => _VehicleMetricChartPointV3(
            axisLabel: _mmdd(d.dateKst),
            tooltipLabel: d.dateKst,
            distanceM: d.distanceM,
            operationSec: d.operationSec,
            movingSec: d.movingSec,
          ),
        )
        .toList();
  }

  final Map<String, double> distanceMap = <String, double>{};
  final Map<String, double> operationMap = <String, double>{};
  final Map<String, double> movingMap = <String, double>{};
  final Map<String, String> axisLabelMap = <String, String>{};
  final Map<String, String> tooltipLabelMap = <String, String>{};

  for (final DailyDistancePoint d in daily) {
    final DateTime dt = DateTime.parse(d.dateKst);
    late final String key;
    late final String axisLabel;
    late final String tooltipLabel;

    if (normalized == 'weekly') {
      final DateTime monday = dt.subtract(Duration(days: dt.weekday - 1));
      key = _dateSortKey(monday);
      axisLabel = _mmdd(_yyyyMmDd(monday));
      tooltipLabel = _yyyyMmDd(monday);
    } else if (normalized == 'monthly') {
      key = '${dt.year}${dt.month.toString().padLeft(2, '0')}';
      axisLabel = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      tooltipLabel = axisLabel;
    } else {
      key = dt.year.toString();
      axisLabel = dt.year.toString();
      tooltipLabel = axisLabel;
    }

    distanceMap[key] = (distanceMap[key] ?? 0) + d.distanceM;
    operationMap[key] = (operationMap[key] ?? 0) + d.operationSec;
    movingMap[key] = (movingMap[key] ?? 0) + d.movingSec;
    axisLabelMap[key] = axisLabel;
    tooltipLabelMap[key] = tooltipLabel;
  }

  final List<String> sortedKeys = distanceMap.keys.toList()..sort();
  return sortedKeys
      .map(
        (String key) => _VehicleMetricChartPointV3(
          axisLabel: axisLabelMap[key] ?? key,
          tooltipLabel: tooltipLabelMap[key] ?? key,
          distanceM: distanceMap[key] ?? 0,
          operationSec: operationMap[key] ?? 0,
          movingSec: movingMap[key] ?? 0,
        ),
      )
      .toList();
}

// 인프라 일별 감지 객체 데이터를 기간별로 집계
// raw: [{ 'date_kst': 'YYYY-MM-DD', 'total_objects': int }, ...]
// 반환: [(axisLabel, count), ...]
List<(String, int)> _aggregateInfraObjectPoints(
  List<Map<String, dynamic>> raw,
  String period,
) {
  if (raw.isEmpty) return <(String, int)>[];

  final String normalized = _normalizeDistanceChartPeriod(period);

  if (normalized == 'daily') {
    return raw.map((Map<String, dynamic> row) {
      final String date = row['date_kst'] as String? ?? '';
      final int count = (row['total_objects'] as num?)?.toInt() ?? 0;
      return (_mmdd(date), count);
    }).toList();
  }

  final Map<String, int> countMap = <String, int>{};
  final Map<String, String> labelMap = <String, String>{};

  for (final Map<String, dynamic> row in raw) {
    final String date = row['date_kst'] as String? ?? '';
    if (date.length < 10) continue;
    final int count = (row['total_objects'] as num?)?.toInt() ?? 0;

    late final String key;
    late final String label;

    if (normalized == 'weekly') {
      try {
        final DateTime dt = DateTime.parse(date);
        final DateTime monday = dt.subtract(Duration(days: dt.weekday - 1));
        key = _dateSortKey(monday);
        label = _mmdd(_yyyyMmDd(monday));
      } catch (_) {
        key = date.substring(0, 7);
        label = date.substring(0, 7);
      }
    } else if (normalized == 'monthly') {
      key = '${date.substring(0, 4)}${date.substring(5, 7)}';
      label = '${date.substring(0, 4)}-${date.substring(5, 7)}';
    } else {
      key = date.substring(0, 4);
      label = date.substring(0, 4);
    }

    countMap[key] = (countMap[key] ?? 0) + count;
    labelMap[key] = label;
  }

  final List<String> sortedKeys = countMap.keys.toList()..sort();
  return sortedKeys.map((String k) => (labelMap[k] ?? k, countMap[k]!)).toList();
}

List<DailyDistancePoint> _legacyOperationDailyToDistancePoints(
  List<Map<String, dynamic>> raw,
) {
  return raw
      .map((Map<String, dynamic> row) {
        final String dateKst = row['date_kst'] as String? ?? '';
        final double operationMinutes =
            double.tryParse(row['operation_time_min']?.toString() ?? '0') ?? 0;

        return DailyDistancePoint(
          dateKst: dateKst,
          distanceM: 0,
          operationSec: operationMinutes * 60,
          movingSec: operationMinutes * 60,
        );
      })
      .where((DailyDistancePoint point) => point.dateKst.isNotEmpty)
      .toList();
}

double _resolveSelectedVehicleMovingTotalSec(
  ActivityController controller,
  VehicleDistanceStat? stat,
) {
  final double directTotal = stat?.totalMovingSec ?? 0;
  if (directTotal > 0) return directTotal;

  final double dailyTotal = (stat?.daily ?? <DailyDistancePoint>[])
      .fold<double>(0, (double sum, DailyDistancePoint point) => sum + point.movingSec);
  if (dailyTotal > 0) return dailyTotal;

  return controller.vehicleDailyOperationStats.fold<double>(
    0,
    (double sum, Map<String, dynamic> row) {
      final double minutes = double.tryParse(row['operation_time_min']?.toString() ?? '0') ?? 0;
      return sum + (minutes * 60);
    },
  );
}

class _DistPeriodPoint {
  final String label;
  final double km;
  const _DistPeriodPoint(this.label, this.km);
}

List<_DistPeriodPoint> _aggregateDist(List<DailyDistancePoint> daily, String period) {
  if (daily.isEmpty) return <_DistPeriodPoint>[];

  if (period == 'day') {
    return daily
        .map((DailyDistancePoint d) => _DistPeriodPoint(_mmdd(d.dateKst), d.distanceM / 1000))
        .toList();
  }

  final Map<String, double> kmMap = <String, double>{};
  final Map<String, String> labelMap = <String, String>{};

  for (final DailyDistancePoint d in daily) {
    final DateTime dt = DateTime.parse(d.dateKst);
    String sortKey, label;

    if (period == 'week') {
      // ISO 주 기준 월요일
      final DateTime monday = dt.subtract(Duration(days: dt.weekday - 1));
      sortKey = '${monday.year}'
          '${monday.month.toString().padLeft(2, '0')}'
          '${monday.day.toString().padLeft(2, '0')}';
      label = '${monday.month}/${monday.day}';
    } else {
      // 월
      sortKey = '${dt.year}${dt.month.toString().padLeft(2, '0')}';
      label = isEnglishLocale ? '${_monthAbbr(dt.month)} ${dt.year}' : '${dt.month}월';
    }

    kmMap[sortKey] = (kmMap[sortKey] ?? 0) + d.distanceM / 1000;
    labelMap[sortKey] = label;
  }

  final List<String> sortedKeys = kmMap.keys.toList()..sort();
  return sortedKeys.map((String k) => _DistPeriodPoint(labelMap[k]!, kmMap[k]!)).toList();
}

String _monthAbbr(int month) {
  const List<String> abbr = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return abbr[month - 1];
}

bool _isSameLocalDay(DateTime value, DateTime dayStart) {
  return value.year == dayStart.year && value.month == dayStart.month && value.day == dayStart.day;
}

String _calendarMonthLabel(DateTime date) {
  if (isEnglishLocale) {
    return _monthAbbr(date.month).toUpperCase();
  }
  return '${date.month}월';
}

String _calendarWeekdayLabel(DateTime date) {
  const List<String> weekdaysKo = <String>[
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];
  const List<String> weekdaysEn = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return isEnglishLocale ? weekdaysEn[date.weekday - 1] : weekdaysKo[date.weekday - 1];
}

String _weatherTemperatureLabel(double? value) {
  if (value == null) return '--°';
  return '${value.round()}°';
}

String _weatherLabel(int? weatherCode) {
  switch (weatherCode) {
    case 0:
      return l10n('맑음', 'Clear');
    case 1:
    case 2:
      return l10n('구름 조금', 'Partly Cloudy');
    case 3:
      return l10n('흐림', 'Overcast');
    case 45:
    case 48:
      return l10n('안개', 'Fog');
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return l10n('이슬비', 'Drizzle');
    case 61:
    case 63:
    case 65:
    case 80:
    case 81:
    case 82:
      return l10n('비', 'Rain');
    case 66:
    case 67:
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return l10n('눈', 'Snow');
    case 95:
    case 96:
    case 99:
      return l10n('뇌우', 'Thunderstorm');
    default:
      return l10n('날씨 정보', 'Weather');
  }
}

Color _weatherAccent(int? weatherCode) {
  switch (weatherCode) {
    case 0:
    case 1:
      return const Color(0xFFF9C74F);
    case 2:
    case 3:
    case 45:
    case 48:
      return const Color(0xFF9AA5B1);
    case 61:
    case 63:
    case 65:
    case 80:
    case 81:
    case 82:
      return const Color(0xFF60A5FA);
    case 66:
    case 67:
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return const Color(0xFFE2E8F0);
    case 95:
    case 96:
    case 99:
      return const Color(0xFFF97316);
    default:
      return const Color(0xFF68A8FF);
  }
}

IconData _weatherIcon(int? weatherCode) {
  switch (weatherCode) {
    case 0:
    case 1:
      return Icons.wb_sunny_rounded;
    case 2:
    case 3:
      return Icons.cloud_queue_rounded;
    case 45:
    case 48:
      return Icons.foggy;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
    case 61:
    case 63:
    case 65:
    case 80:
    case 81:
    case 82:
      return Icons.water_drop_rounded;
    case 66:
    case 67:
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return Icons.ac_unit_rounded;
    case 95:
    case 96:
    case 99:
      return Icons.thunderstorm_rounded;
    default:
      return Icons.device_thermostat_rounded;
  }
}

String _calendarEventDetail(ActivityEventItem event) {
  final List<String> parts = <String>[];
  if (event.subtitle.trim().isNotEmpty) {
    parts.add(event.subtitle.trim());
  }
  if (event.stationName != null && event.stationName!.trim().isNotEmpty) {
    parts.add(event.stationName!.trim());
  }
  if (event.speedKph != null) {
    parts.add('${event.speedKph!.toStringAsFixed(0)} km/h');
  }
  return parts.join(' · ');
}

String _calendarEventTimeLabel(DateTime eventTime) {
  final String hhmm =
      '${eventTime.hour.toString().padLeft(2, '0')}:${eventTime.minute.toString().padLeft(2, '0')}';
  final DateTime now = DateTime.now();
  if (_isSameLocalDay(eventTime, DateTime(now.year, now.month, now.day))) {
    return hhmm;
  }
  return '${eventTime.month}/${eventTime.day} · $hhmm';
}

// ─────────────────────────────────────────────
// 기간 선택 칩
// ─────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _primary : _primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _primary)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 순수 함수 헬퍼
// ─────────────────────────────────────────────

double _maxY(List<double> values) {
  double maxValue = 0;
  for (final double value in values) {
    if (value > maxValue) maxValue = value;
  }
  if (maxValue <= 0) return 4;
  if (maxValue <= 5) return 6;
  return (maxValue * 1.2).ceilToDouble();
}

double _axisInterval(double maxY) {
  if (maxY <= 4) return 1;
  if (maxY <= 10) return 2;
  if (maxY <= 20) return 5;
  if (maxY <= 60) return 10;
  return (maxY / 4).ceilToDouble();
}

String _mmdd(String dateKst) {
  final List<String> parts = dateKst.split('-');
  if (parts.length != 3) return dateKst;
  return '${parts[1]}/${parts[2]}';
}

String _formatKm(double km) {
  if (km >= 100) return '${km.toStringAsFixed(0)} km';
  if (km >= 10) return '${km.toStringAsFixed(1)} km';
  return '${km.toStringAsFixed(2)} km';
}

Color _severityColor(int severity) {
  if (severity >= 3) return _danger;
  if (severity >= 2) return _warning;
  return _primary;
}

String _severityLabel(int severity) {
  if (severity >= 3) return l10n('위험', 'Critical');
  if (severity >= 2) return l10n('경고', 'Warning');
  return l10n('정보', 'Info');
}

IconData _eventIcon(String eventType) {
  switch (eventType) {
    case 'high_speed':
      return Icons.speed_rounded;
    case 'emergency_stop':
      return Icons.warning_amber_rounded;
    case 'vehicle_offline':
      return Icons.portable_wifi_off_rounded;
    case 'vehicle_online':
      return Icons.wifi_rounded;
    case 'vehicle_move':
      return Icons.directions_car_rounded;
    case 'vehicle_arrived':
      return Icons.place_rounded;
    case 'infra_offline':
      return Icons.cell_tower_rounded;
    case 'infra_online':
      return Icons.cell_tower_rounded;
    default:
      return Icons.notifications_active_rounded;
  }
}

String _relativeLabel(int ms) {
  final DateTime time = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  final Duration diff = DateTime.now().difference(time);
  if (diff.inSeconds < 10) return l10n('방금 전', 'Just now');
  if (diff.inSeconds < 60) {
    return isEnglishLocale ? '${diff.inSeconds}s ago' : '${diff.inSeconds}초 전';
  }
  if (diff.inMinutes < 60) {
    return isEnglishLocale ? '${diff.inMinutes}m ago' : '${diff.inMinutes}분 전';
  }
  if (diff.inHours < 24) {
    return isEnglishLocale ? '${diff.inHours}h ago' : '${diff.inHours}시간 전';
  }
  return isEnglishLocale ? '${diff.inDays}d ago' : '${diff.inDays}일 전';
}

String _deviceTypeLabel(String deviceType) {
  switch (deviceType) {
    case 'vehicle':
      return l10n('차량', 'Vehicle');
    case 'infra':
      return l10n('인프라', 'Infra');
    default:
      return deviceType;
  }
}

String _activeDaysLabel(int activeDays) {
  if (activeDays <= 0) {
    return l10n('이동 거리 이력이 없습니다.', 'No distance history');
  }
  return isEnglishLocale ? '$activeDays active days' : '$activeDays일 이동';
}

String _eventTooltipLabel(String dateKst, int total) {
  return isEnglishLocale ? '$dateKst\nTotal $total' : '$dateKst\n총 $total건';
}