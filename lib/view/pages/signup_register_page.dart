import 'package:flutter/material.dart';
import 'package:fms/view/components/empty_top_bar_view.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/pages/mobile/signup_register_page_mobile.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/register_controller.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_text_horizontal.dart';
import '../components/line_button.dart';
import 'signup_page.dart';

class SignupRegisterPage extends StatefulWidget {
  static const routeName = '/register-first';

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

  String? _errorNameMsg;
  String? _errorEmailMsg;
  String? _errorCodeMsg;

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

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const SignupRegisterPageMobile();
    }
    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: [
            EmptyTopBarView(),
            Expanded(
              child: Center(
                child: Container(
                  width: 454,
                  height: 430,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 42),
                  alignment: Alignment.center,
                  child: buildFormContents(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFormContents() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        const Text(
          "회원 가입",
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: kBlueFontColor,
          ),
        ),
        const SizedBox(height: 32),
        InputEditTextHorizontal(
          label: "이름",
          hint: "이름을 입력하세요.",
          controller: _nameCtrl,
          focusNode: _nameFocusNode,
          errorText: _errorNameMsg,
        ),
        const SizedBox(height: 16),
        InputEditTextHorizontal(
          label: "메일",
          hint: "가입에 사용한 메일을 입력하세요.",
          controller: _emailCtrl,
          focusNode: _emailFocusNode,
          errorText: _errorEmailMsg,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Spacer(),
            SizedBox(
              width: 286,
              child: LineButton(
                buttonText: "인증메일 보내기",
                onTap: onSendCode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InputEditTextHorizontal(
          label: "인증번호",
          hint: "인증번호를 입력해 주세요.",
          controller: _codeCtrl,
          focusNode: _codeFocusNode,
          errorText: _errorCodeMsg,
        ),
        const SizedBox(height: 24),
        GradientButton(
          buttonText: "확인",
          buttonColor: const Color(0xFF005FB8),
          onTap: onCheckCode,
        ),
      ],
    );
  }

  Future<void> onSendCode() async {
    _errorNameMsg = "";
    _errorEmailMsg = "";

    final String nameVal = _nameCtrl.text.trim();
    final String emailVal = _emailCtrl.text.trim();

    if (nameVal.isEmpty) {
      _errorNameMsg = "이름을 입력해주세요.";

      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (emailVal.isEmpty) {
      _errorEmailMsg = "메일을 입력해주세요.";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    final regCtrl = Get.find<RegisterController>();
    final success = await regCtrl.sendRegisterCode(nameVal, emailVal);
    if (!success) {
      _errorEmailMsg = "서버 에러 혹은 메일주소가 잘못됨.";
      if (mounted) {
        setState(() {});
      }
      return;
    }
    Utils.showSnackBar("인증번호가 발송되었습니다. 이메일 확인해주세요.");
  }

  Future<void> onCheckCode() async {
    _errorCodeMsg = "";
    _errorNameMsg = "";
    _errorEmailMsg = "";

    final String nameVal = _nameCtrl.text.trim();
    final String emailVal = _emailCtrl.text.trim();
    final String codeVal = _codeCtrl.text.trim();

    if (nameVal.isEmpty) {
      _errorNameMsg = "이름을 입력해주세요.";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (emailVal.isEmpty) {
      _errorEmailMsg = "메일을 입력해주세요.";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (codeVal.isEmpty) {
      _errorCodeMsg = "인증번호를 입력해주세요.";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    final regCtrl = Get.find<RegisterController>();
    final verified = await regCtrl.verifyRegisterCode(emailVal, codeVal);
    if (!verified) {
      _errorCodeMsg = "인증번호가 유효하지 않습니다.";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    Utils.showSnackBar("인증번호 확인 성공! 다음 단계로 이동하세요.");
    Get.toNamed(SignUpPage.routeName, arguments: {"name": _nameCtrl.text.trim(), "email": _emailCtrl.text.trim()});
  }
}
