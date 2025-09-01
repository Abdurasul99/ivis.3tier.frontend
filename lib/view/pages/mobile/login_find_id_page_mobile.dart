// lib/view/pages/mobile/login_find_id_page_mobile.dart

import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/utils/utils.dart';
import '/viewmodel/controller/user_controller.dart';
import '/view/pages/login_check_id_page.dart';

const double designWidth = 390.0;
const double designHeight = 812.0;

double scaleWidth(BuildContext context, double pixelValue) {
  double screenWidth = MediaQuery.of(context).size.width;
  double widthRatio = pixelValue / designWidth;
  return (screenWidth * widthRatio).roundToDouble();
}

double scaleHeight(BuildContext context, double pixelValue) {
  double screenHeight = MediaQuery.of(context).size.height;
  double heightRatio = pixelValue / designHeight;
  return (screenHeight * heightRatio).roundToDouble();
}

class NoBounceScrollBehavior extends ScrollBehavior {
  const NoBounceScrollBehavior();

  @override
  Widget buildViewportChrome(BuildContext context, Widget childWidget, AxisDirection axisDirection) => childWidget;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context, {ScrollPhysics? parent}) => const ClampingScrollPhysics();
}

class LoginFindIdPageMobile extends StatefulWidget {
  const LoginFindIdPageMobile({Key? key}) : super(key: key);

  static const String routeName = '/find-id';

  @override
  State<LoginFindIdPageMobile> createState() => _LoginFindIdPageMobileState();
}

class _LoginFindIdPageMobileState extends State<LoginFindIdPageMobile> {
  final TextEditingController nameTextEditingController = TextEditingController();
  final TextEditingController emailTextEditingController = TextEditingController();
  final TextEditingController verificationCodeTextEditingController = TextEditingController();

  bool isVerificationCodeError = false;
  String verificationCodeErrorMessage = '';

  @override
  void initState() {
    super.initState();
    injectIosGhostScrollFixIfNeeded();
  }

  @override
  void dispose() {
    nameTextEditingController.dispose();
    emailTextEditingController.dispose();
    verificationCodeTextEditingController.dispose();
    super.dispose();
  }

  void injectIosGhostScrollFixIfNeeded() {
    if (!kIsWeb) return;
    if (html.document.getElementById('ios-ghost-fix') != null) return;
    html.StyleElement styleElement = html.StyleElement()
      ..id = 'ios-ghost-fix'
      ..innerHtml = '''
        .flt-glass-pane { transform: translateZ(0); }
        body, #flt-platform-view { overscroll-behavior: contain; }
      ''';
    html.document.head!.append(styleElement);
  }

  TextStyle buildTextStyle(
    BuildContext context,
    double fontSize, {
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: 'pretendard',
      fontSize: scaleWidth(context, fontSize),
      color: color,
      height: 1.0,
      fontWeight: fontWeight,
    );
  }

  Future<void> performSendVerificationCode() async {
    String enteredName = nameTextEditingController.text.trim();
    String enteredEmail = emailTextEditingController.text.trim();
    if (enteredName.isEmpty || enteredEmail.isEmpty) {
      Utils.showSnackBar('이름과 메일을 입력하세요.', isError: true);
      return;
    }
    UserController userController = Get.find<UserController>();
    bool isSent = await userController.reqFindIdSendCode(enteredName, enteredEmail);
    if (isSent) {
      Utils.showSnackBar('인증메일을 보냈습니다. 메일을 확인해주세요.');
    } else {
      Utils.showSnackBar('메일 전송에 실패했습니다.', isError: true);
    }
  }

