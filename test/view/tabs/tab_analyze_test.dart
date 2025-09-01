// test/view/tabs/tab_analyze_test.dart

// @TestOn('browser')
import 'package:test/test.dart' show Timeout;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fms/view/tabs/tab_analyze.dart';

void main() {
  group('TabAnalyze widget tests', () {
    testWidgets('displays centered "Analyze" text', (WidgetTester tester) async {
      // ARRANGE: pump TabAnalyze inside a simple app
      await tester.pumpWidget(
        const MaterialApp(home: TabAnalyze()),
      );

      // ACT & ASSERT: verify that the text "Analyze" is present
      final textFinder = find.text('Analyze');
      expect(textFinder, findsOneWidget);

      // ASSERT: the Text widget is a child of Center
      final centerWidget = tester.widget<Center>(find.byType(Center));
      expect(centerWidget.child, isA<Text>());
      expect((centerWidget.child as Text).data, 'Analyze');
    });

    testWidgets('text style is 60 bold', (WidgetTester tester) async {
      // ARRANGE
      await tester.pumpWidget(
        const MaterialApp(home: TabAnalyze()),
      );

      // ACT: locate the Text widget
      final textWidget = tester.widget<Text>(find.text('Analyze'));

      // ASSERT: check fontSize and fontWeight
      final style = textWidget.style!;
      expect(style.fontSize, 60);
      expect(style.fontWeight, FontWeight.bold);
    });
  });
}
