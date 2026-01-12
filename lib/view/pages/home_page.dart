import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ivis/view/tabs/tab_dashboard.dart';
import 'package:ivis/view/tabs/tab_setting.dart';
import 'package:ivis/viewmodel/repository/log_repository.dart';

import '../../constants/constants.dart';
import '../../viewmodel/controller/log_controller.dart';
import '../../viewmodel/controller/time_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const String routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const double menuWidth = 88;
  static const double menuItemHeight = 80;
  static const double headerHeight = 60;
  static const double avatarSize = 40;

  final List<String> menuTitles = <String>['대시보드', '설정'];
  final List<String> menuIcons = <String>['dashboard', 'setting'];

  int selectedMenuIndex = 0;
  late TabController tabController;

  bool isProfileMenuVisible = false;
  late AnimationController profileMenuAnimationController;
  late Animation<Offset> profileMenuAnimation;

  late LogController logController;

  @override
  void initState() {
    super.initState();

    tabController = TabController(vsync: this, length: menuTitles.length);
    profileMenuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    profileMenuAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: profileMenuAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    logController = Get.isRegistered<LogController>() ? Get.find<LogController>() : Get.put(LogController());
  }

  @override
  void dispose() {
    profileMenuAnimationController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: <Widget>[
            buildHeaderBar(),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      buildSideMenu(),
                      Expanded(
                        child: buildTabHost(),
                      ),
                    ],
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

  Widget buildSideMenu() {
    return Container(
      width: menuWidth,
      color: Colors.white,
      child: Column(
        children: List<Widget>.generate(
          menuTitles.length,
          (int index) => buildMenuItem(index),
        ),
      ),
    );
  }

  Widget buildMenuItem(int index) {
    final bool selected = selectedMenuIndex == index;
    final Color backgroundColor = selected ? const Color(0xFFF3F4F6) : Colors.white;
    final Color borderColor = selected ? const Color(0xFFE5E7EB) : Colors.white;
    final Color labelColor = selected ? const Color(0xFF111827) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () {
        selectedMenuIndex = index;
        tabController.index = selectedMenuIndex;
        if (mounted) {
          setState(() {});
        }
      },
      child: Row(
        children: <Widget>[
          const SizedBox(width: 2),
          Stack(
            children: <Widget>[
              Container(
                width: menuWidth - 2,
                height: menuItemHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SvgPicture.asset(
                      selected
                          ? 'assets/images/icons_menu_${menuIcons[index]}_selected.svg'
                          : 'assets/images/icons_menu_${menuIcons[index]}_unselected.svg',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      menuTitles[index],
                      style: TextStyle(
                        fontFamily: 'gm-medium',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 4,
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

  Widget buildHeaderBar() {
    return Column(
      children: <Widget>[
        Container(
          height: headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.04),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              SvgPicture.asset(
                'assets/images/icons_symbol.svg',
                width: 22,
                fit: BoxFit.fitWidth,
              ),
              const SizedBox(width: 10),
              const Text(
                '3tier',
                style: TextStyle(
                  fontFamily: 'gm-medium',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              GetBuilder<LogController>(
                init: logController,
                builder: (LogController controller) {
                  return SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: controller.isDownloading
                          ? null
                          : () {
                              controller.downloadLatestLog();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005CB2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      icon: const Icon(
                        Icons.download,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        '데이터 다운로드',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              GetBuilder<TimeController>(
                init: TimeController(),
                builder: (TimeController controller) {
                  final String formattedTime = DateFormat('yyyy.MM.dd  HH:mm').format(DateTime.now());
                  return Text(
                    formattedTime,
                    style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              GetBuilder<UserController>(
                init: UserController(),
                builder: (UserController controller) {
                  Widget avatar;
                  if (controller.loginUser != null &&
                      controller.loginUser!.imageUrl != null &&
                      controller.loginUser!.imageUrl!.isNotEmpty) {
                    avatar = ClipRRect(
                      borderRadius: BorderRadius.circular(avatarSize / 2),
                      child: ExtendedImage.network(
                        controller.loginUser!.imageUrl!,
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      ),
                    );
                  } else {
                    avatar = SvgPicture.asset(
                      'assets/images/icons_small_profile.svg',
                      width: avatarSize,
                      fit: BoxFit.fitWidth,
                    );
                  }
                  return GestureDetector(
                    onTap: () {
                      isProfileMenuVisible = !isProfileMenuVisible;
                      if (isProfileMenuVisible) {
                        profileMenuAnimationController.forward();
                      } else {
                        profileMenuAnimationController.reverse();
                      }
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: avatar,
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: const Color(0xFFE5E7EB),
        ),
      ],
    );
  }

  Widget buildTabHost() {
    return DefaultTabController(
      length: menuTitles.length,
      child: TabBarView(
        controller: tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const <Widget>[
          TabDashboard(),
          TabSetting(),
        ],
      ),
    );
  }

  Widget buildProfilePanel() {
    if (!isProfileMenuVisible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 10,
      right: 20,
      child: SlideTransition(
        position: profileMenuAnimation,
        child: Container(
          width: 290,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GetBuilder<UserController>(
                init: UserController(),
                builder: (UserController controller) {
                  if (controller.loginUser == null) {
                    return const SizedBox.shrink();
                  }
                  final String name = controller.loginUser!.name ?? '';
                  final String email = controller.loginUser!.email ?? '';
                  Widget avatar;
                  if (controller.loginUser!.imageUrl != null && controller.loginUser!.imageUrl!.isNotEmpty) {
                    avatar = ClipRRect(
                      borderRadius: BorderRadius.circular(44),
                      child: ExtendedImage.network(
                        controller.loginUser!.imageUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    );
                  } else {
                    avatar = SvgPicture.asset(
                      'assets/images/icons_profile.svg',
                      width: 88,
                      fit: BoxFit.fitWidth,
                    );
                  }
                  return SizedBox(
                    height: 96,
                    child: Row(
                      children: <Widget>[
                        avatar,
                        const SizedBox(width: 14),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: kBlackFontColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email,
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  tabController.index = 1;
                  selectedMenuIndex = 1;
                  isProfileMenuVisible = false;
                  profileMenuAnimationController.reverse();
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Row(
                  children: const <Widget>[
                    SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.gear,
                      size: 22,
                      color: kBlackFontColor,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'My account',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: kBlackFontColor,
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  await Get.find<UserController>().logout();
                  Get.offAllNamed(LoginPage.routeName);
                },
                child: Row(
                  children: const <Widget>[
                    SizedBox(width: 6),
                    Icon(
                      Icons.logout,
                      size: 22,
                      color: kBlackFontColor,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Log out',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: kBlackFontColor,
                      ),
                    ),
                    Spacer(),
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
