import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../utils/utils.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_text_logviewer.dart';
import '../dialogs/period_select_dialog.dart';

class TabRobotLogViewer extends StatefulWidget {
  const TabRobotLogViewer({super.key});

  @override
  State<TabRobotLogViewer> createState() => _TabRobotLogViewerState();
}

class _TabRobotLogViewerState extends State<TabRobotLogViewer> with RouteAware {
  final GlobalKey _dateTimeButtonKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _startDate = "";
  String _endDate = "";
  bool _orderAsc = true;

  @override
  void initState() {
    super.initState();
    Get.find<LogController>().clearSelectedIds();
  }

  @override
  void dispose() {
    super.dispose();

    _searchController.dispose();
    _searchFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 102,
                child: GradientButton(
                  buttonText: "전체 선택",
                  onTap: () {
                    List<RobotLog> logs = Get.find<LogController>().robotLogs;
                    for (int i = 0; i < logs.length; i++) {
                      Get.find<LogController>().addSelectedId(logs[i].id ?? -1);
                    }

                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 102,
                child: GradientButton(
                  buttonText: "선택 해제",
                  onTap: () {
                    List<RobotLog> logs = Get.find<LogController>().robotLogs;
                    for (int i = 0; i < logs.length; i++) {
                      Get.find<LogController>().removeSelectedId(logs[i].id ?? -1);
                    }

                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 102,
                child: GradientButton(
                  buttonText: "문서 저장",
                  buttonColor: const Color(0xFF005FB8),
                  onTap: () {
                    if (Get.find<LogController>().selectedIds.isEmpty) {
                      Utils.showSnackBar("항목을 선택하세요", isWarning: true);
                      return;
                    }

                    Get.find<LogController>().reqLogListForDocument();
                  },
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 120,
                child: GradientButton(
                  icon: Icon(CupertinoIcons.refresh, color: Colors.black, size: 20),
                  buttonText: "새로고침",
                  onTap: () {
                    Get.find<LogController>().setViewPage(0);
                    Get.find<LogController>().clearSelectedIds();
                    Get.find<LogController>().reqLogList(
                      startDate: _startDate,
                      endDate: _endDate,
                      keyword: _searchController.text,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InputEditTextLogViewer(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: '검색',
            onSubmitted: (value) {
              Get.find<LogController>().setViewPage(0);
              Get.find<LogController>().clearSelectedIds();
              Get.find<LogController>().reqLogList(
                startDate: _startDate,
                endDate: _endDate,
                keyword: _searchController.text,
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            color: const Color(0xFFFAFAFA),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Text(
                    "선택",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF666565),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDateTimeButtonTap,
                  key: _dateTimeButtonKey,
                  child: Container(
                    width: 154,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "날짜, 시간",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF666565),
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(CupertinoIcons.line_horizontal_3_decrease, size: 16, color: Color(0xFF666565)),
                      ],
                    ),
                  ),
                ),
                // Container(
                //   width: 120,
                //   height: 40,
                //   alignment: Alignment.center,
                //   child: const Row(
                //     mainAxisSize: MainAxisSize.min,
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     crossAxisAlignment: CrossAxisAlignment.center,
                //     children: [
                //       Text(
                //         "등급",
                //         style: TextStyle(
                //           fontSize: 15,
                //           fontWeight: FontWeight.w400,
                //           color: Color(0xFF666565),
                //         ),
                //       ),
                //       SizedBox(width: 6),
                //       Icon(CupertinoIcons.arrow_up_arrow_down, size: 16, color: Color(0xFF666565)),
                //     ],
                //   ),
                // ),
                GestureDetector(
                  onTap: () => setState(() => _orderAsc = !_orderAsc),
                  child: Container(
                    width: 120,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "등급",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF666565),
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(CupertinoIcons.arrow_up_arrow_down, size: 16, color: Color(0xFF666565)),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Container(
                    height: 40,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text(
                      "내용",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF666565),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GetBuilder<LogController>(
              init: LogController(),
              builder: (controller) {
                if (controller.isLoading) {
                  return Center(
                    child: CupertinoActivityIndicator(radius: 20, color: Colors.grey),
                  );
                }

                if (controller.robotLogs.isEmpty) {
                  return Center(
                    child: Text(
                      "조건에 맞는 로그가 없습니다. 😑",
                      style: TextStyle(
                        fontSize: 18,
                        color: kHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }

                final items = [...controller.robotLogs]..sort((a, b) {
                    final ka = (a.level ?? '');
                    final kb = (b.level ?? '');
                    return _orderAsc ? ka.compareTo(kb) : kb.compareTo(ka);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  //itemCount: controller.robotLogs.length,
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    // RobotLog log = controller.robotLogs[index];
                    final log = items[index];
                    return Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (controller.isSelectedId(log.id!)) {
                                controller.removeSelectedId(log.id ?? -1);
                              } else {
                                controller.addSelectedId(log.id ?? -1);
                              }

                              if (mounted) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              width: 70,
                              height: 40,
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                controller.isSelectedId(log.id!)
                                    ? "assets/images/icons_checkbox_checked.svg"
                                    : "assets/images/icons_checkbox_unchecked.svg",
                                width: 16,
                              ),
                            ),
                          ),
                          Container(
                            width: 154,
                            height: 40,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              log.createdTs ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF666565),
                              ),
                            ),
                          ),
                          Container(
                            width: 120,
                            height: 40,
                            alignment: Alignment.center,
                            child: Text(
                              log.level ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF666565),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 40,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                log.message ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF666565),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          GetBuilder<LogController>(
            init: LogController(),
            builder: (controller) {
              return Container(
                height: 70,
                alignment: Alignment.center,
                child: Get.find<LogController>().getPageNationView(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> onDateTimeButtonTap() async {
    final RenderBox renderBox = _dateTimeButtonKey.currentContext?.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final Map<String, String>? result = await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  Get.back();
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy + 20,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 373,
                  height: 262,
                  child: PeriodSelectDialog(
                    startDate: _startDate,
                    endDate: _endDate,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      debugPrint("result $result");
      String startDate = result['start'] ?? "";
      String endDate = result['end'] ?? "";

      if (startDate.isNotEmpty && endDate.isNotEmpty) {
        _startDate = startDate;
        _endDate = endDate;

        Get.find<LogController>().setViewPage(0);
        Get.find<LogController>().clearSelectedIds();
        Get.find<LogController>().reqLogList(
          startDate: _startDate,
          endDate: _endDate,
          keyword: _searchController.text,
        );
      }
    }
  }
}
