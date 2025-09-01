import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';

class MovingDistanceByDayWidgetMobile extends StatefulWidget {
  const MovingDistanceByDayWidgetMobile({super.key});

  @override
  State<MovingDistanceByDayWidgetMobile> createState() => _MovingDistanceByDayWidgetMobileState();
}

class _MovingDistanceByDayWidgetMobileState extends State<MovingDistanceByDayWidgetMobile> {
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    // Pre-load data
    Get.find<GraphController>().makeTotalValues();
  }

  Future<void> refresh() async {
    await Get.find<GraphController>().makeTotalValues();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced padding → widget looks more compact on screen
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
              fontSize: 16, // was 18
              color: Color(0xFF666565),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6), // was 8
          Expanded(
            child: GetBuilder<GraphController>(
              init: GraphController(),
              builder: (controller) {
                List<Robot> robots = Get.find<RobotController>().unDeletedRobots;
                if (controller.distanceByDay.isEmpty) {
                  // Lazy refresh
                  refresh();
                }

                if (controller.isLoadingTotal) {
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 16, color: Colors.grey), // radius smaller
                  );
                }

                Map<int, double> distanceByDay = controller.distanceByDay;

                if (robots.isEmpty || distanceByDay.isEmpty) {
                  return const Center(
                    child: Text(
                      '주행 정보가 없습니다 😑',
                      style: TextStyle(
                        fontSize: 16, // was 18
                        color: kHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }

                // Split robots into Untact / Taro groups
                List<Robot> taroRobots = [];
                List<Robot> untactRobots = [];

                for (Robot robot in robots) {
                  if (robot.typeDescription!.toLowerCase() == "untact") {
                    untactRobots.add(robot);
                  } else {
                    taroRobots.add(robot);
                  }
                }

                // Build bar groups — slightly thinner (width 12 was 16)
                List<BarChartGroupData> taroBarGroups = [];
                Map<int, String> taroRobotNames = {};
                double maxTaroDistance = 0;

                List<BarChartGroupData> untactBarGroups = [];
                Map<int, String> untactRobotNames = {};
                double maxUntactDistance = 0;

                int taroIndex = 0;
                for (Robot robot in taroRobots) {
                  int robotId = robot.id!;
                  double distance = distanceByDay[robotId] ?? 0.0;
                  distance = (distance * 100).round() / 100;

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
                          color: Colors.green.shade400,
                          width: 12, // thinner
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
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
                  int robotId = robot.id!;
                  double distance = distanceByDay[robotId] ?? 0.0;
                  distance = ((distance / 10000) * 100).round() / 100;

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
                          color: Colors.blue.shade400,
                          width: 12, // thinner
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: touchedIndex == (untactIndex + 100) ? [0] : [],
                    ),
                  );

                  untactIndex++;
                }

                double taroYMax = maxTaroDistance > 0 ? maxTaroDistance * 1.2 : 10;
                double untactYMax = maxUntactDistance > 0 ? maxUntactDistance * 1.2 : 10;

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
                                width: 16, // was 20
                                height: 16,
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
                              const SizedBox(width: 4), // was 6
                              const Text(
                                'Untact(km)',
                                style: TextStyle(
                                  fontSize: 11, // was 12
                                  color: kBlackFontColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12), // was 16
                          Expanded(
                            child: untactRobots.isEmpty
                                ? const Text(
                                    '데이터가 없습니다 😑',
                                    style: TextStyle(
                                      fontSize: 11, // was 12
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
                                          tooltipPadding:
                                              const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // smaller
                                          getTooltipColor: (BarChartGroupData group) {
                                            return const Color(0xFFF8F8FB);
                                          },
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            String robotName = untactRobotNames[group.x.toInt()] ?? "";
                                            return BarTooltipItem(
                                              "$robotName\n",
                                              const TextStyle(
                                                fontSize: 9, // was 10
                                                color: Color(0xFF333333),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              children: <TextSpan>[
                                                TextSpan(
                                                  text: "${rod.toY}km",
                                                  style: const TextStyle(
                                                    fontSize: 9,
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
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Text(
                                                  robotName,
                                                  style: const TextStyle(
                                                    fontFamily: 'light',
                                                    fontSize: 8, // was 9
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
                                            reservedSize: 24, // was 30
                                            interval: untactYMax / 4,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              String text = value.toStringAsFixed(1);
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
                                                          fontSize: 8, // was 9
                                                          color: Color(0xFF666565),
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
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
                                        border: Border.all(color: const Color(0xFFDDDDDD)),
                                      ),
                                      gridData: FlGridData(
                                        show: true,
                                        horizontalInterval: untactYMax / 4,
                                        getDrawingHorizontalLine: (value) => FlLine(
                                          color: kHintColor,
                                          strokeWidth: 1,
                                        ),
                                        drawVerticalLine: false,
                                      ),
                                      barGroups: untactBarGroups,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12), // was 16
                    Flexible(
                      flex: taroRobots.length,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16, // was 20
                                height: 16,
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
                              const SizedBox(width: 4),
                              const Text(
                                'Taro(m)',
                                style: TextStyle(
                                  fontSize: 11, // was 12
                                  color: kBlackFontColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: taroRobots.isEmpty
                                ? const Text(
                                    '데이터가 없습니다 😑',
                                    style: TextStyle(
                                      fontSize: 11, // was 12
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
                                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          getTooltipColor: (BarChartGroupData group) {
                                            return const Color(0xFFF8F8FB);
                                          },
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            String robotName = taroRobotNames[group.x.toInt()] ?? "";
                                            return BarTooltipItem(
                                              "$robotName\n",
                                              const TextStyle(
                                                fontSize: 9,
                                                color: Color(0xFF333333),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              children: <TextSpan>[
                                                TextSpan(
                                                  text: "${rod.toY}m",
                                                  style: const TextStyle(
                                                    fontSize: 9,
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
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Text(
                                                  robotName,
                                                  style: const TextStyle(
                                                    fontFamily: 'light',
                                                    fontSize: 8,
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
                                            reservedSize: 30, // was 40
                                            interval: taroYMax / 4,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              String text = value.toStringAsFixed(1);
                                              return Row(
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
                                                        fontSize: 8,
                                                        color: Color(0xFF666565),
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
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
                                        border: Border.all(color: const Color(0xFFDDDDDD)),
                                      ),
                                      gridData: FlGridData(
                                        show: true,
                                        horizontalInterval: taroYMax / 4,
                                        getDrawingHorizontalLine: (value) => FlLine(
                                          color: const Color(0xFFDDDDDD),
                                          strokeWidth: 1,
                                        ),
                                        drawVerticalLine: false,
                                      ),
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
