import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:get/get.dart';

import '../../model/dashboard_model.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_dropdown_dashboard.dart';
import '../components/input_edit_text_dashboard.dart';

class DashboardWidgetDialog extends StatefulWidget {
  const DashboardWidgetDialog({
    super.key,
    required this.row,
    required this.column,
    this.layoutSet,
  });

  final int row;
  final int column;
  final LayoutSet? layoutSet;

  @override
  State<DashboardWidgetDialog> createState() => _DashboardWidgetDialogState();
}

class _DashboardWidgetDialogState extends State<DashboardWidgetDialog> {
  final TextEditingController _methodController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  final List<String> _infoOptions = [
    "기기 운행 현황",
    "주요 알림",
    "전체 로봇의 누적 주행거리",
    "전체 로봇의 누적 운영시간",
    "전체 로봇의 누적 사용배터리",
    "로봇별 일평균 주행거리",
    "로봇별 일평균 운영시간",
    "로봇별 일평균 사용배터리",
  ];

  String _layoutType = "";

  @override
  void initState() {
    super.initState();

    if (widget.layoutSet != null) {
      _methodController.text = widget.layoutSet!.displayMethod ?? "";
      _periodController.text = widget.layoutSet!.period ?? "";
      _layoutType = widget.layoutSet!.title ?? "";
    }
  }

  @override
  void dispose() {
    super.dispose();

    _methodController.dispose();
    _periodController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double dialogWidth = 500;

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
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '위젯 생성',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '표시 정보',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 13,
                color: Color(0xFF666565),
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            InputEditDropDownDashboard(
              hintText: '표시 정보를 선택하세요.',
              items: _infoOptions,
              selectedText: _layoutType,
              onChanged: (value) {
                if (value == null || value.isEmpty) {
                  return;
                }

                _layoutType = value;
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),
            InputEditTextDashboard(
              title: "표시 방법",
              hintText: '표시 방법을 입력하세요.',
              controller: _methodController,
            ),
            const SizedBox(height: 16),
            InputEditTextDashboard(
              title: "기간",
              hintText: '표시할 기간을 입력하세요.',
              controller: _periodController,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    buttonText: "확 인",
                    buttonColor: const Color(0xFF005FB8),
                    onTap: () {
                      LayoutSet layoutSet = LayoutSet(
                        title: _layoutType,
                        rowIndex: widget.row,
                        columnIndex: widget.column,
                        displayMethod: _methodController.text,
                        period: _periodController.text.trim(),
                      );

                      Get.find<DashboardController>().addLayout(layoutSet);
                      Get.back();
                    },
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: GradientButton(
                    buttonText: "취 소",
                    onTap: () {
                      Get.back();
                    },
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
