import 'package:fms/viewmodel/controller/password_controller.dart';
import 'package:get/get.dart';

import '../../model/user_model.dart';
import '../repository/local_repository.dart';
import '../repository/user_repository.dart';

class UserController extends GetxController {
  LoginUser? _loginUser;
  String? _accessToken;

  String foundUserId = '';
  String foundJoinDate = '';

  LoginUser? get loginUser => _loginUser;
  String? get accessToken => _accessToken;

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
      await LocalRepository().saveAccessToken(_accessToken!);
      update();
      return true;
    }
    return false;
  }

  Future<bool> reqLoginByToken() async {
    final storedToken = await LocalRepository().getAccessToken();
    if (storedToken.isEmpty) {
      return false;
    }

    final loginResult = await UserRepository().requestLoginByToken(storedToken);
    if (loginResult != null && loginResult.code == "0000") {
      _loginUser = loginResult.loginUser;
      _accessToken = loginResult.loginUser?.accessToken ?? "";
      await LocalRepository().saveAccessToken(_accessToken!);
      update();
      return true;
    }
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
    update();
  }

  bool isAdminUser() {
    if (_loginUser != null) {
      return (_loginUser!.role == "admin");
    }

    return false;
  }
}
