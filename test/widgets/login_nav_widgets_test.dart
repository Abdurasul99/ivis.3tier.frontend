// test/widgets/login_nav_widgets_test.dart
// LOGIN + HEADER + SIDEBAR NAV 위젯 테스트 (Triple-A 패턴)
//
// 실제 페이지들(LoginPage / SignupRegisterPage / SignUpPage / HomePage)은
// UserController, MqttController, VehicleController, InfraController,
// RegisterController, ActivityController, LocaleController 등 다수의 GetxController
// 의존성과 HTTP / SharedPreferences / MQTT 클라이언트를 요구한다.
//
// flutter widget test 환경에서는 이러한 의존성을 모두 mock 으로 띄우는 것이 비용이
// 너무 크므로, 본 테스트는 기존 `login_widget_test.dart` 와 동일한 전략을 따른다:
//
//   1) 각 화면의 "핵심 동작(폼 검증, 토글, 콜백 디스패치)" 만을 추출한 Harness 위젯을
//      MaterialApp + Scaffold 안에서 마운트한다.
//   2) Mockito 로 서비스 호출을 가로채고, 디스패치된 이벤트 라벨을 검사한다.
//   3) 외부 의존성(EmptyTopBarView / GetX Snackbar / SharedPreferences) 은 직접
//      호출하지 않는다.
//
// 커버 영역
//   - LoginPage           : 아이디 / 비밀번호 / 보이기 토글 / 아이디 저장 /
//                           로그인 버튼 / 로딩 / 4 개 네비게이션 링크
//   - SignupRegisterPage  : 이름 / 메일 / 인증번호 전송 / 인증번호 확인 / 뒤로
//   - SignUpPage          : 4 개 필드 검증 / 비밀번호·확인 보이기 토글 /
//                           회원가입 / 뒤로
//   - HeaderBar           : 로고 텍스트 표시
//   - SideNav             : 4 개 메뉴 항목 / 선택 시 인덱스 변경 / unread 뱃지

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 테스트 전용 서비스 추상화 — Mockito 가 implements 할 수 있도록 인터페이스로 추출
// ─────────────────────────────────────────────────────────────────────────────
abstract class IAuthService {
  Future<bool> login(String userId, String password);
  Future<bool> sendRegisterCode(String name, String email);
  Future<bool> verifyRegisterCode(String email, String code);
  Future<bool> signUp(
    String id,
    String email,
    String name,
    String phone,
    String password,
  );
}

class MockAuthService extends Mock implements IAuthService {
  @override
  Future<bool> login(String? userId, String? password) =>
      super.noSuchMethod(
        Invocation.method(#login, <Object?>[userId, password]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;

  @override
  Future<bool> sendRegisterCode(String? name, String? email) =>
      super.noSuchMethod(
        Invocation.method(#sendRegisterCode, <Object?>[name, email]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;

  @override
  Future<bool> verifyRegisterCode(String? email, String? code) =>
      super.noSuchMethod(
        Invocation.method(#verifyRegisterCode, <Object?>[email, code]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;

  @override
  Future<bool> signUp(
    String? id,
    String? email,
    String? name,
    String? phone,
    String? password,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #signUp,
          <Object?>[id, email, name, phone, password],
        ),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;
}

void main() {
  late MockAuthService mockAuth;
  late List<String> dispatched;

  setUp(() {
    mockAuth = MockAuthService();
    dispatched = <String>[];
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 공용 헬퍼 — 각 Harness 를 MaterialApp 으로 감싸서 마운트
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginHarness(
            service: mockAuth,
            onEvent: dispatched.add,
          ),
        ),
      ),
    );
  }

  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupRegisterHarness(
            service: mockAuth,
            onEvent: dispatched.add,
          ),
        ),
      ),
    );
  }

