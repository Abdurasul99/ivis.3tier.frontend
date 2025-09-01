// lib/view/tabs/mobile/tab_setting_mobile.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '/view/tabs/mobile/tab_setting_alarm_mobile.dart';
import '/view/tabs/tab_setting_dashboard.dart';
import '/view/tabs/tab_setting_member.dart';
import '/view/tabs/tab_setting_profile.dart';
import '/viewmodel/controller/user_controller.dart';
import '/view/pages/login_page.dart';
import '/utils/utils.dart'; // FOR Utils.showSnackBar

class TabSettingMobile extends StatefulWidget {
  const TabSettingMobile({
    Key? key,
    this.openAlarmList = false,
  }) : super(key: key);

  final bool openAlarmList;

  @override
  State<TabSettingMobile> createState() => _TabSettingMobileState();
}

class _TabSettingMobileState extends State<TabSettingMobile> with TickerProviderStateMixin {
  late List<String> _menuTitles;
  late List<String> _menuIcons;
  late String _selectedMenu;

  bool _mobileMenuOpen = true;
  int _mobileIndex = 0;
  late final TabController _tabController;
  late final int _dashboardIndex;

  @override
  void initState() {
    super.initState();

    final isAdmin = Get.find<UserController>().isAdminUser();
    _menuTitles = isAdmin ? ['프로필 설정', '대시보드 관리', '맴버 관리', '주요 알림'] : ['프로필 설정', '대시보드 관리', '주요 알림'];
    _menuIcons = isAdmin ? ['profile', 'dashboard', 'member', 'alarm'] : ['profile', 'dashboard', 'alarm'];

    _dashboardIndex = _menuTitles.indexOf('대시보드 관리');

    if (widget.openAlarmList) {
      _mobileMenuOpen = false;
      _mobileIndex = _menuTitles.indexOf('주요 알림');
    }

    _selectedMenu = _menuTitles[_mobileIndex];
    _tabController = TabController(
      vsync: this,
      length: _menuTitles.length,
      initialIndex: _mobileIndex,
    );
  }

  @override
  void didUpdateWidget(covariant TabSettingMobile old) {
    super.didUpdateWidget(old);
    if (widget.openAlarmList && !old.openAlarmList) {
      final idx = _menuTitles.indexOf('주요 알림');
      if (idx != -1) {
        setState(() {
          _mobileMenuOpen = false;
          _mobileIndex = idx;
          _selectedMenu = _menuTitles[idx];
          _tabController.animateTo(idx);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) => c.maxWidth < 600 ? _buildMobile() : _buildDesktop(),
    );
  }

  Widget _buildMobile() {
    if (_mobileMenuOpen) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              ...List.generate(_menuTitles.length, _buildMobileMenuTile),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await Get.find<UserController>().logout();
                  Get.offAllNamed(LoginPage.routeName);
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout, size: 22),
                      SizedBox(width: 6),
                      Text(
                        '로그아웃',
                        style: TextStyle(fontFamily: 'pretendard', fontSize: 16, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          _selectedMenu,
          style: const TextStyle(
            fontFamily: 'pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _mobileMenuOpen = true),
        ),
      ),
      body: _buildTabScreens()[_mobileIndex],
    );
  }

  Widget _buildMobileMenuTile(int i) {
    return GestureDetector(
      onTap: () {
        if (i == _dashboardIndex) {
          Utils.showSnackBar('모바일 화면에서는 지원되지 않습니다.', isError: false);
          return;
        }
        setState(() {
          _mobileMenuOpen = false;
          _mobileIndex = i;
          _selectedMenu = _menuTitles[i];
          _tabController.animateTo(i);
        });
      },
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                SvgPicture.asset('assets/images/icons_setting_${_menuIcons[i]}_unselected.svg', width: 26, height: 26),
                const SizedBox(width: 12),
                Text(
                  _menuTitles[i],
                  style: const TextStyle(fontFamily: 'pretendard', fontSize: 17, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 26, color: Colors.black54),
              ],
            ),
          ),
          const Divider(indent: 24, height: 1, color: Color(0xFFE5E5E5)),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        Container(
          width: 280,
          color: Colors.white,
          child: Column(
            children: List.generate(_menuTitles.length, (i) {
              final sel = _selectedMenu == _menuTitles[i];
              return ListTile(
                leading: SvgPicture.asset(
                  'assets/images/icons_setting_${_menuIcons[i]}_${sel ? 'selected' : 'unselected'}.svg',
                ),
                title: Text(
                  _menuTitles[i],
                  style: TextStyle(color: sel ? const Color(0xFF005FB8) : Colors.black),
                ),
                onTap: () {
                  if (i == _dashboardIndex) {
                    Utils.showSnackBar('모바일 화면에서는 지원되지 않습니다.', isError: false);
                    return;
                  }
                  setState(() {
                    _selectedMenu = _menuTitles[i];
                    _tabController.animateTo(i);
                  });
                },
              );
            }),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: _buildTabScreens(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTabScreens() {
    final alarmTab = const TabSettingAlarmMobile(showAppBar: false);
    final dashTab = const TabSettingDashboard();
    return Get.find<UserController>().isAdminUser()
        ? [const TabSettingProfile(), dashTab, const TabSettingMember(), alarmTab]
        : [const TabSettingProfile(), dashTab, alarmTab];
  }
}
