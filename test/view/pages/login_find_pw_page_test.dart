import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/login_find_pw_page.dart';
import 'package:fms/viewmodel/controller/password_controller.dart';
import 'package:fms/model/common_model.dart';

/// Stubbed controller that can toggle success / failure.
class FakePasswordController extends GetxController implements PasswordController {
  String? lastEmail;
  String? lastCode;

  bool sendSucceeds = true;
  bool verifySucceeds = true;

  @override
  String? get resetEmail => lastEmail;
  @override
  String? get resetCode => lastCode;
  @override
  String? get resetToken => verifySucceeds ? 'dummy-token' : null;

  @override
  Future<CommonResponse?> reqResetPassword(String email) async {
    lastEmail = email;
    return CommonResponse(
      code: sendSucceeds ? '0000' : '9999',
      message: '',
      body: <String, dynamic>{},
    );
  }

  @override
  Future<CommonResponse?> reqResetPasswordByIdAndEmail(String id, String email) => reqResetPassword(email);

  @override
  Future<CommonResponse?> reqPasswordVerifyCode(String email, String code) async {
    lastEmail = email;
    lastCode = code;
    return CommonResponse(
      code: verifySucceeds ? '0000' : '9999',
      message: '',
      body: verifySucceeds ? <String, dynamic>{'verifyToken': 'dummy-token'} : <String, dynamic>{},
    );
  }

  @override
  Future<CommonResponse?> reqPasswordVerifyCodeByIdAndEmail(String payload) async {
    return CommonResponse(
      code: verifySucceeds ? '0000' : '9999',
      message: '',
      body: verifySucceeds ? <String, dynamic>{'verifyToken': 'dummy-token'} : <String, dynamic>{},
    );
  }

  @override
  Future<CommonResponse?> reqPasswordComplete(String payload) async =>
      CommonResponse(code: '0000', message: '', body: <String, dynamic>{});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePasswordController fakeCtrl;

  setUp(() {
    Get.testMode = true;
    fakeCtrl = Get.put<PasswordController>(
      FakePasswordController(),
      permanent: true,
    ) as FakePasswordController;
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  Future<void> _pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpWidget(
      GetMaterialApp(
        home: const LoginFindPwPage(),
        getPages: [
          GetPage(
            name: '/reset-pw',
            page: () => const Scaffold(body: Center(child: Text('RESET PW'))),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders labels, inputs and buttons', (tester) async {
    // Arrange
    await _pumpPage(tester);

    // Assert
    expect(find.text('비밀번호 찾기'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('인증메일 보내기'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('empty fields on send shows error SnackBar', (tester) async {
    // Arrange
    await _pumpPage(tester);

    // Act
    await tester.tap(find.text('인증메일 보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Assert
    expect(find.text('아이디와 메일을 입력하세요.'), findsOneWidget);
    expect(fakeCtrl.lastEmail, isNull);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('successful send-code shows success SnackBar', (tester) async {
    // Arrange
    fakeCtrl.sendSucceeds = true;
    await _pumpPage(tester);
    await tester.enterText(find.byType(TextField).at(0), 'myid');
    await tester.enterText(find.byType(TextField).at(1), 'me@domain.com');
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('인증메일 보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Assert
    expect(fakeCtrl.lastEmail, 'me@domain.com');
    expect(find.text('인증메일을 보냈습니다. 메일을 확인해주세요.'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('empty code on confirm shows inline error', (tester) async {
    // Arrange
    await _pumpPage(tester);

    // Act
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('인증번호를 입력하세요.'), findsOneWidget);
  });

  testWidgets('valid code navigates to /reset-pw', (tester) async {
    // Arrange
    fakeCtrl.verifySucceeds = true;
    await _pumpPage(tester);
    await tester.enterText(find.byType(TextField).at(1), 'me@domain.com');
    await tester.enterText(find.byType(TextField).at(2), '1234');
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Assert
    expect(Get.currentRoute, '/reset-pw');
    expect(find.text('RESET PW'), findsOneWidget);
  });
}
