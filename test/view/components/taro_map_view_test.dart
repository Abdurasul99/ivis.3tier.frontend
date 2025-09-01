// test/view/components/taro_map_view_test.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fms/view/components/taro_map_view.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/robot_model.dart';

class MockRobotController extends RobotController {
  @override
  List<RobotStatus> get robotStatusList => [];
}

void main() {
  setUp(() {
    Get.reset();
    Get.put<RobotController>(MockRobotController());
  });

  testWidgets('renders background image inside an InteractiveViewer', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: const TaroMapView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('img_taro_map.png')),
      findsOneWidget,
    );
  });

  testWidgets('initialScale parameter updates the transformation matrix', (WidgetTester tester) async {
    const double width = 400;
    const double height = 300;
    const double initialScaleParam = 2.0;
    const double imageWidth = 701.0;
    const double imageHeight = 570.0;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: const TaroMapView(initialScale: initialScaleParam),
          ),
        ),
      ),
    );
    // let post-frame callback
    await tester.pumpAndSettle();

    // Grab the controller
    final interactiveViewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = interactiveViewer.transformationController!;
    final actualScale = controller.value.getMaxScaleOnAxis();

    // Compute expected initialFitScale and resulting matrix scale
    final double initialFitScale = math.min(width / imageWidth, height / imageHeight);
    final double expectedScale = (initialScaleParam / initialFitScale).clamp(0.1, 4.0);

    expect(actualScale, isNot(equals(1.0)));
    expect(actualScale, moreOrLessEquals(expectedScale, epsilon: 0.01));
  });
}
