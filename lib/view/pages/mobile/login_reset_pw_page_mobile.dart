import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/utils/utils.dart';
import '/viewmodel/controller/password_controller.dart';

class LoginResetPwPageMobile extends StatefulWidget {
  static const String routeName = '/reset-pw';

  const LoginResetPwPageMobile({super.key});

  @override
  State<LoginResetPwPageMobile> createState() => _LoginResetPwPageState();
}

class _LoginResetPwPageState extends State<LoginResetPwPageMobile> {
  static const double _mobileBreakpointWidth = 550.0;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  final RegExp _passwordValidationRegex = RegExp(
    r'^(?=.*[0-9])(?=.*[a-zA-Z])(?=.*[^a-zA-Z0-9]).{8,16}$',
  );

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= _mobileBreakpointWidth;

    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: isMobile ? _buildMobileForm() : Center(child: _buildDesktopForm()),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00000D).withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 3.0,
          ),
        ],
      ),
      child: Row(
        children: [
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

  Widget _buildDesktopForm() {
    return Container(
      width: 454,
      height: 430,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildFormContent(),
    );
  }

  Widget _buildMobileForm() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40, 
                vertical: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 358),
                  child: _buildMobileFormContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '비밀번호 재설정',
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: Color(0xFF005FB7),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '영문, 숫자, 특수문자 등 (8자 이상 16자 이하)을 함께 사용하면  보다 안전합니다..',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 84),
        _buildPasswordField(
          labelText: '새 비밀번호',
          hintText: '비밀번호를 입력하세요.',
          controller: _newPasswordController,
        ),
        const SizedBox(height: 45),
        _buildPasswordField(
          labelText: '비밀번호 확인',
          hintText: '비밀번호를 한 번 더 입력하세요.',
          controller: _confirmNewPasswordController,
        ),
        const SizedBox(height: 200),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: _onTapConfirmPasswordReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlueFontColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
            ),
            child: const Text(
              '확인',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '비밀번호 재설정',
          style: TextStyle(
            fontFamily: 'gm-medium',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: Color(0xFF005FB7),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '영문, 숫자, 특수문자 등을 함께 사용하면\n(8자 이상 16자 이하) 보다 안전합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 24),
        _buildPasswordField(
          labelText: '새 비밀번호',
          hintText: '비밀번호를 입력하세요.',
          controller: _newPasswordController,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          labelText: '비밀번호 확인',
          hintText: '비밀번호를 한 번 더 입력하세요.',
          controller: _confirmNewPasswordController,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: _onTapConfirmPasswordReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlueFontColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
            ),
            child: const Text(
              '확인',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String labelText,
    required String hintText,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              color: Color(0xFF666565),
            ),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB3B3B3)),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB3B3B3)),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB3B3B3)),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Future<void> _onTapConfirmPasswordReset() async {
    final String newPassword = _newPasswordController.text.trim();
    final String confirmPassword = _confirmNewPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      Utils.showSnackBar('비밀번호를 입력하세요.', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      Utils.showSnackBar('비밀번호가 서로 일치하지 않습니다.', isError: true);
      return;
    }
    if (!_passwordValidationRegex.hasMatch(newPassword)) {
      Utils.showSnackBar(
        '비밀번호는 영문, 숫자, 특수문자를 포함해 8~16자로 입력해주세요.',
        isError: true,
      );
      return;
    }

    final PasswordController passwordController = Get.find<PasswordController>();
    final response = await passwordController.reqPasswordComplete(newPassword);
    if (response == null) {
      Utils.showSnackBar('서버 요청 오류 (reqPasswordComplete null).', isError: true);
      return;
    }
    if (response.code == '0000') {
      Utils.showSnackBar('비밀번호가 변경되었습니다!');
      Get.offAllNamed('/reset-final');
    } else {
      Utils.showSnackBar('비밀번호 변경 실패: ${response.message}', isError: true);
    }
  }
}
