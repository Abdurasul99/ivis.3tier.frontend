// test/widgets/dashboard_pagination_test.dart
//
// 대시보드 페이지네이션 UI 테스트 — Triple-A 패턴 (Arrange / Act / Assert)
//
// 실제 TabDashboard 의 페이지네이션 컴포넌트는 PlutoGrid + DashboardController
// 의존성이 무겁기 때문에, 페이지 이동(Prev/Next/Jump/페이지 번호) 의 콜백
// 디스패치를 검증하는 PaginationBarHarness 위젯을 추출하여 테스트한다.
//
// 검증 항목:
//   1. Chevron Prev → loadPrevPage 호출
//   2. Chevron Next → loadNextPage 호출
//   3. 페이지 번호 클릭 → changePage(page) 호출
//   4. Jump-to-page Enter → changePage 호출 (입력값 정수 파싱)
//   5. 페이지 번호 1 자체 클릭은 호출 안 됨 (현재와 동일)
//   6. 첫 페이지에서 Prev 비활성화
//   7. 마지막 페이지에서 Next 비활성화
//   8. 빈 입력 / 음수 입력 / 범위 초과 입력 → changePage 호출 안 됨
//   9. buildVisiblePages 같은 가시 페이지 목록 (1, 현재-1, 현재, 현재+1, last)
//   10. 로딩 중 Prev/Next 비활성화

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 페이지네이션 컨트롤러 인터페이스 — DashboardController 의 페이지 관련 API
// ─────────────────────────────────────────────────────────────────────────────
abstract class IPaginationController {
  Future<void> loadPrevPage();
  Future<void> loadNextPage();
  void changePage(int page);
}

