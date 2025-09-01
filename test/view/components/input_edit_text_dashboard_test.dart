// test/view/components/input_edit_text_dashboard_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_dashboard.dart';

void main() {
  group('InputEditTextDashboard Widget Tests', () {
    testWidgets('renders title and required asterisk when isRequired is true', (WidgetTester tester) async {
      // Arrange: Title with required indicator
      const String fieldTitle = 'Username';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextDashboard(
              title: fieldTitle,
              isRequired: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: Asterisk and title are present
      expect(find.text('* '), findsOneWidget);
      expect(find.text(fieldTitle), findsOneWidget);
    });

    testWidgets('does not render title row when title is null or empty', (WidgetTester tester) async {
      // Arrange: No title provided
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InputEditTextDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: No asterisk or title, but TextFormField exists
      expect(find.text('* '), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('displays hintText as placeholder when provided', (WidgetTester tester) async {
      // Arrange: Provide hint text
      const String hint = 'Enter your name';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextDashboard(
              hintText: hint,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: Hint text is visible in the widget tree
      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('invokes onChanged callback when typing', (WidgetTester tester) async {
      // Arrange: Track changed value
      String? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextDashboard(
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: Input text into the field
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pumpAndSettle();

      // Assert: Callback received the text
      expect(changedValue, equals('abc'));
    });

    testWidgets('invokes onSubmitted callback on submission', (WidgetTester tester) async {
      // Arrange: Track submitted value
      String? submittedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextDashboard(
              onSubmitted: (value) => submittedValue = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: Simulate user submission
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      tester.testTextInput.enterText('hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Assert: Submission callback received the text
      expect(submittedValue, equals('hello'));
    });

    testWidgets('renders bold border when isBoldBorder=true', (WidgetTester tester) async {
      // Arrange: Bold border property
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextDashboard(isBoldBorder: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: The container wrapping the TextFormField has a thicker border
      // Find any Container with BoxDecoration that has a border width != 1.0
      final Finder containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null &&
            (widget.decoration as BoxDecoration).border!.top.width == 2.5,
      );
      expect(containerFinder, findsOneWidget);
      final Container container = tester.widget<Container>(containerFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      final Border border = decoration.border as Border;
      expect(border.top.width, equals(2.5));
    });
  });
}
