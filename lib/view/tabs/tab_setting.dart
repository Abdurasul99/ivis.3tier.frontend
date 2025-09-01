import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/tabs/mobile/tab_setting_mobile.dart';
import 'package:fms/view/tabs/tab_setting_alarm.dart';
import 'package:fms/view/tabs/tab_setting_dashboard.dart';
import 'package:fms/view/tabs/tab_setting_member.dart';
import 'package:fms/view/tabs/tab_setting_profile.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:get/get.dart';

import '../../viewmodel/controller/user_controller.dart';

class TabSetting extends StatefulWidget {
  const TabSetting({super.key, this.changeAlarmTab});

  final Function(VoidCallback)? changeAlarmTab;

  @override
  State<TabSetting> createState() => _TabSettingState();
}

class _TabSettingState extends State<TabSetting> with TickerProviderStateMixin {
  List<String> _menuTitles = ["프로필 설정", "대시보드 관리", "맴버 관리", "주요 알림"];
  List<String> _menuIcon = ["profile", "dashboard", "member", "alarm"];

  String _selectedMenu = "프로필 설정";

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    if (Get.find<UserController>().isAdminUser()) {
      _menuTitles = ["프로필 설정", "대시보드 관리", "맴버 관리", "주요 알림"];
      _menuIcon = ["profile", "dashboard", "member", "alarm"];
    } else {
      _menuTitles = ["프로필 설정", "대시보드 관리", "주요 알림"];
      _menuIcon = ["profile", "dashboard", "alarm"];
    }

    _selectedMenu = _menuTitles[Get.find<NotificationController>().settingTabIndex];

    _tabController = TabController(
      vsync: this,
      initialIndex: Get.find<NotificationController>().settingTabIndex,
      length: _menuTitles.length,
    );

    Get.find<NotificationController>().setSettingTabIndex(0);
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabSettingMobile();
    }

    return Row(
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: const Color(0xFFFAFAFA),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: Offset(3, 0),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: _menuTitles
                .map(
                  (e) => buildMenuItem(_menuIcon[_menuTitles.indexOf(e)], e),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: _menuTitles.length,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: Get.find<UserController>().isAdminUser()
                  ? [
                      TabSettingProfile(),
                      TabSettingDashboard(),
                      TabSettingMember(),
                      TabSettingAlarm(),
                    ]
                  : [
                      TabSettingProfile(),
                      TabSettingDashboard(),
                      TabSettingAlarm(),
                    ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMenuItem(String iconName, String title) {
    return GestureDetector(
      onTap: () {
        _selectedMenu = title;
        _tabController.animateTo(_menuTitles.indexOf(title));
        if (mounted) {
          setState(() {});
        }
      },
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: SvgPicture.asset(
                "assets/images/icons_setting_$iconName${(_selectedMenu == title) ? "_selected" : "_unselected"}.svg",
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: (_selectedMenu == title) ? const Color(0xFF005FB8) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
