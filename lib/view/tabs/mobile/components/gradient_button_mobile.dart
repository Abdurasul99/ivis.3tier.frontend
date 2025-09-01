import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.buttonText,
    this.onTap,
    this.buttonColor = Colors.white,
    this.borderColor,
    this.textColor,
    this.icon,
  });

  final String buttonText;
  final GestureTapCallback? onTap;
  final Color buttonColor;
  final Color? borderColor;
  final Color? textColor;
  final Widget? icon;

  bool get _useGradient => buttonColor != Colors.white;

  @override
  Widget build(BuildContext context) {
    final Color effectiveBorder =
        borderColor ?? (buttonColor == Colors.white ? const Color(0xFFD9D9D9) : Colors.transparent);

    final Color effectiveText = textColor ?? (buttonColor == Colors.white ? const Color(0xFF1B1B1B) : Colors.white);

    final inner = Container(
      height: 40,
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: effectiveBorder, width: 1),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(
            buttonText,
            style: TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: effectiveText,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: _useGradient
            ? Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF1F1F1), Color(0xFFD6D6D6)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
                child: inner,
              )
            : inner,
      ),
    );
  }
}
