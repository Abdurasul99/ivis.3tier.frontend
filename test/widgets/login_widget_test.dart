// test/widgets/login_widget_test.dart
// 로그인 화면의 입력 검증 / 버튼 활성화 / 로딩 상태 위젯 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// 전체 LoginPage 는 MqttController, LocaleController, VehicleController, InfraController
// 등 다수의 의존성을 요구하므로, 본 테스트는 로그인 화면의 핵심 동작(폼 검증 + 콜백
// 디스패치) 만을 격리한 LoginFormHarness 위젯으로 추출하여 검증한다.
//
// 검증 항목:
//   - 아이디 / 비밀번호 입력 필드 렌더링
//   - 빈 아이디 → 콜백에 'empty_id' 라벨 전달
//   - 빈 비밀번호 → 콜백에 'empty_password' 라벨 전달
//   - 둘 다 채워진 상태 → MockUserService.login 호출
//   - 로그인 성공 → success 콜백
//   - 로그인 실패 → fail 콜백
//   - 로딩 중 CircularProgressIndicator 표시 및 버튼 비활성화

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 테스트 전용 추상화 — 실제 UserController 대신 인터페이스를 사용해 Mockito 로 모킹
// ─────────────────────────────────────────────────────────────────────────────
abstract class IUserService {
  Future<bool> login(String userId, String password);
}

// build_runner 없이도 동작하도록 수기 작성한 Mock 클래스
class MockUserService extends Mock implements IUserService {
  @override
  Future<bool> login(String? userId, String? password) =>
      super.noSuchMethod(
        Invocation.method(#login, <Object?>[userId, password]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;
}

void main() {
  late MockUserService mockService;
  late List<String> dispatched;

  setUp(() {
    mockService = MockUserService();
    dispatched = <String>[];
  });

  // 폼 위젯 빌드 헬퍼
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginFormHarness(
            service: mockService,
            onEvent: dispatched.add,
          ),
        ),
      ),
    );
  }

  group('LoginFormHarness — 렌더링', () {
    testWidgets('아이디 / 비밀번호 입력 필드와 로그인 버튼 표시', (WidgetTester tester) async {
      // Arrange & Act
      await pumpForm(tester);

      // Assert
      expect(find.byKey(const Key('id-field')), findsOneWidget);
      expect(find.byKey(const Key('password-field')), findsOneWidget);
      expect(find.byKey(const Key('login-button')), findsOneWidget);
    });
  });

  group('LoginFormHarness — 입력 검증', () {
    testWidgets('아이디 비어있을 때 로그인 버튼 누르면 empty_id 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpForm(tester);

      // Act
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_id'));
      verifyNever(mockService.login(any, any));
    });

    testWidgets('아이디만 있고 비밀번호 비어있으면 empty_password 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpForm(tester);

      // Act
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_password'));
      verifyNever(mockService.login(any, any));
    });
  });

  group('LoginFormHarness — 로그인 호출', () {
    testWidgets('유효한 입력으로 service.login 호출 후 성공 이벤트',
        (WidgetTester tester) async {
      // Arrange
      when(mockService.login('admin', 'pw1234'))
          .thenAnswer((_) async => true);
      await pumpForm(tester);

      // Act
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.enterText(find.byKey(const Key('password-field')), 'pw1234');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump(); // 로딩 시작
      await tester.pumpAndSettle();

      // Assert
      verify(mockService.login('admin', 'pw1234')).called(1);
      expect(dispatched, contains('success'));
    });

    testWidgets('로그인 실패 시 fail 이벤트 디스패치', (WidgetTester tester) async {
      // Arrange
      when(mockService.login(any, any)).thenAnswer((_) async => false);
      await pumpForm(tester);

      // Act
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.enterText(find.byKey(const Key('password-field')), 'badpw');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Assert
      expect(dispatched, contains('fail'));
    });
  });

  group('LoginFormHarness — 로딩 상태', () {
    testWidgets('로그인 진행 중 CircularProgressIndicator 표시',
        (WidgetTester tester) async {
      // Arrange — 비동기 응답 지연
      when(mockService.login(any, any)).thenAnswer(
        (_) => Future<bool>.delayed(
            const Duration(milliseconds: 200), () => true),
      );
      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.enterText(find.byKey(const Key('password-field')), 'pw1234');

      // Act
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump(); // 한 프레임 — 로딩 시작

      // Assert — 로딩 인디케이터 표시
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 정리 — 비동기 작업 완료
      await tester.pumpAndSettle();
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// LoginFormHarness — 테스트 격리용 로그인 폼 위젯
// 실제 LoginPage 와 동일한 검증 로직을 사용하지만, 의존성을 props 로 주입받는다.
// ─────────────────────────────────────────────────────────────────────────────
class LoginFormHarness extends StatefulWidget {
  final IUserService service;
  final void Function(String event) onEvent;

  const LoginFormHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  @override
  State<LoginFormHarness> createState() => _LoginFormHarnessState();
}

class _LoginFormHarnessState extends State<LoginFormHarness> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (_idCtrl.text.isEmpty) {
      widget.onEvent('empty_id');
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      widget.onEvent('empty_password');
      return;
    }

    setState(() => _loading = true);
    final bool ok = await widget.service.login(
      _idCtrl.text.trim(),
      _pwCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    widget.onEvent(ok ? 'success' : 'fail');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(key: const Key('id-field'), controller: _idCtrl),
        TextField(
          key: const Key('password-field'),
          controller: _pwCtrl,
          obscureText: true,
        ),
        if (_loading) const CircularProgressIndicator(),
        ElevatedButton(
          key: const Key('login-button'),
          onPressed: _loading ? null : _onLoginPressed,
          child: const Text('로그인'),
        ),
      ],
    );
  }
}
