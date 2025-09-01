import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/graph_controller.dart';
import '../../viewmodel/controller/robot_controller.dart';

class UsedBatteryByDayWidget extends StatefulWidget {
  const UsedBatteryByDayWidget({super.key});

  @override
  State<UsedBatteryByDayWidget> createState() => _UsedBatteryByDayWidgetState();
}

class _UsedBatteryByDayWidgetState extends State<UsedBatteryByDayWidget> {
  int touchedIndex = -1;
  @override
  void initState() {
    super.initState();

    Get.find<GraphController>().makeTotalValues();
  }

  Future<void> refresh() async {
    await Get.find<GraphController>().makeTotalValues();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '일평균 사용베터리',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF666565),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GetBuilder<GraphController>(
              init: GraphController(),
              builder: (controller) {
                List<Robot> robots = Get.find<RobotController>().unDeletedRobots;
                if (controller.totalDistance.isEmpty) {
                  refresh();
                }

                if (controller.isLoadingTotal) {
                  return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
                }

                Map<int, double> batteryByDay = controller.batteryByDay;

                if (robots.isEmpty || batteryByDay.isEmpty) {
                  return const Center(
                    child: Text(
                      '배터리 정보가 없습니다 😑',
                      style: TextStyle(
                        fontSize: 18,
                        color: kHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }

                List<BarChartGroupData> robotBarGroups = [];
                Map<int, String> robotNames = {};
                double maxBattery = 0;

                int robotIndex = 0;
                for (Robot robot in robots) {
                  int robotId = robot.id!;

                  double battery = 0.0;
                  if (batteryByDay.containsKey(robotId)) {
                    var rawValue = batteryByDay[robotId];
                    if (rawValue != null && !rawValue.isNaN) {
                      battery = double.tryParse(rawValue.toString()) ?? 0.0;
                    }
                  }

                  if (battery > maxBattery) {
                    maxBattery = battery;
                  }

                  robotNames[robotIndex] = "${robot.name}";

                  robotBarGroups.add(
                    BarChartGroupData(
                      x: robotIndex,
                      barRods: [
                        BarChartRodData(
                          toY: battery,
                          color: const Color(0xFFFDAE00),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: touchedIndex == robotIndex ? [0] : [],
                    ),
                  );

                  robotIndex++;
                }

                double robotYMax = maxBattery > 0 ? (((maxBattery / 4).ceil()) * 4).toDouble() : 8.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Expanded(
                      child: robots.isEmpty
                          ? const Text(
                              '데이터가 없습니다 😑',
                              style: TextStyle(
                                fontSize: 12,
                                color: kHintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : BarChart(
                              BarChartData(
                                maxY: robotYMax,
                                alignment: BarChartAlignment.spaceAround,
                                groupsSpace: 0,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    getTooltipColor: (BarChartGroupData group) {
                                      return const Color(0xFFF8F8FB);
                                    },
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      String robotName = robotNames[group.x.toInt()] ?? "";
                                      String value = "";

                                      double doubleValue = rod.toY;
                                      doubleValue = ((doubleValue * 10).round()) / 10;
                                      value = "${Utils.doubleWithComma(doubleValue)}%";

                                      return BarTooltipItem(
                                        "$robotName\n",
                                        const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF333333),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        children: <TextSpan>[
                                          TextSpan(
                                            text: value,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF407BFF),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                                    setState(() {
                                      if (barTouchResponse != null &&
                                          event is! FlTapUpEvent &&
                                          event is! FlPanEndEvent &&
                                          barTouchResponse.spot != null) {
                                        touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex + 100;
                                      } else {
                                        touchedIndex = -1;
                                      }
                                    });
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        final index = value.toInt();
                                        final robotName = robotNames[index] ?? "";

                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            robotName,
                                            style: const TextStyle(
                                              fontFamily: 'light',
                                              fontSize: 9,
                                              color: Color(0xFF666565),
                                              fontWeight: FontWeight.w400,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: robotYMax / 4,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        int intValue = value.round();
                                        String text = "$intValue%";

                                        return Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  text,
                                                  textAlign: TextAlign.right,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.fade,
                                                  style: const TextStyle(
                                                    fontFamily: 'light',
                                                    fontSize: 9,
                                                    color: Color(0xFF666565),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: const Border(
                                    bottom: BorderSide(color: Color(0xFFDDDDDD)),
                                    left: BorderSide(color: Color(0xFFDDDDDD)),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: false,
                                  horizontalInterval: 4,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: kHintColor,
                                      strokeWidth: 1,
                                    );
                                  },
                                  drawVerticalLine: false,
                                ),
                                barGroups: robotBarGroups,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
