// test/view/dashboard_widget/used_battery_widget_test.dart

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/used_battery_widget.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/utils/utils.dart';

/// A fake GraphController that drives isLoadingTotal & totalBattery
class FakeGraphController extends GraphController {
  bool _loading = false;
  Map<int, double> _totalBattery = {};

  @override
  bool get isLoadingTotal => _loading;
  set isLoadingTotal(bool v) => _loading = v;

  @override
  Map<int, double> get totalBattery => Map.unmodifiable(_totalBattery);

  /// helper to seed totalBattery
  void setTotalBattery(Map<int, double> data) {
    _totalBattery = Map<int, double>.from(data);
  }

  @override
  Future<void> makeTotalValues() async {
    // no-op
  }
}

/// A fake RobotController that drives the robots list
class FakeRobotController extends RobotController {
  List<Robot> _robots = <Robot>[];

  @override
  List<Robot> get robots => List.unmodifiable(_robots);

  /// helper to seed robots
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
    // Put our fakes into GetX before pumping
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

  testWidgets('shows spinner when loading', (WidgetTester tester) async {
    // arrange
    graphCtrl.isLoadingTotal = true;
    graphCtrl.setTotalBattery({});
    robotCtrl.setRobots(<Robot>[]);

    // act
    await tester.pumpWidget(wrap(const UsedBatteryWidget()));
    await tester.pump(); // allow indicator to appear

    // assert
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('베터리 정보가 없습니다 😑'), findsNothing);
    expect(find.byType(ExtendedImage), findsNothing);
  });

  testWidgets('shows empty message when not loading and no data', (WidgetTester tester) async {
    // arrange
    graphCtrl.isLoadingTotal = false;
    graphCtrl.setTotalBattery({});
    robotCtrl.setRobots(<Robot>[]);

    // act
    await tester.pumpWidget(wrap(const UsedBatteryWidget()));
    await tester.pumpAndSettle();

    // assert
    expect(find.text('베터리 정보가 없습니다 😑'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.byType(ExtendedImage), findsNothing);
  });

  testWidgets('renders two robots in one row with correct percentage units after rounding',
      (WidgetTester tester) async {
    // arrange
    graphCtrl.isLoadingTotal = false;

    // seed two robots
    robotCtrl.setRobots(<Robot>[
      Robot.fromJson({'id': 1, 'type_description': 'T', 'name': 'One'}),
      Robot.fromJson({'id': 2, 'type_description': 'U', 'name': 'Two'}),
    ]);

    // battery values: will be multiplied by 100 and rounded to 2 decimal places
    graphCtrl.setTotalBattery({1: 0.105, 2: 0.8765});

    // act
    await tester.pumpWidget(wrap(const UsedBatteryWidget()));
    await tester.pumpAndSettle();

    // header always present
    expect(find.text('전체 로봇의 누적 사용배터리'), findsOneWidget);

    // each robot’s label: "T_One" and "U_Two"
    expect(find.text('T_One'), findsOneWidget);
    expect(find.text('U_Two'), findsOneWidget);

    // actual widget uses (battery*100).round()/100:
    //   0.105*100 = 10.5 → round()=11 → 11/100 = 0.11 → "0.11%"
    //   0.8765*100 = 87.65 → round()=88 → 88/100 = 0.88 → "0.88%"
    expect(find.text('0.11%'), findsOneWidget);
    expect(find.text('0.88%'), findsOneWidget);

    // no spinner or empty text
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.text('베터리 정보가 없습니다 😑'), findsNothing);
  });
}
