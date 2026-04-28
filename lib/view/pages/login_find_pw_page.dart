import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/password_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_page.dart';
import 'login_reset_pw_page.dart';

class LoginFindPwPage extends StatefulWidget {
  static const String routeName = '/find-pw';

  const LoginFindPwPage({super.key});

  @override
  State<LoginFindPwPage> createState() => _LoginFindPwPageState();
}

class _LoginFindPwPageState extends State<LoginFindPwPage> {
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  final FocusNode _userIdFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  String _codeErrorMsg = '';

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _userIdFocusNode.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    final String userId = _userIdCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    if (userId.isEmpty || email.isEmpty) {
      Utils.showSnackBar(t('아이디와 메일을 입력하세요.'), isError: true);
      return;
    }

    final PasswordController passwordCtrl = Get.find<PasswordController>();
    final dynamic response = await passwordCtrl.reqResetPassword(email);
    if (response == null) {
      Utils.showSnackBar(t('서버 오류가 발생했습니다.'), isError: true);
      return;
    }
    if (response.code == '0000') {
      Utils.showSnackBar(t('인증메일을 보냈습니다. 메일을 확인해주세요.'));
    } else {
      Utils.showSnackBar(
        l10n('메일 전송 실패: ${response.message}', 'Failed to send email: ${response.message}'),
        isError: true,
      );
    }
  }

  Future<void> _onVerifyCode() async {
    final String userId = _userIdCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    if (userId.isEmpty || email.isEmpty) {
      Utils.showSnackBar(t('아이디와 메일을 입력하세요.'), isError: true);
      return;
    }

    setState(() => _codeErrorMsg = '');
    final String code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeErrorMsg = t('인증번호를 입력하세요.'));
      return;
    }

    final PasswordController passwordCtrl = Get.find<PasswordController>();
    final dynamic verifyRes = await passwordCtrl.reqPasswordVerifyCode(email, code);
    if (verifyRes == null) {
      setState(() => _codeErrorMsg = t('서버 오류가 발생했습니다.'));
      return;
    }

    if (verifyRes.code == '0000') {
      Utils.showSnackBar(t('인증되었습니다! 비밀번호를 재설정하세요.'));
      Get.offAllNamed(LoginResetPwPage.routeName);
    } else {
      setState(() => _codeErrorMsg = t('인증번호가 올바르지 않습니다.'));
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
              t('비밀번호 찾기'),
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
              t('아이디와 메일로 비밀번호를 재설정하세요.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 36),
            AuthFieldLabel(text: t('아이디')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _userIdCtrl,
              focusNode: _userIdFocusNode,
              hintText: t('아이디를 입력하세요.'),
              prefixIconData: CupertinoIcons.person,
            ),
            const SizedBox(height: 20),
            AuthFieldLabel(text: t('메일')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _emailCtrl,
              focusNode: _emailFocusNode,
              hintText: t('가입에 사용한 메일을 입력하세요.'),
              prefixIconData: CupertinoIcons.mail,
            ),
            const SizedBox(height: 10),
            AuthOutlineButton(text: t('인증메일 보내기'), onTap: _onSendCode),
            const SizedBox(height: 20),
            AuthFieldLabel(text: t('인증번호')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _codeCtrl,
              focusNode: _codeFocusNode,
              hintText: t('인증번호를 입력해 주세요.'),
              prefixIconData: CupertinoIcons.shield,
              errorText: _codeErrorMsg.isNotEmpty ? _codeErrorMsg : null,
            ),
            const SizedBox(height: 32),
            AuthPrimaryButton(text: t('확인'), onTap: _onVerifyCode),
            const SizedBox(height: 24),
            AuthBackLink(
              text: t('← 로그인으로 돌아가기'),
              onTap: () => Get.offAllNamed(LoginPage.routeName),
            ),
          ],
        ),
      ),
    );
  }
}
