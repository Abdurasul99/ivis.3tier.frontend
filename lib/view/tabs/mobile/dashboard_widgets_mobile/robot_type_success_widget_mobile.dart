import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:fms/viewmodel/controller/dashboard_controller.dart';

class RobotTypeSuccessWidgetMobile extends StatelessWidget {
  const RobotTypeSuccessWidgetMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      init: DashboardController(),
      builder: (ctrl) {
        if (ctrl.robotSuccessData.isEmpty) {
          if (!ctrl.isLoading) {
            Future.microtask(() => ctrl.fetchRobotSuccess());
          }
          return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
        }
        List<Color> barColors = [
          const Color(0xFF005FB8),
          const Color(0xFF00B8F8),
          const Color(0xFF48C3F5),
          const Color(0xFF699EF1),
          const Color(0xFF8183E5),
          const Color(0xFF8C70DE),
          const Color(0xFFEC5AD5),
          const Color(0xFFFF66CC),
        ];
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '로봇 타입별 작업 성공률',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF666565),
                  fontWeight: FontWeight.w400,
                  fontFamily: 'pretendard',
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: List.generate(ctrl.robotSuccessData.length, (idx) {
                  var item = ctrl.robotSuccessData[idx];
                  String name = item.robotName ?? "Robot";
                  double rawRate = item.successRate ?? 0.0;
                  int intRate = rawRate.round().clamp(0, 100);
                  Color barColor = barColors[idx % barColors.length];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: Color(0xFF666565),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              double maxW = constraints.maxWidth;
                              double fillWidth = maxW * (intRate / 100.0);
                              return Stack(
                                children: [
                                  Container(
                                    width: maxW,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Container(
                                    width: fillWidth,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$intRate%',
                            style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: Color(0xFF666565),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
