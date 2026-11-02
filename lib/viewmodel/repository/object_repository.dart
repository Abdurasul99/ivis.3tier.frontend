//ivis.3tier.frontend/lib/viewmodel/repository/object_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../model/object_model.dart';
import 'base_repository.dart';

class ObjectRepository extends BaseRepository {
  final String _byVehicleInfoPath = '/api/detectedObjects/byVehicleInfo';
  final String _byInfraInfoPath = '/api/detectedObjects/byInfraInfo';
  final String _byVehicleHistoryPath = '/api/detectedObjects/byVehicleHistory';
  final String _byInfraHistoryPath = '/api/detectedObjects/byInfraHistory';
  final String _historyPath = '/api/detectedObjects/history';

  Future<DetectedObjectResult?> requestByVehicleInfo({
    required int vehicleInfoId,
    int limit = 50000,
    int offset = 0,
    bool latestOnly = false,
    int? vehicleTimeStampMs,
    int? vehicleId,
    int? msgSeq,
    int? expectedObjectCount,
  }) async {
    final Uri url = buildApiUri(_byVehicleInfoPath);

    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'vehicle_info_id': vehicleInfoId,
        'limit': limit,
        'offset': offset,
      };

      if (latestOnly) {
        payload['latest_only'] = true;
      }
      if (vehicleTimeStampMs != null) {
        payload['vehicle_time_stamp_ms'] = vehicleTimeStampMs;
      }
      if (vehicleId != null) {
        payload['vehicle_id'] = vehicleId;
      }
      if (msgSeq != null) {
        payload['msg_seq'] = msgSeq;
      }
      if (expectedObjectCount != null) {
        payload['expected_object_count'] = expectedObjectCount;
      }

