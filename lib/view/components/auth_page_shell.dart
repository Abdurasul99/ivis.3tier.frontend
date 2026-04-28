import 'package:flutter/material.dart';

import '../../constants/constants.dart';

/// 로그인·인증 계열 페이지 공통 split-card 레이아웃
/// Wide (>=720px): 왼쪽 3tier.png / 오른쪽 폼
/// Narrow (<720px): 이미지 상단 + 폼 하단 스크롤
class AuthPageShell extends StatelessWidget {
  final Widget formChild;

  const AuthPageShell({super.key, required this.formChild});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth >= 720) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
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
                                      horizontal: 48,
                                      vertical: 52,
                                    ),
                                    child: formChild,
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                        child: formChild,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

        ],
      ),
    );
  }
}

/// 공통 필드 라벨
class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel({super.key, required this.text});

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

/// 공통 텍스트 필드
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final IconData prefixIconData;
  final bool obscureText;
  final IconData? suffixIconData;
  final VoidCallback? onSuffixTapped;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final String? errorText;

  const AuthTextField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.prefixIconData,
    this.obscureText = false,
    this.suffixIconData,
    this.onSuffixTapped,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          readOnly: readOnly,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 14,
            color: readOnly
                ? const Color(0xFF6B7280)
                : const Color(0xFF1A202C),
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
            fillColor: readOnly
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFE53E3E)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFE53E3E)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFE53E3E)
                    : kBlueFontColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFE53E3E),
            ),
          ),
        ],
      ],
    );
  }
}

/// 아웃라인 보조 버튼 (인증메일 보내기 등)
class AuthOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const AuthOutlineButton({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kBlueFontColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          foregroundColor: kBlueFontColor,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// 기본 주 버튼
class AuthPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlueFontColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: kBlueFontColor.withValues(alpha: 0.45),
        ),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// 하단 텍스트 링크 행 (← 로그인으로 돌아가기 등)
class AuthBackLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const AuthBackLink({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: kBlueFontColor,
            decoration: TextDecoration.underline,
            decorationColor: kBlueFontColor,
          ),
        ),
      ),
    );
  }
}
