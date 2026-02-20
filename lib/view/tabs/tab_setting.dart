import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:ivis/view/tabs/tab_setting_member.dart';
import 'package:ivis/view/tabs/tab_setting_profile.dart';

class TabSetting extends StatefulWidget {
  const TabSetting({super.key});

  @override
  State<TabSetting> createState() => _TabSettingState();
}

class _TabSettingState extends State<TabSetting> with TickerProviderStateMixin {
  final List<String> _menuTitles = ["프로필 설정", "맴버 관리"];
  final List<String> _menuIcons = ["profile", "member"];
  static const double _menuWidth = 280;
  static const double _rowHeight = 48;
  static const double _iconSide = 28;

  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    _tabController = TabController(vsync: this, length: _menuTitles.length);
    _tabController.index = _selectedIndex;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          width: _menuWidth,
          color: const Color(0xFFFAFAFA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ...List.generate(_menuTitles.length, (int index) {
                return _buildMenuItem(
                  iconName: _menuIcons[index],
                  title: _menuTitles[index],
                  selected: _selectedIndex == index,
                  onTap: () {
                    _selectedIndex = index;
                    _tabController.animateTo(index);
                    setState(() {});
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: _menuTitles.length,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                TabSettingProfile(),
                TabSettingMember(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String iconName,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    Color lineColor = selected ? const Color(0xFF005FB8) : Colors.transparent;
    Color textColor = selected ? const Color(0xFF005FB8) : const Color(0xFF222222);
    Color backgroundColor = selected ? const Color(0xFFF2F6FD) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _rowHeight,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: BorderSide(
              color: lineColor,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: _iconSide,
              height: _iconSide,
              child: SvgPicture.asset(
                "assets/images/icons_setting_${iconName}${selected ? "_selected" : "_unselected"}.svg",
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
