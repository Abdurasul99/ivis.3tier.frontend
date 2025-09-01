// test/view/components/text_title_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/text_title.dart';

void main() {
  group('TextTitle Widget Tests', () {
    testWidgets('renders text with default parameters', (WidgetTester tester) async {
      const String testText = 'Hello World';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const TextTitle(titleText: testText),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Text widget
      final textFinder = find.text(testText);
      expect(textFinder, findsOneWidget);
      final Text textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
      expect(textWidget.maxLines, equals(1));

      // Verify default style
      final TextStyle style = textWidget.style!;
      expect(style.fontSize, equals(20));
      expect(style.height, equals(1.2));
      expect(style.color, equals(const Color(0xFF363636)));
      expect(style.fontWeight, equals(FontWeight.w500));
      expect(style.fontFamily, equals('s-dream'));

      // Verify Container parameters
      final containerFinder = find
          .descendant(
            of: find.byType(TextTitle),
            matching: find.byType(Container),
          )
          .first;
      final Container containerWidget = tester.widget<Container>(containerFinder);
      expect(containerWidget.constraints?.minHeight, equals(28));
      expect(containerWidget.alignment, equals(Alignment.centerLeft));
      expect(
        containerWidget.padding,
        equals(const EdgeInsets.symmetric(horizontal: 16)),
      );
    });

    testWidgets('applies custom parameters correctly', (WidgetTester tester) async {
      const String testText = 'Custom';
      const double customHeight = 50;
      const double customFontSize = 30;
      const FontWeight customWeight = FontWeight.w700;
      const Color customColor = Colors.red;
      const String customFamily = 'Roboto';
      const EdgeInsets customPadding = EdgeInsets.only(left: 8, right: 24);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextTitle(
              titleText: testText,
              cellHeight: customHeight,
              fontSize: customFontSize,
              fontWeight: customWeight,
              fontColor: customColor,
              fontFamily: customFamily,
              padding: customPadding,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Text widget
      final textWidget = tester.widget<Text>(find.text(testText));
      final style = textWidget.style!;
      expect(style.fontSize, equals(customFontSize));
      expect(style.color, equals(customColor));
      expect(style.fontWeight, equals(customWeight));
      expect(style.fontFamily, equals(customFamily));

      // Verify Container parameters
      final containerWidget = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TextTitle),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(containerWidget.constraints?.minHeight, equals(customHeight));
      expect(containerWidget.padding, equals(customPadding));
    });
  });
}
