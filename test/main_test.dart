import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart' show MqttClientConnectionStatus;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// ────────── APP imports ──────────
import 'package:fms/model/user_model.dart';
import 'package:fms/view/pages/start_page.dart';
import 'package:fms/view/pages/login_page.dart';
import 'package:fms/view/pages/home_page.dart';

import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/viewmodel/controller/map_controller.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';

/// ──────────────────────────────
///  F-A-K-E  WebView implementation
/// ──────────────────────────────
class _FakeWebViewController with MockPlatformInterfaceMixin implements PlatformWebViewController {
  _FakeWebViewController([this.creationParams = const PlatformWebViewControllerCreationParams()]) {
    debugPrint('[FakeWebView] controller created');
  }

  @override
  final PlatformWebViewControllerCreationParams creationParams;

  final _navDelegate = _FakeNavigationDelegate();
  @override
  PlatformNavigationDelegate get navigationDelegate => _navDelegate;

  /* methods really used by widgets */
  @override
  Future<void> loadRequest(LoadRequestParams params) async => debugPrint('[FakeWebView] loadRequest $params');

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async => debugPrint('[FakeWebView] setJsMode $mode');

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async =>
      debugPrint('[FakeWebView] addJsChannel ${params.name}');

  @override
  Future<String?> currentUrl() async => null;

  @override
  Future<void> runJavaScript(String js) async => debugPrint('[FakeWebView] runJs $js');

