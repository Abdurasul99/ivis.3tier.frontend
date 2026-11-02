import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../model/vehicle_model.dart';
import 'base_repository.dart';

class VehicleRepository extends BaseRepository {
  // Correct API paths — use /api/vehicle/ prefix (NOT /api/vehicle-status/).
  // The server does not have a /api/vehicle-status/* route, which causes 404.
  final String vehicleListPath = '/api/vehicle/list';
  final String vehicleByIdPath = '/api/vehicle/getById';
  final String vehicleStatusPath = '/api/vehicle/status';
  final String vehicleHistoryPath = '/api/vehicle/history';
  final String vehicleLatestPath = '/api/vehicle/latest';
  final String vehicleManageListPath = '/api/vehicle/manage/list';
  final String vehicleManageDeletePath = '/api/vehicle/manage/delete';

  Future<List<Vehicle>> requestVehicleList() async {
    final Uri url = buildApiUri(vehicleListPath);

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestVehicleList() statusCode ${response.statusCode}');
        return <Vehicle>[];
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is List) {
          final List<Vehicle> result = <Vehicle>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                result.add(Vehicle.fromJson(Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return result;
        }

        return <Vehicle>[];
      });
    } catch (exception) {
      debugPrint('[Exception] requestVehicleList $exception');
      return <Vehicle>[];
    }
  }

  Future<Vehicle?> requestVehicleById(int vehicleId) async {
    final Uri url = buildApiUri(vehicleByIdPath);

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId}),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestVehicleById() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        final dynamic body = jsonResponse['body'];
        if (body is! Map<String, dynamic>) {
          return null;
        }
        return Vehicle.fromJson(body);
      });
    } catch (exception) {
      debugPrint('[Exception] requestVehicleById $exception');
      return null;
    }
  }

  /// Fetches the latest vehicle info.
  /// IMPORTANT: Uses POST to /api/vehicle/latest (not GET to /api/vehicle-status/latest).
  Future<VehicleInfo?> requestLatestVehicleInfo(int vehicleId) async {
    final Uri url = buildApiUri(vehicleLatestPath);

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId}),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestLatestVehicleInfo() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        final dynamic body = jsonResponse['body'];
        if (body is! Map<String, dynamic>) {
          return null;
        }
        return VehicleInfo.fromJson(body);
      });
    } catch (exception) {
      debugPrint('[Exception] requestLatestVehicleInfo $exception');
      return null;
    }
  }

  /// Fetches all latest vehicle statuses for map display.
  /// Use this instead of direct http.get to /api/vehicle-status/latest.
  Future<List<VehicleInfo>> requestAllLatestVehicleInfo() async {
    final Uri url = buildApiUri(vehicleStatusPath);

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{
          'limit': 1000,
          'offset': 0,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestAllLatestVehicleInfo() statusCode ${response.statusCode}');
        return <VehicleInfo>[];
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is Map) {
          final VehicleInfoResult result = VehicleInfoResult.fromJson(Map<String, dynamic>.from(body));
          return result.items ?? <VehicleInfo>[];
        }

        if (body is List) {
          final List<VehicleInfo> items = <VehicleInfo>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(VehicleInfo.fromJson(Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return items;
        }

        return <VehicleInfo>[];
      });
    } catch (exception) {
      debugPrint('[Exception] requestAllLatestVehicleInfo $exception');
      return <VehicleInfo>[];
    }
  }

  Future<VehicleInfoResult?> requestVehicleStatus({
    int? vehicleId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
    // ── 키셋 커서 페이지네이션 (신규) ─────────────────────────────────────
    // cursorId: 이전 페이지의 마지막(또는 처음) row 의 history_id
    // cursorDirection: 'next' = 다음 페이지, 'prev' = 이전 페이지
    // cursor 가 지정되면 offset 은 페이로드에 포함되지 않는다 (서버는 keyset 사용).
    int? cursorId,
    String? cursorDirection,
  }) async {
    final Uri url = buildApiUri(vehicleStatusPath);

    final bool useKeyset = cursorId != null && cursorId > 0;
    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
    };
    if (useKeyset) {
      // 키셋 모드: { cursor: { history_id, direction } }
      payload['cursor'] = <String, dynamic>{
        'history_id': cursorId,
        'direction': cursorDirection == 'prev' ? 'prev' : 'next',
      };
    } else {
      // 백워드 호환: 기존 offset 페이지네이션
      payload['offset'] = offset;
    }

    if (vehicleId != null) {
      payload['vehicle_id'] = vehicleId;
    }

    if (fromEpochMs != null) {
      payload['from'] = fromEpochMs;
    }

    if (toEpochMs != null) {
      payload['to'] = toEpochMs;
    }

    if (searchText != null && searchText.trim().isNotEmpty) {
      payload['searchText'] = searchText.trim();
    }

    if (searchColumnName != null && searchColumnName.trim().isNotEmpty) {
      payload['searchColumnName'] = searchColumnName.trim();
    }

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[Error] requestVehicleStatus() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is Map) {
          return VehicleInfoResult.fromJson(Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<VehicleInfo> items = <VehicleInfo>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(VehicleInfo.fromJson(Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return VehicleInfoResult(totalCount: items.length, items: items);
        }

        return VehicleInfoResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestVehicleStatus $exception');
      return null;
    }
  }

  Future<VehicleInfoHistoryResult?> requestVehicleHistory({
    int? vehicleId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
    // ── 키셋 커서 페이지네이션 (신규) ─────────────────────────────────────
    // cursorId 가 지정되면 offset 대신 keyset 으로 페이지네이션한다.
    // direction: 'next' = 다음 페이지, 'prev' = 이전 페이지.
    int? cursorId,
    String? cursorDirection,
  }) async {
    final Uri url = buildApiUri(vehicleHistoryPath);

    final bool useKeyset = cursorId != null && cursorId > 0;
    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
    };
    if (useKeyset) {
      payload['cursor'] = <String, dynamic>{
        'history_id': cursorId,
        'direction': cursorDirection == 'prev' ? 'prev' : 'next',
      };
    } else {
      payload['offset'] = offset;
    }

    if (vehicleId != null) {
      payload['vehicle_id'] = vehicleId;
    }

    if (fromEpochMs != null) {
      payload['from'] = fromEpochMs;
    }

    if (toEpochMs != null) {
      payload['to'] = toEpochMs;
    }

    if (searchText != null && searchText.trim().isNotEmpty) {
      payload['searchText'] = searchText.trim();
    }

    if (searchColumnName != null && searchColumnName.trim().isNotEmpty) {
      payload['searchColumnName'] = searchColumnName.trim();
    }

    try {
      // 대용량(수천만 행) 이력 쿼리는 콜드/윈도우 조회 시 수 초~20초 걸릴 수 있어
      // 기본 15초 대신 30초 타임아웃 사용 (성공 응답이 잘리는 것 방지).
      final http.Response response = await safePost(
        url,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[Error] requestVehicleHistory() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is Map) {
          return VehicleInfoHistoryResult.fromJson(Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<VehicleInfoHistory> items = <VehicleInfoHistory>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(VehicleInfoHistory.fromJson(Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return VehicleInfoHistoryResult(totalCount: items.length, items: items);
        }

        return VehicleInfoHistoryResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestVehicleHistory $exception');
      return null;
    }
  }

  // 관리 페이지: 차량 목록 (vehicle_id별 집계)
  Future<List<Map<String, dynamic>>> requestVehicleManageList() async {
    final Uri url = buildApiUri(vehicleManageListPath);
    try {
      final http.Response response = await safePost(url, body: jsonEncode(<String, dynamic>{})).timeout(requestTimeout);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      return handleResponse(response, (dynamic j) {
        final dynamic body = j['body'];
        if (body is List) return body.map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
        return <Map<String, dynamic>>[];
      });
    } catch (e) {
      debugPrint('[Exception] requestVehicleManageList $e');
      return <Map<String, dynamic>>[];
    }
  }

  // 차량 일별 운행 통계 (운행 시간/평균속도/최대속도)
  // 반환: [{ date_kst, operation_time_min, avg_kph, max_kph, moving_records, total_records }]
  Future<List<Map<String, dynamic>>> requestDailyOperationStats({
    required int vehicleId,
    int days = 30,
  }) async {
    final Uri url = buildApiUri('/api/vehicle/dailyOperationStats');
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId, 'days': days}),
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic body = decoded is Map ? decoded['body'] : decoded;
      if (body is List) {
        return body
            .whereType<Map>()
            .map((dynamic e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('[Exception] requestDailyOperationStats $e');
      return <Map<String, dynamic>>[];
    }
  }

  // 차량 일별 감지 객체 합계 (KST 기준, 차트용)
  // 반환: [{ date_kst, total_objects }]
  Future<List<Map<String, dynamic>>> requestVehicleDailyObjectCounts({
    required int vehicleId,
    int days = 30,
  }) async {
    final Uri url = buildApiUri('/api/vehicle/dailyObjectCounts');
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId, 'days': days}),
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic body = decoded is Map ? decoded['body'] : decoded;
      if (body is List) {
        return body
            .whereType<Map>()
            .map((dynamic e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('[Exception] requestVehicleDailyObjectCounts $e');
      return <Map<String, dynamic>>[];
    }
  }

  // 관리 페이지: 차량 데이터 삭제
  Future<bool> requestVehicleManageDelete(int vehicleId) async {
    final Uri url = buildApiUri(vehicleManageDeletePath);
    try {
      final http.Response response = await safePost(url, body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId})).timeout(requestTimeout);
      if (response.statusCode != 200) return false;
      final dynamic j = jsonDecode(utf8.decode(response.bodyBytes));
      return j?['code'] == '0000';
    } catch (e) {
      debugPrint('[Exception] requestVehicleManageDelete $e');
      return false;
    }
  }
}
