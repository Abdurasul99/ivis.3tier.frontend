import 'package:flutter/material.dart';
import 'package:ivis/view/components/empty_top_bar_view.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart'; // kBlueFontColor, etc.
import '../../utils/utils.dart';
import '../../viewmodel/controller/user_controller.dart';
import 'signup_final_page.dart';

final TextStyle kPlaceholderStyle = TextStyle(
  fontFamily: 'pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 15,
  height: 17.9 / 15,
  color: Color(0xFF666565),
);

final TextStyle kLabelStyle = TextStyle(
  fontFamily: 'pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 15,
  height: 17.9 / 15,
  color: Colors.black,
);

final TextStyle kLabelErrorStyle = TextStyle(
  fontFamily: 'pretendard',
  fontSize: 14,
  color: Color(0xFFC42B1C),
  fontWeight: FontWeight.w400,
);

class SignUpPage extends StatefulWidget {
  static const routeName = '/signup';

  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  String nameFromPrev = "";
  String emailFromPrev = "";

  bool _idError = false;
  bool _pwError = false;
  bool _pwConfirmError = false;
  bool _phoneError = false;

  String _idErrMsg = "";
  String _pwErrMsg = "";
  String _pwConfirmErrMsg = "";
  String _phoneErrMsg = "";

  @override
  void initState() {
    super.initState();
    final args = Get.arguments ?? {};
    nameFromPrev = args['name'] ?? "";
    emailFromPrev = args['email'] ?? "";
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const SignUpPage();
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
                  height: 685,
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
                  child: buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "회원가입",
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: kBlueFontColor,
          ),
        ),
        const SizedBox(height: 24),
        buildFieldRowWithError(
          label: "아이디",
          errorMsg: _idErrMsg,
          isError: _idError,
          controller: _idCtrl,
          hintText: "아이디를 입력하세요.",
          obscureText: false,
        ),
        const SizedBox(height: 16),
        // 비밀번호
        buildFieldRowWithError(
          label: "비밀번호",
          errorMsg: _pwErrMsg,
          isError: _pwError,
          controller: _passwordCtrl,
          hintText: "비밀번호를 입력하세요.",
          obscureText: true,
        ),
        const SizedBox(height: 16),
        // 비밀번호 확인
        buildFieldRowWithError(
          label: "비밀번호 확인",
          errorMsg: _pwConfirmErrMsg,
          isError: _pwConfirmError,
          controller: _confirmCtrl,
          hintText: "비밀번호를 다시 입력하세요.",
          obscureText: true,
        ),
        const SizedBox(height: 16),
        // 이름 (read-only)
        buildReadOnlyField(label: "이름", value: nameFromPrev),
        const SizedBox(height: 16),
        // 메일 (read-only)
        buildReadOnlyField(label: "메일", value: emailFromPrev),
        const SizedBox(height: 16),
        // 연락처
        buildFieldRowWithError(
          label: "연락처",
          errorMsg: _phoneErrMsg,
          isError: _phoneError,
          controller: _phoneCtrl,
          hintText: "연락처를 입력해주세요.",
          obscureText: false,
        ),
        const SizedBox(height: 24),
        // button "확인"
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: onTapSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlueFontColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              "확인",
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFieldRowWithError({
    required String label,
    required String errorMsg,
    required bool isError,
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: kLabelStyle),
            if (isError && errorMsg.isNotEmpty)
              Flexible(
                child: Text(
                  errorMsg,
                  style: kLabelErrorStyle,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: isError ? const Color(0xFFC42B1C) : Colors.black,
            height: 17.9 / 15,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: kPlaceholderStyle,
            border: borderStyle(normal: !isError),
            enabledBorder: borderStyle(normal: !isError),
            focusedBorder: borderStyle(normal: !isError),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget buildReadOnlyField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: kLabelStyle),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            value,
            style: kLabelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  OutlineInputBorder borderStyle({required bool normal}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(
        color: normal ? Colors.grey : const Color(0xFFC42B1C),
        width: 1.0,
      ),
    );
  }

  Future<void> onTapSignUp() async {
    setState(() {
      _idError = false;
      _idErrMsg = "";
      _pwError = false;
      _pwErrMsg = "";
      _pwConfirmError = false;
      _pwConfirmErrMsg = "";
      _phoneError = false;
      _phoneErrMsg = "";
    });

    final idVal = _idCtrl.text.trim();
    final pwVal = _passwordCtrl.text.trim();
    final pw2Val = _confirmCtrl.text.trim();
    final phoneVal = _phoneCtrl.text.trim();

    if (idVal.isEmpty) {
      setState(() {
        _idError = true;
        _idErrMsg = "사용이 불가능한 아이디입니다.";
      });
    }
    if (pwVal.isEmpty) {
      setState(() {
        _pwError = true;
        _pwErrMsg = "사용이 불가능한 비밀번호입니다.";
      });
    }
    if (pw2Val.isEmpty || pw2Val != pwVal) {
      setState(() {
        _pwConfirmError = true;
        _pwConfirmErrMsg = "비밀번호를 확인해주세요.";
      });
    }
    if (phoneVal.isEmpty) {
      setState(() {
        _phoneError = true;
        _phoneErrMsg = "연락처를 입력해주세요.";
      });
    }

    if (_idError || _pwError || _pwConfirmError || _phoneError) {
      return;
    }

    final userCtrl = Get.find<UserController>();
    final success = await userCtrl.reqSignUpByIdAndEmail(
      idVal,
      emailFromPrev,
      nameFromPrev,
      phoneVal,
      pwVal,
    );
    if (!success) {
      Utils.showSnackBar("회원가입 실패: ID/EMAIL 중복이거나 서버 오류", isError: true);
      return;
    }

    Utils.showSnackBar("회원가입 성공!");
    Get.offAllNamed(SignUpFinalPage.routeName);
  }
}
