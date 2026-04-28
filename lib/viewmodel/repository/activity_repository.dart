// lib/viewmodel/repository/activity_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_repository.dart';

// PostgreSQL ROUND/NUMERIC → JSON 으로 string 으로 올 수 있음 → 안전하게 파싱
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class ActivityEventItem {
  final int id;
  final String deviceType;
  final int deviceId;
  final String eventType;
  final int severity;
  final String title;
  final String subtitle;
  final String? stationName;
  final double? speedKph;
  final bool isRead;
  final int occurredAtMs;

  const ActivityEventItem({
    required this.id,
    required this.deviceType,
    required this.deviceId,
    required this.eventType,
    required this.severity,
    required this.title,
    required this.subtitle,
    this.stationName,
    this.speedKph,
    required this.isRead,
    required this.occurredAtMs,
  });

  factory ActivityEventItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawIsRead = json['is_read'];
    return ActivityEventItem(
      id: (json['id'] as num).toInt(),
      deviceType: json['device_type'] as String? ?? 'vehicle',
      deviceId: (json['device_id'] as num).toInt(),
      eventType: json['event_type'] as String? ?? '',
      severity: (json['severity'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      stationName: json['station_name'] as String?,
      speedKph: (json['speed_kph'] as num?)?.toDouble(),
      isRead: rawIsRead is bool
          ? rawIsRead
          : rawIsRead is num
              ? rawIsRead != 0
              : rawIsRead?.toString().toLowerCase() == 'true',
      occurredAtMs: int.parse(json['occurred_at_ms'].toString()),
    );
  }
}

// ─────────────────────────────────────────────
// 차트 데이터 모델
// ─────────────────────────────────────────────

class ActivityChartDay {
  final String dateKst;
  final int total;
  final Map<String, int> byType;

  const ActivityChartDay({
    required this.dateKst,
    required this.total,
    required this.byType,
  });

  factory ActivityChartDay.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawByType =
        (json['by_type'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, int> byType = rawByType.map(
      (String k, dynamic v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );
    return ActivityChartDay(
      dateKst: json['date_kst'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      byType: byType,
    );
  }
}

// ─────────────────────────────────────────────
// 거리 통계 모델
// ─────────────────────────────────────────────

class DailyDistancePoint {
  final String dateKst;
  final double distanceM;
  final double operationSec;
  final double movingSec;

  const DailyDistancePoint({
    required this.dateKst,
    required this.distanceM,
    required this.operationSec,
    required this.movingSec,
  });

  factory DailyDistancePoint.fromJson(Map<String, dynamic> json) {
    return DailyDistancePoint(
      dateKst: json['date_kst'] as String? ?? '',
      distanceM: _toDouble(json['distance_m']),
      operationSec: _toDouble(json['operation_sec']),
      movingSec: _toDouble(json['moving_sec']),
    );
  }
}

class VehicleDistanceStat {
  final int vehicleId;
  final List<DailyDistancePoint> daily;
  final double totalM;
  final double totalKm;
  final double totalOperationSec;
  final double totalMovingSec;

  const VehicleDistanceStat({
    required this.vehicleId,
    required this.daily,
    required this.totalM,
    required this.totalKm,
    required this.totalOperationSec,
    required this.totalMovingSec,
  });

  factory VehicleDistanceStat.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawDaily =
        json['daily'] as List<dynamic>? ?? <dynamic>[];
    return VehicleDistanceStat(
      vehicleId: (json['vehicle_id'] as num).toInt(),
      daily: rawDaily
          .whereType<Map<String, dynamic>>()
          .map(DailyDistancePoint.fromJson)
          .toList(),
      totalM: _toDouble(json['total_m']),
      totalKm: _toDouble(json['total_km']),
      totalOperationSec: _toDouble(json['total_operation_sec']),
      totalMovingSec: _toDouble(json['total_moving_sec']),
    );
  }
}

class DistanceStatsResult {
  final List<VehicleDistanceStat> vehicles;
  final List<DailyDistancePoint> fleetDaily;
  final double fleetTotalKm;

  const DistanceStatsResult({
    required this.vehicles,
    required this.fleetDaily,
    required this.fleetTotalKm,
  });
}

// ─────────────────────────────────────────────
// 사용량 통계 모델 (일/주/월 집계)
// ─────────────────────────────────────────────

class UsagePeriodItem {
  final String periodLabel;
  final double distanceM;

  const UsagePeriodItem({required this.periodLabel, required this.distanceM});

  factory UsagePeriodItem.fromJson(Map<String, dynamic> json) {
    return UsagePeriodItem(
      periodLabel: json['period_label'] as String? ?? '',
      distanceM: _toDouble(json['distance_m']),
    );
  }
}

class UsageStatsResult {
  final String period;
  final List<UsagePeriodItem> items;
  final double totalM;
  final double totalKm;

  const UsageStatsResult({
    required this.period,
    required this.items,
    required this.totalM,
    required this.totalKm,
  });
}

class ActivityRepository extends BaseRepository {
  static const String _eventsPath = '/api/activity/events';
  static const String _unreadCountPath = '/api/activity/unreadCount';
  static const String _markReadPath = '/api/activity/markRead';
  static const String _markAllReadPath = '/api/activity/markAllRead';
  static const String _chartDataPath = '/api/activity/chartData';
  static const String _distanceStatsPath = '/api/activity/distanceStats';
  static const String _usageStatsPath = '/api/activity/usageStats';

  // 이벤트 목록 조회
  Future<({List<ActivityEventItem> items, int totalCount})> requestEvents({
    int? vehicleId,
    int? deviceId,
    String? deviceType,
    int? minSeverity,
    int? fromMs,
    int? toMs,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (vehicleId != null) body['vehicle_id'] = vehicleId;
      if (deviceId != null) body['device_id'] = deviceId;
      if (deviceType != null) body['device_type'] = deviceType;
      if (minSeverity != null) body['severity'] = minSeverity;
      if (fromMs != null) body['from'] = fromMs;
      if (toMs != null) body['to'] = toMs;

      final http.Response resp = await safePost(
        buildApiUri(_eventsPath),
        body: jsonEncode(body),
      ).timeout(requestTimeout);

      if (resp.statusCode != 200) {
        return (items: <ActivityEventItem>[], totalCount: 0);
      }

      final dynamic decoded = jsonDecode(resp.body);
      final dynamic respBody = decoded['body'];
      if (respBody is! Map) {
        return (items: <ActivityEventItem>[], totalCount: 0);
      }

      final List<dynamic> rawList =
          respBody['items'] as List<dynamic>? ?? <dynamic>[];
      final int total = (respBody['totalCount'] as num?)?.toInt() ?? 0;
      final List<ActivityEventItem> items = rawList
          .whereType<Map<String, dynamic>>()
          .map(ActivityEventItem.fromJson)
          .toList();
      return (items: items, totalCount: total);
    } catch (e) {
      debugPrint('[ActivityRepository.requestEvents] $e');
      return (items: <ActivityEventItem>[], totalCount: 0);
    }
  }

  // 미읽은 알림 수
  Future<int> requestUnreadCount() async {
    try {
      final http.Response resp = await safePost(
        buildApiUri(_unreadCountPath),
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(requestTimeout);
      if (resp.statusCode != 200) return 0;
      final dynamic decoded = jsonDecode(resp.body);
      return (decoded['body']?['unread_count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // 읽음 처리
  Future<void> requestMarkRead(int id) async {
    try {
      await safePost(
        buildApiUri(_markReadPath),
        body: jsonEncode(<String, dynamic>{'id': id}),
      ).timeout(requestTimeout);
    } catch (_) {}
  }

  // 모두 읽음
  Future<void> requestMarkAllRead() async {
    try {
      await safePost(
        buildApiUri(_markAllReadPath),
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(requestTimeout);
    } catch (_) {}
  }

  // 일별 이벤트 차트 데이터 (최근 N일)
  Future<List<ActivityChartDay>> requestChartData({
    int days = 30,
    String? deviceType,
    int? deviceId,
    int? fromMs,
    int? toMs,
  }) async {
    try {
      final http.Response resp = await safePost(
        buildApiUri(_chartDataPath),
        body: jsonEncode(<String, dynamic>{
          'days': days,
          if (deviceType != null) 'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
          if (fromMs != null) 'from': fromMs,
          if (toMs != null) 'to': toMs,
        }),
      ).timeout(requestTimeout);

      if (resp.statusCode != 200) return <ActivityChartDay>[];
      final dynamic decoded = jsonDecode(resp.body);
      final List<dynamic> rawList =
          (decoded['body']?['daily'] as List<dynamic>?) ?? <dynamic>[];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(ActivityChartDay.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[ActivityRepository.requestChartData] $e');
      return <ActivityChartDay>[];
    }
  }

  // 차량별 / 플리트 이동거리 통계
  Future<DistanceStatsResult> requestDistanceStats({
    int days = 30,
    int? vehicleId,
    bool includeRuntime = false,
  }) async {
    try {
      final http.Response resp = await safePost(
        buildApiUri(_distanceStatsPath),
        body: jsonEncode(<String, dynamic>{
          'days': days,
          if (vehicleId != null) 'vehicle_id': vehicleId,
          if (includeRuntime) 'include_runtime': true,
        }),
      ).timeout(requestTimeout);

      if (resp.statusCode != 200) {
        return DistanceStatsResult(
            vehicles: <VehicleDistanceStat>[],
            fleetDaily: <DailyDistancePoint>[],
            fleetTotalKm: 0);
      }
      final dynamic decoded = jsonDecode(resp.body);
      final dynamic body = decoded['body'];
      if (body is! Map) {
        return DistanceStatsResult(
            vehicles: <VehicleDistanceStat>[],
            fleetDaily: <DailyDistancePoint>[],
            fleetTotalKm: 0);
      }

      final List<dynamic> rawVehicles =
          body['vehicles'] as List<dynamic>? ?? <dynamic>[];
      final List<dynamic> rawFleet =
          body['fleet_daily'] as List<dynamic>? ?? <dynamic>[];

      return DistanceStatsResult(
        vehicles: rawVehicles
            .whereType<Map<String, dynamic>>()
            .map(VehicleDistanceStat.fromJson)
            .toList(),
        fleetDaily: rawFleet
            .whereType<Map<String, dynamic>>()
            .map(DailyDistancePoint.fromJson)
            .toList(),
        fleetTotalKm: _toDouble(body['fleet_total_km']),
      );
    } catch (e) {
      debugPrint('[ActivityRepository.requestDistanceStats] $e');
      return DistanceStatsResult(
          vehicles: <VehicleDistanceStat>[],
          fleetDaily: <DailyDistancePoint>[],
          fleetTotalKm: 0);
    }
  }

  // 플리트 사용량 통계 (일/주/월 집계)
  Future<UsageStatsResult> requestUsageStats({String period = 'day'}) async {
    final UsageStatsResult empty = UsageStatsResult(
      period: period,
      items: <UsagePeriodItem>[],
      totalM: 0,
      totalKm: 0,
    );
    try {
      final http.Response resp = await safePost(
        buildApiUri(_usageStatsPath),
        body: jsonEncode(<String, dynamic>{'period': period}),
      ).timeout(requestTimeout);

      if (resp.statusCode != 200) return empty;
      final dynamic decoded = jsonDecode(resp.body);
      final dynamic body = decoded['body'];
      if (body is! Map) return empty;

      final List<dynamic> rawItems =
          body['items'] as List<dynamic>? ?? <dynamic>[];
      return UsageStatsResult(
        period: body['period'] as String? ?? period,
        items: rawItems
            .whereType<Map<String, dynamic>>()
            .map(UsagePeriodItem.fromJson)
            .toList(),
        totalM: _toDouble(body['total_m']),
        totalKm: _toDouble(body['total_km']),
      );
    } catch (e) {
      debugPrint('[ActivityRepository.requestUsageStats] $e');
      return empty;
    }
  }
}
