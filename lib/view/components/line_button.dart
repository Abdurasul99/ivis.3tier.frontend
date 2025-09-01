import 'package:flutter/material.dart';

class LineButton extends StatelessWidget {
  const LineButton({
    super.key,
    required this.buttonText,
    this.onTap,
    this.buttonColor = Colors.white,
    this.lineColor = const Color(0xFF005FB8),
    this.icon,
  });

  final String buttonText;
  final GestureTapCallback? onTap;
  final Color buttonColor;
  final Color lineColor;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: lineColor, width: 1.0),
            borderRadius: BorderRadius.all(Radius.circular(3.0)),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              const SizedBox(width: 1),
              Expanded(
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
                        fontSize: 15,
                        color: (buttonColor == Colors.white) ? const Color(0xFF1B1B1B) : Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
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
