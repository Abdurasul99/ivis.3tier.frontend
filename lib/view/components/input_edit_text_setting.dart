import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class InputEditTextSetting extends StatelessWidget {
  const InputEditTextSetting({
    super.key,
    this.controller,
    this.focusNode,
    this.title,
    this.hintText,
    this.onChanged,
    this.validator,
    this.onSubmitted,
    this.isRequired = false,
    this.maxLength,
    this.isReadOnly = false,
    this.mainColor = const Color(0xFF666565),
    this.isObscureText = false,
    this.isBoldBorder = false,
    this.borderColor = const Color(0xFFD9D9D9),
    this.textAlign = TextAlign.left,
    this.isBoldText = false,
    this.errorText = "",
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? title;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final bool? isRequired;
  final int? maxLength;
  final bool? isReadOnly;
  final Color? mainColor;
  final bool? isObscureText;
  final bool? isBoldBorder;
  final Color? borderColor;
  final TextAlign textAlign;
  final bool isBoldText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (title != null && title!.isNotEmpty)
          Container(
            height: 20,
            alignment: Alignment.centerLeft,
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                if (isRequired ?? false)
                  const Text(
                    "* ",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFF0000),
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                Text(
                  title ?? "",
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 13,
                    color: mainColor,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        Container(
          height: 40,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: (isReadOnly ?? false)
                ? const Color(0xFFE2E2E2)
                : Colors.transparent,
            border: Border.all(
              color: borderColor!,
              width: (isBoldBorder == true) ? 2.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(3.0),
          ),
          alignment: Alignment.centerLeft,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0.0, horizontal: 14),
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
              fontSize: 15,
              fontWeight: isBoldText ? FontWeight.w700 : FontWeight.w400,
              color: Colors.black,
            ),
            textAlign: textAlign,
          ),
        ),
      ],
    );
  }
}
