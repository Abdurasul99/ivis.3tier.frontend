// lib/view/pages/mobile/login_page_mobile.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/utils/utils.dart';
import '/view/components/input_edit_text_underline.dart';
import '/view/pages/home_page.dart';
import '/view/pages/mobile/login_find_id_page_mobile.dart';
import '/view/pages/mobile/login_find_pw_page_mobile.dart';
import '/viewmodel/controller/dashboard_controller.dart';
import '/viewmodel/controller/mqtt_controller.dart';
import '/viewmodel/controller/notification_controller.dart';
import '/viewmodel/controller/robot_controller.dart';
import '/viewmodel/controller/user_controller.dart';

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
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context, {ScrollPhysics? parent}) {
    return const ClampingScrollPhysics();
  }
}

class LoginPageMobile extends StatefulWidget {
  const LoginPageMobile({Key? key}) : super(key: key);

  static const String loginPageRouteName = '/login';

  @override
  State<LoginPageMobile> createState() => _LoginPageMobileState();
}

class _LoginPageMobileState extends State<LoginPageMobile> {
  final TextEditingController userIdTextController = TextEditingController();
  final TextEditingController passwordTextController = TextEditingController();
  final FocusNode userIdFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  bool isRememberMeChecked = false;
  bool isPasswordVisible = false;

  /// null: no input; true: valid; false: invalid
  bool? isUserIdValid;

