import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/infra_controller.dart';
import '../../viewmodel/controller/mqtt_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../../viewmodel/controller/vehicle_controller.dart';
import '../components/empty_top_bar_view.dart';
import '../components/input_edit_text_underline.dart';
import 'home_page.dart';
import 'login_find_id_page.dart';
import 'login_find_pw_page.dart';
import 'signup_register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const String routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idTextEditingController = TextEditingController();
  final TextEditingController _passwordTextEditingController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _checkRememberMe = false;
  bool _showPassword = false;
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRememberMe();
      if (!mounted) {
        return;
      }
      if (_idTextEditingController.text.isNotEmpty) {
        _passwordFocusNode.requestFocus();
      } else {
        _idFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _idTextEditingController.dispose();
    _passwordTextEditingController.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRememberMe() async {
    final UserController userController = Get.find<UserController>();
    _checkRememberMe = await userController.reqGetRememberMe();
    if (_checkRememberMe == true) {
      _idTextEditingController.text = await userController.reqGetLoginEmail();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _requestLogin() async {
    if (_idTextEditingController.text.isEmpty) {
      Utils.showSnackBar('Enter your ID', isError: true);
      _idFocusNode.requestFocus();
      return;
    }
    if (_passwordTextEditingController.text.isEmpty) {
      Utils.showSnackBar('Enter your password', isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }

    setState(() {
      _loggingIn = true;
    });

    final UserController userController = Get.find<UserController>();
    final bool isLoginSuccessful = await userController.reqLoginById(
      _idTextEditingController.text.trim(),
      _passwordTextEditingController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loggingIn = false;
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
    await infraController.reqLoadInfraIdentifiers();

    userController.reqSaveRememberMe(_checkRememberMe);
    if (_checkRememberMe) {
      userController.reqSaveLoginEmail(_idTextEditingController.text.trim());
    }

    if (!mounted) {
      return;
    }

    Get.offNamed(HomePage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: <Widget>[
            const EmptyTopBarView(),
            Expanded(child: _buildLoginBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginBody() {
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
              _buildLeftPanel(),
              _buildRightPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
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

  Widget _buildRightPanel() {
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
                  textController: _idTextEditingController,
                  focusNode: _idFocusNode,
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
                      _passwordFocusNode.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: InputEditTextUnderline(
                  textController: _passwordTextEditingController,
                  focusNode: _passwordFocusNode,
                  obscureText: !_showPassword,
                  hintText: '비밀번호를 입력하세요.',
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
                  onChanged: (String value) {
                    setState(() {});
                  },
                  onSubmit: (String value) {
                    if (value.isNotEmpty) {
                      _requestLogin();
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
                        _checkRememberMe = !_checkRememberMe;
                        setState(() {});
                      },
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            _checkRememberMe
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
                    onPressed: _loggingIn ? null : _requestLogin,
                    child: _loggingIn
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
}
