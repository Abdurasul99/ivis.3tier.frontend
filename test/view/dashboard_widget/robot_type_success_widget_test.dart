// test/view/dashboard_widget/robot_type_success_widget_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/robot_type_success_widget.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/model/dashboard_model.dart'; // <-- correct import for RobotSuccessData

/// A fake DashboardController matching only what the widget needs.
class FakeDashboardController extends DashboardController {
  bool _loading = false;
  final List<RobotSuccessData> _data = <RobotSuccessData>[];
  bool fetchCalled = false;

  @override
  bool get isLoading => _loading;
  set isLoading(bool v) => _loading = v;

  @override
  List<RobotSuccessData> get robotSuccessData => List.unmodifiable(_data);

  /// Helper to set up test data.
  void setData(List<RobotSuccessData> data) {
    _data
      ..clear()
      ..addAll(data);
  }

  @override
  Future<void> fetchRobotSuccess() async {
    fetchCalled = true;
    // no real network call
  }
}

void main() {
  late FakeDashboardController ctrl;

  setUp(() {
    Get.reset();
    ctrl = FakeDashboardController();
    Get.put<DashboardController>(ctrl);
  });

  Widget wrap(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, height: 200, child: child),
      ),
    );
  }

  testWidgets(
    'when data list is empty and not loading → spinner + fetch called',
    (WidgetTester tester) async {
      // arrange
      ctrl.isLoading = false;
      ctrl.setData(<RobotSuccessData>[]);

      // act
      await tester.pumpWidget(wrap(const RobotTypeSuccessWidget()));
      // let the microtask scheduled in build() run
      await tester.pump();

      // assert
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(ctrl.fetchCalled, isTrue);
    },
  );

  testWidgets(
    'when data present → header, names, and rounded percentages show',
    (WidgetTester tester) async {
      // arrange
      ctrl.isLoading = false;
      ctrl.setData(<RobotSuccessData>[
        RobotSuccessData(robotName: 'Alpha', successRate: 12.3),
        RobotSuccessData(robotName: 'Beta', successRate: 99.9),
      ]);

      // act
      await tester.pumpWidget(wrap(const RobotTypeSuccessWidget()));
      await tester.pumpAndSettle();

      // header
      expect(find.text('로봇 타입별 작업 성공률'), findsOneWidget);

      // names
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      // percentages: 12.3 → "12%", 99.9 → clamped to "100%"
      expect(find.text('12%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // no spinner
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    },
  );
}
