import 'package:flutter/material.dart';

import 'input_edit_text.dart';

class InputEditTextHorizontal extends StatelessWidget {
  const InputEditTextHorizontal({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label ?? "",
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 286,
            child: InputEditText(
              controller: controller,
              focusNode: focusNode,
              hintText: hint,
              borderColor: const Color(0xFFB3B3B3),
              errorText: errorText,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
