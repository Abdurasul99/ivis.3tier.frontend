// test/widgets/settings_widgets_test.dart
// 설정(SETTINGS) + 알림(NOTIFICATIONS) 영역 위젯 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// 실제 TabSettingProfile / TabSettingMember / PasswordChangeDialog 위젯은
// UserController / MemberController / LocaleController / Get.context! / SvgPicture
// 등 다수의 외부 의존성을 요구하므로, 본 테스트는 각 화면의 핵심 동작(렌더링 + 검증
// 로직 + 콜백 디스패치) 만을 격리한 Harness 위젯으로 추출하여 검증한다.
//
// 검증 대상:
//   - 프로필 렌더링(이름/메일/연락처/등급)
//   - 비밀번호 변경 다이얼로그 (열기/검증/일치확인)
//   - 로그아웃 버튼 → UserController.logout 호출
//   - 멤버 목록 렌더링 (승인 대기 / 승인 완료)
//   - 승인/거절/등급변경/삭제 버튼 → MemberController 호출
//   - 페이지네이션 (페이지 이동/카운트)
//   - 알림 패널 (열기/닫기/렌더/읽음/빈 상태)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. 테스트 전용 추상화 — 실제 Controller 대신 인터페이스 사용
// ─────────────────────────────────────────────────────────────────────────────

/// 유저(프로필) 서비스 — 비밀번호 변경 / 로그아웃
abstract class IUserService {
  String? get name;
  String? get email;
  String? get phoneNumber;
  String? get role;

  Future<String> changePassword(String oldPw, String newPw);
  Future<void> logout();
}

/// 멤버 서비스 — 승인/거절/등급변경/삭제/페이지로드
abstract class IMemberService {
  Future<List<MemberRow>> loadMembers(int page);
  Future<bool> approveMember(int id);
  Future<bool> rejectMember(int id);
  Future<bool> changeRole(int id, String role);
  Future<bool> deleteMember(int id);
}

