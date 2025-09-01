// test/view/dashboard_widget/moving_distance_widget_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/moving_distance_widget.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';

/// A fake GraphController where we control loading and totalDistance.
class FakeGraphController extends GraphController {
  bool _loading = false;
  Map<int, double> _totals = {};

  @override
  bool get isLoadingTotal => _loading;
  set isLoadingTotal(bool v) => _loading = v;

  @override
  Map<int, double> get totalDistance => _totals;
  set totalDistance(Map<int, double> m) => _totals = m;

  @override
  Future<void> makeTotalValues() async {
    // no-op
  }
}

/// A fake RobotController where we set the robots list.
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
    // Provide plenty of space to avoid overflow.
    return GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 800, height: 400, child: child),
        ),
      ),
    );
  }

  testWidgets('renders two robots in one row with correct distance units', (tester) async {
    // Arrange
    graphCtrl.isLoadingTotal = false;

    // Robot 1: untact, raw totalDistance=10000 => displayed as (10000/10000)*100 → round/100 → 1.0 → "1km"
    final untact = Robot(id: 1, name: 'U1', typeDescription: 'untact');

    // Robot 2: taro, raw totalDistance=123.45 → round/100 → 123.45 → "123.45m"
    final taro = Robot(id: 2, name: 'T2', typeDescription: 'taro');

    robotCtrl.robots = [untact, taro];
    graphCtrl.totalDistance = {
      1: 10000.0,
      2: 123.45,
    };

    // Act
    await tester.pumpWidget(wrap(const MovingDistanceWidget()));
    await tester.pumpAndSettle();

    // Assert that each robot label shows up
    expect(find.text('untact_U1'), findsOneWidget);
    expect(find.text('taro_T2'), findsOneWidget);

    // Assert the formatted distances
    expect(find.text('1km'), findsOneWidget);
    expect(find.text('123.45m'), findsOneWidget);
  });
}
