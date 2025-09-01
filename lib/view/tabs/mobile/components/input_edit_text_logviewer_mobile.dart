import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '/constants/constants.dart';

class InputEditTextLogViewer extends StatelessWidget {
  const InputEditTextLogViewer({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.validator,
    this.onSubmitted,
    this.maxLength,
    this.isReadOnly = false,
    this.mainColor = Colors.white,
    this.isObscureText = false,
    this.isBoldBorder = false,
    this.borderColor = const Color(0xFFD9D9D9),
    this.textAlign = TextAlign.left,
    this.isBoldText = false,
    this.errorText = "",
    this.hintTextColor = const Color(0xFF666565),
    this.showIcon = true,
    this.showHint = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final bool? isReadOnly;
  final Color? mainColor;
  final bool? isObscureText;
  final bool? isBoldBorder;
  final Color? borderColor;
  final TextAlign textAlign;
  final bool isBoldText;
  final String? errorText;
  final Color? hintTextColor;

  final bool showIcon;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: (isReadOnly ?? false) ? const Color(0xFFE2E2E2) : mainColor,
        border: Border.all(
          color: borderColor!,
          width: (isBoldBorder == true) ? 2.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(3.0),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          if (showIcon)
            GestureDetector(
              onTap: () => onSubmitted?.call(controller?.text ?? ''),
              child: const Icon(
                CupertinoIcons.search,
                size: 24,
                color: Color(0xFF666565),
              ),
            ),
          if (showIcon) const SizedBox(width: 4),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16),
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
                hintText: showHint ? hintText : null,
                hintStyle: TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 14,
                  color: hintTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              maxLength: maxLength,
              onChanged: onChanged,
              validator: validator,
              onFieldSubmitted: onSubmitted,
              readOnly: isReadOnly ?? false,
              obscureText: isObscureText ?? false,
              obscuringCharacter: '●',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 14,
                fontWeight: isBoldText ? FontWeight.w700 : FontWeight.w400,
                color: kBlackFontColor,
              ),
              textAlign: textAlign,
            ),
          ),
        ],
      ),
    );
  }
}
