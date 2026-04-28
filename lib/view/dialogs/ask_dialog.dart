// lib/view/dialogs/ask_dialog.dart
//
// A yes/no dialog from GitHub code.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../i18n/app_locale.dart';
import '../components/gradient_button.dart';

class AskDialog extends StatelessWidget {
  const AskDialog({
    super.key,
    this.message,
    this.addMessage,
    this.leftText,
    this.rightText,
  });

  final String? message;
  final String? addMessage;
  final String? leftText;
  final String? rightText;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = 600;

    if (screenWidth < 600) {
      dialogWidth = screenWidth - 12;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Text(
                message ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 18,
                  color: kBlackFontColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (addMessage != null && addMessage!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 26),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Text(
                  addMessage ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 15,
                    color: kBlackFontColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            const SizedBox(height: 26),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 157,
                  child: GradientButton(
                    buttonText: leftText ?? l10n('예', 'Yes'),
                    buttonColor: const Color(0xFF005FB8),
                    onTap: () {
                      Get.back(result: "LEFT");
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 157,
                  child: GradientButton(
                    buttonText: rightText ?? l10n('아니오', 'No'),
                    onTap: () {
                      Get.back(result: "RIGHT");
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 38),
          ],
        ),
      ),
    );
  }
}