      final http.Response response = await http
          .post(
            url,
            headers: getHeader(),
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[Error] requestByVehicleInfo() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        final dynamic body = jsonResponse['body'];

        if (body is Map) {
          return DetectedObjectResult.fromJson(Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<DetectedObject> items = <DetectedObject>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(DetectedObject.fromJson(
                    Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return DetectedObjectResult(totalCount: items.length, items: items);
        }

        return DetectedObjectResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestByVehicleInfo $exception');
      return null;
    }
  }

  Future<DetectedObjectResult?> requestByInfraInfo({
    required int infraInfoId,
    int limit = 200,
    int offset = 0,
    bool latestOnly = false,
    int? infraTimeStampMs,
    int? infraId,
    int? msgSeq,
    int? expectedObjectCount,
  }) async {
    final Uri url = buildApiUri(_byInfraInfoPath);

    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'infra_info_id': infraInfoId,
        'limit': limit,
        'offset': offset,
      };

      if (latestOnly) {
        payload['latest_only'] = true;
      }
      if (infraTimeStampMs != null) {
        payload['infra_time_stamp_ms'] = infraTimeStampMs;
      }
      if (infraId != null) {
        payload['infra_id'] = infraId;
      }
      if (msgSeq != null) {
        payload['msg_seq'] = msgSeq;
      }
      if (expectedObjectCount != null) {
        payload['expected_object_count'] = expectedObjectCount;
      }

      final http.Response response = await http
          .post(
            url,
            headers: getHeader(),
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[Error] requestByInfraInfo() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        final dynamic body = jsonResponse['body'];

        if (body is Map) {
          return DetectedObjectResult.fromJson(Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<DetectedObject> items = <DetectedObject>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(DetectedObject.fromJson(
                    Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return DetectedObjectResult(totalCount: items.length, items: items);
        }

        return DetectedObjectResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestByInfraInfo $exception');
      return null;
    }
  }

  Future<DetectedObjectHistoryResult?> requestByVehicleHistory({
    required int vehicleHistoryId,
    int limit = 200,
    int offset = 0,
  }) async {
    final Uri url = buildApiUri(_byVehicleHistoryPath);

    try {
      final http.Response response = await http
          .post(
            url,
            headers: getHeader(),
            body: jsonEncode(<String, dynamic>{
              'vehicle_history_id': vehicleHistoryId,
              'limit': limit,
              'offset': offset,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[Error] requestByVehicleHistory() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        final dynamic body = jsonResponse['body'];

        if (body is Map) {
          return DetectedObjectHistoryResult.fromJson(
              Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<DetectedObjectHistory> items = <DetectedObjectHistory>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(DetectedObjectHistory.fromJson(
                    Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return DetectedObjectHistoryResult(
              totalCount: items.length, items: items);
        }

        return DetectedObjectHistoryResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestByVehicleHistory $exception');
      return null;
    }
  }

  Future<DetectedObjectHistoryResult?> requestByInfraHistory({
    required int infraHistoryId,
    int limit = 200,
    int offset = 0,
  }) async {
    final Uri url = buildApiUri(_byInfraHistoryPath);

    try {
      final http.Response response = await http
          .post(
            url,
            headers: getHeader(),
            body: jsonEncode(<String, dynamic>{
              'infra_history_id': infraHistoryId,
              'limit': limit,
              'offset': offset,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[Error] requestByInfraHistory() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        final dynamic body = jsonResponse['body'];

        if (body is Map) {
          return DetectedObjectHistoryResult.fromJson(
              Map<String, dynamic>.from(body));
        }

        if (body is List) {
          final List<DetectedObjectHistory> items = <DetectedObjectHistory>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(DetectedObjectHistory.fromJson(
                    Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return DetectedObjectHistoryResult(
              totalCount: items.length, items: items);
        }

        return DetectedObjectHistoryResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestByInfraHistory $exception');
      return null;
    }
  }

  Future<List<DetectedObject>> requestHistory({
    String? from,
    String? to,
    String? sourceKind,
    int limit = 200,
    int offset = 0,
  }) async {
    final Uri url = buildApiUri(_historyPath);

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    if (from != null) {
      payload['from'] = from;
    }

    if (to != null) {
      payload['to'] = to;
    }

    if (sourceKind != null && sourceKind.trim().isNotEmpty) {
      payload['source_kind'] = sourceKind.trim();
    }

    try {
      final http.Response response = await http
          .post(
            url,
            headers: getHeader(),
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[Error] requestHistory() statusCode ${response.statusCode}');
        return <DetectedObject>[];
      }

      return handleResponse(response, (jsonResponse) {
        final dynamic body = jsonResponse['body'];

        List<dynamic>? rawList;
        if (body is Map) {
          rawList = body['items'] as List<dynamic>?;
        } else if (body is List) {
          rawList = body;
        }

        if (rawList == null) {
          return <DetectedObject>[];
        }

        final List<DetectedObject> result = <DetectedObject>[];
        for (final dynamic element in rawList) {
          if (element is Map) {
            try {
              result.add(
                  DetectedObject.fromJson(Map<String, dynamic>.from(element)));
            } catch (_) {}
          }
        }
        return result;
      });
    } catch (exception) {
      debugPrint('[Exception] requestHistory $exception');
      return <DetectedObject>[];
    }
  }

  Future<DetectedObjectResult> requestLatestStatus({
    required String sourceKind,
    int limit = 12,
    int offset = 0,
  }) async {
    final Uri url = buildApiUri(_historyPath);
    final Map<String, dynamic> payload = <String, dynamic>{
      'source_kind': sourceKind,
      'latest_per_source': true,
      'limit': limit,
      'offset': offset,
    };

    try {
      final http.Response response = await http
          .post(
            url,
            headers: getHeader(),
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[Error] requestLatestStatus() statusCode ${response.statusCode}');
        return DetectedObjectResult();
      }

      return handleResponse(response, (jsonResponse) {
        final dynamic body = jsonResponse['body'];
        if (body is Map) {
          return DetectedObjectResult.fromJson(Map<String, dynamic>.from(body));
        }
        if (body is List) {
          final List<DetectedObject> items = <DetectedObject>[];
          for (final dynamic element in body) {
            if (element is Map) {
              try {
                items.add(DetectedObject.fromJson(
                    Map<String, dynamic>.from(element)));
              } catch (_) {}
            }
          }
          return DetectedObjectResult(totalCount: items.length, items: items);
        }
        return DetectedObjectResult();
      });
    } catch (exception) {
      debugPrint('[Exception] requestLatestStatus $exception');
      return DetectedObjectResult();
    }
  }
}
