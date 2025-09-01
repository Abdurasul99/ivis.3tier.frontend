// lib/view/tabs/mobile/tab_robot_graph_mobile.dart
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:fms/view/tabs/mobile/components/chart_view_mobile.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/model/graph_model.dart';
import 'package:fms/utils/download_utils.dart';
import 'package:fms/utils/utils.dart';

class TabRobotGraphMobile extends StatefulWidget {
  const TabRobotGraphMobile({super.key});

  @override
  State<TabRobotGraphMobile> createState() => _TabRobotGraphMobileState();
}

class _TabRobotGraphMobileState extends State<TabRobotGraphMobile> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final noBorderTheme = Theme.of(context).copyWith(
      cardTheme: const CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.zero),
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 142,
              child: GradientButton(
                buttonText: "운행 기록 내보내기",
                buttonColor: const Color(0xFF005FB8),
                onTap: _exportRunHistoryToExcel,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Theme(
            data: noBorderTheme,
            child: const SizedBox(height: 310, child: ChartViewMobile(type: "distance")),
          ),
          const SizedBox(height: 25),
          Theme(
            data: noBorderTheme,
            child: const SizedBox(height: 310, child: ChartViewMobile(type: "time")),
          ),
          const SizedBox(height: 25),
          Theme(
            data: noBorderTheme,
            child: const SizedBox(height: 310, child: ChartViewMobile(type: "battery")),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Future<void> _exportRunHistoryToExcel() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final graph = Get.find<GraphController>();

      final dailyItems = await graph.reqUpdateChartItems('daily');
      final weeklyItems = await graph.reqUpdateChartItems('weekly');
      final monthlyItems = await graph.reqUpdateChartItems('monthly');
      final yearlyItems = await graph.reqUpdateChartItems('yearly');

      final excelBytes = await _convertChartItemsToExcel(
        dailyItems: dailyItems,
        weeklyItems: weeklyItems,
        monthlyItems: monthlyItems,
        yearlyItems: yearlyItems,
      );

      final robotName = Get.find<RobotController>().getRobotNameByRobotId(graph.selectedRobotId);
      final fileName = _generateFileName(robotName);

      DownloadUtils.downloadExcelFile(
        excelBytes: Uint8List.fromList(excelBytes),
        fileName: fileName,
      );

      if (Get.isDialogOpen ?? false) Get.back();
      Utils.showSnackBar("운행 기록이 저장되었습니다.");
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Utils.showSnackBar("Excel 파일 생성 중 오류가 발생했습니다: $e", isError: true);
      debugPrint("[Export Exception] $e");
    }
  }

  static Future<List<int>> _convertChartItemsToExcel({
    required List<ChartItem> dailyItems,
    required List<ChartItem> weeklyItems,
    required List<ChartItem> monthlyItems,
    required List<ChartItem> yearlyItems,
  }) async {
    final excel = Excel.createExcel();

    await _createChartItemSheet(excel, '일별', dailyItems);
    await _createChartItemSheet(excel, '주별', weeklyItems);
    await _createChartItemSheet(excel, '월별', monthlyItems);
    await _createChartItemSheet(excel, '연별', yearlyItems);

    final toDelete = <String>[];
    for (final s in excel.tables.keys) {
      if (!['일별', '주별', '월별', '연별'].contains(s)) toDelete.add(s);
    }
    for (final s in toDelete) {
      excel.delete(s);
    }

    final bytes = excel.save();
    return bytes ?? [];
  }

  static Future<void> _createChartItemSheet(Excel excel, String sheetName, List<ChartItem> items) async {
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue100,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headerRow = ['날짜', '거리', '시간', '배터리(%)'];
    for (int i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headerRow[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final row = i + 1;

      final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      dateCell.value = TextCellValue(item.date ?? '');
      dateCell.cellStyle = dataStyle;

      final distanceCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      distanceCell.value = DoubleCellValue(double.parse((item.distance ?? 0.0).toStringAsFixed(2)));
      distanceCell.cellStyle = dataStyle;

      final timeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      timeCell.value = DoubleCellValue(double.parse((item.time ?? 0.0).toStringAsFixed(2)));
      timeCell.cellStyle = dataStyle;

      final batteryCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      batteryCell.value = DoubleCellValue(double.parse((item.battery ?? 0.0).toStringAsFixed(2)));
      batteryCell.cellStyle = dataStyle;
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 12);

    if (items.isEmpty) {
      final noData = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      noData.value = TextCellValue('데이터가 없습니다.');
      noData.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontColorHex: ExcelColor.grey,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1),
      );
    }
  }

  String _generateFileName(String robotName) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return '운행기록_${robotName}_${formatter.format(now)}.xlsx';
  }
}
