import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/infra_controller.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/mqtt_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../../viewmodel/controller/vehicle_controller.dart';
import '../components/empty_top_bar_view.dart';
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
      if (!mounted) return;
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
    if (_checkRememberMe) {
      _idTextEditingController.text = await userController.reqGetLoginEmail();
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestLogin() async {
    if (_idTextEditingController.text.isEmpty) {
      Utils.showSnackBar(
        l10n('아이디를 입력하세요', 'Enter your ID'),
        isError: true,
      );
      _idFocusNode.requestFocus();
      return;
    }
    if (_passwordTextEditingController.text.isEmpty) {
      Utils.showSnackBar(
        l10n('비밀번호를 입력하세요', 'Enter your password'),
        isError: true,
      );
      _passwordFocusNode.requestFocus();
      return;
    }

    setState(() => _loggingIn = true);

    final UserController userController = Get.find<UserController>();
    final bool isLoginSuccessful = await userController.reqLoginById(
      _idTextEditingController.text.trim(),
      _passwordTextEditingController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loggingIn = false);

    if (!isLoginSuccessful) {
      Utils.showSnackBar(
        l10n('잘못된 아이디 또는 비밀번호입니다', 'Invalid ID or password'),
        isError: true,
      );
      return;
    }

    final String? loginUserEmail = userController.loginUser?.email?.trim();
    final String? loginUserId = userController.loginUser?.userId?.trim();
    final String clientId =
        (loginUserEmail != null && loginUserEmail.isNotEmpty)
            ? loginUserEmail
            : (loginUserId != null && loginUserId.isNotEmpty
                ? loginUserId
                : 'fms-web');

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

    if (!mounted) return;
    Get.offNamed(HomePage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => Scaffold(
        backgroundColor: kBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            const EmptyTopBarView(),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double screenWidth = constraints.maxWidth;
                  final double screenHeight = constraints.maxHeight;

                  if (screenWidth >= 720) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 920,
                              maxHeight: screenHeight * 0.88,
                            ),
                            child: IntrinsicHeight(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 32,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 55,
                                      child: Image.asset(
                                        'assets/images/3tier.png',
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topLeft,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 45,
                                      child: Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 48, vertical: 52),
                                        child: Center(
                                          child: _LoginFormContent(
                                            idController: _idTextEditingController,
                                            passwordController:
                                                _passwordTextEditingController,
                                            idFocusNode: _idFocusNode,
                                            passwordFocusNode:
                                                _passwordFocusNode,
                                            checkRememberMe: _checkRememberMe,
                                            showPassword: _showPassword,
                                            loggingIn: _loggingIn,
                                            onRememberMeToggle: () => setState(() =>
                                                _checkRememberMe =
                                                    !_checkRememberMe),
                                            onShowPasswordToggle: () => setState(() =>
                                                _showPassword = !_showPassword),
                                            onFieldChanged: () =>
                                                setState(() {}),
                                            onLoginPressed: _requestLogin,
                                            onIdSubmitted: () {
                                              if (_idTextEditingController
                                                  .text.isNotEmpty) {
                                                _passwordFocusNode.requestFocus();
                                              }
                                            },
                                            onPasswordSubmitted: () {
                                              if (_passwordTextEditingController
                                                  .text.isNotEmpty) {
                                                _requestLogin();
                                              }
                                            },
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
                      ),
                    );
                  }

                  return _StackedLayout(
                    idController: _idTextEditingController,
                    passwordController: _passwordTextEditingController,
                    idFocusNode: _idFocusNode,
                    passwordFocusNode: _passwordFocusNode,
                    checkRememberMe: _checkRememberMe,
                    showPassword: _showPassword,
                    loggingIn: _loggingIn,
                    onRememberMeToggle: () =>
                        setState(() => _checkRememberMe = !_checkRememberMe),
                    onShowPasswordToggle: () =>
                        setState(() => _showPassword = !_showPassword),
                    onFieldChanged: () => setState(() {}),
                    onLoginPressed: _requestLogin,
                    onIdSubmitted: () {
                      if (_idTextEditingController.text.isNotEmpty) {
                        _passwordFocusNode.requestFocus();
                      }
                    },
                    onPasswordSubmitted: () {
                      if (_passwordTextEditingController.text.isNotEmpty) {
                        _requestLogin();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _StackedLayout extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController passwordController;
  final FocusNode idFocusNode;
  final FocusNode passwordFocusNode;
  final bool checkRememberMe;
  final bool showPassword;
  final bool loggingIn;
  final VoidCallback onRememberMeToggle;
  final VoidCallback onShowPasswordToggle;
  final VoidCallback onFieldChanged;
  final VoidCallback onLoginPressed;
  final VoidCallback onIdSubmitted;
  final VoidCallback onPasswordSubmitted;

  const _StackedLayout({
    required this.idController,
    required this.passwordController,
    required this.idFocusNode,
    required this.passwordFocusNode,
    required this.checkRememberMe,
    required this.showPassword,
    required this.loggingIn,
    required this.onRememberMeToggle,
    required this.onShowPasswordToggle,
    required this.onFieldChanged,
    required this.onLoginPressed,
    required this.onIdSubmitted,
    required this.onPasswordSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 220,
          color: const Color(0xFF061525),
          child: Image.asset(
            'assets/images/3tier.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 36,
              ),
              child: _LoginFormContent(
                idController: idController,
                passwordController: passwordController,
                idFocusNode: idFocusNode,
                passwordFocusNode: passwordFocusNode,
                checkRememberMe: checkRememberMe,
                showPassword: showPassword,
                loggingIn: loggingIn,
                onRememberMeToggle: onRememberMeToggle,
                onShowPasswordToggle: onShowPasswordToggle,
                onFieldChanged: onFieldChanged,
                onLoginPressed: onLoginPressed,
                onIdSubmitted: onIdSubmitted,
                onPasswordSubmitted: onPasswordSubmitted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginFormContent extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController passwordController;
  final FocusNode idFocusNode;
  final FocusNode passwordFocusNode;
  final bool checkRememberMe;
  final bool showPassword;
  final bool loggingIn;
  final VoidCallback onRememberMeToggle;
  final VoidCallback onShowPasswordToggle;
  final VoidCallback onFieldChanged;
  final VoidCallback onLoginPressed;
  final VoidCallback onIdSubmitted;
  final VoidCallback onPasswordSubmitted;

  const _LoginFormContent({
    required this.idController,
    required this.passwordController,
    required this.idFocusNode,
    required this.passwordFocusNode,
    required this.checkRememberMe,
    required this.showPassword,
    required this.loggingIn,
    required this.onRememberMeToggle,
    required this.onShowPasswordToggle,
    required this.onFieldChanged,
    required this.onLoginPressed,
    required this.onIdSubmitted,
    required this.onPasswordSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n('로그인', 'Login'),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A1628),
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n('계정에 접속하려면 로그인하세요.', 'Sign in to access your account.'),
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF8A94A6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        _FieldLabel(text: l10n('아이디', 'ID')),
        const SizedBox(height: 8),
        _LoginTextField(
          controller: idController,
          focusNode: idFocusNode,
          hintText: l10n('아이디를 입력하세요.', 'Enter your ID.'),
          prefixIconData: CupertinoIcons.person,
          obscureText: false,
          onChanged: (_) => onFieldChanged(),
          onSubmitted: (_) => onIdSubmitted(),
        ),
        const SizedBox(height: 22),
        _FieldLabel(text: l10n('비밀번호', 'Password')),
        const SizedBox(height: 8),
        _LoginTextField(
          controller: passwordController,
          focusNode: passwordFocusNode,
          hintText: l10n('비밀번호를 입력하세요.', 'Enter your password.'),
          prefixIconData: CupertinoIcons.lock,
          obscureText: !showPassword,
          suffixIconData:
              showPassword ? Icons.visibility : Icons.visibility_off,
          onSuffixTapped: onShowPasswordToggle,
          onChanged: (_) => onFieldChanged(),
          onSubmitted: (_) => onPasswordSubmitted(),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onRememberMeToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              SvgPicture.asset(
                checkRememberMe
                    ? 'assets/images/icons_checkbox_checked.svg'
                    : 'assets/images/icons_checkbox_unchecked.svg',
                width: 15,
              ),
              const SizedBox(width: 9),
              Text(
                l10n('아이디 저장', 'Remember ID'),
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555C6E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlueFontColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              disabledBackgroundColor:
                  kBlueFontColor.withValues(alpha: 0.45),
            ),
            onPressed: loggingIn ? null : onLoginPressed,
            child: loggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n('로그인', 'Login'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              GestureDetector(
                onTap: () => Get.toNamed(LoginFindIdPage.routeName),
                child: Text(
                  l10n('아이디 찾기', 'Find ID'),
                  style: TextStyle(
                    fontSize: 12,
                    color: kBlueFontColor,
                  ),
                ),
              ),
              const Text(
                '·',
                style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(LoginFindPwPage.routeName),
                child: Text(
                  l10n('비밀번호 찾기', 'Find password'),
                  style: TextStyle(
                    fontSize: 12,
                    color: kBlueFontColor,
                  ),
                ),
              ),
              const Text(
                '·',
                style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(SignupRegisterPage.routeName),
                child: Text(
                  l10n('회원가입', 'Sign up'),
                  style: TextStyle(
                    fontSize: 12,
                    color: kBlueFontColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2D3748),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData prefixIconData;
  final bool obscureText;
  final IconData? suffixIconData;
  final VoidCallback? onSuffixTapped;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _LoginTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.prefixIconData,
    required this.obscureText,
    this.suffixIconData,
    this.onSuffixTapped,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A202C),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFBEC5CF),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          prefixIconData,
          size: 18,
          color: const Color(0xFF94A3B8),
        ),
        suffixIcon: suffixIconData != null
            ? GestureDetector(
                onTap: onSuffixTapped,
                child: Icon(
                  suffixIconData,
                  size: 18,
                  color: const Color(0xFFAAAAAA),
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBlueFontColor, width: 1.5),
        ),
      ),
    );
  }
}
