//ivis.3tier.frontend/lib/viewmodel/repository/infra_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../model/infra_model.dart';
import 'base_repository.dart';

class InfraRepository extends BaseRepository {
  final String infraIdentifiersPath = '/api/infra/identifiers';
  final String infraLatestPath = '/api/infra/latest';
  final String infraStatusPath = '/api/infra/status';
  final String infraHistoryPath = '/api/infra/history';
  final String infraManageListPath = '/api/infra/manage/list';
  final String infraManageDeletePath = '/api/infra/manage/delete';

  Future<List<int>> requestInfraIdentifiers() async {
    final Uri url = buildApiUri(infraIdentifiersPath);

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestInfraIdentifiers() statusCode ${response.statusCode}');
        return <int>[];
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is List) {
          final List<int> ids = <int>[];
          for (final dynamic element in body) {
            final int? value = parseIntInternal(element);
            if (value != null && value > 0) {
              ids.add(value);
            }
          }
          return ids;
        }

        if (body is Map) {
          final Map<String, dynamic> mapBody = Map<String, dynamic>.from(body);
          final dynamic items = mapBody['items'] ?? mapBody['infra_ids'] ?? mapBody['ids'];
          if (items is List) {
            final List<int> ids = <int>[];
            for (final dynamic element in items) {
              final int? value = parseIntInternal(element);
              if (value != null && value > 0) {
                ids.add(value);
              }
            }
            return ids;
          }
        }

        return <int>[];
      });
    } catch (exception) {
      debugPrint('[Exception] requestInfraIdentifiers $exception');
      return <int>[];
    }
  }

  Future<InfraInfo?> requestLatestInfraInfo(int infraId) async {
    final Uri url = buildApiUri(infraLatestPath);

    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'infra_id': infraId}),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestLatestInfraInfo() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        final dynamic body = jsonResponse['body'];
        if (body is! Map<String, dynamic>) {
          return null;
        }
        return InfraInfo.fromJson(body);
      });
    } catch (exception) {
      debugPrint('[Exception] requestLatestInfraInfo $exception');
      return null;
    }
  }

  Future<InfraInfoResult?> requestInfraStatus({
    int? infraId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
  }) async {
    final Uri url = buildApiUri(infraStatusPath);

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    if (infraId != null) {
      payload['infra_id'] = infraId;
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
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestInfraStatus() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is Map) {
          return InfraInfoResult.fromJson(Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<InfraInfo> items = <InfraInfo>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(InfraInfo.fromJson(Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return InfraInfoResult(totalCount: items.length, items: items);
        }

        return InfraInfoResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestInfraStatus $exception');
      return null;
    }
  }

  Future<InfraInfoHistoryResult?> requestInfraHistory({
    int? infraId,
    int? fromEpochMs,
    int? toEpochMs,
    int limit = 18,
    int offset = 0,
    String? searchText,
    String? searchColumnName,
  }) async {
    final Uri url = buildApiUri(infraHistoryPath);

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    if (infraId != null) {
      payload['infra_id'] = infraId;
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
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestInfraHistory() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (dynamic jsonResponse) {
        dynamic body = jsonResponse['body'];
        if (body == null) {
          body = jsonResponse;
        }

        if (body is Map) {
          return InfraInfoHistoryResult.fromJson(Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<InfraInfoHistory> items = <InfraInfoHistory>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(InfraInfoHistory.fromJson(Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return InfraInfoHistoryResult(totalCount: items.length, items: items);
        }

        return InfraInfoHistoryResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestInfraHistory $exception');
      return null;
    }
  }

  int? parseIntInternal(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return int.tryParse(value.toString());
  }

  // 관리 페이지: 인프라 목록 (infra_id별 집계)
  Future<List<Map<String, dynamic>>> requestInfraManageList() async {
    final Uri url = buildApiUri(infraManageListPath);
    try {
      final http.Response response = await safePost(url, body: jsonEncode(<String, dynamic>{})).timeout(requestTimeout);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      return handleResponse(response, (dynamic j) {
        final dynamic body = j['body'];
        if (body is List) return body.map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
        return <Map<String, dynamic>>[];
      });
    } catch (e) {
      debugPrint('[Exception] requestInfraManageList $e');
      return <Map<String, dynamic>>[];
    }
  }

  // 인프라 일별 감지 객체 합계 (KST 기준, 차트용)
  // 반환: [{ 'date_kst': 'YYYY-MM-DD', 'total_objects': int }, ...]
  Future<List<Map<String, dynamic>>> requestInfraDailyObjectCounts({
    required int infraId,
    int days = 30,
  }) async {
    final Uri url = buildApiUri('/api/infra/dailyObjectCounts');
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{
          'infra_id': infraId,
          'days': days,
        }),
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
      debugPrint('[Exception] requestInfraDailyObjectCounts $e');
      return <Map<String, dynamic>>[];
    }
  }

  // 인프라별 전체 감지 객체 합계 (비교 차트용)
  // 반환: [{ 'infra_id': int, 'total_objects': int }] - total_objects 내림차순
  Future<List<Map<String, dynamic>>> requestInfraTotalByInfra({int days = 30}) async {
    final Uri url = buildApiUri('/api/infra/totalByInfra');
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'days': days}),
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
      debugPrint('[Exception] requestInfraTotalByInfra $e');
      return <Map<String, dynamic>>[];
    }
  }

  // 관리 페이지: 인프라 데이터 삭제
  Future<bool> requestInfraManageDelete(int infraId) async {
    final Uri url = buildApiUri(infraManageDeletePath);
    try {
      final http.Response response = await safePost(url, body: jsonEncode(<String, dynamic>{'infra_id': infraId})).timeout(requestTimeout);
      if (response.statusCode != 200) return false;
      final dynamic j = jsonDecode(utf8.decode(response.bodyBytes));
      return j?['code'] == '0000';
    } catch (e) {
      debugPrint('[Exception] requestInfraManageDelete $e');
      return false;
    }
  }
}