  @override
  void initState() {
    super.initState();
    userIdTextController.addListener(_validateUserIdInput);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRememberMeSettings();
      if (userIdTextController.text.isNotEmpty) {
        passwordFocusNode.requestFocus();
      } else {
        userIdFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    userIdTextController.dispose();
    passwordTextController.dispose();
    userIdFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateUserIdInput() {
    String currentInput = userIdTextController.text.trim();
    setState(() {
      if (currentInput.isEmpty) {
        isUserIdValid = null;
      } else {
        final RegExp validPattern = RegExp(r'^[a-zA-Z0-9@.]+$');
        isUserIdValid = validPattern.hasMatch(currentInput);
      }
    });
  }

  Future<void> _loadRememberMeSettings() async {
    UserController userController = Get.find<UserController>();
    isRememberMeChecked = await userController.reqGetRememberMe();
    if (isRememberMeChecked) {
      userIdTextController.text = await userController.reqGetLoginEmail();
    } else {
      userIdTextController.clear();
    }
    if (mounted) setState(() {});
  }

  Future<void> _performLogin() async {
    if (userIdTextController.text.isEmpty) {
      Utils.showSnackBar('Enter your ID', isError: true);
      userIdFocusNode.requestFocus();
      return;
    }
    if (passwordTextController.text.isEmpty) {
      Utils.showSnackBar('Enter your password', isError: true);
      passwordFocusNode.requestFocus();
      return;
    }

    UserController userController = Get.find<UserController>();
    bool loginSuccess = await userController.reqLoginById(
      userIdTextController.text.trim(),
      passwordTextController.text.trim(),
    );
    if (!loginSuccess) {
      Utils.showSnackBar('Invalid ID or password', isError: true);
      return;
    }

    await Get.find<NotificationController>().reqUnreadNotifications();
    await Get.find<DashboardController>().reqDashboardLayoutSetting();
    Get.find<MqttController>().connect(userController.loginUser!.email!);
    final RobotController robotController = Get.find<RobotController>();
    await robotController.reqRobotTypes();
    await robotController.reqRobotList();
    await robotController.reqRobotStatusList();

    await userController.reqSaveRememberMe(isRememberMeChecked);
    if (isRememberMeChecked) {
      await userController.reqSaveLoginEmail(userIdTextController.text.trim());
    } else {
      await userController.reqSaveLoginEmail('');
    }

    Get.offNamed(HomePage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = scaleWidth(context, 41);
    final double topSpacing = 117.0;
    final double spacingTitleToUserId = 80.0;
    final double spacingBetweenFields = scaleHeight(context, 24);
    final double spacingFieldToRemember = scaleHeight(context, 22);
    final double spacingFieldToLogin = scaleHeight(context, 250);
    final double spacingLinksToLogin = scaleHeight(context, 55);
    final double loginButtonHeight = scaleHeight(context, 48);
    final double bottomPadding = MediaQuery.of(context).padding.bottom + scaleHeight(context, 1);

    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: kBackgroundColor,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: <Widget>[
              _buildTopBar(context),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const NoBounceScrollBehavior(),
                  child: CustomScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(height: topSpacing),
                              Center(
                                child: Text(
                                  '로그인',
                                  style: TextStyle(
                                    fontSize: scaleWidth(context, 30),
                                    color: kBlueFontColor,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'gm-medium',
                                  ),
                                ),
                              ),
                              SizedBox(height: spacingTitleToUserId),
                              InputEditTextUnderline(
                                textController: userIdTextController,
                                focusNode: userIdFocusNode,
                                hintText: '아이디를 입력하세요.',
                                icon: Icon(
                                  CupertinoIcons.person,
                                  size: scaleWidth(context, 18),
                                  color: kDarkGrayColor,
                                ),
                                iconOnRight: isUserIdValid == null
                                    ? null
                                    : Icon(
                                        isUserIdValid! ? Icons.check_circle : Icons.cancel,
                                        size: scaleWidth(context, 18),
                                        color: isUserIdValid! ? Colors.green : Colors.red,
                                      ),
                                onSubmit: (_) => passwordFocusNode.requestFocus(),
                              ),
                              SizedBox(height: spacingBetweenFields),
                              InputEditTextUnderline(
                                textController: passwordTextController,
                                focusNode: passwordFocusNode,
                                obscureText: !isPasswordVisible,
                                hintText: '비밀번호를 입력하세요.',
                                icon: Icon(
                                  CupertinoIcons.lock,
                                  size: scaleWidth(context, 18),
                                  color: kDarkGrayColor,
                                ),
                                iconOnRight: Icon(
                                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  size: scaleWidth(context, 18),
                                  color: kDarkGrayColor,
                                ),
                                onTapRightIcon: () => setState(() => isPasswordVisible = !isPasswordVisible),
                                onSubmit: (_) => _performLogin(),
                              ),
                              SizedBox(height: spacingFieldToRemember),
                              Padding(
                                padding: EdgeInsets.only(left: scaleWidth(context, 28)),
                                child: Row(
                                  children: <Widget>[
                                    GestureDetector(
                                      onTap: () => setState(() => isRememberMeChecked = !isRememberMeChecked),
                                      child: SvgPicture.asset(
                                        isRememberMeChecked
                                            ? 'assets/images/icons_checkbox_checked.svg'
                                            : 'assets/images/icons_checkbox_unchecked.svg',
                                        width: scaleWidth(context, 16),
                                      ),
                                    ),
                                    SizedBox(width: scaleWidth(context, 8)),
                                    Text(
                                      '아이디 저장',
                                      style: TextStyle(
                                        fontFamily: 'pretendard',
                                        fontSize: scaleWidth(context, 15),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: spacingFieldToLogin -
                                    spacingFieldToRemember -
                                    spacingBetweenFields -
                                    spacingLinksToLogin,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  LinkWidget(
                                    linkText: '아이디 찾기',
                                    onLinkTap: () => Get.toNamed(LoginFindIdPageMobile.routeName),
                                  ),
                                  SlashDivider(),
                                  LinkWidget(
                                    linkText: '비밀번호 찾기',
                                    onLinkTap: () => Get.toNamed(LoginFindPwPageMobile.routeName),
                                  ),
                                  SlashDivider(),
                                  LinkWidget(
                                    linkText: '회원가입',
                                    onLinkTap: () => Get.toNamed('/register-first'),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacingLinksToLogin),
                              SizedBox(
                                height: loginButtonHeight,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kBlueFontColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  onPressed: _performLogin,
                                  child: Text(
                                    '로그인',
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: scaleWidth(context, 16),
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: bottomPadding),
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

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: scaleHeight(context, 60),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withOpacity(0.05), offset: Offset(0, 1), blurRadius: 3)],
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: scaleWidth(context, 24)),
          SvgPicture.asset('assets/images/icons_symbol.svg', width: scaleWidth(context, 24)),
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
}

class LinkWidget extends StatelessWidget {
  final String linkText;
  final VoidCallback onLinkTap;

  const LinkWidget({
    required this.linkText,
    required this.onLinkTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLinkTap,
      child: Text(
        linkText,
        style: TextStyle(
          fontSize: scaleWidth(context, 15),
          color: kBlueFontColor,
          fontWeight: FontWeight.w400,
          fontFamily: 'pretendard',
        ),
      ),
    );
  }
}

class SlashDivider extends StatelessWidget {
  const SlashDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scaleWidth(context, 8)),
      child: Text(
        '/',
        style: TextStyle(
          fontSize: scaleWidth(context, 14),
          color: kBlueFontColor,
        ),
      ),
    );
  }
}
