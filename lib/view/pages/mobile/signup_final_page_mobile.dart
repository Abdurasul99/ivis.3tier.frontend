// lib/view/pages/signup_final_page_mobile.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/svg.dart';

import '/constants/constants.dart';
import '/view/pages/login_page.dart';

class SignUpFinalPageMobile extends StatelessWidget {
  static const routeName = '/signup-final';

  const SignUpFinalPageMobile({super.key});

  Widget _buildTopBar() {
    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00000D).withOpacity(.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          SvgPicture.asset('assets/images/icons_symbol.svg', width: 24),
          const SizedBox(width: 16),
          const Text(
            '아이비스 FMS 관제 시스템',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 41),
                child: Column(
                  children: [
                    const SizedBox(height: 117), 
                    const Text(
                      '회원가입',
                      style: TextStyle(
                        fontFamily: 'gm-medium',
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF005FB7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '회원가입이 완료되었습니다.',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 448), 
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => Get.offAllNamed(LoginPage.routeName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlueFontColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 93), 
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
