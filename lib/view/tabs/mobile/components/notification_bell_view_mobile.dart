import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/model/notification_model.dart';
import '/utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '/viewmodel/controller/dashboard_controller.dart';
import '/viewmodel/controller/notification_controller.dart';

class NotificationBellViewMobile extends StatelessWidget {
  const NotificationBellViewMobile({super.key});

  void _setIframePointerEvents(String iframeId, bool block) {
    if (!kIsWeb) return;
    final el = html.document.getElementById(iframeId);
    if (el != null) el.style.pointerEvents = block ? 'none' : 'auto';
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return GetBuilder<NotificationController>(
      init: NotificationController(),
      builder: (controller) {
        return IconButton(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications, size: isMobile ? 28 : 24, color: const Color(0xFF666565)),
              if (controller.unreadCount > 0)
                Positioned(
                  right: -7,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC42B1C),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      controller.unreadCount > 99 ? '99+' : '${controller.unreadCount}',
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () async {
            await controller.reqUnreadNotificationCount();
            await controller.reqNotifications(null, null);

            Get.find<NotificationController>().setNotificationDialogOpen(true);
            _setIframePointerEvents(Get.find<DashboardController>().mapViewId, true);

            final top = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

            if (isMobile) {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _buildBottomSheet(ctx),
              );
            } else {
              await showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Notifications',
                barrierColor: Colors.black.withOpacity(0.01),
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return _buildDialog(context, top);
                },
              );
            }

            Get.find<NotificationController>().setNotificationDialogOpen(false);
            _setIframePointerEvents(Get.find<DashboardController>().mapViewId, false);
          },
        );
      },
    );
  }

  /* ---------- DESKTOP / TABLET POP-UP ---------- */

  Widget _buildDialog(BuildContext context, double top) {
    final double w = MediaQuery.of(context).size.width.clamp(0, 400);
    final double h = (MediaQuery.of(context).size.height * 0.8).clamp(0, 500).toDouble();

    return Stack(
      children: [
        const Positioned.fill(child: ModalBarrier(dismissible: true, color: Colors.transparent)),
        Positioned(
          top: top,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: _DialogContent(onClose: Get.back),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    final double corner = 12;
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(corner)),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(child: _DialogContent(onClose: Get.back)),
          ],
        ),
      ),
    );
  }
}

class _DialogContent extends StatelessWidget {
  const _DialogContent({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8E8E8)),
        Expanded(child: _NotificationList()),
      ],
    );
  }
}

class _NotificationList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotificationController>(
      init: NotificationController(),
      builder: (controller) {
        if (controller.isLoading) {
          return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.grey));
        }

        if (controller.unreadNotifications.isEmpty) {
          return const Center(
            child: Text(
              '미확인 알림 정보가 없습니다 😑',
              style: TextStyle(
                fontSize: 18,
                color: kHintColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: controller.unreadNotifications.length,
          separatorBuilder: (_, __) => const SizedBox.shrink(),
          itemBuilder: (context, index) {
            final NotificationItem item = controller.unreadNotifications[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: item.isRead == true ? Colors.grey.shade200 : Colors.blue.shade50,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    item.isRead == true ? Icons.notifications : Icons.fiber_new,
                    key: ValueKey(item.isRead),
                    color: item.isRead == true ? Colors.grey : Colors.blue,
                    size: 20,
                  ),
                ),
              ),
              title: Text(
                item.comment ?? "",
                style: TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  fontWeight: item.isRead == true ? FontWeight.w400 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                item.createTs ?? "",
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              onTap: () {
                if (item.isRead != true) {
                  controller.reqReadNotification(item.id ?? -1);
                }
              },
            );
          },
        );
      },
    );
  }
}
