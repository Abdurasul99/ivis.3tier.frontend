// password_repository.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../model/common_model.dart';
import 'base_repository.dart';

class PasswordRepository extends BaseRepository {
  final String resetPath = "/api/password/reset";
  final String verifyPath = "/api/password/verify";
  final String completePath = "/api/password/complete";

  /// Parses the JSON envelope {code, message, ...} of a 200 or 4xx response.
  /// Returns null for other statuses and for bodies that are not an envelope.
  @visibleForTesting
  static CommonResponse? parseEnvelope(http.Response response) {
    final int status = response.statusCode;
    if (status != 200 && (status < 400 || status >= 500)) return null;
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['code'] is! String) return null;
      return CommonResponse.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  // Null only for network errors, timeouts and unparseable bodies.
  Future<CommonResponse?> _post(String label, String path, Map<String, dynamic> payload) async {
    final Uri url = buildApiUri(path);
    try {
      final http.Response response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(requestTimeout);
      final CommonResponse? parsed = parseEnvelope(response);
      if (parsed == null) {
        debugPrint("$label error: ${response.statusCode}");
      }
      return parsed;
    } catch (err) {
      debugPrint("$label exception: $err");
      return null;
    }
  }

  Future<CommonResponse?> requestResetPassword(String email, {String? userId}) {
    final String id = userId?.trim() ?? '';
    return _post("requestResetPassword", resetPath, <String, dynamic>{
      "email": email,
      if (id.isNotEmpty) "user_id": id,
    });
  }

  Future<CommonResponse?> requestVerifyCode(String email, String code) {
    return _post("requestVerifyCode", verifyPath, <String, dynamic>{
      "email": email,
      "code": code,
    });
  }

  Future<CommonResponse?> requestCompletePassword(String email, String newPassword, String verifyToken) {
    return _post("requestCompletePassword", completePath, <String, dynamic>{
      "email": email,
      "newPassword": newPassword,
      "verifyToken": verifyToken,
    });
  }
}
