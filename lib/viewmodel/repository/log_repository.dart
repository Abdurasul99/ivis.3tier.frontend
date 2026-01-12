import 'dart:convert';
import 'dart:html' as html;

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../controller/user_controller.dart';

class LogFileInfo {
  final String fileName;
  final int sizeBytes;
  final DateTime? lastModified;

  LogFileInfo({
    required this.fileName,
    required this.sizeBytes,
    this.lastModified,
  });

  factory LogFileInfo.fromJson(Map<String, dynamic> json) {
    final String name = (json['fileName'] ?? json['file_name'] ?? '').toString();

    final int size = int.tryParse(
          '${json['sizeBytes'] ?? json['size_bytes'] ?? json['size'] ?? 0}',
        ) ??
        0;

    DateTime? lm;
    final dynamic rawTs = json['lastModified'] ?? json['last_modified'] ?? json['modifiedAt'];
    if (rawTs is String) {
      lm = DateTime.tryParse(rawTs);
    }

    return LogFileInfo(
      fileName: name,
      sizeBytes: size,
      lastModified: lm,
    );
  }
}

class LogRepository {
  String get apiServerHost => kApiServer;

  Uri buildUri(String path, {Map<String, dynamic>? query}) {
    return Uri.http(apiServerHost, path, query);
  }

  Map<String, String> buildHeaders() {
    final String accessToken = Get.find<UserController>().accessToken ?? '';
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (accessToken.isNotEmpty) {
      headers['x-access-token'] = accessToken;
    }
    return headers;
  }

  Future<List<LogFileInfo>> fetchLogFiles() async {
    final Uri uri = buildUri('/api/broker-debug/files');
    final http.Response response = await http.get(uri, headers: buildHeaders());

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final dynamic decoded = jsonDecode(response.body);

    List<dynamic> rawList = [];
    if (decoded is Map<String, dynamic>) {
      if (decoded['files'] is List<dynamic>) {
        rawList = decoded['files'];
      } else if (decoded['body'] is Map && decoded['body']['files'] is List<dynamic>) {
        rawList = decoded['body']['files'];
      }
    }

    final List<Map<String, dynamic>> onlyXls = rawList.whereType<Map<String, dynamic>>().where((file) {
      final String name = (file['fileName'] ?? file['file_name'] ?? '').toString();
      return name.toLowerCase().endsWith('.xls');
    }).toList();

    return onlyXls.map((e) => LogFileInfo.fromJson(e)).toList();
  }

  Future<void> downloadLogFile(String fileName) async {
    final Uri uri = buildUri('/api/broker-debug/download/$fileName');
    html.window.open(uri.toString(), '_blank');
  }
}
