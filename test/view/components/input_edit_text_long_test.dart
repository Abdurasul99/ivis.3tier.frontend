// test/view/components/input_edit_text_long_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_long.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('InputEditTextLong Widget Tests', () {
    testWidgets('renders title, asterisk and error text when provided', (WidgetTester tester) async {
      // Arrange
      const title = 'Description';
      const error = 'Too short';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLong(
              title: title,
              isRequired: true,
              errorText: error,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('* '), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text(error), findsOneWidget);
    });

    testWidgets('hides title row when title is empty', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: InputEditTextLong())),
      );
      await tester.pumpAndSettle();

      // Assert: only TextFormField present
      expect(find.text('* '), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('applies bold border and custom borderColor when isBoldBorder is true', (WidgetTester tester) async {
      // Arrange
      const customColor = Colors.purple;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLong(
              isBoldBorder: true,
              borderColor: customColor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find decorated container
      final Finder containerFinder = find.descendant(
        of: find.byType(InputEditTextLong),
        matching: find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final BoxDecoration d = widget.decoration as BoxDecoration;
            return d.border != null && d.border!.top.color == customColor && d.border!.top.width == 2.5;
          }
          return false;
        }),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('uses grey background when isReadOnly is true', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLong(isReadOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder containerFinder = find.descendant(
        of: find.byType(InputEditTextLong),
        matching: find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final BoxDecoration d = widget.decoration as BoxDecoration;
            return d.color == const Color(0xFFE2E2E2);
          }
          return false;
        }),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('displays hintText and uses hintTextColor', (WidgetTester tester) async {
      // Arrange
      const hint = 'Enter description';
      const hintColor = Colors.orange;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLong(
              hintText: hint,
              hintTextColor: hintColor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: hint text style
      final Finder hintFinder = find.text(hint);
      expect(hintFinder, findsOneWidget);
      final Text hintWidget = tester.widget<Text>(hintFinder);
      expect(hintWidget.style!.color, equals(hintColor));
    });

    testWidgets('invokes onChanged when typing', (WidgetTester tester) async {
      // Arrange
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLong(
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextFormField), 'hello');
      await tester.pumpAndSettle();

      // Assert
      expect(changed, equals('hello'));
    });

    testWidgets('invokes onSubmitted when done action is triggered', (WidgetTester tester) async {
      // Arrange
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLong(
              onSubmitted: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'done');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Assert
      expect(submitted, equals('done'));
    });
  });
}
