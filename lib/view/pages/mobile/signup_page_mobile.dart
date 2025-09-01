// lib/view/pages/signup_page_mobile.dart
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/utils/utils.dart';
import '/view/pages/signup_final_page.dart';
import '/viewmodel/controller/user_controller.dart';

const double _designWidth = 390;
const double _designHeight = 812;

double scaleWidth(BuildContext context, double pixels) =>
    (MediaQuery.of(context).size.width * (pixels / _designWidth)).roundToDouble();

double scaleHeight(BuildContext context, double pixels) =>
    (MediaQuery.of(context).size.height * (pixels / _designHeight)).roundToDouble();

double verticalGap25(BuildContext context) => scaleHeight(context, 25);

TextStyle buildTextStyle(
  BuildContext context,
  double fontSize, {
  Color color = Colors.black,
  FontWeight weight = FontWeight.w400,
  String fontFamily = 'pretendard',
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: scaleWidth(context, fontSize),
    color: color,
    height: 1,
    fontWeight: weight,
  );
}

class SignUpPageMobile extends StatefulWidget {
  const SignUpPageMobile({super.key});
  static const String routeName = '/signup';

  @override
  State<SignUpPageMobile> createState() => _SignUpPageMobileState();
}

class _SignUpPageMobileState extends State<SignUpPageMobile> {
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  late final String previousName;
  late final String previousEmail;
  bool idError = false, passwordError = false, confirmError = false, phoneError = false;

  String idErrorMessage = '', passwordErrorMessage = '', confirmErrorMessage = '', phoneErrorMessage = '';

  static const double _mobileWidthThreshold = 550;

  @override
  void initState() {
    super.initState();
    _applyIosScrollFix();

    final Map<String, dynamic> arguments = Get.arguments is Map<String, dynamic> ? Get.arguments : <String, dynamic>{};
    previousName = arguments['name'] as String? ?? '';
    previousEmail = arguments['email'] as String? ?? '';
  }

