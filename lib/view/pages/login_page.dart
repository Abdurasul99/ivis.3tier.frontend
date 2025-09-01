import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fms/view/components/empty_top_bar_view.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/pages/mobile/login_page_mobile.dart';
import 'package:fms/view/pages/signup_register_page.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/mqtt_controller.dart';
import '../../viewmodel/controller/notification_controller.dart';
import '../../viewmodel/controller/robot_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/input_edit_text_underline.dart';
import 'home_page.dart';
import 'login_find_id_page.dart';
import 'login_find_pw_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idEditController = TextEditingController();
  final TextEditingController _passwordEditController = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _checkRememberMe = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadRememberMe();
      if (_idEditController.text.isNotEmpty) {
        _passwordFocusNode.requestFocus();
      } else {
        _idFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _idEditController.dispose();
    _passwordEditController.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadRememberMe() async {
    _checkRememberMe = await Get.find<UserController>().reqGetRememberMe();
    if (_checkRememberMe == true) {
      _idEditController.text = await Get.find<UserController>().reqGetLoginEmail();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const LoginPageMobile();
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
              child: buildLoginBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLoginBody() {
    return Container(
      alignment: Alignment.center,
      child: Container(
        height: 554,
        width: 794,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.25),
              offset: const Offset(0, 0),
              blurRadius: 8.0,
            ),
          ],
        ),
        child: Row(
          children: [
            buildLeftPanel(),
            buildRightPanel(),
          ],
        ),
      ),
    );
  }

  Widget buildLeftPanel() {
    return Flexible(
      flex: 344,
      child: Stack(
        children: [
          Container(
            height: 554,
            width: 344,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFD),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              height: 440,
              width: 323,
              decoration: const BoxDecoration(
                color: Color(0xFFFAFCFD),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(10)),
                image: DecorationImage(
                  image: AssetImage("assets/images/img_login_background.png"),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRightPanel() {
    return Flexible(
      flex: 450,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            const SizedBox(height: 94),
            const Text(
              "로그인",
              style: TextStyle(
                fontFamily: 'gm-medium',
                fontSize: 40,
                color: kBlueFontColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 57),

            // ID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: InputEditTextUnderline(
                textController: _idEditController,
                focusNode: _idFocusNode,
                hintText: "아이디를 입력하세요.",
                icon: const Icon(
                  CupertinoIcons.person,
                  size: 18,
                  color: kDarkGrayColor,
                ),
                onChanged: (value) => setState(() {}),
                onSubmit: (value) {
                  if (value.isNotEmpty) {
                    _passwordFocusNode.requestFocus();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // PW
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: InputEditTextUnderline(
                textController: _passwordEditController,
                focusNode: _passwordFocusNode,
                obscureText: !_showPassword,
                hintText: "비밀번호를 입력하세요.",
                icon: const Icon(
                  CupertinoIcons.lock,
                  size: 18,
                  color: kDarkGrayColor,
                ),
                iconOnRight: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: kDarkGrayColor,
                ),
                onTapRightIcon: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
                onChanged: (value) => setState(() {}),
                onSubmit: (value) {
                  if (value.isNotEmpty) {
                    requestLogin();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // Remember me
            Row(
              children: [
                const SizedBox(width: 56),
                GestureDetector(
                  onTap: () {
                    _checkRememberMe = !_checkRememberMe;
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      SvgPicture.asset(
                        _checkRememberMe
                            ? "assets/images/icons_checkbox_checked.svg"
                            : "assets/images/icons_checkbox_unchecked.svg",
                        width: 14,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "아이디 저장",
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 15,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 56),
              ],
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Get.toNamed(LoginFindIdPage.routeName);
                  },
                  child: const Text(
                    "아이디 찾기",
                    style: TextStyle(
                      fontSize: 15,
                      color: kBlueFontColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Text(
                  " / ",
                  style: TextStyle(
                    fontSize: 15,
                    color: kBlueFontColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Get.toNamed(LoginFindPwPage.routeName);
                  },
                  child: const Text(
                    "비밀번호 찾기",
                    style: TextStyle(
                      fontSize: 15,
                      color: kBlueFontColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Text(
                  " / ",
                  style: TextStyle(
                    fontSize: 15,
                    color: kBlueFontColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Get.toNamed(SignupRegisterPage.routeName);
                  },
                  child: const Text(
                    "회원가입",
                    style: TextStyle(
                      fontSize: 15,
                      color: kBlueFontColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: requestLogin,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 52),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kBlueFontColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "로그인",
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> requestLogin() async {
    if (_idEditController.text.isEmpty) {
      Utils.showSnackBar("Enter your ID", isError: true);
      _idFocusNode.requestFocus();
      return;
    }

    if (_passwordEditController.text.isEmpty) {
      Utils.showSnackBar("Enter your password", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }

    final userCtrl = Get.find<UserController>();
    bool result = await userCtrl.reqLoginById(
      _idEditController.text.trim(),
      _passwordEditController.text.trim(),
    );

    if (!result) {
      Utils.showSnackBar("Invalid ID or password", isError: true);
      return;
    }

    Get.find<NotificationController>().reqUnreadNotifications();
    Get.find<DashboardController>().reqDashboardLayoutSetting();
    Get.find<MqttController>().connect(Get.find<UserController>().loginUser!.email!);
    Get.find<RobotController>().reqRobotTypes();
    Get.find<RobotController>().reqRobotList();
    Get.find<RobotController>().reqRobotStatusList();
    Get.find<RobotController>().setRobotFilterStr("3tier");

    userCtrl.reqSaveRememberMe(_checkRememberMe);
    if (_checkRememberMe) {
      userCtrl.reqSaveLoginEmail(_idEditController.text.trim());
    }

    Get.offNamed(HomePage.routeName);
  }
}
