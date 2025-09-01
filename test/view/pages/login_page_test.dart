// test/view/pages/login_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/login_page.dart';
import 'package:fms/view/pages/login_find_id_page.dart';
import 'package:fms/view/pages/login_find_pw_page.dart';
import 'package:fms/view/pages/home_page.dart';

import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'package:fms/model/user_model.dart';

/* ──────────────────────────────── fake controllers ──────────────────────────────── */

class FakeUserController extends GetxController implements UserController {
  bool remember = false;
  String storedEmail = '';
  bool loginResult = true;

  String? lastId;
  String? lastPw;
  bool? savedRemember;
  String? savedEmail;

  @override
  LoginUser? get loginUser => LoginUser(email: 'dummy@domain.com');

  @override
  Future<bool> reqGetRememberMe() async => remember;

  @override
  Future<String> reqGetLoginEmail() async => storedEmail;

  @override
  Future<bool> reqLoginById(String id, String pw) async {
    lastId = id;
    lastPw = pw;
    return loginResult;
  }

  @override
  Future<bool> reqSaveRememberMe(bool value) async {
    savedRemember = value;
    return true;
  }

  @override
  Future<bool> reqSaveLoginEmail(String email) async {
    savedEmail = email;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationController extends GetxController implements NotificationController {
  bool called = false;
  @override
  Future<void> reqUnreadNotifications() async {
    called = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDashboardController extends GetxController implements DashboardController {
  bool called = false;
  @override
  Future<void> reqDashboardLayoutSetting() async {
    called = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMqttController extends GetxController implements MqttController {
  bool called = false;
  @override
  Future<MqttClientConnectionStatus?> connect(String email) async {
    called = true;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRobotController extends GetxController implements RobotController {
  int calls = 0;
  @override
  Future<void> reqRobotTypes() async => calls++;

  @override
  Future<void> reqRobotList({int? typeId}) async => calls++;

  @override
  Future<void> reqRobotStatusList({int? objectId, int? objectTypeId}) async => calls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/* ──────────────────────────────── helpers ──────────────────────────────── */

late FakeUserController userCtrl;
late FakeNotificationController notifCtrl;
late FakeDashboardController dashCtrl;
late FakeMqttController mqttCtrl;
late FakeRobotController robotCtrl;

Future<void> _pumpLoginPage(WidgetTester tester) async {
  tester.binding.window.physicalSizeTestValue = const Size(800, 800);
  tester.binding.window.devicePixelRatioTestValue = 1.0;
  addTearDown(() {
    tester.binding.window.clearPhysicalSizeTestValue();
    tester.binding.window.clearDevicePixelRatioTestValue();
  });

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: LoginPage.routeName,
      getPages: [
        GetPage(name: LoginPage.routeName, page: () => const LoginPage()),
        GetPage(name: LoginFindIdPage.routeName, page: () => const Scaffold(body: Text('FIND ID'))),
        GetPage(name: LoginFindPwPage.routeName, page: () => const Scaffold(body: Text('FIND PW'))),
        GetPage(name: '/register-first', page: () => const Scaffold(body: Text('SIGN UP'))),
        GetPage(name: HomePage.routeName, page: () => const Scaffold(body: Text('HOME'))),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

/* ──────────────────────────────── test suite ──────────────────────────────── */

void main() {
  setUp(() {
    Get.testMode = true;
    userCtrl = Get.put<UserController>(FakeUserController(), permanent: true) as FakeUserController;
    notifCtrl =
        Get.put<NotificationController>(FakeNotificationController(), permanent: true) as FakeNotificationController;
    dashCtrl = Get.put<DashboardController>(FakeDashboardController(), permanent: true) as FakeDashboardController;
    mqttCtrl = Get.put<MqttController>(FakeMqttController(), permanent: true) as FakeMqttController;
    robotCtrl = Get.put<RobotController>(FakeRobotController(), permanent: true) as FakeRobotController;
  });

  tearDown(() {
    Get.reset();
  });

  group('LoginPage widget tests', () {
    testWidgets('empty ID shows SnackBar error', (tester) async {
      // ---------- Arrange ----------
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.tap(find.text('Login').at(1));
      await tester.pump(); // SnackBar animation

      // ---------- Assert ----------
      expect(find.text('Enter your ID'), findsOneWidget);
      expect(userCtrl.lastId, isNull);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('empty password shows SnackBar error', (tester) async {
      // ---------- Arrange ----------
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.enterText(find.byType(TextField).at(0), 'testid');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login').at(1));
      await tester.pump(); // SnackBar animation

      // ---------- Assert ----------
      expect(find.text('Enter your password'), findsOneWidget);
      expect(userCtrl.lastId, isNull);
      expect(userCtrl.lastPw, isNull);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('invalid credentials shows error', (tester) async {
      // ---------- Arrange ----------
      userCtrl.loginResult = false;
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.enterText(find.byType(TextField).at(0), 'id');
      await tester.enterText(find.byType(TextField).at(1), 'pw');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login').at(1));
      await tester.pump(); // SnackBar animation

      // ---------- Assert ----------
      expect(find.text('Invalid ID or password'), findsOneWidget);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('successful login triggers controllers and navigates home', (tester) async {
      // ---------- Arrange ----------
      userCtrl.loginResult = true;
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.enterText(find.byType(TextField).at(0), 'id');
      await tester.enterText(find.byType(TextField).at(1), 'pw');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login').at(1));
      await tester.pumpAndSettle();

      // ---------- Assert ----------
      expect(notifCtrl.called, true);
      expect(dashCtrl.called, true);
      expect(mqttCtrl.called, true);
      expect(robotCtrl.calls, 3);
      expect(userCtrl.savedRemember, false);
      expect(Get.currentRoute, HomePage.routeName);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('Find ID link navigates to FindIdPage', (tester) async {
      // ---------- Arrange ----------
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.tap(find.text('Find ID'));
      await tester.pumpAndSettle();

      // ---------- Assert ----------
      expect(Get.currentRoute, LoginFindIdPage.routeName);
    });

    testWidgets('Find PW link navigates to FindPwPage', (tester) async {
      // ---------- Arrange ----------
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.tap(find.text('Find PW'));
      await tester.pumpAndSettle();

      // ---------- Assert ----------
      expect(Get.currentRoute, LoginFindPwPage.routeName);
    });

    testWidgets('Sign up link navigates to register-first', (tester) async {
      // ---------- Arrange ----------
      await _pumpLoginPage(tester);

      // ---------- Act ----------
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      // ---------- Assert ----------
      expect(Get.currentRoute, '/register-first');
    });
  });
}
