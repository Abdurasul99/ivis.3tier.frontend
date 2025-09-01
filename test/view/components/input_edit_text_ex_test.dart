// test/view/components/input_edit_text_ex_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_ex.dart';

void main() {
  group('InputEditTextEx Widget Tests', () {
    testWidgets('renders title, asterisk and error text when provided', (WidgetTester tester) async {
      // Arrange
      const String title = 'Email';
      const String error = 'Invalid format';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextEx(
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
        MaterialApp(home: Scaffold(body: InputEditTextEx())),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('* '), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('displays hintText with correct style', (WidgetTester tester) async {
      // Arrange
      const String hint = 'Enter value';
      const Color hintColor = Colors.blue;
      const double fontSize = 20.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextEx(
              hintText: hint,
              hintTextColor: hintColor,
              fontSize: fontSize,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: hint text style
      final Finder hintFinder = find.text(hint);
      expect(hintFinder, findsOneWidget);
      final Text hintTextWidget = tester.widget<Text>(hintFinder);
      expect(hintTextWidget.style!.color, equals(hintColor));
      expect(hintTextWidget.style!.fontSize, equals(fontSize));
    });

    testWidgets('invokes onTap callback when tapping the field container', (WidgetTester tester) async {
      // Arrange
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextEx(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate the GestureDetector container
      final Finder gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Calculate a point just inside the container's top-left corner,
      // outside the TextFormField area so the GestureDetector catches it.
      final Rect containerRect = tester.getRect(gestureFinder);
      final Offset tapPoint = containerRect.topLeft + const Offset(4, 4);

      // Act
      await tester.tapAt(tapPoint);
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, isTrue);
    });

    testWidgets('calls onChanged when text is entered', (WidgetTester tester) async {
      // Arrange
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextEx(
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pumpAndSettle();

      // Assert
      expect(changed, equals('abc'));
    });

    testWidgets('calls onSubmitted when done action is triggered', (WidgetTester tester) async {
      // Arrange
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextEx(
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

    testWidgets('applies bold border and custom borderColor when isBoldBorder is true', (WidgetTester tester) async {
      // Arrange
      const Color borderColor = Colors.green;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextEx(
              isBoldBorder: true,
              borderColor: borderColor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: find the Container with correct border
      final Finder containerFinder = find.descendant(
        of: find.byType(InputEditTextEx),
        matching: find.byWidgetPredicate((widget) {
          if (widget is Container && widget.decoration is BoxDecoration) {
            final BoxDecoration d = widget.decoration as BoxDecoration;
            return d.border != null && d.border!.top.color == borderColor && d.border!.top.width == 2.5;
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
            body: InputEditTextEx(isReadOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: container with grey background
      final Finder containerFinder = find.descendant(
        of: find.byType(InputEditTextEx),
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
  });
}
