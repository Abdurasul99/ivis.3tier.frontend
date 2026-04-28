import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../model/common_model.dart';
import '../../model/user_model.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository {
  final String signUpByIdEmailPath = "/api/users/signUpByIdAndEmail";
  final String loginByIdPath = "/api/users/signInById";
  final String loginByTokenPath = "/api/users/signInByToken";
  final String refreshTokenPath = "/api/users/accessToken";
  final String changePasswordPath = "/api/users/update";
  final String changePhoneNumberPath = "/api/users/updatePhoneNumber";
  final String changeProfilePath = "/api/users/updateProfile";
  final String findIdSendCodePath = "/api/findid/sendCode";
  final String findIdVerifyCodePath = "/api/findid/verify";

  Future<CommonResponse?> requestSignUpByIdAndEmail(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(signUpByIdEmailPath);
    final body = jsonEncode(params);

    try {
      final response = await http.post(
        url,
        headers: getHeader(includeToken: false),
        body: body,
      ).timeout(requestTimeout);
      return handleResponse(response, (jsonResp) {
        return CommonResponse.fromJson(jsonResp);
      });
    } catch (e) {
      debugPrint("[Exception] requestSignUpByIdAndEmail => $e");
      return null;
    }
  }

  Future<LoginResult?> requestLoginById(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(loginByIdPath);
    final body = jsonEncode(params);

    try {
      final response = await http.post(
        url,
        headers: getHeader(includeToken: false),
        body: body,
      ).timeout(requestTimeout);
      return handleResponse(response, (jsonResp) {
        return LoginResult.fromJson(jsonResp);
      });
    } catch (e) {
      debugPrint("[Exception] requestLoginById => $e");
      return null;
    }
  }

  /// 리프레시 토큰으로 새 액세스 토큰을 발급받는다.
  /// 반환값: 새 accessToken 문자열, 실패 시 null
  Future<String?> requestRefreshAccessToken(String refreshToken) async {
    final Uri url = buildApiUri(refreshTokenPath);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'x-access-token': refreshToken,
    };
    try {
      final http.Response response =
          await http.post(url, headers: headers).timeout(requestTimeout);
      if (response.statusCode != 200) return null;
      final dynamic json = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic body = json?['body'];
      if (body == null) return null;
      final String? newToken = body['accessToken']?.toString();
      return (newToken != null && newToken.isNotEmpty) ? newToken : null;
    } catch (e) {
      debugPrint("[Exception] requestRefreshAccessToken => $e");
      return null;
    }
  }

  Future<LoginResult?> requestLoginByToken(String token) async {
    final Uri url = buildApiUri(loginByTokenPath);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'x-access-token': token,
    };

    try {
      final http.Response response =
          await http.post(url, headers: headers).timeout(requestTimeout);
      return handleResponse(response, (jsonResp) {
        return LoginResult.fromJson(jsonResp);
      });
    } catch (e) {
      debugPrint("[Exception] requestLoginByToken => $e");
      return null;
    }
  }

  Future<String> requestChangePassword(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(changePasswordPath);
    final body = jsonEncode(params);

    try {
      final http.Response response = await http
          .post(url, headers: getHeader(), body: body)
          .timeout(requestTimeout);

      return handleResponse(response, (jsonResp) {
        final cr = CommonResponse.fromJson(jsonResp);
        if (cr.code == "0000") {
          return "changed password";
        } else if (cr.code == "8003") {
          return "wrong password";
        }
        return "";
      });
    } catch (e) {
      debugPrint("[Exception] requestChangePassword() => ${e.toString()}");
      return "";
    }
  }

  Future<bool> requestChangePhoneNumber(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(changePhoneNumberPath);
    final body = jsonEncode(params);

    try {
      final http.Response response = await http
          .post(url, headers: getHeader(), body: body)
          .timeout(requestTimeout);

      return handleResponse(response, (jsonResp) {
        final cr = CommonResponse.fromJson(jsonResp);
        debugPrint("requestChangePhoneNumber() code ${cr.code}");
        return (cr.code == "0000");
      });
    } catch (e) {
      debugPrint("[Exception] requestChangePhoneNumber() => ${e.toString()}");
      return false;
    }
  }

  Future<bool> requestUpdateProfileImage(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(changeProfilePath);
    final body = jsonEncode(params);

    try {
      final http.Response response = await http
          .post(url, headers: getHeader(), body: body)
          .timeout(requestTimeout);
      return handleResponse(response, (jsonResp) {
        final cr = CommonResponse.fromJson(jsonResp);
        return (cr.code == "0000");
      });
    } catch (e) {
      debugPrint("[Exception] requestUpdateProfileImage() => ${e.toString()}");
      return false;
    }
  }

  Future<bool> requestFindIdSendCode(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(findIdSendCodePath);
    final body = jsonEncode(params);

    try {
      final http.Response response = await http
          .post(url, headers: getHeader(), body: body)
          .timeout(requestTimeout);
      return handleResponse(response, (jsonResp) {
        final cr = CommonResponse.fromJson(jsonResp);
        return (cr.code == "0000");
      });
    } catch (e) {
      debugPrint("[Exception] requestFindIdSendCode() => ${e.toString()}");
      return false;
    }
  }

  Future<Map<String, dynamic>> requestFindIdVerifyCodeWithData(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(findIdVerifyCodePath);
    final body = jsonEncode(params);

    try {
      final http.Response response = await http
          .post(url, headers: getHeader(), body: body)
          .timeout(requestTimeout);
      return handleResponse(response, (jsonResp) {
        final cr = CommonResponse.fromJson(jsonResp);

        if (cr.code == "0000" && cr.body != null) {
          final userId = cr.body['user_id'] ?? '';
          final joinDate = cr.body['join_date'] ?? '';
          final verifyToken = cr.body['verifyToken'] ?? '';
          final email = cr.body['email'] ?? '';

          return {
            'success': true,
            'userId': userId,
            'joinDate': joinDate,
            'verifyToken': verifyToken,
            'email': email,
          };
        } else {
          return {
            'success': false,
          };
        }
      });
    } catch (e) {
      debugPrint("[Exception] requestFindIdVerifyCodeWithData() => $e");
      return {
        'success': false,
      };
    }
  }
}
