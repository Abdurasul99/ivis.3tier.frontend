import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../model/graph_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/graph_controller.dart';

class ChartView extends StatefulWidget {
  const ChartView({
    super.key,
    required this.type,
  });

  final String type;

  @override
  State<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends State<ChartView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double viewerWidth = constraints.maxWidth;
        double viewHeight = constraints.maxHeight;

        return GetBuilder<GraphController>(
          init: GraphController(),
          builder: (controller) {
            BarChartBase? barChartBase = controller.getBarChartGroupData(widget.type);

            String period = controller.getCurrentPeriod(widget.type);
            double chartWidth = (barChartBase == null)
                ? 0
                : (barChartBase.barChartItems!.length * 16) + (barChartBase.barChartItems!.length * 24) + 24;

            double groupsSpace = 24;

            bool showArrow = true;

            if (chartWidth != 0 && chartWidth < viewerWidth) {
              chartWidth = viewerWidth - 64 - 48;

              groupsSpace =
                  (viewerWidth - (barChartBase!.barChartItems!.length * 16)) / (barChartBase.barChartItems!.length + 2);
              showArrow = false;
            }

            String totalValue = "-";

            if (barChartBase != null) {
              if (widget.type == 'distance') {
                int divValue = 1000;
                if (controller.selectedRobotType.toLowerCase() == 'untact') {
                  divValue = 10000;
                }

                int km = (barChartBase.sumOfValue ?? 0).round() ~/ divValue;
                int meter = (barChartBase.sumOfValue ?? 0).round() % divValue;

                if (km > 0) {
                  double doubleValue = ((barChartBase.sumOfValue ?? 0) / divValue);
                  doubleValue = ((doubleValue * 100).round()) / 100;
                  totalValue = "${Utils.doubleWithComma(doubleValue)}Km";
                } else {
                  totalValue = "${Utils.numberWithComma(meter)}m";
                }
              } else if (widget.type == 'time') {
                int intValue = (barChartBase.sumOfValue ?? 0).round();
                int hour = intValue ~/ 3600;
                int min = (intValue % 3600) ~/ 60;
                int sec = intValue % 60;

                totalValue = "";

                if (hour > 0) {
                  totalValue = "${hour.toString().padLeft(2, '0')}시간 ";
                }

                if (min > 0) {
                  totalValue += "${min.toString().padLeft(2, '0')}분 ";
                }

                totalValue += "${sec.toString().padLeft(2, '0')}초";
              } else if (widget.type == 'battery') {
                double doubleValue = (barChartBase.sumOfValue ?? 0);
                doubleValue = ((doubleValue * 100).round()) / 100;
                totalValue = "${Utils.doubleWithComma(doubleValue)}%";
              }
            }

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDBDBDB), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.25),
                        offset: Offset(2, 0),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (widget.type == "distance")
                                      ? "누적 주행 거리"
                                      : (widget.type == "time")
                                          ? "운영 시간"
                                          : "사용 배터리",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 12,
                                    color: const Color(0xFF666565),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    totalValue,
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 24,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          buildPeriodSelector(),
                        ],
                      ),
                      Expanded(
                        child: (controller.isLoading || (barChartBase == null))
                            ? const Center(child: CupertinoActivityIndicator(color: Colors.grey, radius: 20))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _scrollController,
                                child: Container(
                                  width: chartWidth,
                                  alignment: Alignment.center,
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.center,
                                      maxY: (barChartBase.maxY ?? 0) + 20,
                                      minY: 0,
                                      groupsSpace: groupsSpace,
                                      barTouchData: BarTouchData(
                                        enabled: true,
                                        touchTooltipData: BarTouchTooltipData(
                                          tooltipRoundedRadius: 4,
                                          maxContentWidth: 200,
                                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          fitInsideVertically: true,
                                          fitInsideHorizontally: true,
                                          tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                                          getTooltipColor: (BarChartGroupData group) {
                                            return const Color(0xFFF8F8FB);
                                          },
                                          direction: TooltipDirection.auto,
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            String date = barChartBase.titles![group.x.toInt()];
                                            String value = "";

                                            if (widget.type == "distance") {
                                              int divValue = 1000;
                                              if (controller.selectedRobotType.toLowerCase() == 'untact') {
                                                divValue = 10000;

                                                double doubleValue = (rod.toY / divValue);
                                                doubleValue = ((doubleValue * 100).round()) / 100;
                                                value = "${Utils.doubleWithComma(doubleValue)}Km";
                                              } else {
                                                double doubleValue = ((rod.toY * 100).round()) / 100;
                                                value = "${Utils.doubleWithComma(doubleValue)}m";
                                              }
                                            } else if (widget.type == "time") {
                                              int intValue = rod.toY.round();
                                              int hour = intValue ~/ 3600;
                                              int min = (intValue % 3600) ~/ 60;
                                              int sec = intValue % 60;

                                              if (hour > 0) {
                                                value = "${hour.toString().padLeft(2, '0')}시간 ";
                                              }

                                              value +=
                                                  "${min.toString().padLeft(2, '0')}분 ${sec.toString().padLeft(2, '0')}초";
                                            } else {
                                              double doubleValue = rod.toY;
                                              doubleValue = ((doubleValue * 10).round()) / 10;
                                              value = "${Utils.doubleWithComma(doubleValue)}%";
                                            }

                                            return BarTooltipItem(
                                              "\n",
                                              textAlign: TextAlign.center,
                                              const TextStyle(
                                                fontSize: 4,
                                                color: Colors.transparent,
                                                fontWeight: FontWeight.w700,
                                                height: 1.4,
                                              ),
                                              children: <TextSpan>[
                                                TextSpan(
                                                  text: "$date\n",
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF407BFF),
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: value,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Color(0xFF363636),
                                                    fontWeight: FontWeight.w400,
                                                    wordSpacing: 1.0,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              String date = barChartBase.titles![value.toInt()];

                                              if (period == 'daily') {
                                                date = date.substring(5);
                                                date = date.replaceAll("-", "/");
                                              } else if (period == 'weekly') {
                                                date = date.substring(5);
                                              }

                                              return Text(
                                                date,
                                                style: TextStyle(
                                                  fontFamily: 'light',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                            reservedSize: 40,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      gridData: FlGridData(
                                        show: false,
                                        horizontalInterval: 20,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: Colors.red,
                                            strokeWidth: 1,
                                          );
                                        },
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade400,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      barGroups: barChartBase.barChartItems ?? [],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  Positioned(
                    left: 40,
                    top: (viewHeight - 25) / 2,
                    child: GestureDetector(
                      onTap: () {
                        _scrollController.animateTo(_scrollController.offset - 200,
                            duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
                      },
                      child: Container(
                        width: 15,
                        height: 25,
                        alignment: Alignment.center,
                        color: Colors.transparent,
                        child: SvgPicture.asset(
                          "assets/images/icons_left.svg",
                          width: 12,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                if (showArrow)
                  Positioned(
                    right: 40,
                    top: (viewHeight - 25) / 2,
                    child: GestureDetector(
                      onTap: () {
                        _scrollController.animateTo(_scrollController.offset + 200,
                            duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
                      },
                      child: Container(
                        width: 15,
                        height: 25,
                        alignment: Alignment.center,
                        color: Colors.transparent,
                        child: SvgPicture.asset(
                          "assets/images/icons_right.svg",
                          width: 12,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE6E6E6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            offset: Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (widget.type == "distance") {
                Get.find<GraphController>().setSelectedPeriodDistance("daily");
              } else if (widget.type == "time") {
                Get.find<GraphController>().setSelectedPeriodTime("daily");
              } else {
                Get.find<GraphController>().setSelectedPeriodBattery("daily");
              }

              Get.find<GraphController>().reqUpdateChartItems("daily");
            },
            child: buildPeriodButton("일"),
          ),
          GestureDetector(
            onTap: () {
              if (widget.type == "distance") {
                Get.find<GraphController>().setSelectedPeriodDistance("weekly");
              } else if (widget.type == "time") {
                Get.find<GraphController>().setSelectedPeriodTime("weekly");
              } else {
                Get.find<GraphController>().setSelectedPeriodBattery("weekly");
              }
              Get.find<GraphController>().reqUpdateChartItems("weekly");
            },
            child: buildPeriodButton("주"),
          ),
          GestureDetector(
            onTap: () {
              if (widget.type == "distance") {
                Get.find<GraphController>().setSelectedPeriodDistance("monthly");
              } else if (widget.type == "time") {
                Get.find<GraphController>().setSelectedPeriodTime("monthly");
              } else {
                Get.find<GraphController>().setSelectedPeriodBattery("monthly");
              }
              Get.find<GraphController>().reqUpdateChartItems("monthly");
            },
            child: buildPeriodButton("월"),
          ),
          GestureDetector(
            onTap: () {
              if (widget.type == "distance") {
                Get.find<GraphController>().setSelectedPeriodDistance("yearly");
              } else if (widget.type == "time") {
                Get.find<GraphController>().setSelectedPeriodTime("yearly");
              } else {
                Get.find<GraphController>().setSelectedPeriodBattery("yearly");
              }
              Get.find<GraphController>().reqUpdateChartItems("yearly");
            },
            child: buildPeriodButton("년"),
          ),
        ],
      ),
    );
  }

  Widget buildPeriodButton(String title) {
    String period = (widget.type == "distance")
        ? Get.find<GraphController>().selectedPeriodDistance
        : (widget.type == "time")
            ? Get.find<GraphController>().selectedPeriodTime
            : Get.find<GraphController>().selectedPeriodBattery;

    bool isSelected = (period == "daily" && title == "일") ||
        (period == "weekly" && title == "주") ||
        (period == "monthly" && title == "월") ||
        (period == "yearly" && title == "년");

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isSelected ? const Color(0xFF146CBE) : Colors.transparent,
            isSelected ? const Color(0xFF0641C9) : Colors.transparent,
          ],
        ),
      ),
      margin: const EdgeInsets.all(2),
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005FB8) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  String getCurrentPeriod() {
    if (widget.type == "distance") {
      return Get.find<GraphController>().selectedPeriodDistance;
    } else if (widget.type == "time") {
      return Get.find<GraphController>().selectedPeriodTime;
    } else {
      return Get.find<GraphController>().selectedPeriodBattery;
    }
  }
}
