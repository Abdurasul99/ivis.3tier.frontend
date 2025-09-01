// lib/view/tabs/mobile/dashboard_widgets_mobile/alarm_widget_mobile.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/model/notification_model.dart';
import '/viewmodel/controller/notification_controller.dart';

/// Mobile‑optimised alarm list (top‑5).
class AlarmWidgetMobile extends StatefulWidget {
  const AlarmWidgetMobile({
    Key? key,
    required this.onViewAll,
  }) : super(key: key);

  final VoidCallback onViewAll;

  @override
  State<AlarmWidgetMobile> createState() => _AlarmWidgetMobileState();
}

class _AlarmWidgetMobileState extends State<AlarmWidgetMobile> {
  @override
  void initState() {
    super.initState();
    final nc = Get.find<NotificationController>();
    if (nc.notifications.isEmpty) {
      nc.reqNotifications(null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotificationController>(
      init: NotificationController(),
      builder: (c) {
        if (c.isLoading) {
          return const Center(child: CupertinoActivityIndicator(radius: 16));
        }
        if (c.notifications.isEmpty) {
          return const Center(
            child: Text(
              '알림이 없습니다 😑',
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: kHintColor,
              ),
            ),
          );
        }

        final List<NotificationItem> top = c.notifications.take(5).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ───── Header ─────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '주요 알림',
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF666565),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onViewAll();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF005FB8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ───── List ─────
              Expanded(
                child: Center(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: top.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _AlarmRow(item: top[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlarmRow extends StatelessWidget {
  const _AlarmRow({required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.notifications, size: 20, color: Color(0xFF666565)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.comment ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
        ],
      );
}
