import 'package:get/get.dart';
import '../../model/common_model.dart';
import '../repository/password_repository.dart';

// Shared password policy: 8-16 chars with a letter, a digit and a special char.
final RegExp _passwordPolicy = RegExp(
  r'^(?=.*[0-9])(?=.*[a-zA-Z])(?=.*[^a-zA-Z0-9]).{8,16}$',
);

bool isValidPasswordPolicy(String password) => _passwordPolicy.hasMatch(password);

class PasswordController extends GetxController {
  final PasswordRepository _repo = PasswordRepository();

  String? verifyToken;
  String? resetEmail;

  // Email reset; the backend also checks the ID when it is sent.
  Future<CommonResponse?> reqResetPassword(String email, {String? userId}) async {
    return _repo.requestResetPassword(email, userId: userId);
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
}
