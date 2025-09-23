import 'dart:convert';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/view/tabs/mobile/components/gradient_button_mobile.dart';
import 'package:fms/view/components/input_edit_dropdown.dart';
import 'package:fms/view/tabs/mobile/components/multi_select_filter.dart';
import 'package:fms/view/tabs/mobile/tab_robot_graph_mobile.dart';
import 'package:fms/view/tabs/mobile/tab_robot_logviewer_mobile.dart';
import 'package:fms/view/tabs/tab_robot_logviewer.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fms/view/tabs/tab_robot.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:fms/utils/ui_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;
import 'package:fms/utils/utils.dart';

import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';
import 'package:fms/viewmodel/controller/map_controller.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';
import 'package:fms/view/components/input_edit_text_ex.dart';
import 'package:fms/view/components/input_edit_text_long.dart';
import 'package:fms/view/tabs/mobile/dialogs/ask_dialog_mobile.dart';
import 'package:fms/utils/clamp.dart';

class TabRobotMobile extends StatefulWidget {
  const TabRobotMobile({super.key});

  @override
  State<TabRobotMobile> createState() => _TabRobotStateMobile();
}

class _TabRobotStateMobile extends State<TabRobotMobile> with TickerProviderStateMixin {
  final List<String> _tabTitles = ["컨트롤러", "그래프 보기", "로그 보기"];

  late final TabController _tabController;

  int _selectedIndex = -1;
  int _currentTabIndex = 0;
  bool _isRightPanelVisible = false;

  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  bool _mapActive = true;

  bool _mapReady = false;
  final List<String> _postQueue = [];
  Color _disabledOr(Color original, bool deleted) => deleted ? const Color(0xFF666565) : original;

  late final String _viewId;
  Widget _mapView = const Center(child: CircularProgressIndicator());

  html.IFrameElement? _iframe;
  WebViewController? _wvCtrl;

  String _selectedRobotType = "";
  String _selectedRobotFilter = "";
  List<String> _filterTypes = [];
  List<String> _selectedFilters = [];

  final _robotNameController = TextEditingController();
  final _serialController = TextEditingController();
  final _descController = TextEditingController();
  final _robotNameFocusNode = FocusNode();
  final _serialFocusNode = FocusNode();
  final _descFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabTitles.length, vsync: this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rc = Get.find<RobotController>();
      await rc.reqRobotTypes();
      await rc.reqRobotList();
      await rc.reqRobotStatusList();

      _viewId = 'kakao-map-${DateTime.now().millisecondsSinceEpoch}';
      final mapUrl = Get.find<MapController>().mapUri.toString();
      kIsWeb ? _setupWebView(mapUrl) : _setupNativeWebView(mapUrl);

