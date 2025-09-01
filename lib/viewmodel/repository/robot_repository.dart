import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fms/viewmodel/repository/base_repository.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/robot_model.dart';

class RobotRepository extends BaseRepository {
  final String robotTypesPath = "/api/robot/types";
  final String robotListPath = "/api/robot/list";
  final String addRobotPath = "/api/robot/add";
  final String deleteRobotPath = "/api/robot/delete";
  final String softDeleteRobotPath = '/api/robot/soft-delete';
  final String robotStatusPath = "/api/robot/status";

  Future<List<RobotType>> requestRobotTypes() async {
    var url = Uri.http(kApiServer, robotTypesPath);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestRobotTypes() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestRobotTypes() ${jsonResp.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<RobotType> result = items.map((e) => RobotType.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestRobotTypes $e");
      return [];
    }
  }

  Future<bool> requestSoftDeleteRobot(int objectId) async {
    final url = Uri.http(kApiServer, softDeleteRobotPath);
    final body = jsonEncode({'id': objectId});

    try {
      final resp = await http.post(url, body: body, headers: getHeader());
      if (resp.statusCode != 200) {
        debugPrint('[Error] softDelete status ${resp.statusCode}');
        return false;
      }

      return handleResponse(resp, (json) => (json['body']?['affectedRows'] ?? 0) > 0);
    } catch (e) {
      debugPrint('[Exception] softDelete $e');
      return false;
    }
  }

  Future<List<Robot>> requestRobotList(int? typeId) async {
    Map<String, dynamic> params = {};
    if (typeId != null) {
      params['typeId'] = typeId.toString();
    }

    var url = Uri.http(kApiServer, robotListPath, params);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestRobotList() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        //debugPrint("requestRobotList() ${jsonResponse.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<Robot> result = items.map((e) => Robot.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestRobotList $e");
      return [];
    }
  }

  Future<bool> requestAddRobot(Map<String, dynamic> params) async {
    var url = Uri.http(kApiServer, addRobotPath);
    final body = jsonEncode(params);

    try {
      final response = await http.post(url, body: body, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestAddRobot() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestAddRobot() ${jsonResp.toString()}");
        return (jsonResponse['body']['affectedRows'] != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestAddRobot $e");
      return false;
    }
  }

  Future<bool> requestDeleteRobot(int objectId) async {
    var url = Uri.http(kApiServer, deleteRobotPath);

    Map<String, dynamic> params = {};
    params['id'] = objectId.toString();

    final body = jsonEncode(params);

    try {
      final response = await http.delete(url, body: body, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestDeleteRobot() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestDeleteRobot() ${jsonResp.toString()}");
        return (jsonResponse['body']['affectedRows'] != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestDeleteRobot $e");
      return false;
    }
  }

  Future<List<RobotStatus>> requestRobotStatusList({int? objectId, int? objectTypeId}) async {
    Map<String, dynamic> queryParams = {};
    if (objectId != null) {
      queryParams['object_id'] = objectId;
    }

    if (objectTypeId != null) {
      queryParams['object_type_id'] = objectTypeId;
    }

    var url = Uri.http(kApiServer, robotStatusPath, queryParams);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestRobotStatusList() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestRobotStatusList() ${jsonResp.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<RobotStatus> result = items.map((e) => RobotStatus.fromJson(e)).toList();
        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestRobotStatusList() $e");
      return [];
    }
  }
}
