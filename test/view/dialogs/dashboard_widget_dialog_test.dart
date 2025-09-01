// test/view/dashboard_widget/dashboard_widget_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dialogs/dashboard_widget_dialog.dart';
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
import 'package:fms/model/dashboard_model.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/view/components/input_edit_dropdown_dashboard.dart';
import 'package:fms/view/components/input_edit_text_dashboard.dart';

/// A fake DashboardController that simply records any LayoutSet passed to addLayout.
class FakeDashboardController extends DashboardController {
  final List<LayoutSet> addedLayouts = [];

  @override
  void addLayout(LayoutSet layoutSet) {
    addedLayouts.add(layoutSet);
  }
}

void main() {
  late FakeDashboardController fakeCtrl;

  setUp(() {
    Get.reset(); // clear any previously registered controllers
    fakeCtrl = FakeDashboardController();
    Get.put<DashboardController>(fakeCtrl);
  });

  /// Wraps a dialog so we can open it by tapping a button in a testable app scaffold.
  Widget _wrapWithHost(Widget dialog) {
    return GetMaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => dialog,
                );
              },
              child: const Text('SHOW'),
            ),
          );
        }),
      ),
    );
  }

  testWidgets('confirm path: selects option, enters text, taps confirm, and adds LayoutSet',
      (WidgetTester tester) async {
    const int testRow = 5;
    const int testColumn = 7;

    // 1) Pump the host with the dialog
    await tester.pumpWidget(
      _wrapWithHost(DashboardWidgetDialog(row: testRow, column: testColumn)),
    );
    // 2) Open the dialog
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();

    // 3) Tap dropdown and pick the first item ("기기 운행 현황")
    await tester.tap(find.byType(InputEditDropDownDashboard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기기 운행 현황').last);
    await tester.pumpAndSettle();

    // 4) Enter text into the two InputEditTextDashboard fields
    final finderTextFields = find.byType(InputEditTextDashboard);
    expect(finderTextFields, findsNWidgets(2));
    await tester.enterText(finderTextFields.at(0), 'MyMethod');
    await tester.enterText(finderTextFields.at(1), 'MyPeriod');

    // 5) Tap the "확 인" button
    await tester.tap(find.widgetWithText(GradientButton, '확 인'));
    await tester.pumpAndSettle();

    // 6) Verify controller.addLayout was called exactly once
    expect(fakeCtrl.addedLayouts, hasLength(1));
    final LayoutSet added = fakeCtrl.addedLayouts.first;

    // 7) Inspect the added LayoutSet
    expect(added.title, '기기 운행 현황');
    expect(added.rowIndex, testRow);
    expect(added.columnIndex, testColumn);
    expect(added.displayMethod, 'MyMethod');
    expect(added.period, 'MyPeriod');

    // 8) The dialog should have been dismissed
    expect(find.text('확 인'), findsNothing);
  });

  testWidgets('cancel path: tapping 취 소 dismisses without adding anything', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapWithHost(const DashboardWidgetDialog(row: 0, column: 0)),
    );
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();

    // Tap the cancel button
    await tester.tap(find.widgetWithText(GradientButton, '취 소'));
    await tester.pumpAndSettle();

    // Nothing should have been added
    expect(fakeCtrl.addedLayouts, isEmpty);
    // The dialog should be gone
    expect(find.text('취 소'), findsNothing);
  });

  testWidgets('initialization: dialog pre-populates fields when layoutSet is passed in', (WidgetTester tester) async {
    // Prepare an existing LayoutSet to edit
    final initial = LayoutSet(
      title: '로봇별 일평균 주행거리',
      rowIndex: 2,
      columnIndex: 3,
      displayMethod: 'InitMethod',
      period: 'InitPeriod',
    );

    await tester.pumpWidget(
      _wrapWithHost(DashboardWidgetDialog(row: initial.rowIndex!, column: initial.columnIndex!, layoutSet: initial)),
    );
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();

    // The dropdown shows the initial title
    expect(find.text(initial.title!), findsOneWidget);

    // The two text fields contain the initial method and period
    expect(find.widgetWithText(InputEditTextDashboard, initial.displayMethod!), findsOneWidget);
    expect(find.widgetWithText(InputEditTextDashboard, initial.period!), findsOneWidget);
  });
}
