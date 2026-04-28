import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_check_id_page.dart';
import 'login_page.dart';

class LoginFindIdPage extends StatefulWidget {
  static const String routeName = '/find-id';

  const LoginFindIdPage({super.key});

  @override
  State<LoginFindIdPage> createState() => _LoginFindIdPageState();
}

class _LoginFindIdPageState extends State<LoginFindIdPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  String _codeErrorMsg = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      Utils.showSnackBar(t('이름과 메일을 입력하세요.'), isError: true);
      return;
    }

    final bool success = await Get.find<UserController>().reqFindIdSendCode(name, email);
    if (success) {
      Utils.showSnackBar(t('인증메일을 보냈습니다. 메일을 확인해주세요.'));
    } else {
      Utils.showSnackBar(t('메일 전송에 실패했습니다.'), isError: true);
    }
  }

  Future<void> _onVerifyCode() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      Utils.showSnackBar(t('이름과 메일을 입력하세요.'), isError: true);
      return;
    }

    setState(() => _codeErrorMsg = '');
    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeErrorMsg = t('인증번호를 입력해주세요.'));
      return;
    }

    final UserController userCtrl = Get.find<UserController>();
    final bool verified = await userCtrl.reqFindIdVerifyCode(_emailController.text.trim(), code);
    if (!verified) {
      _codeController.clear();
      setState(() => _codeErrorMsg = t('인증번호가 일치하지 않습니다.'));
      _codeFocusNode.requestFocus();
      return;
    }

    Get.toNamed(
      LoginCheckIdPage.routeName,
      arguments: <String, dynamic>{
        'userId': userCtrl.foundUserId,
        'joinDate': userCtrl.foundJoinDate.isNotEmpty ? userCtrl.foundJoinDate : '2025.01.13',
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
              t('이름과 메일로 아이디를 찾아보세요.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 36),
            AuthFieldLabel(text: t('이름')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              hintText: t('이름을 입력하세요.'),
              prefixIconData: CupertinoIcons.person,
            ),
            const SizedBox(height: 20),
            AuthFieldLabel(text: t('메일')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _emailController,
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
              controller: _codeController,
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