  Future<void> pumpSignUp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignUpHarness(
            service: mockAuth,
            onEvent: dispatched.add,
            nameFromPrev: '홍길동',
            emailFromPrev: 'gildong@example.com',
          ),
        ),
      ),
    );
  }

  Future<void> pumpHeader(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HeaderHarness()),
      ),
    );
  }

  Future<void> pumpSideNav(
    WidgetTester tester, {
    int unreadBadge = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SideNavHarness(
            onEvent: dispatched.add,
            unreadBadge: unreadBadge,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1) 로그인 페이지
  // ═══════════════════════════════════════════════════════════════════════════
  group('로그인 페이지', () {
    testWidgets('아이디 / 비밀번호 / 로그인 버튼 / 아이디 저장 체크박스 렌더링',
        (WidgetTester tester) async {
      // Arrange & Act
      await pumpLogin(tester);

      // Assert
      expect(find.byKey(const Key('id-field')), findsOneWidget);
      expect(find.byKey(const Key('password-field')), findsOneWidget);
      expect(find.byKey(const Key('login-button')), findsOneWidget);
      expect(find.byKey(const Key('remember-me')), findsOneWidget);
    });

    testWidgets('아이디 비어있는 상태에서 로그인 누르면 empty_id 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Act
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_id'));
      verifyNever(mockAuth.login(any, any));
    });

    testWidgets('아이디만 있고 비밀번호 비어있으면 empty_password 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Act
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_password'));
      verifyNever(mockAuth.login(any, any));
    });

    testWidgets('유효한 입력으로 로그인 → service.login 호출 + success 이벤트',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuth.login('admin', 'pw1234'))
          .thenAnswer((_) async => true);
      await pumpLogin(tester);

      // Act
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'pw1234',
      );
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuth.login('admin', 'pw1234')).called(1);
      expect(dispatched, contains('success'));
    });

    testWidgets('로그인 실패 → fail 이벤트', (WidgetTester tester) async {
      // Arrange
      when(mockAuth.login(any, any)).thenAnswer((_) async => false);
      await pumpLogin(tester);

      // Act
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'badpw',
      );
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(dispatched, contains('fail'));
    });

    testWidgets('로그인 진행 중에는 CircularProgressIndicator 표시',
        (WidgetTester tester) async {
      // Arrange — 응답 지연
      when(mockAuth.login(any, any)).thenAnswer(
        (_) => Future<bool>.delayed(
          const Duration(milliseconds: 200),
          () => true,
        ),
      );
      await pumpLogin(tester);
      await tester.enterText(find.byKey(const Key('id-field')), 'admin');
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'pw1234',
      );

      // Act
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // 정리
    });

    testWidgets('비밀번호 보이기 토글 — 처음에는 visibility_off, 탭하면 visibility',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Assert — 초기 상태
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // Act — 토글 탭
      await tester.tap(find.byKey(const Key('toggle-password')));
      await tester.pump();

      // Assert — 토글 후 상태
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });

    testWidgets('아이디 저장 체크박스 탭 → toggle_remember 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Act
      await tester.tap(find.byKey(const Key('remember-me')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('toggle_remember'));
    });

    testWidgets('아이디 찾기 링크 탭 → nav_find_id 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Act
      await tester.tap(find.byKey(const Key('link-find-id')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_find_id'));
    });

    testWidgets('비밀번호 찾기 링크 탭 → nav_find_pw 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Act
      await tester.tap(find.byKey(const Key('link-find-pw')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_find_pw'));
    });

    testWidgets('회원가입 링크 탭 → nav_signup 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpLogin(tester);

      // Act
      await tester.tap(find.byKey(const Key('link-signup')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_signup'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2) 회원가입 1단계 (인증메일)
  // ═══════════════════════════════════════════════════════════════════════════
  group('회원가입 1단계 (이름/메일/인증)', () {
    testWidgets('이름 / 메일 / 인증번호 입력 필드 + 두 버튼 + 뒤로 링크 렌더링',
        (WidgetTester tester) async {
      // Arrange & Act
      await pumpRegister(tester);

      // Assert
      expect(find.byKey(const Key('name-field')), findsOneWidget);
      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.byKey(const Key('code-field')), findsOneWidget);
      expect(find.byKey(const Key('send-code-button')), findsOneWidget);
      expect(find.byKey(const Key('check-code-button')), findsOneWidget);
      expect(find.byKey(const Key('back-link')), findsOneWidget);
    });

    testWidgets('이름이 비어있을 때 인증메일 보내기 → empty_name 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpRegister(tester);

      // Act
      await tester.tap(find.byKey(const Key('send-code-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_name'));
      verifyNever(mockAuth.sendRegisterCode(any, any));
    });

    testWidgets('이름만 있고 메일 비어있으면 empty_email 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpRegister(tester);

      // Act
      await tester.enterText(find.byKey(const Key('name-field')), '홍길동');
      await tester.tap(find.byKey(const Key('send-code-button')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('empty_email'));
      verifyNever(mockAuth.sendRegisterCode(any, any));
    });

    testWidgets('유효한 이름·메일로 인증메일 발송 → service 호출 + send_success',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuth.sendRegisterCode('홍길동', 'a@b.com'))
          .thenAnswer((_) async => true);
      await pumpRegister(tester);

      // Act
      await tester.enterText(find.byKey(const Key('name-field')), '홍길동');
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'a@b.com',
      );
      await tester.tap(find.byKey(const Key('send-code-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuth.sendRegisterCode('홍길동', 'a@b.com')).called(1);
      expect(dispatched, contains('send_success'));
    });

    testWidgets('인증번호 비어있는 상태로 확인 → 에러 메시지 표시',
        (WidgetTester tester) async {
      // Arrange
      await pumpRegister(tester);
      await tester.enterText(find.byKey(const Key('name-field')), '홍길동');
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'a@b.com',
      );

      // Act
      await tester.tap(find.byKey(const Key('check-code-button')));
      await tester.pump();

      // Assert
      expect(find.text('인증번호를 입력해주세요.'), findsOneWidget);
      verifyNever(mockAuth.verifyRegisterCode(any, any));
    });

    testWidgets('인증번호 확인 성공 → verify_success 이벤트',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuth.verifyRegisterCode('a@b.com', '123456'))
          .thenAnswer((_) async => true);
      await pumpRegister(tester);

      // Act
      await tester.enterText(find.byKey(const Key('name-field')), '홍길동');
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'a@b.com',
      );
      await tester.enterText(
        find.byKey(const Key('code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('check-code-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuth.verifyRegisterCode('a@b.com', '123456')).called(1);
      expect(dispatched, contains('verify_success'));
    });

    testWidgets('인증번호 검증 실패 → 에러 메시지 표시',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuth.verifyRegisterCode(any, any))
          .thenAnswer((_) async => false);
      await pumpRegister(tester);

      // Act
      await tester.enterText(find.byKey(const Key('name-field')), '홍길동');
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'a@b.com',
      );
      await tester.enterText(find.byKey(const Key('code-field')), '000000');
      await tester.tap(find.byKey(const Key('check-code-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('인증번호가 유효하지 않습니다.'), findsOneWidget);
    });

    testWidgets('로그인으로 돌아가기 탭 → nav_back_to_login 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpRegister(tester);

      // Act
      await tester.tap(find.byKey(const Key('back-link')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_back_to_login'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3) 회원가입 2단계 (계정 정보 입력)
  // ═══════════════════════════════════════════════════════════════════════════
  group('회원가입 2단계 (계정 정보)', () {
    testWidgets('비어있는 폼으로 확인 → 모든 필드 에러 표시',
        (WidgetTester tester) async {
      // Arrange
      await pumpSignUp(tester);

      // Act
      await tester.tap(find.byKey(const Key('signup-button')));
      await tester.pump();

      // Assert — 4 가지 에러 메시지
      expect(find.text('사용이 불가능한 아이디입니다.'), findsOneWidget);
      expect(find.text('사용이 불가능한 비밀번호입니다.'), findsOneWidget);
      expect(find.text('비밀번호를 확인해주세요.'), findsOneWidget);
      expect(find.text('연락처를 입력해주세요.'), findsOneWidget);
      verifyNever(mockAuth.signUp(any, any, any, any, any));
    });

    testWidgets('비밀번호와 확인이 다르면 비밀번호 확인 에러',
        (WidgetTester tester) async {
      // Arrange
      await pumpSignUp(tester);

      // Act
      await tester.enterText(find.byKey(const Key('signup-id')), 'newuser');
      await tester.enterText(find.byKey(const Key('signup-pw')), 'pw1234');
      await tester.enterText(
        find.byKey(const Key('signup-pw-confirm')),
        'differ',
      );
      await tester.enterText(
        find.byKey(const Key('signup-phone')),
        '01012345678',
      );
      await tester.tap(find.byKey(const Key('signup-button')));
      await tester.pump();

      // Assert
      expect(find.text('비밀번호를 확인해주세요.'), findsOneWidget);
      verifyNever(mockAuth.signUp(any, any, any, any, any));
    });

    testWidgets('비밀번호 보이기 토글 — eye_slash ↔ eye 변경',
        (WidgetTester tester) async {
      // Arrange
      await pumpSignUp(tester);

      // Assert — 초기에는 hidden 상태(아이콘 = eye_slash)
      expect(find.byKey(const Key('pw-toggle-icon-hidden')), findsOneWidget);
      expect(find.byKey(const Key('pw-toggle-icon-shown')), findsNothing);

      // Act
      await tester.tap(find.byKey(const Key('toggle-pw')));
      await tester.pump();

      // Assert
      expect(find.byKey(const Key('pw-toggle-icon-shown')), findsOneWidget);
      expect(find.byKey(const Key('pw-toggle-icon-hidden')), findsNothing);
    });

    testWidgets('비밀번호 확인 보이기 토글 독립 동작',
        (WidgetTester tester) async {
      // Arrange
      await pumpSignUp(tester);

      // Act — 확인 필드만 토글
      await tester.tap(find.byKey(const Key('toggle-pw-confirm')));
      await tester.pump();

      // Assert — pw-confirm 만 shown, pw 는 hidden 유지
      expect(
        find.byKey(const Key('pw-confirm-toggle-icon-shown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pw-toggle-icon-hidden')),
        findsOneWidget,
      );
    });

    testWidgets('모든 필드 유효 + 비밀번호 일치 → service.signUp 호출 + success',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuth.signUp(
        'newuser',
        'gildong@example.com',
        '홍길동',
        '01012345678',
        'pw1234',
      )).thenAnswer((_) async => true);
      await pumpSignUp(tester);

      // Act
      await tester.enterText(find.byKey(const Key('signup-id')), 'newuser');
      await tester.enterText(find.byKey(const Key('signup-pw')), 'pw1234');
      await tester.enterText(
        find.byKey(const Key('signup-pw-confirm')),
        'pw1234',
      );
      await tester.enterText(
        find.byKey(const Key('signup-phone')),
        '01012345678',
      );
      await tester.tap(find.byKey(const Key('signup-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuth.signUp(
        'newuser',
        'gildong@example.com',
        '홍길동',
        '01012345678',
        'pw1234',
      )).called(1);
      expect(dispatched, contains('signup_success'));
    });

    testWidgets('회원가입 실패 → fail 이벤트', (WidgetTester tester) async {
      // Arrange
      when(mockAuth.signUp(any, any, any, any, any))
          .thenAnswer((_) async => false);
      await pumpSignUp(tester);

      // Act
      await tester.enterText(find.byKey(const Key('signup-id')), 'newuser');
      await tester.enterText(find.byKey(const Key('signup-pw')), 'pw1234');
      await tester.enterText(
        find.byKey(const Key('signup-pw-confirm')),
        'pw1234',
      );
      await tester.enterText(
        find.byKey(const Key('signup-phone')),
        '01012345678',
      );
      await tester.tap(find.byKey(const Key('signup-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(dispatched, contains('signup_fail'));
    });

    testWidgets('로그인으로 돌아가기 탭 → nav_back_to_login',
        (WidgetTester tester) async {
      // Arrange
      await pumpSignUp(tester);

      // Act
      await tester.tap(find.byKey(const Key('signup-back-link')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_back_to_login'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4) Header Bar
  // ═══════════════════════════════════════════════════════════════════════════
  group('헤더 바', () {
    testWidgets('3Tier 로고 텍스트 표시', (WidgetTester tester) async {
      // Arrange & Act
      await pumpHeader(tester);

      // Assert
      expect(find.text('3Tier'), findsOneWidget);
    });

    testWidgets('헤더 컨테이너 높이 60', (WidgetTester tester) async {
      // Arrange & Act
      await pumpHeader(tester);

      // Assert
      final Container container = tester.widget<Container>(
        find.byKey(const Key('header-container')),
      );
      expect(container.constraints?.minHeight, 60);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5) 사이드 네비게이션
  // ═══════════════════════════════════════════════════════════════════════════
  group('사이드 네비게이션', () {
    testWidgets('4개 메뉴 항목 렌더링 (대시보드 / 장치 관리 / 활동 / 설정)',
        (WidgetTester tester) async {
      // Arrange & Act
      await pumpSideNav(tester);

      // Assert
      expect(find.text('대시보드'), findsOneWidget);
      expect(find.text('장치 관리'), findsOneWidget);
      expect(find.text('활동'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
    });

    testWidgets('처음에는 대시보드(인덱스 0) 가 선택됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpSideNav(tester);

      // Act (별도 동작 없음)

      // Assert — 선택된 인디케이터는 인덱스 0 메뉴 항목에만 존재
      expect(find.byKey(const Key('selected-bar-0')), findsOneWidget);
      expect(find.byKey(const Key('selected-bar-1')), findsNothing);
    });

    testWidgets('장치 관리 항목 탭 → 인덱스 1로 변경 + nav_1 이벤트',
        (WidgetTester tester) async {
      // Arrange
      await pumpSideNav(tester);

      // Act
      await tester.tap(find.byKey(const Key('menu-item-1')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_1'));
      expect(find.byKey(const Key('selected-bar-1')), findsOneWidget);
      expect(find.byKey(const Key('selected-bar-0')), findsNothing);
    });

    testWidgets('활동 메뉴에 unread 뱃지 표시', (WidgetTester tester) async {
      // Arrange & Act — unread 3개
      await pumpSideNav(tester, unreadBadge: 3);

      // Assert
      expect(find.byKey(const Key('unread-badge-2')), findsOneWidget);
    });

    testWidgets('unread 0개일 때 뱃지 없음', (WidgetTester tester) async {
      // Arrange & Act
      await pumpSideNav(tester);

      // Assert
      expect(find.byKey(const Key('unread-badge-2')), findsNothing);
    });

    testWidgets('설정 메뉴 탭 → 인덱스 3 선택', (WidgetTester tester) async {
      // Arrange
      await pumpSideNav(tester);

      // Act
      await tester.tap(find.byKey(const Key('menu-item-3')));
      await tester.pump();

      // Assert
      expect(dispatched, contains('nav_3'));
      expect(find.byKey(const Key('selected-bar-3')), findsOneWidget);
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Harness 위젯들 — 실제 페이지와 동일한 로직을 의존성 주입 형태로 추출
// ═════════════════════════════════════════════════════════════════════════════

// 1) 로그인 화면 Harness
class LoginHarness extends StatefulWidget {
  final IAuthService service;
  final void Function(String event) onEvent;

  const LoginHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  @override
  State<LoginHarness> createState() => _LoginHarnessState();
}

class _LoginHarnessState extends State<LoginHarness> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  bool _checkRememberMe = false;
  bool _showPassword = false;
  bool _loggingIn = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_idCtrl.text.isEmpty) {
      widget.onEvent('empty_id');
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      widget.onEvent('empty_password');
      return;
    }
    setState(() => _loggingIn = true);
    final bool ok = await widget.service.login(
      _idCtrl.text.trim(),
      _pwCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loggingIn = false);
    widget.onEvent(ok ? 'success' : 'fail');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          TextField(
            key: const Key('id-field'),
            controller: _idCtrl,
          ),
          TextField(
            key: const Key('password-field'),
            controller: _pwCtrl,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              suffixIcon: GestureDetector(
                key: const Key('toggle-password'),
                onTap: () =>
                    setState(() => _showPassword = !_showPassword),
                child: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          GestureDetector(
            key: const Key('remember-me'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _checkRememberMe = !_checkRememberMe);
              widget.onEvent('toggle_remember');
            },
            child: Row(
              children: <Widget>[
                Icon(
                  _checkRememberMe
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                const Text('아이디 저장'),
              ],
            ),
          ),
          if (_loggingIn) const CircularProgressIndicator(),
          ElevatedButton(
            key: const Key('login-button'),
            onPressed: _loggingIn ? null : _onLogin,
            child: const Text('로그인'),
          ),
          GestureDetector(
            key: const Key('link-find-id'),
            onTap: () => widget.onEvent('nav_find_id'),
            child: const Text('아이디 찾기'),
          ),
          GestureDetector(
            key: const Key('link-find-pw'),
            onTap: () => widget.onEvent('nav_find_pw'),
            child: const Text('비밀번호 찾기'),
          ),
          GestureDetector(
            key: const Key('link-signup'),
            onTap: () => widget.onEvent('nav_signup'),
            child: const Text('회원가입'),
          ),
        ],
      ),
    );
  }
}

// 2) 회원가입 1단계 Harness
class SignupRegisterHarness extends StatefulWidget {
  final IAuthService service;
  final void Function(String event) onEvent;

  const SignupRegisterHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  @override
  State<SignupRegisterHarness> createState() => _SignupRegisterHarnessState();
}

class _SignupRegisterHarnessState extends State<SignupRegisterHarness> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String _codeErr = '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    if (_name.text.trim().isEmpty) {
      widget.onEvent('empty_name');
      return;
    }
    if (_email.text.trim().isEmpty) {
      widget.onEvent('empty_email');
      return;
    }
    final bool ok =
        await widget.service.sendRegisterCode(_name.text.trim(), _email.text.trim());
    widget.onEvent(ok ? 'send_success' : 'send_fail');
  }

  Future<void> _onCheckCode() async {
    setState(() => _codeErr = '');
    if (_code.text.trim().isEmpty) {
      setState(() => _codeErr = '인증번호를 입력해주세요.');
      return;
    }
    final bool ok = await widget.service.verifyRegisterCode(
      _email.text.trim(),
      _code.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _codeErr = '인증번호가 유효하지 않습니다.');
      return;
    }
    widget.onEvent('verify_success');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          TextField(key: const Key('name-field'), controller: _name),
          TextField(key: const Key('email-field'), controller: _email),
          OutlinedButton(
            key: const Key('send-code-button'),
            onPressed: _onSendCode,
            child: const Text('인증메일 보내기'),
          ),
          TextField(key: const Key('code-field'), controller: _code),
          if (_codeErr.isNotEmpty) Text(_codeErr),
          ElevatedButton(
            key: const Key('check-code-button'),
            onPressed: _onCheckCode,
            child: const Text('확인'),
          ),
          GestureDetector(
            key: const Key('back-link'),
            onTap: () => widget.onEvent('nav_back_to_login'),
            child: const Text('← 로그인으로 돌아가기'),
          ),
        ],
      ),
    );
  }
}

// 3) 회원가입 2단계 Harness
class SignUpHarness extends StatefulWidget {
  final IAuthService service;
  final void Function(String event) onEvent;
  final String nameFromPrev;
  final String emailFromPrev;

  const SignUpHarness({
    super.key,
    required this.service,
    required this.onEvent,
    required this.nameFromPrev,
    required this.emailFromPrev,
  });

  @override
  State<SignUpHarness> createState() => _SignUpHarnessState();
}

class _SignUpHarnessState extends State<SignUpHarness> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _pw = TextEditingController();
  final TextEditingController _pwConfirm = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  bool _showPw = false;
  bool _showPwConfirm = false;

  String _idErr = '';
  String _pwErr = '';
  String _pwConfirmErr = '';
  String _phoneErr = '';

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    _pwConfirm.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    setState(() {
      _idErr = '';
      _pwErr = '';
      _pwConfirmErr = '';
      _phoneErr = '';
    });

    final String idVal = _id.text.trim();
    final String pwVal = _pw.text.trim();
    final String pw2Val = _pwConfirm.text.trim();
    final String phoneVal = _phone.text.trim();

    bool hasError = false;
    if (idVal.isEmpty) {
      setState(() => _idErr = '사용이 불가능한 아이디입니다.');
      hasError = true;
    }
    if (pwVal.isEmpty) {
      setState(() => _pwErr = '사용이 불가능한 비밀번호입니다.');
      hasError = true;
    }
    if (pw2Val.isEmpty || pw2Val != pwVal) {
      setState(() => _pwConfirmErr = '비밀번호를 확인해주세요.');
      hasError = true;
    }
    if (phoneVal.isEmpty) {
      setState(() => _phoneErr = '연락처를 입력해주세요.');
      hasError = true;
    }
    if (hasError) return;

    final bool ok = await widget.service.signUp(
      idVal,
      widget.emailFromPrev,
      widget.nameFromPrev,
      phoneVal,
      pwVal,
    );
    if (!mounted) return;
    widget.onEvent(ok ? 'signup_success' : 'signup_fail');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          TextField(key: const Key('signup-id'), controller: _id),
          if (_idErr.isNotEmpty) Text(_idErr),
          TextField(
            key: const Key('signup-pw'),
            controller: _pw,
            obscureText: !_showPw,
            decoration: InputDecoration(
              suffixIcon: GestureDetector(
                key: const Key('toggle-pw'),
                onTap: () => setState(() => _showPw = !_showPw),
                child: Icon(
                  _showPw ? Icons.visibility : Icons.visibility_off,
                  // 아이콘 마커 키 — 테스트에서 구분 용도
                  key: _showPw
                      ? const Key('pw-toggle-icon-shown')
                      : const Key('pw-toggle-icon-hidden'),
                ),
              ),
            ),
          ),
          if (_pwErr.isNotEmpty) Text(_pwErr),
          TextField(
            key: const Key('signup-pw-confirm'),
            controller: _pwConfirm,
            obscureText: !_showPwConfirm,
            decoration: InputDecoration(
              suffixIcon: GestureDetector(
                key: const Key('toggle-pw-confirm'),
                onTap: () =>
                    setState(() => _showPwConfirm = !_showPwConfirm),
                child: Icon(
                  _showPwConfirm ? Icons.visibility : Icons.visibility_off,
                  key: _showPwConfirm
                      ? const Key('pw-confirm-toggle-icon-shown')
                      : const Key('pw-confirm-toggle-icon-hidden'),
                ),
              ),
            ),
          ),
          if (_pwConfirmErr.isNotEmpty) Text(_pwConfirmErr),
          TextField(key: const Key('signup-phone'), controller: _phone),
          if (_phoneErr.isNotEmpty) Text(_phoneErr),
          ElevatedButton(
            key: const Key('signup-button'),
            onPressed: _onSignUp,
            child: const Text('확인'),
          ),
          GestureDetector(
            key: const Key('signup-back-link'),
            onTap: () => widget.onEvent('nav_back_to_login'),
            child: const Text('← 로그인으로 돌아가기'),
          ),
        ],
      ),
    );
  }
}

// 4) 헤더 바 Harness — EmptyTopBarView 의 기본 구조만 추출 (SVG 의존성 제거)
class HeaderHarness extends StatelessWidget {
  const HeaderHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('header-container'),
      constraints: const BoxConstraints(
        minHeight: 60,
        maxHeight: 60,
      ),
      color: Colors.white,
      alignment: Alignment.centerLeft,
      child: Row(
        children: const <Widget>[
          SizedBox(width: 24),
          Icon(Icons.layers, size: 24),
          SizedBox(width: 16),
          Text(
            '3Tier',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          Spacer(),
          SizedBox(width: 24),
        ],
      ),
    );
  }
}

// 5) 사이드 네비게이션 Harness — HomePage.buildSideMenu 의 핵심 동작 추출
class SideNavHarness extends StatefulWidget {
  final void Function(String event) onEvent;
  final int unreadBadge;

  const SideNavHarness({
    super.key,
    required this.onEvent,
    this.unreadBadge = 0,
  });

  @override
  State<SideNavHarness> createState() => _SideNavHarnessState();
}

class _SideNavHarnessState extends State<SideNavHarness> {
  int selectedMenuIndex = 0;

  static const List<String> titles = <String>[
    '대시보드',
    '장치 관리',
    '활동',
    '설정',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: List<Widget>.generate(titles.length, (int index) {
          final bool selected = selectedMenuIndex == index;
          final bool hasBadge = index == 2 && widget.unreadBadge > 0;
          return GestureDetector(
            key: Key('menu-item-$index'),
            onTap: () {
              setState(() => selectedMenuIndex = index);
              widget.onEvent('nav_$index');
            },
            child: Container(
              height: 80,
              alignment: Alignment.center,
              color: selected
                  ? const Color(0xFFF3F4F6)
                  : Colors.white,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          const Icon(Icons.dashboard, size: 26),
                          if (hasBadge)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                key: Key('unread-badge-$index'),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFC42B1C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(titles[index]),
                    ],
                  ),
                  if (selected)
                    Positioned(
                      left: 0,
                      top: 10,
                      bottom: 10,
                      child: Container(
                        key: Key('selected-bar-$index'),
                        width: 4,
                        color: const Color(0xFF005CB2),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
