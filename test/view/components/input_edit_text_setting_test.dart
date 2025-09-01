// test/view/components/input_edit_text_setting_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_setting.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('InputEditTextSetting Widget Tests', () {
    testWidgets('renders title with required asterisk when isRequired is true', (WidgetTester tester) async {
      const title = 'API Key';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextSetting(
              title: title,
              isRequired: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('* '), findsOneWidget);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('hides title row when title is empty or null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InputEditTextSetting()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('* '), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('applies bold border and custom color when isBoldBorder is true', (WidgetTester tester) async {
      const borderColor = Colors.blue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextSetting(
              isBoldBorder: true,
              borderColor: borderColor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = find.descendant(
        of: find.byType(InputEditTextSetting),
        matching: find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final d = w.decoration as BoxDecoration;
            return d.border != null && d.border!.top.width == 2.5 && d.border!.top.color == borderColor;
          }
          return false;
        }),
      );
      expect(container, findsOneWidget);
    });

    testWidgets('uses grey background when isReadOnly is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InputEditTextSetting(isReadOnly: true)),
        ),
      );
      await tester.pumpAndSettle();

      final container = find.descendant(
        of: find.byType(InputEditTextSetting),
        matching: find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            return (w.decoration as BoxDecoration).color == const Color(0xFFE2E2E2);
          }
          return false;
        }),
      );
      expect(container, findsOneWidget);
    });

    testWidgets('displays hintText with correct style', (WidgetTester tester) async {
      const hint = 'Enter value';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextSetting(
              hintText: hint,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hintFinder = find.text(hint);
      expect(hintFinder, findsOneWidget);
      final Text hintWidget = tester.widget<Text>(hintFinder);
      final style = hintWidget.style!;
      expect(style.fontSize, 15);
      expect(style.color, kDarkGrayColor);
      expect(style.fontWeight, FontWeight.w300);
    });

    testWidgets('invokes onChanged callback when typing', (WidgetTester tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextSetting(
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'hello');
      await tester.pumpAndSettle();
      expect(changed, 'hello');
    });

    testWidgets('invokes onSubmitted callback on done action', (WidgetTester tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextSetting(
              onSubmitted: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'done');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, 'done');
    });
  });
}
