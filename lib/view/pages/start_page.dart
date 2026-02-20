import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:get/get.dart';

import '../../viewmodel/controller/mqtt_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import 'home_page.dart';
import 'login_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  static const String routeName = '/start';

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final UserController userController = Get.find<UserController>();

    final bool isTokenValid = await userController.reqLoginByToken();

    if (!mounted) {
      return;
    }

    if (isTokenValid) {
      await _loadEssentialData();

      if (!mounted) {
        return;
      }

      Get.offAllNamed(HomePage.routeName);

      _connectMqttInBackground();
    } else {
      Get.offAllNamed(LoginPage.routeName);
    }
  }

  Future<void> _loadEssentialData() async {
    VehicleController vehicleController = Get.find<VehicleController>();
    InfraController infraController = Get.find<InfraController>();

    await vehicleController.reqLoadVehicles();
    await infraController.reqLoadInfraIdentifiers();
  }

  void _connectMqttInBackground() {
    final UserController userController = Get.find<UserController>();
    final MqttController mqttController = Get.find<MqttController>();

    final String? email = userController.loginUser?.email?.trim();
    final String? userId = userController.loginUser?.userId?.trim();

    final String clientId =
        (email != null && email.isNotEmpty) ? email : (userId != null && userId.isNotEmpty ? userId : 'fms-web');

    mqttController.connect(clientId);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CupertinoActivityIndicator(
          radius: 20,
          color: Colors.grey,
        ),
      ),
    );
  }
}
