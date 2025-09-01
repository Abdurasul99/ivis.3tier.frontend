import 'dart:async';

import 'package:get/get.dart';

class TimeController extends GetxController {
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      update();
    });
  }

  @override
  void onClose() {
    super.onClose();

    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
  }
}
