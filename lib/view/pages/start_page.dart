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
      await initializeApp();
    });
  }

  Future<void> initializeApp() async {
    final UserController userController = Get.find<UserController>();

    final bool isTokenValid = await userController.reqLoginByToken();

    if (!mounted) {
      return;
    }

    if (isTokenValid) {
      await handleAfterTokenLogin();

      if (!mounted) {
        return;
      }

      await verifyDataLoaded();

      if (!mounted) {
        return;
      }

      Get.offAllNamed(HomePage.routeName);
    } else {
      Get.offAllNamed(LoginPage.routeName);
    }
  }

  Future<void> handleAfterTokenLogin() async {
    final UserController userController = Get.find<UserController>();
    final VehicleController vehicleController = Get.find<VehicleController>();
    final InfraController infraController = Get.find<InfraController>();
    final MqttController mqttController = Get.find<MqttController>();

    await Future.wait(<Future<void>>[
      vehicleController.reqLoadVehicles(),
      infraController.reqLoadInfraIdentifiers(),
    ]);

    await infraController.refreshAll();

    final String? email = userController.loginUser?.email?.trim();
    final String? userId = userController.loginUser?.userId?.trim();

    final String clientId =
        (email != null && email.isNotEmpty) ? email : (userId != null && userId.isNotEmpty ? userId : 'fms-web');

    mqttController.connect(clientId);
  }

  Future<void> verifyDataLoaded() async {
    final UserController userController = Get.find<UserController>();
    final VehicleController vehicleController = Get.find<VehicleController>();

    for (int attempt = 0; attempt < 100; attempt++) {
      final String? token = userController.accessToken;
      final bool hasToken = token != null && token.isNotEmpty;

      if (hasToken && vehicleController.vehicles.isNotEmpty) {
        return;
      }

      if (hasToken && attempt > 20) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
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
