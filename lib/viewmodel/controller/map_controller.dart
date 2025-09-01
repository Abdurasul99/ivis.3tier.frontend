import 'package:get/get.dart';

import '../../constants/constants.dart';

class MapController extends GetxController {
  Uri mapUri = Uri.parse("http://$kMapHost");

  void setMapUri(String url) {
    mapUri = Uri.parse(url);
    update();
  }
}
