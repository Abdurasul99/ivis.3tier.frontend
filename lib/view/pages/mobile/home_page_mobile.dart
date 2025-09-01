import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '/constants/constants.dart';
import '/view/pages/login_page.dart';
import '/view/tabs/mobile/tab_dashboard_mobile.dart';
import '/view/tabs/mobile/tab_robot_mobile.dart';
import '/view/tabs/mobile/tab_setting_mobile.dart';
import '/view/tabs/mobile/tab_setting_profile_mobile.dart';
import '/view/components/notification_bell_view.dart';
import '/viewmodel/controller/notification_controller.dart';
import '/viewmodel/controller/user_controller.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({
    super.key,
    this.initialTabIndex = 0,
    this.openAlarmList = false,
  });

  static const routeName = '/home';

  final int initialTabIndex;
  final bool openAlarmList;

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> with TickerProviderStateMixin {
  // ───────────────────────── Menu config ─────────────────────────
  final List<String> _menuTitles = ['대시보드', '로봇', '설정'];
  final List<String> _menuIcons = ['dashboard', 'robot', 'setting'];

  // ──────────────────── Runtime‑controlled state ─────────────────
  late int _selectedMenuIndex;
  late bool _openAlarmListInitially;
  late TabController _tabController;

  bool _isProfileMenuVisible = false;
  late AnimationController _profileMenuAnimationController;
  late Animation<Offset> _profileMenuAnimation;

  // ─────────────────────────── Lifecycle ──────────────────────────
  @override
  void initState() {
    super.initState();

    _selectedMenuIndex = widget.initialTabIndex;
    _openAlarmListInitially = widget.openAlarmList;

    _tabController = TabController(
      vsync: this,
      length: _menuTitles.length,
      initialIndex: _selectedMenuIndex,
    );

    if (_selectedMenuIndex == 2 && _openAlarmListInitially) {
      Future.microtask(
        () => Get.find<NotificationController>().setSettingTabIndex(3),
      );
    }

    _profileMenuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _profileMenuAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _profileMenuAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _profileMenuAnimationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _gotoAlarmTab() {
    setState(() {
      _selectedMenuIndex = 2;
      _tabController.index = 2;
      _openAlarmListInitially = true;
    });
    Get.find<NotificationController>().setSettingTabIndex(3);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobileWidth = MediaQuery.of(context).size.width < 600;

    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        bottomNavigationBar: isMobileWidth ? _buildBottomBar() : null,
        body: Column(
          children: [
            _buildStateBar(),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      if (!isMobileWidth) _buildLeftMenu(),
                      Expanded(child: _buildTabViews()),
                    ],
                  ),
                  _buildProfilePanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomBar() => BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedMenuIndex,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedItemColor: const Color(0xFF005CB2),
        unselectedItemColor: const Color(0xFF666566),
        onTap: (int index) {
          setState(() {
            _selectedMenuIndex = index;
            _tabController.index = index;
            _openAlarmListInitially = false;
          });
        },
        items: List.generate(
          _menuTitles.length,
          (i) => BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/icons_menu_${_menuIcons[i]}_unselected.svg',
              width: 24,
            ),
            activeIcon: SvgPicture.asset(
              'assets/images/icons_menu_${_menuIcons[i]}_selected.svg',
              width: 24,
            ),
            label: _menuTitles[i],
          ),
        ),
      );

  Widget _buildLeftMenu() {
    return Container(
      width: 80,
      color: Colors.white,
      child: Column(
        children: List.generate(_menuTitles.length, (i) {
          final bool isSelected = _selectedMenuIndex == i;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedMenuIndex = i;
              _tabController.index = i;
              _openAlarmListInitially = false;
            }),
            child: Container(
              width: 78,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF7F7F7) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                border: Border.all(
                  color: isSelected ? const Color(0xFFEAEAEA) : Colors.white,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/icons_menu_${_menuIcons[i]}_${isSelected ? 'selected' : 'unselected'}.svg',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _menuTitles[i],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666566),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabViews() => TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          MobileTabDashboard(gotoAlarmSet: _gotoAlarmTab),
          const TabRobotMobile(),
          TabSettingMobile(openAlarmList: _openAlarmListInitially),
        ],
      );

  Widget _buildStateBar() {
    final bool isMobileWidth = MediaQuery.of(context).size.width < 600;
    final double barHeight = isMobileWidth ? 48 : 60;
    final double logoSize = isMobileWidth ? 18 : 22;
    final double titleSize = isMobileWidth ? 16 : 18;
    final double avatarSize = isMobileWidth ? 36 : 42;
    final double gap = isMobileWidth ? 8 : 16;
    final double horizontalPadding = isMobileWidth ? 12 : 24;

    return Column(
      children: [
        Container(
          height: barHeight,
          color: Colors.white,
          child: Row(
            children: [
              SizedBox(width: horizontalPadding),
              SvgPicture.asset('assets/images/icons_symbol.svg', width: logoSize),
              SizedBox(width: gap),
              Text(
                '아이비스 FMS 관제 시스템',
                style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              GetBuilder<UserController>(
                builder: (userController) {
                  final imageUrl = userController.loginUser?.imageUrl ?? '';

                  return GestureDetector(
                    onTap: () {
                      setState(() => _isProfileMenuVisible = !_isProfileMenuVisible);
                      if (_isProfileMenuVisible) {
                        _profileMenuAnimationController.forward();
                      } else {
                        _profileMenuAnimationController.reverse();
                      }
                    },
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(avatarSize / 2),
                            child: ExtendedImage.network(
                              imageUrl,
                              width: avatarSize,
                              height: avatarSize,
                              fit: BoxFit.cover,
                              cache: true,
                            ),
                          )
                        : SvgPicture.asset(
                            'assets/images/icons_small_profile.svg',
                            width: avatarSize,
                          ),
                  );
                },
              ),
              SizedBox(width: gap),
              const NotificationBellView(),
              if (!isMobileWidth) ...[
                SizedBox(width: gap),
                Text(
                  DateFormat('yyyy.MM.dd aa hh:mm').format(DateTime.now()),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              SizedBox(width: horizontalPadding),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8E8E8)),
      ],
    );
  }

  Widget _buildProfilePanel() {
    if (!_isProfileMenuVisible) return const SizedBox.shrink();

    final user = Get.find<UserController>().loginUser;

    return Positioned(
      top: 8,
      right: 16,
      child: SlideTransition(
        position: _profileMenuAnimation,
        child: Container(
          width: 294,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8E8E8)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                Row(
                  children: [
                    user.imageUrl != null && user.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(44),
                            child: ExtendedImage.network(
                              user.imageUrl!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              cache: true,
                            ),
                          )
                        : SvgPicture.asset(
                            'assets/images/icons_small_profile.svg',
                            width: 88,
                            height: 88,
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name ?? '',
                            style: const TextStyle(fontSize: 20),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.email ?? '',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              GestureDetector(
                onTap: () {
                  _profileMenuAnimationController.reverse();
                  setState(() => _isProfileMenuVisible = false);

                  Get.to(
                    () => Scaffold(
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        iconTheme: const IconThemeData(color: Colors.black),
                        title: const Text(
                          '프로필 설정',
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      body: const TabSettingProfileMobile(),
                      bottomNavigationBar: _buildBottomBar(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.gear, size: 22, color: kBlackFontColor),
                    const SizedBox(width: 12),
                    const Text(
                      'My account',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: kBlackFontColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  await Get.find<UserController>().logout();
                  Get.offAllNamed(LoginPage.routeName);
                },
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Log out',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
