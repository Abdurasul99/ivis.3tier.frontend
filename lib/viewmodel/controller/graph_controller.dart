import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../model/graph_model.dart';
import '../../model/robot_model.dart';
import '../repository/graph_repository.dart';

class GraphController extends GetxController {
  Map<int, List<ChartItem>> _dailyCharts = {};
  Map<int, List<ChartItem>> _weeklyCharts = {};
  Map<int, List<ChartItem>> _monthlyCharts = {};
  Map<int, List<ChartItem>> _yearlyCharts = {};

  Map<int, BarChartBase> _dailyDistanceBarChartGroups = {};
  Map<int, BarChartBase> _dailyTimeBarChartGroups = {};
  Map<int, BarChartBase> _dailyBatteryBarChartGroups = {};

  Map<int, BarChartBase> _weeklyDistanceBarChartGroups = {};
  Map<int, BarChartBase> _weeklyTimeBarChartGroups = {};
  Map<int, BarChartBase> _weeklyBatteryBarChartGroups = {};

  Map<int, BarChartBase> _monthlyDistanceBarChartGroups = {};
  Map<int, BarChartBase> _monthlyTimeBarChartGroups = {};
  Map<int, BarChartBase> _monthlyBatteryBarChartGroups = {};

  Map<int, BarChartBase> _yearlyDistanceBarChartGroups = {};
  Map<int, BarChartBase> _yearlyTimeBarChartGroups = {};
  Map<int, BarChartBase> _yearlyBatteryBarChartGroups = {};

  Map<int, double> _totalDistance = {};
  Map<int, double> _totalTime = {};
  Map<int, double> _totalBattery = {};

  Map<int, double> _distanceByDay = {};
  Map<int, double> _timeByDay = {};
  Map<int, double> _batteryByDay = {};

  bool _isLoading = false;
  bool _isLoadingTotal = false;
  int _selectedRobotId = -1;
  String _selectedRobotType = "";

  String _selectedPeriodDistance = "daily";
  String _selectedPeriodTime = "daily";
  String _selectedPeriodBattery = "daily";

  Map<int, List<ChartItem>> get dailyCharts => _dailyCharts;
  Map<int, List<ChartItem>> get weeklyCharts => _weeklyCharts;
  Map<int, List<ChartItem>> get monthlyCharts => _monthlyCharts;
  Map<int, List<ChartItem>> get yearlyCharts => _yearlyCharts;

  Map<int, BarChartBase> get dailyDistanceBarChartGroups => _dailyDistanceBarChartGroups;
  Map<int, BarChartBase> get dailyTimeBarChartGroups => _dailyTimeBarChartGroups;
  Map<int, BarChartBase> get dailyBatteryBarChartGroups => _dailyBatteryBarChartGroups;

  Map<int, BarChartBase> get weeklyDistanceBarChartGroups => _weeklyDistanceBarChartGroups;
  Map<int, BarChartBase> get weeklyTimeBarChartGroups => _weeklyTimeBarChartGroups;
  Map<int, BarChartBase> get weeklyBatteryBarChartGroups => _weeklyBatteryBarChartGroups;

  Map<int, BarChartBase> get monthlyDistanceBarChartGroups => _monthlyDistanceBarChartGroups;
  Map<int, BarChartBase> get monthlyTimeBarChartGroups => _monthlyTimeBarChartGroups;
  Map<int, BarChartBase> get monthlyBatteryBarChartGroups => _monthlyBatteryBarChartGroups;

  Map<int, BarChartBase> get yearlyDistanceBarChartGroups => _yearlyDistanceBarChartGroups;
  Map<int, BarChartBase> get yearlyTimeBarChartGroups => _yearlyTimeBarChartGroups;
  Map<int, BarChartBase> get yearlyBatteryBarChartGroups => _yearlyBatteryBarChartGroups;

  Map<int, double> get totalDistance => _totalDistance;
  Map<int, double> get totalTime => _totalTime;
  Map<int, double> get totalBattery => _totalBattery;

  Map<int, double> get distanceByDay => _distanceByDay;
  Map<int, double> get timeByDay => _timeByDay;
  Map<int, double> get batteryByDay => _batteryByDay;

