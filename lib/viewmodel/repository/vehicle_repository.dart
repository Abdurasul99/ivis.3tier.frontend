import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
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

  Future<List<Vehicle>> requestVehicleList() async {
    final Uri url = Uri.http(kApiServer, vehicleListPath);

    try {
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(<String, dynamic>{}),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[Error] requestVehicleList() unauthorized statusCode ${response.statusCode}');
        return <Vehicle>[];
      }

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
    final Uri url = Uri.http(kApiServer, vehicleByIdPath);

    try {
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId}),
      );

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
    final Uri url = Uri.http(kApiServer, vehicleLatestPath);

    try {
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(<String, dynamic>{'vehicle_id': vehicleId}),
      );

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
    final Uri url = Uri.http(kApiServer, vehicleStatusPath);

    try {
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(<String, dynamic>{
          'limit': 1000,
          'offset': 0,
        }),
      );

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
  }) async {
    final Uri url = Uri.http(kApiServer, vehicleStatusPath);

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

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
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(payload),
      );

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
  }) async {
    final Uri url = Uri.http(kApiServer, vehicleHistoryPath);

    final Map<String, dynamic> payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

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
      final http.Response response = await http.post(
        url,
        headers: getHeader(),
        body: jsonEncode(payload),
      );

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
}
