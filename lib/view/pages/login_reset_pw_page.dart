import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/password_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_reset_final_page.dart';

class LoginResetPwPage extends StatefulWidget {
  static const String routeName = '/reset-pw';

  const LoginResetPwPage({super.key});

  @override
  State<LoginResetPwPage> createState() => _LoginResetPwPageState();
}

class _LoginResetPwPageState extends State<LoginResetPwPage> {
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();

  final FocusNode _pwFocusNode = FocusNode();
  final FocusNode _pwConfirmFocusNode = FocusNode();

  bool _showPassword = false;
  bool _showConfirm = false;

  final RegExp _regexPassword = RegExp(
    r'^(?=.*[0-9])(?=.*[a-zA-Z])(?=.*[^a-zA-Z0-9]).{8,16}$',
  );

  @override
  void dispose() {
    _pwController.dispose();
    _pwConfirmController.dispose();
    _pwFocusNode.dispose();
    _pwConfirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onTapConfirm() async {
    final String pw1 = _pwController.text.trim();
    final String pw2 = _pwConfirmController.text.trim();

    if (pw1.isEmpty || pw2.isEmpty) {
      Utils.showSnackBar(t('비밀번호를 입력하세요.'), isError: true);
      return;
    }
    if (pw1 != pw2) {
      Utils.showSnackBar(t('비밀번호가 서로 일치하지 않습니다.'), isError: true);
      return;
    }
    if (!_regexPassword.hasMatch(pw1)) {
      Utils.showSnackBar(t('비밀번호는 영문, 숫자, 특수문자를 포함해 8~16자로 입력해주세요.'), isError: true);
      return;
    }

    final PasswordController passwordCtrl = Get.find<PasswordController>();
    final dynamic response = await passwordCtrl.reqPasswordComplete(pw1);
    if (response == null) {
      Utils.showSnackBar(t('서버 요청 오류 (reqPasswordComplete null).'), isError: true);
      return;
    }
    if (response.code == '0000') {
      Utils.showSnackBar(t('비밀번호가 변경되었습니다!'));
      Get.offAllNamed(LoginResetFinalPage.routeName);
    } else {
      Utils.showSnackBar(
        l10n('비밀번호 변경 실패: ${response.message}', 'Password change failed: ${response.message}'),
        isError: true,
      );
    }
  }

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
              t('비밀번호 재설정'),
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
              t('영문, 숫자, 특수문자를 함께 사용하면 (8~16자) 보다 안전합니다.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 36),
            AuthFieldLabel(text: t('새 비밀번호')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _pwController,
              focusNode: _pwFocusNode,
              hintText: t('비밀번호를 입력하세요.'),
              prefixIconData: CupertinoIcons.lock,
              obscureText: !_showPassword,
              suffixIconData: _showPassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              onSuffixTapped: () => setState(() => _showPassword = !_showPassword),
            ),
            const SizedBox(height: 20),
            AuthFieldLabel(text: t('비밀번호 확인')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _pwConfirmController,
              focusNode: _pwConfirmFocusNode,
              hintText: t('비밀번호를 한 번 더 입력하세요.'),
              prefixIconData: CupertinoIcons.lock,
              obscureText: !_showConfirm,
              suffixIconData: _showConfirm ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              onSuffixTapped: () => setState(() => _showConfirm = !_showConfirm),
            ),
            const SizedBox(height: 40),
            AuthPrimaryButton(text: t('확인'), onTap: _onTapConfirm),
          ],
        ),
      ),
    );
  }
}