  Future<void> performVerifyCode() async {
    setState(() {
      isVerificationCodeError = false;
      verificationCodeErrorMessage = '';
    });
    String enteredCode = verificationCodeTextEditingController.text.trim();
    if (enteredCode.isEmpty) {
      setState(() {
        isVerificationCodeError = true;
        verificationCodeErrorMessage = '인증번호를 확인해주세요.';
      });
      return;
    }
    UserController userController = Get.find<UserController>();
    bool isVerified = await userController.reqFindIdVerifyCode(
      emailTextEditingController.text.trim(),
      enteredCode,
    );
    if (!isVerified) {
      setState(() {
        isVerificationCodeError = true;
        verificationCodeErrorMessage = '인증번호를 확인해주세요.';
      });
      return;
    }
    Get.toNamed(
      LoginCheckIdPage.routeName,
      arguments: <String, String>{
        'userId': userController.foundUserId,
        'joinDate': userController.foundJoinDate.isNotEmpty ? userController.foundJoinDate : '2025.01.13',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double horizontalPadding = scaleWidth(context, 41);
    double topGap = scaleHeight(context, 120);
    double spacingBelowTitle = scaleHeight(context, 32);
    double spacingBetweenFields = scaleHeight(context, 28);
    double spacingAboveSendButton = scaleHeight(context, 50);
    double spacingAboveCodeField = scaleHeight(context, 64);
    double spacingAboveVerifyButton = scaleHeight(context, 32);
    double actionButtonHeight = scaleHeight(context, 40);

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: Column(
          children: <Widget>[
            buildTopBar(context),
            Expanded(
              child: ScrollConfiguration(
                behavior: const NoBounceScrollBehavior(),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(height: topGap),
                        Center(
                          child: Text(
                            '아이디 찾기',
                            style: TextStyle(
                              fontFamily: 'gm-medium',
                              fontSize: scaleWidth(context, 24),
                              color: kBlueFontColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: spacingBelowTitle),
                        buildInputField(
                          context,
                          '이름',
                          '이름을 입력하세요.',
                          nameTextEditingController,
                        ),
                        SizedBox(height: spacingBetweenFields),
                        buildInputField(
                          context,
                          '메일',
                          '가입에 사용한 메일을 입력하세요.',
                          emailTextEditingController,
                        ),
                        SizedBox(height: spacingAboveSendButton),
                        SizedBox(
                          width: double.infinity,
                          height: actionButtonHeight,
                          child: OutlinedButton(
                            onPressed: performSendVerificationCode,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBlueFontColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                            ),
                            child: Text(
                              '인증메일 보내기',
                              style: buildTextStyle(context, 15),
                            ),
                          ),
                        ),
                        SizedBox(height: spacingAboveCodeField),
                        buildInputField(
                          context,
                          '인증번호',
                          '인증번호를 입력하세요.',
                          verificationCodeTextEditingController,
                          isError: isVerificationCodeError,
                          errorMessage: verificationCodeErrorMessage,
                        ),
                        SizedBox(height: spacingAboveVerifyButton),
                        SizedBox(
                          width: double.infinity,
                          height: actionButtonHeight,
                          child: ElevatedButton(
                            onPressed: performVerifyCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBlueFontColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            child: Text(
                              '확인',
                              style: buildTextStyle(context, 15, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: scaleHeight(context, 24)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopBar(BuildContext context) {
    return Container(
      height: scaleHeight(context, 60),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
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
            style: TextStyle(
              fontFamily: 'gm-medium',
              fontSize: scaleWidth(context, 18),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputField(
    BuildContext context,
    String fieldLabel,
    String hintText,
    TextEditingController controller, {
    bool isError = false,
    String errorMessage = '',
  }) {
    TextStyle labelStyle = buildTextStyle(
      context,
      15,
      color: isError ? const Color(0xFFC42B1C) : Colors.black,
    );
    TextStyle errorStyle = buildTextStyle(
      context,
      13,
      color: const Color(0xFFC42B1C),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(fieldLabel, style: labelStyle),
            if (isError) ...[
              SizedBox(width: scaleWidth(context, 6)),
              Flexible(
                child: Text(
                  errorMessage,
                  style: errorStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: scaleHeight(context, 6)),
        Container(
          height: scaleHeight(context, 40),
          padding: EdgeInsets.fromLTRB(
            scaleWidth(context, 12),
            scaleHeight(context, 6),
            scaleWidth(context, 12),
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isError ? const Color(0xFFC42B1C) : const Color(0xFFB3B3B3),
            ),
          ),
          child: TextField(
            controller: controller,
            style: buildTextStyle(context, 15),
            textAlignVertical: TextAlignVertical.center,
            cursorColor: Colors.black,
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: buildTextStyle(context, 15, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}
