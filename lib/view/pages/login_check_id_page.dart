import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../viewmodel/controller/password_controller.dart';
import 'login_reset_pw_page.dart';

class LoginCheckIdPage extends StatelessWidget {
  static const routeName = '/check-id';

  const LoginCheckIdPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const LoginCheckIdPage();
    }
    final args = Get.arguments ?? {};
    final userId = args['userId'] ?? 'unknown@domain.com';
    final joinDate = args['joinDate'] ?? '2025.01.13';

    final verifyToken = args['verifyToken'] ?? '';
    if (verifyToken.isNotEmpty) {
      final passwordCtrl = Get.find<PasswordController>();
      passwordCtrl.verifyToken = verifyToken;
      final foundEmail = args['foundEmail'] ?? '';
      if (foundEmail.isNotEmpty) {
        passwordCtrl.resetEmail = foundEmail;
      }
    }

    return SafeArea(
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
                  child: _buildBody(userId, joinDate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상단 바 (Top bar) matching your snippet's style
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

  /// 폼 전체 레이아웃
  Widget _buildBody(String userId, String joinDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(height: 8),
        // 색상을 검정(Colors.black)으로 변경
        const Text(
          "고객님의 정보와 일치하는 아이디입니다.",
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),
        // 아이디 / 가입일 컨테이너를 가로로 중앙 정렬
        Center(
          child: Container(
            width: 358,
            height: 89,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFEAEAEA), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "아이디 : $userId",
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'pretendard',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "가입일 : $joinDate",
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // "비밀번호 재설정" 버튼
        SizedBox(
          width: 358,
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF005FB8), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: onTapResetPassword,
            child: const Text(
              "비밀번호 재설정",
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Color(0xFF005FB8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // "로그인" 버튼
        SizedBox(
          width: 358,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF005FB8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: onTapLogin,
            child: const Text(
              "로그인",
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void onTapResetPassword() {
    // Not changed, as requested
    Get.offAllNamed(LoginResetPwPage.routeName);
  }

  void onTapLogin() {
    // Not changed, as requested
    Get.offAllNamed('/login');
  }
}
