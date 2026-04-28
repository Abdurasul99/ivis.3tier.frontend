import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ivis/i18n/app_locale.dart';
import 'package:ivis/view/tabs/tab_activity.dart';
import 'package:ivis/view/tabs/tab_dashboard.dart';
import 'package:ivis/view/tabs/tab_device_management.dart';
import 'package:ivis/view/tabs/tab_setting.dart';

import '../../constants/constants.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/activity_controller.dart';
import '../../viewmodel/controller/infra_controller.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/time_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import '../../viewmodel/controller/vehicle_controller.dart';
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

  final List<String> menuIcons = <String>['dashboard', '', '', 'setting'];
  final List<IconData?> menuGlyphs = <IconData?>[
    null,
    Icons.devices_rounded,
    Icons.timeline_rounded,
    null,
  ];
  // SVG가 없는 항목은 IconData로 대체
  final List<IconData?> menuIconData = <IconData?>[null, Icons.devices_rounded, Icons.timeline_rounded, null];

  int selectedMenuIndex = 0;
  late TabController tabController;

  bool isProfileMenuVisible = false;
  late AnimationController profileMenuAnimationController;
  late Animation<Offset> profileMenuAnimation;

  List<String> get navigationTitles => <String>[
        l10n('대시보드', 'Dashboard'),
        l10n('장치 관리', 'Device Mgmt'),
        l10n('활동', 'Activity'),
        l10n('설정', 'Settings'),
      ];

  @override
  void initState() {
    super.initState();

    tabController = TabController(vsync: this, length: 4);
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureSessionOnDirectRefresh();
    });
  }

  @override
  void dispose() {
    profileMenuAnimationController.dispose();
    tabController.dispose();
    super.dispose();
  }

  Future<void> _ensureSessionOnDirectRefresh() async {
    final UserController userController = Get.find<UserController>();

    // Normal navigation after login/start already has an in-memory session.
    final bool hasMemorySession = (userController.accessToken?.isNotEmpty ?? false) &&
        userController.loginUser != null;
    if (hasMemorySession) {
      return;
    }

    final bool hasStoredToken = await userController.ensureAccessTokenLoaded();
    if (!hasStoredToken) {
      if (!mounted) return;
      Get.offAllNamed(LoginPage.routeName);
      return;
    }

    final bool isTokenValid = await userController.reqLoginByToken();
    if (!mounted) return;
    if (!isTokenValid) {
      await userController.logout();
      if (!mounted) return;
      Get.offAllNamed(LoginPage.routeName);
      return;
    }

    final VehicleController vehicleController = Get.find<VehicleController>();
    final InfraController infraController = Get.find<InfraController>();

    if (vehicleController.vehicles.isEmpty) {
      await vehicleController.reqLoadVehicles();
    }
    if (infraController.infraIdentifiers.isEmpty) {
      await infraController.reqLoadInfraIdentifiers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) {
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
      },
    );
  }

  Widget buildSideMenu() {
    return GetBuilder<ActivityController>(
      init: Get.find<ActivityController>(),
      builder: (ActivityController ac) => Container(
        width: menuWidth,
        color: Colors.white,
        child: Column(
          children: List<Widget>.generate(
            navigationTitles.length,
            (int index) => buildMenuItem(index, unreadBadge: index == 2 ? ac.unreadCount : 0),
          ),
        ),
      ),
    );
  }

  Widget buildMenuItem(int index, {int unreadBadge = 0}) {
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        if (menuGlyphs[index] != null)
                          Icon(
                            menuGlyphs[index],
                            size: 26,
                            color: selected
                                ? const Color(0xFF005CB2)
                                : const Color(0xFF6B7280),
                          )
                        else
                          SvgPicture.asset(
                            selected
                                ? 'assets/images/icons_menu_${menuIcons[index]}_selected.svg'
                                : 'assets/images/icons_menu_${menuIcons[index]}_unselected.svg',
                          ),
                        if (unreadBadge > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFC42B1C),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      navigationTitles[index],
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
                color: const Color(0xFF000000).withValues(alpha: 0.04),
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
              GetBuilder<TimeController>(
                init: Get.find<TimeController>(),
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
              const SizedBox(width: 16),
              // 알림 벨 배지
              GetBuilder<ActivityController>(
                init: Get.find<ActivityController>(),
                builder: (ActivityController ac) {
                  return GestureDetector(
                    onTap: () {
                      selectedMenuIndex = 2;
                      tabController.index = 2;
                      if (mounted) setState(() {});
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Icon(
                          Icons.notifications_rounded,
                          size: 24,
                          color: ac.unreadCount > 0
                              ? const Color(0xFF005CB2)
                              : const Color(0xFF9CA3AF),
                        ),
                        if (ac.unreadCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC42B1C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                              child: Text(
                                ac.unreadCount > 99 ? '99+' : '${ac.unreadCount}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontFamily: 'pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              GetBuilder<UserController>(
                init: Get.find<UserController>(),
                builder: (UserController controller) {
                  Widget avatar;
                  if (controller.loginUser != null &&
                      controller.loginUser!.imageUrl != null &&
                      controller.loginUser!.imageUrl!.isNotEmpty) {
                    avatar = ClipRRect(
                      borderRadius: BorderRadius.circular(avatarSize / 2),
                      child: Image.network(
                        Utils.proxyImageUrl(controller.loginUser!.imageUrl!),
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SvgPicture.asset(
                          'assets/images/icons_small_profile.svg',
                          width: avatarSize,
                          fit: BoxFit.fitWidth,
                        ),
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
      length: 4,
      child: TabBarView(
        controller: tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const <Widget>[
          TabDashboard(),
          TabDeviceManagement(),
          TabActivity(),
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
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GetBuilder<UserController>(
                init: Get.find<UserController>(),
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
                      child: Image.network(
                        Utils.proxyImageUrl(controller.loginUser!.imageUrl!),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SvgPicture.asset(
                          'assets/images/icons_profile.svg',
                          width: 88,
                          fit: BoxFit.fitWidth,
                        ),
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
                  tabController.index = 3;
                  selectedMenuIndex = 3;
                  isProfileMenuVisible = false;
                  profileMenuAnimationController.reverse();
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.gear,
                      size: 22,
                      color: kBlackFontColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n('내 계정', 'My account'),
                      style: const TextStyle(
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
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  await Get.find<UserController>().logout();
                  Get.offAllNamed(LoginPage.routeName);
                },
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 6),
                    const Icon(
                      Icons.logout,
                      size: 22,
                      color: kBlackFontColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n('로그아웃', 'Log out'),
                      style: const TextStyle(
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
}
