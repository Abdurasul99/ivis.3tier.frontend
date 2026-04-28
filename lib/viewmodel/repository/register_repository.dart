import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../../model/common_model.dart';
import 'base_repository.dart';

class RegisterRepository extends BaseRepository {
  Future<CommonResponse?> requestRegisterSendCode(String name, String email) async {
    final Uri url = buildApiUri("/api/findId/sendCode");
    final body = jsonEncode({"name": name, "email": email});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(requestTimeout);
      debugPrint("requestRegisterSendCode => ${response.body}");
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        return CommonResponse.fromJson(jsonResp);
      } else {
        debugPrint("requestRegisterSendCode error => ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("requestRegisterSendCode exception => $e");
      return null;
    }
  }

  Future<CommonResponse?> requestRegisterVerifyCode(String email, String code) async {
    final Uri url = buildApiUri("/api/findId/verify");
    final body = jsonEncode({"email": email, "code": code});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(requestTimeout);
      debugPrint("requestRegisterVerifyCode => ${response.body}");
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        return CommonResponse.fromJson(jsonResp);
      } else {
        debugPrint("requestRegisterVerifyCode error => ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("requestRegisterVerifyCode exception => $e");
      return null;
    }
  }

  Future<CommonResponse?> requestRegisterComplete({
    required String email,
    required String userId,
    required String name,
    required String phoneNumber,
    required String password,
    required String verifyToken,
  }) async {
    final Uri url = buildApiUri("/api/findId/complete");
    final body = jsonEncode({
      "email": email,
      "user_id": userId,
      "name": name,
      "phone_number": phoneNumber,
      "password": password,
      "verifyToken": verifyToken,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(requestTimeout);
      debugPrint("requestRegisterComplete => ${response.body}");
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        return CommonResponse.fromJson(jsonResp);
      } else {
        debugPrint("requestRegisterComplete error => ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("requestRegisterComplete exception => $e");
      return null;
    }
  }
}
