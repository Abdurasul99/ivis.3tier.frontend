// test/view/dashboard_widget/alarm_widget_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fms/view/dashboard_widgets/alarm_widget.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/model/notification_model.dart';

class FakeNotificationController extends NotificationController {
  bool _loading = false;
  List<NotificationItem> _notes = [];

  @override
  bool get isLoading => _loading;
  set isLoading(bool v) => _loading = v;

  @override
  List<NotificationItem> get notifications => _notes;
  set notifications(List<NotificationItem> v) => _notes = v;

  @override
  Future<void> reqNotifications(String? a, String? b) async {
    // no-op
  }
}

void main() {
  // Initialize Korean locale data so DateFormat('ko') won't crash
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  late FakeNotificationController ctrl;

  setUp(() {
    Get.reset();
    ctrl = FakeNotificationController();
    Get.put<NotificationController>(ctrl);
  });

  Widget _wrap(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        // needs a bounded height so Expanded/ListView can layout
        body: SizedBox(height: 200, child: child),
      ),
    );
  }

  testWidgets('shows loading spinner when isLoading is true', (tester) async {
    ctrl.isLoading = true;
    ctrl.notifications = [];
    await tester.pumpWidget(_wrap(const AlarmWidget()));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('shows empty-list message when notifications is empty', (tester) async {
    ctrl.isLoading = false;
    ctrl.notifications = [];
    await tester.pumpWidget(_wrap(const AlarmWidget()));
    await tester.pump();
    expect(find.text('알림이 없습니다 😑'), findsOneWidget);
  });

  testWidgets('renders header and View all, and tapping it fires callback', (tester) async {
    ctrl.isLoading = false;

    // MUST supply at least 5 items because alarm_widget uses itemCount = 5
    ctrl.notifications = List.generate(
      5,
      (i) => NotificationItem(
        id: i,
        comment: 'Comment $i',
        createTs: '2025.07.${i + 1} 오전 10:0$i',
      ),
    );

    var tapped = false;
    await tester.pumpWidget(_wrap(AlarmWidget(gotoAlarmSet: () => tapped = true)));
    await tester.pump();

    // header
    expect(find.text('주요 알림'), findsOneWidget);
    // "View all" button
    final viewAll = find.text('View all');
    expect(viewAll, findsOneWidget);

    // tap it
    await tester.tap(viewAll);
    await tester.pump();
    expect(tapped, isTrue);
  });
}
