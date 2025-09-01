import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/common_model.dart';
import '../repository/register_repository.dart';

class RegisterController extends GetxController {
  final RegisterRepository _repo = RegisterRepository();

  String? verifyToken; // stored after verifying code

  // Step 1: send code
  Future<bool> sendRegisterCode(String name, String email) async {
    final CommonResponse? resp = await _repo.requestRegisterSendCode(name, email);
    if (resp == null) return false;
    if (resp.code == "0000") {
      // success
      return true;
    } else {
      debugPrint("sendRegisterCode failed => ${resp.message}");
      return false;
    }
  }

  // Step 2: verify code => store verifyToken
  Future<bool> verifyRegisterCode(String email, String code) async {
    final CommonResponse? resp = await _repo.requestRegisterVerifyCode(email, code);
    if (resp == null) return false;
    if (resp.code == "0000") {
      // success
      verifyToken = resp.body["verifyToken"];
      return true;
    } else {
      debugPrint("verifyRegisterCode failed => ${resp.message}");
      return false;
    }
  }

  // Step 3: complete registration
  Future<bool> completeRegister({
    required String email,
    required String userId,
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    if (verifyToken == null || verifyToken!.isEmpty) {
      debugPrint("No verifyToken stored, can't completeRegister.");
      return false;
    }

    final CommonResponse? resp = await _repo.requestRegisterComplete(
      email: email,
      userId: userId,
      name: name,
      phoneNumber: phoneNumber,
      password: password,
      verifyToken: verifyToken!,
    );
    if (resp == null) return false;

    if (resp.code == "0000") {
      // success
      return true;
    } else {
      debugPrint("completeRegister failed => ${resp.message}");
      return false;
    }
  }
}
