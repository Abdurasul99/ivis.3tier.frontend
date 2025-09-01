// test/view/components/chart_view_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:fms/view/components/chart_view.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/model/graph_model.dart';

/// A mock GraphController that tracks loading state, chart data, and period selection.
class MockGraphController extends GraphController {
  bool _isLoading = false;
  BarChartBase? _mockChartData;
  String _currentPeriod = 'daily';
  String _selectedRobotType = 'default';

  /// Allow tests to configure loading state.
  set isLoadingState(bool value) => _isLoading = value;

  @override
  bool get isLoading {
    debugPrint('DEBUG: isLoading -> $_isLoading');
    return _isLoading;
  }

  /// Allow tests to provide fake chart data.
  set mockChartData(BarChartBase? data) => _mockChartData = data;

  @override
  BarChartBase? getBarChartGroupData(String type) {
    debugPrint('DEBUG: getBarChartGroupData(type: $type) -> $_mockChartData');
    return _mockChartData;
  }

  @override
  String getCurrentPeriod(String type) {
    debugPrint('DEBUG: getCurrentPeriod(type: $type) -> $_currentPeriod');
    return _currentPeriod;
  }

  @override
  String get selectedRobotType {
    debugPrint('DEBUG: selectedRobotType -> $_selectedRobotType');
    return _selectedRobotType;
  }

  /// Override period selection methods so they update internal state.
  @override
  void setSelectedPeriodDistance(String period) {
    _currentPeriod = period;
    debugPrint('DEBUG: setSelectedPeriodDistance -> $_currentPeriod');
  }

  @override
  void setSelectedPeriodTime(String period) {
    _currentPeriod = period;
    debugPrint('DEBUG: setSelectedPeriodTime -> $_currentPeriod');
  }

  @override
  void setSelectedPeriodBattery(String period) {
    _currentPeriod = period;
    debugPrint('DEBUG: setSelectedPeriodBattery -> $_currentPeriod');
  }

  @override
  Future<List<ChartItem>> reqUpdateChartItems(String period) async {
    // Simulate chart update request; no-op in tests.
    debugPrint('DEBUG: reqUpdateChartItems($period)');
    return [];
  }
}

void main() {
  group('ChartView Widget Tests', () {
    late MockGraphController mockController;

    setUp(() {
      // Register our mock controller before each test.
      mockController = MockGraphController();
      Get.reset();
      Get.put<GraphController>(mockController);
    });

    testWidgets('shows loading spinner when controller.isLoading is true', (WidgetTester tester) async {
      // Arrange: controller in loading state, no chart data.
      mockController.isLoadingState = true;
      mockController.mockChartData = null;

      // Act: render the ChartView.
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: ChartView(type: 'distance')),
        ),
      );
      await tester.pump(); // complete the build

      // Assert: a CupertinoActivityIndicator is displayed.
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('renders BarChart and displays correct totalValue text for distance', (WidgetTester tester) async {
      // Arrange: create dummy bar groups and wrap in BarChartBase.
      final groups = [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 1500)], showingTooltipIndicators: [0]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 2500)], showingTooltipIndicators: [0]),
      ];
      final dummyData = BarChartBase(
        barChartItems: groups,
        sumOfValue: 4000,
        maxY: 2600,
        titles: ['2025-06-01', '2025-06-02'],
      );

      mockController.isLoadingState = false;
      mockController.mockChartData = dummyData;
      // Default robot type produces Km conversion.
      // Act: render with fixed size to ensure layoutBuilder constraints.
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, height: 300, child: ChartView(type: 'distance')),
          ),
        ),
      );
      await tester.pumpAndSettle(); // wait for animations

      // Assert: BarChart is present.
      expect(find.byType(BarChart), findsOneWidget);
      // Assert: totalValue text shows "4Km".
      expect(find.text('4Km'), findsOneWidget);
    });

    testWidgets('tapping period buttons updates controller period', (WidgetTester tester) async {
      // Arrange: dummy empty chart so loading=false.
      final dummyData = BarChartBase(barChartItems: [], sumOfValue: 0, maxY: 0, titles: []);
      mockController.isLoadingState = false;
      mockController.mockChartData = dummyData;

      // Act: render the widget.
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, height: 300, child: ChartView(type: 'distance')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the period selection buttons by their labels.
      final Finder dailyButton = find.text('일');
      final Finder weeklyButton = find.text('주');
      final Finder monthlyButton = find.text('월');
      final Finder yearlyButton = find.text('년');

      // Act & Assert: tap 'weekly'
      await tester.tap(weeklyButton);
      await tester.pumpAndSettle();
      expect(mockController.getCurrentPeriod('distance'), equals('weekly'));

      // Tap 'monthly'
      await tester.tap(monthlyButton);
      await tester.pumpAndSettle();
      expect(mockController.getCurrentPeriod('distance'), equals('monthly'));

      // Tap 'yearly'
      await tester.tap(yearlyButton);
      await tester.pumpAndSettle();
      expect(mockController.getCurrentPeriod('distance'), equals('yearly'));

      // Tap 'daily'
      await tester.tap(dailyButton);
      await tester.pumpAndSettle();
      expect(mockController.getCurrentPeriod('distance'), equals('daily'));
    });
  });
}
