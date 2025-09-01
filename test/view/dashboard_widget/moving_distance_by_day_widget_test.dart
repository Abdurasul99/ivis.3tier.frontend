// test/view/dashboard_widget/moving_distance_by_day_widget_test.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/moving_distance_by_day_widget.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';

/// A fake GraphController that never clears its loading flag in makeTotalValues().
class FakeGraphController extends GraphController {
  bool _loading = false;
  Map<int, double> _data = {};

  @override
  bool get isLoadingTotal => _loading;
  set isLoadingTotal(bool v) => _loading = v;

  @override
  Map<int, double> get distanceByDay => _data;
  set distanceByDay(Map<int, double> m) => _data = m;

  /// Do nothing here, so if we set _loading=true, it stays true.
  @override
  Future<void> makeTotalValues() async {
    // intentionally no update()
  }
}

/// A fake RobotController so we can drive the `robots` list.
class FakeRobotController extends RobotController {
  List<Robot> _robots = [];

  @override
  List<Robot> get robots => _robots;
  set robots(List<Robot> list) => _robots = list;
}

void main() {
  late FakeGraphController graphCtrl;
  late FakeRobotController robotCtrl;

  setUp(() {
    Get.reset();
    graphCtrl = FakeGraphController();
    robotCtrl = FakeRobotController();
    Get.put<GraphController>(graphCtrl);
    Get.put<RobotController>(robotCtrl);
  });

  Widget wrap(Widget child) {
    // Give plenty of room to avoid overflow errors.
    return GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 400, height: 300, child: child),
        ),
      ),
    );
  }

  testWidgets('shows spinner when graph is loading', (tester) async {
    // Arrange: force loading=true and no data
    graphCtrl.isLoadingTotal = true;
    graphCtrl.distanceByDay = {};
    robotCtrl.robots = [];

    // Act
    await tester.pumpWidget(wrap(const MovingDistanceByDayWidget()));
    await tester.pump(); // allow build

    // Assert
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('shows empty-state when no robots or no data', (tester) async {
    // Arrange: no load, no data, no robots
    graphCtrl.isLoadingTotal = false;
    graphCtrl.distanceByDay = {};
    robotCtrl.robots = [];

    // Act
    await tester.pumpWidget(wrap(const MovingDistanceByDayWidget()));
    await tester.pump(); // allow build

    // Assert
    expect(find.text('주행 정보가 없습니다 😑'), findsOneWidget);
  });

  testWidgets('renders two BarCharts when both taro+untact robots with data', (tester) async {
    // Arrange: not loading
    graphCtrl.isLoadingTotal = false;

    // Two robots: one "taro", one "untact"
    robotCtrl.robots = [
      Robot(id: 10, name: 'Taro1', typeDescription: 'taro'),
      Robot(id: 20, name: 'Unt1', typeDescription: 'untact'),
    ];

    // Provide distances for both
    graphCtrl.distanceByDay = {
      10: 123.45,
      20: 67.89,
    };

    // Act
    await tester.pumpWidget(wrap(const MovingDistanceByDayWidget()));
    await tester.pumpAndSettle(); // finish any animations

    // The title is always present
    expect(find.text('일평균 주행거리'), findsOneWidget);

    // There should be exactly two BarCharts:
    //  - one for the untact group
    //  - one for the taro group
    expect(find.byType(BarChart), findsNWidgets(2));
  });
}
