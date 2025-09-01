// test/view/components/gradient_button_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/gradient_button.dart';

void main() {
  group('GradientButton Widget Tests with Debug', () {
    testWidgets('renders text and default style correctly', (WidgetTester tester) async {
      debugPrint('DEBUG: Test "renders text and default style correctly" START');

      // Arrange: define button parameters
      const String buttonText = 'Press Me';
      bool wasTapped = false;

      // Act: pump the widget into the tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              buttonText: buttonText,
              onTap: () {
                wasTapped = true;
              },
              buttonColor: Colors.white,
            ),
          ),
        ),
      );
      debugPrint('DEBUG: Widget pumped');

      // Assert: find the Text widget
      final Finder textFinder = find.text(buttonText);
      expect(textFinder, findsOneWidget);
      debugPrint('DEBUG: Found text "$buttonText"');

      // Assert: text color should be dark when buttonColor is white
      final Text textWidget = tester.widget<Text>(textFinder);
      final Color actualTextColor = textWidget.style!.color!;
      const Color expectedTextColor = Color(0xFF1B1B1B);
      debugPrint('DEBUG: actualTextColor=$actualTextColor, expected=$expectedTextColor');
      expect(actualTextColor, equals(expectedTextColor));
      debugPrint('DEBUG: Text color is correct for default white buttonColor');

      // Act: tap the button
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      debugPrint('DEBUG: GestureDetector tapped');

      // Assert: callback was invoked
      expect(wasTapped, isTrue);
      debugPrint('DEBUG: onTap callback invoked, wasTapped=$wasTapped');

      debugPrint('DEBUG: Test complete');
    });

    testWidgets('renders icon when provided and text color white for custom buttonColor', (WidgetTester tester) async {
      debugPrint('DEBUG: Test "renders icon when provided and custom buttonColor" START');

      // Arrange
      const String buttonText = 'Icon Test';
      const Color customColor = Colors.blue;
      bool wasTapped = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              buttonText: buttonText,
              onTap: () {
                wasTapped = true;
              },
              buttonColor: customColor,
              icon: Icon(Icons.star),
            ),
          ),
        ),
      );
      debugPrint('DEBUG: Widget with icon pumped');

      // Assert: find the Icon widget
      final Finder iconFinder = find.byIcon(Icons.star);
      expect(iconFinder, findsOneWidget);
      debugPrint('DEBUG: Icon found');

      // Assert: find the Text widget
      final Finder textFinder = find.text(buttonText);
      expect(textFinder, findsOneWidget);
      debugPrint('DEBUG: Found text "$buttonText"');

      // Assert: text color should be white when buttonColor is not white
      final Text textWidget = tester.widget<Text>(textFinder);
      final Color actualTextColor = textWidget.style!.color!;
      const Color expectedTextColor = Colors.white;
      debugPrint('DEBUG: actualTextColor=$actualTextColor, expected=$expectedTextColor');
      expect(actualTextColor, equals(expectedTextColor));
      debugPrint('DEBUG: Text color is correct for custom buttonColor');

      // Act: tap the button
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      debugPrint('DEBUG: GestureDetector tapped');

      // Assert: callback invoked
      expect(wasTapped, isTrue);
      debugPrint('DEBUG: onTap callback invoked, wasTapped=$wasTapped');

      debugPrint('DEBUG: Test complete');
    });
  });
}
