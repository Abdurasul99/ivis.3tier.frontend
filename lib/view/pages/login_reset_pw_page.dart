import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/pages/mobile/login_reset_pw_page_mobile.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/password_controller.dart';

class LoginResetPwPage extends StatefulWidget {
  static const routeName = '/reset-pw';

  const LoginResetPwPage({super.key});

  @override
  State<LoginResetPwPage> createState() => _LoginResetPwPageState();
}

class _LoginResetPwPageState extends State<LoginResetPwPage> {
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();

  // Regex for password validation: 8~16 chars, must have digit, letter, special char
  final RegExp _regexPassword = RegExp(
    r'^(?=.*[0-9])(?=.*[a-zA-Z])(?=.*[^a-zA-Z0-9]).{8,16}$',
  );

  @override
  void dispose() {
    _pwController.dispose();
    _pwConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const LoginResetPwPageMobile();
    }
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: Container(
                  width: 454,
                  height: 430,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top bar styled like your snippet
  Widget _buildTopBar() {
    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00000D).withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 3.0,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          SvgPicture.asset("assets/images/icons_symbol.svg", width: 24),
          const SizedBox(width: 16),
          const Text(
            "3Tier",
            style: TextStyle(
              fontFamily: 'gm-medium',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title
        const Text(
          "비밀번호 재설정",
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF005FB7),
          ),
        ),
        const SizedBox(height: 18),
        // Subtitle
        const Text(
          "영문, 숫자, 특수문자 등을 함께 사용하면 (8자 이상 16자 이하)\n보다 안전합니다.",
          textAlign: TextAlign.left,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 24),

        // "새 비밀번호"
        SizedBox(
          width: 358,
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  "새 비밀번호",
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _pwController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "비밀번호를 입력하세요.",
                      hintStyle: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: Color(0xFF666565),
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFB3B3B3)),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFB3B3B3)),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFB3B3B3)),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                    style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // "비밀번호 확인"
        SizedBox(
          width: 358,
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  "비밀번호 확인",
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _pwConfirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "비밀번호를 한 번 더 입력하세요.",
                      hintStyle: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: Color(0xFF666565),
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFB3B3B3)),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFB3B3B3)),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFB3B3B3)),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                    style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 92),

        // "확인" button with no navigation (hover/splash) effect
        SizedBox(
          width: 358,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlueFontColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: onTapConfirm,
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

  Future<void> onTapConfirm() async {
    final pw1 = _pwController.text.trim();
    final pw2 = _pwConfirmController.text.trim();

    if (pw1.isEmpty || pw2.isEmpty) {
      Utils.showSnackBar("비밀번호를 입력하세요.", isError: true);
      return;
    }
    if (pw1 != pw2) {
      Utils.showSnackBar("비밀번호가 서로 일치하지 않습니다.", isError: true);
      return;
    }
    if (!_regexPassword.hasMatch(pw1)) {
      Utils.showSnackBar(
        "비밀번호는 영문, 숫자, 특수문자를 포함해 8~16자로 입력해주세요.",
        isError: true,
      );
      return;
    }

    final passwordCtrl = Get.find<PasswordController>();
    final response = await passwordCtrl.reqPasswordComplete(pw1);
    if (response == null) {
      Utils.showSnackBar("서버 요청 오류 (reqPasswordComplete null).", isError: true);
      return;
    }

    if (response.code == "0000") {
      Utils.showSnackBar("비밀번호가 변경되었습니다!");
      Get.offAllNamed('/reset-final');
    } else {
      Utils.showSnackBar("비밀번호 변경 실패: ${response.message}", isError: true);
    }
  }
}
