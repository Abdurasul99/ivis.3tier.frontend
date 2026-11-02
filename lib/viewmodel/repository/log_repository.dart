import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

class HistoryExportResult {
  final String fileName;
  final int rowCount;
  final int columnCount;
  final bool truncated;

  HistoryExportResult({
    required this.fileName,
    required this.rowCount,
    required this.columnCount,
    this.truncated = false,
  });
}

class LogRepository {
  String get apiServerHost => kApiServer;
  Duration get requestTimeout => const Duration(seconds: 8);
  Duration get exportTimeout => const Duration(seconds: 600);

  Uri buildUri(String path, {Map<String, dynamic>? query}) {
    final String server = apiServerHost.trim();
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Map<String, String>? normalizedQuery = query?.map(
      (String key, dynamic value) => MapEntry(key, value.toString()),
    );

    if (server.startsWith('http://') || server.startsWith('https://')) {
      final Uri parsed = Uri.parse(server);
      final String basePath = parsed.path.endsWith('/')
          ? parsed.path.substring(0, parsed.path.length - 1)
          : parsed.path;
      return parsed.replace(
        path: '$basePath$normalizedPath',
        queryParameters: normalizedQuery,
      );
    }

    if (Uri.base.scheme == 'https') {
      return Uri.https(server, normalizedPath, normalizedQuery);
    }
    return Uri.http(server, normalizedPath, normalizedQuery);
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
    final http.Response response =
        await http.get(uri, headers: buildHeaders()).timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final dynamic decoded = jsonDecode(response.body);

    List<dynamic> rawList = [];
    if (decoded is Map<String, dynamic>) {
      if (decoded['body'] is List<dynamic>) {
        rawList = decoded['body'] as List<dynamic>;
      } else if (decoded['files'] is List<dynamic>) {
        rawList = decoded['files'] as List<dynamic>;
      }
    }

    final List<Map<String, dynamic>> onlyXls = rawList.whereType<Map<String, dynamic>>().where((file) {
      final String name = (file['fileName'] ?? file['file_name'] ?? '').toString();
      final String lowered = name.toLowerCase();
      return lowered.endsWith('.xls') || lowered.endsWith('.xlsx');
    }).toList();

    return onlyXls.map((e) => LogFileInfo.fromJson(e)).toList();
  }

  Future<void> downloadLogFile(String fileName) async {
    final Uri uri = buildUri('/api/broker-debug/download/$fileName');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<HistoryExportResult> exportHistoryFile({
    required String entityType,
    required List<String> visibleColumns,
    String? searchText,
    String? searchColumnName,
    int? vehicleId,
    int? infraId,
    int? fromEpochMs,
    int? toEpochMs,
    String? sortColumn,
    String? sortDirection,
  }) async {
    final Uri uri = buildUri('/api/broker-debug/export/history');

    final Map<String, dynamic> payload = <String, dynamic>{
      'entityType': entityType,
      'visibleColumns': visibleColumns,
      'searchText': searchText,
      'searchColumnName': searchColumnName,
      'vehicleId': vehicleId,
      'infraId': infraId,
      'from': fromEpochMs,
      'to': toEpochMs,
      'sortColumn': sortColumn,
      'sortDirection': sortDirection,
    };

    final http.Response response = await http.post(
      uri,
      headers: buildHeaders(),
      body: jsonEncode(payload),
    ).timeout(exportTimeout);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final dynamic decoded = jsonDecode(response.body);
    Map<String, dynamic> bodyMap = <String, dynamic>{};

    if (decoded is Map<String, dynamic>) {
      final dynamic rawBody = decoded['body'];
      if (rawBody is Map<String, dynamic>) {
        bodyMap = rawBody;
      } else {
        bodyMap = decoded;
      }
    }

    final String fileName = (bodyMap['fileName'] ?? bodyMap['file_name'] ?? '').toString().trim();
    final int rowCount = int.tryParse('${bodyMap['rowCount'] ?? bodyMap['row_count'] ?? 0}') ?? 0;

    // 2026-08-10: 선택한 기간에 데이터가 없으면 서버가 코드 9207 과 함께
    //   fileName='' , rowCount=0 을 돌려준다(빈 파일을 만들지 않는다).
    //   이 경우는 오류가 아니라 정상 결과이므로 예외를 던지지 않고 그대로 반환해
    //   호출부가 "데이터 없음" 을 안내하도록 한다.
    //   (이전에는 빈 파일을 그대로 내려받아 사용자가 헤더만 있는 CSV 를 받았다.)
    if (fileName.isEmpty && rowCount == 0) {
      return HistoryExportResult(
        fileName: '',
        rowCount: 0,
        columnCount: int.tryParse('${bodyMap['columnCount'] ?? bodyMap['column_count'] ?? 0}') ?? 0,
        truncated: false,
      );
    }

    if (fileName.isEmpty) {
      throw Exception('export fileName is empty');
    }

    final int columnCount = int.tryParse('${bodyMap['columnCount'] ?? bodyMap['column_count'] ?? 0}') ?? 0;
    final bool truncated =
        bodyMap['truncated'] == true || '${bodyMap['truncated']}' == 'true';

    return HistoryExportResult(
      fileName: fileName,
      rowCount: rowCount,
      columnCount: columnCount,
      truncated: truncated,
    );
  }
}
