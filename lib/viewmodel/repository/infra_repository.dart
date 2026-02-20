//ivis.3tier.frontend/lib/viewmodel/repository/infra_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import '../../model/infra_model.dart';
import 'base_repository.dart';

class InfraRepository extends BaseRepository {
  final String infraIdentifiersPath = '/api/infra/identifiers';
  final String infraLatestPath = '/api/infra/latest';
  final String infraStatusPath = '/api/infra/status';
  final String infraHistoryPath = '/api/infra/history';

  Future<List<int>> requestInfraIdentifiers() async {
    final Uri url = Uri.http(kApiServer, infraIdentifiersPath);

    try {
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(<String, dynamic>{}),
      );

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
    final Uri url = Uri.http(kApiServer, infraLatestPath);

    try {
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(<String, dynamic>{'infra_id': infraId}),
      );

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
    final Uri url = Uri.http(kApiServer, infraStatusPath);

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
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(payload),
      );

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
    final Uri url = Uri.http(kApiServer, infraHistoryPath);

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
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(payload),
      );

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
}
