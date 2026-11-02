// test/widgets/header_popover_exclusive_test.dart
//
// 헤더 팝오버(알림 / 프로필) 상호 배타 동작 회귀 테스트 — Triple-A 패턴
//
// 배경 (2026-08-10 UI 버그):
//   벨 아이콘 탭 핸들러는 프로필 패널을 닫아 주는데, 프로필 아이콘 탭 핸들러는
//   알림 패널을 닫지 않았다. 그래서 "벨 → 프로필" 순서로 누르면 두 패널이
//   화면에 겹쳐서 떴다.
//   수정: 프로필 탭도 알림 패널을 닫아 항상 하나만 열리도록 대칭을 맞췄다.
//
// home_page.dart 는 다수의 컨트롤러/네트워크에 의존해 위젯 전체를 띄우기 어렵다.
// 대신 두 핸들러의 상태 전이 규칙을 그대로 옮겨와 불변식을 고정한다:
//   "어느 순서로 눌러도 동시에 열린 패널은 최대 1개"

import 'package:flutter_test/flutter_test.dart';

/// home_page.dart 의 벨/프로필 탭 핸들러와 동일한 상태 전이.
class HeaderPopoverState {
  bool isBellPanelOpen = false;
  bool isProfileMenuVisible = false;

  /// 벨 아이콘 탭 — 열릴 때 프로필을 닫는다.
  void tapBell() {
    isBellPanelOpen = !isBellPanelOpen;
    if (isBellPanelOpen) {
      if (isProfileMenuVisible) isProfileMenuVisible = false;
    }
  }

  /// 프로필 아이콘 탭 — 열릴 때 알림을 닫는다(2026-08-10 수정).
  void tapProfile() {
    isProfileMenuVisible = !isProfileMenuVisible;
    if (isProfileMenuVisible) {
      if (isBellPanelOpen) isBellPanelOpen = false;
    }
  }

  /// 패널 바깥 탭 — 둘 다 닫는다.
  void tapOutside() {
    isBellPanelOpen = false;
    isProfileMenuVisible = false;
  }

  int get openCount =>
      (isBellPanelOpen ? 1 : 0) + (isProfileMenuVisible ? 1 : 0);
}

void main() {
  late HeaderPopoverState state;

  setUp(() {
    state = HeaderPopoverState();
  });

  group('상호 배타 — 한 번에 하나만 열린다', () {
    test('벨 → 프로필 순서 (버그가 났던 순서)', () {
      // Arrange
      state.tapBell();
      expect(state.isBellPanelOpen, isTrue);

      // Act
      state.tapProfile();

      // Assert — 수정 전에는 둘 다 true 여서 화면에 겹쳐 떴다
      expect(state.isProfileMenuVisible, isTrue);
      expect(state.isBellPanelOpen, isFalse);
      expect(state.openCount, 1);
    });

    test('프로필 → 벨 순서', () {
      // Arrange
      state.tapProfile();
      expect(state.isProfileMenuVisible, isTrue);

      // Act
      state.tapBell();

      // Assert
      expect(state.isBellPanelOpen, isTrue);
      expect(state.isProfileMenuVisible, isFalse);
      expect(state.openCount, 1);
    });

    test('여러 번 번갈아 눌러도 항상 최대 1개', () {
      // Arrange / Act / Assert
      for (int i = 0; i < 10; i++) {
        state.tapBell();
        expect(state.openCount, lessThanOrEqualTo(1),
            reason: '벨 탭 $i 회차에서 두 패널이 동시에 열림');
        state.tapProfile();
        expect(state.openCount, lessThanOrEqualTo(1),
            reason: '프로필 탭 $i 회차에서 두 패널이 동시에 열림');
      }
    });
  });

  group('같은 아이콘 재탭 — 토글로 닫힌다', () {
    test('벨을 두 번 누르면 닫힌다', () {
      // Arrange
      state.tapBell();

      // Act
      state.tapBell();

      // Assert
      expect(state.isBellPanelOpen, isFalse);
      expect(state.openCount, 0);
    });

    test('프로필을 두 번 누르면 닫힌다', () {
      // Arrange
      state.tapProfile();

      // Act
      state.tapProfile();

      // Assert
      expect(state.isProfileMenuVisible, isFalse);
      expect(state.openCount, 0);
    });
  });

  group('바깥 탭 — 둘 다 닫힌다', () {
    test('알림이 열린 상태에서 바깥 탭', () {
      // Arrange
      state.tapBell();

      // Act
      state.tapOutside();

      // Assert
      expect(state.openCount, 0);
    });

    test('프로필이 열린 상태에서 바깥 탭', () {
      // Arrange
      state.tapProfile();

      // Act
      state.tapOutside();

      // Assert
      expect(state.openCount, 0);
    });
  });
}
