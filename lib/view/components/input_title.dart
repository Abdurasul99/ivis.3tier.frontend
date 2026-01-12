import 'package:flutter/material.dart';
import 'package:ivis/view/components/text_title.dart';
import '../../constants/constants.dart';

class InputTitle extends StatelessWidget {
  const InputTitle({
    super.key,
    this.title = "",
    this.isRequired = false,
  });

  final String title;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        if (isRequired)
          const Text(
            "* ",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
        TextTitle(
          titleText: title,
          cellHeight: 20,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontColor: kBlackFontColor,
          padding: const EdgeInsets.all(0),
          fontFamily: 'medium',
        ),
      ],
    );
  }
}
