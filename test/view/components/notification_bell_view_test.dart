// test/view/components/notification_bell_view_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fms/view/components/notification_bell_view.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/model/notification_model.dart';

class MockDashboardController extends DashboardController {
  @override
  String mapViewId = 'test-iframe';
}

class MockNotificationController extends NotificationController {
  int _unreadCount = 0;
  bool _isLoading = false;
  List<NotificationItem> _items = [];

  @override
  int get unreadCount => _unreadCount;
  set unreadCount(int value) => _unreadCount = value;

  @override
  bool get isLoading => _isLoading;
  set isLoading(bool value) => _isLoading = value;

  @override
  List<NotificationItem> get unreadNotifications => _items;
  set unreadNotifications(List<NotificationItem> items) => _items = items;

  bool reqUnreadCalled = false;
  bool reqNotificationsCalled = false;
  final List<int> readCalledWith = [];

  // Matches NotificationController signature: Future<int> reqUnreadNotificationCount()
  @override
  Future<int> reqUnreadNotificationCount() async {
    reqUnreadCalled = true;
    return _unreadCount;
  }

  // Matches NotificationController signature: Future<void> reqNotifications(String?, String?)
  @override
  Future<void> reqNotifications(String? a, String? b) async {
    reqNotificationsCalled = true;
  }

  @override
  Future<void> reqReadNotification(int id) async {
    readCalledWith.add(id);
  }

  @override
  void setNotificationDialogOpen(bool open) {
    // no-op
  }
}

void main() {
  late MockDashboardController mockDash;
  late MockNotificationController mockNotif;

  setUp(() {
    Get.reset();
    mockDash = MockDashboardController();
    mockNotif = MockNotificationController();
    Get.put<DashboardController>(mockDash);
    Get.put<NotificationController>(mockNotif);
  });

  testWidgets('badge hidden when unreadCount is zero', (WidgetTester tester) async {
    mockNotif.unreadCount = 0;
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: NotificationBellView())),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications), findsOneWidget);
    // No Positioned badge
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('badge shows count when unreadCount > 0', (WidgetTester tester) async {
    mockNotif.unreadCount = 5;
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: NotificationBellView())),
    );
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('tapping bell opens dialog and calls controller methods', (WidgetTester tester) async {
    mockNotif.unreadCount = 1;
    mockNotif.unreadNotifications = [];
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: NotificationBellView())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(mockNotif.reqUnreadCalled, isTrue);
    expect(mockNotif.reqNotificationsCalled, isTrue);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('dialog shows loading indicator when controller.isLoading is true', (WidgetTester tester) async {
    mockNotif.unreadCount = 1;
    mockNotif.isLoading = true;
    mockNotif.unreadNotifications = [];
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: NotificationBellView())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('dialog shows empty text when no notifications', (WidgetTester tester) async {
    mockNotif.unreadCount = 1;
    mockNotif.isLoading = false;
    mockNotif.unreadNotifications = [];
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: NotificationBellView())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('미확인 알림 정보가 없습니다 😑'), findsOneWidget);
  });

  testWidgets('dialog lists notifications and tapping item marks read', (WidgetTester tester) async {
    mockNotif.unreadCount = 2;
    mockNotif.isLoading = false;
    mockNotif.unreadNotifications = [
      NotificationItem(id: 10, comment: 'First', createTs: '2025-06-01', isRead: false),
      NotificationItem(id: 20, comment: 'Second', createTs: '2025-06-02', isRead: true),
    ];
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: NotificationBellView())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();

    expect(mockNotif.readCalledWith, contains(10));
  });
}
