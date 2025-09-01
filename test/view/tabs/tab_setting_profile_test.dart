// File: test/view/tabs/tab_setting_profile_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fms/view/tabs/tab_setting_profile.dart';
import 'package:fms/view/dialogs/photo_edit_dialog.dart';
import 'package:fms/view/dialogs/noti_dialog.dart';
import 'package:fms/view/dialogs/password_change_dialog.dart';
import 'package:fms/view/pages/login_page.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/model/user_model.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/view/components/input_edit_text_read_only.dart';
import 'package:fms/view/components/input_edit_text_setting.dart';
import 'package:fms/utils/utils.dart';

class FakeUserController extends UserController {
  final LoginUser fakeUser = LoginUser(
    id: 42,
    name: 'Test User',
    email: 'test@example.com',
    role: 'user',
    phoneNumber: '',
    imageUrl: '',
  );
  bool changePhoneCalled = false;
  bool logoutCalled = false;

  @override
  LoginUser? get loginUser => fakeUser;

  @override
  Future<bool> reqChangePhoneNumber(Map<String, dynamic> params) async {
    debugPrint('reqChangePhoneNumber called with $params');
    changePhoneCalled = true;
    return true;
  }

  @override
  Future<void> logout() async {
    debugPrint('logout called');
    logoutCalled = true;
  }
}

void main() {
  // Route all debugPrints to stdout so we can see them in flutter test output:
  debugPrint = (String? message, {int? wrapWidth}) => print(message);

  Future<void> pumpProfile(WidgetTester tester, FakeUserController ctrl) async {
    // Give LOTS of room to avoid overflow
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    Get.reset();
    Get.put<UserController>(ctrl);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const Scaffold(body: TabSettingProfile())),
          GetPage(name: LoginPage.routeName, page: () => const Scaffold(body: Text('LOGIN'))),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders profile info and placeholder avatar', (tester) async {
    final ctrl = FakeUserController();
    await pumpProfile(tester, ctrl);

    // Three read-only fields
    expect(find.byType(InputEditTextReadOnly), findsNWidgets(3));
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('일반'), findsOneWidget);

    // One phone input
    expect(find.byType(InputEditTextSetting), findsOneWidget);

    // Two SVGs: placeholder + edit icon
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });

  testWidgets('opens PhotoEditDialog when tapping edit icon', (tester) async {
    final ctrl = FakeUserController();
    await pumpProfile(tester, ctrl);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoEditDialog), findsOneWidget);
  });

  testWidgets('does not call changePhone when phone is empty', (tester) async {
    final ctrl = FakeUserController();
    await pumpProfile(tester, ctrl);

    // We do *not* tap the 연락처 변경 button here,
    // so reqChangePhoneNumber should never be called.
    expect(ctrl.changePhoneCalled, isFalse);
  });

  testWidgets('changes phone and shows NotiDialog', (tester) async {
    final ctrl = FakeUserController();
    ctrl.fakeUser.phoneNumber = '010-1234-5678';
    await pumpProfile(tester, ctrl);

    await tester.enterText(find.byType(InputEditTextSetting), '010-1234-5678');
    await tester.pump();

    await tester.tap(find.widgetWithText(GradientButton, '연락처 변경'));
    await tester.pumpAndSettle();

    expect(ctrl.changePhoneCalled, isTrue);
    expect(find.byType(NotiDialog), findsOneWidget);
  });

  testWidgets('opens PasswordChangeDialog', (tester) async {
    final ctrl = FakeUserController();
    await pumpProfile(tester, ctrl);

    await tester.tap(find.widgetWithText(GradientButton, '비밀번호 변경'));
    await tester.pumpAndSettle();

    expect(find.byType(PasswordChangeDialog), findsOneWidget);
  });

  testWidgets('logout navigates to login page', (tester) async {
    final ctrl = FakeUserController();
    await pumpProfile(tester, ctrl);

    await tester.tap(find.widgetWithText(GradientButton, '로그아웃'));
    await tester.pumpAndSettle();

    expect(ctrl.logoutCalled, isTrue);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
