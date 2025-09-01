import 'package:flutter/material.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/viewmodel/repository/base_repository.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';

class LogRepository extends BaseRepository {
  final String logListPath = "/api/log/list";
  final String logListDocPath = "/api/log/list/doc";

  Future<RobotLogList?> requestLogList(
    int objectId,
    int limit,
    int offset, {
    String? startDate,
    String? endDate,
    String? keyword,
  }) async {
    Map<String, dynamic> params = {};
    params['objectId'] = objectId.toString();
    params['limit'] = limit.toString();
    params['offset'] = offset.toString();

    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate.toString();
    }

    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate.toString();
    }

    if (keyword != null && keyword.isNotEmpty) {
      params['keyword'] = keyword.toString();
    }

    var url = Uri.http(kApiServer, logListPath, params);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] getLogList() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("getLogList() ${jsonResponse.toString()}");
        dynamic body = jsonResponse['body'];
        RobotLogList result = RobotLogList.fromJson(body);

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] getLogList $e");
      return null;
    }
  }

  Future<List<RobotLog>> requestLogListForDocument(int objectId, int minId, int maxId) async {
    Map<String, dynamic> params = {};
    params['objectId'] = objectId.toString();
    params['startId'] = minId.toString();
    params['endId'] = maxId.toString();

    var url = Uri.http(kApiServer, logListDocPath, params);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestLogListForDocument() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestLogListForDocument() ${jsonResp.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<RobotLog> result = items.map((e) => RobotLog.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestLogListForDocument $e");
      return [];
    }
  }
}
