// test/view/components/input_edit_text_underline_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_underline.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('InputEditTextUnderline Widget Tests', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    testWidgets('applies bottom border and background color', (WidgetTester tester) async {
      const bgColor = Colors.yellow;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextUnderline(
              textController: controller,
              focusNode: focusNode,
              backgroundColor: bgColor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          final bs = dec.border?.bottom;
          return dec.color == bgColor && bs != null && bs.color == kDarkGrayColor && bs.width == 1.0;
        }
        return false;
      });
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('displays left icon when icon provided', (WidgetTester tester) async {
      const testIcon = Icon(Icons.add);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextUnderline(
              textController: controller,
              focusNode: focusNode,
              icon: testIcon,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('displays right icon and invokes tap callback', (WidgetTester tester) async {
      bool tapped = false;
      const rightIcon = Icon(Icons.clear);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextUnderline(
              textController: controller,
              focusNode: focusNode,
              iconOnRight: rightIcon,
              onTapRightIcon: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.widgetWithIcon(GestureDetector, Icons.clear);
      expect(iconFinder, findsOneWidget);
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('displays hintText and invokes onChanged and onSubmit', (WidgetTester tester) async {
      const hint = 'Search';
      String? changed;
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextUnderline(
              textController: controller,
              focusNode: focusNode,
              hintText: hint,
              onChanged: (v) => changed = v,
              onSubmit: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(hint), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'hello');
      await tester.pumpAndSettle();
      expect(changed, equals('hello'));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, equals('hello'));
    });

    testWidgets('inputFormatters are applied', (WidgetTester tester) async {
      final formatter = FilteringTextInputFormatter.digitsOnly;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextUnderline(
              textController: controller,
              focusNode: focusNode,
              textInputFormatter: [formatter],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'abc123');
      await tester.pumpAndSettle();

      expect(controller.text, equals('123'));
    });
  });
}
