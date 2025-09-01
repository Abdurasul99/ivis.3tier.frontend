import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fms/view/pages/signup_final_page.dart';
import 'package:fms/view/pages/login_page.dart';
import 'package:fms/viewmodel/controller/user_controller.dart'; // Import UserController

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup the test environment
  setUp(() {
    Get.reset(); // Reset GetX to avoid duplicate controllers
    print("DEBUG: Initializing UserController...");
    Get.put(UserController()); // Initialize UserController here
    print("DEBUG: UserController initialized.");

    Get.testMode = true; // Use GetX in test mode
  });

  // Tear down the environment
  tearDown(() {
    print("DEBUG: Resetting GetX...");
    Get.reset(); // Reset GetX after each test
  });

  testWidgets('renders top bar, messages, and login button', (tester) async {
    // Arrange: Setup the widget and prepare everything for the test
    print("DEBUG: Pumping SignUpFinalPage widget...");
    await tester.pumpWidget(
      GetMaterialApp(
        home: const SignUpFinalPage(),
      ),
    );
    await tester.pumpAndSettle();
    print("DEBUG: Finished pumping SignUpFinalPage.");

    // Act: Interact with the widget (in this case, verify the content)
    print("DEBUG: Verifying top bar and messages...");
    // Verify the text of top bar and message
    expect(find.text('아이비스 FMS 관제 시스템'), findsOneWidget);
    expect(find.text('회원가입이 완료되었습니다.'), findsOneWidget);

    final loginButton = find.widgetWithText(ElevatedButton, '로그인');
    print("DEBUG: Verifying login button...");
    // Verify the login button is rendered
    expect(loginButton, findsOneWidget);
    print("DEBUG: Login button found.");
  });

  testWidgets('tapping "로그인" navigates to LoginPage', (tester) async {
    // Arrange: Set up GetMaterialApp with routes for navigation
    print("DEBUG: Setting up navigation test...");
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: SignUpFinalPage.routeName,
        getPages: [
          GetPage(name: SignUpFinalPage.routeName, page: () => const SignUpFinalPage()),
          GetPage(name: LoginPage.routeName, page: () => const LoginPage()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    print("DEBUG: App setup complete, ready for navigation test.");

    // Act: Tap the "로그인" button
    print("DEBUG: Tapping '로그인' button...");
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    print("DEBUG: Button tapped, waiting for navigation...");

    // Assert: Verify if it navigates to LoginPage
    print("DEBUG: Verifying if navigation to LoginPage occurred...");
    expect(find.byType(LoginPage), findsOneWidget);
    print("DEBUG: Navigation to LoginPage successful.");
  });
}
