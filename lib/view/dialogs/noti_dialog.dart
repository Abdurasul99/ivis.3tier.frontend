// lib/view/dialogs/noti_dialog.dart
//
// A simple "OK" notification dialog with GradientButton.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../components/gradient_button.dart';

class NotiDialog extends StatelessWidget {
  const NotiDialog({
    super.key,
    this.message,
    this.addMessage,
  });

  final String? message;
  final String? addMessage;

  @override
  Widget build(BuildContext context) {
    double dialogWidth = 456;

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
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 0),
              blurRadius: 5,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 35),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 13),
              child: Text(
                message ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (addMessage != null && addMessage!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 26),
                alignment: Alignment.center,
                child: Text(
                  addMessage ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            const SizedBox(height: 26),
            SizedBox(
              width: 157,
              child: GradientButton(
                buttonText: "확인",
                buttonColor: const Color(0xFF005FB8),
                onTap: () {
                  Get.back();
                },
              ),
            ),
            const SizedBox(height: 38),
          ],
        ),
      ),
    );
  }
}
