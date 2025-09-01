// test/viewmodel/controller/time_controller_test.dart
//
// Unit-test for TimeController.


import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fake_async/fake_async.dart';

import 'package:fms/viewmodel/controller/time_controller.dart';

void main() {
  group('TimeController – AAA with debug prints', () {
    test(
      'periodic timer triggers update() once per second',
      () {
        fakeAsync(
          (FakeAsync fake) {
            print('\n▶ TEST: TimeController timer');

            /* ─────────────── Arrange ─────────────── */
            Get.testMode = true;
            print('ARRANGE   → instantiate controller and add listener');

            final TimeController controller = TimeController();
            
            Get.put<TimeController>(controller);

            int rebuildCount = 0;
            controller.addListener(
              () {
                rebuildCount++;
                print('   listener fired   → rebuildCount = $rebuildCount');
              },
            );

            /* ─────────────── Act ─────────────────── */
            print('ACT       → elapse 3 seconds in fake time');
            fake.elapse(const Duration(seconds: 3));

            /* ─────────────── Assert ─────────────── */
            print('ASSERT    → expect exactly 3 notifications');
            expect(rebuildCount, equals(3));

            /* ─── Clean-up: cancel timer and verify no more ticks ─── */
            controller.onClose(); 
            print('CLEAN-UP  → timer cancelled, elapse 2 more seconds');
            fake.elapse(const Duration(seconds: 2));

            expect(rebuildCount, equals(3)); 
          },
        );
      },
    );
  });
}
