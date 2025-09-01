import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    this.buttonText = "",
    this.onTap,
    this.buttonColor = Colors.white,
    this.icon,
    this.fontSize = 15,
  });

  final String buttonText;
  final GestureTapCallback? onTap;
  final Color buttonColor;
  final Widget? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF1F1F1),
                Color(0xFFD6D6D6),
              ],
            ),
            borderRadius: BorderRadius.all(Radius.circular(3.0)),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              const SizedBox(width: 1),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    border: Border.all(color: Colors.transparent, width: 1.0),
                    borderRadius: const BorderRadius.all(Radius.circular(3.0)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (icon != null) icon!,
                      if (icon != null) const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: fontSize,
                          color: (buttonColor == Colors.white)
                              ? const Color(0xFF1B1B1B)
                              : (buttonColor == const Color(0xFFE8E8E8))
                                  ? const Color(0xFF666565)
                                  : Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 1),
            ],
          ),
        ),
      ),
    );
  }
}
