import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/tabs/mobile/tab_setting_alarm_mobile.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/notification_model.dart';
import '../../viewmodel/controller/notification_controller.dart';
import '../dialogs/period_select_dialog.dart';

class TabSettingAlarm extends StatefulWidget {
  const TabSettingAlarm({super.key});

  @override
  State<TabSettingAlarm> createState() => _TabSettingAlarmState();
}

class _TabSettingAlarmState extends State<TabSettingAlarm> {
  final GlobalKey _dateTimeButtonKey = GlobalKey();

  String _startDate = "";
  String _endDate = "";
  bool _orderAsc = true;
  @override
  void initState() {
    super.initState();
    Get.find<NotificationController>().reqNotifications(null, null);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabSettingAlarmMobile();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주요 알림',
            style: TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              color: kDarkGrayColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 40,
            color: const Color(0xFFFAFAFA),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                //     Container(
                GestureDetector(
                  onTap: () => setState(() => _orderAsc = !_orderAsc),
                  child: Container(
                    width: 160,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "알림 위치",
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
                GestureDetector(
                  onTap: onDateTimeButtonTap,
                  key: _dateTimeButtonKey,
                  child: Container(
                    width: 200,
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
            child: GetBuilder<NotificationController>(
              init: NotificationController(),
              builder: (controller) {
                if (controller.isLoading) {
                  return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
                }

                if (controller.notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      '조건에 맞는 알림 정보가 없습니다 😑',
                      style: TextStyle(
                        fontSize: 18,
                        color: kHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }

                final items = [...controller.notifications]..sort((a, b) {
                    final ka = (a.alarmType ?? '');
                    final kb = (b.alarmType ?? '');
                    return _orderAsc ? ka.compareTo(kb) : kb.compareTo(ka);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = items[index];
                    return buildNotificationItem(item);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          GetBuilder<NotificationController>(
            builder: (controller) => controller.getPageNationView(),
          ),
        ],
      ),
    );
  }

  Widget buildNotificationItem(NotificationItem item) {
    return GestureDetector(
      onTap: () {
        if (item.isRead != true) {
          Get.find<NotificationController>().reqReadNotification(item.id ?? -1);
        }
      },
      child: Container(
        height: 40,
        color: Colors.white,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                item.alarmType ?? "",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: (item.isRead == true) ? FontWeight.w400 : FontWeight.w500,
                    //           color: (item.isRead == true) ? Color(0xFF666565) : Colors.black,
                    color: Color(0xFF000000)),
              ),
            ),
            Container(
              width: 200,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                item.createTs ?? "",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: (item.isRead == true) ? FontWeight.w400 : FontWeight.w500,
                    //       color: (item.isRead == true) ? Color(0xFFD9D9D9) : Color(0xFF666565),
                    color: Color(0xFF000000)),
              ),
            ),
            Expanded(
              child: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  item.comment ?? "",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: (item.isRead == true) ? FontWeight.w400 : FontWeight.w500,
                      //      color: (item.isRead == true) ? Color(0xFF666565) : Colors.black,
                      color: Color(0xFF000000)),
                ),
              ),
            ),
          ],
        ),
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

        Get.find<NotificationController>().reqNotifications(startDate, endDate);
      }
    }
  }
}
