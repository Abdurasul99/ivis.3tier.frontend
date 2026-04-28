import 'package:flutter/foundation.dart';
import 'package:ivis/viewmodel/controller/password_controller.dart';
import 'package:get/get.dart';

import '../../model/user_model.dart';
import '../repository/local_repository.dart';
import '../repository/user_repository.dart';

class UserController extends GetxController {
  LoginUser? _loginUser;
  String? _accessToken;

  String foundUserId = '';
  String foundJoinDate = '';

  /// 테스트 전용 — 로그인 유저 직접 주입
  @visibleForTesting
  set loginUserForTest(LoginUser? user) => _loginUser = user;

  /// 테스트 전용 — 액세스 토큰 직접 주입
  @visibleForTesting
  set accessTokenForTest(String? token) => _accessToken = token;

  LoginUser? get loginUser => _loginUser;
  String? get accessToken => _accessToken;

  /// Load token from local storage into memory for direct route refresh cases.
  Future<bool> ensureAccessTokenLoaded() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return true;
    }

    final String storedToken = await LocalRepository().getAccessToken();
    if (storedToken.isEmpty) {
      return false;
    }

    _accessToken = storedToken;
    update();
    return true;
  }

  Future<bool> reqSignUpByIdAndEmail(
    String userId,
    String email,
    String name,
    String phoneNumber,
    String password,
  ) async {
    final params = {
      "user_id": userId,
      "email": email,
      "name": name,
      "phone_number": phoneNumber,
      "password": password,
    };

    final response = await UserRepository().requestSignUpByIdAndEmail(params);
    if (response != null && response.code == "0000") {
      return true;
    }
    return false;
  }

  Future<bool> reqLoginById(String userId, String password) async {
    final params = {
      "user_id": userId,
      "password": password,
    };

    final loginResult = await UserRepository().requestLoginById(params);
    if (loginResult != null && loginResult.code == "0000") {
      _loginUser = loginResult.loginUser;
      _accessToken = loginResult.loginUser?.accessToken ?? "";
      final refreshToken = loginResult.loginUser?.refreshToken ?? "";
      await LocalRepository().saveAccessToken(_accessToken!);
      if (refreshToken.isNotEmpty) {
        await LocalRepository().saveRefreshToken(refreshToken);
      }
      update();
      return true;
    }
    return false;
  }

  /// 리프레시 토큰으로 액세스 토큰을 갱신한다.
  /// 성공 시 새 토큰을 저장하고 true 반환. 실패 시 false.
  Future<bool> refreshAccessToken() async {
    final storedRefresh = await LocalRepository().getRefreshToken();
    if (storedRefresh.isEmpty) return false;

    final newAccessToken = await UserRepository().requestRefreshAccessToken(storedRefresh);
    if (newAccessToken == null || newAccessToken.isEmpty) return false;

    _accessToken = newAccessToken;
    await LocalRepository().saveAccessToken(newAccessToken);
    update();
    return true;
  }

  /// 앱 시작/새로고침 시 저장된 토큰으로 자동 로그인을 시도한다.
  /// 1단계: 액세스 토큰으로 signInByToken 시도
  /// 2단계: 실패 시 리프레시 토큰으로 새 액세스 토큰 발급 후 재시도
  /// 3단계: 모두 실패 시 false 반환 → 로그인 페이지로
  Future<bool> reqLoginByToken() async {
    final storedToken = await LocalRepository().getAccessToken();
    if (storedToken.isEmpty) return false;

    // 메모리에 토큰 즉시 세팅 (API 헤더 준비)
    _accessToken = storedToken;
    update();

    // 1단계: 액세스 토큰으로 직접 로그인 시도
    final loginResult = await UserRepository().requestLoginByToken(storedToken);
    if (loginResult != null && loginResult.code == "0000") {
      _loginUser = loginResult.loginUser;
      _accessToken = loginResult.loginUser?.accessToken ?? storedToken;
      final refreshToken = loginResult.loginUser?.refreshToken ?? "";
      await LocalRepository().saveAccessToken(_accessToken!);
      if (refreshToken.isNotEmpty) {
        await LocalRepository().saveRefreshToken(refreshToken);
      }
      update();
      return true;
    }

    // 2단계: 액세스 토큰 만료 → 리프레시 토큰으로 새 액세스 토큰 발급
    final refreshed = await refreshAccessToken();
    if (!refreshed) {
      // 리프레시 토큰도 만료됨 → 완전 로그아웃
      await logout();
      return false;
    }

    // 3단계: 새 액세스 토큰으로 재시도
    final retryResult = await UserRepository().requestLoginByToken(_accessToken!);
    if (retryResult != null && retryResult.code == "0000") {
      _loginUser = retryResult.loginUser;
      _accessToken = retryResult.loginUser?.accessToken ?? _accessToken;
      final refreshToken = retryResult.loginUser?.refreshToken ?? "";
      await LocalRepository().saveAccessToken(_accessToken!);
      if (refreshToken.isNotEmpty) {
        await LocalRepository().saveRefreshToken(refreshToken);
      }
      update();
      return true;
    }

    // 모두 실패 → 로그아웃
    await logout();
    return false;
  }

  Future<String> reqChangePassword(Map<String, dynamic> params) async {
    return await UserRepository().requestChangePassword(params);
  }

  Future<bool> reqChangePhoneNumber(Map<String, dynamic> params) async {
    final result = await UserRepository().requestChangePhoneNumber(params);
    if (result) {
      if (_loginUser != null) {
        _loginUser!.phoneNumber = params['phoneNumber'];
      }
      update();
    }
    return result;
  }

  Future<bool> reqUpdateProfileImage(Map<String, dynamic> params) async {
    bool result = await UserRepository().requestUpdateProfileImage(params);
    if (result) {
      if (_loginUser != null) {
        _loginUser!.imageUrl = params['imageUrl'];
      }
      update();
    }
    return result;
  }

  Future<bool> reqFindIdSendCode(String name, String email) async {
    final params = {"name": name, "email": email};
    return await UserRepository().requestFindIdSendCode(params);
  }

  Future<bool> reqFindIdVerifyCode(String email, String code) async {
    final params = {"email": email, "code": code};

    final resultMap = await UserRepository().requestFindIdVerifyCodeWithData(params);
    if (resultMap['success'] == true) {
      foundUserId = resultMap['userId'] ?? '';
      foundJoinDate = resultMap['joinDate'] ?? '';

      final vt = resultMap['verifyToken'];
      final em = resultMap['email'];
      if (vt != null && vt is String && vt.isNotEmpty && em != null) {
        final passCtrl = Get.find<PasswordController>();
        passCtrl.verifyToken = vt;
        passCtrl.resetEmail = em;
      }
      return true;
    }
    return false;
  }

  Future<bool> reqSaveRememberMe(bool rememberMe) async {
    return await LocalRepository().saveRememberMe(rememberMe);
  }

  Future<bool> reqGetRememberMe() async {
    return await LocalRepository().getRememberMe();
  }

  Future<bool> reqSaveLoginEmail(String loginEmail) async {
    return await LocalRepository().saveLoginEmail(loginEmail);
  }

  Future<String> reqGetLoginEmail() async {
    return await LocalRepository().getLoginEmail();
  }

  Future<void> logout() async {
    _loginUser = null;
    _accessToken = null;
    await LocalRepository().clearAccessToken();
    await LocalRepository().clearRefreshToken();
    update();
  }

  bool isAdminUser() {
    if (_loginUser != null) {
      return (_loginUser!.role == "admin");
    }

    return false;
  }
}
