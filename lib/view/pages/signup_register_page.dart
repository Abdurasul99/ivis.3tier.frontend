import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/register_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_page.dart';
import 'signup_page.dart';

class SignupRegisterPage extends StatefulWidget {
  static const String routeName = '/register-first';

  const SignupRegisterPage({super.key});

  @override
  State<SignupRegisterPage> createState() => _SignupRegisterPageState();
}

class _SignupRegisterPageState extends State<SignupRegisterPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  String _codeErrorMsg = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    final String name = _nameCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnackBar(t('이름을 입력해주세요.'), isError: true);
      return;
    }
    if (email.isEmpty) {
      Utils.showSnackBar(t('메일을 입력해주세요.'), isError: true);
      return;
    }

    final RegisterController regCtrl = Get.find<RegisterController>();
    final bool success = await regCtrl.sendRegisterCode(name, email);
    if (success) {
      Utils.showSnackBar(t('인증번호가 발송되었습니다. 이메일 확인해주세요.'));
    } else {
      Utils.showSnackBar(t('서버 에러 혹은 메일주소가 잘못됨.'), isError: true);
    }
  }

  Future<void> _onCheckCode() async {
    final String name = _nameCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      Utils.showSnackBar(t('이름과 메일을 입력하세요.'), isError: true);
      return;
    }

    setState(() => _codeErrorMsg = '');
    final String code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeErrorMsg = t('인증번호를 입력해주세요.'));
      return;
    }

    final RegisterController regCtrl = Get.find<RegisterController>();
    final bool verified = await regCtrl.verifyRegisterCode(email, code);
    if (!verified) {
      setState(() => _codeErrorMsg = t('인증번호가 유효하지 않습니다.'));
      return;
    }

    Utils.showSnackBar(t('인증번호 확인 성공! 다음 단계로 이동하세요.'));
    Get.toNamed(
      SignUpPage.routeName,
      arguments: <String, dynamic>{
        'name': name,
        'email': email,
      },
    );
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
              t('회원 가입'),
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
              t('이름과 메일로 본인 확인을 진행하세요.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 36),
            AuthFieldLabel(text: t('이름')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _nameCtrl,
              focusNode: _nameFocusNode,
              hintText: t('이름을 입력하세요.'),
              prefixIconData: CupertinoIcons.person,
            ),
            const SizedBox(height: 20),
            AuthFieldLabel(text: t('메일')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _emailCtrl,
              focusNode: _emailFocusNode,
              hintText: t('가입에 사용할 메일을 입력하세요.'),
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
            AuthPrimaryButton(text: t('확인'), onTap: _onCheckCode),
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
