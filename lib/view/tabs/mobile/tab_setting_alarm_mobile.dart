import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/constants/constants.dart';
import '/model/notification_model.dart';
import '/view/tabs/mobile/dialogs/period_select_dialog_mobile.dart';
import '/viewmodel/controller/notification_controller.dart';

class TabSettingAlarmMobile extends StatefulWidget {
  const TabSettingAlarmMobile({
    Key? key,
    this.showAppBar = true,
  }) : super(key: key);

  final bool showAppBar;

  @override
  State<TabSettingAlarmMobile> createState() => _TabSettingAlarmMobileState();
}

class _TabSettingAlarmMobileState extends State<TabSettingAlarmMobile> {
  final GlobalKey _dateBtnKey = GlobalKey();
  bool _orderAsc = true;
  String _startDate = '';
  String _endDate = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<NotificationController>().reqNotifications(null, null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 37),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showAppBar) ...[
              const SizedBox(height: 8),
              const Text(
                '주요 알림',
                style: TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildFilterRow(),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() => Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _orderAsc = !_orderAsc),
              child: const _FilterButton(label: '알림 위치 ↑↓'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              key: _dateBtnKey,
              onTap: _showPeriodDialog,
              child: const _FilterButton(
                label: '날짜, 시간',
                trailing: Icon(
                  CupertinoIcons.line_horizontal_3_decrease,
                  size: 16,
                  color: Color(0xFF666565),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildList() => GetBuilder<NotificationController>(
        builder: (c) {
          if (c.isLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 18));
          }
          if (c.notifications.isEmpty) {
            return const Center(
              child: Text(
                '조건에 맞는 알림 정보가 없습니다 😑',
                style: TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 16,
                  color: kHintColor,
                ),
              ),
            );
          }

          final items = List<NotificationItem>.from(c.notifications)
            ..sort((a, b) => _orderAsc
                ? (a.alarmType ?? '').compareTo(b.alarmType ?? '')
                : (b.alarmType ?? '').compareTo(a.alarmType ?? ''));

          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 23),
            itemBuilder: (_, i) => _NotificationCard(item: items[i]),
          );
        },
      );

  Future<void> _showPeriodDialog() async {
    final renderBox = _dateBtnKey.currentContext!.findRenderObject() as RenderBox;
    final top = renderBox.localToGlobal(Offset.zero).dy + renderBox.size.height + 4;

    const side = 37.0;
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = screenW - side * 2;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Stack(
        children: [
          Positioned(
            left: side,
            top: top,
            width: dialogW,
            child: const PeriodSelectDialogMobile(),
          ),
        ],
      ),
    );

    if (result == null) return;
    final newStart = result['start'] ?? '';
    final newEnd = result['end'] ?? '';
    if (newStart.isEmpty || newEnd.isEmpty) return;

    setState(() {
      _startDate = newStart;
      _endDate = newEnd;
    });

    Get.find<NotificationController>().reqNotifications(_startDate, _endDate);
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '',
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 15,
              color: Color(0xFF666565),
              fontWeight: FontWeight.w400,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final read = item.isRead == true;

    const black = Color(0xFF000000);

    final textStyle = TextStyle(
      fontFamily: 'pretendard',
      fontSize: 15,
      height: 1.4,
      fontWeight: read ? FontWeight.w400 : FontWeight.w500,
      color: black,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(item.alarmType ?? '', style: textStyle),
              const Spacer(),
              Text(item.createTs ?? '', style: textStyle),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(item.comment ?? '', style: textStyle, maxLines: 4, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
