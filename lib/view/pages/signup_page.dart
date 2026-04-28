import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/auth_page_shell.dart';
import 'login_page.dart';
import 'signup_final_page.dart';

class SignUpPage extends StatefulWidget {
  static const String routeName = '/signup';

  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  String nameFromPrev = '';
  String emailFromPrev = '';

  bool _showPassword = false;
  bool _showConfirm = false;

  String _idErrMsg = '';
  String _pwErrMsg = '';
  String _pwConfirmErrMsg = '';
  String _phoneErrMsg = '';

  @override
  void initState() {
    super.initState();
    final Map<dynamic, dynamic> args = Get.arguments ?? <String, dynamic>{};
    nameFromPrev = args['name']?.toString() ?? '';
    emailFromPrev = args['email']?.toString() ?? '';
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onTapSignUp() async {
    setState(() {
      _idErrMsg = '';
      _pwErrMsg = '';
      _pwConfirmErrMsg = '';
      _phoneErrMsg = '';
    });

    final String idVal = _idCtrl.text.trim();
    final String pwVal = _passwordCtrl.text.trim();
    final String pw2Val = _confirmCtrl.text.trim();
    final String phoneVal = _phoneCtrl.text.trim();

    bool hasError = false;
    if (idVal.isEmpty) {
      setState(() => _idErrMsg = t('사용이 불가능한 아이디입니다.'));
      hasError = true;
    }
    if (pwVal.isEmpty) {
      setState(() => _pwErrMsg = t('사용이 불가능한 비밀번호입니다.'));
      hasError = true;
    }
    if (pw2Val.isEmpty || pw2Val != pwVal) {
      setState(() => _pwConfirmErrMsg = t('비밀번호를 확인해주세요.'));
      hasError = true;
    }
    if (phoneVal.isEmpty) {
      setState(() => _phoneErrMsg = t('연락처를 입력해주세요.'));
      hasError = true;
    }
    if (hasError) return;

    final UserController userCtrl = Get.find<UserController>();
    final bool success = await userCtrl.reqSignUpByIdAndEmail(
      idVal,
      emailFromPrev,
      nameFromPrev,
      phoneVal,
      pwVal,
    );
    if (!success) {
      Utils.showSnackBar(t('회원가입 실패: ID/EMAIL 중복이거나 서버 오류'), isError: true);
      return;
    }
    Utils.showSnackBar(t('회원가입 성공!'));
    Get.offAllNamed(SignUpFinalPage.routeName);
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
              t('계정 정보를 입력하여 회원가입을 완료하세요.'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
            const SizedBox(height: 32),
            AuthFieldLabel(text: t('아이디')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _idCtrl,
              focusNode: _idFocusNode,
              hintText: t('아이디를 입력하세요.'),
              prefixIconData: CupertinoIcons.person,
              errorText: _idErrMsg.isNotEmpty ? _idErrMsg : null,
            ),
            const SizedBox(height: 16),
            AuthFieldLabel(text: t('비밀번호')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocusNode,
              hintText: t('비밀번호를 입력하세요.'),
              prefixIconData: CupertinoIcons.lock,
              obscureText: !_showPassword,
              suffixIconData: _showPassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              onSuffixTapped: () => setState(() => _showPassword = !_showPassword),
              errorText: _pwErrMsg.isNotEmpty ? _pwErrMsg : null,
            ),
            const SizedBox(height: 16),
            AuthFieldLabel(text: t('비밀번호 확인')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _confirmCtrl,
              focusNode: _confirmFocusNode,
              hintText: t('비밀번호를 다시 입력하세요.'),
              prefixIconData: CupertinoIcons.lock,
              obscureText: !_showConfirm,
              suffixIconData: _showConfirm ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              onSuffixTapped: () => setState(() => _showConfirm = !_showConfirm),
              errorText: _pwConfirmErrMsg.isNotEmpty ? _pwConfirmErrMsg : null,
            ),
            const SizedBox(height: 16),
            AuthFieldLabel(text: t('이름')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: TextEditingController(text: nameFromPrev),
              hintText: t('이름'),
              prefixIconData: CupertinoIcons.person_alt,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            AuthFieldLabel(text: t('메일')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: TextEditingController(text: emailFromPrev),
              hintText: t('메일'),
              prefixIconData: CupertinoIcons.mail,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            AuthFieldLabel(text: t('연락처')),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _phoneCtrl,
              focusNode: _phoneFocusNode,
              hintText: t('연락처를 입력해주세요.'),
              prefixIconData: CupertinoIcons.phone,
              errorText: _phoneErrMsg.isNotEmpty ? _phoneErrMsg : null,
            ),
            const SizedBox(height: 32),
            AuthPrimaryButton(text: t('확인'), onTap: _onTapSignUp),
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
