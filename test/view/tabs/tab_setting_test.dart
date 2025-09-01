// File: test/view/tabs/tab_setting_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/svg.dart';

import 'package:fms/view/tabs/tab_setting.dart';
import 'package:fms/view/tabs/tab_setting_profile.dart';
import 'package:fms/view/tabs/tab_setting_dashboard.dart';
import 'package:fms/view/tabs/tab_setting_member.dart';
import 'package:fms/view/tabs/tab_setting_alarm.dart';

import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/member_controller.dart';

class FakeUserControllerAdmin extends UserController {
  @override
  bool isAdminUser() => true;
}

class FakeUserControllerNonAdmin extends UserController {
  @override
  bool isAdminUser() => false;
}

class FakeNotificationController extends NotificationController {
  @override
  int get settingTabIndex => 0;

  @override
  void setSettingTabIndex(int index) {
    // debug log so you can see it in the test output
    debugPrint('📢 NotificationController.setSettingTabIndex($index)');
    super.setSettingTabIndex(index);
  }
}

void main() {
  // route debugPrint to stdout
  debugPrint = (String? message, {int? wrapWidth}) => print(message);

  Future<void> pumpTabSetting(
    WidgetTester tester, {
    required UserController userCtrl,
    required NotificationController notifCtrl,
  }) async {
    // Give lots of room to avoid overflows
    await tester.binding.setSurfaceSize(const Size(2000, 2000));

    Get.reset();
    // register all needed controllers
    Get.put<UserController>(userCtrl);
    Get.put<NotificationController>(notifCtrl);
    Get.put<DashboardController>(DashboardController());
    Get.put<MemberController>(MemberController());

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: TabSetting()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TabSetting as Admin', () {
    final userCtrl = FakeUserControllerAdmin();
    final notifCtrl = FakeNotificationController();

    testWidgets('shows four menu items and default Profile tab', (tester) async {
      await pumpTabSetting(tester, userCtrl: userCtrl, notifCtrl: notifCtrl);

      expect(find.text('프로필 설정'), findsOneWidget);
      expect(find.text('대시보드 관리'), findsOneWidget);
      expect(find.text('맴버 관리'), findsOneWidget);
      expect(find.text('주요 알림'), findsOneWidget);

      // Profile tab should be shown initially
      expect(find.byType(TabSettingProfile), findsOneWidget);
    });

    testWidgets('navigates to each tab on tap', (tester) async {
      await pumpTabSetting(tester, userCtrl: userCtrl, notifCtrl: notifCtrl);

      // Dashboard
      await tester.tap(find.text('대시보드 관리'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingDashboard), findsOneWidget);

      // Member
      await tester.tap(find.text('맴버 관리'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingMember), findsOneWidget);

      // Alarm
      await tester.tap(find.text('주요 알림'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingAlarm), findsOneWidget);

      // Back to Profile
      await tester.tap(find.text('프로필 설정'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingProfile), findsOneWidget);
    });
  });

  group('TabSetting as Non-Admin', () {
    final userCtrl = FakeUserControllerNonAdmin();
    final notifCtrl = FakeNotificationController();

    testWidgets('shows three menu items (no Member)', (tester) async {
      await pumpTabSetting(tester, userCtrl: userCtrl, notifCtrl: notifCtrl);

      expect(find.text('프로필 설정'), findsOneWidget);
      expect(find.text('대시보드 관리'), findsOneWidget);
      expect(find.text('주요 알림'), findsOneWidget);

      // "맴버 관리" should not be present
      expect(find.text('맴버 관리'), findsNothing);

      // Profile tab is default
      expect(find.byType(TabSettingProfile), findsOneWidget);
    });

    testWidgets('navigates skipping Member', (tester) async {
      await pumpTabSetting(tester, userCtrl: userCtrl, notifCtrl: notifCtrl);

      // Dashboard
      await tester.tap(find.text('대시보드 관리'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingDashboard), findsOneWidget);

      // Alarm (skips Member)
      await tester.tap(find.text('주요 알림'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingAlarm), findsOneWidget);

      // Back to Profile
      await tester.tap(find.text('프로필 설정'));
      await tester.pumpAndSettle();
      expect(find.byType(TabSettingProfile), findsOneWidget);
    });
  });
}
