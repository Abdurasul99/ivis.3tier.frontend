import 'package:flutter/material.dart';

class InputEditTextReadOnly extends StatelessWidget {
  const InputEditTextReadOnly({
    super.key,
    this.title,
    this.value,
  });

  final String? title;
  final String? value;

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
                Text(
                  title ?? "",
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 13,
                    color: Color(0xFF666565),
                    fontWeight: FontWeight.w400,
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
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(3.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Text(
            value ?? "",
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
