// lib/viewmodel/repository/graph_repository.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../constants/constants.dart';
import '../../model/graph_model.dart';
import 'base_repository.dart';

class GraphRepository extends BaseRepository {
  final String chartItemPath = "/api/chart/items";

  Future<GraphModel?> fetch(int objectId, String period, int limit, String metric) async {
    final query = {
      'object_id': '$objectId',
      'period': period,
      'limit': '$limit',
      'metric': metric,
    };

    final uri = Uri.http(kApiServer, '/api/chart', query);
    try {
      final res = await http.get(uri, headers: getHeader(includeToken: false));
      return handleResponse(
        res,
        (jsonResp) => GraphModel.fromJson(jsonResp['body']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<ChartItem>> getChartItems(int objectId, String period) async {
    Map<String, dynamic> params = {};
    params['objectId'] = objectId.toString();
    params['period'] = period.toString();

    var url = Uri.http(kApiServer, chartItemPath, params);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        // debugPrint('[Error] getChartItems() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("getChartItems() ${jsonResponse.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<ChartItem> result = items.map((e) => ChartItem.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] getChartItems $e");
      return [];
    }
  }
}
