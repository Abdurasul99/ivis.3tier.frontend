// test/view/components/custom_menu_item_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/custom_menu_item.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('CustomMenuItem (tablet layout) tests', () {
    testWidgets('does not render an Icon when icon is null', (WidgetTester tester) async {
      // Arrange: build widget with no icon
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMenuItem(
              icon: null,
              menuText: 'NoIcon',
              onPressMenu: () {},
              onHover: (hovered) {},
            ),
          ),
        ),
      );

      // Assert: no Icon widgets are present
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders icon and text with default (unselected, non-hover) style', (WidgetTester tester) async {
      // Arrange: build widget with icon and menuText
      const String label = 'Home';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMenuItem(
              icon: Icons.home,
              menuText: label,
              isSelected: false,
              isOnHover: false,
              onPressMenu: () {},
              onHover: (hovered) {},
            ),
          ),
        ),
      );

      // Act: find the Icon and Text
      final Finder iconFinder = find.byType(Icon);
      final Finder textFinder = find.text(label);

      // Assert: Icon is displayed with grey color
      expect(iconFinder, findsOneWidget);
      final Icon iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, equals(Colors.grey));

      // Assert: Text is displayed with grey color and FontWeight.w400
      expect(textFinder, findsOneWidget);
      final Text textWidget = tester.widget<Text>(textFinder);
      final TextStyle style = textWidget.style!;
      expect(style.color, equals(Colors.grey));
      expect(style.fontWeight, equals(FontWeight.w400));
      expect(style.decoration, equals(TextDecoration.none));
    });

    testWidgets('renders selected style when isSelected is true', (WidgetTester tester) async {
      // Arrange: build widget with selected = true
      const String label = 'Selected';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMenuItem(
              icon: Icons.check,
              menuText: label,
              isSelected: true,
              isOnHover: false,
              onPressMenu: () {},
              onHover: (hovered) {},
            ),
          ),
        ),
      );

      // Act: find Icon and Text
      final Icon iconWidget = tester.widget<Icon>(find.byType(Icon));
      final Text textWidget = tester.widget<Text>(find.text(label));
      final TextStyle style = textWidget.style!;

      // Assert: both Icon and Text are white, Text is bold
      expect(iconWidget.color, equals(Colors.white));
      expect(style.color, equals(Colors.white));
      expect(style.fontWeight, equals(FontWeight.w700));
    });

    testWidgets('renders hover style when isOnHover is true', (WidgetTester tester) async {
      // Arrange: build widget with hover = true
      const String label = 'Hover';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMenuItem(
              icon: Icons.star,
              menuText: label,
              isSelected: false,
              isOnHover: true,
              onPressMenu: () {},
              onHover: (hovered) {},
            ),
          ),
        ),
      );

      // Act: find Icon and Text
      final Icon iconWidget = tester.widget<Icon>(find.byType(Icon));
      final Text textWidget = tester.widget<Text>(find.text(label));
      final TextStyle style = textWidget.style!;

      // Assert: Icon and Text use hover color, Text is underlined
      expect(iconWidget.color, equals(kHoverColor));
      expect(style.color, equals(kHoverColor));
      expect(style.decoration, equals(TextDecoration.underline));
      expect(style.decorationColor, equals(Colors.white));
    });

    testWidgets('invokes onPressMenu callback when tapped', (WidgetTester tester) async {
      // Arrange: flag to track callback invocation
      bool wasPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMenuItem(
              icon: Icons.touch_app,
              menuText: 'TapMe',
              onPressMenu: () {
                wasPressed = true;
              },
              onHover: (hovered) {},
            ),
          ),
        ),
      );

      // Act: tap the InkWell
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Assert: callback was invoked
      expect(wasPressed, isTrue);
    });

    testWidgets('invokes onHover callback when hover event is invoked', (WidgetTester tester) async {
      // Arrange: flag to track hover callback
      bool hoveredState = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMenuItem(
              icon: Icons.mouse,
              menuText: 'HoverMe',
              onPressMenu: () {},
              onHover: (hovered) {
                hoveredState = hovered;
              },
            ),
          ),
        ),
      );

      // Act: retrieve the InkWell and manually invoke onHover
      final InkWell inkWell = tester.widget<InkWell>(find.byType(InkWell));
      inkWell.onHover!(true);
      expect(hoveredState, isTrue);
      inkWell.onHover!(false);
      expect(hoveredState, isFalse);
    });
  });
}
