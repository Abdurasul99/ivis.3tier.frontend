import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/utils/stubs/js_stub.dart' if (dart.library.html) 'dart:js' as js;
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/tabs/mobile/tab_setting_dashboard_mobile.dart';
import 'package:get/get.dart';

import '../../model/dashboard_model.dart';
import '../../utils/utils.dart';
import '../../view/dashboard_widgets/device_status_widget.dart';
import '../../view/dashboard_widgets/robot_type_success_widget.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../components/gradient_button.dart';
import '../dashboard_widgets/alarm_widget.dart';
import '../dashboard_widgets/moving_distance_by_day_widget.dart';
import '../dashboard_widgets/moving_distance_widget.dart';
import '../dashboard_widgets/operation_time_by_day_widget.dart';
import '../dashboard_widgets/operation_time_widget.dart';
import '../dashboard_widgets/used_battery_by_day_widget.dart';
import '../dashboard_widgets/used_battery_widget.dart';
import '../dialogs/dashboard_widget_dialog.dart';

class TabSettingDashboard extends StatefulWidget {
  const TabSettingDashboard({super.key});

  @override
  State<TabSettingDashboard> createState() => _TabSettingDashboardState();
}

class _TabSettingDashboardState extends State<TabSettingDashboard> {
  final GlobalKey _menuKey = GlobalKey();

  List<bool> _layoutSetRow0 = [false, false, false];
  List<bool> _layoutSetRow1 = [false, false, false];

  bool _showRow1st = false;
  bool _showRow2nd = false;

  @override
  void initState() {
    super.initState();
    loadDashboardLayoutSettings();
    disableContextMenu();
  }

  @override
  void dispose() {
    enableContextMenu();
    super.dispose();
  }

  void disableContextMenu() {
    js.context.callMethod('eval', [
      '''
      window._oldContextMenuHandler = document.oncontextmenu;
      document.oncontextmenu = function(e) {
        e.preventDefault();
        return false;
      };
      '''
    ]);
  }

  void enableContextMenu() {
    js.context.callMethod('eval', [
      '''
      document.oncontextmenu = window._oldContextMenuHandler;
      '''
    ]);
  }

