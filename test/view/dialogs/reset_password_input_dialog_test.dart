// test/view/dialogs/reset_password_input_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Import the dialog under test
import 'package:fms/view/dialogs/reset_password_input_dialog.dart';

void main() {
  late GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  setUp(() {
    Get.reset();
    scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  });

  /// Helper to launch the dialog and capture its result
  Widget buildTestApp(void Function(String?) onDialogResult) {
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
                  builder: (_) => const ResetPasswordInputDialog(),
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

  /// Finds a TextField by its hint text in decoration.
  Finder findFieldByHint(String hint) {
    return find.byWidgetPredicate((widget) {
      if (widget is TextField) {
        final decoration = widget.decoration;
        return decoration != null && decoration.hintText == hint;
      }
      return false;
    });
  }

  testWidgets('empty password shows error and remains open', (tester) async {
    String? result;
    debugPrint('=== empty password remains open ===');

    await tester.pumpWidget(buildTestApp((v) => result = v));

    // Open dialog
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Tap 확인 immediately
    debugPrint('[Test] Tapping 확인 with empty fields');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog should still be visible
    expect(find.byType(ResetPasswordInputDialog), findsOneWidget);
    debugPrint('[Test] Dialog still open');
    expect(result, isNull);
  });

  testWidgets('empty confirm shows error and remains open', (tester) async {
    String? result;
    debugPrint('=== empty confirm remains open ===');

    await tester.pumpWidget(buildTestApp((v) => result = v));

    // Open dialog
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Enter password only
    const password = 'password123';
    debugPrint('[Test] Entering password "$password"');
    await tester.enterText(findFieldByHint('password'), password);
    await tester.pump();

    // Tap 확인
    debugPrint('[Test] Tapping 확인 with empty confirm');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog still open
    expect(find.byType(ResetPasswordInputDialog), findsOneWidget);
    expect(result, isNull);
    debugPrint('[Test] Dialog still open');
  });

  testWidgets('mismatched passwords remains open', (tester) async {
    String? result;
    debugPrint('=== mismatched passwords remains open ===');

    await tester.pumpWidget(buildTestApp((v) => result = v));

    // Open dialog
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Enter password
    const password = 'password123';
    debugPrint('[Test] Entering password "$password"');
    await tester.enterText(findFieldByHint('password'), password);
    await tester.pump();

    // Enter non-matching confirm
    const confirm = 'different';
    debugPrint('[Test] Entering confirm "$confirm"');
    await tester.enterText(findFieldByHint('Confirm password'), confirm);
    await tester.pump();

    // Tap 확인
    debugPrint('[Test] Tapping 확인 with mismatch');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog still open
    expect(find.byType(ResetPasswordInputDialog), findsOneWidget);
    expect(result, isNull);
    debugPrint('[Test] Dialog still open');
  });

  testWidgets('matching passwords returns result and closes', (tester) async {
    String? result;
    debugPrint('=== matching passwords returns and closes ===');

    await tester.pumpWidget(buildTestApp((v) => result = v));

    // Open dialog
    await tester.tap(find.byKey(const Key('openDialogButton')));
    await tester.pumpAndSettle();

    // Enter password
    const password = 'securePass!';
    debugPrint('[Test] Entering password "$password"');
    await tester.enterText(findFieldByHint('password'), password);
    await tester.pump();

    // Enter matching confirm
    debugPrint('[Test] Entering confirm "$password"');
    await tester.enterText(findFieldByHint('Confirm password'), password);
    await tester.pump();

    // Tap 확인
    debugPrint('[Test] Tapping 확인 with matching passwords');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Dialog closed
    expect(find.byType(ResetPasswordInputDialog), findsNothing);
    expect(result, equals(password));
    debugPrint('[Test] Dialog closed with result: $result');
  });
}
