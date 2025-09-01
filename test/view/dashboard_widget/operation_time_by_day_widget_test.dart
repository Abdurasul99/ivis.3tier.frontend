// test/view/dashboard_widget/operation_time_by_day_widget_test.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/operation_time_by_day_widget.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/constants/constants.dart';

/// A fake GraphController where we can control loading and timeByDay.
class FakeGraphController extends GraphController {
  bool _loading = false;
  Map<int, double> _timeByDay = <int, double>{};

  @override
  bool get isLoadingTotal {
    return _loading;
  }

  set isLoadingTotal(bool value) {
    _loading = value;
  }

  @override
  Map<int, double> get timeByDay {
    return _timeByDay;
  }

  set timeByDay(Map<int, double> map) {
    _timeByDay = map;
  }

  @override
  Future<void> makeTotalValues() async {
    // no-op for tests
  }
}

/// A fake RobotController where we can set the robots list.
class FakeRobotController extends RobotController {
  List<Robot> _robots = <Robot>[];

  @override
  List<Robot> get robots {
    return _robots;
  }

  set robots(List<Robot> list) {
    _robots = list;
  }
}

void main() {
  late FakeGraphController graphCtrl;
  late FakeRobotController robotCtrl;

  setUp(() {
    // Clear and re-register our fakes before each test
    Get.reset();
    graphCtrl = FakeGraphController();
    robotCtrl = FakeRobotController();
    Get.put<GraphController>(graphCtrl);
    Get.put<RobotController>(robotCtrl);
  });

  /// Wrap the widget in a MaterialApp and give it plenty of room
  /// to avoid any overflow during testing.
  Widget wrapInApp(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800.0,
            height: 400.0,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('shows a spinner when graph data is loading', (WidgetTester tester) async {
    // Arrange
    graphCtrl.isLoadingTotal = true;
    robotCtrl.robots = <Robot>[];
    graphCtrl.timeByDay = <int, double>{};

    // Act
    await tester.pumpWidget(wrapInApp(const OperationTimeByDayWidget()));
    await tester.pump(); // let the first frame settle

    // Assert
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('shows "주행 시간이 없습니다 😑" when there are no robots or no data', (WidgetTester tester) async {
    // Arrange
    graphCtrl.isLoadingTotal = false;
    robotCtrl.robots = <Robot>[];
    graphCtrl.timeByDay = <int, double>{};

    // Act
    await tester.pumpWidget(wrapInApp(const OperationTimeByDayWidget()));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('주행 시간이 없습니다 😑'), findsOneWidget);
  });

  testWidgets('renders one BarChart when robots + timeByDay are present', (WidgetTester tester) async {
    // Arrange: two robots and matching time-by-day values
    graphCtrl.isLoadingTotal = false;

    final Robot robotA = Robot(id: 0, name: 'Alpha', typeDescription: 'Taro');
    final Robot robotB = Robot(id: 1, name: 'Beta', typeDescription: 'Untact');

    robotCtrl.robots = <Robot>[robotA, robotB];

    // Provide two entries of time in seconds.
    // These become the BarChart rods.
    graphCtrl.timeByDay = <int, double>{
      0: 3600.0, // one hour
      1: 180.0, // three minutes
    };

    // Act
    await tester.pumpWidget(wrapInApp(const OperationTimeByDayWidget()));
    await tester.pumpAndSettle();

    // Assert that exactly one BarChart is rendered
    expect(find.byType(BarChart), findsOneWidget);

    // And the bottom titles should include the two robot names.
    // The chart builds Text widgets for each name.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });
}
