import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../viewmodel/controller/graph_controller.dart';
import '../../viewmodel/controller/robot_controller.dart';

class MovingDistanceByDayWidget extends StatefulWidget {
  const MovingDistanceByDayWidget({super.key});

  @override
  State<MovingDistanceByDayWidget> createState() => _MovingDistanceByDayWidgetState();
}

class _MovingDistanceByDayWidgetState extends State<MovingDistanceByDayWidget> {
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
            '일평균 주행거리',
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
                if (controller.distanceByDay.isEmpty) {
                  refresh();
                }

                if (controller.isLoadingTotal) {
                  return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
                }

                Map<int, double> distanceByDay = controller.distanceByDay;

                if (robots.isEmpty || distanceByDay.isEmpty) {
                  return const Center(
                    child: Text(
                      '주행 정보가 없습니다 😑',
                      style: TextStyle(
                        fontSize: 18,
                        color: kHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }

                List<Robot> taroRobots = [];
                List<Robot> untactRobots = [];

                for (Robot robot in robots) {
                  if (robot.isDeleted == true) {
                    continue;
                  }

                  if (robot.typeDescription!.toLowerCase() == "untact") {
                    untactRobots.add(robot);
                  } else {
                    taroRobots.add(robot);
                  }
                }

                List<BarChartGroupData> taroBarGroups = [];
                Map<int, String> taroRobotNames = {};
                double maxTaroDistance = 0;

                List<BarChartGroupData> untactBarGroups = [];
                Map<int, String> untactRobotNames = {};
                double maxUntactDistance = 0;

                int taroIndex = 0;
                for (Robot robot in taroRobots) {
                  if (robot.isDeleted == true) {
                    continue;
                  }

                  int robotId = robot.id!;
                  double distance = 0.0;

                  if (distanceByDay.containsKey(robotId)) {
                    var rawValue = distanceByDay[robotId];
                    if (rawValue != null && !rawValue.isNaN) {
                      distance = double.tryParse(rawValue.toString()) ?? 0.0;
                    }
                  }

                  if (distance > maxTaroDistance) {
                    maxTaroDistance = distance;
                  }

                  taroRobotNames[taroIndex] = "${robot.name}";

                  taroBarGroups.add(
                    BarChartGroupData(
                      x: taroIndex,
                      barRods: [
                        BarChartRodData(
                          toY: distance,
                          color: const Color(0xFF0060B9),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: touchedIndex == taroIndex ? [0] : [],
                    ),
                  );

                  taroIndex++;
                }

                int untactIndex = 0;
                for (Robot robot in untactRobots) {
                  if (robot.isDeleted == true) {
                    continue;
                  }

                  int robotId = robot.id!;

                  double distance = 0.0;
                  if (distanceByDay.containsKey(robotId)) {
                    var rawValue = distanceByDay[robotId];
                    if (rawValue != null && !rawValue.isNaN) {
                      distance = ((rawValue / 10000) * 100).round() / 100;
                    }
                  }

                  if (distance > maxUntactDistance) {
                    maxUntactDistance = distance;
                  }

                  untactRobotNames[untactIndex] = "${robot.name}";

                  untactBarGroups.add(
                    BarChartGroupData(
                      x: untactIndex,
                      barRods: [
                        BarChartRodData(
                          toY: distance,
                          color: const Color(0xFF0FBDFC),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: touchedIndex == (untactIndex + 100) ? [0] : [],
                    ),
                  );

                  untactIndex++;
                }

                double taroYMax = maxTaroDistance > 0 ? (((maxTaroDistance / 4).ceil()) * 4).toDouble() : 8.0;
                double untactYMax = maxUntactDistance > 0 ? (((maxUntactDistance / 4).ceil()) * 4).toDouble() : 8.0;

                return Row(
                  children: [
                    Flexible(
                      flex: untactRobots.length,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFDBDBDB), width: 1.0),
                                  image: DecorationImage(
                                    image: ExtendedNetworkImageProvider(
                                      untactRobots[0].imageUrl ?? untactRobots[0].typeImageUrl ?? "",
                                      cache: true,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Untact(km)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kBlackFontColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: untactRobots.isEmpty
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
                                      maxY: untactYMax,
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
                                            String robotName = untactRobotNames[group.x.toInt()] ?? "";
                                            return BarTooltipItem(
                                              "$robotName\n",
                                              const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF333333),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              children: <TextSpan>[
                                                TextSpan(
                                                  text: "${rod.toY}km",
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
                                              final robotName = untactRobotNames[index] ?? "";

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
                                            // reservedSize: 42,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 42,
                                            interval: untactYMax / 4,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              String text = value.round().toString();
                                              return Expanded(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        "${text}km",
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
                                      gridData: FlGridData(show: false),
                                      barGroups: untactBarGroups,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: taroRobots.length,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFDBDBDB), width: 1.0),
                                  image: DecorationImage(
                                    image: ExtendedNetworkImageProvider(
                                      taroRobots[0].imageUrl ?? taroRobots[0].typeImageUrl ?? "",
                                      cache: true,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Taro(m)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kBlackFontColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: taroRobots.isEmpty
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
                                      maxY: taroYMax,
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
                                            String robotName = taroRobotNames[group.x.toInt()] ?? "";
                                            return BarTooltipItem(
                                              "$robotName\n",
                                              const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF333333),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              children: <TextSpan>[
                                                TextSpan(
                                                  text: "${rod.toY}m",
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
                                              touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
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
                                              final robotName = taroRobotNames[index] ?? "";

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
                                            // reservedSize: 42,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            interval: taroYMax / 4,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              String text = value.round().toString();
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      "${text}m",
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
                                      gridData: FlGridData(show: false),
                                      barGroups: taroBarGroups,
                                    ),
                                  ),
                          ),
                        ],
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
