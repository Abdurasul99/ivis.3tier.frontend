// test/view/dialogs/password_change_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dialogs/password_change_dialog.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/model/user_model.dart';
import 'package:fms/utils/utils.dart';

/// A fake UserController that overrides only what we need:
///   • `loginUser` getter
///   • `reqChangePassword(...)` behavior
class FakeUserController extends UserController {
  LoginUser? _fakeLoginUser;
  String _nextResult = 'changed password';

  bool wasCalled = false;
  Map<String, dynamic>? lastParams;

  /// Seed both the fake loginUser and what reqChangePassword will return.
  void seedFakeUser({required String email, required String nextResult}) {
    _fakeLoginUser = LoginUser(email: email, accessToken: 'token');
    _nextResult = nextResult;
  }

  @override
  LoginUser? get loginUser => _fakeLoginUser;

  @override
  Future<String> reqChangePassword(Map<String, dynamic> params) async {
    wasCalled = true;
    lastParams = params;
    return _nextResult;
  }
}

void main() {
  late FakeUserController fakeController;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  setUp(() {
    Get.reset();
    fakeController = FakeUserController();
    Get.put<UserController>(fakeController);
  });

  /// Wraps our dialog in a minimal app + button to open it.
  Widget buildTestApp(Widget dialog) {
    return GetMaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              key: const Key('openDialogButton'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => dialog,
              ),
              child: const Text('OPEN_DIALOG'),
            ),
          );
        }),
      ),
    );
  }

  testWidgets(
    'when passwords match and backend returns success, dialog closes and shows success snackbar',
    (WidgetTester tester) async {
      // Wrap in runAsync so real timers (snackbar) fire and clear themselves:
      await tester.runAsync(() async {
        // Arrange: seed controller so that loginUser.email is available
        fakeController.seedFakeUser(
          email: 'test@domain.com',
          nextResult: 'changed password',
        );

        // Pump our test app
        await tester.pumpWidget(buildTestApp(const PasswordChangeDialog()));

        // Open the dialog
        await tester.tap(find.byKey(const Key('openDialogButton')));
        await tester.pumpAndSettle();

        // Sanity check: dialog title present
        expect(find.text('비밀번호 변경'), findsOneWidget);

        // Fill in the three TextFields
        await tester.enterText(find.byType(TextField).at(0), 'oldpass');
        await tester.enterText(find.byType(TextField).at(1), 'newpass123');
        await tester.enterText(find.byType(TextField).at(2), 'newpass123');

        // Tap the confirm button
        await tester.tap(find.widgetWithText(GradientButton, '확 인'));

        // Allow the dialog-close animation (~200ms) and snackbar (~1500ms) to complete
        await tester.pump(); // start the button’s onTap
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 2));

        // Assert: dialog has closed
        expect(find.text('비밀번호 변경'), findsNothing);

        // Assert: snackbar text appears
        expect(find.text('비밀번호가 변경되었습니다.'), findsOneWidget);

        // Assert: that our fake controller was called with correct params
        expect(fakeController.wasCalled, isTrue);
        expect(fakeController.lastParams!['email'], 'test@domain.com');
        expect(fakeController.lastParams!['password'], 'oldpass');
        expect(fakeController.lastParams!['newpassword'], 'newpass123');
      });
    },
  );
}
