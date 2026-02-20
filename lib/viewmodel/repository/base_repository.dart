// ivis.3tier.frontend/lib/viewmodel/repository/base_repository.dart
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../controller/user_controller.dart';

class BaseRepository {
  final String kQueryPath = "/api/admin/common/query";

  Map<String, String> getHeader({bool includeToken = true}) {
    Map<String, String> headers = {};

    headers["Content-Type"] = "application/json; charset=utf-8";

    if (includeToken) {
      String accessToken = Get.find<UserController>().accessToken ?? "";

      if (accessToken.isNotEmpty) {
        headers['x-access-token'] = accessToken;
      }
    }

    return headers;
  }

  dynamic handleResponse(http.Response response, dynamic Function(dynamic) function) {
    if (response.statusCode != 200) {
      throw Exception('statusCode ${response.statusCode} ${response.body}');
    }

    dynamic jsonResponse;

    try {
      jsonResponse = json.decode(utf8.decode(response.bodyBytes));
    } catch (exception) {
      throw Exception(exception.toString());
    }

    if (jsonResponse == null) {
      throw Exception("jsonResponse is null");
    }

    return function(jsonResponse);
  }
}
