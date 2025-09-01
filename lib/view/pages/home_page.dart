import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fms/view/tabs/tab_dashboard.dart';
import 'package:fms/view/tabs/tab_setting.dart';
import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../constants/constants.dart';
import '../../view/components/layout.dart';
import '../../view/pages/mobile/home_page_mobile.dart';
import '../../viewmodel/controller/time_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../components/notification_bell_view.dart';
import '../tabs/tab_robot.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final List<String> _menuTitles = ["대시보드", "로봇", "설정"];
  final List<String> _menuIcons = ["dashboard", "robot", "setting"];

  int _selectMenuIndex = 0;

  late TabController _tabController;

  bool _isProfileMenuVisible = false;
  late AnimationController _profileMenuAnimationController;
  late Animation<Offset> _profileMenuAnimation;

  VoidCallback? _changeAlarmTabFunction;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _menuTitles.length);

    _profileMenuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _profileMenuAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _profileMenuAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _profileMenuAnimationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const HomePageMobile();
    }
    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: [
            buildStateBar(),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        buildMenu(),
                        Expanded(child: buildDefaultTabControl()),
                      ],
                    ),
                  ),
                  buildProfilePanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMenu() {
    return Container(
      width: 80,
      color: Colors.white,
      child: Column(
        children: _menuTitles.map((e) => buildMenuItem(_menuTitles.indexOf(e))).toList(),
      ),
    );
  }

  Widget buildMenuItem(int index) {
    return GestureDetector(
      onTap: () {
        _selectMenuIndex = index;
        _tabController.index = _selectMenuIndex;

        if (mounted) {
          setState(() {});
        }
      },
      child: Row(
        children: [
          const SizedBox(width: 2),
          Stack(
            children: [
              Container(
                width: 78,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (_selectMenuIndex == index) ? const Color(0xFFF7F7F7) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: (_selectMenuIndex == index) ? const Color(0xFFEAEAEA) : Colors.white,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      (_selectMenuIndex == index)
                          ? "assets/images/icons_menu_${_menuIcons[index]}_selected.svg"
                          : "assets/images/icons_menu_${_menuIcons[index]}_unselected.svg",
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _menuTitles[index],
                      style: const TextStyle(
                        fontFamily: 'gm-medium',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF666566),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectMenuIndex == index)
                Positioned(
                  left: 0,
                  top: 10,
                  child: Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF005CB2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStateBar() {
    return Column(
      children: [
        Container(
          height: 60,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00000D).withOpacity(0.05),
                offset: const Offset(0.0, 1.0),
                blurRadius: 3.0,
                spreadRadius: 0.0,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 24),
              SvgPicture.asset(
                "assets/images/icons_symbol.svg",
                width: 22,
                fit: BoxFit.fitWidth,
              ),
              const SizedBox(width: 16),
              Text(
                "3Tier",
                style: TextStyle(
                  fontFamily: 'gm-medium',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              GetBuilder<UserController>(
                init: UserController(),
                builder: (controller) {
                  return GestureDetector(
                    onTap: () {
                      _isProfileMenuVisible = !_isProfileMenuVisible;
                      if (_isProfileMenuVisible) {
                        _profileMenuAnimationController.forward();
                      } else {
                        _profileMenuAnimationController.reverse();
                      }

                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: (controller.loginUser != null &&
                            controller.loginUser!.imageUrl != null &&
                            controller.loginUser!.imageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: ExtendedImage.network(
                              controller.loginUser!.imageUrl!,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          )
                        : SvgPicture.asset(
                            "assets/images/icons_small_profile.svg",
                            width: 42,
                            fit: BoxFit.fitWidth,
                          ),
                  );
                },
              ),
              const SizedBox(width: 22),
              const NotificationBellView(),
              const SizedBox(width: 22),
              GetBuilder<TimeController>(
                init: TimeController(),
                builder: (controller) {
                  String time = DateFormat('yyyy.MM.dd aa hh:mm').format(DateTime.now());

                  return Text(
                    time,
                    style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: kBlackFontColor,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        Container(height: 1, color: const Color(0xFFE8E8E8)),
      ],
    );
  }

  Widget buildDefaultTabControl() {
    return DefaultTabController(
      length: _menuTitles.length,
      child: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          TabDashboard(gotoAlarmSet: gotoAlarmSetTab),
          const TabRobot(),
          const TabSetting(),
        ],
      ),
    );
  }

  void gotoAlarmSetTab() async {
    Get.find<NotificationController>().setSettingTabIndex(3);
    _tabController.index = 2;
    _selectMenuIndex = 2;

    if (mounted) {
      setState(() {});
    }
  }

  Widget buildProfilePanel() {
    if (_isProfileMenuVisible == false) {
      return Container();
    }

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
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GetBuilder<UserController>(
                init: UserController(),
                builder: (controller) {
                  if (controller.loginUser == null) {
                    return Container();
                  }

                  return Container(
                    height: 96,
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        (controller.loginUser!.imageUrl != null && controller.loginUser!.imageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(44),
                                child: ExtendedImage.network(
                                  controller.loginUser!.imageUrl!,
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : SvgPicture.asset(
                                "assets/images/icons_profile.svg",
                                width: 88,
                                fit: BoxFit.fitWidth,
                              ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              controller.loginUser!.name ?? "",
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: kBlackFontColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              controller.loginUser!.email ?? "",
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: kBlackFontColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _goToProfile,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(CupertinoIcons.gear, size: 22, color: kBlackFontColor),
                    const SizedBox(width: 12),
                    const Text(
                      "My account",
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: kBlackFontColor,
                      ),
                    ),
                    const Spacer(),
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
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.logout, size: 22, color: kBlackFontColor),
                    const SizedBox(width: 12),
                    const Text(
                      "Log out",
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: kBlackFontColor,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToProfile() {
    Get.find<NotificationController>().setSettingTabIndex(0);
    _tabController.index = 2;
    _selectMenuIndex = 2;
    _isProfileMenuVisible = false;
    _profileMenuAnimationController.reverse();
    setState(() {});
  }
}
