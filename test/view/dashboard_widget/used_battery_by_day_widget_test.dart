// test/view/dashboard_widget/used_battery_by_day_widget_test.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/used_battery_by_day_widget.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';

/// A minimal fake GraphController to drive isLoadingTotal & batteryByDay.
class FakeGraphController extends GraphController {
  bool _loading = false;
  Map<int, double> _batteryByDay = {};

  @override
  bool get isLoadingTotal => _loading;
  set isLoadingTotal(bool v) => _loading = v;

  @override
  Map<int, double> get batteryByDay => Map.unmodifiable(_batteryByDay);

  /// helper to seed battery data
  void setBatteryByDay(Map<int, double> data) {
    _batteryByDay = Map<int, double>.from(data);
  }

  @override
  Future<void> makeTotalValues() async {
    // do nothing
  }
}

/// A minimal fake RobotController to drive robots list.
class FakeRobotController extends RobotController {
  List<Robot> _robots = <Robot>[];

  @override
  List<Robot> get robots => List.unmodifiable(_robots);

  /// helper to seed robots list
  void setRobots(List<Robot> list) {
    _robots = List<Robot>.from(list);
  }
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
    return GetMaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 300, child: child),
      ),
    );
  }

  testWidgets('shows spinner when graph is loading', (WidgetTester tester) async {
    graphCtrl.isLoadingTotal = true;
    graphCtrl.setBatteryByDay({});
    robotCtrl.setRobots(<Robot>[]);

    await tester.pumpWidget(wrap(const UsedBatteryByDayWidget()));
    await tester.pump(); // allow one frame

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('배터리 정보가 없습니다 😑'), findsNothing);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('shows empty message when not loading but no data', (WidgetTester tester) async {
    graphCtrl.isLoadingTotal = false;
    graphCtrl.setBatteryByDay({});
    robotCtrl.setRobots(<Robot>[]);

    await tester.pumpWidget(wrap(const UsedBatteryByDayWidget()));
    await tester.pump(); // finish build

    expect(find.text('배터리 정보가 없습니다 😑'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('renders one BarChart when robots + battery data present', (WidgetTester tester) async {
    graphCtrl.isLoadingTotal = false;
    // two robots with IDs 1 and 2
    robotCtrl.setRobots(<Robot>[
      Robot.fromJson({'id': 1, 'name': 'R1', 'type_description': 'X'}),
      Robot.fromJson({'id': 2, 'name': 'R2', 'type_description': 'Y'}),
    ]);
    // daily battery usage for each robot
    graphCtrl.setBatteryByDay({1: 45.5, 2: 80.0});

    await tester.pumpWidget(wrap(const UsedBatteryByDayWidget()));
    await tester.pumpAndSettle();

    // header text always present
    expect(find.text('일평균 사용베터리'), findsOneWidget);
    // exactly one BarChart in the tree
    expect(find.byType(BarChart), findsOneWidget);

    // verify the chart got built with our two data points by looking
    // for the two bottom-label Texts R1 and R2 that FLChart generated:
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('R2'), findsOneWidget);

    // no spinner or empty-message
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.text('배터리 정보가 없습니다 😑'), findsNothing);
  });
}
