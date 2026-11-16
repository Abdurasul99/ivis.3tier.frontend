// ivis.3tier.frontend/lib/viewmodel/repository/base_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../controller/user_controller.dart';
import 'user_repository.dart' show TokenCheckStatus;

class BaseRepository {
  /// 세션 만료(리프레시 토큰 갱신 실패) 시 호출되는 콜백.
  /// 뷰 레이어(main.dart)에서 주입 — 레포지토리가 view를 직접 import하지 않도록 분리.
  static void Function()? onSessionExpired;

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

  /// Envelope ({code, message, ...}) of a 4xx answer, or null when there is none.
  Map<String, dynamic>? errorEnvelope(http.Response response) {
    if (response.statusCode < 400 || response.statusCode >= 500) return null;
    try {
      final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['code'] != null) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Shared 401 handling for every authenticated call: refresh the access token once
  /// (concurrent 401s share one refresh) and send the request again.
  /// [send] must build the request anew on each call so the retry carries the new token.
  /// The session is cleared only when the refresh token was rejected, not on network/5xx errors.
  Future<http.Response> sendAuthorized(
    Future<http.Response> Function(bool isRetry) send,
  ) async {
    final UserController userCtrl = Get.find<UserController>();
    final String? sentToken = userCtrl.accessToken;

    final http.Response resp = await send(false);
    if (resp.statusCode != 401) return resp;

    // Another call already refreshed the token while this one was in flight.
    final String? currentToken = userCtrl.accessToken;
    if (currentToken != null && currentToken.isNotEmpty && currentToken != sentToken) {
      return send(true);
    }

    final TokenCheckStatus status = await userCtrl.refreshAccessTokenStatus();
    if (status == TokenCheckStatus.ok) return send(true);

    if (status == TokenCheckStatus.rejected && userCtrl.accessToken != null) {
      // Refresh token rejected: log out once and go to the login page.
      await userCtrl.logout();
      onSessionExpired?.call();
    }
    return resp;
  }

  Future<http.Response> safePost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) {
    return sendAuthorized((bool isRetry) => http
        .post(url, headers: isRetry ? getHeader() : (headers ?? getHeader()), body: body)
        .timeout(timeout ?? requestTimeout));
  }

  Future<http.Response> safeGet(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return sendAuthorized((bool isRetry) => http
        .get(url, headers: isRetry ? getHeader() : (headers ?? getHeader()))
        .timeout(timeout ?? requestTimeout));
  }

  Future<http.Response> safePatch(Uri url, {Object? body}) {
    return sendAuthorized(
        (_) => http.patch(url, headers: getHeader(), body: body).timeout(requestTimeout));
  }

  Future<http.Response> safeDelete(Uri url, {Object? body}) {
    return sendAuthorized(
        (_) => http.delete(url, headers: getHeader(), body: body).timeout(requestTimeout));
  }

  /// [build] must return a fresh request each time (a multipart request cannot be re-sent).
  /// The access token header is added here.
  Future<http.Response> safeMultipart(http.MultipartRequest Function() build) {
    return sendAuthorized((_) async {
      final http.MultipartRequest request = build();
      final String token = Get.find<UserController>().accessToken ?? '';
      if (token.isNotEmpty) {
        request.headers['x-access-token'] = token;
      }
      final http.StreamedResponse streamed = await request.send().timeout(requestTimeout);
      return http.Response.fromStream(streamed).timeout(requestTimeout);
    });
  }
}
