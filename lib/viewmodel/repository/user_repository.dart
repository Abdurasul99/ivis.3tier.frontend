import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../model/common_model.dart';
import '../../model/user_model.dart';
import 'base_repository.dart';

/// Result of checking a stored token against the server.
enum TokenCheckStatus {
  ok,

  /// The server refused the token (expired / invalid / unknown user).
  rejected,

  /// Timeout, network error or 5xx: the token may still be valid.
  unreachable,
}

class TokenRefreshOutcome {
  final TokenCheckStatus status;
  final String? accessToken;
  const TokenRefreshOutcome(this.status, {this.accessToken});
}

class TokenLoginOutcome {
  final TokenCheckStatus status;
  final LoginResult? result;
  const TokenLoginOutcome(this.status, {this.result});
}

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

  /// A 4xx answer that carries the backend envelope: wrong password (8003), unknown user (8002) ...
  /// Returned to the caller instead of a generic failure; null when there is no envelope.
  T? _envelopeOf<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    final Map<String, dynamic>? envelope = errorEnvelope(response);
    if (envelope == null) return null;
    try {
      return parse(envelope);
    } catch (_) {
      return null;
    }
  }

  /// 401/403 or a backend error code on a 4xx: the token itself was refused.
  /// Timeouts, network errors, 5xx and unreadable answers are "unreachable".
  TokenCheckStatus _failureStatusOf(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return TokenCheckStatus.rejected;
    }
    return errorEnvelope(response) != null
        ? TokenCheckStatus.rejected
        : TokenCheckStatus.unreachable;
  }

  Future<CommonResponse?> requestSignUpByIdAndEmail(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(signUpByIdEmailPath);
    final body = jsonEncode(params);

    try {
      final response = await http.post(
        url,
        headers: getHeader(includeToken: false),
        body: body,
      ).timeout(requestTimeout);
      final CommonResponse? failure = _envelopeOf(response, CommonResponse.fromJson);
      if (failure != null) return failure;
      return handleResponse(response, (jsonResp) {
        return CommonResponse.fromJson(jsonResp);
      });
    } catch (e) {
      debugPrint("[Exception] requestSignUpByIdAndEmail => $e");
      return null;
    }
  }

  /// On a 4xx with the backend envelope the result carries its code/message (loginUser is null).
  Future<LoginResult?> requestLoginById(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(loginByIdPath);
    final body = jsonEncode(params);

    try {
      final response = await http.post(
        url,
        headers: getHeader(includeToken: false),
        body: body,
      ).timeout(requestTimeout);
      final LoginResult? failure = _envelopeOf(response, LoginResult.fromJson);
      if (failure != null) return failure;
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
    return (await requestRefreshAccessTokenChecked(refreshToken)).accessToken;
  }

  /// Same call, but tells a refused refresh token apart from an unreachable server.
  Future<TokenRefreshOutcome> requestRefreshAccessTokenChecked(String refreshToken) async {
    final Uri url = buildApiUri(refreshTokenPath);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'x-access-token': refreshToken,
    };
    try {
      final http.Response response =
          await http.post(url, headers: headers).timeout(requestTimeout);
      if (response.statusCode != 200) {
        return TokenRefreshOutcome(_failureStatusOf(response));
      }
      final dynamic json = jsonDecode(utf8.decode(response.bodyBytes));
      final String? newToken = json?['body']?['accessToken']?.toString();
      if (newToken == null || newToken.isEmpty) {
        return const TokenRefreshOutcome(TokenCheckStatus.unreachable);
      }
      return TokenRefreshOutcome(TokenCheckStatus.ok, accessToken: newToken);
    } catch (e) {
      debugPrint("[Exception] requestRefreshAccessToken => $e");
      return const TokenRefreshOutcome(TokenCheckStatus.unreachable);
    }
  }

  Future<LoginResult?> requestLoginByToken(String token) async {
    return (await requestLoginByTokenChecked(token)).result;
  }

  /// Same call, but tells a refused token apart from an unreachable server.
  Future<TokenLoginOutcome> requestLoginByTokenChecked(String token) async {
    final Uri url = buildApiUri(loginByTokenPath);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'x-access-token': token,
    };

    try {
      final http.Response response =
          await http.post(url, headers: headers).timeout(requestTimeout);
      if (response.statusCode != 200) {
        return TokenLoginOutcome(_failureStatusOf(response));
      }
      final LoginResult result = handleResponse(response, (jsonResp) {
        return LoginResult.fromJson(jsonResp);
      });
      if (result.code != "0000") {
        return TokenLoginOutcome(TokenCheckStatus.rejected, result: result);
      }
      return TokenLoginOutcome(TokenCheckStatus.ok, result: result);
    } catch (e) {
      debugPrint("[Exception] requestLoginByToken => $e");
      return const TokenLoginOutcome(TokenCheckStatus.unreachable);
    }
  }

  Future<String> requestChangePassword(Map<String, dynamic> params) async {
    final Uri url = buildApiUri(changePasswordPath);
    final body = jsonEncode(params);

    try {
      final http.Response response = await safePost(url, body: body);

      // The backend sends 8003 (wrong current password) with HTTP 400.
      if (errorEnvelope(response)?['code'] == "8003") {
        return "wrong password";
      }

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
      final http.Response response = await safePost(url, body: body);

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
      final http.Response response = await safePost(url, body: body);
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
