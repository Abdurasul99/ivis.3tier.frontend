import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/view/pages/login_page.dart';

class LoginResetFinalPageMobile extends StatelessWidget {
  static const String routeName = '/reset-final';
  static const double mobileBreakpointWidth = 550.0;

  const LoginResetFinalPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= mobileBreakpointWidth;
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: [
            buildTopBar(),
            Expanded(
              child: isMobile ? _buildMobileForm() : Center(child: buildDesktopForm()),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopBar() {
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

  Widget buildDesktopForm() {
    return Container(
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
      child: buildFormContent(),
    );
  }

  Widget _buildMobileForm() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 358),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '비밀번호 재설정',
                            style: TextStyle(
                              fontFamily: 'gm-medium',
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF005FB7),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '비밀번호 재설정이 완료되었습니다!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 548),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: onTapLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlueFontColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ).copyWith(
                            overlayColor: WidgetStateProperty.all(Colors.transparent),
                            splashFactory: NoSplash.splashFactory,
                          ),
                          child: const Text(
                            '로그인',
                            style: TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildFormContent() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '비밀번호 재설정',
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: kBlueFontColor,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '비밀번호 재설정이 완료되었습니다!',
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
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
              '로그인',
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
