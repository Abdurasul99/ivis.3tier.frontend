// test/view/components/input_edit_text_log_viewer_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/input_edit_text_logviewer.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('InputEditTextLogViewer Widget Tests', () {
    testWidgets('applies bold border and custom borderColor when isBoldBorder is true', (WidgetTester tester) async {
      const Color customBorder = Colors.red;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLogViewer(
              isBoldBorder: true,
              borderColor: customBorder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find outer Container
      final Finder containerFinder = find.byType(Container).first;
      final Container containerWidget = tester.widget(containerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;
      final Border border = decoration.border as Border;
      expect(border.top.width, equals(2.5));
      expect(border.top.color, equals(customBorder));
    });

    testWidgets('uses grey background when isReadOnly is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLogViewer(isReadOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder containerFinder = find.byType(Container).first;
      final Container containerWidget = tester.widget(containerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFE2E2E2)));
    });

    testWidgets('displays hintText with correct style', (WidgetTester tester) async {
      const String hint = 'Search logs';
      const Color hintColor = Colors.green;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLogViewer(
              hintText: hint,
              hintTextColor: hintColor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hint appears in TextFormField
      final Finder hintFinder = find.text(hint);
      expect(hintFinder, findsOneWidget);
      final Text hintTextWidget = tester.widget<Text>(hintFinder);
      expect(hintTextWidget.style!.color, equals(hintColor));
    });

    testWidgets('invokes onChanged callback when typing', (WidgetTester tester) async {
      String? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLogViewer(
              onChanged: (v) => changedValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pumpAndSettle();
      expect(changedValue, equals('abc'));
    });

    testWidgets('invokes onSubmitted callback on done action', (WidgetTester tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLogViewer(
              controller: TextEditingController(text: 'done'),
              onSubmitted: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate submission via keyboard done
      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'done');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, equals('done'));
    });

    testWidgets('tapping search icon calls onSubmitted with controller text', (WidgetTester tester) async {
      String? submitted;
      final controller = TextEditingController(text: 'search me');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditTextLogViewer(
              controller: controller,
              onSubmitted: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find GestureDetector around the search icon
      final Finder iconTapFinder = find.widgetWithIcon(GestureDetector, CupertinoIcons.search);
      expect(iconTapFinder, findsOneWidget);

      await tester.tap(iconTapFinder);
      await tester.pumpAndSettle();

      expect(submitted, equals('search me'));
    });
  });
}
