import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/signup_page.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';

/// Replace any SVG asset request with a 1 × 1 empty stub; keeps tests fast.
void _stubSvgAsset() {
  const fakeSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>';
  final data = ByteData.view(Uint8List.fromList(utf8.encode(fakeSvg)).buffer);
  ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (_) async => data,
  );
}

/// Minimal fake controller; always “succeeds”.
class FakeUserController extends UserController {
  @override
  Future<bool> reqSignUpByIdAndEmail(
    String id,
    String email,
    String name,
    String phone,
    String password,
  ) async =>
      true;
}

void main() {
  setUp(() {
    _stubSvgAsset();
    Get.reset();
    Get.put<FakeUserController>(FakeUserController());
  });

  testWidgets('empty fields show all validation errors', (tester) async {
    // ---------- Arrange ----------
    await tester.pumpWidget(
      GetMaterialApp(
        home: const SignUpPage(),
        initialBinding: BindingsBuilder(
          () => Get.put<FakeUserController>(FakeUserController()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ---------- Act ----------
    final Finder confirmBtn = find.widgetWithText(ElevatedButton, '확인'); // “Confirm” button
    expect(confirmBtn, findsOneWidget);

    // scroll down so the button is visible on small test surfaces
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // ---------- Assert ----------
    expect(find.text('사용이 불가능한 아이디입니다.'), findsOneWidget);
    expect(find.text('사용이 불가능한 비밀번호입니다.'), findsOneWidget);
    expect(find.text('비밀번호를 확인해주세요.'), findsOneWidget);

    // “연락처를 입력해주세요.” appears in red (`Color(0xFFC42B1C)`) exactly once.
    final errorTextFinder = find.text('연락처를 입력해주세요.').evaluate().where((element) {
      final widget = element.widget;
      return widget is Text && widget.style?.color == const Color(0xFFC42B1C);
    }).toList();
    expect(errorTextFinder.length, 1);
  });
}