  bool get isLoading => _isLoading;
  bool get isLoadingTotal => _isLoadingTotal;
  int get selectedRobotId => _selectedRobotId;
  String get selectedRobotType => _selectedRobotType;

  String get selectedPeriodDistance => _selectedPeriodDistance;
  String get selectedPeriodTime => _selectedPeriodTime;
  String get selectedPeriodBattery => _selectedPeriodBattery;

  ///////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  void setSelectedRobotId(int robotId) {
    _selectedRobotId = robotId;
  }

  void setSelectedRobotType(String robotType) {
    _selectedRobotType = robotType;
  }

  void setSelectedPeriodDistance(String period) {
    _selectedPeriodDistance = period;
  }

  void setSelectedPeriodTime(String period) {
    _selectedPeriodTime = period;
  }

  void setSelectedPeriodBattery(String period) {
    _selectedPeriodBattery = period;
  }

  List<ChartItem> getChartItems(String type) {
    List<ChartItem> chartItems = [];

    // debugPrint("getChartItems() type: $type, _selectedRobotId: $_selectedRobotId");

    if (_selectedRobotId == -1) {
      return [];
    }

    String period = (type == "distance")
        ? _selectedPeriodDistance
        : (type == "time")
            ? _selectedPeriodTime
            : _selectedPeriodBattery;

    if (period == "daily") {
      chartItems = _dailyCharts[_selectedRobotId] ?? [];
    } else if (period == "weekly") {
      chartItems = _weeklyCharts[_selectedRobotId] ?? [];
    } else if (period == "monthly") {
      chartItems = _monthlyCharts[_selectedRobotId] ?? [];
    } else if (period == "yearly") {
      chartItems = _yearlyCharts[_selectedRobotId] ?? [];
    }

    return chartItems;
  }

  void reqRemoveChartItems(int robotId) async {
    debugPrint("reqRemoveChartItems() robotId: $robotId");

    _isLoading = true;

    _dailyCharts[robotId] = await GraphRepository().getChartItems(_selectedRobotId, "daily");
    _weeklyCharts[robotId] = await GraphRepository().getChartItems(_selectedRobotId, "weekly");
    _monthlyCharts[robotId] = await GraphRepository().getChartItems(_selectedRobotId, "monthly");
    _yearlyCharts[robotId] = await GraphRepository().getChartItems(_selectedRobotId, "yearly");

    _dailyDistanceBarChartGroups.remove(robotId);
    _dailyTimeBarChartGroups.remove(robotId);
    _dailyBatteryBarChartGroups.remove(robotId);

    _weeklyDistanceBarChartGroups.remove(robotId);
    _weeklyTimeBarChartGroups.remove(robotId);
    _weeklyBatteryBarChartGroups.remove(robotId);

    _monthlyDistanceBarChartGroups.remove(robotId);
    _monthlyTimeBarChartGroups.remove(robotId);
    _monthlyBatteryBarChartGroups.remove(robotId);

    _yearlyDistanceBarChartGroups.remove(robotId);
    _yearlyTimeBarChartGroups.remove(robotId);
    _yearlyBatteryBarChartGroups.remove(robotId);

    _isLoading = false;
    update();
  }

  Future<List<ChartItem>> reqUpdateChartItems(String period) async {
    List<ChartItem>? chartItems;

    if (_selectedRobotId == -1) {
      return [];
    }

    // debugPrint("reqUpdateChartItems() period: $period");

    if (period == "daily") {
      chartItems = _dailyCharts[_selectedRobotId];
    } else if (period == "weekly") {
      chartItems = _weeklyCharts[_selectedRobotId];
    } else if (period == "monthly") {
      chartItems = _monthlyCharts[_selectedRobotId];
    } else if (period == "yearly") {
      chartItems = _yearlyCharts[_selectedRobotId];
    }

    if (chartItems != null) {
      update();
      return chartItems;
    }

    _isLoading = true;
    chartItems = await GraphRepository().getChartItems(_selectedRobotId, period);

    // debugPrint("chartItems $chartItems");

    if (period == "daily") {
      _dailyCharts[_selectedRobotId] = chartItems;
    } else if (period == "weekly") {
      _weeklyCharts[_selectedRobotId] = chartItems;
    } else if (period == "monthly") {
      _monthlyCharts[_selectedRobotId] = chartItems;
    } else if (period == "yearly") {
      _yearlyCharts[_selectedRobotId] = chartItems;
    }

    _isLoading = false;
    update();

    return chartItems;
  }

  BarChartBase? getBarChartGroupData(String type) {
    BarChartBase? barChartBase;

    if (_isLoading) {
      return null;
    }

    if (type == "distance") {
      if (_selectedPeriodDistance == 'daily') {
        barChartBase = _dailyDistanceBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodDistance == 'weekly') {
        barChartBase = _weeklyDistanceBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodDistance == 'monthly') {
        barChartBase = _monthlyDistanceBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodDistance == 'yearly') {
        barChartBase = _yearlyDistanceBarChartGroups[_selectedRobotId];
      }
    } else if (type == "time") {
      if (_selectedPeriodTime == 'daily') {
        barChartBase = _dailyTimeBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodTime == 'weekly') {
        barChartBase = _weeklyTimeBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodTime == 'monthly') {
        barChartBase = _monthlyTimeBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodTime == 'yearly') {
        barChartBase = _yearlyTimeBarChartGroups[_selectedRobotId];
      }
    } else {
      if (_selectedPeriodBattery == 'daily') {
        barChartBase = _dailyBatteryBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodBattery == 'weekly') {
        barChartBase = _weeklyBatteryBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodBattery == 'monthly') {
        barChartBase = _monthlyBatteryBarChartGroups[_selectedRobotId];
      } else if (_selectedPeriodBattery == 'yearly') {
        barChartBase = _yearlyBatteryBarChartGroups[_selectedRobotId];
      }
    }

    // debugPrint("getBarChartGroupData() barChartBase: $barChartBase");

    if (barChartBase == null) {
      barChartBase = makeBarChartGroupData(type);

      if (type == "distance") {
        if (_selectedPeriodDistance == 'daily') {
          _dailyDistanceBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodDistance == 'weekly') {
          _weeklyDistanceBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodDistance == 'monthly') {
          _monthlyDistanceBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodDistance == 'yearly') {
          _yearlyDistanceBarChartGroups[_selectedRobotId] = barChartBase;
        }
      } else if (type == "time") {
        if (_selectedPeriodTime == 'daily') {
          _dailyTimeBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodTime == 'weekly') {
          _weeklyTimeBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodTime == 'monthly') {
          _monthlyTimeBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodTime == 'yearly') {
          _yearlyTimeBarChartGroups[_selectedRobotId] = barChartBase;
        }
      } else if (type == "battery") {
        if (_selectedPeriodBattery == 'daily') {
          _dailyBatteryBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodBattery == 'weekly') {
          _weeklyBatteryBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodBattery == 'monthly') {
          _monthlyBatteryBarChartGroups[_selectedRobotId] = barChartBase;
        } else if (_selectedPeriodBattery == 'yearly') {
          _yearlyBatteryBarChartGroups[_selectedRobotId] = barChartBase;
        }
      }
    }

    return barChartBase;
  }

  BarChartBase makeBarChartGroupData(String type) {
    List<ChartItem> chartItems = [];
    List<BarChartGroupData> barItems = [];

    chartItems = getChartItems(type);

    // debugPrint("makeBarChartGroupData() chartItems: $chartItems");

    double maxY = 0;
    double sumOfValue = 0;
    List<String> dates = [];

    if (chartItems.isNotEmpty) {
      int xCount = calcXItemCount(chartItems[0].date ?? "", chartItems[chartItems.length - 1].date ?? "", type);
      // debugPrint("xCount: $xCount");

      String indexDate = chartItems[0].date ?? "";
      for (int i = 0; i < xCount; i++) {
        // debugPrint("chartItems[$i].date: $indexDate");
        ChartItem? item = chartItems.firstWhereOrNull((element) => element.date == indexDate);

        double valueY = (item == null)
            ? 0
            : (type == "distance")
                ? (item.distance ?? 0)
                : (type == "time")
                    ? (item.time ?? 0)
                    : (item.battery ?? 0);

        maxY = max(maxY, valueY);
        sumOfValue += valueY;

        barItems.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: valueY,
                color: const Color(0xFF60CDFF),
                width: 16,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
            ],
          ),
        );

        dates.add(indexDate);
        indexDate = getNextLabel(indexDate, type);
      }
    }

    BarChartBase barChartBase = BarChartBase(
      maxY: maxY,
      sumOfValue: sumOfValue,
      titles: dates,
      barChartItems: barItems,
    );

    return barChartBase;
  }

  String getCurrentPeriod(String type) {
    if (type == "distance") {
      return Get.find<GraphController>().selectedPeriodDistance;
    } else if (type == "time") {
      return Get.find<GraphController>().selectedPeriodTime;
    } else {
      return Get.find<GraphController>().selectedPeriodBattery;
    }
  }

  String getNextLabel(String current, type) {
    String period = getCurrentPeriod(type);

    if (period == "daily") {
      DateTime startDate = DateTime.parse(current);
      startDate = startDate.add(const Duration(days: 1));

      DateFormat formatter = DateFormat('yyyy-MM-dd');
      return formatter.format(startDate);
    } else if (period == "weekly") {
      List<int> details = parseWeekString(current);

      int year = details[0];
      int weekOfYear = details[1];

      weekOfYear++;

      int weeksInYear = calculateWeeksInYear(year);

      if (weekOfYear > weeksInYear) {
        year++;
        weekOfYear = 1;
      }

      return "$year-W${weekOfYear.toString().padLeft(2, '0')}";
    } else if (period == "monthly") {
      List<int> details = parseYearMonthString(current);

      int year = details[0];
      int month = details[1];
      month++;

      if (month >= 13) {
        year++;
        month = 1;
      }

      return "$year-${(month < 10) ? "0" : ""}$month";
    } else if (period == "yearly") {
      int year = int.tryParse(current) ?? 0;
      return "${(year + 1)}";
    }

    return "";
  }

  int calculateWeeksInYear(int year) {
    DateTime dec28 = DateTime(year, 12, 28);
    int dayOfYear = calcDayOfYear(dec28);
    return ((dayOfYear - dec28.weekday + 10) / 7).floor();
  }

  int calcDayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  int calcXItemCount(String start, String end, String type) {
    String period = getCurrentPeriod(type);

    if (period == "daily") {
      DateTime startDate = DateTime.parse(start);
      DateTime endDate = DateTime.parse(end);
      return endDate.difference(startDate).inDays + 1;
    } else if (period == "weekly") {
      List<int> startDetails = parseWeekString(start);
      List<int> endDetails = parseWeekString(end);

      int startYear = startDetails[0];
      int startWeekNum = startDetails[1];
      int endYear = endDetails[0];
      int endWeekNum = endDetails[1];

      DateTime startDate = getFirstDayOfWeek(startYear, startWeekNum);
      DateTime endDate = getFirstDayOfWeek(endYear, endWeekNum);

      if (endDate.isBefore(startDate)) {
        return 0;
      }

      int differenceInDays = endDate.difference(startDate).inDays;
      int numberOfWeeks = (differenceInDays / 7).floor() + 1;

      return numberOfWeeks;
    } else if (period == "monthly") {
      List<int> startDetails = parseYearMonthString(start);
      List<int> endDetails = parseYearMonthString(end);

      int startYear = startDetails[0];
      int startMon = startDetails[1];
      int endYear = endDetails[0];
      int endMon = endDetails[1];

      if (endYear < startYear || (endYear == startYear && endMon < startMon)) {
        return 0;
      }

      int numberOfMonths = (endYear - startYear) * 12 + (endMon - startMon) + 1;
      return numberOfMonths;
    } else if (period == "yearly") {
      int startDetail = int.tryParse(start) ?? 0;
      int endDetail = int.tryParse(end) ?? 0;

      return (endDetail - startDetail) + 1;
    }

    return 0;
  }

  List<int> parseWeekString(String weekString) {
    final parts = weekString.split('-W');
    if (parts.length != 2) {
      throw FormatException("Invalid week string format: $weekString");
    }
    final year = int.tryParse(parts[0]);
    final week = int.tryParse(parts[1]);
    if (year == null || week == null) {
      throw FormatException("Invalid year or week number in: $weekString");
    }
    return [year, week];
  }

  DateTime getFirstDayOfWeek(int year, int weekNumber) {
    final jan4 = DateTime.utc(year, 1, 4);
    final dayOfWeekJan4 = jan4.weekday;
    final firstDayOfFirstWeek = jan4.subtract(Duration(days: dayOfWeekJan4 - 1));
    return firstDayOfFirstWeek.add(Duration(days: (weekNumber - 1) * 7));
  }

  List<int> parseYearMonthString(String yearMonthString) {
    final parts = yearMonthString.split('-');
    if (parts.length != 2) {
      if (yearMonthString.length == 6) {
        final year = int.tryParse(yearMonthString.substring(0, 4));
        final month = int.tryParse(yearMonthString.substring(4));
        if (year != null && month != null && month >= 1 && month <= 12) {
          return [year, month];
        }
      }
      throw FormatException("Invalid year-month string format: $yearMonthString. Expected YYYY-MM");
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      throw FormatException("Invalid year or month number in: $yearMonthString");
    }
    return [year, month];
  }

  Future<void> makeTotalValues() async {
    // debugPrint("isLoading $_isLoading");

    if (_isLoading) {
      return;
    }

    _isLoadingTotal = true;

    try {
      List<RobotStatus> robotStatusList = Get.find<RobotController>().robotStatusList;
      int beforeSelectedRobotId = _selectedRobotId;

      for (int i = 0; i < robotStatusList.length; i++) {
        int robotId = robotStatusList[i].id!;

        List<ChartItem> yearCharts = _yearlyCharts[robotId] ?? [];
        if (yearCharts.isEmpty) {
          _selectedRobotId = robotId;
          yearCharts = await reqUpdateChartItems("yearly");
          _yearlyCharts[robotId] = yearCharts;
        }

        List<ChartItem> dailyCharts = _dailyCharts[robotId] ?? [];
        if (dailyCharts.isEmpty) {
          _selectedRobotId = robotId;
          dailyCharts = await reqUpdateChartItems("daily");
          _dailyCharts[robotId] = dailyCharts;
        }

        double totalDistance = 0;
        double totalTime = 0;
        double totalBattery = 0;

        int distanceDayCount = 0;
        int timeDayCount = 0;
        int batteryDayCount = 0;

        for (int j = 0; j < yearCharts.length; j++) {
          ChartItem chartItem = yearCharts[j];

          totalDistance += (chartItem.distance ?? 0);
          totalTime += (chartItem.time ?? 0);
          totalBattery += (chartItem.battery ?? 0);
        }

        _totalDistance[robotId] = totalDistance;
        _totalTime[robotId] = totalTime;
        _totalBattery[robotId] = totalBattery;

        for (int j = 0; j < dailyCharts.length; j++) {
          ChartItem chartItem = dailyCharts[j];

          if (chartItem.distance != null && ((chartItem.distance ?? 0) > 0)) {
            distanceDayCount++;
          }

          if (chartItem.time != null && ((chartItem.time ?? 0) > 0)) {
            timeDayCount++;
          }

          if (chartItem.battery != null && ((chartItem.battery ?? 0) > 0)) {
            batteryDayCount++;
          }
        }

        _distanceByDay[robotId] = totalDistance / distanceDayCount;
        _timeByDay[robotId] = totalTime / timeDayCount;
        _batteryByDay[robotId] = totalBattery / batteryDayCount;
      }

      _selectedRobotId = beforeSelectedRobotId;
    } catch (error) {
      debugPrint("Error in makeTotalValues: $error");
    } finally {
      _isLoadingTotal = false;

      Future.microtask(() {
        update();
      });
    }
  }
}
