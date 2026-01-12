// password_repository.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/common_model.dart';

class PasswordRepository {
  final String resetPath = "/api/password/reset";
  final String verifyPath = "/api/password/verify";
  final String completePath = "/api/password/complete";
  final String resetByIdEmailPath = "/api/password/resetByIdAndEmail";
  final String verifyByIdEmailPath = "/api/password/verifyByIdAndEmail";
  Future<CommonResponse?> requestResetPassword(String email) async {
    final url = Uri.http(kApiServer, resetPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
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
    final url = Uri.http(kApiServer, verifyPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "code": code}),
      );
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
    final url = Uri.http(kApiServer, completePath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "newPassword": newPassword,
          "verifyToken": verifyToken,
        }),
      );
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
    final url = Uri.http(kApiServer, resetByIdEmailPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "email": email}),
      );
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
    final url = Uri.http(kApiServer, verifyByIdEmailPath);
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "email": email, "code": code}),
      );
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