  Future<void> loadDashboardLayoutSettings() async {
    _layoutSetRow0 = [false, false, false];
    _layoutSetRow1 = [false, false, false];

    await Get.find<DashboardController>().reqDashboardLayoutSetting();
    List<LayoutSet> sets = Get.find<DashboardController>().layoutSets;

    for (int i = 0; i < sets.length; i++) {
      if (sets[i].rowIndex == 0) {
        _layoutSetRow0[sets[i].columnIndex ?? 0] = true;
        _showRow1st = true;
      } else if (sets[i].rowIndex == 1) {
        _layoutSetRow1[sets[i].columnIndex ?? 0] = true;
        _showRow2nd = true;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabSettingDashboardMobile();
    }

    return GetBuilder<DashboardController>(
      init: DashboardController(),
      builder: (controller) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 36, vertical: 20),
          alignment: Alignment.center,
          child: Column(
            children: [
              buildTopButtons(),
              if (_showRow1st || _showRow2nd)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF8F8),
                    border: Border.all(color: const Color(0xFFB3B3B3), width: 1.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_showRow1st) buildRow(0),
                      if (_showRow2nd) buildRow(1),
                      Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () {
                            if (_showRow2nd) {
                              Get.find<DashboardController>().deleteLayoutByRow(1);
                              _layoutSetRow1 = [false, false, false];
                              _showRow2nd = false;
                            } else if (_showRow1st) {
                              Get.find<DashboardController>().deleteLayoutByRow(0);
                              _layoutSetRow0 = [false, false, false];
                              _showRow1st = false;
                            }
                          },
                          child: Text(
                            '- 행 삭제',
                            style: TextStyle(
                              color: Color(0xFF666565),
                              fontFamily: 'pretendard',
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_showRow2nd == false) buildAddRowButton(),
              Expanded(child: buildMapArea()),
            ],
          ),
        );
      },
    );
  }

  Widget buildTopButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 200,
            height: 40,
            child: GradientButton(
              buttonText: "대시보드 저장",
              buttonColor: const Color(0xFF005FB8),
              onTap: () async {
                // if (Get.find<DashboardController>().isEmptyLayouts()) {
                //   Utils.showSnackBar("저장할 대시보드가 없습니다.", isWarning: true);
                //   return;
                // }

                bool result = await Get.find<DashboardController>().saveLayouts();

                if (result) {
                  Utils.showSnackBar("대시보드 레이아웃이 저장되었습니다!");
                } else {
                  Utils.showSnackBar("저장에 실패했습니다.", isError: true);
                }
              },
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 200,
            height: 40,
            child: GradientButton(
              buttonText: "취소",
              onTap: () {
                loadDashboardLayoutSettings();
              },
            ),
          ),
        ],
      ),
    );
  }

  LayoutSet? getLayoutSet(int row, int column) {
    List<LayoutSet> sets = Get.find<DashboardController>().layoutSets;
    for (int i = 0; i < sets.length; i++) {
      LayoutSet layoutSet = sets[i];

      if (layoutSet.rowIndex == row && layoutSet.columnIndex == column) {
        return layoutSet;
      }
    }
    return null;
  }

  Widget buildLayout(LayoutSet? layout, int row, int column) {
    // if (layout == null) {
    //   return Container();
    // }

    if (layout == null || layout.title == null || layout.title!.isEmpty) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: Get.context!,
            builder: (BuildContext context) {
              return DashboardWidgetDialog(
                row: row,
                column: column,
                layoutSet: layout,
              );
            },
            barrierDismissible: false,
          );
        },
        child: buildEmptyLayout(),
      );
    }

    Widget dashboardWidget;

    if (layout.title == '로봇 타입별 작업 성공률') {
      dashboardWidget = const RobotTypeSuccessWidget();
    } else if (layout.title == '기기 운행 현황') {
      dashboardWidget = const DeviceStatusWidget();
    } else if (layout.title == '주요 알림') {
      dashboardWidget = const AlarmWidget();
    } else if (layout.title == '전체 로봇의 누적 주행거리') {
      dashboardWidget = const MovingDistanceWidget();
    } else if (layout.title == '전체 로봇의 누적 운영시간') {
      dashboardWidget = const OperationTimeWidget();
    } else if (layout.title == '전체 로봇의 누적 사용배터리') {
      dashboardWidget = const UsedBatteryWidget();
    } else if (layout.title == '로봇별 일평균 주행거리') {
      dashboardWidget = const MovingDistanceByDayWidget();
    } else if (layout.title == '로봇별 일평균 운영시간') {
      dashboardWidget = const OperationTimeByDayWidget();
    } else if (layout.title == '로봇별 일평균 사용배터리') {
      dashboardWidget = const UsedBatteryByDayWidget();
    } else {
      dashboardWidget = Center(child: Text('Unknown: ${layout.title}'));
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(width: 1.5, color: const Color(0xFF666565)),
      ),
      child: Stack(
        children: [
          dashboardWidget,
          Positioned(
            right: 12,
            top: 12,
            child: GestureDetector(
              onTap: () {
                Get.find<DashboardController>().deleteLayout(row, column);
                if (row == 0) {
                  _layoutSetRow0[column] = false;
                } else {
                  _layoutSetRow1[column] = false;
                }

                if (mounted) {
                  setState(() {});
                }
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: kBlackFontColor,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRow(int rowIndex) {
    LayoutSet? layout1 = getLayoutSet(rowIndex, 0);
    LayoutSet? layout2 = getLayoutSet(rowIndex, 1);
    LayoutSet? layout3 = getLayoutSet(rowIndex, 2);

    bool isExist2ndColumn = false;
    bool isExist3rdColumn = false;

    if (rowIndex == 0) {
      isExist2ndColumn = _layoutSetRow0[1];
      isExist3rdColumn = _layoutSetRow0[2];
    } else {
      isExist2ndColumn = _layoutSetRow1[1];
      isExist3rdColumn = _layoutSetRow1[2];
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (TapDownDetails details) {
          debugPrint("onSecondaryTapDown() rowIndex $rowIndex, $_layoutSetRow0, $_layoutSetRow1");

          if (rowIndex == 0) {
            if (_layoutSetRow0[0] && _layoutSetRow0[1] && _layoutSetRow0[2]) {
              return;
            }
          }

          if (rowIndex == 1) {
            if (_layoutSetRow1[0] && _layoutSetRow1[1] && _layoutSetRow1[2]) {
              return;
            }
          }

          showCustomMenu(details.globalPosition, rowIndex);

          if (mounted) {
            setState(() {});
          }
        },
        onSecondaryTap: () {},
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: Row(
                  children: [
                    Expanded(child: buildLayout(layout1, rowIndex, 0)),
                    if (isExist2ndColumn) const SizedBox(width: 10),
                    if (isExist2ndColumn) Expanded(child: buildLayout(layout2, rowIndex, 1)),
                    if (isExist3rdColumn) const SizedBox(width: 10),
                    if (isExist3rdColumn) Expanded(child: buildLayout(layout3, rowIndex, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEmptyLayout() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(width: 1.5, color: const Color(0xFF666565)),
        color: const Color(0xFFFAF8F8),
      ),
      alignment: Alignment.center,
      child: buildAddIcon(),
    );
  }

  Widget buildAddRowButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        key: _menuKey,
        onTap: () async {
          final box = _menuKey.currentContext!.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero);
          final size = box.size;

          final selected = await showMenu<int>(
            context: context,
            position: RelativeRect.fromLTRB(
              offset.dx + size.width / 2 + 60,
              offset.dy + size.height - 36,
              offset.dx + size.width / 2 + 70,
              0,
            ),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            items: [
              PopupMenuItem(
                value: 1,
                child: Center(
                  child: Text(
                    '1열',
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                      color: Color(0xFF000000),
                    ),
                  ),
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Center(
                  child: Text(
                    '2열',
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                      color: Color(0xFF000000),
                    ),
                  ),
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Center(
                  child: Text(
                    '3열',
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                      color: Color(0xFF000000),
                    ),
                  ),
                ),
              ),
            ],
          );

          if (selected != null) {
            int columnIndex = selected;

            if (_showRow1st == false) {
              _showRow1st = true;
              for (int i = 0; i < columnIndex; i++) {
                _layoutSetRow0[i] = true;
              }

              if (mounted) {
                setState(() {});
              }
            } else if (_showRow2nd == false) {
              _showRow2nd = true;
              for (int i = 0; i < columnIndex; i++) {
                _layoutSetRow1[i] = true;
              }

              if (mounted) {
                setState(() {});
              }
            }
          }
        },
        child: DottedBorder(
          color: const Color(0xFFB3B3B3),
          strokeWidth: 0.5,
          dashPattern: const [3, 2],
          child: Container(
            color: Color(0xFFFAF8F8),
            height: 40,
            alignment: Alignment.center,
            child: Text(
              '+ 행 추가',
              style: TextStyle(
                color: Color(0xFF666565),
                fontFamily: 'pretendard',
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showCustomMenu(Offset position, int rowIndex) async {
    debugPrint("showCustomMenu() rowIndex: $rowIndex");

    final RelativeRect positionRelative = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    );

    final value = await showMenu(
      context: context,
      position: positionRelative,
      items: <PopupMenuEntry>[
        PopupMenuItem(
          value: 'add_column',
          height: 40,
          child: Container(
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.increase_quotelevel, color: Color(0xFF666565)),
                SizedBox(width: 6),
                Text(
                  '열 추가',
                  style: TextStyle(
                    color: Color(0xFF666565),
                    fontFamily: 'pretendard',
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (value == 'add_column') {
      List<List<bool>> layoutSetRows = [_layoutSetRow0, _layoutSetRow1];

      if (layoutSetRows[rowIndex][0] == false) {
        layoutSetRows[rowIndex][0] = true;
      }

      if (layoutSetRows[rowIndex][1] == false) {
        layoutSetRows[rowIndex][1] = true;
        if (mounted) {
          setState(() {});
        }
        return;
      }

      if (layoutSetRows[rowIndex][2] == false) {
        layoutSetRows[rowIndex][2] = true;
        if (mounted) {
          setState(() {});
        }
        return;
      }
    }
  }

  Widget buildMapArea() {
    return Container(
      color: const Color(0xFF666565),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 24, color: Colors.white),
          const SizedBox(width: 6),
          const Text(
            '지도 영역',
            style: TextStyle(
              fontFamily: 'pretendard',
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAddIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF666565), width: 2.0),
        borderRadius: const BorderRadius.all(Radius.circular(50.0)),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 2,
              height: 20,
              color: const Color(0xFF666565),
            ),
          ),
          Center(
            child: Container(
              width: 20,
              height: 2,
              color: const Color(0xFF666565),
            ),
          ),
        ],
      ),
    );
  }
}
