// test/utils/test_utils.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class TestUtils {
  static void init() {
    Get.testMode = true;
  }

  static Future<void> cleanUp(TestWidgetsFlutterBinding binding) async {
 
    Get.closeAllSnackbars();
    await binding.pump(); 

    Get.reset(); 
    Get.clearRouteTree();
    Get.testMode = false; 
  }

  static Future<void> expectSnack(WidgetTester tester, String message) async {
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(message), findsWidgets); 
    Get.closeAllSnackbars();
    await tester.pump();
  }
}