  @override
  void dispose() {
    userIdController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _applyIosScrollFix() {
    if (!kIsWeb) return;
    if (html.document.getElementById('ios-ghost-fix') != null) return;
    html.document.head!.append(html.StyleElement()
      ..id = 'ios-ghost-fix'
      ..innerHtml = '''
        .flt-glass-pane { transform: translateZ(0); }
        body, #flt-platform-view { overscroll-behavior: contain; }
      ''');
  }

  /* ────────── UI helpers ────────── */
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: scaleHeight(context, 60),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF00000D).withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: scaleWidth(context, 24)),
          SvgPicture.asset(
            'assets/images/icons_symbol.svg',
            width: scaleWidth(context, 24),
          ),
          SizedBox(width: scaleWidth(context, 16)),
          Text(
            '아이비스 FMS 관제 시스템',
            style: buildTextStyle(
              context,
              18,
              weight: FontWeight.w500,
              fontFamily: 'gm-medium',
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _buildBorder({required bool isNormal}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(
        color: isNormal ? Colors.grey : const Color(0xFFC42B1C),
        width: 1,
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required bool hasError,
    required String errorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: buildTextStyle(context, 15)),
            const Spacer(),
            Flexible(
              child: Opacity(
                opacity: hasError ? 1 : 0,
                child: Text(
                  errorMessage,
                  overflow: TextOverflow.ellipsis,
                  style: buildTextStyle(
                    context,
                    14,
                    color: const Color(0xFFC42B1C),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: scaleHeight(context, 4)),
        SizedBox(
          height: scaleHeight(context, 40),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: buildTextStyle(
              context,
              15,
              color: hasError ? const Color(0xFFC42B1C) : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: buildTextStyle(
                context,
                15,
                color: const Color(0xFF666565),
              ),
              border: _buildBorder(isNormal: !hasError),
              enabledBorder: _buildBorder(isNormal: !hasError),
              focusedBorder: _buildBorder(isNormal: !hasError),
              contentPadding: EdgeInsets.symmetric(
                horizontal: scaleWidth(context, 25),
                vertical: scaleHeight(context, 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: buildTextStyle(context, 15)),
        SizedBox(height: scaleHeight(context, 4)),
        Container(
          height: scaleHeight(context, 40),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: scaleWidth(context, 25)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: buildTextStyle(context, 15),
          ),
        ),
      ],
    );
  }

  /* ────────── BUILD ────────── */
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= _mobileWidthThreshold;

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: kBackgroundColor,
        body: Column(
          children: <Widget>[
            _buildTopBar(context),
            Expanded(
              child: isMobile ? _buildMobileBody() : _buildDesktopBody(),
            ),
          ],
        ),
      ),
    );
  }

  /* ────────── MOBILE LAYOUT ────────── */
  Widget _buildMobileBody() {
    final double gap = verticalGap25(context);
    final double buttonHeight = scaleHeight(context, 40);

    return ScrollConfiguration(
      behavior: const _NoGlowScrollBehavior(),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          SliverFillRemaining(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: scaleWidth(context, 36),
                vertical: scaleHeight(context, 24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: gap),
                  Center(
                    child: Text(
                      '회원가입',
                      style: buildTextStyle(
                        context,
                        30,
                        color: kBlueFontColor,
                        weight: FontWeight.w600, // ←  Pretendard 20 / 600
                        fontFamily: 'pretendard',
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  _buildFormField(
                    label: '아이디',
                    controller: userIdController,
                    hintText: '아이디를 입력하세요.',
                    obscureText: false,
                    hasError: idError,
                    errorMessage: idErrorMessage,
                  ),
                  SizedBox(height: gap),
                  _buildFormField(
                    label: '비밀번호',
                    controller: passwordController,
                    hintText: '비밀번호를 입력하세요.',
                    obscureText: true,
                    hasError: passwordError,
                    errorMessage: passwordErrorMessage,
                  ),
                  SizedBox(height: gap),
                  _buildFormField(
                    label: '비밀번호 확인',
                    controller: confirmController,
                    hintText: '비밀번호를 다시 입력하세요.',
                    obscureText: true,
                    hasError: confirmError,
                    errorMessage: confirmErrorMessage,
                  ),
                  SizedBox(height: gap),
                  _buildReadOnlyField('이름', previousName),
                  SizedBox(height: gap),
                  _buildReadOnlyField('메일', previousEmail),
                  SizedBox(height: gap),
                  _buildFormField(
                    label: '연락처',
                    controller: phoneController,
                    hintText: '연락처를 입력해주세요.',
                    obscureText: false,
                    hasError: phoneError,
                    errorMessage: phoneErrorMessage,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: _submitSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlueFontColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        '확인',
                        style: buildTextStyle(
                          context,
                          15,
                          color: Colors.white,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: scaleWidth(context, 454),
          padding: EdgeInsets.all(scaleWidth(context, 24)),
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
          child: _buildMobileBody(),
        ),
      ),
    );
  }

  /* ────────── SUBMIT ────────── */
  Future<void> _submitSignUp() async {
    setState(() {
      idError = passwordError = confirmError = phoneError = false;
      idErrorMessage = passwordErrorMessage = confirmErrorMessage = phoneErrorMessage = '';
    });

    final String idValue = userIdController.text.trim();
    final String passwordValue = passwordController.text.trim();
    final String confirmValue = confirmController.text.trim();
    final String phoneValue = phoneController.text.trim();

    if (idValue.isEmpty) {
      idError = true;
      idErrorMessage = '사용이 불가능한 아이디입니다.';
    }
    if (passwordValue.isEmpty) {
      passwordError = true;
      passwordErrorMessage = '사용이 불가능한 비밀번호입니다.';
    }
    if (confirmValue.isEmpty || confirmValue != passwordValue) {
      confirmError = true;
      confirmErrorMessage = '비밀번호를 확인해주세요.';
    }
    if (phoneValue.isEmpty) {
      phoneError = true;
      phoneErrorMessage = '연락처를 입력해주세요.';
    }
    if (idError || passwordError || confirmError || phoneError) {
      setState(() {});
      return;
    }

    final UserController userController = Get.find<UserController>();
    final bool success = await userController.reqSignUpByIdAndEmail(
      idValue,
      previousEmail,
      previousName,
      phoneValue,
      passwordValue,
    );

    if (!success) {
      Utils.showSnackBar(
        '회원가입 실패: ID/EMAIL 중복 или 서버 오류',
        isError: true,
      );
      return;
    }

    Utils.showSnackBar('회원가입 성공!');
    Get.offAllNamed(SignUpFinalPage.routeName);
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) => child;
}
