import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/password_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_page.dart';
import 'login_reset_pw_page.dart';

class LoginCheckIdPage extends StatelessWidget {
  static const String routeName = '/check-id';

  const LoginCheckIdPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<dynamic, dynamic> args = Get.arguments ?? <String, dynamic>{};
    final String userId = args['userId']?.toString() ?? 'unknown';
    final String joinDate = args['joinDate']?.toString() ?? '';

    final String verifyToken = args['verifyToken']?.toString() ?? '';
    if (verifyToken.isNotEmpty) {
      final PasswordController passwordCtrl = Get.find<PasswordController>();
      passwordCtrl.verifyToken = verifyToken;
      final String foundEmail = args['foundEmail']?.toString() ?? '';
      if (foundEmail.isNotEmpty) {
        passwordCtrl.resetEmail = foundEmail;
      }
    }

    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => AuthPageShell(
        formChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              t('아이디 찾기'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A1628),
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n('고객님의 정보와 일치하는 아이디입니다.', 'This ID matches your account information.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n('아이디 : $userId', 'ID: $userId'),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A202C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (joinDate.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      l10n('가입일 : $joinDate', 'Joined: $joinDate'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8A94A6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            AuthOutlineButton(
              text: t('비밀번호 재설정'),
              onTap: () => Get.offAllNamed(LoginResetPwPage.routeName),
            ),
            const SizedBox(height: 12),
            AuthPrimaryButton(
              text: t('로그인'),
              onTap: () => Get.offAllNamed(LoginPage.routeName),
            ),
          ],
        ),
      ),
    );
  }
}
