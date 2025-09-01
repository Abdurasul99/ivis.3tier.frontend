import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/view/pages/login_find_id_page.dart';

/// Stub controller that lets every API call succeed or fail on demand.
class FakeUserController extends UserController {
  FakeUserController({this.willSendOk = true, this.willVerifyOk = true});

  final bool willSendOk;
  final bool willVerifyOk;

  @override
  Future<bool> reqFindIdSendCode(String name, String email) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return willSendOk;
  }

  @override
  Future<bool> reqFindIdVerifyCode(String email, String code) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return willVerifyOk;
  }
}

void main() {
  setUp(() => Get.testMode = true);

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  Widget _app(UserController ctrl) {
    Get.put<UserController>(ctrl, permanent: true);
    return GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const LoginFindIdPage()),
        GetPage(
          name: '/check-id',
          page: () => const Scaffold(body: Text('CHECK')),
        ),
      ],
    );
  }

  testWidgets('empty tap shows inline-error SnackBar', (tester) async {
    // Arrange
    await tester.pumpWidget(_app(FakeUserController()));

    // Act
    await tester.tap(find.text('인증메일 보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Assert
    expect(find.text('이름과 메일을 입력하세요.'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('send success shows success SnackBar', (tester) async {
    // Arrange
    await tester.pumpWidget(_app(FakeUserController(willSendOk: true)));
    await tester.enterText(find.byType(TextField).at(0), 'Abdurasul');
    await tester.enterText(find.byType(TextField).at(1), 'abdurasul@ivis.ai');
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('인증메일 보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Assert
    expect(find.text('인증메일을 보냈습니다. 메일을 확인해주세요.'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('send failure shows failure SnackBar', (tester) async {
    // Arrange
    await tester.pumpWidget(_app(FakeUserController(willSendOk: false)));
    await tester.enterText(find.byType(TextField).at(0), 'Abdurasul');
    await tester.enterText(find.byType(TextField).at(1), 'abdurasul@ivis.ai');
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('인증메일 보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Assert
    expect(find.text('메일 전송에 실패했습니다.'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('correct code navigates to /check-id', (tester) async {
    // Arrange
    await tester.pumpWidget(
      _app(FakeUserController(willSendOk: true, willVerifyOk: true)),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Abdurasul');
    await tester.enterText(find.byType(TextField).at(1), 'abdurasul@ivis.ai');
    await tester.pumpAndSettle();

    await tester.tap(find.text('인증메일 보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Act
    await tester.enterText(find.byType(TextField).at(2), '123456');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // Assert
    expect(Get.currentRoute, '/check-id');
    expect(find.text('CHECK'), findsOneWidget);
  });
}
