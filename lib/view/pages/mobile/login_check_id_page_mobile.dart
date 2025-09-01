import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/viewmodel/controller/password_controller.dart';
import '/view/pages/login_reset_pw_page.dart';

class LoginCheckIdPageMobile extends StatelessWidget {
  static const String routeName = '/check-id';
  static const double _mobileBreakpointWidth = 550.0;

  const LoginCheckIdPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> arguments = Get.arguments as Map<String, dynamic>? ?? <String, dynamic>{};
    final String foundUserId = arguments['userId'] as String? ?? 'unknown@domain.com';
    final String foundJoinDate = arguments['joinDate'] as String? ?? '2025.01.13';
    final String verifyToken = arguments['verifyToken'] as String? ?? '';

    if (verifyToken.isNotEmpty) {
      final PasswordController passwordController = Get.find<PasswordController>();
      passwordController.verifyToken = verifyToken;
      final String foundEmail = arguments['foundEmail'] as String? ?? '';
      if (foundEmail.isNotEmpty) {
        passwordController.resetEmail = foundEmail;
      }
    }

    final bool isMobile = MediaQuery.of(context).size.width <= _mobileBreakpointWidth;

    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: isMobile
                  ? _buildMobileBody(foundUserId, foundJoinDate)
                  : Center(
                      child: Container(
                        width: 454,
                        height: 430,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildBody(foundUserId, foundJoinDate),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF00000D).withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 3.0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
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

  Widget _buildBody(String userId, String joinDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 12),
        const Text(
          '아이디 찾기',
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: kBlueFontColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '고객님의 정보와 일치하는 아이디입니다.',
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 358,
            height: 89,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFB3B3B3), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '아이디 : $userId',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'pretendard',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '가입일 : $joinDate',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
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
              '비밀번호 재설정',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 358,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005FB8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: onTapLogin,
            child: const Text(
              '로그인',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMobileBody(String userId, String joinDate) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 42, 42, 62),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 84),
                  const Text(
                    '아이디 찾기',
                    style: TextStyle(
                      fontFamily: 'gm-medium',
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: kBlueFontColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '고객님의 정보와 일치하는 아이디입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 55),
                  // Поля 아이디 и 가입일
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '아이디',
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFB3B3B3), width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          userId,
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        '가입일',
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFB3B3B3), width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          joinDate,
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 185),
                  // Кнопки внизу
                  Column(
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
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
                            '비밀번호 재설정',
                            style: TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: kBlackFontColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005FB8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ).copyWith(
                            overlayColor: WidgetStateProperty.all(Colors.transparent),
                            splashFactory: NoSplash.splashFactory,
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void onTapResetPassword() {
    Get.offAllNamed(LoginResetPwPage.routeName);
  }

  void onTapLogin() {
    Get.offAllNamed('/login');
  }
}