/// 알림 서비스 — 목록/읽음 처리
abstract class INotificationService {
  Future<List<NotificationItem>> loadNotifications();
  Future<void> markAsRead(int id);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. 수기 Mock 클래스 — build_runner 없이 동작
// ─────────────────────────────────────────────────────────────────────────────

class MockUserService extends Mock implements IUserService {
  @override
  String? get name =>
      super.noSuchMethod(Invocation.getter(#name), returnValue: null) as String?;
  @override
  String? get email =>
      super.noSuchMethod(Invocation.getter(#email), returnValue: null) as String?;
  @override
  String? get phoneNumber =>
      super.noSuchMethod(Invocation.getter(#phoneNumber), returnValue: null) as String?;
  @override
  String? get role =>
      super.noSuchMethod(Invocation.getter(#role), returnValue: null) as String?;

  @override
  Future<String> changePassword(String? oldPw, String? newPw) =>
      super.noSuchMethod(
        Invocation.method(#changePassword, <Object?>[oldPw, newPw]),
        returnValue: Future<String>.value(''),
        returnValueForMissingStub: Future<String>.value(''),
      ) as Future<String>;

  @override
  Future<void> logout() => super.noSuchMethod(
        Invocation.method(#logout, <Object?>[]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;
}

class MockMemberService extends Mock implements IMemberService {
  @override
  Future<List<MemberRow>> loadMembers(int? page) => super.noSuchMethod(
        Invocation.method(#loadMembers, <Object?>[page]),
        returnValue: Future<List<MemberRow>>.value(<MemberRow>[]),
        returnValueForMissingStub: Future<List<MemberRow>>.value(<MemberRow>[]),
      ) as Future<List<MemberRow>>;

  @override
  Future<bool> approveMember(int? id) => super.noSuchMethod(
        Invocation.method(#approveMember, <Object?>[id]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;

  @override
  Future<bool> rejectMember(int? id) => super.noSuchMethod(
        Invocation.method(#rejectMember, <Object?>[id]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;

  @override
  Future<bool> changeRole(int? id, String? role) => super.noSuchMethod(
        Invocation.method(#changeRole, <Object?>[id, role]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;

  @override
  Future<bool> deleteMember(int? id) => super.noSuchMethod(
        Invocation.method(#deleteMember, <Object?>[id]),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>;
}

class MockNotificationService extends Mock implements INotificationService {
  @override
  Future<List<NotificationItem>> loadNotifications() => super.noSuchMethod(
        Invocation.method(#loadNotifications, <Object?>[]),
        returnValue: Future<List<NotificationItem>>.value(<NotificationItem>[]),
        returnValueForMissingStub: Future<List<NotificationItem>>.value(<NotificationItem>[]),
      ) as Future<List<NotificationItem>>;

  @override
  Future<void> markAsRead(int? id) => super.noSuchMethod(
        Invocation.method(#markAsRead, <Object?>[id]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. 도메인 모델 (테스트 격리용 단순 DTO)
// ─────────────────────────────────────────────────────────────────────────────

class MemberRow {
  final int id;
  final String name;
  final String userId;
  final String email;
  final String phoneNumber;
  String role; // 'admin' | 'user'
  final bool isApproved;

  MemberRow({
    required this.id,
    required this.name,
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.isApproved,
  });
}

class NotificationItem {
  final int id;
  final String title;
  final String body;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.isRead = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. 테스트 본문
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late MockUserService mockUser;
  late MockMemberService mockMember;
  late MockNotificationService mockNoti;
  late List<String> events;

  setUp(() {
    mockUser = MockUserService();
    mockMember = MockMemberService();
    mockNoti = MockNotificationService();
    events = <String>[];

    // 프로필 기본값 스텁
    when(mockUser.name).thenReturn('홍길동');
    when(mockUser.email).thenReturn('hong@example.com');
    when(mockUser.phoneNumber).thenReturn('010-1234-5678');
    when(mockUser.role).thenReturn('admin');
  });

  // ═════════════════════════════════════════════════════════════════════════
  // SETTINGS — 프로필 / 비밀번호 / 로그아웃 / 멤버
  // ═════════════════════════════════════════════════════════════════════════

  group('SettingsProfileHarness — 프로필 렌더링', () {
    testWidgets('1. 프로필에 이름/메일/연락처/등급이 모두 표시된다',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));

      // Act — 추가 액션 없음, 단순 렌더링 확인

      // Assert
      expect(find.text('홍길동'), findsOneWidget);
      expect(find.text('hong@example.com'), findsOneWidget);
      expect(find.text('010-1234-5678'), findsOneWidget);
      expect(find.text('관리자'), findsOneWidget);
    });

    testWidgets('2. 일반 권한일 때 등급 라벨이 "일반"으로 표시된다',
        (WidgetTester tester) async {
      // Arrange — 일반 권한 사용자로 재스텁
      when(mockUser.role).thenReturn('user');

      // Act
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));

      // Assert
      expect(find.text('일반'), findsOneWidget);
      expect(find.text('관리자'), findsNothing);
    });
  });

  group('SettingsProfileHarness — 비밀번호 변경 다이얼로그', () {
    testWidgets('3. "비밀번호 변경" 버튼 탭 → 다이얼로그가 열린다',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));

      // Act
      await tester.tap(find.byKey(const Key('change-password-button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('password-dialog')), findsOneWidget);
      expect(find.text('비밀번호 변경'), findsWidgets);
    });

    testWidgets('4. 비밀번호가 너무 짧으면 length 이벤트 발생',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));
      await tester.tap(find.byKey(const Key('change-password-button')));
      await tester.pumpAndSettle();

      // Act — 너무 짧은 비밀번호 입력
      await tester.enterText(find.byKey(const Key('current-pw')), 'old');
      await tester.enterText(find.byKey(const Key('new-pw')), '123');
      await tester.enterText(find.byKey(const Key('confirm-pw')), '123');
      await tester.tap(find.byKey(const Key('pw-confirm-button')));
      await tester.pump();

      // Assert
      expect(events, contains('pw_too_short'));
      verifyNever(mockUser.changePassword(any, any));
    });

    testWidgets('5. 새 비밀번호와 확인이 다르면 mismatch 이벤트 발생',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));
      await tester.tap(find.byKey(const Key('change-password-button')));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byKey(const Key('current-pw')), 'oldpw123');
      await tester.enterText(find.byKey(const Key('new-pw')), 'newpw1234');
      await tester.enterText(find.byKey(const Key('confirm-pw')), 'different1');
      await tester.tap(find.byKey(const Key('pw-confirm-button')));
      await tester.pump();

      // Assert
      expect(events, contains('pw_mismatch'));
      verifyNever(mockUser.changePassword(any, any));
    });

    testWidgets('6. 유효한 비밀번호 입력 → changePassword 호출 및 성공 이벤트',
        (WidgetTester tester) async {
      // Arrange
      when(mockUser.changePassword('oldpw1234', 'newpw1234'))
          .thenAnswer((_) async => 'changed password');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));
      await tester.tap(find.byKey(const Key('change-password-button')));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byKey(const Key('current-pw')), 'oldpw1234');
      await tester.enterText(find.byKey(const Key('new-pw')), 'newpw1234');
      await tester.enterText(find.byKey(const Key('confirm-pw')), 'newpw1234');
      await tester.tap(find.byKey(const Key('pw-confirm-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockUser.changePassword('oldpw1234', 'newpw1234')).called(1);
      expect(events, contains('pw_success'));
    });
  });

  group('SettingsProfileHarness — 로그아웃', () {
    testWidgets('7. "로그아웃" 버튼 탭 → UserController.logout 호출 + logout 이벤트',
        (WidgetTester tester) async {
      // Arrange
      when(mockUser.logout()).thenAnswer((_) async {});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsProfileHarness(service: mockUser, onEvent: events.add),
        ),
      ));

      // Act
      await tester.tap(find.byKey(const Key('logout-button')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockUser.logout()).called(1);
      expect(events, contains('logout'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 멤버 목록 — 렌더링 / 승인 / 거절 / 등급변경 / 삭제 / 페이지네이션
  // ───────────────────────────────────────────────────────────────────────

  List<MemberRow> sampleMembers() => <MemberRow>[
        MemberRow(
          id: 1,
          name: '김철수',
          userId: 'chulsoo',
          email: 'chulsoo@ex.com',
          phoneNumber: '010-1111-2222',
          role: 'user',
          isApproved: false,
        ),
        MemberRow(
          id: 2,
          name: '박영희',
          userId: 'younghee',
          email: 'younghee@ex.com',
          phoneNumber: '010-3333-4444',
          role: 'admin',
          isApproved: true,
        ),
      ];

  group('MemberListHarness — 렌더링', () {
    testWidgets('8. 멤버 목록이 행으로 렌더링된다', (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());

      // Act
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(service: mockMember, onEvent: events.add),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('김철수'), findsOneWidget);
      expect(find.text('박영희'), findsOneWidget);
      expect(find.byKey(const Key('member-row-1')), findsOneWidget);
      expect(find.byKey(const Key('member-row-2')), findsOneWidget);
    });
  });

  group('MemberListHarness — 승인/거절', () {
    testWidgets('9. 승인 버튼 탭 → approveMember 호출', (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());
      when(mockMember.approveMember(1)).thenAnswer((_) async => true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(service: mockMember, onEvent: events.add),
        ),
      ));
      await tester.pumpAndSettle();

      // Act — 승인 대기(id=1) 의 승인 버튼 탭
      await tester.tap(find.byKey(const Key('approve-1')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMember.approveMember(1)).called(1);
      expect(events, contains('approved_1'));
    });

    testWidgets('10. 거절 버튼 탭 → 확인 후 rejectMember 호출',
        (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());
      when(mockMember.rejectMember(1)).thenAnswer((_) async => true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(
            service: mockMember,
            onEvent: events.add,
            confirmReject: true, // 확인 다이얼로그 자동 승인
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('reject-1')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMember.rejectMember(1)).called(1);
      expect(events, contains('rejected_1'));
    });

    testWidgets('11. 거절 확인 다이얼로그에서 취소하면 rejectMember 호출되지 않음',
        (WidgetTester tester) async {
      // Arrange — confirmReject=false → 사용자 취소
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(
            service: mockMember,
            onEvent: events.add,
            confirmReject: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('reject-1')));
      await tester.pumpAndSettle();

      // Assert
      verifyNever(mockMember.rejectMember(any));
      expect(events, isNot(contains('rejected_1')));
    });
  });

  group('MemberListHarness — 등급 변경', () {
    testWidgets('12. 등급 드롭다운 변경 → changeMemberRole 호출',
        (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());
      when(mockMember.changeRole(2, '관리자'))
          .thenAnswer((_) async => true);
      when(mockMember.changeRole(2, '일반'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(service: mockMember, onEvent: events.add),
        ),
      ));
      await tester.pumpAndSettle();

      // Act — id=2 의 등급을 '일반' 으로 변경
      await tester.tap(find.byKey(const Key('role-dropdown-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반').last);
      await tester.pumpAndSettle();

      // Assert
      verify(mockMember.changeRole(2, '일반')).called(1);
      expect(events, contains('role_changed_2'));
    });
  });

  group('MemberListHarness — 삭제', () {
    testWidgets('13. 삭제 버튼 → 확인 시 deleteMember 호출',
        (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());
      when(mockMember.deleteMember(2)).thenAnswer((_) async => true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(
            service: mockMember,
            onEvent: events.add,
            confirmDelete: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Act — 승인된 멤버 id=2 삭제
      await tester.tap(find.byKey(const Key('delete-2')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMember.deleteMember(2)).called(1);
      expect(events, contains('deleted_2'));
    });

    testWidgets('14. 삭제 확인 취소 시 deleteMember 호출되지 않음',
        (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(
            service: mockMember,
            onEvent: events.add,
            confirmDelete: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('delete-2')));
      await tester.pumpAndSettle();

      // Assert
      verifyNever(mockMember.deleteMember(any));
    });
  });

  group('MemberListHarness — 페이지네이션', () {
    testWidgets('15. 다음 페이지 버튼 → 페이지 1 로드',
        (WidgetTester tester) async {
      // Arrange — 페이지 0,1 각각 다른 데이터
      when(mockMember.loadMembers(0))
          .thenAnswer((_) async => sampleMembers());
      when(mockMember.loadMembers(1)).thenAnswer(
        (_) async => <MemberRow>[
          MemberRow(
            id: 3,
            name: '이순신',
            userId: 'sunshin',
            email: 'sunshin@ex.com',
            phoneNumber: '010-9999-0000',
            role: 'user',
            isApproved: true,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(service: mockMember, onEvent: events.add),
        ),
      ));
      await tester.pumpAndSettle();

      // 초기 페이지 0 데이터 확인
      expect(find.text('김철수'), findsOneWidget);

      // Act — 다음 페이지로 이동
      await tester.tap(find.byKey(const Key('page-next')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMember.loadMembers(1)).called(1);
      expect(find.text('이순신'), findsOneWidget);
      expect(find.text('김철수'), findsNothing);
    });

    testWidgets('16. 페이지 카운터 텍스트 갱신',
        (WidgetTester tester) async {
      // Arrange
      when(mockMember.loadMembers(any))
          .thenAnswer((_) async => sampleMembers());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemberListHarness(service: mockMember, onEvent: events.add),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert (초기)
      expect(find.byKey(const Key('page-indicator')), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);

      // Act — 다음 페이지
      await tester.tap(find.byKey(const Key('page-next')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Page 2'), findsOneWidget);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS — 알림 패널
  // ═════════════════════════════════════════════════════════════════════════

  List<NotificationItem> sampleNotis() => <NotificationItem>[
        NotificationItem(id: 10, title: '새 멤버 가입', body: '홍길동님이 가입했습니다.'),
        NotificationItem(id: 11, title: '차량 경고', body: '속도 초과 감지', isRead: true),
      ];

  group('NotificationPanelHarness — 패널 열기/닫기', () {
    testWidgets('17. 벨 아이콘 클릭 → 패널이 열린다',
        (WidgetTester tester) async {
      // Arrange
      when(mockNoti.loadNotifications())
          .thenAnswer((_) async => sampleNotis());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationPanelHarness(
            service: mockNoti,
            onEvent: events.add,
          ),
        ),
      ));

      // Assert — 초기엔 패널 닫혀있음
      expect(find.byKey(const Key('noti-panel')), findsNothing);

      // Act — 벨 아이콘 탭
      await tester.tap(find.byKey(const Key('bell-icon')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('noti-panel')), findsOneWidget);
      verify(mockNoti.loadNotifications()).called(1);
    });

    testWidgets('18. 닫기 버튼 클릭 → 패널이 사라진다',
        (WidgetTester tester) async {
      // Arrange
      when(mockNoti.loadNotifications())
          .thenAnswer((_) async => sampleNotis());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationPanelHarness(
            service: mockNoti,
            onEvent: events.add,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('bell-icon')));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const Key('noti-close')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const Key('noti-panel')), findsNothing);
    });
  });

  group('NotificationPanelHarness — 항목 렌더링', () {
    testWidgets('19. 알림 항목이 제목 + 본문과 함께 렌더링된다',
        (WidgetTester tester) async {
      // Arrange
      when(mockNoti.loadNotifications())
          .thenAnswer((_) async => sampleNotis());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationPanelHarness(
            service: mockNoti,
            onEvent: events.add,
          ),
        ),
      ));

      // Act
      await tester.tap(find.byKey(const Key('bell-icon')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('새 멤버 가입'), findsOneWidget);
      expect(find.text('홍길동님이 가입했습니다.'), findsOneWidget);
      expect(find.text('차량 경고'), findsOneWidget);
    });

    testWidgets('20. 읽지 않은 알림에는 unread 점이 표시된다',
        (WidgetTester tester) async {
      // Arrange
      when(mockNoti.loadNotifications())
          .thenAnswer((_) async => sampleNotis());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationPanelHarness(
            service: mockNoti,
            onEvent: events.add,
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('bell-icon')));
      await tester.pumpAndSettle();

      // Assert — id=10 은 미읽음 (unread dot 존재), id=11 은 읽음 (dot 없음)
      expect(find.byKey(const Key('unread-dot-10')), findsOneWidget);
      expect(find.byKey(const Key('unread-dot-11')), findsNothing);
    });
  });

  group('NotificationPanelHarness — 읽음 처리', () {
    testWidgets('21. 알림 탭 → markAsRead 호출 + unread 점 제거',
        (WidgetTester tester) async {
      // Arrange
      when(mockNoti.loadNotifications())
          .thenAnswer((_) async => sampleNotis());
      when(mockNoti.markAsRead(10)).thenAnswer((_) async {});

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationPanelHarness(
            service: mockNoti,
            onEvent: events.add,
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('bell-icon')));
      await tester.pumpAndSettle();

      // Act — 미읽음 알림 탭
      await tester.tap(find.byKey(const Key('noti-item-10')));
      await tester.pumpAndSettle();

      // Assert
      verify(mockNoti.markAsRead(10)).called(1);
      expect(find.byKey(const Key('unread-dot-10')), findsNothing);
      expect(events, contains('read_10'));
    });
  });

  group('NotificationPanelHarness — 빈 상태', () {
    testWidgets('22. 알림이 없으면 "알림이 없습니다" 메시지가 표시된다',
        (WidgetTester tester) async {
      // Arrange
      when(mockNoti.loadNotifications())
          .thenAnswer((_) async => <NotificationItem>[]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationPanelHarness(
            service: mockNoti,
            onEvent: events.add,
          ),
        ),
      ));

      // Act
      await tester.tap(find.byKey(const Key('bell-icon')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('알림이 없습니다'), findsOneWidget);
      expect(find.byKey(const Key('noti-empty')), findsOneWidget);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. Harness 위젯들 — 실제 위젯과 동일한 검증/콜백 로직을 격리해 재구현
// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// SettingsProfileHarness — 프로필 + 비밀번호 + 로그아웃
// ─────────────────────────────────────────────────────────────────────────────
class SettingsProfileHarness extends StatelessWidget {
  final IUserService service;
  final void Function(String) onEvent;

  const SettingsProfileHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  String _roleLabel() => service.role == 'admin' ? '관리자' : '일반';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          // 프로필 정보 표시
          Text(service.name ?? ''),
          Text(service.email ?? ''),
          Text(service.phoneNumber ?? ''),
          Text(_roleLabel()),

          // 비밀번호 변경 버튼 — 다이얼로그 오픈
          ElevatedButton(
            key: const Key('change-password-button'),
            onPressed: () async {
              await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PasswordDialogHarness(
                  service: service,
                  onEvent: onEvent,
                ),
              );
            },
            child: const Text('비밀번호 변경'),
          ),

          // 로그아웃 버튼
          ElevatedButton(
            key: const Key('logout-button'),
            onPressed: () async {
              await service.logout();
              onEvent('logout');
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PasswordDialogHarness — 비밀번호 변경 다이얼로그 (검증 + 호출)
// ─────────────────────────────────────────────────────────────────────────────
class PasswordDialogHarness extends StatefulWidget {
  final IUserService service;
  final void Function(String) onEvent;

  const PasswordDialogHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  @override
  State<PasswordDialogHarness> createState() => _PasswordDialogHarnessState();
}

class _PasswordDialogHarnessState extends State<PasswordDialogHarness> {
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  static const int _minLength = 8;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    // 길이 검증
    if (_newCtrl.text.length < _minLength) {
      widget.onEvent('pw_too_short');
      return;
    }
    // 일치 검증
    if (_newCtrl.text != _confirmCtrl.text) {
      widget.onEvent('pw_mismatch');
      return;
    }

    final String result =
        await widget.service.changePassword(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;

    if (result == 'changed password') {
      widget.onEvent('pw_success');
      Navigator.of(context).pop();
    } else {
      widget.onEvent('pw_fail');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('password-dialog'),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('비밀번호 변경'),
              TextField(
                key: const Key('current-pw'),
                controller: _currentCtrl,
                obscureText: true,
              ),
              TextField(
                key: const Key('new-pw'),
                controller: _newCtrl,
                obscureText: true,
              ),
              TextField(
                key: const Key('confirm-pw'),
                controller: _confirmCtrl,
                obscureText: true,
              ),
              ElevatedButton(
                key: const Key('pw-confirm-button'),
                onPressed: _onConfirm,
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MemberListHarness — 멤버 목록 + 승인/거절/등급/삭제 + 페이지네이션
// ─────────────────────────────────────────────────────────────────────────────
class MemberListHarness extends StatefulWidget {
  final IMemberService service;
  final void Function(String) onEvent;
  final bool confirmReject;
  final bool confirmDelete;

  const MemberListHarness({
    super.key,
    required this.service,
    required this.onEvent,
    this.confirmReject = true,
    this.confirmDelete = true,
  });

  @override
  State<MemberListHarness> createState() => _MemberListHarnessState();
}

class _MemberListHarnessState extends State<MemberListHarness> {
  List<MemberRow> _rows = <MemberRow>[];
  int _page = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int page) async {
    setState(() => _loading = true);
    final List<MemberRow> rows = await widget.service.loadMembers(page);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _page = page;
      _loading = false;
    });
  }

  Future<bool> _confirmDialog(bool answer) async {
    // answer 파라미터로 사용자의 확인/취소 선택을 자동 응답한다.
    // (confirmReject / confirmDelete 플래그가 다이얼로그 응답을 결정)
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // 다음 프레임에 자동으로 answer 값으로 닫기
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(answer);
          }
        });
        return AlertDialog(
          content: const Text('confirm?'),
          actions: <Widget>[
            TextButton(
              key: const Key('confirm-yes'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('확인'),
            ),
            TextButton(
              key: const Key('confirm-no'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: <Widget>[
        // 페이지 카운터
        Padding(
          key: const Key('page-indicator'),
          padding: const EdgeInsets.all(8),
          child: Text('Page ${_page + 1}'),
        ),

        // 멤버 행들
        Expanded(
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (_, int idx) {
              final MemberRow m = _rows[idx];
              return _buildRow(m);
            },
          ),
        ),

        // 페이지네이션 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              key: const Key('page-prev'),
              onPressed: _page > 0 ? () => _load(_page - 1) : null,
              child: const Text('Prev'),
            ),
            TextButton(
              key: const Key('page-next'),
              onPressed: () => _load(_page + 1),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(MemberRow m) {
    return Container(
      key: Key('member-row-${m.id}'),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(m.name)),
          Expanded(child: Text(m.userId)),
          Expanded(child: Text(m.email)),
          Expanded(child: Text(m.phoneNumber)),

          // 등급 드롭다운 (승인된 멤버만)
          if (m.isApproved)
            DropdownButton<String>(
              key: Key('role-dropdown-${m.id}'),
              value: m.role == 'admin' ? '관리자' : '일반',
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: '관리자', child: Text('관리자')),
                DropdownMenuItem<String>(value: '일반', child: Text('일반')),
              ],
              onChanged: (String? value) async {
                if (value == null) return;
                final bool ok = await widget.service.changeRole(m.id, value);
                if (ok) {
                  setState(() {
                    m.role = (value == '관리자') ? 'admin' : 'user';
                  });
                  widget.onEvent('role_changed_${m.id}');
                }
              },
            )
          else
            Text(m.role == 'admin' ? '관리자' : '일반'),

          // 승인/거절 (미승인) 또는 삭제 (승인)
          if (!m.isApproved) ...<Widget>[
            ElevatedButton(
              key: Key('approve-${m.id}'),
              onPressed: () async {
                final bool ok = await widget.service.approveMember(m.id);
                if (ok) widget.onEvent('approved_${m.id}');
              },
              child: const Text('승인'),
            ),
            ElevatedButton(
              key: Key('reject-${m.id}'),
              onPressed: () async {
                final bool confirmed = await _confirmDialog(widget.confirmReject);
                if (!confirmed) return;
                final bool ok = await widget.service.rejectMember(m.id);
                if (ok) widget.onEvent('rejected_${m.id}');
              },
              child: const Text('거절'),
            ),
          ] else
            ElevatedButton(
              key: Key('delete-${m.id}'),
              onPressed: () async {
                final bool confirmed = await _confirmDialog(widget.confirmDelete);
                if (!confirmed) return;
                final bool ok = await widget.service.deleteMember(m.id);
                if (ok) widget.onEvent('deleted_${m.id}');
              },
              child: const Text('삭제'),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationPanelHarness — 벨 아이콘 + 패널 + 항목 + 빈 상태
// ─────────────────────────────────────────────────────────────────────────────
class NotificationPanelHarness extends StatefulWidget {
  final INotificationService service;
  final void Function(String) onEvent;

  const NotificationPanelHarness({
    super.key,
    required this.service,
    required this.onEvent,
  });

  @override
  State<NotificationPanelHarness> createState() =>
      _NotificationPanelHarnessState();
}

class _NotificationPanelHarnessState extends State<NotificationPanelHarness> {
  bool _open = false;
  List<NotificationItem> _items = <NotificationItem>[];

  Future<void> _openPanel() async {
    final List<NotificationItem> items =
        await widget.service.loadNotifications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _open = true;
    });
    widget.onEvent('panel_open');
  }

  void _closePanel() {
    setState(() => _open = false);
    widget.onEvent('panel_close');
  }

  Future<void> _onItemTap(NotificationItem item) async {
    if (item.isRead) return;
    await widget.service.markAsRead(item.id);
    if (!mounted) return;
    setState(() => item.isRead = true);
    widget.onEvent('read_${item.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // 벨 아이콘 (좌상단)
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            key: const Key('bell-icon'),
            icon: const Icon(Icons.notifications),
            onPressed: _openPanel,
          ),
        ),

        // 알림 패널
        if (_open)
          Positioned(
            top: 60,
            left: 8,
            child: Container(
              key: const Key('noti-panel'),
              width: 360,
              height: 480,
              color: Colors.white,
              child: Column(
                children: <Widget>[
                  // 헤더 (닫기)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('알림'),
                      ),
                      IconButton(
                        key: const Key('noti-close'),
                        icon: const Icon(Icons.close),
                        onPressed: _closePanel,
                      ),
                    ],
                  ),
                  // 본문
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            key: Key('noti-empty'),
                            child: Text('알림이 없습니다'),
                          )
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, int idx) {
                              final NotificationItem item = _items[idx];
                              return ListTile(
                                key: Key('noti-item-${item.id}'),
                                title: Text(item.title),
                                subtitle: Text(item.body),
                                trailing: item.isRead
                                    ? null
                                    : Container(
                                        key: Key('unread-dot-${item.id}'),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                onTap: () => _onItemTap(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
