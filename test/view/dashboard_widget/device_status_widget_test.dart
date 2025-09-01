// test/view/dashboard_widget/device_status_widget_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dashboard_widgets/device_status_widget.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/constants/constants.dart';

/// A minimal fake to drive isLoading & robotStatusList.
class FakeRobotController extends RobotController {
  bool _loading = false;
  List<RobotStatus> _statuses = <RobotStatus>[];

  @override
  bool get isLoading {
    return _loading;
  }

  set isLoading(bool value) {
    _loading = value;
  }

  @override
  List<RobotStatus> get robotStatusList {
    return _statuses;
  }

  set robotStatusList(List<RobotStatus> list) {
    _statuses = list;
  }
}

void main() {
  late FakeRobotController controller;

  setUp(() {
    Get.reset();
    controller = FakeRobotController();
    Get.put<RobotController>(controller);
  });

  Widget wrapInApp(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800.0,
            height: 600.0,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('when loading, shows only a CupertinoActivityIndicator', (WidgetTester tester) async {
    controller.isLoading = true;
    controller.robotStatusList = <RobotStatus>[];

    await tester.pumpWidget(wrapInApp(const DeviceStatusWidget()));
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('when not loading and no statuses, shows empty-message text', (WidgetTester tester) async {
    controller.isLoading = false;
    controller.robotStatusList = <RobotStatus>[];

    await tester.pumpWidget(wrapInApp(const DeviceStatusWidget()));
    await tester.pump();

    expect(find.text('운행 정보가 없습니다 😑'), findsOneWidget);
  });

  testWidgets('with exactly one active, one charging, one error → titles present + single "1" count',
      (WidgetTester tester) async {
    controller.isLoading = false;

    // Active: description "untact", not at any station
    RobotStatus active = RobotStatus.fromJson(<String, dynamic>{
      'serial': 'A',
      'description': 'untact',
      'robotStatus': 0,
      'latitude': 0.0,
      'longitude': 0.0,
    });

    // Charging: description "untact", at station 0
    RobotStatus charging = RobotStatus.fromJson(<String, dynamic>{
      'serial': 'C',
      'description': 'untact',
      'robotStatus': 0,
      'latitude': kStation0Latitude,
      'longitude': kStation0Longitude,
    });

    // Error: other description, robotStatus = error
    RobotStatus error = RobotStatus.fromJson(<String, dynamic>{
      'serial': 'E',
      'description': 'other',
      'robotStatus': RobotState.error,
      'posX': 1.0,
      'posY': 1.0,
    });

    controller.robotStatusList = <RobotStatus>[active, charging, error];

    await tester.pumpWidget(wrapInApp(const DeviceStatusWidget()));
    await tester.pumpAndSettle();

    // Verify the three section titles
    expect(find.text('운행중'), findsOneWidget);
    expect(find.text('충전중'), findsOneWidget);
    expect(find.text('고장'), findsOneWidget);

    // Verify exactly one "1" is shown as the count
    expect(find.text('1'), findsOneWidget);
  });
}
