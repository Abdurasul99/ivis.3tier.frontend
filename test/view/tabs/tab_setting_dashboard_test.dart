// test/view/tabs/tab_setting_dashboard_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Need LayoutSet type
import 'package:fms/model/dashboard_model.dart';
// Controller to stub
import 'package:fms/viewmodel/controller/dashboard_controller.dart';
// The widget under test
import 'package:fms/view/tabs/tab_setting_dashboard.dart';

/// A fake DashboardController so Get.find() in the widget doesn’t crash.
class FakeDashboardController extends DashboardController {
  @override
  Future<void> reqDashboardLayoutSetting() async {
    debugPrint('FakeDashboardController.reqDashboardLayoutSetting called');
    // No-op for tests
  }

  @override
  void deleteLayoutByRow(int row) {
    debugPrint('FakeDashboardController.deleteLayoutByRow called with row: $row');
    // No-op
  }

  @override
  bool isEmptyLayouts() {
    debugPrint('FakeDashboardController.isEmptyLayouts called');
    return false; // Always report layouts exist
  }

  @override
  Future<bool> saveLayouts() async {
    debugPrint('FakeDashboardController.saveLayouts called');
    return true; // Simulate successful save
  }

  @override
  List<LayoutSet> get layoutSets {
    debugPrint('FakeDashboardController.layoutSets getter called');
    return []; // No initial rows
  }
}

void main() {
  // Ensure binding is initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset and register our fake
    Get.reset();
    Get.put<DashboardController>(FakeDashboardController());
    debugPrint('Registered FakeDashboardController');
  });

  tearDown(() {
    // Clear window size overrides
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
    debugPrint('Cleared window overrides');
  });

  testWidgets('Add row shows delete button, and top save/cancel exist', (tester) async {
    // Prevent overflow by using a large test window
    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(1200, 800);
    binding.window.devicePixelRatioTestValue = 1.0;
    debugPrint('Window size set to 1200x800');

    // Build the widget tree
    await tester.pumpWidget(
      GetMaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: const TabSettingDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('Widget tree built');

    // 1) Verify top action buttons
    expect(find.text('대시보드 저장'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    debugPrint('Verified save and cancel buttons');

    // 2) Before adding, only the add-row button should be visible
    expect(find.text('+ 행 추가'), findsOneWidget);
    expect(find.text('- 행 삭제'), findsNothing);
    debugPrint('Verified only add-row button is visible initially');

    // 3) Tap the add-row button, and expect delete-row button
    await tester.tap(find.text('+ 행 추가'));
    await tester.pumpAndSettle();
    expect(find.text('- 행 삭제'), findsOneWidget);
    debugPrint('Tapped + 행 추가 and verified - 행 삭제 appears');

    // 4) Tap the delete-row button to ensure it doesn’t crash
    await tester.tap(find.text('- 행 삭제'));
    await tester.pumpAndSettle();
    // Given current widget logic, the button remains
    expect(find.text('- 행 삭제'), findsOneWidget);
    debugPrint('Tapped - 행 삭제 and verified button remains');
  });
}
