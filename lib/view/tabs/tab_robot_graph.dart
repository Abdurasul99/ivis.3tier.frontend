import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../model/graph_model.dart';
import '../../utils/download_utils.dart';
import '../../utils/utils.dart';
import '../components/chart_view.dart';
import '../components/gradient_button.dart';

class TabRobotGraph extends StatefulWidget {
  const TabRobotGraph({super.key});

  @override
  State<TabRobotGraph> createState() => _TabRobotGraphState();
}

class _TabRobotGraphState extends State<TabRobotGraph> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            SizedBox(
              width: 142,
              child: GradientButton(
                buttonText: "운행 기록 내보내기",
                buttonColor: const Color(0xFF005FB8),
                onTap: () async {
                  try {
                    Get.dialog(
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                      barrierDismissible: false,
                    );

                    List<ChartItem> dailyItems = await Get.find<GraphController>().reqUpdateChartItems('daily');
                    List<ChartItem> weeklyItems = await Get.find<GraphController>().reqUpdateChartItems('weekly');
                    List<ChartItem> monthlyItems = await Get.find<GraphController>().reqUpdateChartItems('monthly');
                    List<ChartItem> yearlyItems = await Get.find<GraphController>().reqUpdateChartItems('yearly');

                    // debugPrint("weekly $weeklyItems");
                    // debugPrint("monthly $monthlyItems");
                    // debugPrint("yearly $yearlyItems");

                    final excelBytes = await convertChartItemsToExcel(
                      dailyItems: dailyItems,
                      weeklyItems: weeklyItems,
                      monthlyItems: monthlyItems,
                      yearlyItems: yearlyItems,
                    );

                    String robotName = Get.find<RobotController>().getRobotNameByRobotId(
                      Get.find<GraphController>().selectedRobotId,
                    );

                    String fileName = generateFileName(robotName);

                    DownloadUtils.downloadExcelFile(
                      excelBytes: Uint8List.fromList(excelBytes),
                      fileName: fileName,
                    );
                    Get.back();

                    Utils.showSnackBar("운행 기록이 저장되었습니다.");
                  } catch (e) {
                    if (Get.isDialogOpen ?? false) {
                      Get.back();
                    }

                    Utils.showSnackBar("Excel 파일 생성 중 오류가 발생했습니다: $e", isError: true);
                    debugPrint("[Exception] $e");
                  }
                },
              ),
            ),
            const SizedBox(width: 26),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ChartView(type: "distance"),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ChartView(type: "time"),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ChartView(type: "battery"),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static Future<List<int>> convertChartItemsToExcel({
    required List<ChartItem> dailyItems,
    required List<ChartItem> weeklyItems,
    required List<ChartItem> monthlyItems,
    required List<ChartItem> yearlyItems,
  }) async {
    var excel = Excel.createExcel();

    await createChartItemSheet(excel, '일별', dailyItems);
    await createChartItemSheet(excel, '주별', weeklyItems);
    await createChartItemSheet(excel, '월별', monthlyItems);
    await createChartItemSheet(excel, '연별', yearlyItems);

    List<String> sheetsToDelete = [];
    for (String sheetName in excel.tables.keys) {
      if (!['일별', '주별', '월별', '연별'].contains(sheetName)) {
        sheetsToDelete.add(sheetName);
      }
    }

    for (String sheetName in sheetsToDelete) {
      excel.delete(sheetName);
    }

    var fileBytes = excel.save();
    return fileBytes ?? [];
  }

  static Future<void> createChartItemSheet(Excel excel, String sheetName, List<ChartItem> items) async {
    Sheet sheet = excel[sheetName];

    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue100,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    CellStyle dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    var headerRow = ['날짜', '거리', '시간', '배터리(%)'];
    for (int i = 0; i < headerRow.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headerRow[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < items.length; i++) {
      ChartItem item = items[i];
      int rowIndex = i + 1;

      var dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      dateCell.value = TextCellValue(item.date ?? '');
      dateCell.cellStyle = dataStyle;

      var distanceCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      distanceCell.value = DoubleCellValue(double.parse((item.distance ?? 0.0).toStringAsFixed(2)));
      distanceCell.cellStyle = dataStyle;

      var timeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      timeCell.value = DoubleCellValue(double.parse((item.time ?? 0.0).toStringAsFixed(2)));
      timeCell.cellStyle = dataStyle;

      var batteryCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      batteryCell.value = DoubleCellValue(double.parse((item.battery ?? 0.0).toStringAsFixed(2)));
      batteryCell.cellStyle = dataStyle;
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 12);

    if (items.isEmpty) {
      var noDataCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      noDataCell.value = TextCellValue('데이터가 없습니다.');
      noDataCell.cellStyle = CellStyle(
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

  String generateFileName(String robotName) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return '운행기록_${robotName}_${formatter.format(now)}.xlsx';
  }
}
