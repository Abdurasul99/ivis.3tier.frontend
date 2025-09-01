// test/view/dialogs/reset_password_code_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Import your dialog
import 'package:fms/view/dialogs/reset_password_code_dialog.dart';

void main() {
  late GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  setUp(() {
    Get.reset();
    scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  });

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
                showDialog<String>(
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

  testWidgets('empty code does not close dialog and returns null', (tester) async {
    String? dialogResult;
    debugPrint('=== Test: empty code does not close dialog ===');

    await tester.pumpWidget(buildTestApp(
      dialog: const ResetPasswordCodeDialog(email: 'user@example.com'),
      onDialogResult: (value) => dialogResult = value,
    ));

    // Open the dialog
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Confirm nothing has returned yet
    expect(dialogResult, isNull);

    // Tap 확인 with empty input
    debugPrint('[Test] Tapping 확인 without code');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog should still be open
    expect(find.byType(ResetPasswordCodeDialog), findsOneWidget);
    debugPrint('[Test] Dialog remains open');
    // No result should have been returned
    expect(dialogResult, isNull);
  });

  testWidgets('entering code returns it and closes dialog', (tester) async {
    String? dialogResult;
    debugPrint('=== Test: valid code returns result and closes ===');

    await tester.pumpWidget(buildTestApp(
      dialog: const ResetPasswordCodeDialog(email: 'user@example.com'),
      onDialogResult: (value) => dialogResult = value,
    ));

    // Open the dialog
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Enter 4-digit code
    debugPrint('[Test] Entering code "1234"');
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();

    // Tap 확인
    debugPrint('[Test] Tapping 확인 with code');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog should close
    expect(find.byType(ResetPasswordCodeDialog), findsNothing);
    debugPrint('[Test] Dialog closed');

    // And callback should have received the code
    expect(dialogResult, equals('1234'));
    debugPrint('[Test] Received code: $dialogResult');
  });
}
