import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/pick_image_model.dart';
import '../../model/upload_model.dart';
import 'base_repository.dart';

class UploadRepository extends BaseRepository {
  final String fileUploadPath = "/api/upload/file";

  Future<List<UploadModel>> requestUploadImage(List<PickImageFile> files) async {
    var url = Uri.http(kApiServer, fileUploadPath);

    try {
      var request = http.MultipartRequest('POST', url);

      int index = 0;

      for (PickImageFile pickFile in files) {
        if (pickFile.fileType == PickImageFileType.networkFile) {
          index++;
          continue;
        }

        if (pickFile.fileType == PickImageFileType.networkFile) {
          continue;
        } else if (pickFile.fileType == PickImageFileType.imageBytes) {
          Uint8List? bytes = pickFile.imageBytes;

          if (bytes == null) {
            continue;
          }

          request.files.add(
            http.MultipartFile(
              'files',
              Stream.value(
                List<int>.from(bytes),
              ),
              bytes.length,
              filename: Get.find<UserController>().loginUser?.id.toString(),
            ),
          );
        }
        index++;
      }

      request.headers.addAll(getHeader());

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestUploadImage() statusCode ${response.statusCode}');
        return [];
      }

      var jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse == null) {
        debugPrint('[Error] requestUploadImage() jsonResponse is null');
        return [];
      }

      debugPrint("requestUploadImage() ${jsonResponse.toString()}");
      List<dynamic> items = jsonResponse['result'];
      return items.map((e) => UploadModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("[Exception] requestUploadImage() ${e.toString()}");
      return [];
    }
  }
}
