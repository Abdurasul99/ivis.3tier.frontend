// test/view/components/custom_scroll_behavior_test.dart

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/view/components/custom_scroll_behavior.dart';

void main() {
  group('CustomScrollBehavior', () {
    test('dragDevices should contain touch and mouse only', () {
      // Arrange: create an instance of the custom scroll behavior
      final CustomScrollBehavior behavior = CustomScrollBehavior();

      // Act: retrieve the set of drag devices
      final Set<PointerDeviceKind> actualDragDevices = behavior.dragDevices;

      // Assert: the behavior supports exactly touch and mouse pointer devices
      expect(
        actualDragDevices,
        equals({PointerDeviceKind.touch, PointerDeviceKind.mouse}),
        reason: 'CustomScrollBehavior.dragDevices must only include touch and mouse',
      );
    });
  });
}
