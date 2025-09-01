import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/login_reset_pw_page.dart';
import 'package:fms/viewmodel/controller/password_controller.dart';
import 'package:fms/model/common_model.dart';

/// Fake controller: password reset succeeds only for `ValidPassword1!`.
class StubPasswordController extends PasswordController {
  @override
  Future<CommonResponse?> reqPasswordComplete(String pw) async => CommonResponse(
        code: pw == 'ValidPassword1!' ? '0000' : '0001',
        message: pw == 'ValidPassword1!' ? 'Success' : 'Failed',
        additionalMessage: '',
        responseTime: '',
        body: null,
      );
}

void main() {
  /* ───────── helpers ───────── */

  /// Builds the widget tree with a fresh GetX scope and the stub controller.
  Future<void> _pumpApp(WidgetTester tester) async {
    debugPrint('⏱  Arrange: _pumpApp → reset Get & inject stub');

    Get.reset();
    Get.testMode = true; // disables SnackBar animations/tickers
    Get.put<PasswordController>(StubPasswordController(), permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: LoginResetPwPage.routeName,
        getPages: [
          GetPage(
            name: LoginResetPwPage.routeName,
            page: () => const LoginResetPwPage(),
          ),
          GetPage(
            name: '/reset-final',
            page: () => const Scaffold(body: Text('Final page')),
          ),
        ],
      ),
    );
    await tester.pump(); // first frame
  }

  /// Waits for the SnackBar and asserts that the given message is present.
  Future<void> _expectSnack(WidgetTester t, String msg) async {
    await t.pump(const Duration(milliseconds: 100)); // overlay delay
    debugPrint('✅  Assert: SnackBar should contain → "$msg"');
    expect(find.text(msg), findsWidgets); // GetX draws title + body
    Get.closeAllSnackbars();
    await t.pump();
  }

  /* ───────── global cleanup ───────── */

  tearDown(() {
    debugPrint('🧹  tearDown: reset Get & close SnackBars');
    Get.closeAllSnackbars();
    Get.reset();
    Get.clearRouteTree();
    Get.testMode = false;
  });

  /* ───────── tests ───────── */

  testWidgets('shows error when password fields are empty', (tester) async {
    // Arrange
    await _pumpApp(tester);

    // Act
    debugPrint('👉  Act: tap "확인" with empty fields');
    await tester.tap(find.text('확인'));

    // Assert
    await _expectSnack(tester, '비밀번호를 입력하세요.');
  });

  testWidgets('shows error when passwords do not match', (tester) async {
    // Arrange
    await _pumpApp(tester);

    // Act
    debugPrint('👉  Act: enter mismatching passwords and tap "확인"');
    await tester.enterText(find.byType(TextField).at(0), 'Password1!');
    await tester.enterText(find.byType(TextField).at(1), 'Different!');
    await tester.tap(find.text('확인'));

    // Assert
    await _expectSnack(tester, '비밀번호가 서로 일치하지 않습니다.');
  });

  testWidgets('shows error when password fails regex validation', (tester) async {
    // Arrange
    await _pumpApp(tester);

    // Act
    debugPrint('👉  Act: enter invalid (too short) password and tap "확인"');
    await tester.enterText(find.byType(TextField).at(0), 'short');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.tap(find.text('확인'));

    // Assert
    await _expectSnack(
      tester,
      '비밀번호는 영문, 숫자, 특수문자를 포함해 8~16자로 입력해주세요.',
    );
  });

  testWidgets('navigates to /reset-final on successful reset', (tester) async {
    // Arrange
    await _pumpApp(tester);

    // Act
    debugPrint('👉  Act: enter valid password twice and tap "확인"');
    await tester.enterText(find.byType(TextField).at(0), 'ValidPassword1!');
    await tester.enterText(find.byType(TextField).at(1), 'ValidPassword1!');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Assert
    debugPrint('✅  Assert: "Final page" should be visible');
    expect(find.text('Final page'), findsOneWidget);
  });
}
