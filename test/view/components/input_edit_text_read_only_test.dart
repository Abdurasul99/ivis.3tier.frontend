// test/view/components/input_edit_text_read_only_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_read_only.dart';

void main() {
  group('InputEditTextReadOnly Widget Tests', () {
    testWidgets('renders title and value when provided', (WidgetTester tester) async {
      // Arrange
      const String title = 'Username';
      const String value = 'John Doe';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextReadOnly(
              title: title,
              value: value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: title is shown
      expect(find.text(title), findsOneWidget);
      // Assert: value is shown
      expect(find.text(value), findsOneWidget);
    });

    testWidgets('hides title row when title is null or empty', (WidgetTester tester) async {
      // Arrange: no title
      const String value = 'Data';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextReadOnly(
              title: null,
              value: value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: no title
      expect(find.text('*'), findsNothing);
      expect(find.text(value), findsOneWidget);
      // Only one Container present for the value
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('applies correct background color and border radius', (WidgetTester tester) async {
      // Arrange: minimal
      const String value = 'Test';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextReadOnly(value: value),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: the value container has grey background & radius 3
      final Finder containerFinder = find
          .descendant(
            of: find.byType(InputEditTextReadOnly),
            matching: find.byType(Container),
          )
          .last;

      final Container container = tester.widget<Container>(containerFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFF5F5F5)));
      expect(decoration.borderRadius, equals(BorderRadius.circular(3.0)));
    });

    testWidgets('value text has correct style', (WidgetTester tester) async {
      // Arrange
      const String value = 'Stylish';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextReadOnly(value: value),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: Text style matches spec
      final Text textWidget = tester.widget<Text>(find.text(value));
      final TextStyle style = textWidget.style!;
      expect(style.fontSize, equals(15));
      expect(style.color, equals(Colors.black));
      expect(style.fontWeight, equals(FontWeight.w400));
    });
  });
}
