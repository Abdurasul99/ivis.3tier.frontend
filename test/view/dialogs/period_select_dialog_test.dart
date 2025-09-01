// test/view/dialogs/period_select_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/view/dialogs/period_select_dialog.dart';

void main() {
  late DateFormat dateFormat;

  setUp(() {
    dateFormat = DateFormat('yyyy-MM-dd');
  });

  /// Wraps PeriodSelectDialog in a GetMaterialApp + a button that opens it
  /// and captures the result when “조회” is tapped.
  Widget buildTestApp(ValueSetter<Map<String, String>?> onDialogClosed) {
    return GetMaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              key: const Key('openPeriodDialog'),
              onPressed: () async {
                final result = await showDialog<Map<String, String>>(
                  context: context,
                  builder: (_) => const PeriodSelectDialog(),
                );
                onDialogClosed(result);
              },
              child: const Text('OPEN_PERIOD_DIALOG'),
            ),
          );
        }),
      ),
    );
  }

  testWidgets('tapping "1주일" then 조회 returns start=today-7, end=today', (tester) async {
    Map<String, String>? captured;
    await tester.pumpWidget(buildTestApp((r) => captured = r));

    // Open the dialog
    await tester.tap(find.byKey(const Key('openPeriodDialog')));
    await tester.pumpAndSettle();

    // Find and tap the "1주일" button
    final oneWeekButton = find.text('1주일');
    expect(oneWeekButton, findsOneWidget);
    await tester.tap(oneWeekButton);
    await tester.pumpAndSettle();

    // Compute expected dates
    final now = DateTime.now();
    final expectedEnd = dateFormat.format(now);
    final expectedStart = dateFormat.format(now.subtract(const Duration(days: 7)));

    // The dialog should display these dates in the two bordered containers
    // We look for Text widgets showing those strings:
    expect(find.text(expectedStart), findsOneWidget);
    expect(find.text(expectedEnd), findsOneWidget);

    // Tap the "조회" button
    final lookupButton = find.widgetWithText(GradientButton, '조회');
    expect(lookupButton, findsOneWidget);
    await tester.tap(lookupButton);

    // Let the dialog close
    await tester.pumpAndSettle();

    // The captured result should match our computed map
    expect(captured, isNotNull);
    expect(captured!['start'], expectedStart);
    expect(captured!['end'], expectedEnd);
  });

  testWidgets('tapping "1개월" then 조회 returns start=today-30, end=today', (tester) async {
    Map<String, String>? captured;
    await tester.pumpWidget(buildTestApp((r) => captured = r));

    // Open dialog
    await tester.tap(find.byKey(const Key('openPeriodDialog')));
    await tester.pumpAndSettle();

    // Tap "1개월"
    await tester.tap(find.text('1개월'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final expectedEnd = dateFormat.format(now);
    final expectedStart = dateFormat.format(now.subtract(const Duration(days: 30)));

    expect(find.text(expectedStart), findsOneWidget);
    expect(find.text(expectedEnd), findsOneWidget);

    // Tap 조회
    await tester.tap(find.widgetWithText(GradientButton, '조회'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['start'], expectedStart);
    expect(captured!['end'], expectedEnd);
  });

  testWidgets('tapping "1일" then 조회 returns start=today-1, end=today', (tester) async {
    Map<String, String>? captured;
    await tester.pumpWidget(buildTestApp((r) => captured = r));

    // Open dialog
    await tester.tap(find.byKey(const Key('openPeriodDialog')));
    await tester.pumpAndSettle();

    // Tap "1일"
    await tester.tap(find.text('1일'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final expectedEnd = dateFormat.format(now);
    final expectedStart = dateFormat.format(now.subtract(const Duration(days: 1)));

    expect(find.text(expectedStart), findsOneWidget);
    expect(find.text(expectedEnd), findsOneWidget);

    // Tap 조회
    await tester.tap(find.widgetWithText(GradientButton, '조회'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['start'], expectedStart);
    expect(captured!['end'], expectedEnd);
  });
}
