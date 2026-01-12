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
  static const double _expandedW = 280;
  static const double _collapsedW = 72;
  static const double _rowH = 48;
  static const double _iconSide = 28;

  late TabController _tabController;
  int _selectedIndex = 0;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // стартуем всегда с 0 (без NotificationController)
    _selectedIndex = 0;
    _tabController = TabController(vsync: this, length: _menuTitles.length);
    _tabController.index = _selectedIndex;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          width: _collapsed ? _collapsedW : _expandedW,
          color: const Color(0xFFFAFAFA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: _collapsed ? 12 : 16),
                alignment: _collapsed ? Alignment.center : Alignment.centerRight,
                child: InkWell(
                  onTap: _toggleCollapsed,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      _collapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 18,
                      color: const Color(0xFF005FB8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ...List.generate(_menuTitles.length, (i) {
                return _buildMenuItem(
                  iconName: _menuIcons[i],
                  title: _menuTitles[i],
                  selected: _selectedIndex == i,
                  collapsed: _collapsed,
                  onTap: () {
                    _selectedIndex = i;
                    _tabController.animateTo(i);
                    setState(() {});
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // RIGHT: content
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
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    final Color lineColor = selected ? const Color(0xFF005FB8) : Colors.transparent;
    final Color textColor = selected ? const Color(0xFF005FB8) : const Color(0xFF222222);
    final Color bgColor = selected ? const Color(0xFFF2F6FD) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _rowH,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(left: BorderSide(color: lineColor, width: 4)),
        ),
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 20),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
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
            if (!collapsed) ...[
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
          ],
        ),
      ),
    );
  }
}
