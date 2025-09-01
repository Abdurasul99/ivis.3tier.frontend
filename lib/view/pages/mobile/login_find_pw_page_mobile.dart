// lib/view/pages/mobile/login_find_pw_page_mobile.dart

import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/utils/utils.dart';
import '/viewmodel/controller/password_controller.dart';

// ────────── responsive helpers ──────────
const double _designW = 390, _designH = 812;
double sw(BuildContext c, double px) => (MediaQuery.of(c).size.width * (px / _designW)).roundToDouble();
double sh(BuildContext c, double px) => (MediaQuery.of(c).size.height * (px / _designH)).roundToDouble();

class LoginFindPwPageMobile extends StatefulWidget {
  static const routeName = '/find-pw';
  const LoginFindPwPageMobile({super.key});

  @override
  State<LoginFindPwPageMobile> createState() => _LoginFindPwPageState();
}

class _LoginFindPwPageState extends State<LoginFindPwPageMobile> {
  final _userIdCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _codeCtl = TextEditingController();

  bool _codeErr = false;
  String _codeErrMsg = '';

  @override
  void initState() {
    super.initState();
    _injectIOSGhostFix(); // runtime-CSS (Safari ghost fix)
  }

  @override
  void dispose() {
    _userIdCtl.dispose();
    _emailCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  // ───── Safari ghost-scroll CSS ─────
  void _injectIOSGhostFix() {
    if (!kIsWeb) return;
    if (html.document.getElementById('ios-ghost-fix') != null) return;

    html.document.head!.append(html.StyleElement()
      ..id = 'ios-ghost-fix'
      ..innerHtml = '''
        .flt-glass-pane{transform:translateZ(0);}
        body,#flt-platform-view{overscroll-behavior:contain;}
      ''');
  }

  ThemeData _theme(BuildContext c) => Theme.of(c).copyWith(
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.black),
        inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
      );

  @override
  Widget build(BuildContext context) {
    final hPad = sw(context, 41);
    final topGap = sh(context, 120); 
    final titleToInput = sh(context, 32);
    final betweenInputs = sh(context, 28);
    final inputToButton = sh(context, 50);
    final buttonToCode = sh(context, 64);
    final codeToOk = sh(context, 31);
    final buttonHeight = sh(context, 40);

    final labelStyle = TextStyle(fontFamily: 'pretendard', fontSize: sw(context, 15));
    final hintStyle = labelStyle.copyWith(color: const Color(0xFF666565));
    final errorStyle = labelStyle.copyWith(fontSize: sw(context, 13), color: const Color(0xFFC42B1C));

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: kBackgroundColor,
        body: Theme(
          data: _theme(context),
          child: Column(
            children: [
              _topBar(context, labelStyle),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _NoBounceScroll(),
                  child: CustomScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: topGap),

                              // ─── Title
                              Center(
                                child: Text(
                                  '비밀번호 찾기',
                                  style: TextStyle(
                                    fontFamily: 'gm-medium',
                                    fontSize: sw(context, 30),
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF005FB7),
                                  ),
                                ),
                              ),
                              SizedBox(height: titleToInput),

                              // ─── Fields
                              _field('아이디', '아이디를 입력하세요.', _userIdCtl, labelStyle, hintStyle, errorStyle),
                              SizedBox(height: betweenInputs),
                              _field('메일', '가입에 사용한 메일을 입력하세요.', _emailCtl, labelStyle, hintStyle, errorStyle),
                              SizedBox(height: inputToButton),

                              // ─── Send-code
                              SizedBox(
                                height: buttonHeight,
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF005FB7)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                  ).copyWith(overlayColor: MaterialStateProperty.all(Colors.transparent)),
                                  onPressed: _sendCode,
                                  child: Text('인증메일 보내기', style: labelStyle.copyWith(color: Colors.black)),
                                ),
                              ),
                              SizedBox(height: buttonToCode),

                              _field('인증번호', '인증번호를 입력하세요.', _codeCtl, labelStyle, hintStyle, errorStyle,
                                  isErr: _codeErr, errMsg: _codeErrMsg),
                              SizedBox(height: codeToOk),

                              // ─── Verify
                              SizedBox(
                                height: buttonHeight,
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kBlueFontColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  onPressed: _verifyCode,
                                  child: Text('확인', style: labelStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────── sub-widgets
  Widget _topBar(BuildContext c, TextStyle labelStyle) => Container(
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
                style: labelStyle.copyWith(fontFamily: 'gm-medium', fontWeight: FontWeight.w500, fontSize: sw(c, 18))),
          ],
        ),
      );

  Widget _field(
    String label,
    String hint,
    TextEditingController ctl,
    TextStyle labelStyle,
    TextStyle hintStyle,
    TextStyle errorStyle, {
    bool isErr = false,
    String errMsg = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: isErr ? labelStyle.copyWith(color: const Color(0xFFC42B1C)) : labelStyle),
            if (isErr) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(errMsg,
                    style: errorStyle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
              )
            ]
          ],
        ),
        SizedBox(height: sh(context, 6)),
        Container(
          height: sh(context, 40),
          padding: EdgeInsets.fromLTRB(sw(context, 12), sh(context, 6), sw(context, 12), 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: isErr ? const Color(0xFFC42B1C) : const Color(0xFFB3B3B3)),
          ),
          child: TextField(
            controller: ctl,
            style: labelStyle,
            textAlignVertical: TextAlignVertical.center,
            cursorColor: Colors.black,
            decoration: InputDecoration.collapsed(hintText: hint, hintStyle: hintStyle),
          ),
        ),
      ],
    );
  }

  // ────────── actions
  Future<void> _sendCode() async {
    if (_userIdCtl.text.isEmpty || _emailCtl.text.isEmpty) {
      Utils.showSnackBar('아이디와 메일을 입력하세요.', isError: true);
      return;
    }
    final ctrl = Get.find<PasswordController>();
    final res = await ctrl.reqResetPassword(_emailCtl.text.trim());

    if (res == null) {
      Utils.showSnackBar('서버 오류가 발생했습니다.', isError: true);
    } else if (res.code == '0000') {
      Utils.showSnackBar('인증메일을 보냈습니다. 메일을 확인해주세요.');
    } else {
      Utils.showSnackBar('메일 전송 실패: ${res.message}', isError: true);
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _codeErr = false;
      _codeErrMsg = '';
    });

    if (_codeCtl.text.trim().isEmpty) {
      setState(() {
        _codeErr = true;
        _codeErrMsg = '인증번호를 입력하세요.';
      });
      return;
    }

    final ctrl = Get.find<PasswordController>();
    final res = await ctrl.reqPasswordVerifyCode(_emailCtl.text.trim(), _codeCtl.text.trim());

    if (res == null) {
      setState(() {
        _codeErr = true;
        _codeErrMsg = '서버 오류가 발생했습니다.';
      });
    } else if (res.code == '0000') {
      Utils.showSnackBar('인증되었습니다. 비밀번호를 재설정하세요.');
      Get.offAllNamed('/reset-pw');
    } else {
      setState(() {
        _codeErr = true;
        _codeErrMsg = '인증번호가 올바르지 않습니다.';
      });
    }
  }
}

// ────────── scroll-behavior helper ──────────
class _NoBounceScroll extends ScrollBehavior {
  const _NoBounceScroll();
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection _) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext _, {ScrollPhysics? parent}) => const ClampingScrollPhysics();
}
