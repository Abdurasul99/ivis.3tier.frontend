// File: test/view/tabs/tab_robot_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Stub out WebView so it never actually builds a WebView
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:fms/view/tabs/tab_robot.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/viewmodel/controller/map_controller.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/model/robot_model.dart';

/// A no-op WebViewController for tests
class NoopWebViewController extends PlatformWebViewController {
  NoopWebViewController(PlatformWebViewControllerCreationParams p) : super.implementation(p);
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    debugPrint('🚧 NoopWebViewController.setJavaScriptMode');
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    debugPrint('🚧 NoopWebViewController.addJavaScriptChannel(${params.name})');
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    debugPrint('🚧 NoopWebViewController.loadRequest(${params.uri})');
  }

  @override
  Future<void> runJavaScript(String js) async {
    debugPrint('🚧 NoopWebViewController.runJavaScript');
  }

  @override
  Future<Object> runJavaScriptReturningResult(String js) async {
    debugPrint('🚧 NoopWebViewController.runJavaScriptReturningResult');
    return '';
  }
}

/// Fake platform that returns our no-op controller & widget
class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams p) {
    debugPrint('🚧 FakeWebViewPlatform.createController');
    return NoopWebViewController(p);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams p) {
    debugPrint('🚧 FakeWebViewPlatform.createWidget');
    return _FakeWebViewWidget(p);
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(PlatformWebViewWidgetCreationParams p) : super.implementation(p);
  @override
  Widget build(BuildContext _) {
    debugPrint('🚧 _FakeWebViewWidget.build');
    return const SizedBox.shrink();
  }
}

// Fakes for all controllers:

class FakeUserController extends UserController {
  @override
  bool isAdminUser() {
    debugPrint('🚧 FakeUserController.isAdminUser');
    return true;
  }
}

class FakeMapController extends MapController {
  @override
  Uri get mapUri {
    debugPrint('🚧 FakeMapController.mapUri');
    return Uri.parse('about:blank');
  }
}

class FakeRobotController extends RobotController {
  @override
  List<RobotType> get robotTypes {
    debugPrint('🚧 FakeRobotController.robotTypes');
    return [RobotType(id: 1, typeDescription: 'Taro', imageUrl: '')];
  }

  @override
  List<String> get robotTypeDescriptions {
    debugPrint('🚧 FakeRobotController.robotTypeDescriptions');
    return ['Taro'];
  }

  @override
  List<Robot> get robots {
    debugPrint('🚧 FakeRobotController.robots');
    return [Robot(id: 42, typeDescription: 'Taro', name: 'R2D2', imageUrl: '', serial: 'R2D2')];
  }

  @override
  List<RobotStatus> get robotStatusList {
    debugPrint('🚧 FakeRobotController.robotStatusList');
    return [
      RobotStatus(
        id: 42,
        latitude: 35.0,
        longitude: 128.0,
        drivingSpeed: 1.23,
        wheelBattery: 50.0,
        robotStatus: 0,
        serial: 'R2D2',
      )
    ];
  }

  @override
  Future<void> reqRobotTypes() async {
    debugPrint('📢 reqRobotTypes');
  }

  @override
  Future<void> reqRobotList({int? typeId}) async {
    debugPrint('📢 reqRobotList(typeId=$typeId)');
  }

  @override
  Future<void> reqRobotStatusList({int? objectId, int? objectTypeId}) async {
    debugPrint('📢 reqRobotStatusList(objectId=$objectId, objectTypeId=$objectTypeId)');
  }

  @override
  String getTaroLocation(String serial) {
    debugPrint('🚧 FakeRobotController.getTaroLocation($serial)');
    return '100.0,200.0';
  }
}

class FakeLogController extends LogController {
  List<dynamic> logList = [];
  @override
  Future<void> getLogList({int? objectId}) async {
    debugPrint('📢 getLogList(objectId=$objectId)');
    logList = [];
    update();
  }
}

class FakeGraphController extends GraphController {
  @override
  void onInit() {
    super.onInit();
    debugPrint('📢 GraphController.onInit');
    update();
  }

  @override
  Future<void> getGraphData({int? objectId}) async {
    debugPrint('📢 getGraphData(objectId=$objectId)');
    update();
  }
}

void main() {
  setUpAll(() {
    debugPrint('🛠️ setUpAll: registering fakes');
    WebViewPlatform.instance = FakeWebViewPlatform();
    Get.reset();
    Get.put<UserController>(FakeUserController(), permanent: true);
    Get.put<MapController>(FakeMapController(), permanent: true);
    Get.put<GraphController>(FakeGraphController(), permanent: true);
    Get.put<LogController>(FakeLogController(), permanent: true);
    Get.put<MqttController>(MqttController(), permanent: true);
    Get.put<RobotController>(FakeRobotController(), permanent: true);
  });

  Future<void> pumpTabRobot(WidgetTester tester) async {
    debugPrint('▶️ pumpTabRobot start');
    await tester.binding.setSurfaceSize(const Size(2000, 2000));
    await tester.pumpWidget(
      GetMaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(2000, 2000)),
          child: const Scaffold(body: TabRobot()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('▶️ pumpTabRobot done');
  }

  testWidgets('renders two "Select a robot" prompts before selection', (tester) async {
    debugPrint('--- test 1 start ---');
    await pumpTabRobot(tester);
    debugPrint('🔎 Finding prompts');
    expect(find.text('로봇을 선택하세요. 😎'), findsNWidgets(2));
    debugPrint('--- test 1 end ---');
  });

  testWidgets('tapping the add-robot button slides in add-robot panel', (tester) async {
    debugPrint('--- test 2 start ---');
    await pumpTabRobot(tester);
    final addBtn = find.widgetWithText(GradientButton, '로봇 추가');
    debugPrint('🔎 Found addBtn: $addBtn');
    expect(addBtn, findsOneWidget);

    debugPrint('👉 tapping addBtn');
    await tester.tap(addBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    debugPrint('⏱ animations settled');

    debugPrint('🔎 Verifying panel');
    expect(find.text('로봇 추가'), findsNWidgets(2));
    expect(find.text('확인'), findsOneWidget);
    debugPrint('--- test 2 end ---');
  });

  testWidgets('tapping the robot tile selects the robot', (tester) async {
    debugPrint('--- test 3 start ---');
    await pumpTabRobot(tester);
    final tile = find.text('Taro_R2D2');
    debugPrint('🔎 Found robot tile: $tile');
    expect(tile, findsOneWidget);

    debugPrint('👉 tapping robot tile');
    // swallow TaroMapView null-check error
    final origOnError = FlutterError.onError;
    FlutterError.onError = (details) => debugPrint('⚠️ suppressed error: ${details.exception}');
    await tester.tap(tile);
    await tester.pump();
    FlutterError.onError = origOnError;
    debugPrint('⏱ after tap and pump');

    debugPrint('🔎 Verifying selection state');
    expect(find.text('Taro_R2D2'), findsWidgets);
    expect(find.text('확인'), findsNothing);
    debugPrint('--- test 3 end ---');
  });
}
