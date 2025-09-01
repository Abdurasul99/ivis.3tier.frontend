// test/viewmodel/controller/map_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fms/constants/constants.dart';
import 'package:get/get.dart';

import 'package:fms/viewmodel/controller/map_controller.dart';

void main() {
  late MapController controller;

  setUp(() {
    Get.testMode = true; // GetX 테스트 모드
    controller = MapController();
  });

  group('MapController – AAA 스타일', () {
    test('setMapUri()가 mapUri를 파싱하고 업데이트해야 한다', () {
      // --------------- 준비 (Arrange) ---------------
      const url = 'http://$kMapHost';

      // ---------------- 수행 (Act) ----------------
      controller.setMapUri(url);

      // --------------- 검증 (Assert) ---------------
      expect(controller.mapUri.toString(), equals(url));
    });
  });
}