class MockPaginationController extends Mock
    implements IPaginationController {
  @override
  Future<void> loadPrevPage() => super.noSuchMethod(
        Invocation.method(#loadPrevPage, <Object?>[]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> loadNextPage() => super.noSuchMethod(
        Invocation.method(#loadNextPage, <Object?>[]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  void changePage(int? page) => super.noSuchMethod(
        Invocation.method(#changePage, <Object?>[page]),
        returnValueForMissingStub: null,
      );
}

void main() {
  late MockPaginationController mockCtrl;

  setUp(() {
    mockCtrl = MockPaginationController();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required int currentPage,
    required int totalPages,
    bool isLoading = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaginationBarHarness(
            controller: mockCtrl,
            currentPage: currentPage,
            totalPages: totalPages,
            isLoading: isLoading,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Chevron Prev / Next 클릭 — loadPrevPage / loadNextPage 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('PaginationBarHarness — Chevron Prev/Next', () {
    testWidgets('중간 페이지에서 Prev 탭 → loadPrevPage 호출',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 3, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('chevron-prev')));
      await tester.pump();

      // Assert
      verify(mockCtrl.loadPrevPage()).called(1);
      verifyNever(mockCtrl.loadNextPage());
    });

    testWidgets('중간 페이지에서 Next 탭 → loadNextPage 호출',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 3, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('chevron-next')));
      await tester.pump();

      // Assert
      verify(mockCtrl.loadNextPage()).called(1);
      verifyNever(mockCtrl.loadPrevPage());
    });

    testWidgets('첫 페이지에서 Prev 비활성화 (탭해도 호출 안됨)',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 1, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('chevron-prev')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.loadPrevPage());
    });

    testWidgets('마지막 페이지에서 Next 비활성화 (탭해도 호출 안됨)',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 10, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('chevron-next')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.loadNextPage());
    });

    testWidgets('단일 페이지 (totalPages=1) → Prev/Next 둘 다 비활성화',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 1, totalPages: 1);

      // Act
      await tester.tap(find.byKey(const Key('chevron-prev')));
      await tester.tap(find.byKey(const Key('chevron-next')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.loadPrevPage());
      verifyNever(mockCtrl.loadNextPage());
    });

    testWidgets('로딩 중에는 Prev/Next 비활성화', (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester,
          currentPage: 5, totalPages: 10, isLoading: true);

      // Act
      await tester.tap(find.byKey(const Key('chevron-prev')));
      await tester.tap(find.byKey(const Key('chevron-next')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.loadPrevPage());
      verifyNever(mockCtrl.loadNextPage());
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 페이지 번호 클릭 — changePage 호출
  // ───────────────────────────────────────────────────────────────────────────
  group('PaginationBarHarness — 페이지 번호 클릭', () {
    testWidgets('가시 페이지 목록 렌더링: 1 / current-1 / current / current+1 / last',
        (WidgetTester tester) async {
      // Arrange — current=5, total=10 → 가시 페이지 {1, 4, 5, 6, 10}
      await pumpBar(tester, currentPage: 5, totalPages: 10);

      // Assert — 페이지 버튼 키 존재 확인
      expect(find.byKey(const Key('page-button-1')), findsOneWidget);
      expect(find.byKey(const Key('page-button-4')), findsOneWidget);
      expect(find.byKey(const Key('page-button-5')), findsOneWidget);
      expect(find.byKey(const Key('page-button-6')), findsOneWidget);
      expect(find.byKey(const Key('page-button-10')), findsOneWidget);
    });

    testWidgets('페이지 번호 4 탭 → changePage(4) 호출',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 5, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('page-button-4')));
      await tester.pump();

      // Assert
      verify(mockCtrl.changePage(4)).called(1);
    });

    testWidgets('마지막 페이지 번호 10 탭 → changePage(10) 호출',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 5, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('page-button-10')));
      await tester.pump();

      // Assert
      verify(mockCtrl.changePage(10)).called(1);
    });

    testWidgets('현재 페이지 번호 자체 탭 → changePage 호출 안됨 (no-op)',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 5, totalPages: 10);

      // Act
      await tester.tap(find.byKey(const Key('page-button-5')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });

    testWidgets('로딩 중 페이지 번호 탭 → changePage 호출 안됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester,
          currentPage: 5, totalPages: 10, isLoading: true);

      // Act
      await tester.tap(find.byKey(const Key('page-button-4')));
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Jump-to-page 입력 — Enter → changePage(parsed)
  // ───────────────────────────────────────────────────────────────────────────
  group('PaginationBarHarness — Jump-to-page 입력', () {
    testWidgets('유효한 페이지 번호 입력 + Enter → changePage(7) 호출',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 1, totalPages: 100);

      // Act
      await tester.enterText(find.byKey(const Key('jump-input')), '7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      verify(mockCtrl.changePage(7)).called(1);
    });

    testWidgets('범위 초과 입력 (200) but totalPages=100 → changePage(200) 호출 후 controller가 clamp 책임',
        (WidgetTester tester) async {
      // Arrange — UI 는 정수만 검증, clamp 는 controller 책임
      await pumpBar(tester, currentPage: 1, totalPages: 100);

      // Act
      await tester.enterText(find.byKey(const Key('jump-input')), '200');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert — controller 가 호출되었지만 인자 그대로 전달 (clamp 는 controller 내부에서)
      verify(mockCtrl.changePage(200)).called(1);
    });

    testWidgets('빈 입력 + Enter → changePage 호출 안됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 1, totalPages: 100);

      // Act
      await tester.enterText(find.byKey(const Key('jump-input')), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });

    testWidgets('숫자가 아닌 입력 (abc) → changePage 호출 안됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 1, totalPages: 100);

      // Act
      await tester.enterText(find.byKey(const Key('jump-input')), 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });

    testWidgets('0 또는 음수 입력 → changePage 호출 안됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 5, totalPages: 100);

      // Act — 0 입력
      await tester.enterText(find.byKey(const Key('jump-input')), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });

    testWidgets('로딩 중 Jump 입력 → changePage 호출 안됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester,
          currentPage: 1, totalPages: 100, isLoading: true);

      // Act
      await tester.enterText(find.byKey(const Key('jump-input')), '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });

    testWidgets('현재 페이지와 같은 번호 입력 → changePage 호출 안됨',
        (WidgetTester tester) async {
      // Arrange
      await pumpBar(tester, currentPage: 5, totalPages: 100);

      // Act
      await tester.enterText(find.byKey(const Key('jump-input')), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      verifyNever(mockCtrl.changePage(any));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PaginationBarHarness — buildVisiblePages 가시 페이지 목록 검증
  // ───────────────────────────────────────────────────────────────────────────
  group('PaginationBarHarness — buildVisiblePages 헬퍼', () {
    test('current=1, total=1 → [1]', () {
      // Arrange & Act
      final List<int> pages =
          buildVisiblePages(currentPage: 1, totalPages: 1);

      // Assert
      expect(pages, <int>[1]);
    });

    test('current=5, total=10 → [1, 4, 5, 6, 10]', () {
      // Arrange & Act
      final List<int> pages =
          buildVisiblePages(currentPage: 5, totalPages: 10);

      // Assert
      expect(pages, <int>[1, 4, 5, 6, 10]);
    });

    test('current=1, total=10 → [1, 2, 10]', () {
      // Arrange & Act
      final List<int> pages =
          buildVisiblePages(currentPage: 1, totalPages: 10);

      // Assert
      expect(pages, <int>[1, 2, 10]);
    });

    test('current=10, total=10 → [1, 9, 10]', () {
      // Arrange & Act
      final List<int> pages =
          buildVisiblePages(currentPage: 10, totalPages: 10);

      // Assert
      expect(pages, <int>[1, 9, 10]);
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// HARNESS / HELPERS
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// buildVisiblePages — DashboardController.buildVisiblePages 와 같은 로직
// (1, current-1, current, current+1, last) 의 정렬된 집합.
// ─────────────────────────────────────────────────────────────────────────────
List<int> buildVisiblePages({
  required int currentPage,
  required int totalPages,
}) {
  final int safe = totalPages < 1 ? 1 : totalPages;
  if (safe <= 1) return <int>[1];
  final Set<int> pages = <int>{
    1,
    safe,
    currentPage,
    currentPage - 1,
    currentPage + 1,
  };
  pages.removeWhere((int p) => p < 1 || p > safe);
  return pages.toList()..sort();
}

// ─────────────────────────────────────────────────────────────────────────────
// PaginationBarHarness — 페이지네이션 전용 격리 위젯
// Prev / 페이지 번호들 / Next / Jump-to-page 입력으로 구성됨.
// ─────────────────────────────────────────────────────────────────────────────
class PaginationBarHarness extends StatefulWidget {
  final IPaginationController controller;
  final int currentPage;
  final int totalPages;
  final bool isLoading;

  const PaginationBarHarness({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.totalPages,
    this.isLoading = false,
  });

  @override
  State<PaginationBarHarness> createState() => _PaginationBarHarnessState();
}

class _PaginationBarHarnessState extends State<PaginationBarHarness> {
  final TextEditingController _jumpCtrl = TextEditingController();

  @override
  void dispose() {
    _jumpCtrl.dispose();
    super.dispose();
  }

  bool get _hasPrev => widget.currentPage > 1;
  bool get _hasNext => widget.currentPage < widget.totalPages;
  bool get _enabled => !widget.isLoading;

  void _onPrev() {
    if (!_enabled || !_hasPrev) return;
    widget.controller.loadPrevPage();
  }

  void _onNext() {
    if (!_enabled || !_hasNext) return;
    widget.controller.loadNextPage();
  }

  void _onPageTap(int page) {
    if (!_enabled) return;
    if (page == widget.currentPage) return;
    widget.controller.changePage(page);
  }

  void _onJumpSubmitted(String raw) {
    if (!_enabled) return;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    if (parsed < 1) return;
    if (parsed == widget.currentPage) return;
    widget.controller.changePage(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final List<int> visible = buildVisiblePages(
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: const Key('chevron-prev'),
          onPressed: (_enabled && _hasPrev) ? _onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        ...visible.map(
          (int p) => TextButton(
            key: Key('page-button-$p'),
            onPressed: _enabled ? () => _onPageTap(p) : null,
            child: Text('$p'),
          ),
        ),
        IconButton(
          key: const Key('chevron-next'),
          onPressed: (_enabled && _hasNext) ? _onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            key: const Key('jump-input'),
            controller: _jumpCtrl,
            keyboardType: TextInputType.number,
            enabled: _enabled,
            onSubmitted: _onJumpSubmitted,
          ),
        ),
      ],
    );
  }
}
