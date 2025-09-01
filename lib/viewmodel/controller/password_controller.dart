import 'package:get/get.dart';
import '../../model/common_model.dart';
import '../repository/password_repository.dart';

class PasswordController extends GetxController {
  final PasswordRepository _repo = PasswordRepository();

  String? verifyToken;
  String? resetEmail;
  String? resetUserId;

  // Regular email reset
  Future<CommonResponse?> reqResetPassword(String email) async {
    return _repo.requestResetPassword(email);
  }

  Future<CommonResponse?> reqPasswordVerifyCode(
      String email, String code) async {
    final res = await _repo.requestVerifyCode(email, code);
    if (res != null && res.code == "0000") {
      if (res.body != null && res.body["verifyToken"] != null) {
        verifyToken = res.body["verifyToken"];
        resetEmail = email;
      }
    }
    return res;
  }

  Future<CommonResponse?> reqPasswordComplete(String newPassword) async {
    if (verifyToken == null || resetEmail == null) {
      return null;
    }
    return _repo.requestCompletePassword(
        resetEmail!, newPassword, verifyToken!);
  }

  // ID + Email version
  Future<CommonResponse?> reqResetPasswordByIdAndEmail(
      String userId, String email) async {
    final res = await _repo.requestResetPasswordByIdAndEmail(userId, email);
    if (res != null && res.code == "0000") {
      resetUserId = userId;
      resetEmail = email;
    }
    return res;
  }

  Future<CommonResponse?> reqPasswordVerifyCodeByIdAndEmail(String code) async {
    if (resetEmail == null || resetUserId == null) {
      return null;
    }
    final res = await _repo.requestVerifyCodeByIdAndEmail(
        resetUserId!, resetEmail!, code);
    if (res != null && res.code == "0000") {
      if (res.body != null && res.body["verifyToken"] != null) {
        verifyToken = res.body["verifyToken"];
      }
    }
    return res;
  }
}
