import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
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

    // Built anew for the retry after a token refresh (a multipart request cannot be re-sent).
    http.MultipartRequest buildRequest() {
      var request = http.MultipartRequest('POST', url);

      for (PickImageFile pickFile in files) {
        if (pickFile.fileType == PickImageFileType.networkFile) {
          continue;
        } else if (pickFile.fileType == PickImageFileType.imageBytes) {
          Uint8List? bytes = pickFile.imageBytes;

          if (bytes == null) {
            continue;
          }

          // PNG: 89 50 4E 47, JPEG: FF D8 FF
          final bool isPng = bytes.length >= 4 &&
              bytes[0] == 0x89 && bytes[1] == 0x50 &&
              bytes[2] == 0x4E && bytes[3] == 0x47;
          final String ext    = isPng ? 'png' : 'jpg';
          final String userId = Get.find<UserController>().loginUser?.id.toString() ?? 'photo';

          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              bytes,
              filename: '$userId.$ext',
              contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
            ),
          );
        }
      }

      return request;
    }

    try {
      // Content-Type은 multipart/form-data로 자동 설정됨 — json 헤더 추가하면 덮어써짐
      // (safeMultipart adds only the access token header)
      final http.Response response = await safeMultipart(buildRequest);

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
      final http.Response response = await safeDelete(
        url,
        body: json.encode({'imageUrl': imageUrl}),
      );

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
