// lib/view/pages/signup_register_page_mobile.dart

import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fms/view/pages/mobile/signup_page_mobile.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/utils/utils.dart';
import '/viewmodel/controller/register_controller.dart';
import '/view/pages/signup_page.dart';

const double designWidth = 390.0;
const double designHeight = 812.0;

double sw(BuildContext c, double px) => (MediaQuery.of(c).size.width * (px / designWidth)).roundToDouble();
double sh(BuildContext c, double px) => (MediaQuery.of(c).size.height * (px / designHeight)).roundToDouble();

class NoBounceScrollBehavior extends ScrollBehavior {
  const NoBounceScrollBehavior();
  @override
  Widget buildViewportChrome(BuildContext c, Widget child, AxisDirection _) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext c, {ScrollPhysics? parent}) => const ClampingScrollPhysics();
}

class SignupRegisterPageMobile extends StatefulWidget {
  const SignupRegisterPageMobile({Key? key}) : super(key: key);
  static const String routeName = '/register-first';
  @override
  State<SignupRegisterPageMobile> createState() => _SignupRegisterPageMobileState();
}

class _SignupRegisterPageMobileState extends State<SignupRegisterPageMobile> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  bool isNameError = false, isEmailError = false, isCodeError = false;
  String? nameErrorText, emailErrorText, codeErrorText;

  @override
  void initState() {
    super.initState();
    _injectIosFix();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  void _injectIosFix() {
    if (!kIsWeb) return;
    if (html.document.getElementById('ios-ghost-fix') != null) return;
    final style = html.StyleElement()
      ..id = 'ios-ghost-fix'
      ..innerHtml = '''
        .flt-glass-pane { transform: translateZ(0); }
        body, #flt-platform-view { overscroll-behavior: contain; }
      ''';
    html.document.head!.append(style);
  }

  TextStyle _tx(BuildContext c, double size, {Color color = Colors.black, FontWeight w = FontWeight.w400}) =>
      TextStyle(fontFamily: 'pretendard', fontSize: sw(c, size), color: color, height: 1.0, fontWeight: w);

  Future<void> _sendCode() async {
    setState(() {
      isNameError = isEmailError = false;
      nameErrorText = emailErrorText = null;
    });
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    if (name.isEmpty) {
      setState(() {
        isNameError = true;
        nameErrorText = '이름을 입력해주세요.';
      });
      return;
    }
    if (email.isEmpty) {
      setState(() {
        isEmailError = true;
        emailErrorText = '메일을 입력해주세요.';
      });
      return;
    }
    final ctrl = Get.find<RegisterController>();
    final ok = await ctrl.sendRegisterCode(name, email);
    if (ok) {
      Utils.showSnackBar('인증번호가 발송되었습니다. 이메일 확인해주세요.');
    } else {
      setState(() {
        isEmailError = true;
        emailErrorText = '서버 오류 혹은 메일주소가 잘못됨.';
      });
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      isCodeError = false;
      codeErrorText = null;
    });
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        isCodeError = true;
        codeErrorText = '인증번호를 입력해주세요.';
      });
      return;
    }
    if (email.isEmpty) {
      setState(() {
        isEmailError = true;
        emailErrorText = '메일을 먼저 입력해주세요.';
      });
      return;
    }
    final ctrl = Get.find<RegisterController>();
    final ok = await ctrl.verifyRegisterCode(email, code);
    if (!ok) {
      setState(() {
        isCodeError = true;
        codeErrorText = '인증번호가 유효하지 않습니다.';
      });
      return;
    }
    Utils.showSnackBar('인증번호 확인 성공! 다음 단계로 이동하세요.');
    Get.toNamed(SignUpPageMobile.routeName, arguments: {'name': name, 'email': email});
  }

  @override
  Widget build(BuildContext context) {
    final hPad = sw(context, 41);
    final topGap = sh(context, 120);
    final fldGap = sh(context, 32);
    final sendGap = sh(context, 64);
    final okGap = sh(context, 32);
    final btnH = sh(context, 40);

    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            _topBar(context),
            Expanded(
              child: ScrollConfiguration(
                behavior: const NoBounceScrollBehavior(),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topGap),
                        Center(
                            child: Text('회원가입',
                                style: TextStyle(
                                    fontFamily: 'gm-medium',
                                    fontSize: sw(context, 30),
                                    fontWeight: FontWeight.w500,
                                    color: kBlueFontColor))),
                        SizedBox(height: fldGap),
                        _field(context, '이름', '이름을 입력하세요.', nameController, isNameError, nameErrorText),
                        SizedBox(height: fldGap),
                        _field(context, '메일', '가입에 사용한 메일을 입력하세요.', emailController, isEmailError, emailErrorText),
                        SizedBox(height: sendGap),
                        SizedBox(
                          width: double.infinity,
                          height: btnH,
                          child: OutlinedButton(
                            onPressed: _sendCode,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBlueFontColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                              splashFactory: NoSplash.splashFactory,
                            ),
                            child: Text('인증메일 보내기', style: _tx(context, 15)),
                          ),
                        ),
                        SizedBox(height: sendGap),
                        _field(context, '인증번호', '인증번호를 입력하세요.', codeController, isCodeError, codeErrorText),
                        SizedBox(height: okGap),
                        SizedBox(
                          width: double.infinity,
                          height: btnH,
                          child: ElevatedButton(
                            onPressed: _verifyCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBlueFontColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                              splashFactory: NoSplash.splashFactory,
                            ),
                            child: Text('확인', style: _tx(context, 15, color: Colors.white)),
                          ),
                        ),
                        SizedBox(height: sh(context, 24)),
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

  Widget _topBar(BuildContext c) => Container(
        height: sh(c, 60),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), offset: const Offset(0, 1), blurRadius: 3)],
        ),
        child: Row(
          children: [
            SizedBox(width: sw(c, 24)),
            SvgPicture.asset('assets/images/icons_symbol.svg', width: sw(c, 24)),
            SizedBox(width: sw(c, 16)),
            Text('아이비스 FMS 관제 시스템',
                style: TextStyle(fontFamily: 'gm-medium', fontSize: sw(c, 18), fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _field(
    BuildContext context,
    String label,
    String hint,
    TextEditingController ctl,
    bool isErr,
    String? errMsg,
  ) {
    final labelStyle = _tx(context, 15, color: isErr ? const Color(0xFFC42B1C) : Colors.black);
    final hintStyle = labelStyle.copyWith(color: const Color(0xFF666565));
    final errorStyle = labelStyle.copyWith(fontSize: sw(context, 13), color: const Color(0xFFC42B1C));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        SizedBox(height: sh(context, 6)),
        Container(
          height: sh(context, 40),
          padding: EdgeInsets.fromLTRB(sw(context, 12), sh(context, 8), sw(context, 12), 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: isErr ? const Color(0xFFC42B1C) : const Color(0xFFB3B3B3)),
          ),
          child: TextField(
            controller: ctl,
            style: labelStyle,
            cursorColor: Colors.black,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: hintStyle,
            ),
          ),
        ),
        if (isErr && errMsg != null) ...[
          SizedBox(height: sh(context, 4)),
          Text(errMsg, style: errorStyle),
        ],
      ],
    );
  }
}
