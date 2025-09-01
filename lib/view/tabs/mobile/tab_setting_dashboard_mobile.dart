// lib/view/tabs/mobile/tab_setting_dashboard_mobile.dart
//
// Мобильный дашборд с адаптивной 1‑/2‑колоночной сеткой.
// Каждой карточке дали больше воздуха: _layoutHeight = 280.

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/utils/stubs/js_stub.dart' if (dart.library.html) 'dart:js' as js;

import '/model/dashboard_model.dart';
import '/utils/utils.dart';
import '/view/components/gradient_button.dart';
import '/view/dialogs/dashboard_widget_dialog.dart';
import '/viewmodel/controller/dashboard_controller.dart';

import 'dashboard_widgets_mobile/alarm_widget_mobile.dart';
import 'dashboard_widgets_mobile/device_status_widget_mobile.dart';
import 'dashboard_widgets_mobile/moving_distance_by_day_widget_mobile.dart';
import 'dashboard_widgets_mobile/moving_distance_widget_mobile.dart';
import 'dashboard_widgets_mobile/operation_time_by_day_widget_mobile.dart';
import 'dashboard_widgets_mobile/operation_time_widget_mobile.dart';
import 'dashboard_widgets_mobile/robot_type_success_widget_mobile.dart';
import 'dashboard_widgets_mobile/used_battery_by_day_widget_mobile.dart';
import 'dashboard_widgets_mobile/used_battery_widget_mobile.dart';

class TabSettingDashboardMobile extends StatefulWidget {
  const TabSettingDashboardMobile({super.key});

  @override
  State<TabSettingDashboardMobile> createState() => _TabSettingDashboardMobileState();
}

class _TabSettingDashboardMobileState extends State<TabSettingDashboardMobile> {
  /* ────────── layout flags ────────── */
  List<bool> _layoutSetRow0 = <bool>[false, false, false];
  List<bool> _layoutSetRow1 = <bool>[false, false, false];
  bool _showFirstRow = false;
  bool _showSecondRow = false;

  /* ────────── constants ────────── */
  static const double _layoutHeight = 280.0; // waS 200
  static const double _outerHorizontalPadding = 16.0;
  static const double _outerVerticalPadding = 12.0;

  /* ────────── lifecycle ────────── */
  @override
  void initState() {
    super.initState();
    _loadDashboardLayoutSettings();
    _disableContextMenu();
  }

  @override
  void dispose() {
    _enableContextMenu();
    super.dispose();
  }

  /* ────────── context‑menu block (Web workaround) ────────── */
  void _disableContextMenu() {
    js.context.callMethod('eval', <Object>[
      '''
        window._oldContextMenuHandler = document.oncontextmenu;
        document.oncontextmenu = function(e){e.preventDefault();return false;};
      '''
    ]);
  }

  void _enableContextMenu() {
    js.context.callMethod('eval', <Object>[
      '''
        document.oncontextmenu = window._oldContextMenuHandler;
      '''
    ]);
  }

  /* ────────── data loading ────────── */
  Future<void> _loadDashboardLayoutSettings() async {
    _layoutSetRow0 = <bool>[false, false, false];
    _layoutSetRow1 = <bool>[false, false, false];
    _showFirstRow = _showSecondRow = false;

    await Get.find<DashboardController>().reqDashboardLayoutSetting();

    for (final LayoutSet set in Get.find<DashboardController>().layoutSets) {
      if (set.rowIndex == 0) {
        _layoutSetRow0[set.columnIndex ?? 0] = true;
        _showFirstRow = true;
      } else if (set.rowIndex == 1) {
        _layoutSetRow1[set.columnIndex ?? 0] = true;
        _showSecondRow = true;
      }
    }
    if (mounted) setState(() {});
  }

