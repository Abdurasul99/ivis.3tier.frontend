// @TestOn('browser')
// test/view/tabs/tab_robot_logviewer_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/view/tabs/tab_robot_logviewer.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';
import 'package:get/get.dart';

/// A stubbed LogController that we can manipulate in-tests.
class StubLogController extends LogController {
  VoidCallback? onFetch;
  bool _loading = false;
  final List<RobotLog> _logs = [];
  final List<bool> _selected = [];

  @override
  bool get isLoading => _loading;

  @override
  List<RobotLog> get robotLogs => _logs;

  @override
  List<bool> get isSelected => _selected;

  /// Helper to populate logs and reset selection.
  void setLogs(List<RobotLog> logs) {
    _logs
      ..clear()
      ..addAll(logs);
    _selected
      ..clear()
      ..addAll(List<bool>.filled(logs.length, false));
    update();
    debugPrint('StubLogController: logs set (${logs.length})');
  }

  @override
  Future<void> reqLogList({String? startDate, String? endDate, String? keyword}) async {
    debugPrint('StubLogController.reqLogList called');
    onFetch?.call();
  }

  @override
  void setViewPage(int page) {
    debugPrint('StubLogController.setViewPage($page)');
    // no-op
  }

  @override
  void setSelectedAll(bool all) {
    for (var i = 0; i < _selected.length; i++) {
      _selected[i] = all;
    }
    update();
    debugPrint('StubLogController.setSelectedAll($all)');
  }

  @override
  void setIsSelected(int index, dynamic value) {
    _selected[index] = value as bool;
    update();
    debugPrint('StubLogController.setIsSelected($index, $value)');
  }
}

void main() {
  late StubLogController stubCtrl;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    stubCtrl = StubLogController();
    // Register our stub as the app’s LogController
    Get.put<LogController>(stubCtrl, permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('shows empty state when no logs', (tester) async {
    // Build with no logs loaded
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TabRobotLogViewer())),
    );
    await tester.pumpAndSettle();

    // Should show the “no logs” message
    expect(find.text('조건에 맞는 로그가 없습니다. 😑'), findsOneWidget);
    debugPrint('Verified empty-state message');
  });

  testWidgets('displays logs and toggles selection', (tester) async {
    // Populate two test logs
    stubCtrl.setLogs([
      RobotLog(createdTs: '2025-01-01 12:00', level: 'INFO', message: 'Test log 1'),
      RobotLog(createdTs: '2025-01-02 13:00', level: 'WARN', message: 'Test log 2'),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TabRobotLogViewer())),
    );
    await tester.pumpAndSettle();

    // Verify timestamps and levels render
    expect(find.text('2025-01-01 12:00'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
    expect(find.text('Test log 2'), findsOneWidget);
    debugPrint('Verified log entries render correctly');

    // Tap “Select All”
    await tester.tap(find.widgetWithText(GradientButton, '전체 선택'));
    await tester.pump();
    // All items should now be selected
    expect(stubCtrl.isSelected.every((e) => e), isTrue);
    debugPrint('Verified 전체 선택 sets all to true');

    // Tap the first individual log-row checkbox (via its SVG icon) to toggle off
    final checkboxFinder = find.ancestor(
      of: find.byType(SvgPicture).first,
      matching: find.byType(GestureDetector),
    );
    expect(checkboxFinder, findsOneWidget, reason: 'Should find exactly one log-row checkbox');
    await tester.tap(checkboxFinder);
    await tester.pump();
    expect(stubCtrl.isSelected[0], isFalse);
    debugPrint('Verified tapping first log-row checkbox toggles selection');
  });

  testWidgets('refresh button calls reqLogList', (tester) async {
    bool called = false;
    stubCtrl.onFetch = () => called = true;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TabRobotLogViewer())),
    );
    await tester.pumpAndSettle();

    // Tap the refresh icon button
    await tester.tap(find.widgetWithIcon(GradientButton, CupertinoIcons.refresh));
    await tester.pump();
    expect(called, isTrue);
    debugPrint('Verified refresh button invokes reqLogList');
  });
}
