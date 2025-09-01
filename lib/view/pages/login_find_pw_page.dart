import 'package:flutter/material.dart';
import 'package:fms/view/components/empty_top_bar_view.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/pages/mobile/login_find_pw_page_mobile.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/password_controller.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_text_horizontal.dart';
import '../components/line_button.dart';
import 'login_reset_pw_page.dart';

final TextStyle kTitleStyleFindID = TextStyle(
  fontFamily: 'gm-medium',
  fontWeight: FontWeight.w500,
  fontSize: 20,
  height: 23 / 20,
  color: Color(0xFF005FB7),
);

final TextStyle kLabelStyle = TextStyle(
  fontFamily: 'pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 15,
  height: 17.9 / 15,
  color: Colors.black,
);

final TextStyle kPlaceholderStyle = TextStyle(
  fontFamily: 'pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 15,
  height: 17.9 / 15,
  color: Color(0xFF666565),
);

final TextStyle kButtonStyle = TextStyle(
  fontFamily: 'pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 15,
  height: 17.9 / 15,
  color: Colors.black,
);

final TextStyle kErrorStyle = TextStyle(
  fontFamily: 'pretendard',
  fontSize: 13,
  color: Color(0xFFC42B1C),
);

class LoginFindPwPage extends StatefulWidget {
  static const routeName = '/find-pw';

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

  String _codeErrorMsg = "";

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

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const LoginFindPwPageMobile();
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
                  child: buildFormContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        const Text(
          "비밀번호 찾기",
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontWeight: FontWeight.w500,
            fontSize: 20,
            color: Color(0xFF005FB7),
          ),
        ),
        const SizedBox(height: 32),
        InputEditTextHorizontal(
          label: "아이디",
          hint: "아이디를 입력하세요.",
          controller: _userIdCtrl,
          focusNode: _userIdFocusNode,
        ),
        const SizedBox(height: 16),
        InputEditTextHorizontal(
          label: "메일",
          hint: "가입에 사용한 메일을 입력하세요.",
          controller: _emailCtrl,
          focusNode: _emailFocusNode,
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
          errorText: _codeErrorMsg,
        ),
        const SizedBox(height: 16),
        GradientButton(
          buttonText: "확인",
          buttonColor: const Color(0xFF005FB8),
          onTap: onVerifyCode,
        ),
      ],
    );
  }

  /// "인증메일 보내기" button (Rounded + remove extra column)
  Widget buildButtonSendCode() {
    return SizedBox(
      width: 365,
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 62),
          const SizedBox(width: 16),
          // Using OutlinedButton directly (borderRadius=3, blue border)
          SizedBox(
            width: 286,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF005FB7), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
                surfaceTintColor: Colors.transparent,
              ).copyWith(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
              ),
              onPressed: onSendCode,
              child: Text(
                "인증메일 보내기",
                style: kButtonStyle.copyWith(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> onSendCode() async {
    final userId = _userIdCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (userId.isEmpty || email.isEmpty) {
      Utils.showSnackBar("아이디와 메일을 입력하세요.", isError: true);
      return;
    }

    final passwordCtrl = Get.find<PasswordController>();
    final response = await passwordCtrl.reqResetPassword(email);
    if (response == null) {
      Utils.showSnackBar("서버 오류가 발생했습니다.", isError: true);
      return;
    }

    if (response.code == "0000") {
      Utils.showSnackBar("인증메일을 보냈습니다. 메일을 확인해주세요.");
    } else {
      Utils.showSnackBar("메일 전송 실패: ${response.message}", isError: true);
    }
  }

  Future<void> onVerifyCode() async {
    final userId = _userIdCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (userId.isEmpty || email.isEmpty) {
      Utils.showSnackBar("아이디와 메일을 입력하세요.", isError: true);
      return;
    }

    _codeErrorMsg = "";

    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _codeErrorMsg = "인증번호를 입력하세요.";
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final passwordCtrl = Get.find<PasswordController>();
    final verifyRes = await passwordCtrl.reqPasswordVerifyCode(_emailCtrl.text.trim(), code);
    if (verifyRes == null) {
      _codeErrorMsg = "서버 오류 (null).";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (verifyRes.code == "0000") {
      Utils.showSnackBar("인증되었습니다! 비밀번호를 재설정하세요.");
      Get.offAllNamed(LoginResetPwPage.routeName);
    } else {
      _codeErrorMsg = "인증번호가 올바르지 않습니다.";

      if (mounted) {
        setState(() {});
      }
    }
  }
}
