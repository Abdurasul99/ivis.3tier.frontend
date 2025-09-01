import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/dashboard_model.dart';
import 'base_repository.dart';

class DashboardRepository extends BaseRepository {
  final String layoutSettingPath = "/api/dashboard/setting/layout";

  Future<List<RobotSuccessData>> fetchRobotSuccess() async {
    final uri = Uri.http(kApiServer, '/api/dashboard/robotSuccess');
    final response = await http.get(uri, headers: getHeader());

    return handleResponse(response, (json) {
      final items = json['data'] as List<dynamic>;
      return items.map((e) => RobotSuccessData.fromJson(Map<String, dynamic>.from(e))).toList();
    });
  }

  Future<DeviceStatusData> fetchDeviceStatus() async {
    final uri = Uri.http(kApiServer, '/api/dashboard/deviceStatus');
    final headers = getHeader();

    final response = await http.get(uri, headers: headers);

    return handleResponse(response, (json) {
      return DeviceStatusData.fromJson(Map<String, dynamic>.from(json['body']));
    });
  }

  Future<List<LayoutSet>> requestDashboardLayoutSetting() async {
    var url = Uri.http(kApiServer, layoutSettingPath);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        // debugPrint('[Error] requestDashboardLayoutSetting() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestDashboardLayoutSetting() ${jsonResponse.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<LayoutSet> result = items.map((e) => LayoutSet.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestDashboardLayoutSetting $e");
      return [];
    }
  }

  Future<bool> requestInsertDashboardLayoutSetting(Map<String, dynamic> params) async {
    var url = Uri.http(kApiServer, layoutSettingPath);
    String body = jsonEncode(params);

    try {
      final response = await http.post(url, headers: getHeader(), body: body);
      if (response.statusCode != 200) {
        // debugPrint('[Error] requestInsertDashboardLayoutSetting() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestInsertDashboardLayoutSetting() ${jsonResponse.toString()}");
        return (jsonResponse != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestInsertDashboardLayoutSetting $e");
      return false;
    }
  }

  Future<bool> requestDeleteDashboardLayoutSetting() async {
    var url = Uri.http(kApiServer, layoutSettingPath);

    try {
      final response = await http.delete(url, headers: getHeader());
      if (response.statusCode != 200) {
        // debugPrint('[Error] requestDeleteDashboardLayoutSetting() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestDeleteDashboardLayoutSetting() ${jsonResponse.toString()}");
        return (jsonResponse != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestDeleteDashboardLayoutSetting $e");
      return false;
    }
  }
}
