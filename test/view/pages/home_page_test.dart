// test/view/pages/home_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:fms/view/pages/home_page.dart';
import 'package:fms/view/tabs/tab_dashboard.dart';
import 'package:fms/view/tabs/tab_robot.dart';
import 'package:fms/view/tabs/tab_setting.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/viewmodel/controller/map_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/controller/time_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/constants/constants.dart';

/// ——— Fake WebViewPlatform & stubs ———————————————————————————————

class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      FakePlatformWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      FakePlatformWebViewWidget(
        controller: params.controller,
        params: params,
      );

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      FakeNavigationDelegate(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(PlatformWebViewCookieManagerCreationParams params) =>
      FakeCookieManager(params);
}

class FakePlatformWebViewController extends PlatformWebViewController {
  FakePlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) : super.implementation(params);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<String?> currentUrl() async => null;

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate delegate) async {}
}

class FakePlatformWebViewWidget extends PlatformWebViewWidget {
  FakePlatformWebViewWidget({
    required PlatformWebViewController controller,
    required PlatformWebViewWidgetCreationParams params,
  }) : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(PlatformNavigationDelegateCreationParams params) : super.implementation(params);

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback cb) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback cb) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback cb) async {}

  @override
  Future<void> setOnProgress(ProgressCallback cb) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback cb) async {}
}

class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(PlatformWebViewCookieManagerCreationParams params) : super.implementation(params);
}

void main() {
  setUpAll(() {
    // install our fake WebView platform before any tests
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  setUp(() {
    // Put all your GetX controllers so they exist during HomePage build
    Get.testMode = true;
    Get.put(DashboardController());
    Get.put(RobotController());
    Get.put(MapController());
    Get.put(UserController());
    Get.put(TimeController());
    Get.put(NotificationController());
  });

  tearDown(() {
    Get.reset(); // clean up for next test
  });

  Future<void> _pumpHome(WidgetTester tester) async {
    // enlarge the test window so top bar row never overflows
    tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  testWidgets('A1: SafeArea and Scaffold backgroundColor', (tester) async {
    await _pumpHome(tester);

    expect(find.byType(SafeArea), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, kBackgroundColor);
  });

  testWidgets('A2: Three menu items and default tab content', (tester) async {
    await _pumpHome(tester);

    expect(find.text('대시보드'), findsOneWidget);
    expect(find.text('로봇'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);

    // Dashboard should be visible by default
    expect(find.byType(TabDashboard), findsOneWidget);
    expect(find.byType(TabRobot), findsNothing);
    expect(find.byType(TabSetting), findsNothing);
  });

  testWidgets('A3: Tapping tabs switches content', (tester) async {
    await _pumpHome(tester);

    // start on 대시보드
    expect(find.byType(TabDashboard), findsOneWidget);

    // tap 로봇
    await tester.tap(find.text('로봇'));
    await tester.pumpAndSettle();
    expect(find.byType(TabRobot), findsOneWidget);
    expect(find.byType(TabDashboard), findsNothing);

    // tap 설정
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.byType(TabSetting), findsOneWidget);
    expect(find.byType(TabRobot), findsNothing);
  });
}
