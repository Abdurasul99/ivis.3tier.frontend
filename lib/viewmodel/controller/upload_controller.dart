import 'package:get/get.dart';

import '../../model/pick_image_model.dart';
import '../../model/upload_model.dart';
import '../repository/upload_repository.dart';

class UploadController extends GetxController {
  Future<List<UploadModel>> reqUploadImage(List<PickImageFile> files) {
    return UploadRepository().requestUploadImage(files);
  }
}
