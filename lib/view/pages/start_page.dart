/// lib/view/pages/start_page.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:get/get.dart';

import '../../viewmodel/controller/mqtt_controller.dart';
import '../../viewmodel/controller/notification_controller.dart';
import '../../viewmodel/controller/robot_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import 'home_page.dart';
import 'login_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});
  static const routeName = '/start';

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool result = await Get.find<UserController>().reqLoginByToken();

      debugPrint("reqLoginByToken result $result");

      if (result) {
        Get.find<NotificationController>().reqUnreadNotifications();
        Get.find<DashboardController>().reqDashboardLayoutSetting();
        Get.find<MqttController>().connect(Get.find<UserController>().loginUser!.email!);
        Get.find<RobotController>().reqRobotTypes();
        Get.find<RobotController>().reqRobotList();
        Get.find<RobotController>().reqRobotStatusList();
        Get.find<RobotController>().setRobotFilterStr("3tier");

        Get.offAllNamed(HomePage.routeName);
      } else {
        Get.offAllNamed(LoginPage.routeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey)),
    );
  }
}
