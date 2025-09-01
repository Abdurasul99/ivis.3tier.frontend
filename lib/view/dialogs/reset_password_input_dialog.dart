// lib/view/dialogs/reset_password_input_dialog.dart
//
// A dialog to set new password after verifying the code.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../components/input_edit_text.dart';

class ResetPasswordInputDialog extends StatefulWidget {
  const ResetPasswordInputDialog({super.key});

  @override
  State<ResetPasswordInputDialog> createState() =>
      _ResetPasswordInputDialogState();
}

class _ResetPasswordInputDialogState extends State<ResetPasswordInputDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmFocusNode = FocusNode();

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
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(1),
          boxShadow: const [
            BoxShadow(
                color: Colors.black, offset: Offset(0, 0.5), blurRadius: 0.5),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(color: kMainColor, height: 6, width: double.infinity),
              buildHeader(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      "비밀번호 설정",
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 14,
                        color: kGrayFontColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputEditText(
                      title: "New Password",
                      isRequired: true,
                      isObscureText: true,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      hintText: "password",
                      onSubmitted: (value) {
                        _confirmFocusNode.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),
                    InputEditText(
                      title: "Confirm Password",
                      isRequired: true,
                      isObscureText: true,
                      controller: _confirmController,
                      focusNode: _confirmFocusNode,
                      hintText: "Confirm password",
                      onSubmitted: (value) {
                        _confirmFocusNode.requestFocus();
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            if (_passwordController.text.isEmpty) {
                              Utils.showSnackBar("비밀번호를 입력하세요.", isError: true);
                              _passwordFocusNode.requestFocus();
                              return;
                            }
                            if (_confirmController.text.isEmpty) {
                              Utils.showSnackBar("확인 비밀번호를 입력하세요.",
                                  isError: true);
                              _confirmFocusNode.requestFocus();
                              return;
                            }
                            if (_passwordController.text.trim() !=
                                _confirmController.text.trim()) {
                              Utils.showSnackBar("비밀번호가 일치하지 않습니다.",
                                  isError: true);
                              _confirmFocusNode.requestFocus();
                              return;
                            }

                            // Return the new password to the caller:
                            Get.back(result: _passwordController.text);
                          },
                          child: Container(
                            height: 40,
                            width: 90,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Icon(
                                    CupertinoIcons.check_mark_circled,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Padding(
                                  padding: EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    "확인",
                                    style: TextStyle(
                                      fontFamily: 'medium',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          const Text(
            "🔐 Set New Password",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(4.0),
                color: Colors.black,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
