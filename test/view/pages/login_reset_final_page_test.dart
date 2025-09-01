// test/view/pages/login_reset_final_page_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/login_reset_final_page.dart';
import 'package:fms/view/pages/login_page.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/model/common_model.dart';

/// A TestAssetBundle that:
//  - returns a minimal valid SVG for any .svg asset,
//  - returns '{}' for any JSON manifest,
//  - returns empty ByteData for all others.
class TestAssetBundle extends CachingAssetBundle {
  static const _tinySvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">
  <rect width="1" height="1" fill="none"/>
</svg>
''';

  @override
  Future<ByteData> load(String key) async {
    print('DEBUG: TestAssetBundle.load("$key")');
    if (key.endsWith('.svg')) {
      final bytes = utf8.encode(_tinySvg);
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }
    // Return empty for other binary assets
    return ByteData(0);
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    FutureOr<T> Function(String) parser,
  ) async {
    print('DEBUG: TestAssetBundle.loadStructuredData("$key")');
    // Return empty JSON for manifests
    return parser('{}');
  }

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData) parser,
  ) async {
    print('DEBUG: TestAssetBundle.loadStructuredBinaryData("$key")');
    if (key.endsWith('.json')) {
      final bd = ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
      return parser(bd);
    }
    final bd = await load(key);
    return parser(bd);
  }
}

/// A stub UserController so LoginPage.find<UserController>() does not throw.
class StubUserController extends GetxController implements UserController {
  @override
  Future<void> loadRememberMe() async {
    print('DEBUG: StubUserController.loadRememberMe()');
  }

  @override
  Future<CommonResponse?> reqLogin(String id, String pw) async {
    print('DEBUG: StubUserController.reqLogin(id=$id, pw=$pw)');
    return CommonResponse(code: '0000', message: '', body: {});
  }

  @override
  Future<bool> reqGetRememberMe() async {
    print('DEBUG: StubUserController.reqGetRememberMe()');
    return false;
  }

  @override
  Future<String> reqGetLoginEmail() async {
    print('DEBUG: StubUserController.reqGetLoginEmail()');
    return '';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestAssetBundle _assetBundle;

  setUp(() {
    print('DEBUG: setUp - initialize TestWidgetsFlutterBinding & Get');
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    Get.reset();
    _assetBundle = TestAssetBundle();
    // Bind our stub globally
    Get.put<UserController>(StubUserController(), permanent: true);
  });

  tearDown(() {
    print('DEBUG: tearDown - close snackbars & reset Get');
    Get.closeAllSnackbars();
    Get.reset();
  });

  /// Pumps the LoginResetFinalPage wrapped in our test bundle.
  Future<void> _pumpResetFinalPage(WidgetTester tester) async {
    print('DEBUG: _pumpResetFinalPage - pumping LoginResetFinalPage');
    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _assetBundle,
        child: GetMaterialApp(
          home: const LoginResetFinalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders top bar, header, message and login button', (tester) async {
    print('=== TEST: renders UI elements ===');
    await _pumpResetFinalPage(tester);

    // Verify that all expected texts and the button are present
    expect(find.text('아이비스 FMS 관제 시스템'), findsOneWidget);
    expect(find.text('비밀번호 재설정'), findsOneWidget);
    expect(find.text('비밀번호 재설정이 완료되었습니다!'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '로그인'), findsOneWidget);
  });

  testWidgets('tapping "로그인" navigates to stub LoginPage', (tester) async {
    print('=== TEST: navigation on login tap ===');
    await tester.binding.setSurfaceSize(const Size(500, 800));

    // Set up named routes: reset-final -> our page, and login -> simple scaffold
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _assetBundle,
        child: GetMaterialApp(
          initialRoute: LoginResetFinalPage.routeName,
          getPages: [
            GetPage(
              name: LoginResetFinalPage.routeName,
              page: () => const LoginResetFinalPage(),
            ),
            GetPage(
              name: LoginPage.routeName,
              // Use a simple Scaffold to avoid layout issues in the real LoginPage
              page: () => const Scaffold(body: Center(child: Text('LOGIN'))),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    print('DEBUG: tapping 로그인 button');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    // Expect to find our simple 'LOGIN' text on the new route
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
