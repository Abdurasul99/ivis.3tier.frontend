import 'dart:ui';

import 'package:flutter/foundation.dart'
    show ErrorDescription, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ivis/view/components/custom_scroll_behavior.dart';
import 'package:ivis/view/pages/home_page.dart';
import 'package:ivis/view/pages/login_check_id_page.dart';
import 'package:ivis/view/pages/login_find_id_page.dart';
import 'package:ivis/view/pages/login_find_pw_page.dart';
import 'package:ivis/view/pages/login_page.dart';
import 'package:ivis/view/pages/login_reset_final_page.dart';
import 'package:ivis/view/pages/login_reset_pw_page.dart';
import 'package:ivis/view/pages/signup_final_page.dart';
import 'package:ivis/view/pages/signup_page.dart';
import 'package:ivis/view/pages/signup_register_page.dart';
import 'package:ivis/view/pages/start_page.dart';
import 'package:ivis/viewmodel/controller/activity_controller.dart';
import 'package:ivis/viewmodel/controller/locale_controller.dart';
import 'package:ivis/viewmodel/controller/member_controller.dart';
import 'package:ivis/viewmodel/controller/mqtt_controller.dart';
import 'package:ivis/viewmodel/controller/password_controller.dart';
import 'package:ivis/viewmodel/controller/register_controller.dart';
import 'package:ivis/viewmodel/controller/time_controller.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';
import 'package:ivis/viewmodel/controller/infra_controller.dart';
import 'package:ivis/viewmodel/controller/object_controller.dart';
import 'package:ivis/viewmodel/controller/dashboard_controller.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'platform',
        context: ErrorDescription('while handling an uncaught platform error'),
      ),
    );
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    final String message =
        kDebugMode ? details.exceptionAsString() : 'Unexpected UI error';
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  Get.put(UserController(), permanent: true);
  Get.put(TimeController(), permanent: true);
  Get.put(PasswordController(), permanent: true);
  Get.put(MemberController(), permanent: true);
  Get.put(RegisterController(), permanent: true);
  Get.put(VehicleController(), permanent: true);
  Get.put(InfraController(), permanent: true);
  Get.put(MqttController(), permanent: true);
  final LocaleController localeController =
      Get.put(LocaleController(), permanent: true);
  await localeController.loadSavedLocale();
  Get.lazyPut<ObjectController>(() => ObjectController(), fenix: true);
  Get.lazyPut<DashboardController>(() => DashboardController(), fenix: true);
  Get.lazyPut<ActivityController>(() => ActivityController(), fenix: true);
  runApp(const IvisFmsApp());
}

class IvisFmsApp extends StatelessWidget {
  const IvisFmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      fontFamily: 'pretendard',
      primaryColor: Colors.white,
      scaffoldBackgroundColor: Colors.white,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final theme = base.copyWith(
      platform: kIsWeb ? TargetPlatform.android : base.platform,
    );

    return GetMaterialApp(
      title: '3tier Data Dashboard',
      debugShowCheckedModeBanner: false,
      scrollBehavior: CustomScrollBehavior(),
      initialRoute: StartPage.routeName,
      locale: Get.find<LocaleController>().locale,
      fallbackLocale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      darkTheme: theme,
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
    );
  }
}
