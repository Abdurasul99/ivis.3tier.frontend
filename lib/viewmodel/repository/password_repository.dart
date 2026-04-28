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
  final String resetByIdEmailPath = "/api/password/resetByIdAndEmail";
  final String verifyByIdEmailPath = "/api/password/verifyByIdAndEmail";
  Future<CommonResponse?> requestResetPassword(String email) async {
    final Uri url = buildApiUri(resetPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return CommonResponse.fromJson(jsonDecode(response.body));
      }
      debugPrint("requestResetPassword error: ${response.statusCode}");
      return null;
    } catch (err) {
      debugPrint("requestResetPassword exception: $err");
      return null;
    }
  }

  Future<CommonResponse?> requestVerifyCode(String email, String code) async {
    final Uri url = buildApiUri(verifyPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "code": code}),
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return CommonResponse.fromJson(jsonDecode(response.body));
      }
      debugPrint("requestVerifyCode error: ${response.statusCode}");
      return null;
    } catch (err) {
      debugPrint("requestVerifyCode exception: $err");
      return null;
    }
  }

  Future<CommonResponse?> requestCompletePassword(String email, String newPassword, String verifyToken) async {
    final Uri url = buildApiUri(completePath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "newPassword": newPassword,
          "verifyToken": verifyToken,
        }),
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return CommonResponse.fromJson(jsonDecode(response.body));
      }
      debugPrint("requestCompletePassword error: ${response.statusCode}");
      return null;
    } catch (err) {
      debugPrint("requestCompletePassword exception: $err");
      return null;
    }
  }

  Future<CommonResponse?> requestResetPasswordByIdAndEmail(String userId, String email) async {
    final Uri url = buildApiUri(resetByIdEmailPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "email": email}),
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return CommonResponse.fromJson(jsonDecode(response.body));
      }
      debugPrint("requestResetPasswordByIdAndEmail error: ${response.statusCode}");
      return null;
    } catch (err) {
      debugPrint("requestResetPasswordByIdAndEmail exception: $err");
      return null;
    }
  }

  Future<CommonResponse?> requestVerifyCodeByIdAndEmail(String userId, String email, String code) async {
    final Uri url = buildApiUri(verifyByIdEmailPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "email": email, "code": code}),
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return CommonResponse.fromJson(jsonDecode(response.body));
      }
      debugPrint("requestVerifyCodeByIdAndEmail error: ${response.statusCode}");
      return null;
    } catch (err) {
      debugPrint("requestVerifyCodeByIdAndEmail exception: $err");
      return null;
    }
  }
}
