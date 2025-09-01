// test/view/dialogs/reset_password_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Import the dialog under test
import 'package:fms/view/dialogs/reset_password_dialog.dart';

void main() {
  late GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  setUp(() {
    Get.reset();
    scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  });

  /// Helper to build an app that opens the dialog and captures its result.
  Widget buildTestApp({
    required Widget dialog,
    required void Function(String?) onDialogResult,
  }) {
    return GetMaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return Center(
            child: ElevatedButton(
              key: const Key('openDialogButton'),
              onPressed: () {
                debugPrint('[TestApp] OPEN button tapped');
                showDialog<String?>(
                  context: ctx,
                  builder: (_) => dialog,
                ).then((value) {
                  debugPrint('[TestApp] Dialog returned: $value');
                  onDialogResult(value);
                });
              },
              child: const Text('OPEN'),
            ),
          );
        }),
      ),
    );
  }

  testWidgets('empty email does not close dialog and returns null', (WidgetTester tester) async {
    String? dialogResult;
    debugPrint('=== Test: empty email does not close dialog ===');

    await tester.pumpWidget(buildTestApp(
      dialog: const ResetPasswordDialog(),
      onDialogResult: (value) => dialogResult = value,
    ));

    // Open the dialog
    debugPrint('[Test] Tapping OPEN button');
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // No result yet
    expect(dialogResult, isNull);

    // Tap "확인" without entering email
    debugPrint('[Test] Tapping 확인 without email');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog should remain open
    expect(find.byType(ResetPasswordDialog), findsOneWidget);
    debugPrint('[Test] Dialog remains open');
    // No result still
    expect(dialogResult, isNull);
  });

  testWidgets('entering email returns it and closes dialog', (WidgetTester tester) async {
    String? dialogResult;
    debugPrint('=== Test: valid email returns result and closes dialog ===');

    await tester.pumpWidget(buildTestApp(
      dialog: const ResetPasswordDialog(),
      onDialogResult: (value) => dialogResult = value,
    ));

    // Open the dialog
    debugPrint('[Test] Tapping OPEN button');
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Enter an email address
    const String testEmail = 'ctrlcv@ivis.ai';
    debugPrint('[Test] Entering email "$testEmail"');
    await tester.enterText(find.byType(TextField), testEmail);
    await tester.pump();

    // Tap "확인"
    debugPrint('[Test] Tapping 확인 with email');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog should close
    expect(find.byType(ResetPasswordDialog), findsNothing);
    debugPrint('[Test] Dialog closed');

    // Callback should receive the entered email
    expect(dialogResult, equals(testEmail));
    debugPrint('[Test] Received email: $dialogResult');
  });
}
