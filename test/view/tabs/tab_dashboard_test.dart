// File: test/view/tabs/tab_dashboard_test.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Intl initialization for AlarmWidget's DateFormat
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fms/view/tabs/tab_dashboard.dart';
import 'package:fms/view/dashboard_widgets/alarm_widget.dart';
import 'package:fms/view/dashboard_widgets/device_status_widget.dart';
import 'package:fms/view/dashboard_widgets/moving_distance_widget.dart';
import 'package:fms/view/dashboard_widgets/moving_distance_by_day_widget.dart';
import 'package:fms/view/dashboard_widgets/operation_time_widget.dart';
import 'package:fms/view/dashboard_widgets/operation_time_by_day_widget.dart';
import 'package:fms/view/dashboard_widgets/used_battery_widget.dart';
import 'package:fms/view/dashboard_widgets/used_battery_by_day_widget.dart';

import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/map_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/model/dashboard_model.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Fake WebView platform + no-op controller + widget, so nothing crashes
class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      _FakeWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWebViewWidget(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(PlatformWebViewControllerCreationParams params) : super.implementation(params);
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    debugPrint('[_FakeWebViewController] setJavaScriptMode($mode)');
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    debugPrint('[_FakeWebViewController] addJavaScriptChannel(${params.name})');
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    debugPrint('[_FakeWebViewController] loadRequest(${params.uri})');
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(PlatformWebViewWidgetCreationParams params) : super.implementation(params);
  @override
  Widget build(BuildContext _) {
    debugPrint('[_FakeWebViewWidget] build()');
    return const SizedBox.shrink();
  }
}

/// Fakes for Get.find<…>()
class FakeMapController extends MapController {
  @override
  void onInit() {
    debugPrint('[FakeMapController] onInit');
  }
}

class FakeRobotController extends RobotController {
  @override
  void onInit() {
    debugPrint('[FakeRobotController] onInit');
  }
}

class FakeDashboardController extends DashboardController {
  @override
  Future<void> reqDashboardLayoutSetting() async {
    debugPrint('[FakeDashboardController] reqDashboardLayoutSetting');
    layoutSets
      ..clear()
      ..addAll([
        LayoutSet(rowIndex: 0, columnIndex: 0, title: '기기 운행 현황'),
        LayoutSet(rowIndex: 0, columnIndex: 1, title: '주요 알림'),
        LayoutSet(rowIndex: 1, columnIndex: 0, title: '전체 로봇의 누적 주행거리'),
        LayoutSet(rowIndex: 1, columnIndex: 1, title: '로봇별 일평균 주행거리'),
      ]);
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('[FakeDashboardController] onInit');
  }
}

class FakeNotificationController extends NotificationController {
  @override
  void onInit() {
    debugPrint('[FakeNotificationController] onInit');
  }
}

void main() {
  setUp(() async {
    // 1) Initialize intl for DateFormat in AlarmWidget
    await initializeDateFormatting();
    Intl.defaultLocale = 'ko';
    debugPrint('[setUp] Intl initialized with locale=${Intl.defaultLocale}');

    // 2) Reset and register fakes
    Get.reset();
    WebViewPlatform.instance = _FakeWebViewPlatform();
    debugPrint('[setUp] WebViewPlatform set to Fake');

    Get.put<MapController>(FakeMapController());
    Get.put<RobotController>(FakeRobotController());
    Get.put<DashboardController>(FakeDashboardController());
    Get.put<GraphController>(GraphController());
    Get.put<NotificationController>(FakeNotificationController());
    debugPrint('[setUp] Registered fake controllers');
  });

  testWidgets('TabDashboard lays out exactly the four expected widgets', (tester) async {
    debugPrint('[test] Starting TabDashboard test');

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: TabDashboard(gotoAlarmSet: () {})),
      ),
    );
    debugPrint('[test] pumpWidget done');

    // Allow first build + the async layout‐load in initState to complete:
    await tester.pump();
    debugPrint('[test] first pump done');
    await tester.pump(const Duration(milliseconds: 50));
    debugPrint('[test] second pump (+50ms) done');

    // First row:
    debugPrint('[test] Checking DeviceStatusWidget');
    expect(find.byType(DeviceStatusWidget), findsOneWidget);

    debugPrint('[test] Checking AlarmWidget');
    expect(find.byType(AlarmWidget), findsOneWidget);

    // Second row:
    debugPrint('[test] Checking MovingDistanceWidget');
    expect(find.byType(MovingDistanceWidget), findsOneWidget);

    debugPrint('[test] Checking MovingDistanceByDayWidget');
    expect(find.byType(MovingDistanceByDayWidget), findsOneWidget);

    // The rest should not appear:
    debugPrint('[test] Checking absence of OperationTimeWidget');
    expect(find.byType(OperationTimeWidget), findsNothing);

    debugPrint('[test] Checking absence of OperationTimeByDayWidget');
    expect(find.byType(OperationTimeByDayWidget), findsNothing);

    debugPrint('[test] Checking absence of UsedBatteryWidget');
    expect(find.byType(UsedBatteryWidget), findsNothing);

    debugPrint('[test] Checking absence of UsedBatteryByDayWidget');
    expect(find.byType(UsedBatteryByDayWidget), findsNothing);

    debugPrint('[test] TabDashboard test complete');
  });
}
