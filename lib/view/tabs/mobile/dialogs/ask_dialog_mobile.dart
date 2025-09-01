import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/constants/constants.dart';

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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dialogWidth = screenWidth < 600 ? screenWidth - 24 : 480;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.white,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message ?? "",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'pretendard',
                color: kBlackFontColor,
              ),
            ),
            if (addMessage != null && addMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                addMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'pretendard',
                  color: Color(0xFF666666),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: () => Get.back(result: "LEFT"),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFC42B1C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        leftText ?? '삭제',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'pretendard',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: "RIGHT"),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        rightText ?? '취소',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'pretendard',
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