      if (!_mapReady) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return !_mapReady;
        });
      }

      for (final s in rc.robotStatusList) {
        final robo = rc.robots.firstWhereOrNull((r) => r.id == s.id);
        final notDeleted = robo != null && !_isDeleted(robo);

        if (notDeleted && s.latitude != null && s.longitude != null) {
          _postMoveCar(s.id.toString(), s.latitude!, s.longitude!);
        }
      }

      final firstActive = rc.robotStatusList.firstWhereOrNull((s) {
        final robo = rc.robots.firstWhereOrNull((r) => r.id == s.id);
        return robo != null && !_isDeleted(robo);
      });

      if (firstActive != null && firstActive.id != null) {
        _selectedIndex = rc.robots.indexWhere((r) => r.id == firstActive.id);
        _postSelectCar(firstActive.id!);
      }

      setState(() {});
    });
  }

  void _applyPointerEventState() {
    if (_iframe != null) {
      (_iframe!.style as dynamic).pointerEvents = _mapActive ? 'auto' : 'none';
    }
    if (_wvCtrl != null) {
      final pe = _mapActive ? 'auto' : 'none';
      _wvCtrl!.runJavaScript(
        "document.documentElement.style.pointerEvents='$pe';"
        "document.body.style.pointerEvents='$pe';",
      );
    }
  }

  void _setupWebView(String mapUrl) {
    ui.platformViewRegistry.registerViewFactory(_viewId, (_) {
      _iframe = html.IFrameElement()
        ..src = mapUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';

      _iframe!.onLoad.listen((_) {
        setState(() => _mapReady = true);
        _applyPointerEventState(); // 🔹

        debugPrint("🟢 지도가 준비되었습니다!");

        Future.delayed(const Duration(milliseconds: 200), () {
          for (final p in _postQueue) {
            _iframe!.contentWindow?.postMessage(p, '*');
          }
          _postQueue.clear();

          if (_selectedIndex >= 0) {
            final id = Get.find<RobotController>().robots[_selectedIndex].id;
            if (id != null) {
              _postSelectCar(id);
            }
          }
        });
      });

      return _iframe!;
    });

    html.window.onMessage.listen((e) {
      try {
        _processMessage(jsonDecode(e.data));
      } catch (_) {}
    });

    setState(() {
      _mapView = HtmlElementView(viewType: _viewId, key: UniqueKey());
    });
  }

  void _setupNativeWebView(String mapUrl) {
    _wvCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() {
              _mapReady = true;
            });
            for (final p in _postQueue) {
              final esc = p.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
              _wvCtrl!.runJavaScript("window.postMessage('$esc', '*');");
            }
            _postQueue.clear();
          },
        ),
      )
      ..loadRequest(Uri.parse(mapUrl));

    _mapView = WebViewWidget(controller: _wvCtrl!);
  }

  void _setMapEnabled(bool enabled) {
    if (_mapActive == enabled) return;

    _mapActive = enabled;

    if (_mapReady) {
      _applyPointerEventState();
    }

    setState(() {});
  }

  String _escapeJs(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  void _sendToMap(String payload) {
    if (_mapReady) {
      if (_iframe != null) {
        _iframe!.contentWindow?.postMessage(payload, '*');
      } else if (_wvCtrl != null) {
        final esc = _escapeJs(payload);
        _wvCtrl!.runJavaScript("window.postMessage('$esc', '*');");
      }
    } else {
      _postQueue.add(payload);
    }
  }

  int _safeIdx(int idx, int max) => (idx >= 0 && idx < max) ? idx : 0;

  bool _isDeleted(Robot r) => Get.find<RobotController>().isDeletedRobot(r.id ?? -1);

  Widget _grayOut(bool disabled, Widget child) {
    return AbsorbPointer(
      absorbing: disabled,
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: child,
      ),
    );
  }

  void _postMoveCar(String id, double lat, double lng) {
    _sendToMap(jsonEncode({
      'sender': 'moveCar',
      'value': '$id,$lat,$lng;',
    }));
  }

  void _postSelectCar(int objectId) {
    _sendToMap(jsonEncode({
      'sender': 'selectCar',
      'id': objectId,
    }));
  }

  void _processMessage(Map data) {
    if (data['sender'] == 'onClickCar') {
      final id = int.tryParse(data['message'].toString());
      if (id != null && mounted) {
        final robots = Get.find<RobotController>().robots;
        final idx = robots.indexWhere((r) => r.id == id);
        if (idx >= 0) {
          if (!_isRightPanelVisible) _toggleRightPanel();
          setState(() => _selectedIndex = idx);
        }
      }
    }
  }

  Future<void> _toggleRightPanel() async {
    final wantOpen = !_isRightPanelVisible;

    _setMapEnabled(!wantOpen);

    if (wantOpen) {
      await Get.find<RobotController>().reqRobotTypes();
      await _animationController.forward();
    } else {
      _robotNameController.clear();
      _serialController.clear();
      _descController.clear();
      _selectedRobotType = "";
      await _animationController.reverse();
    }

    setState(() => _isRightPanelVisible = wantOpen);
  }

  @override
  Widget build(BuildContext context) {
    final RobotController robotController = Get.find<RobotController>();
    final UserController userController = Get.find<UserController>();

    final bool deletedSel = _selectedIndex >= 0 && _isDeleted(robotController.robots[_selectedIndex]);
    final bool showDeleteBar =
        _selectedIndex >= 0 && userController.isAdminUser() && _currentTabIndex == 0 && !deletedSel;

    if (deletedSel && _currentTabIndex > 0) _currentTabIndex = 0;
    if (showDeleteBar && _mapActive) _setMapEnabled(false);
    if (!showDeleteBar && !_isRightPanelVisible && !_mapActive) _setMapEnabled(true);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Stack(
          children: [
            _selectedIndex < 0
                ? ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      buildRobotListPanel(),
                      const SizedBox(height: 80),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedIndex = -1;
                                _currentTabIndex = 0;
                              }),
                              child: const Icon(Icons.arrow_back, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Builder(
                              builder: (context) {
                                final idx = clampIdx(_selectedIndex, robotController.robots.length);
                                return Text(
                                  '${robotController.robots[idx].typeDescription}_${robotController.robots[idx].name}',
                                  style: const TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: const Color(0xFFFAFAFA),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List<Widget>.generate(3, (i) {
                                final bool tabDisabled = deletedSel && i > 0;
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 102,
                                      height: 36,
                                      child: TextButton(
                                        onPressed: tabDisabled ? null : () => setState(() => _currentTabIndex = i),
                                        style: TextButton.styleFrom(
                                          backgroundColor: (!tabDisabled && _currentTabIndex == i)
                                              ? const Color(0xFF005FB8)
                                              : const Color(0xFFFAFAFA),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          const ['컨트롤러', '그래프 보기', '로그 보기'][i],
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: tabDisabled
                                                ? const Color(0xFF666565)
                                                : (_currentTabIndex == i ? Colors.white : Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < 2) const SizedBox(width: 10),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: IndexedStack(
                          index: _currentTabIndex,
                          children: [
                            ListView(
                              padding: EdgeInsets.zero,
                              physics: const BouncingScrollPhysics(),
                              // deletedSel ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                              children: [
                                const SizedBox(height: 12),
                                buildRobotStatePanel(),
                                const SizedBox(height: 24),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: TabRobotGraphMobile(),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: TabRobotLogViewerMobile(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            if (_selectedIndex < 0 && userController.isAdminUser())
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 15,
                right: 16,
                child: Material(
                  color: const Color(0xFFFAFAFA),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add, size: 24, color: Color(0xFF666565)),
                      onPressed: _toggleRightPanel,
                    ),
                  ),
                ),
              ),
            if (showDeleteBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleDeleteRobot,
                  child: Material(
                    elevation: 4,
                    color: const Color(0xFFFAFAFA),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
                        const SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              '로봇 삭제하기',
                              style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 15,
                                color: Color(0xFFC42B1C),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isRightPanelVisible)
              SlideTransition(
                position: _slideAnimation,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: buildAddRobotPanel(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    return SizedBox(
      height: 345,
      width: double.infinity,
      child: IgnorePointer(
        ignoring: !_mapActive,
        child: _mapView,
      ),
    );
  }

  Future<void> _handleDeleteRobot() async {
    if (_selectedIndex < 0) return;

    _setMapEnabled(false);

    final rc = Get.find<RobotController>();
    final robot = rc.robots[_selectedIndex];
    final String? answer = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AskDialog(
        message: '이 로봇을 삭제하시겠습니까?',
        addMessage: '이 로봇을 삭제하면 관련 데이터도 함께 삭제됩니다.\n정말 삭제하시겠습니까?',
        leftText: '삭제',
        rightText: '취소',
      ),
    );

    _setMapEnabled(true);

    if (answer != 'LEFT') return;

    final success = await rc.reqDeleteRobot(robot.id!);
    if (success) {
      Utils.showSnackBar('삭제 되었습니다');

      setState(() => _selectedIndex = -1);

      await rc.reqRobotTypes();
      await rc.reqRobotList();
      await rc.reqRobotStatusList();
    }
  }

  Widget buildAddRobotPanel() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      width: 496,
      height: MediaQuery.of(context).size.height - 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(3, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "로봇 추가",
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 20,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    "종류",
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 13,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InputEditDropDown(
                    items: Get.find<RobotController>().robotTypeDescriptions,
                    hintText: "로봇의 타입을 선택하세요.",
                    onChanged: (value) {
                      _selectedRobotType = value ?? "";
                      if (mounted) setState(() {});
                    },
                    selectedText: _selectedRobotType,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    "이름",
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 13,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InputEditTextEx(
                    controller: _robotNameController,
                    focusNode: _robotNameFocusNode,
                    hintText: "로봇의 이름을 입력하세요.",
                    borderColor: const Color(0xFFD9D9D9),
                    hintTextColor: const Color(0xFF666565),
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    "시리얼 넘버",
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 13,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InputEditTextEx(
                    controller: _serialController,
                    focusNode: _serialFocusNode,
                    hintText: "로봇의 시리얼 넘버를 입력하세요.",
                    borderColor: const Color(0xFFD9D9D9),
                    hintTextColor: const Color(0xFF666565),
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    "설명",
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 13,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InputEditTextLong(
                    controller: _descController,
                    focusNode: _descFocusNode,
                    hintText: "설명을 입력하세요.",
                    borderColor: const Color(0xFFD9D9D9),
                    hintTextColor: const Color(0xFF666565),
                    maxLines: 5,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.fromLTRB(32, 8, 32, 16 + bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    buttonText: "확인",
                    buttonColor: const Color(0xFF005FB8),
                    onTap: _addRobot,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GradientButton(
                    buttonText: "취소",
                    onTap: _toggleRightPanel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRobotStatePanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
      ),
      child: GetBuilder<RobotController>(
        builder: (controller) {
          if (_selectedIndex == -1) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  "로봇을 선택하세요. 😎",
                  style: TextStyle(
                    fontSize: 18,
                    color: kHintColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            );
          }

          final idx = clampIdx(_selectedIndex, controller.robots.length);
          Robot robot = controller.robots[idx];

          return buildUntactStatePanel(robot);
        },
      ),
    );
  }

  Widget _blockInput(bool disabled, Widget child) {
    return AbsorbPointer(absorbing: disabled, child: child);
  }

  Widget buildUntactStatePanel(Robot robot) {
    return GetBuilder<RobotController>(
        init: RobotController(),
        builder: (controller) {
          RobotStatus? robotState;
          for (var s in controller.robotStatusList) {
            if (s.id == robot.id) {
              robotState = s;
              break;
            }
          }
          if (robotState == null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
              child: Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${robot.typeDescription}_${robot.name}",
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 20,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            );
          }

          final state = robotState!;
          final bool deleted = _isDeleted(robot);
          final String badgeText = deleted ? '삭제됨' : kStateStr[_safeIdx(state.robotStatus ?? 0, kStateStr.length)];
          final Color badgeColor =
              deleted ? kNavyColor : kStateColor[_safeIdx(state.robotStatus ?? 0, kStateColor.length)];
          final allOpenDeliveryBox = state.openDeliveryBox01 == true &&
              state.openDeliveryBox02 == true &&
              state.openDeliveryBox03 == true &&
              state.openDeliveryBox04 == true;

          // return AbsorbPointer(
          //   absorbing: _isDeleted(robot),
          //    child: Column(
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDADADA), width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ColorFiltered(
                                  colorFilter: deleted
                                      ? const ColorFilter.mode(Colors.white, BlendMode.saturation)
                                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                                  child: Opacity(
                                    opacity: deleted ? 0.35 : 1.0,
                                    child: ExtendedImage.network(
                                      robot.imageUrl ?? robot.typeImageUrl ?? '',
                                      fit: BoxFit.cover,
                                      cache: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: 16,
                                alignment: Alignment.center,
                                color: (deleted ? kNavyColor : badgeColor).withOpacity(0.7),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "배터리(%)",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 13,
                                      color: Color(0xFF666565),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    state.battery?.toStringAsFixed(1) ?? "-",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 25,
                                      color: _disabledOr(state.battery == null ? kHintColor : Colors.black, deleted),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 1, thickness: 1, color: Color(0xFFDBDBDB)),
                              Row(
                                children: [
                                  const Text(
                                    "현재 속도(km/h)",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 13,
                                      color: Color(0xFF666565),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    state.drivingSpeed?.toString() ?? "-",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 25,
                                      color:
                                          _disabledOr(state.drivingSpeed == null ? kHintColor : Colors.black, deleted),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 1, thickness: 1, color: Color(0xFFDBDBDB)),
                              Row(
                                children: [
                                  const Text(
                                    "임무장비 배터리(%)",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 13,
                                      color: Color(0xFF666565),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    state.serviceBattery?.toStringAsFixed(1) ?? "-",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 25,
                                      color: _disabledOr(
                                          state.serviceBattery == null ? kHintColor : Colors.black, deleted),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: const Text(
                        "차량 제어",
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 13,
                          color: Color(0xFF666565),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: () {
                            String setValue = robotState?.onAutoPilot == true ? "wait" : "ready";
                            final payload = {
                              'tag': "on_auto_pilot",
                              'action': "status",
                              'data': {'message': setValue},
                            };
                            Get.find<MqttController>().publishMessage(robot.serial ?? "", json.encode(payload));
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Text(
                                  "자율주행",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 14,
                                    color: deleted ? const Color(0xFF666565) : Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  deleted ? "이용불가" : (robotState.onAutoPilot == true ? "켜짐" : "꺼짐"),
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 12,
                                    color: deleted
                                        ? Color(0xFF666565)
                                        : (robotState.onAutoPilot == true ? Color(0xFF005FB8) : Color(0xFF666565)),
                                    fontWeight: deleted
                                        ? FontWeight.w400
                                        : (robotState.onAutoPilot == true ? FontWeight.w600 : FontWeight.w400),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            String setValue = robotState?.onHeadLight == true ? "wait" : "ready";
                            final payload = {
                              'tag': "on_head_light",
                              'action': "status",
                              'data': {'message': setValue},
                            };
                            Get.find<MqttController>().publishMessage(robot.serial ?? "", json.encode(payload));
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Text(
                                  "전조등",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 14,
                                    color: deleted ? const Color(0xFF666565) : Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  deleted ? "이용불가" : (robotState.onHeadLight == true ? "켜짐" : "꺼짐"),
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 12,
                                    color: deleted
                                        ? Color(0xFF666565)
                                        : (robotState.onHeadLight == true ? Color(0xFF005FB8) : Color(0xFF666565)),
                                    fontWeight: deleted
                                        ? FontWeight.w400
                                        : (robotState.onHeadLight == true ? FontWeight.w600 : FontWeight.w400),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GradientButton(
                          buttonText: state.onReturning == true ? "센터복귀중" : "센터복귀",
                          buttonColor: deleted ? const Color(0xFFE0E0E0) : Colors.white,
                          borderColor: deleted ? const Color(0xFFD9D9D9) : const Color(0xFFD9D9D9),
                          textColor: deleted ? const Color(0xFF666565) : const Color(0xFF1B1B1B),
                          onTap: deleted
                              ? null
                              : () {
                                  String setValue = robotState?.onReturning == true ? "wait" : "ready";
                                  final payload = {
                                    'tag': "on_returning",
                                    'action': "status",
                                    'data': {'message': setValue},
                                  };
                                  Get.find<MqttController>().publishMessage(robot.serial ?? "", json.encode(payload));
                                },
                        ),
                        const SizedBox(height: 10),
                        GradientButton(
                          buttonText: state.onEmergencyStop == true ? "긴급제동중" : "긴급제동",
                          buttonColor: deleted ? const Color(0xFFE0E0E0) : const Color(0xFFC42B1C),
                          borderColor: Colors.transparent,
                          textColor: deleted ? const Color(0xFF666565) : Colors.white,
                          onTap: deleted
                              ? null
                              : () {
                                  String setValue = robotState?.onEmergencyStop == true ? "wait" : "ready";
                                  final payload = {
                                    'tag': "on_emergency_stop",
                                    'action': "status",
                                    'data': {'message': setValue},
                                  };
                                  Get.find<MqttController>().publishMessage(robot.serial ?? "", json.encode(payload));
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: const Text(
                        "임무장비 제어",
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 13,
                          color: Color(0xFF666565),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              String setValue = (robotState!.openRefrigDoor == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "open_refrig_door";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Text(
                                    "냉장함 도어",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 14,
                                      color: deleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    deleted ? "이용불가" : (robotState.openRefrigDoor == true ? "열림" : "닫힘"),
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: deleted
                                          ? Color(0xFF666565)
                                          : (robotState.openRefrigDoor == true ? Color(0xFF005FB8) : Color(0xFF666565)),
                                      fontWeight: deleted
                                          ? FontWeight.w400
                                          : (robotState.openRefrigDoor == true ? FontWeight.w600 : FontWeight.w400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              String setValue = (robotState!.openInnerDoor == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "interior_door";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Text(
                                    "상온함 도어",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 14,
                                      color: deleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    deleted ? "이용불가" : (robotState.openInnerDoor == true ? "열림" : "닫힘"),
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: deleted
                                          ? Color(0xFF666565)
                                          : (robotState.openInnerDoor == true ? Color(0xFF005FB8) : Color(0xFF666565)),
                                      fontWeight: deleted
                                          ? FontWeight.w400
                                          : (robotState.openInnerDoor == true ? FontWeight.w600 : FontWeight.w400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              String setValue = (robotState!.onInnerLight == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "interior_lamp";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Text(
                                    "내부 조명",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 14,
                                      color: deleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    deleted ? "이용불가" : (robotState.onInnerLight == true ? "켜짐" : "꺼짐"),
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: deleted
                                          ? Color(0xFF666565)
                                          : (robotState.onInnerLight == true ? Color(0xFF005FB8) : Color(0xFF666565)),
                                      fontWeight: deleted
                                          ? FontWeight.w400
                                          : (robotState.onInnerLight == true ? FontWeight.w600 : FontWeight.w400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              String setValue = (robotState!.onOutsideDisplay == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "interior_display";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Text(
                                    "외부 디스플레이",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: deleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    deleted ? "이용불가" : (robotState.onOutsideDisplay == true ? "켜짐" : "꺼짐"),
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 10,
                                      color: deleted
                                          ? Color(0xFF666565)
                                          : (robotState.onOutsideDisplay == true
                                              ? Color(0xFF005FB8)
                                              : Color(0xFF666565)),
                                      fontWeight: deleted
                                          ? FontWeight.w400
                                          : (robotState.onOutsideDisplay == true ? FontWeight.w600 : FontWeight.w400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Text(
                            "배송함",
                            style: TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: deleted ? const Color(0xFF666565) : Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  String setValue = (robotState!.openDeliveryBox01 == true) ? "wait" : "ready";

                                  Map<String, dynamic> data = {};
                                  data['message'] = setValue;

                                  Map<String, dynamic> payload = {};
                                  payload['tag'] = "open_delivery_box_01";
                                  payload['action'] = "status";
                                  payload['data'] = data;

                                  String jsonPayload = json.encode(payload);
                                  Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                                },
                                child: Text(
                                  "1번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color: deleted
                                        ? Color(0xFF666565)
                                        : (robotState.openDeliveryBox01 == true
                                            ? Color(0xFF005FB8)
                                            : Color(0xFF666565)),
                                    fontWeight: deleted
                                        ? FontWeight.w400
                                        : (robotState.openDeliveryBox01 == true ? FontWeight.w500 : FontWeight.w400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  String setValue = (robotState!.openDeliveryBox02 == true) ? "wait" : "ready";

                                  Map<String, dynamic> data = {};
                                  data['message'] = setValue;

                                  Map<String, dynamic> payload = {};
                                  payload['tag'] = "open_delivery_box_02";
                                  payload['action'] = "status";
                                  payload['data'] = data;

                                  String jsonPayload = json.encode(payload);
                                  Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                                },
                                child: Text(
                                  "2번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color: deleted
                                        ? Color(0xFF666565)
                                        : (robotState.openDeliveryBox02 == true
                                            ? Color(0xFF005FB8)
                                            : Color(0xFF666565)),
                                    fontWeight: deleted
                                        ? FontWeight.w400
                                        : (robotState.openDeliveryBox02 == true ? FontWeight.w500 : FontWeight.w400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  String setValue = (robotState!.openDeliveryBox03 == true) ? "wait" : "ready";

                                  Map<String, dynamic> data = {};
                                  data['message'] = setValue;

                                  Map<String, dynamic> payload = {};
                                  payload['tag'] = "open_delivery_box_03";
                                  payload['action'] = "status";
                                  payload['data'] = data;

                                  String jsonPayload = json.encode(payload);
                                  Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                                },
                                child: Text(
                                  "3번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color: deleted
                                        ? Color(0xFF666565)
                                        : (robotState.openDeliveryBox03 == true
                                            ? Color(0xFF005FB8)
                                            : Color(0xFF666565)),
                                    fontWeight: deleted
                                        ? FontWeight.w400
                                        : (robotState.openDeliveryBox03 == true ? FontWeight.w500 : FontWeight.w400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  String setValue = (robotState!.openDeliveryBox04 == true) ? "wait" : "ready";

                                  Map<String, dynamic> data = {};
                                  data['message'] = setValue;

                                  Map<String, dynamic> payload = {};
                                  payload['tag'] = "open_delivery_box_04";
                                  payload['action'] = "status";
                                  payload['data'] = data;

                                  String jsonPayload = json.encode(payload);
                                  Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                                },
                                child: Text(
                                  "4번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color: deleted
                                        ? Color(0xFF666565)
                                        : (robotState.openDeliveryBox04 == true
                                            ? Color(0xFF005FB8)
                                            : Color(0xFF666565)),
                                    fontWeight: deleted
                                        ? FontWeight.w400
                                        : (robotState.openDeliveryBox04 == true ? FontWeight.w500 : FontWeight.w400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              String setValue = allOpenDeliveryBox ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = "$setValue,$setValue,$setValue,$setValue";

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "open_delivery_box";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
                            child: Text(
                              deleted ? "이용불가" : (allOpenDeliveryBox ? "닫기" : "열기"),
                              style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 13,
                                color: deleted
                                    ? Color(0xFF666565)
                                    : (allOpenDeliveryBox ? Color(0xFFC42B1C) : Color(0xFF005FB8)),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              AbsorbPointer(
                absorbing: !_mapActive,
                child: deleted ? const SizedBox(height: 345, width: double.infinity) : _buildMapArea(),
              ),
            ],
          );
        });
  }

  Future<void> _showFilterDialog(BuildContext ctx) async {
    final temp = List<String>.from(_selectedFilters);
    bool selectAll = temp.length == _filterTypes.length;

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(ctx).size.width * 0.8,
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: StatefulBuilder(
              builder: (ctx2, setState2) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text(' Select All'),
                      value: selectAll,
                      onChanged: (v) {
                        setState2(() {
                          selectAll = v ?? false;
                          temp.clear();
                          if (selectAll) temp.addAll(_filterTypes);
                        });
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        children: _filterTypes.map((t) {
                          return CheckboxListTile(
                            title: Text(t),
                            value: temp.contains(t),
                            onChanged: (v) {
                              setState2(() {
                                if (v == true)
                                  temp.add(t);
                                else
                                  temp.remove(t);
                                selectAll = temp.length == _filterTypes.length;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedFilters = temp;
                });
                Navigator.pop(dctx);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget buildRobotListPanel() {
    const double dividerHeight = 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(3, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: GetBuilder<RobotController>(
        builder: (controller) {
          String lc(String s) => s.trim().toLowerCase();

          final typeMap = <String, String>{};
          for (final t in controller.robotTypeDescriptions) {
            typeMap[lc(t)] = t;
          }

          final filters = <String>['Select All', '삭제됨', ...typeMap.values];
          final List<Robot> displayed = controller.robots;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MultiSelectFilter(
                  items: filters,
                  selected: _selectedFilters,
                  hint: 'Robot Filter',
                  onChanged: (sel) {
                    setState(() => _selectedFilters = sel);

                    final selLc = sel.map(lc).toSet();
                    final bool selectAllOn = selLc.contains('select all');
                    final bool includeDeleted = selLc.contains('삭제됨') || selLc.contains('deleted');

                    final allTypeMap = <String, String>{};
                    for (final t in controller.robotTypeDescriptions) {
                      allTypeMap[lc(t)] = t;
                    }

                    List<String> pickedTypes;
                    if (selectAllOn) {
                      pickedTypes = allTypeMap.values.toList();
                    } else {
                      pickedTypes = selLc
                          .where((e) => e != 'select all' && e != '삭제됨' && e != 'deleted')
                          .map((e) => allTypeMap[e])
                          .where((e) => e != null)
                          .cast<String>()
                          .toList();
                    }

                    final filterStr = [
                      if (includeDeleted) '삭제됨',
                      ...pickedTypes,
                    ].join(', ');

                    controller.setRobotFilterStr(filterStr);
                  },
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayed.length,
                itemBuilder: (_, index) {
                  final robot = displayed[index];
                  final isDeleted = controller.isDeletedRobot(robot.id ?? -1);

                  final statusList = controller.robotStatusList;
                  if (statusList.isEmpty) return const SizedBox.shrink();

                  final status = statusList.firstWhere(
                    (s) => s.id == robot.id,
                    orElse: () => RobotStatus(id: null),
                  );
                  if (status.id == null) return const SizedBox.shrink();

                  final battery = status.battery != null ? '${status.battery!.round()}%' : '-%';
                  final location = status.address ?? '-';

                  String statusStr;
                  Color statusColor;
                  if (isDeleted) {
                    statusStr = '삭제됨';
                    statusColor = kNavyColor;
                  } else {
                    final idx = _safeIdx(status.robotStatus ?? 0, kStateStr.length);
                    statusStr = kStateStr[idx];
                    statusColor = kStateColor[idx];
                  }

                  final bool isSel = _selectedIndex >= 0 && controller.robots[_selectedIndex].id == robot.id;
                  final Color rowBg = (isSel || isDeleted) ? const Color(0xFFF0F0F0) : Colors.transparent;

                  final card = GestureDetector(
                    onTap: () {
                      final globalIndex = controller.robots.indexWhere((r) => r.id == robot.id);
                      if (globalIndex == -1 || _selectedIndex == globalIndex) return;

                      setState(() => _selectedIndex = globalIndex);

                      final id = robot.id ?? 0;
                      final type = (robot.typeDescription ?? '').toLowerCase();
                      if (!isDeleted && _mapReady) {
                        final lat = status.latitude;
                        final lng = status.longitude;
                        if (lat != null && lng != null) {
                          _postMoveCar(id.toString(), lat, lng);
                          _postSelectCar(id);
                        } else {
                          Utils.showSnackBar("이 로봇의 좌표를 사용할 수 없습니다!");
                        }
                      } else if (!isDeleted) {
                        Utils.showSnackBar("지도가 로딩 중입니다");
                      }

                      Get.find<GraphController>()
                        ..setSelectedRobotId(id)
                        ..setSelectedRobotType(type)
                        ..setSelectedPeriodDistance('daily')
                        ..setSelectedPeriodTime('daily')
                        ..setSelectedPeriodBattery('daily')
                        ..reqUpdateChartItems('daily');

                      Get.find<LogController>()
                        ..setSelectedRobotId(id)
                        ..setViewPage(0)
                        ..reqLogList();
                    },
                    child: Container(
                      width: double.infinity,
                      color: rowBg,
                      child: Column(
                        children: [
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  "${robot.typeDescription}_${robot.name}",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color: isSel ? const Color(0xFF005CB2) : Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    statusStr,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w400,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: const Color(0xFFDBDBDB),
                          ),
                          Container(
                            height: 100,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFDADADA), width: 1),
                                  ),
                                  foregroundDecoration: isDeleted
                                      ? BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: const Color(0xFFF4F4F4).withOpacity(0.6),
                                          border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
                                        )
                                      : null,
                                  child: ExtendedImage.network(
                                    robot.imageUrl ?? robot.typeImageUrl ?? '',
                                    fit: BoxFit.cover,
                                    cache: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Battery',
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 13,
                                          color: Color(0xFF666565),
                                          fontWeight: FontWeight.w400,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        battery,
                                        style: const TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Location',
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 13,
                                          color: Color(0xFF666565),
                                          fontWeight: FontWeight.w400,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        location,
                                        style: const TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  return isDeleted
                      ? Column(children: [card, Container(height: dividerHeight, color: Colors.white)])
                      : card;
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addRobot() async {
    if (_selectedRobotType.isEmpty) {
      Utils.showSnackBar("로봇 타입을 선택하세요");
      return;
    }
    if (_robotNameController.text.isEmpty) {
      _robotNameFocusNode.requestFocus();
      Utils.showSnackBar("로봇 이름을 입력하세요");
      return;
    }
    if (_serialController.text.isEmpty) {
      _serialFocusNode.requestFocus();
      Utils.showSnackBar("시리얼 번호를 입력하세요");
      return;
    }

    int objectTypeId = -1;
    final rc = Get.find<RobotController>();
    for (final t in rc.robotTypes) {
      if (t.typeDescription == _selectedRobotType) {
        objectTypeId = t.id ?? 0;
      }
    }

    final params = <String, dynamic>{
      'object_type_id': objectTypeId,
      'name': _robotNameController.text,
      'serial': _serialController.text,
    };
    if (_descController.text.isNotEmpty) {
      params['description'] = _descController.text;
    }

    final result = await rc.reqAddRobot(params);
    if (result) {
      Utils.showSnackBar("추가되었습니다");

      _selectedRobotType = "";
      _robotNameController.clear();
      _serialController.clear();
      _descController.clear();

      await _toggleRightPanel();

      await rc.reqRobotTypes();
      await rc.reqRobotList();
      await rc.reqRobotStatusList();

      setState(() => _selectedIndex = -1);
    }
  }

  Widget buildRobotGraphPanel() {
    if (_selectedIndex == -1) {
      return Center(
        child: Text(
          "로봇을 선택하세요. 😎",
          style: TextStyle(
            fontSize: 18,
            color: kHintColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    int robotId = Get.find<RobotController>().robots[_selectedIndex].id ?? 0;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: const Border(
              bottom: BorderSide(color: Color(0xFFD9D9D9), width: 1.0),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 208,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  automaticIndicatorColorAdjustment: false,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666565),
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF005FB8),
                  ),
                  labelColor: const Color(0xFF005FB8),
                  unselectedLabelColor: const Color(0xFF666565),
                  indicatorColor: const Color(0xFF005FB8),
                  onTap: (index) {
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  tabs: [
                    Tab(
                      child: Container(
                        width: 104,
                        height: 48,
                        alignment: Alignment.center,
                        child: Text(
                          _tabTitles[0],
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: (_tabController.index == 0) ? const Color(0xFF005FB8) : const Color(0xFF666565),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    Tab(
                      child: Container(
                        width: 104,
                        height: 48,
                        alignment: Alignment.center,
                        child: Text(
                          _tabTitles[1],
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: (_tabController.index == 1) ? const Color(0xFF005FB8) : const Color(0xFF666565),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              TabRobotGraphMobile(),
              TabRobotLogViewer(),
            ],
          ),
        ),
      ],
    );
  }
}
