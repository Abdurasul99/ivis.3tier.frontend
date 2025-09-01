import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/constants.dart';

class InputEditTextUnderline extends StatelessWidget {
  const InputEditTextUnderline({
    super.key,
    required this.textController,
    required this.focusNode,
    this.showTextCounter = false,
    this.hintText = "",
    this.onChanged,
    this.onSubmit,
    this.enableLength = 100,
    this.maxLength = 1000,
    this.showHelperIcon = false,
    this.onTapGuide,
    this.textInputFormatter,
    this.borderColor = kGrayColor,
    this.backgroundColor = Colors.white,
    this.icon,
    this.obscureText = false,
    this.iconOnRight,
    this.onTapRightIcon,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final bool showTextCounter;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;
  final int enableLength;
  final int maxLength;
  final bool showHelperIcon;
  final GestureTapCallback? onTapGuide;
  final List<TextInputFormatter>? textInputFormatter;
  final Color borderColor;
  final Color backgroundColor;
  final Widget? icon;
  final bool obscureText;
  final Widget? iconOnRight;
  final GestureTapCallback? onTapRightIcon;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) {
      screenWidth = 800;
    }

    return Container(
      width: screenWidth,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: kDarkGrayColor, width: 1.0),
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (icon != null) icon!,
          if (icon != null) const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              onChanged: onChanged,
              controller: textController,
              inputFormatters: textInputFormatter,
              decoration: InputDecoration(
                counterText: "",
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(width: 0, color: Colors.transparent),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(width: 0, color: Colors.transparent),
                ),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(width: 0, color: Colors.transparent),
                ),
                errorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(width: 0, color: Colors.transparent),
                ),
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: kDarkGrayColor,
                  fontWeight: FontWeight.w300,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kBlackFontColor,
              ),
              focusNode: focusNode,
              onFieldSubmitted: onSubmit,
              keyboardType: keyboardType,
              maxLength: maxLength,
              obscureText: obscureText,
            ),
          ),
          if (iconOnRight != null)
            GestureDetector(
              onTap: onTapRightIcon,
              child: iconOnRight!,
            ),
        ],
      ),
    );
  }
}
