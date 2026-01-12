import 'package:flutter/material.dart';
import 'package:ivis/view/components/empty_top_bar_view.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:get/get.dart';
import '../../constants/constants.dart';
import 'login_page.dart';

class SignUpFinalPage extends StatelessWidget {
  static const routeName = '/signup-final';

  const SignUpFinalPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const SignUpFinalPage();
    }
    return Scaffold(
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
                  border: Border.all(
                    color: const Color(0xFFD9D9D9),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      "회원가입",
                      style: TextStyle(
                        fontFamily: 'gm-medium',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF005FB7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "회원가입이 완료되었습니다.",
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 220),
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
                        onPressed: () {
                          Get.offAllNamed(LoginPage.routeName);
                        },
                        child: const Text(
                          "로그인",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
