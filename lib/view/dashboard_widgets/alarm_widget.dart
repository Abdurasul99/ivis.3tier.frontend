import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/notification_model.dart';
import '../../viewmodel/controller/notification_controller.dart';

class AlarmWidget extends StatefulWidget {
  const AlarmWidget({super.key, this.gotoAlarmSet});

  final Function? gotoAlarmSet;

  @override
  State<AlarmWidget> createState() => _AlarmWidgetState();
}

class _AlarmWidgetState extends State<AlarmWidget> {
  late final NotificationController ctrl;

  @override
  void initState() {
    super.initState();

    if (Get.find<NotificationController>().notifications.isEmpty) {
      Get.find<NotificationController>().reqNotifications(null, null);
    }
  }

  String formatDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return "";

    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      DateTime now = DateTime.now();

      bool isToday = dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;

      if (isToday) {
        String period = dateTime.hour < 12 ? "오전" : "오후";
        int hour = dateTime.hour <= 12 ? dateTime.hour : dateTime.hour - 12;
        if (hour == 0) hour = 12;

        return "$period ${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
      } else {
        return "${dateTime.month}월 ${dateTime.day}일";
      }
    } catch (e) {
      return dateTimeStr.length > 16 ? dateTimeStr.substring(0, 16) : dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotificationController>(
      init: NotificationController(),
      builder: (controller) {
        if (controller.isLoading) {
          return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
        }

        if (controller.notifications.isEmpty) {
          return const Center(
            child: Text(
              '알림이 없습니다 😑',
              style: TextStyle(
                fontSize: 18,
                color: kHintColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '주요 알림',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      if (widget.gotoAlarmSet != null) {
                        (widget.gotoAlarmSet)!();
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF005FB8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  itemBuilder: (BuildContext context, int index) {
                    NotificationItem item = controller.notifications[index];
                    return buildNotificationItem(item);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildNotificationItem(NotificationItem item) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications, size: 20, color: Color(0xFF666565)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.comment ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 100,
            alignment: Alignment.centerRight,
            child: Text(
              formatDateTime(item.createTs ?? ""),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