  @override
  Future<Object> runJavaScriptReturningResult(String js) async {
    debugPrint('[FakeWebView] runJsWithResult $js');
    return '';
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNavigationDelegate with MockPlatformInterfaceMixin implements PlatformNavigationDelegate {
  _FakeNavigationDelegate([this.params = const PlatformNavigationDelegateCreationParams()]);
  @override
  final PlatformNavigationDelegateCreationParams params;

  @override
  Future<NavigationDecision> navigate(NavigationRequest request) async {
    debugPrint('[FakeWebView] navigate -> ${request.url}');
    return NavigationDecision.navigate;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebViewWidget with MockPlatformInterfaceMixin implements PlatformWebViewWidget {
  _FakeWebViewWidget(this.params) {
    debugPrint('[FakeWebView] widget created');
  }
  @override
  final PlatformWebViewWidgetCreationParams params;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      _FakeWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _FakeNavigationDelegate(params);
}

void _registerFakeWebViewPlatform() {
  if (WebViewPlatform.instance == null || WebViewPlatform.instance is! _FakeWebViewPlatform) {
    debugPrint('[SETUP] registering fake WebView platform');
    WebViewPlatform.instance = _FakeWebViewPlatform();
  }
}

/// ────────────────── Stub controllers ──────────────────
class _StubUserController extends UserController {
  _StubUserController(this._succ);
  final bool _succ;

  @override
  Future<bool> reqLoginByToken() async {
    debugPrint('[UserCtrl] reqLoginByToken -> $_succ');
    return _succ;
  }

  @override
  final loginUser = LoginUser(email: 'stub@domain.com');
}

class _StubNotificationController extends NotificationController {
  @override
  Future<void> reqUnreadNotifications() async => debugPrint('[NotiCtrl] reqUnreadNotifications');
}

class _StubDashboardController extends DashboardController {
  @override
  Future<void> reqDashboardLayoutSetting() async => debugPrint('[DashCtrl] reqDashboardLayoutSetting');
}

class _StubMqttController extends MqttController {
  @override
  Future<MqttClientConnectionStatus?> connect(String? email) async {
    debugPrint('[MqttCtrl] connect $email');
    return null;
  }
}

class _StubRobotController extends RobotController {
  @override
  Future<void> reqRobotTypes() async => debugPrint('[RobotCtrl] reqRobotTypes');
  @override
  Future<void> reqRobotList({int? typeId}) async => debugPrint('[RobotCtrl] reqRobotList type=$typeId');
  @override
  Future<void> reqRobotStatusList({int? objectId, int? objectTypeId}) async =>
      debugPrint('[RobotCtrl] reqRobotStatusList obj=$objectId');
}

class _StubMapController extends MapController {}

class _StubGraphController extends GraphController {}

class _StubLogController extends LogController {}

void _registerStubs({required bool tokenOk}) {
  debugPrint('[SETUP] register stubs (tokenOk=$tokenOk)');
  Get.put<UserController>(_StubUserController(tokenOk), permanent: true);
  Get.put<NotificationController>(_StubNotificationController(), permanent: true);
  Get.put<DashboardController>(_StubDashboardController(), permanent: true);
  Get.put<MqttController>(_StubMqttController(), permanent: true);
  Get.put<RobotController>(_StubRobotController(), permanent: true);
  Get.put<MapController>(_StubMapController(), permanent: true);
  Get.put<GraphController>(_StubGraphController(), permanent: true);
  Get.put<LogController>(_StubLogController(), permanent: true);
}

/// ───────────────────────── tests ─────────────────────────
void main() {
  _registerFakeWebViewPlatform();
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // Silence overflow logs
  late final FlutterExceptionHandler oldOnError;
  setUpAll(() {
    oldOnError = FlutterError.onError!;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed by')) {
        return;
      }
      oldOnError(details);
    };
  });
  tearDownAll(() => FlutterError.onError = oldOnError);

  setUp(() {
    debugPrint('─── setUp ─────────────────────────────────────────');
    binding.window.physicalSizeTestValue = const Size(1200, 800);
    binding.window.devicePixelRatioTestValue = 1.0;
    Get.testMode = true;
  });

  tearDown(() {
    debugPrint('─── tearDown ──────────────────────────────────────');
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
    Get.reset();
  });

  testWidgets('✓ valid token → lands on HomePage', (tester) async {
    debugPrint('>>> TEST valid-token flow');
    _registerStubs(tokenOk: true);

    debugPrint('[Arrange] pump StartPage');
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: StartPage.routeName,
        getPages: [
          GetPage(name: StartPage.routeName, page: () => const StartPage()),
          GetPage(name: LoginPage.routeName, page: () => const LoginPage()),
          GetPage(name: HomePage.routeName, page: () => const HomePage()),
        ],
      ),
    );

    debugPrint('[Act] first pump');
    await tester.pump();
    debugPrint('[Act] settle navigation');
    await tester.pumpAndSettle();

    debugPrint('[Assert]');
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('✗ invalid token → navigates to LoginPage', (tester) async {
    debugPrint('>>> TEST invalid-token flow');
    _registerStubs(tokenOk: false);

    debugPrint('[Arrange] pump StartPage');
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: StartPage.routeName,
        getPages: [
          GetPage(name: StartPage.routeName, page: () => const StartPage()),
          GetPage(name: LoginPage.routeName, page: () => const LoginPage()),
          GetPage(name: HomePage.routeName, page: () => const HomePage()),
        ],
      ),
    );

    debugPrint('[Act] first pump');
    await tester.pump();
    debugPrint('[Act] settle navigation');
    await tester.pumpAndSettle();

    debugPrint('[Assert]');
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('direct push → HomePage renders', (tester) async {
    debugPrint('>>> TEST direct HomePage push');
    _registerStubs(tokenOk: true);

    debugPrint('[Arrange] pump HomePage route');
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: HomePage.routeName,
        getPages: [
          GetPage(name: StartPage.routeName, page: () => const StartPage()),
          GetPage(name: LoginPage.routeName, page: () => const LoginPage()),
          GetPage(name: HomePage.routeName, page: () => const HomePage()),
        ],
      ),
    );

    debugPrint('[Act] settle build');
    await tester.pumpAndSettle();

    debugPrint('[Assert]');
    expect(find.byType(HomePage), findsOneWidget);
  });
}
