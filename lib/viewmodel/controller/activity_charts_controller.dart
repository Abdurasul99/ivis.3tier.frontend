// activity_charts_controller.dart
// ActivityController에서 분리한 전역 차트(이벤트/거리/이용량) 전용 GetX 컨트롤러.
// 글로벌 통계만 담당: refreshCharts, refreshUsageStats, 기간 정규화 헬퍼.
// 디바이스별 차트는 ActivityController(향후 ActivityDeviceController)가 보유.

import 'package:get/get.dart';

import '../repository/activity_repository.dart';
import 'activity_controller.dart';
import 'helper/activity_format_helper.dart';
import 'user_controller.dart';

class ActivityChartsController extends GetxController {
  // Repository is injectable so tests can replace HTTP with a fake.
  ActivityChartsController({ActivityRepository? repository})
      : _repo = repository ?? ActivityRepository();

  final ActivityRepository _repo;

  // Sequence numbers: only the newest request may write its result.
  int _chartsRequestId = 0;
  int _usageRequestId = 0;
  // Selection of the request in flight; a different one must not be skipped.
  int? _chartsLoadingDays;
  String? _usageLoadingPeriod;

  // ── 전역 이벤트 차트 ────────────────────────────────────────────────────
  List<ActivityChartDay> chartDays = <ActivityChartDay>[];
  bool isChartLoading = false;

  // ── 전역 거리 통계 ──────────────────────────────────────────────────────
  DistanceStatsResult? distanceStats;
  bool isDistanceLoading = false;

  // 전역 차트 기간 (View에서 7/30 등으로 직접 변경)
  int chartDays_ = 30;

  // ── 이용량 통계 ─────────────────────────────────────────────────────────
  UsageStatsResult? usageStats;
  bool isUsageLoading = false;
  String usagePeriod = 'day';

  // 부모(ActivityController) GetBuilder 가 같이 리빌드 되도록 위임 update
  void _notify() {
    update();
    if (Get.isRegistered<ActivityController>()) {
      Get.find<ActivityController>().update();
    }
  }

  Future<void> refreshCharts({bool silent = false}) async {
    final String token = Get.find<UserController>().accessToken ?? '';
    if (token.isEmpty) return;
    final int days = chartDays_;
    // Skip only a duplicate of the load in flight; a changed period must load.
    if (isChartLoading && _chartsLoadingDays == days) return;

    final int requestId = ++_chartsRequestId;
    if (!silent) {
      _chartsLoadingDays = days;
      isChartLoading = true;
      isDistanceLoading = true;
      _notify();
    }

    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        _repo.requestChartData(days: days),
        _repo.requestDistanceStats(days: days),
      ]);

      if (requestId != _chartsRequestId) return;
      chartDays = results[0] as List<ActivityChartDay>;
      distanceStats = results[1] as DistanceStatsResult;
    } finally {
      // A superseded load must not hide the spinner of the newer one.
      if (requestId == _chartsRequestId) {
        isChartLoading = false;
        isDistanceLoading = false;
        _chartsLoadingDays = null;
        _notify();
      }
    }
  }

  // 전역 차트 기간만 변경 (디바이스 차트 재조회는 호출자가 처리)
  bool setGlobalChartPeriod(int days) {
    if (chartDays_ == days) return false;
    chartDays_ = days;
    refreshCharts();
    return true;
  }

  Future<void> refreshUsageStats() async {
    final String token = Get.find<UserController>().accessToken ?? '';
    if (token.isEmpty) return;
    final String period = usagePeriod;
    // Skip only a duplicate of the load in flight; a changed period must load.
    if (isUsageLoading && _usageLoadingPeriod == period) return;

    final int requestId = ++_usageRequestId;
    _usageLoadingPeriod = period;
    isUsageLoading = true;
    _notify();
    try {
      final UsageStatsResult result = await _repo.requestUsageStats(period: period);
      if (requestId != _usageRequestId) return;
      usageStats = result;
    } finally {
      if (requestId == _usageRequestId) {
        isUsageLoading = false;
        _usageLoadingPeriod = null;
        _notify();
      }
    }
  }

  void setUsagePeriod(String period) {
    if (usagePeriod == period) return;
    usagePeriod = period;
    refreshUsageStats();
  }

  // ── 차트 표시 유틸 (View 에서 사용) ────────────────────────────────────
  List<String> kstDateLabels(int days) {
    final DateTime todayKst = ActivityFormatHelper.nowKst();
    return List<String>.generate(days, (int index) {
      final DateTime day = todayKst.subtract(Duration(days: days - index - 1));
      return ActivityFormatHelper.formatDate(day);
    });
  }

  List<ActivityChartDay> chartDaysSlice(int days) {
    final Map<String, ActivityChartDay> byDate = <String, ActivityChartDay>{
      for (final ActivityChartDay day in chartDays) day.dateKst: day,
    };

    return kstDateLabels(days).map((String date) {
      return byDate[date] ??
          ActivityChartDay(dateKst: date, total: 0, byType: <String, int>{});
    }).toList();
  }

  int get todayEventCount {
    final String today = ActivityFormatHelper.todayKstStr();
    for (final ActivityChartDay day in chartDays) {
      if (day.dateKst == today) return day.total;
    }
    return 0;
  }

  int get todayOverspeedCount {
    final String today = ActivityFormatHelper.todayKstStr();
    for (final ActivityChartDay day in chartDays) {
      if (day.dateKst == today) {
        return (day.byType['high_speed'] ?? 0) +
            (day.byType['emergency_stop'] ?? 0);
      }
    }
    return 0;
  }

  // ── 기간 라벨 정규화 (디바이스 차트 컨트롤러에서도 사용 → public) ───────
  int distanceChartDaysForPeriod(String period) {
    switch (normalizeDistanceChartPeriod(period)) {
      case 'weekly':
        return 84;
      case 'monthly':
        return 365;
      case 'yearly':
        return 1825;
      case 'daily':
      default:
        return 30;
    }
  }

  String normalizeDistanceChartPeriod(String period) {
    switch (period) {
      case 'daily':
      case 'weekly':
      case 'monthly':
      case 'yearly':
        return period;
      case 'day':
        return 'daily';
      case 'week':
        return 'weekly';
      case 'month':
        return 'monthly';
      case 'year':
        return 'yearly';
      default:
        return 'daily';
    }
  }
}
