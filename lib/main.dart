import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fms/view/components/custom_scroll_behavior.dart';
import 'package:fms/view/pages/home_page.dart';
import 'package:fms/view/pages/login_check_id_page.dart';
import 'package:fms/view/pages/login_find_id_page.dart';
import 'package:fms/view/pages/login_find_pw_page.dart';
import 'package:fms/view/pages/login_page.dart';
import 'package:fms/view/pages/login_reset_final_page.dart';
import 'package:fms/view/pages/login_reset_pw_page.dart';
import 'package:fms/view/pages/signup_final_page.dart';
import 'package:fms/view/pages/signup_page.dart';
import 'package:fms/view/pages/signup_register_page.dart';
import 'package:fms/view/pages/start_page.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';
import 'package:fms/viewmodel/controller/map_controller.dart';
import 'package:fms/viewmodel/controller/member_controller.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/viewmodel/controller/password_controller.dart';
import 'package:fms/viewmodel/controller/register_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/viewmodel/controller/time_controller.dart';
import 'package:fms/viewmodel/controller/upload_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  Get.put(UserController());
  Get.put(TimeController());
  Get.put(DashboardController());
  Get.put(PasswordController());
  Get.put(UploadController());
  Get.put(MemberController());
  Get.put(RegisterController());
  Get.put(RobotController());
  Get.put(MqttController());
  Get.put(MapController());
  Get.put(NotificationController());
  Get.put(GraphController());
  Get.put(LogController());

  runApp(const IvisFmsApp());
}

class IvisFmsApp extends StatelessWidget {
  const IvisFmsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'IVIS FMS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: CustomScrollBehavior(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'pretendard',
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      getPages: [
        GetPage(name: StartPage.routeName, page: () => const StartPage()),
        GetPage(name: LoginPage.routeName, page: () => const LoginPage()),
        GetPage(name: HomePage.routeName, page: () => const HomePage()),
        GetPage(
          name: LoginFindIdPage.routeName,
          page: () => const LoginFindIdPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: LoginCheckIdPage.routeName,
          page: () => const LoginCheckIdPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: LoginResetPwPage.routeName,
          page: () => const LoginResetPwPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: LoginResetFinalPage.routeName,
          page: () => const LoginResetFinalPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: LoginFindPwPage.routeName,
          page: () => const LoginFindPwPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: SignupRegisterPage.routeName,
          page: () => const SignupRegisterPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: SignUpPage.routeName,
          page: () => const SignUpPage(),
          transition: Transition.noTransition,
        ),
        GetPage(
          name: SignUpFinalPage.routeName,
          page: () => const SignUpFinalPage(),
          transition: Transition.noTransition,
        ),
      ],
      home: const StartPage(),
    );
  }
}
