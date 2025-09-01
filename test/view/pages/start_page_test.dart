// test/view/pages/start_page_test.dart
//
// ──────────────────────────────────────────────────────────────
//  We never touch production widgets – only test-side stubs.
//  AAA layout with debugPrint so the console log is readable.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/model/user_model.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'package:fms/view/pages/start_page.dart';
import 'package:fms/view/pages/home_page.dart';
import 'package:fms/view/pages/login_page.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';

/// ──────────────────────────────────────────────────────────────
/// ▸ minimal stubbed controllers the page directly refers to
/// ──────────────────────────────────────────────────────────────

/// Only `reqLoginByToken()` and a non-null `loginUser.email` are needed.
class StubUserController extends UserController {
  StubUserController(this._loginSucceeds);

  final bool _loginSucceeds;

  /// private dummy user returned by the getter
  final LoginUser _dummyUser = LoginUser(email: 'stub@domain.com');

  @override
  LoginUser? get loginUser => _dummyUser;

  @override
  Future<bool> reqLoginByToken() async => _loginSucceeds;
}

/// No-op stubs so the page’s side-effects don’t explode.
class StubNotificationController extends NotificationController {}

class StubDashboardController extends DashboardController {}

class StubMqttController extends MqttController {
  String? lastEmail;

  @override
  Future<MqttClientConnectionStatus?> connect(String? email) async {
    lastEmail = email; // capture the call – handy for asserts
    return null; // no real connection in the stub
  }
}

class StubRobotController extends RobotController {}

/// ──────────────────────────────────────────────────────────────
/// ▸ set-up / tear-down helpers
/// ──────────────────────────────────────────────────────────────

late void Function(FlutterErrorDetails) _originalOnError;

/// Inject stubs and pump the StartPage inside a GetMaterialApp.
Future<void> _pumpStartPage(
  WidgetTester tester, {
  required bool loginSucceeds,
}) async {
  debugPrint('⏱  Arrange: pump StartPage – loginSucceeds=$loginSucceeds');

  Get.reset();
  Get.put<UserController>(StubUserController(loginSucceeds), permanent: true);
  Get.put<NotificationController>(StubNotificationController());
  Get.put<DashboardController>(StubDashboardController());
  Get.put<MqttController>(StubMqttController());
  Get.put<RobotController>(StubRobotController());

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: StartPage.routeName,
      getPages: [
        GetPage(name: StartPage.routeName, page: () => const StartPage()),
        GetPage(
          name: HomePage.routeName,
          page: () => const Scaffold(body: Center(child: Text('HOME PAGE'))),
        ),
        GetPage(
          name: LoginPage.routeName,
          page: () => const Scaffold(body: Center(child: Text('LOGIN PAGE'))),
        ),
      ],
    ),
  );

  // first frame
  await tester.pump();
}

/// ──────────────────────────────────────────────────────────────
/// ▸ tests
/// ──────────────────────────────────────────────────────────────
void main() {
  /* ---------- global set-up ---------- */
  setUp(() {
    _originalOnError = FlutterError.onError!;
    // silence the occasional overflow warning – not relevant here
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed by')) {
        return;
      }
      _originalOnError(details);
    };
    Get.testMode = true;
  });

  tearDown(() {
    FlutterError.onError = _originalOnError;
    Get.reset();
    Get.clearRouteTree();
  });

  testWidgets('navigates to HomePage when token-login succeeds', (tester) async {
    // ---------- Arrange ----------
    await _pumpStartPage(tester, loginSucceeds: true);

    // ---------- Act ----------
    debugPrint('👉  Act: wait for navigation');
    await tester.pumpAndSettle();

    // ---------- Assert ----------
    expect(find.text('HOME PAGE'), findsOneWidget);
    expect(find.text('LOGIN PAGE'), findsNothing);
  });

  testWidgets('navigates to LoginPage when token-login fails', (tester) async {
    // ---------- Arrange ----------
    await _pumpStartPage(tester, loginSucceeds: false);

    // ---------- Act ----------
    debugPrint('👉  Act: wait for navigation');
    await tester.pumpAndSettle();

    // ---------- Assert ----------
    expect(find.text('LOGIN PAGE'), findsOneWidget);
    expect(find.text('HOME PAGE'), findsNothing);
  });

  testWidgets('shows a loading indicator while deciding', (tester) async {
    // ---------- Arrange ----------
    await _pumpStartPage(tester, loginSucceeds: true);

    // ---------- Act ----------
    // only the very first frame – before pumpAndSettle()
    debugPrint('👉  Act: inspect first frame');

    // ---------- Assert ----------
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });
}
