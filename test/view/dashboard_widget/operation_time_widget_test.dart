// test/view/dashboard_widget/operation_time_widget_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/operation_time_widget.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/constants/constants.dart';

/// A fake GraphController where we control loading and totalTime.
class FakeGraphController extends GraphController {
  bool _loading = false;
  Map<int, double> _times = {};

  @override
  bool get isLoadingTotal => _loading;
  set isLoadingTotal(bool v) => _loading = v;

  @override
  Map<int, double> get totalTime => _times;
  set totalTime(Map<int, double> m) => _times = m;

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

  testWidgets('shows spinner when graph is loading', (tester) async {
    // Arrange: simulate loading
    graphCtrl.isLoadingTotal = true;
    robotCtrl.robots = [];

    // Act
    await tester.pumpWidget(wrap(const OperationTimeWidget()));
    await tester.pump(); // first frame

    // Assert
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('shows "운영시간 정보가 없습니다 😑" when no robots or no times', (tester) async {
    // Arrange: not loading, but no data
    graphCtrl.isLoadingTotal = false;
    robotCtrl.robots = [];
    graphCtrl.totalTime = {};

    // Act
    await tester.pumpWidget(wrap(const OperationTimeWidget()));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('운영시간 정보가 없습니다 😑'), findsOneWidget);
  });

  testWidgets('renders two robots in one row with correctly formatted hh/mm/ss', (tester) async {
    // Arrange: one untact and one taro robot
    graphCtrl.isLoadingTotal = false;

    final r1 = Robot(id: 1, name: 'R1', typeDescription: 'untact');
    final r2 = Robot(id: 2, name: 'R2', typeDescription: 'taro');

    robotCtrl.robots = [r1, r2];

    // totalTime in seconds:
    // r1: 3661.4 → round→3661 → 1h 1m 1s → "1시간 01분 01초"
    // r2:  61.7 → round→62   →   1m 2s    → "01분 02초"
    graphCtrl.totalTime = {
      1: 3661.4,
      2:   61.7,
    };

    // Act
    await tester.pumpWidget(wrap(const OperationTimeWidget()));
    await tester.pumpAndSettle();

    // Assert robot labels
    expect(find.text('untact_R1'), findsOneWidget);
    expect(find.text('taro_R2'),   findsOneWidget);

    // Assert formatted times
    expect(find.text('1시간 01분 01초'), findsOneWidget);
    expect(find.text('01분 02초'),     findsOneWidget);
  });
}
