// test/viewmodel/controller/graph_controller_test.dart
//
// GraphController unit tests with explicit, descriptive naming.
// – Dependencies are mocked; no network traffic occurs.
// – All comments are in English only.
// – Variable names are fully descriptive; no single-letter aliases or obscure symbols.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/repository/graph_repository.dart';
import 'package:fms/model/graph_model.dart';

import 'graph_controller_test.mocks.dart';

@GenerateMocks(<Type>[GraphRepository])
void main() {
  late MockGraphRepository mockGraphRepository;
  late GraphController graphController;

  setUp(() {
    Get.testMode = true;

    // Dependency-injection setup
    mockGraphRepository = MockGraphRepository();
    Get.put<GraphRepository>(mockGraphRepository);

    graphController = GraphController();
    Get.put<GraphController>(graphController);
  });

  group('GraphController behavior verification', () {
    test('getChartItems returns exactly one distance entry', () {
      // Arrange
      debugPrint('ARRANGE  ▶  injecting a single daily chart item');
      graphController.dailyCharts[1] = <ChartItem>[
        ChartItem(
          date: '2025-06-15',
          distance: 12.5,
          time: 240,
          battery: 3.2,
        ),
      ];
      graphController.setSelectedRobotId(1);

      // Act
      debugPrint('ACT      ▶  calling getChartItems for "distance"');
      final List<ChartItem> distanceItems = graphController.getChartItems('distance');

      // Assert
      debugPrint('ASSERT   ▶  verifying item count and values');
      expect(distanceItems.length, equals(1));
      expect(distanceItems.first.distance, closeTo(12.5, 0.001));
    });

    test('getBarChartGroupData returns the same instance on repeated calls', () {
      // Arrange
      debugPrint('ARRANGE  ▶  injecting a single daily chart item');
      graphController.dailyCharts[2] = <ChartItem>[
        ChartItem(
          date: '2025-06-15',
          distance: 5.0,
          time: 120,
          battery: 1.1,
        ),
      ];
      graphController.setSelectedRobotId(2);

      // Act
      debugPrint('ACT      ▶  first call to getBarChartGroupData');
      final barChartFirst = graphController.getBarChartGroupData('distance');

      debugPrint('ACT      ▶  second call to getBarChartGroupData');
      final barChartSecond = graphController.getBarChartGroupData('distance');

      // Assert
      debugPrint('ASSERT   ▶  confirming cached instance is reused');
      expect(identical(barChartFirst, barChartSecond), isTrue);
      expect(barChartFirst?.barChartItems?.isNotEmpty ?? false, isTrue);
    });
  });
}
