import 'package:flutter/material.dart';
import 'package:fms/view/components/empty_top_bar_view.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/pages/mobile/login_reset_final_page_mobile.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import 'login_page.dart';

class LoginResetFinalPage extends StatelessWidget {
  static const routeName = '/reset-final';

  const LoginResetFinalPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const LoginResetFinalPageMobile();
    }
    return SafeArea(
      top: false,
      bottom: false,
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
      children: [
        const SizedBox(height: 40),
        const Text(
          "비밀번호 재설정",
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: kBlueFontColor,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "비밀번호 재설정이 완료되었습니다!",
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 200),
        SizedBox(
          width: 358,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlueFontColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
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
      ],
    );
  }

  void onTapLogin() {
    Get.offAllNamed(LoginPage.routeName);
  }
}
