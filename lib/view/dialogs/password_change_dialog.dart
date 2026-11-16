import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/password_controller.dart';
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

  // In-flight guard; nothing is rendered from it.
  bool _submitting = false;

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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dialogWidth = screenWidth < 499 ? screenWidth - 16 : 499;

    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => Dialog(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, 0),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 24),
              Container(
                height: 30,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  t('비밀번호 변경'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  l10n(
                    '영문, 숫자, 특수문자등을 함께 사용하면 (8자 이상 16자 이하) 보다 안전합니다.',
                    'Using letters, numbers, and special characters together is safer (8 to 16 characters).',
                  ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  children: <Widget>[
                    TextTitle(
                      titleText: l10n('현재 비밀번호', 'Current Password'),
                      cellHeight: 20,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontColor: const Color(0xFF666565),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    InputEditText(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      hintText: l10n('현재 비밀번호를 입력하세요.', 'Enter your current password.'),
                      isObscureText: true,
                      onSubmitted: (String value) {
                        if (value.isNotEmpty) _newPasswordFocusNode.requestFocus();
                      },
                    ),
                    const SizedBox(height: 24),
                    TextTitle(
                      titleText: l10n('변경할 비밀번호', 'New Password'),
                      cellHeight: 20,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontColor: const Color(0xFF666565),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    InputEditText(
                      controller: _newPasswordController,
                      focusNode: _newPasswordFocusNode,
                      hintText: l10n('변경할 비밀번호를 입력하세요.', 'Enter the new password.'),
                      isObscureText: true,
                      onSubmitted: (String value) {
                        if (value.isNotEmpty) _rePasswordFocusNode.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),
                    TextTitle(
                      titleText: t('비밀번호 확인'),
                      cellHeight: 20,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontColor: const Color(0xFF666565),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    InputEditText(
                      controller: _rePasswordController,
                      focusNode: _rePasswordFocusNode,
                      hintText: l10n('변경할 비밀번호를 다시 입력하세요.', 'Enter the new password again.'),
                      isObscureText: true,
                      onSubmitted: (_) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  const SizedBox(width: 36),
                  Expanded(
                    child: GradientButton(
                      buttonText: t('확인'),
                      buttonColor: const Color(0xFF005FB8),
                      onTap: () async {
                        if (_submitting) return;
                        // Trimmed like login / signup / reset.
                        final String currentPw = _passwordController.text.trim();
                        final String newPw = _newPasswordController.text.trim();
                        final String rePw = _rePasswordController.text.trim();
                        if (currentPw.isEmpty) {
                          Utils.showSnackBar(t('비밀번호를 입력하세요.'), isError: true);
                          _passwordFocusNode.requestFocus();
                          return;
                        }
                        if (newPw.isEmpty) {
                          Utils.showSnackBar(
                            l10n('변경할 비밀번호를 입력하세요.', 'Enter the new password.'),
                            isError: true,
                          );
                          _newPasswordFocusNode.requestFocus();
                          return;
                        }
                        if (rePw.isEmpty) {
                          Utils.showSnackBar(
                            l10n('변경할 비밀번호를 다시 입력하세요.', 'Enter the new password again.'),
                            isError: true,
                          );
                          _rePasswordFocusNode.requestFocus();
                          return;
                        }
                        if (newPw != rePw) {
                          Utils.showSnackBar(
                            l10n('변경할 비밀번호가 일치하지 않습니다.', 'The new passwords do not match.'),
                            isError: true,
                          );
                          _rePasswordFocusNode.requestFocus();
                          return;
                        }
                        // Same policy as the reset page.
                        if (!isValidPasswordPolicy(newPw)) {
                          Utils.showSnackBar(
                            t('비밀번호는 영문, 숫자, 특수문자를 포함해 8~16자로 입력해주세요.'),
                            isError: true,
                          );
                          _newPasswordFocusNode.requestFocus();
                          return;
                        }

                        final UserController userController = Get.find<UserController>();
                        final Map<String, dynamic> params = <String, dynamic>{
                          'email': userController.loginUser?.email,
                          'password': currentPw,
                          'newpassword': newPw,
                        };

                        _submitting = true;
                        final String result;
                        try {
                          result = await userController.reqChangePassword(params);
                        } finally {
                          _submitting = false;
                        }
                        if (result == 'wrong password') {
                          Utils.showSnackBar(
                            l10n('비밀번호가 맞지 않습니다', 'Current password is incorrect.'),
                            isError: true,
                          );
                          return;
                        }
                        if (result != 'changed password') {
                          Utils.showSnackBar(
                            l10n('비밀번호 변경에 실패했습니다.', 'Failed to change the password.'),
                            isError: true,
                          );
                          return;
                        }

                        Get.back();
                        Utils.showSnackBar(t('비밀번호가 변경되었습니다!'));
                      },
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: GradientButton(
                      buttonText: t('취소'),
                      onTap: () => Get.back(),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
