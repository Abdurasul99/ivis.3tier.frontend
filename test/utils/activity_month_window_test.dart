// test/utils/activity_month_window_test.dart
// KST month windows used by the activity calendar's month paging.
// Triple-A pattern (Arrange / Act / Assert)

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/viewmodel/controller/helper/activity_format_helper.dart';

// Epoch ms of KST midnight on the given date (KST = UTC+9)
int _kstMidnight(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch - const Duration(hours: 9).inMilliseconds;

void main() {
  group('ActivityFormatHelper.monthKstWindow', () {
    test('covers the whole KST month, from midnight on the 1st to 1 ms before the next month', () {
      // Arrange
      final DateTime month = DateTime(2026, 10, 1);

      // Act
      final ({int fromMs, int toMs}) window = ActivityFormatHelper.monthKstWindow(month);

      // Assert
      expect(window.fromMs, _kstMidnight(2026, 10, 1));
      expect(window.toMs, _kstMidnight(2026, 11, 1) - 1);
    });

    test('any day inside the month gives the same window', () {
      // Arrange
      final DateTime firstDay = DateTime(2026, 2, 1);
      final DateTime lastDay = DateTime(2026, 2, 28);

      // Act
      final ({int fromMs, int toMs}) a = ActivityFormatHelper.monthKstWindow(firstDay);
      final ({int fromMs, int toMs}) b = ActivityFormatHelper.monthKstWindow(lastDay);

      // Assert
      expect(b, a);
    });

    test('December ends at the start of January of the next year', () {
      // Act
      final ({int fromMs, int toMs}) window =
          ActivityFormatHelper.monthKstWindow(DateTime(2025, 12, 1));

      // Assert
      expect(window.fromMs, _kstMidnight(2025, 12, 1));
      expect(window.toMs, _kstMidnight(2026, 1, 1) - 1);
    });

    test('paging back from January lands on December of the previous year', () {
      // Arrange: the controller pages with DateTime(year, month - 1)
      final DateTime previous = DateTime(2026, 1 - 1);

      // Act
      final ({int fromMs, int toMs}) window = ActivityFormatHelper.monthKstWindow(previous);

      // Assert
      expect(previous.year, 2025);
      expect(previous.month, 12);
      expect(window.fromMs, _kstMidnight(2025, 12, 1));
    });
  });

  group('ActivityFormatHelper.currentMonthStartKst', () {
    test('is the first day of the current KST month and matches currentMonthKstWindow', () {
      // Act
      final DateTime start = ActivityFormatHelper.currentMonthStartKst();
      final DateTime nowKst = ActivityFormatHelper.nowKst();

      // Assert
      expect(start.day, 1);
      expect(start.year, nowKst.year);
      expect(start.month, nowKst.month);
      expect(ActivityFormatHelper.monthKstWindow(start),
          ActivityFormatHelper.currentMonthKstWindow());
    });
  });
}
