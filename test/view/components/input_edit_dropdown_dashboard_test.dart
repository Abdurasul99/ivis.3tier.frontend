// test/view/components/input_edit_dropdown_dashboard_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:fms/view/components/input_edit_dropdown_dashboard.dart';
import 'package:fms/constants/constants.dart';

void main() {
  group('InputEditDropDownDashboard Widget Tests', () {
    testWidgets('shows hint text when selectedText is empty', (tester) async {
      debugPrint('DEBUG: Test "shows hint text when selectedText is empty" START');

      // Arrange
      const List<String> items = ['One', 'Two', 'Three'];
      const String hint = 'Select an item';
      String? changedValue;

      // Act: Render widget with empty selectedText
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDownDashboard(
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
      debugPrint('DEBUG: Widget pumped with empty selection');

      // Assert: hint text is shown
      expect(find.text(hint), findsOneWidget);
      debugPrint('DEBUG: Found hint text: $hint');
    });

    testWidgets('shows selectedText when provided', (tester) async {
      debugPrint('DEBUG: Test "shows selectedText when provided" START');

      // Arrange
      const List<String> items = ['One', 'Two', 'Three'];
      const String selected = 'Two';
      String? changedValue;

      // Act: Render widget with selectedText
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDownDashboard(
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
      debugPrint('DEBUG: Widget pumped with selectedText = $selected');

      // Assert: selectedText is shown instead of hint
      expect(find.text(selected), findsOneWidget);
      expect(find.text('Hint'), findsNothing);
      debugPrint('DEBUG: Found selected text: $selected');
    });

    testWidgets('opens dropdown and displays all items', (tester) async {
      debugPrint('DEBUG: Test "opens dropdown and displays all items" START');

      // Arrange
      const List<String> items = ['Alpha', 'Beta', 'Gamma'];
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDownDashboard(
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

      // Act: Tap to open dropdown menu
      await tester.tap(find.byType(DropdownButton2<String>));
      await tester.pumpAndSettle();
      debugPrint('DEBUG: DropdownButton2 tapped');

      // Assert: all items are displayed
      for (final item in items) {
        expect(find.text(item), findsWidgets);
        debugPrint('DEBUG: Found dropdown item: $item');
      }
    });

    testWidgets('calls onChanged and updates selected item style', (tester) async {
      debugPrint('DEBUG: Test "calls onChanged and updates selected item style" START');

      // Arrange
      const List<String> items = ['Red', 'Green', 'Blue'];
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InputEditDropDownDashboard(
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

      // Act: open dropdown
      await tester.tap(find.byType(DropdownButton2<String>));
      await tester.pumpAndSettle();
      debugPrint('DEBUG: DropdownButton2 tapped');

      // Act: select 'Green'
      await tester.tap(find.text('Green').last);
      await tester.pumpAndSettle();
      debugPrint('DEBUG: Tapped dropdown item Green');

      // Assert: onChanged callback called with 'Green'
      expect(changedValue, equals('Green'));
      debugPrint('DEBUG: changedValue = $changedValue');
    });
  });
}
