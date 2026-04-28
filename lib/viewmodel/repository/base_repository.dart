// ivis.3tier.frontend/lib/viewmodel/repository/base_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../view/pages/login_page.dart';
import '../controller/user_controller.dart';

class BaseRepository {
  final String kQueryPath = "/api/admin/common/query";
  Duration get requestTimeout => const Duration(seconds: 15);

  Uri buildApiUri(String path, [Map<String, dynamic>? queryParams]) {
    final String server = kApiServer.trim();
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Map<String, String>? normalizedQuery = queryParams?.map(
      (String key, dynamic value) => MapEntry(key, value.toString()),
    );

    if (server.startsWith('http://') || server.startsWith('https://')) {
      final Uri parsed = Uri.parse(server);
      final String basePath = parsed.path.endsWith('/')
          ? parsed.path.substring(0, parsed.path.length - 1)
          : parsed.path;
      return parsed.replace(
        path: '$basePath$normalizedPath',
        queryParameters: normalizedQuery,
      );
    }

    if (kIsWeb && Uri.base.scheme == 'https') {
      return Uri.https(server, normalizedPath, normalizedQuery);
    }
    return Uri.http(server, normalizedPath, normalizedQuery);
  }

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

  /// 401 자동 갱신 인터셉터: 액세스 토큰이 만료되면 리프레시 토큰으로 갱신 후 재시도.
  /// 갱신도 실패하면 로그아웃 처리 후 로그인 페이지로 이동.
  Future<http.Response> safePost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final h = headers ?? getHeader();
    http.Response resp = await http.post(url, headers: h, body: body).timeout(requestTimeout);

    if (resp.statusCode != 401) return resp;

    // 액세스 토큰 만료 → 리프레시 토큰으로 갱신 시도
    final userCtrl = Get.find<UserController>();
    final refreshed = await userCtrl.refreshAccessToken();
    if (!refreshed) {
      // 리프레시도 실패 → 완전 로그아웃 후 로그인 페이지
      await userCtrl.logout();
      Get.offAllNamed(LoginPage.routeName);
      return resp;
    }

    // 새 액세스 토큰으로 재시도
    return http.post(url, headers: getHeader(), body: body).timeout(requestTimeout);
  }

  Future<http.Response> safeGet(Uri url, {Map<String, String>? headers}) async {
    final h = headers ?? getHeader();
    http.Response resp = await http.get(url, headers: h).timeout(requestTimeout);

    if (resp.statusCode != 401) return resp;

    final userCtrl = Get.find<UserController>();
    final refreshed = await userCtrl.refreshAccessToken();
    if (!refreshed) {
      await userCtrl.logout();
      Get.offAllNamed(LoginPage.routeName);
      return resp;
    }

    return http.get(url, headers: getHeader()).timeout(requestTimeout);
  }
}
