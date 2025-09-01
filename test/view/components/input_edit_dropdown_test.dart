// test/view/components/input_edit_dropdown_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:fms/view/components/input_edit_dropdown.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('InputEditDropDown Widget Tests with Debug', () {
    testWidgets('displays hint text when nothing is selected', (WidgetTester tester) async {
      debugPrint('DEBUG: Test "displays hint text when nothing is selected" START');

      // Arrange
      const items = ['A', 'B', 'C'];
      const hint = 'Choose';
      String? changedValue;

      // Act: pump widget with empty selectedText
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDown(
              hintText: hint,
              items: items,
              selectedText: '',
              onChanged: (value) {
                changedValue = value;
                debugPrint('DEBUG: onChanged called with $value');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('DEBUG: Widget pumped with empty selectedText');

      // Assert: hint is shown
      expect(find.text(hint), findsOneWidget);
      debugPrint('DEBUG: Found hint text: $hint');
    });

    testWidgets('displays selectedText when provided', (WidgetTester tester) async {
      debugPrint('DEBUG: Test "displays selectedText when provided" START');

      // Arrange
      const items = ['X', 'Y', 'Z'];
      const selected = 'Y';
      String? changedValue;

      // Act: pump widget with selectedText
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDown(
              hintText: 'Hint',
              items: items,
              selectedText: selected,
              onChanged: (value) {
                changedValue = value;
                debugPrint('DEBUG: onChanged called with $value');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('DEBUG: Widget pumped with selectedText=$selected');

      // Assert: selectedText visible, hint hidden
      expect(find.text(selected), findsOneWidget);
      expect(find.text('Hint'), findsNothing);
      debugPrint('DEBUG: Found selected text: $selected');
    });

    testWidgets('opens dropdown and shows all menu items', (WidgetTester tester) async {
      debugPrint('DEBUG: Test "opens dropdown and shows all menu items" START');

      // Arrange
      const items = ['One', 'Two', 'Three'];
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDown(
              hintText: 'Pick',
              items: items,
              selectedText: '',
              onChanged: (value) {
                changedValue = value;
                debugPrint('DEBUG: onChanged called with $value');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: tap on DropdownButton2 to open menu
      await tester.tap(find.byType(DropdownButton2<String>));
      await tester.pumpAndSettle();
      debugPrint('DEBUG: DropdownButton2 tapped');

      // Assert: each item appears in menu
      for (final item in items) {
        expect(find.text(item), findsWidgets);
        debugPrint('DEBUG: Found dropdown item: $item');
      }
    });

    testWidgets('calls onChanged and updates selection', (WidgetTester tester) async {
      debugPrint('DEBUG: Test "calls onChanged and updates selection" START');

      // Arrange
      const items = ['Red', 'Green', 'Blue'];
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDown(
              hintText: 'Color',
              items: items,
              selectedText: '',
              onChanged: (value) {
                changedValue = value;
                debugPrint('DEBUG: onChanged called with $value');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: open menu
      await tester.tap(find.byType(DropdownButton2<String>));
      await tester.pumpAndSettle();
      debugPrint('DEBUG: Dropdown opened');

      // Act: select 'Green'
      await tester.tap(find.text('Green').last);
      await tester.pumpAndSettle();
      debugPrint('DEBUG: Tapped menu item green');

      // Assert: onChanged callback invoked with correct value
      expect(changedValue, equals('Green'));
      debugPrint('DEBUG: changedValue=$changedValue');
    });
  });
}
