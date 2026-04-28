import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ivis/viewmodel/controller/user_controller.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../model/pick_image_model.dart';
import '../../model/upload_model.dart';
import 'base_repository.dart';

class UploadRepository extends BaseRepository {
  final String fileUploadPath = "/api/upload/file";
  final String fileDeletePath = "/api/upload/file";

  Future<List<UploadModel>> requestUploadImage(List<PickImageFile> files) async {
    final Uri url = buildApiUri(fileUploadPath);

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

      // Content-Type은 multipart/form-data로 자동 설정됨 — json 헤더 추가하면 덮어써짐
      final String? token = Get.find<UserController>().accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['x-access-token'] = token;
      }

      final http.StreamedResponse streamed =
          await request.send().timeout(requestTimeout);
      final http.Response response =
          await http.Response.fromStream(streamed).timeout(requestTimeout);

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
      // buildResponse가 'body' 키를 사용함 — 'result' 아님
      final dynamic raw = jsonResponse['body'];
      if (raw == null || raw is! List) {
        debugPrint('[Error] requestUploadImage() body is null or not a list');
        return [];
      }
      return raw.map((e) => UploadModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("[Exception] requestUploadImage() ${e.toString()}");
      return [];
    }
  }

  // S3에서 이미지 삭제
  Future<bool> requestDeleteImage(String imageUrl) async {
    final Uri url = buildApiUri(fileDeletePath);
    try {
      final http.Response response = await http.delete(
        url,
        headers: getHeader(),
        body: json.encode({'imageUrl': imageUrl}),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[Error] requestDeleteImage() statusCode ${response.statusCode}');
        return false;
      }

      final dynamic jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse?['code'] == '0000';
    } catch (e) {
      debugPrint('[Exception] requestDeleteImage() ${e.toString()}');
      return false;
    }
  }
}