  /* ────────── build ────────── */
  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      init: DashboardController(),
      builder: (_) {
        final bool hasFreeCell =
            !_showFirstRow || _layoutSetRow0.contains(false) || !_showSecondRow || _layoutSetRow1.contains(false);

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _outerHorizontalPadding,
              vertical: _outerVerticalPadding,
            ),
            child: Column(
              children: <Widget>[
                _buildTopButtons(),
                if (_showFirstRow || _showSecondRow) _buildLayoutsFrame(),
                if (hasFreeCell) _buildAddRowButton(),
                _buildMapArea(),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ─────────────────── TOP BUTTONS ─────────────────── */
  Widget _buildTopButtons() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isNarrow = constraints.maxWidth < 360.0;

        final Widget saveButton = SizedBox(
          height: 36.0,
          width: double.infinity,
          child: GradientButton(
            buttonText: '대시보드 저장',
            buttonColor: const Color(0xFF005FB8),
            onTap: () async {
              final DashboardController dc = Get.find<DashboardController>();
              if (dc.isEmptyLayouts()) {
                Utils.showSnackBar('저장할 대시보드가 없습니다.', isWarning: true);
                return;
              }
              final bool ok = await dc.saveLayouts();
              Utils.showSnackBar(
                ok ? '대시보드 레이아웃이 저장되었습니다!' : '저장에 실패했습니다.',
                isError: !ok,
              );
            },
          ),
        );

        final Widget cancelButton = SizedBox(
          height: 36.0,
          width: double.infinity,
          child: GradientButton(
            buttonText: '취소',
            onTap: () => _loadDashboardLayoutSettings(),
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: isNarrow
              ? Column(
                  children: <Widget>[
                    saveButton,
                    const SizedBox(height: 8.0),
                    cancelButton,
                  ],
                )
              : SizedBox(
                  height: 36.0,
                  child: Row(
                    children: <Widget>[
                      Expanded(child: saveButton),
                      const SizedBox(width: 12.0),
                      Expanded(child: cancelButton),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /* ─────────────────── layouts frame ─────────────────── */
  Widget _buildLayoutsFrame() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F8),
        border: Border.all(color: const Color(0xFFB3B3B3)),
      ),
      child: Column(
        children: <Widget>[
          if (_showFirstRow) _buildRow(0),
          if (_showSecondRow) _buildRow(1),
          GestureDetector(
            onTap: () {
              if (_showSecondRow) {
                Get.find<DashboardController>().deleteLayoutByRow(1);
                _layoutSetRow1 = <bool>[false, false, false];
                _showSecondRow = false;
              } else if (_showFirstRow) {
                Get.find<DashboardController>().deleteLayoutByRow(0);
                _layoutSetRow0 = <bool>[false, false, false];
                _showFirstRow = false;
              }
              if (mounted) setState(() {});
            },
            child: const SizedBox(
              height: 32.0,
              child: Center(
                child: Text(
                  '- 행 삭제',
                  style: TextStyle(fontSize: 14.0, color: Color(0xFF666565)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ─────────────────── rows / layouts ─────────────────── */
  LayoutSet? _getLayout(int row, int column) {
    for (final LayoutSet set in Get.find<DashboardController>().layoutSets) {
      if (set.rowIndex == row && set.columnIndex == column) return set;
    }
    return null;
  }

  Widget _buildRow(int row) {
    final List<bool> flags = row == 0 ? _layoutSetRow0 : _layoutSetRow1;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final bool twoColumns = maxWidth > 500.0;
        final double spacing = 8.0;
        final double cardWidth = twoColumns ? (maxWidth - spacing) / 2 : maxWidth;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: <Widget>[
              for (int column = 0; column < 3; column++)
                if (flags[column])
                  SizedBox(
                    width: cardWidth,
                    child: _buildLayout(
                      _getLayout(row, column),
                      row,
                      column,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayout(LayoutSet? layout, int row, int column) {
    if (layout == null || (layout.title ?? '').isEmpty) {
      return GestureDetector(
        onTap: () => showDialog<Widget>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DashboardWidgetDialog(row: row, column: column, layoutSet: layout),
        ),
        child: _buildEmptyLayout(),
      );
    }

    // Card selection
    Widget widgetToShow;
    switch (layout.title) {
      case '로봇 타입별 작업 성공률':
        widgetToShow = const RobotTypeSuccessWidgetMobile();
        break;
      case '기기 운행 현황':
        widgetToShow = const DeviceStatusWidgetMobile();
        break;
      case '주요 알림':
        widgetToShow = AlarmWidgetMobile(
          onViewAll: () {},
        );
        break;
      case '전체 로봇의 누적 주행거리':
        widgetToShow = const MovingDistanceWidgetMobile();
        break;
      case '전체 로봇의 누적 운영시간':
        widgetToShow = const OperationTimeWidgetMobile();
        break;
      case '전체 로봇의 누적 사용배터리':
        widgetToShow = const UsedBatteryWidgetMobile();
        break;
      case '로봇별 일평균 주행거리':
        widgetToShow = const MovingDistanceByDayWidgetMobile();
        break;
      case '로봇별 일평균 운영시간':
        widgetToShow = const OperationTimeByDayWidgetMobile();
        break;
      case '로봇별 일평균 사용배터리':
        widgetToShow = const UsedBatteryByDayWidgetMobile();
        break;
      default:
        widgetToShow = Center(child: Text('Unknown: ${layout.title}'));
    }

    return Container(
      height: _layoutHeight,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF666565), width: 1.5),
      ),
      child: Stack(
        children: <Widget>[
          widgetToShow,
          Positioned(
            right: 10.0,
            top: 10.0,
            child: GestureDetector(
              onTap: () {
                Get.find<DashboardController>().deleteLayout(row, column);
                (row == 0 ? _layoutSetRow0 : _layoutSetRow1)[column] = false;
                if (mounted) setState(() {});
              },
              child: Container(
                width: 22.0,
                height: 22.0,
                decoration: const BoxDecoration(
                  color: kBlackFontColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.close, size: 18.0, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ─────────────────── helpers ─────────────────── */
  Widget _buildEmptyLayout() {
    return Container(
      height: _layoutHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F8),
        border: Border.all(color: const Color(0xFF666565), width: 1.5),
      ),
      alignment: Alignment.center,
      child: _buildAddIcon(),
    );
  }

  /// «+ 행 추가»
  Widget _buildAddRowButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DottedBorder(
        color: const Color(0xFFB3B3B3),
        strokeWidth: 0.5,
        dashPattern: const <double>[3.0, 2.0],
        child: GestureDetector(
          onTap: () {
            if (!_showFirstRow) {
              setState(() => _showFirstRow = true);
              return;
            }
            final int freeColumnRow0 = _layoutSetRow0.indexWhere((bool flag) => flag == false);
            if (freeColumnRow0 != -1) {
              setState(() => _layoutSetRow0[freeColumnRow0] = true);
              return;
            }
            if (!_showSecondRow) {
              setState(() => _showSecondRow = true);
              return;
            }
            final int freeColumnRow1 = _layoutSetRow1.indexWhere((bool flag) => flag == false);
            if (freeColumnRow1 != -1) {
              setState(() => _layoutSetRow1[freeColumnRow1] = true);
              return;
            }

            Utils.showSnackBar('더 이상 행을 추가할 수 없습니다.');
          },
          child: Container(
            height: 36.0,
            color: const Color(0xFFFAF8F8),
            alignment: Alignment.center,
            child: const Text(
              '+ 행 추가',
              style: TextStyle(fontSize: 15.0, color: Color(0xFF666565)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    return Container(
      height: 180.0,
      color: const Color(0xFF666565),
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          Icon(Icons.map_outlined, size: 24.0, color: Colors.white),
          SizedBox(width: 6.0),
          Text(
            '지도 영역',
            style: TextStyle(
              fontSize: 18.0,
              color: Colors.white,
              fontFamily: 'pretendard',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddIcon() {
    return Container(
      width: 46.0,
      height: 46.0,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF666565), width: 2.0),
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Container(
              width: 2.0,
              height: 18.0,
              color: const Color(0xFF666565),
            ),
          ),
          Center(
            child: Container(
              width: 18.0,
              height: 2.0,
              color: const Color(0xFF666565),
            ),
          ),
        ],
      ),
    );
  }
}
