// File: test/view/tabs/tab_setting_alarm_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/tabs/tab_setting_alarm.dart';
import 'package:fms/model/notification_model.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/view/dialogs/period_select_dialog.dart';
import 'package:fms/constants/constants.dart';

// 1) A fake controller for the empty-state scenario
class EmptyNotificationController extends NotificationController {
  @override
  Future<void> reqNotifications(String? start, String? end) async {
    notifications.clear();
    update();
  }

  @override
  Widget getPageNationView() => const Text('PAGINATION');
}

// 2) A fake controller with two notifications (one unread, one read)
class PopulatedNotificationController extends NotificationController {
  int? lastReadId;

  @override
  Future<void> reqNotifications(String? start, String? end) async {
    notifications
      ..clear()
      ..addAll([
        NotificationItem(
          id: 1,
          alarmType: 'Type A',
          createTs: '2025-06-30 10:00',
          comment: 'Comment A',
          isRead: false,
        ),
        NotificationItem(
          id: 2,
          alarmType: 'Type B',
          createTs: '2025-06-29 09:30',
          comment: 'Comment B',
          isRead: true,
        ),
      ]);
    update();
  }

  @override
  Future<void> reqReadNotification(int id) async {
    lastReadId = id;
  }

  @override
  Widget getPageNationView() => const Text('PAGINATION');
}

void main() {
  // Helper function to pump the TabSettingAlarm widget with the given controller
  Future<void> _pump(WidgetTester tester, NotificationController ctrl) async {
    Get.reset();
    Get.put<NotificationController>(ctrl);
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: TabSettingAlarm())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays empty state when there are no notifications', (tester) async {
    final ctrl = EmptyNotificationController();
    await _pump(tester, ctrl);

    // Header and filter labels
    expect(find.text('주요 알림'), findsOneWidget); // "Main Alerts"
    expect(find.text('알림 위치'), findsOneWidget); // "Alert Location"
    expect(find.text('날짜, 시간'), findsOneWidget); // "Date, Time"
    expect(find.text('내용'), findsOneWidget); // "Content"

    // Empty message
    expect(find.text('조건에 맞는 알림 정보가 없습니다 😑'), findsOneWidget);

    // Pagination widget
    expect(find.text('PAGINATION'), findsOneWidget);
  });

  testWidgets('renders list of notifications and handles tap on unread item', (tester) async {
    final ctrl = PopulatedNotificationController();
    await _pump(tester, ctrl);

    // First notification (unread)
    expect(find.text('Type A'), findsOneWidget);
    expect(find.text('2025-06-30 10:00'), findsOneWidget);
    expect(find.text('Comment A'), findsOneWidget);

    // Second notification (read)
    expect(find.text('Type B'), findsOneWidget);
    expect(find.text('2025-06-29 09:30'), findsOneWidget);
    expect(find.text('Comment B'), findsOneWidget);

    // Tap the first (unread) item → should call reqReadNotification(1)
    await tester.tap(find.text('Type A'));
    await tester.pump();
    expect(ctrl.lastReadId, 1);

    // Pagination widget still visible
    expect(find.text('PAGINATION'), findsOneWidget);
  });

  testWidgets('opens PeriodSelectDialog when tapping the date/time filter', (tester) async {
    final ctrl = EmptyNotificationController();
    await _pump(tester, ctrl);

    await tester.tap(find.text('날짜, 시간')); // "Date, Time"
    await tester.pumpAndSettle();

    // The PeriodSelectDialog should appear
    expect(find.byType(PeriodSelectDialog), findsOneWidget);
  });
}
