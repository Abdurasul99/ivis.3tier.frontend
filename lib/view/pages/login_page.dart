import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ivis/view/components/empty_top_bar_view.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:ivis/view/pages/signup_register_page.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';
import 'package:get/get.dart';
import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/mqtt_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/input_edit_text_underline.dart';
import 'home_page.dart';
import 'login_find_id_page.dart';
import 'login_find_pw_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const String routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController idTextEditingController = TextEditingController();
  final TextEditingController passwordTextEditingController = TextEditingController();
  final FocusNode idFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  bool checkRememberMe = false;
  bool showPassword = false;
  bool loggingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadRememberMe();
      if (!mounted) {
        return;
      }
      if (idTextEditingController.text.isNotEmpty) {
        passwordFocusNode.requestFocus();
      } else {
        idFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    idTextEditingController.dispose();
    passwordTextEditingController.dispose();
    idFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadRememberMe() async {
    final UserController userController = Get.find<UserController>();
    checkRememberMe = await userController.reqGetRememberMe();
    if (checkRememberMe == true) {
      idTextEditingController.text = await userController.reqGetLoginEmail();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          backgroundColor: kBackgroundColor,
          body: Column(
            children: <Widget>[
              const EmptyTopBarView(),
              Expanded(child: buildLoginBody()),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: <Widget>[
            const EmptyTopBarView(),
            Expanded(child: buildLoginBody()),
          ],
        ),
      ),
    );
  }

  Widget buildLoginBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          height: 554,
          width: 794,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.25),
                offset: const Offset(0, 0),
                blurRadius: 8.0,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              buildLeftPanel(),
              buildRightPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLeftPanel() {
    return SizedBox(
      width: 344,
      height: 554,
      child: Stack(
        children: <Widget>[
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
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                ),
                image: DecorationImage(
                  image: AssetImage('assets/images/img_login_background.png'),
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
    return SizedBox(
      width: 450,
      height: 554,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 94),
              const Text(
                '로그인',
                style: TextStyle(
                  fontFamily: 'gm-medium',
                  fontSize: 40,
                  color: kBlueFontColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 57),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: InputEditTextUnderline(
                  textController: idTextEditingController,
                  focusNode: idFocusNode,
                  hintText: '아이디를 입력하세요.',
                  icon: const Icon(
                    CupertinoIcons.person,
                    size: 18,
                    color: kDarkGrayColor,
                  ),
                  onChanged: (String value) {
                    setState(() {});
                  },
                  onSubmit: (String value) {
                    if (value.isNotEmpty) {
                      passwordFocusNode.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: InputEditTextUnderline(
                  textController: passwordTextEditingController,
                  focusNode: passwordFocusNode,
                  obscureText: !showPassword,
                  hintText: '비밀번호를 입력하세요.',
                  icon: const Icon(
                    CupertinoIcons.lock,
                    size: 18,
                    color: kDarkGrayColor,
                  ),
                  iconOnRight: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: kDarkGrayColor,
                  ),
                  onTapRightIcon: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  onChanged: (String value) {
                    setState(() {});
                  },
                  onSubmit: (String value) {
                    if (value.isNotEmpty) {
                      requestLogin();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: () {
                        checkRememberMe = !checkRememberMe;
                        setState(() {});
                      },
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            checkRememberMe
                                ? 'assets/images/icons_checkbox_checked.svg'
                                : 'assets/images/icons_checkbox_unchecked.svg',
                            width: 14,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '아이디 저장',
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
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(LoginFindIdPage.routeName);
                    },
                    child: const Text(
                      '아이디 찾기',
                      style: TextStyle(
                        fontSize: 15,
                        color: kBlueFontColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Text(
                    ' / ',
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
                      '비밀번호 찾기',
                      style: TextStyle(
                        fontSize: 15,
                        color: kBlueFontColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Text(
                    ' / ',
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
                      '회원가입',
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlueFontColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      disabledBackgroundColor: kBlueFontColor.withOpacity(0.5),
                    ),
                    onPressed: loggingIn ? null : requestLogin,
                    child: loggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '로그인',
                            style: TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> requestLogin() async {
    if (idTextEditingController.text.isEmpty) {
      Utils.showSnackBar('Enter your ID', isError: true);
      idFocusNode.requestFocus();
      return;
    }
    if (passwordTextEditingController.text.isEmpty) {
      Utils.showSnackBar('Enter your password', isError: true);
      passwordFocusNode.requestFocus();
      return;
    }

    setState(() {
      loggingIn = true;
    });

    final UserController userController = Get.find<UserController>();
    final bool isLoginSuccessful = await userController.reqLoginById(
      idTextEditingController.text.trim(),
      passwordTextEditingController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      loggingIn = false;
    });

    if (!isLoginSuccessful) {
      Utils.showSnackBar('Invalid ID or password', isError: true);
      return;
    }

    final String? loginUserEmail = userController.loginUser?.email?.trim();
    final String? loginUserId = userController.loginUser?.userId?.trim();
    final String clientId = (loginUserEmail != null && loginUserEmail.isNotEmpty)
        ? loginUserEmail
        : (loginUserId != null && loginUserId.isNotEmpty ? loginUserId : 'fms-web');

    final MqttController mqttController = Get.find<MqttController>();
    mqttController.connect(clientId);

    final VehicleController vehicleController = Get.find<VehicleController>();
    await vehicleController.reqLoadVehicles();

    final InfraController infraController = Get.find<InfraController>();
    await infraController.refreshAll();

    userController.reqSaveRememberMe(checkRememberMe);
    if (checkRememberMe) {
      userController.reqSaveLoginEmail(idTextEditingController.text.trim());
    }

    if (!mounted) {
      return;
    }

    Get.offNamed(HomePage.routeName);
  }
}
