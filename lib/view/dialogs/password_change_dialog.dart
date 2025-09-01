// lib/view/dialogs/password_change_dialog.dart
//
// A dialog to change password, from GitHub code.
// You can integrate your userController logic as needed.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/utils.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_text.dart';
import '../components/text_title.dart';

class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({super.key});

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _rePasswordController = TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _rePasswordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    _rePasswordController.dispose();

    _passwordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _rePasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = 499;
    if (screenWidth < dialogWidth) {
      dialogWidth = screenWidth - 16;
    }

    return Dialog(
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              offset: Offset(0, 0.0),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Container(
              height: 30,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: const Text(
                "비밀번호 변경",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: const Text(
                "영문, 숫자, 특수문자등을 함께 사용하면 (8자 이상 16자 이하) 보다 안전합니다.",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  const TextTitle(
                    titleText: "현재 비밀번호",
                    cellHeight: 20,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontColor: Color(0xFF666565),
                    padding: EdgeInsets.all(0),
                  ),
                  const SizedBox(height: 6),
                  InputEditText(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hintText: "현재 비밀번호를 입력하세요.",
                    isObscureText: true,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _newPasswordFocusNode.requestFocus();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const TextTitle(
                    titleText: "변경할 비밀번호",
                    cellHeight: 20,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontColor: Color(0xFF666565),
                    padding: EdgeInsets.all(0),
                  ),
                  const SizedBox(height: 6),
                  InputEditText(
                    controller: _newPasswordController,
                    focusNode: _newPasswordFocusNode,
                    hintText: "변경할 비밀번호를 입력하세요.",
                    isObscureText: true,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _rePasswordFocusNode.requestFocus();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const TextTitle(
                    titleText: "비밀번호 확인",
                    cellHeight: 20,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontColor: Color(0xFF666565),
                    padding: EdgeInsets.all(0),
                  ),
                  const SizedBox(height: 6),
                  InputEditText(
                    controller: _rePasswordController,
                    focusNode: _rePasswordFocusNode,
                    hintText: "변경할 비밀번호를 다시 입력하세요.",
                    isObscureText: true,
                    onSubmitted: (value) {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: GradientButton(
                    buttonText: "확 인",
                    buttonColor: const Color(0xFF005FB8),
                    onTap: () async {
                      if (_passwordController.text.isEmpty) {
                        Utils.showSnackBar("비밀번호를 입력하세요.", isError: true);
                        _passwordFocusNode.requestFocus();
                        return;
                      }

                      if (_newPasswordController.text.isEmpty) {
                        Utils.showSnackBar("변경할 비밀번호를 입력하세요.", isError: true);
                        _newPasswordFocusNode.requestFocus();
                        return;
                      }

                      if (_rePasswordController.text.isEmpty) {
                        Utils.showSnackBar("변경할 비밀번호를 다시 입력하세요.", isError: true);
                        _rePasswordFocusNode.requestFocus();
                        return;
                      }

                      if (_newPasswordController.text != _rePasswordController.text) {
                        Utils.showSnackBar("변경할 비밀번호가 일치하지 않습니다.", isError: true);
                        _rePasswordFocusNode.requestFocus();
                        return;
                      }

                      Map<String, dynamic> params = {};
                      params['email'] = Get.find<UserController>().loginUser!.email;
                      params['password'] = _passwordController.text;
                      params['newpassword'] = _newPasswordController.text;

                      String result = await Get.find<UserController>().reqChangePassword(params);

                      if ("changed password" != result) {
                        Utils.showSnackBar("비밀번호가 맞지 않습니다", isError: true);
                        return;
                      }

                      Get.back();
                      Utils.showSnackBar("비밀번호가 변경되었습니다.");
                    },
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: GradientButton(
                    buttonText: "취 소",
                    onTap: () {
                      Get.back();
                    },
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
