import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_page.dart';

class SignUpFinalPage extends StatelessWidget {
  static const String routeName = '/signup-final';

  const SignUpFinalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => AuthPageShell(
        formChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              t('회원가입'),
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
              t('회원가입이 완료되었습니다.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 48),
            const Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Color(0xFF48BB78),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                t('가입이 완료되었습니다!\n로그인 후 서비스를 이용해보세요.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF4A5568),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 48),
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
