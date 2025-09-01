// test/view/components/page_nation_view_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/view/components/page_nation_view.dart';

void main() {
  group('PageNationView Widget Tests', () {
    testWidgets('initializes page number to viewPage + 1', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageNationView(viewPage: 2, maxPage: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('first and prev arrows are disabled on first page', (WidgetTester tester) async {
      int? callbackValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageNationView(
              viewPage: 0,
              maxPage: 3,
              onViewPageChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstArrow = find.byIcon(Icons.keyboard_double_arrow_left);
      final prevArrow = find.byIcon(Icons.keyboard_arrow_left);

      expect((tester.widget<Icon>(firstArrow)).color, equals(Colors.grey));
      expect((tester.widget<Icon>(prevArrow)).color, equals(Colors.grey));

      await tester.tap(firstArrow);
      await tester.tap(prevArrow);
      await tester.pumpAndSettle();

      expect(callbackValue, isNull);
    });

    testWidgets('next arrow is disabled on last page', (WidgetTester tester) async {
      int? callbackValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageNationView(
              viewPage: 4,
              maxPage: 5,
              onViewPageChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextArrow = find.byIcon(Icons.keyboard_arrow_right);
      expect((tester.widget<Icon>(nextArrow)).color, equals(Colors.grey));

      await tester.tap(nextArrow);
      await tester.pumpAndSettle();
      expect(callbackValue, isNull);
    });

    testWidgets('last arrow still triggers callback on last page', (WidgetTester tester) async {
      int? callbackValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageNationView(
              viewPage: 4,
              maxPage: 5,
              onViewPageChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lastArrow = find.byIcon(Icons.keyboard_double_arrow_right);
      // Icon remains grey on last page
      expect((tester.widget<Icon>(lastArrow)).color, equals(Colors.grey));

      await tester.tap(lastArrow);
      await tester.pumpAndSettle();
      // Tapping still invokes callback with the last index (4)
      expect(callbackValue, equals(4));
    });

    testWidgets('page navigation arrows change pages correctly', (WidgetTester tester) async {
      final calls = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageNationView(
              viewPage: 2,
              maxPage: 5,
              onViewPageChanged: calls.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First → 0
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left));
      await tester.pumpAndSettle();
      expect(calls.removeAt(0), equals(0));
      // Prev → 1
      await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
      await tester.pumpAndSettle();
      expect(calls.removeAt(0), equals(1));
      // Next → 3
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
      await tester.pumpAndSettle();
      expect(calls.removeAt(0), equals(3));
      // Last → 4
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right));
      await tester.pumpAndSettle();
      expect(calls.removeAt(0), equals(4));
    });

    testWidgets('tapping a page index button invokes callback', (WidgetTester tester) async {
      final calls = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageNationView(
              viewPage: 0,
              maxPage: 5,
              onViewPageChanged: calls.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(calls.single, equals(3));
    });
  });
}
