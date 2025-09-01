// test/view/dialogs/noti_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dialogs/noti_dialog.dart';
import 'package:fms/view/components/gradient_button.dart';

void main() {
  /// Hosts the dialog behind a button so that Get.back() works correctly.
  Widget buildTestApp(Widget dialogToShow) {
    return GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => dialogToShow,
                  );
                },
                child: const Text('OPEN_DIALOG'),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets(
    'when only primary message is provided, the dialog shows that text and an OK button, and closes on OK tap',
    (WidgetTester tester) async {
      // Arrange
      const String primaryText = 'Primary only message';

      await tester.pumpWidget(buildTestApp(const NotiDialog(
        message: primaryText,
        addMessage: null,
      )));

      // Act: Open the dialog
      await tester.tap(find.text('OPEN_DIALOG'));
      await tester.pumpAndSettle();

      // Assert: the primary text is displayed
      expect(find.text(primaryText), findsOneWidget);

      // Assert: there is exactly one OK button
      expect(find.widgetWithText(GradientButton, '확인'), findsOneWidget);

      // Act: Tap the OK button
      await tester.tap(find.widgetWithText(GradientButton, '확인'));
      await tester.pumpAndSettle();

      // Assert: dialog has closed (primary text no longer on screen)
      expect(find.text(primaryText), findsNothing);
    },
  );

  testWidgets(
    'when both primary and additional messages are provided, both appear',
    (WidgetTester tester) async {
      // Arrange
      const String primaryText = 'Primary message';
      const String secondaryText = 'Additional details';

      await tester.pumpWidget(buildTestApp(const NotiDialog(
        message: primaryText,
        addMessage: secondaryText,
      )));

      // Act: open the dialog
      await tester.tap(find.text('OPEN_DIALOG'));
      await tester.pumpAndSettle();

      // Assert: both messages are shown
      expect(find.text(primaryText), findsOneWidget);
      expect(find.text(secondaryText), findsOneWidget);

      // Assert: OK button is present
      expect(find.widgetWithText(GradientButton, '확인'), findsOneWidget);

      // Clean up: close the dialog
      await tester.tap(find.widgetWithText(GradientButton, '확인'));
      await tester.pumpAndSettle();
    },
  );
}
