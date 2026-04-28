import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import 'package:ivis/i18n/app_locale.dart';
import 'package:ivis/view/tabs/tab_setting_member.dart';
import 'package:ivis/view/tabs/tab_setting_profile.dart';

import '../../viewmodel/controller/locale_controller.dart';

class TabSetting extends StatefulWidget {
  const TabSetting({super.key});

  @override
  State<TabSetting> createState() => _TabSettingState();
}

class _TabSettingState extends State<TabSetting> with TickerProviderStateMixin {
  final List<String> _menuIcons = <String>['profile', 'member'];
  final List<IconData?> _menuIconData = <IconData?>[null, null];
  static const double _menuWidth = 280;
  static const double _rowHeight = 48;
  static const double _iconSide = 28;

  late TabController _tabController;
  int _selectedIndex = 0;

  List<String> get _menuTitles => <String>[
        t('프로필 설정'),
        t('멤버 관리'),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            width: _menuWidth,
            color: const Color(0xFFFAFAFA),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 16),
                ...List<Widget>.generate(_menuTitles.length, (int index) {
                  return _buildMenuItem(
                    iconName: _menuIcons[index],
                    title: _menuTitles[index],
                    selected: _selectedIndex == index,
                    onTap: () {
                      _selectedIndex = index;
                      _tabController.animateTo(index);
                      setState(() {});
                    },
                    iconData: _menuIconData[index],
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: const <Widget>[
                  TabSettingProfile(),
                  TabSettingMember(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String iconName,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    IconData? iconData,
  }) {
    final Color textColor = selected ? const Color(0xFF005FB8) : const Color(0xFF222222);
    final Color backgroundColor = selected ? const Color(0xFFF2F6FD) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _rowHeight,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: backgroundColor),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: _iconSide,
              height: _iconSide,
              child: iconData != null
                  ? Icon(iconData, size: _iconSide, color: textColor)
                  : SvgPicture.asset(
                      'assets/images/icons_setting_$iconName${selected ? "_selected" : "_unselected"}.svg',
                      width: _iconSide,
                      height: _iconSide,
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ).copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
