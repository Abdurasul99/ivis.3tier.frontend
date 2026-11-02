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
import '../../viewmodel/controller/dashboard_controller.dart';
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
  int _lastTabIndex = 0;
  late TabController tabController;

  bool isProfileMenuVisible = false;
  late AnimationController profileMenuAnimationController;
  late Animation<Offset> profileMenuAnimation;

  bool isBellPanelOpen = false;
  late AnimationController bellPanelAnimationController;
  late Animation<Offset> bellPanelAnimation;

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
    // 대시보드(0번 탭)로 돌아올 때 차량/인프라 목록 새로고침 → 삭제된 기기 즉시 제거
    tabController.addListener(_onTabChanged);
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

    bellPanelAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    bellPanelAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: bellPanelAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureSessionOnDirectRefresh();
    });
  }

  // 탭이 대시보드(0)로 전환될 때: 차량/인프라 목록을 재로드하여
  // 디바이스 관리에서 삭제된 기기가 대시보드(사이드바·지도)에 남지 않게 한다.
  void _onTabChanged() {
    final int idx = tabController.index;
    if (idx == _lastTabIndex) return;
    _lastTabIndex = idx;
    if (idx == 0 && Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().refreshDeviceLists();
    }
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    profileMenuAnimationController.dispose();
    bellPanelAnimationController.dispose();
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
                      // 패널 외부 클릭 시 닫기 — 패널보다 먼저 (아래 레이어)
                      if (isBellPanelOpen || isProfileMenuVisible)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (isBellPanelOpen) {
                                isBellPanelOpen = false;
                                Get.find<ActivityController>().closeBell();
                                bellPanelAnimationController.reverse();
                              }
                              if (isProfileMenuVisible) {
                                isProfileMenuVisible = false;
                                profileMenuAnimationController.reverse();
                              }
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      // 패널은 backdrop보다 위 레이어 — 탭 이벤트가 올바르게 전달됨
                      buildProfilePanel(),
                      buildBellPanel(),
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
                      isBellPanelOpen = !isBellPanelOpen;
                      if (isBellPanelOpen) {
                        ac.openBell();
                        bellPanelAnimationController.forward();
                        // 프로필 패널 닫기
                        if (isProfileMenuVisible) {
                          isProfileMenuVisible = false;
                          profileMenuAnimationController.reverse();
                        }
                      } else {
                        ac.closeBell();
                        bellPanelAnimationController.reverse();
                      }
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
                        // 읽지 않은 알림 배지 – 숫자 변경 시 튀어오르는 애니메이션
                        Positioned(
                          top: -4,
                          right: -4,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.elasticOut,
                                ),
                                child: FadeTransition(opacity: animation, child: child),
                              );
                            },
                            child: ac.unreadCount > 0
                                ? Container(
                                    key: ValueKey<String>(
                                      ac.unreadCount > 99 ? '99+' : '${ac.unreadCount}',
                                    ),
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
                                  )
                                : const SizedBox.shrink(key: ValueKey('empty')),
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
                        // 2026-08-10: 알림 패널 닫기 — 벨 쪽과 대칭 처리.
                        //   벨 탭은 프로필을 닫아 주는데 프로필 탭은 벨을 닫지 않아,
                        //   "벨 → 프로필" 순서로 누르면 두 패널이 겹쳐 떴다.
                        //   한 번에 하나만 열리도록 맞춘다.
                        if (isBellPanelOpen) {
                          isBellPanelOpen = false;
                          Get.find<ActivityController>().closeBell();
                          bellPanelAnimationController.reverse();
                        }
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

  Widget buildBellPanel() {
    if (!isBellPanelOpen) return const SizedBox.shrink();
    return Positioned(
      top: 10,
      right: 80,
      child: SlideTransition(
        position: bellPanelAnimation,
        child: GetBuilder<ActivityController>(
          init: Get.find<ActivityController>(),
          builder: (ActivityController ac) {
            return Container(
              width: 370,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFD7F0), width: 1.2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // ── 헤더 ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEBF4FF),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFBFD7F0), width: 1),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.notifications_rounded, size: 16, color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Text(
                          l10n('알림', 'Notifications'),
                          style: const TextStyle(
                            fontFamily: 'Malgun Gothic',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        if (ac.unreadCount > 0) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              ac.unreadCount > 99 ? '99+' : '${ac.unreadCount}',
                              style: const TextStyle(
                                fontFamily: 'Malgun Gothic',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (ac.unreadCount > 0)
                          GestureDetector(
                            onTap: () => ac.markAllRead(),
                            child: Text(
                              l10n('모두 읽음', 'Mark all read'),
                              style: const TextStyle(
                                fontFamily: 'Malgun Gothic',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            isBellPanelOpen = false;
                            ac.closeBell();
                            bellPanelAnimationController.reverse();
                            if (mounted) setState(() {});
                          },
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF90A4AE)),
                        ),
                      ],
                    ),
                  ),
                  // ── 알림 목록 ──────────────────────────────────
                  if (ac.isBellOpen && ac.bellEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: <Widget>[
                          const Icon(Icons.notifications_off_rounded, size: 36, color: Color(0xFFBFD7F0)),
                          const SizedBox(height: 12),
                          Text(
                            l10n('알림이 없습니다', 'No notifications'),
                            style: const TextStyle(
                              fontFamily: 'Malgun Gothic',
                              fontSize: 13,
                              color: Color(0xFF90A4AE),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: ac.bellEvents.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE3F0FB)),
                        itemBuilder: (BuildContext context, int index) {
                          final event = ac.bellEvents[index];
                          final bool isUnread = !event.isRead;
                          final Color severityColor = event.severity >= 3
                              ? const Color(0xFFE53935)
                              : event.severity >= 2
                                  ? const Color(0xFFFB8C00)
                                  : const Color(0xFF1565C0);
                          final DateTime time = DateTime.fromMillisecondsSinceEpoch(
                            event.occurredAtMs, isUtc: true).toLocal();
                          final String timeLabel =
                              '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          return GestureDetector(
                            onTap: () => ac.markRead(event.id),
                            child: Container(
                              color: isUnread
                                  ? const Color(0xFFF0F7FF)
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 4, right: 10),
                                    decoration: BoxDecoration(
                                      color: isUnread ? severityColor : const Color(0xFFBFD7F0),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          event.title,
                                          style: TextStyle(
                                            fontFamily: 'Malgun Gothic',
                                            fontSize: 12.5,
                                            fontWeight: isUnread
                                                ? FontWeight.bold
                                                : FontWeight.w400,
                                            color: isUnread
                                                ? const Color(0xFF0D47A1)
                                                : const Color(0xFF607D8B),
                                          ),
                                        ),
                                        if (event.subtitle.isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 2),
                                          Text(
                                            event.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Malgun Gothic',
                                              fontSize: 11,
                                              color: Color(0xFF90A4AE),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Malgun Gothic',
                                      fontSize: 10,
                                      color: Color(0xFF90A4AE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
