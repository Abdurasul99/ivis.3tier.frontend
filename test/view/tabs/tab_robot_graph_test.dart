// @TestOn('browser')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fms/view/tabs/tab_robot_graph.dart';
import 'package:fms/view/components/chart_view.dart';

void main() {
  testWidgets('TabRobotGraph displays three ChartView widgets with correct types', (tester) async {
    // Log start of test
    debugPrint('Pumping TabRobotGraph widget');

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const TabRobotGraph(),
        ),
      ),
    );
    // Wait for animations / layout
    await tester.pumpAndSettle();
    debugPrint('Widget tree built');

    // Find all ChartView instances
    final chartFinder = find.byType(ChartView);
    expect(chartFinder, findsNWidgets(3), reason: 'There should be exactly 3 ChartView widgets');
    debugPrint('Found ${tester.widgetList(chartFinder).length} ChartView widgets');

    // Extract their `type` property
    final chartWidgets = tester.widgetList<ChartView>(chartFinder).toList();
    for (var i = 0; i < chartWidgets.length; i++) {
      debugPrint('ChartView #$i has type: ${chartWidgets[i].type}');
    }

    // Assert each one has the expected type
    expect(chartWidgets[0].type, 'distance', reason: 'First chart should be distance');
    expect(chartWidgets[1].type, 'time', reason: 'Second chart should be time');
    expect(chartWidgets[2].type, 'battery', reason: 'Third chart should be battery');
    debugPrint('All ChartView types are correct');
  });
}
