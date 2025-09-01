import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../view/components/page_nation_view.dart';
import '../repository/log_repository.dart';

class LogController extends GetxController {
  bool _isLoading = false;
  int _selectedRobotId = -1;
  int _totalLogCount = 0;
  List<RobotLog> _robotLogs = [];
  int _viewPage = 0;
  int _maxPage = 0;
  Set<int> _selectedIds = {};

  String _startDate = "";
  String _endDate = "";
  String _keyword = "";

  bool get isLoading => _isLoading;
  int get selectedRobotId => _selectedRobotId;
  int get totalLogCount => _totalLogCount;
  List<RobotLog> get robotLogs => _robotLogs;
  int get viewPage => _viewPage;
  int get maxPage => _maxPage;
  Set<int> get selectedIds => _selectedIds;

  /////////////////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////////////////

  void setSelectedRobotId(int robotId) {
    _selectedRobotId = robotId;
  }

  void setViewPage(int page) {
    _viewPage = page;
  }

  void addSelectedId(int id) {
    if (id == -1) {
      return;
    }

    _selectedIds.add(id);
  }

  void removeSelectedId(int id) {
    if (id == -1) {
      return;
    }

    _selectedIds.remove(id);
  }

  void clearSelectedIds() {
    _selectedIds.clear();
  }

  bool isSelectedId(int id) {
    return _selectedIds.contains(id);
  }

  Future<void> reqLogList({String? startDate, String? endDate, String? keyword}) async {
    RobotLogList? robotLogList;
    _isLoading = true;
    _totalLogCount = 0;
    _robotLogs.clear();

    if (startDate != null) {
      _startDate = startDate;
    }

    if (endDate != null) {
      _endDate = endDate;
    }

    if (keyword != null) {
      _keyword = keyword;
    }

    int offset = (_viewPage * kLogListLimit);
    robotLogList = await LogRepository().requestLogList(
      _selectedRobotId,
      kLogListLimit,
      offset,
      startDate: startDate,
      endDate: endDate,
      keyword: keyword,
    );

    if (robotLogList == null) {
      _isLoading = false;
      update();
      return;
    }

    _totalLogCount = robotLogList.listCount ?? 0;
    if (_totalLogCount % kLogListLimit == 0) {
      _maxPage = (_totalLogCount / kLogListLimit).floor();
    } else {
      _maxPage = (_totalLogCount / kLogListLimit).floor() + 1;
    }

    if (_maxPage <= 0) {
      _maxPage = 1;
    }

    _robotLogs = robotLogList.logList;

    _isLoading = false;
    update();
  }

  Future<void> reqLogListForDocument() async {
    _isLoading = true;

    int minLogId =
        _selectedIds.isEmpty ? 0 : _selectedIds.reduce((value, element) => value < element ? value : element);
    int maxLogId =
        _selectedIds.isEmpty ? 0 : _selectedIds.reduce((value, element) => value > element ? value : element);

    List<RobotLog> result = await LogRepository().requestLogListForDocument(_selectedRobotId, minLogId, maxLogId);

    List<RobotLog> excelResult = [];

    for (int i = 0; i < result.length; i++) {
      if (_selectedIds.contains(result[i].id!)) {
        excelResult.add(result[i]);
      }
    }

    if (excelResult.isEmpty) {
      _isLoading = false;
      return;
    }

    await exportToExcel(excelResult);

    _isLoading = false;
    update();
  }

  Future<void> exportToExcel(List<RobotLog> logs) async {
    if (logs.isEmpty) {
      return;
    }

    try {
      String startDate = logs[logs.length - 1].createdTs ?? "";
      String endDate = logs[0].createdTs ?? "";
      String robotName = Get.find<RobotController>().getRobotName(_selectedRobotId);

      final excel = Excel.createExcel();
      final Sheet sheet = excel['Sheet1'];

      final CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.black26,
        horizontalAlign: HorizontalAlign.Center,
      );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('ID')
        ..cellStyle = headerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        ..value = TextCellValue('날짜/시간')
        ..cellStyle = headerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
        ..value = TextCellValue('등급')
        ..cellStyle = headerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
        ..value = TextCellValue('내용')
        ..cellStyle = headerStyle;

      for (int i = 0; i < logs.length; i++) {
        final RobotLog log = logs[i];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value =
            log.id != null ? IntCellValue(log.id!) : null;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value =
            TextCellValue(log.createdTs ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(log.level ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value =
            TextCellValue(log.message ?? '');
      }

      if (kIsWeb) {
        final bytes = excel.save();
        if (bytes != null) {
          final fileName = '${robotName}_logs_$startDate~$endDate.xlsx';

          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final downloadElement = html.AnchorElement()
            ..href = url
            ..download = fileName
            ..style.display = 'none';

          html.document.body?.children.add(downloadElement);
          downloadElement.click();
          downloadElement.remove();
          html.Url.revokeObjectUrl(url);
        }
      }
    } catch (e) {
      debugPrint('Excel 변환 오류: $e');
    }
  }

  String getTaroDestinationName(double x, double y) {
    for (int i = 0; i < kTaroMakers.length; i++) {
      if (kTaroMakers[i]["X"] == x && kTaroMakers[i]["Y"] == y) {
        return kTaroMakers[i]["title"];
      }
    }

    return "";
  }

  String getUntactDestinationName(double x, double y) {
    if (x == kStation0Latitude && y == kStation0Longitude) {
      return "station0(광주광역시 광산구 월전동 59-8)";
    }

    if (x == kStation1Latitude && y == kStation1Longitude) {
      return "station1(광주광역시 광산구 덕립동)";
    }

    if (x == kStation2Latitude && y == kStation2Longitude) {
      return "station2(광주광역시 광산구 덕립동)";
    }

    if (x == kStation3Latitude && y == kStation3Longitude) {
      return "station3(광주광역시 광산구 삼거동)";
    }

    if (x == kStation4Latitude && y == kStation4Longitude) {
      return "station4(광주광역시 광산구 삼거동)";
    }

    return "($x, $y)";
  }

  Widget getPageNationView() {
    return PageNationView(
      viewPage: _viewPage,
      maxPage: _maxPage,
      onViewPageChanged: (index) async {
        _viewPage = index;
        reqLogList(startDate: _startDate, endDate: _endDate, keyword: _keyword);
      },
    );
  }
}
