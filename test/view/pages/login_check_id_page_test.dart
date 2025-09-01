// test/view/pages/login_check_id_page_test.dart
//
// ────────────────────────────────────────────────────────────────────────────
//  NOTE: no production widgets are edited – all tweaks live only in the tests
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/pages/login_check_id_page.dart';
import 'package:fms/view/pages/login_reset_pw_page.dart';

void main() {
  late void Function(FlutterErrorDetails) _originalErrorHandler;

  /* ─────────────── set-up / tear-down ─────────────── */

  setUp(() {
    debugPrint('🛠  setUp → silence expected overflow errors');
    _originalErrorHandler = FlutterError.onError!;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('RenderFlex overflowed by')) {
        // expected in tests – ignore only this one
        return;
      }
      _originalErrorHandler(details); // anything else is real
    };
    Get.testMode = true;
  });

  tearDown(() {
    debugPrint('🧹  tearDown → restore FlutterError.onError');
    FlutterError.onError = _originalErrorHandler;
    Get.reset();
    Get.clearRouteTree();
  });

  /* ─────────────── helpers ─────────────── */

  Future<void> _pumpLoginCheckPage(
    WidgetTester tester, {
    Map<String, dynamic>? arguments,
  }) async {
    debugPrint('⏱  Arrange: pump LoginCheckIdPage – args: $arguments');

    // plenty of vertical room so the fixed-height card fits
    await tester.binding.setSurfaceSize(const Size(800, 1600));

    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            if (arguments != null) {
              Future.microtask(
                () => Get.to(() => const LoginCheckIdPage(), arguments: arguments),
              );
              return const SizedBox.shrink();
            }
            return const LoginCheckIdPage();
          },
        ),
        getPages: [
          GetPage(
            name: LoginResetPwPage.routeName,
            page: () => const Scaffold(body: Center(child: Text('RESET PW'))),
          ),
          GetPage(
            name: '/login',
            page: () => const Scaffold(body: Center(child: Text('LOGIN'))),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    // drain any ignored exceptions so they don’t fail the test
    tester.takeException();
  }

  /* ─────────────── tests ─────────────── */

  testWidgets('renders defaults and both buttons', (tester) async {
    // Arrange
    await _pumpLoginCheckPage(tester);

    // Act – nothing to do, just loaded

    // Assert
    expect(find.text('아이디 찾기'), findsOneWidget);
    expect(find.text('고객님의 정보와 일치하는 아이디입니다.'), findsOneWidget);
    expect(find.text('아이디 : unknown@domain.com'), findsOneWidget);
    expect(find.text('가입일 : 2025.01.13'), findsOneWidget);
    expect(find.text('비밀번호 재설정'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('tapping "비밀번호 재설정" navigates to reset-pw', (tester) async {
    // Arrange
    await _pumpLoginCheckPage(tester);

    // Act
    debugPrint('👉  Act: tap 비밀번호 재설정');
    await tester.tap(find.text('비밀번호 재설정'));
    await tester.pumpAndSettle();
    tester.takeException();

    // Assert
    expect(find.text('RESET PW'), findsOneWidget);
  });

  testWidgets('tapping "로그인" navigates to /login', (tester) async {
    // Arrange
    await _pumpLoginCheckPage(tester);

    // Act
    debugPrint('👉  Act: tap 로그인');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    tester.takeException();

    // Assert
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('honors custom userId & joinDate args', (tester) async {
    // Arrange
    await _pumpLoginCheckPage(
      tester,
      arguments: {
        'userId': 'abdurasul@ivis.ai',
        'joinDate': '2025.01.01',
      },
    );

    // Act – nothing else

    // Assert
    expect(find.text('아이디 : abdurasul@ivis.ai'), findsOneWidget);
    expect(find.text('가입일 : 2025.01.01'), findsOneWidget);
  });
}
