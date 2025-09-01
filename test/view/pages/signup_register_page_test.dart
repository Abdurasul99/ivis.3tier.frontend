// test/view/pages/signup_register_page_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/signup_register_page.dart';
import 'package:fms/view/pages/signup_page.dart';
import 'package:fms/viewmodel/controller/register_controller.dart';

/// Provide a 1 × 1 stub for any SVG asset request so the test runner
/// never tries to decode real files.
void _stubSvg() {
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>';
  final data = ByteData.view(Uint8List.fromList(utf8.encode(svg)).buffer);
  ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (_) async => data,
  );
}

/* ───────────────────────────────────────── stub controllers ───────────────────────────────────────── */

class RegCtrlFail extends RegisterController {
  @override
  Future<bool> sendRegisterCode(_, __) async => false;

  @override
  Future<bool> verifyRegisterCode(_, __) async => false;
}

class RegCtrlOk extends RegisterController {
  @override
  Future<bool> sendRegisterCode(_, __) async => true;

  @override
  Future<bool> verifyRegisterCode(_, __) async => true;
}

/* ───────────────────────────────────────── test suite ───────────────────────────────────────── */

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _stubSvg();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'validation – empty name highlights border in red only',
    (tester) async {
      // ---------- Arrange ----------
      Get.put<RegisterController>(RegCtrlFail(), permanent: true);

      await tester.pumpWidget(
        GetMaterialApp(home: const SignupRegisterPage()),
      );
      await tester.pumpAndSettle();

      // ---------- Act ----------
      await tester.tap(find.text('인증번호 확인'));
      await tester.pumpAndSettle();

      // ---------- Assert ----------
      final nameField = tester.widget<TextField>(find.byType(TextField).at(0));
      final emailField = tester.widget<TextField>(find.byType(TextField).at(1));

      final nameColor = (nameField.decoration!.enabledBorder as OutlineInputBorder).borderSide.color;
      final emailColor = (emailField.decoration!.enabledBorder as OutlineInputBorder).borderSide.color;

      expect(nameColor, const Color(0xFFC42B1C)); // red
      expect(emailColor, const Color(0xFFB3B3B3)); // grey
    },
  );

  testWidgets(
    'send-code success opens a snackbar',
    (tester) async {
      // ---------- Arrange ----------
      Get.put<RegisterController>(RegCtrlOk(), permanent: true);

      await tester.pumpWidget(
        GetMaterialApp(home: const SignupRegisterPage()),
      );
      await tester.pumpAndSettle();

      // ---------- Act ----------
      await tester.enterText(find.byType(TextField).at(0), 'Abdurasul');
      await tester.enterText(find.byType(TextField).at(1), 'abdurasul@ivis.ai');

      await tester.tap(find.text('인증번호 확인'));
      await tester.pump(); // start animation
      await tester.pump(const Duration(milliseconds: 400)); // end animation

      // ---------- Assert ----------
      expect(Get.isSnackbarOpen, isTrue);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'verify-code routes to SignUpPage on success',
    (tester) async {
      // ---------- Arrange ----------
      Get.put<RegisterController>(RegCtrlOk(), permanent: true);

      await tester.pumpWidget(
        GetMaterialApp(
          defaultTransition: Transition.noTransition,
          initialRoute: SignupRegisterPage.routeName,
          getPages: [
            GetPage(
              name: SignupRegisterPage.routeName,
              page: () => const SignupRegisterPage(),
            ),
            GetPage(
              name: SignUpPage.routeName,
              page: () => const SignUpPage(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // ---------- Act ----------
      await tester.enterText(find.byType(TextField).at(0), 'Abdurasul');
      await tester.enterText(find.byType(TextField).at(1), 'abdurasul@ivis.ai');
      await tester.tap(find.text('인증번호 확인'));
      await tester.pump(); // send-code request

      await tester.enterText(find.byType(TextField).at(2), '123456');
      await tester.tap(find.text('확인').last); // verify button
      await tester.pumpAndSettle();

      // ---------- Assert ----------
      expect(find.byType(SignUpPage), findsOneWidget);
    },
  );
}
