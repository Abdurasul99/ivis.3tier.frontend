import 'package:flutter/material.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/empty_top_bar_view.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_text_horizontal.dart';
import '../components/line_button.dart';
import 'login_check_id_page.dart';

/// 로그인 아이디 찾기 페이지
/// 설명(한국어):
/// - 기존 코드 그대로 유지하되, 마우스 네비게이션 효과(hover, splash 등)는 제거합니다.
/// - 입력 필드의 placeholder는 수직 중앙 정렬(contentPadding은 그대로 유지).
class LoginFindIdPage extends StatefulWidget {
  static const routeName = '/find-id';

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

  String _codeErrorMsg = "";

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

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const LoginFindIdPage();
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
          "아이디 찾기",
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
          controller: _nameController,
          focusNode: _nameFocusNode,
        ),
        const SizedBox(height: 16),
        InputEditTextHorizontal(
          label: "메일",
          hint: "가입에 사용한 메일을 입력하세요.",
          controller: _emailController,
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
          controller: _codeController,
          focusNode: _codeFocusNode,
          errorText: _codeErrorMsg,
        ),
        const SizedBox(height: 24),
        GradientButton(
          buttonText: "확인",
          buttonColor: const Color(0xFF005FB8),
          onTap: onVerifyCode,
        ),
      ],
    );
  }

  Future<void> onSendCode() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      Utils.showSnackBar("이름과 메일을 입력하세요.", isError: true);
      return;
    }

    final userCtrl = Get.find<UserController>();
    final success = await userCtrl.reqFindIdSendCode(name, email);
    if (success) {
      Utils.showSnackBar("인증메일을 보냈습니다. 메일을 확인해주세요.");
    } else {
      Utils.showSnackBar("메일 전송에 실패했습니다.", isError: true);
    }
  }

  Future<void> onVerifyCode() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      Utils.showSnackBar("이름과 메일을 입력하세요.", isError: true);
      return;
    }

    _codeErrorMsg = "";

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _codeErrorMsg = "인증번호를 입력해주세요.";

      if (mounted) {
        setState(() {});
      }
      return;
    }

    final email = _emailController.text.trim();
    final userCtrl = Get.find<UserController>();
    final verified = await userCtrl.reqFindIdVerifyCode(email, code);
    if (!verified) {
      _codeController.clear();
      _codeErrorMsg = "인증번호가 일치하지 않습니다.";
      _codeFocusNode.requestFocus();

      if (mounted) {
        setState(() {});
      }
      return;
    }

    final foundId = userCtrl.foundUserId;
    final joinDate = userCtrl.foundJoinDate.isNotEmpty ? userCtrl.foundJoinDate : "2025.01.13";

    Get.toNamed(LoginCheckIdPage.routeName, arguments: {'userId': foundId, 'joinDate': joinDate});
  }
}
