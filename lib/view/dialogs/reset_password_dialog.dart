// lib/view/dialogs/reset_password_dialog.dart
//
// A dialog that asks for email to send code.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../components/input_edit_text.dart';

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
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
                      "Enter your email. If it exists, we will send a 4-digit code.",
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 14,
                        color: kGrayFontColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputEditText(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      hintText: "Email",
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            if (_emailController.text.isEmpty) {
                              Utils.showSnackBar("이메일을 입력하세요", isError: true);
                              _emailFocusNode.requestFocus();
                              return;
                            }
                            Get.back(result: _emailController.text);
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
                                  child: Icon(CupertinoIcons.check_mark_circled,
                                      size: 18, color: Colors.white),
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
            "🔐 Reset Password",
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
