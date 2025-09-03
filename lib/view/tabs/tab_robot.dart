import 'dart:async';
import 'dart:convert';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/view/components/input_edit_dropdown.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/tabs/mobile/tab_robot_mobile.dart';
import 'package:fms/view/tabs/tab_robot_graph.dart';
import 'package:fms/view/tabs/tab_robot_logviewer.dart';
import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../model/robot_model.dart';
import '../../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../utils/ui_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;
import '../../utils/utils.dart';
import '../../viewmodel/controller/graph_controller.dart';
import '../../viewmodel/controller/log_controller.dart';
import '../../viewmodel/controller/map_controller.dart';
import '../components/input_edit_text_ex.dart';
import '../components/input_edit_text_long.dart';
import '../components/robot_list_view.dart';
import '../components/taro_map_view.dart';
import '../dialogs/ask_dialog.dart';

class TabRobot extends StatefulWidget {
  const TabRobot({super.key});

  @override
  State<TabRobot> createState() => _TabRobotState();
}

class _TabRobotState extends State<TabRobot> with TickerProviderStateMixin {
  final List<String> _tabTitles = ["그래프 보기", "로그 보기"];
  late TabController _tabController;

  bool _isRightPanelVisible = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // === Map bridge (как в TabDashboard) ===
  static final Set<String> _registeredViewTypes = {};
  late final String _viewId;
  Widget _mapView = const SizedBox.shrink();

  bool _mapReady = false;
  final List<String> _postQueue = [];
  html.IFrameElement? _iframe;
  WebViewController? _wvCtrl;
  Completer<dynamic>? _mapWindowC;
  String? _mapOrigin;
  StreamSubscription<html.MessageEvent>? _msgSub;

  String _selectedRobotType = "";
  String _selectedRobotFilter = "";

  final TextEditingController _robotNameController = TextEditingController();
  final FocusNode _robotNameFocusNode = FocusNode();

  final TextEditingController _serialController = TextEditingController();
  final FocusNode _serialFocusNode = FocusNode();

  final TextEditingController _descController = TextEditingController();
  final FocusNode _descFocusNode = FocusNode();

  int _selectedObjectId = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _tabTitles.length);

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final robotController = Get.find<RobotController>();
      await robotController.reqRobotTypes();
      await robotController.reqRobotList();
      await robotController.reqRobotStatusList();

      _viewId = 'kakao-map-frame-${DateTime.now().millisecondsSinceEpoch}';
      final mapUrl = Get.find<MapController>().mapUri.toString();

      if (kIsWeb) {
        _setupWebView(mapUrl);
      } else {
        _setupNativeWebView(mapUrl);
      }

      if (!_mapReady) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return !_mapReady;
        });
      }

      for (final status in robotController.robotStatusList) {
        if (status.id != null && status.latitude != null && status.longitude != null) {
          _postMoveCar(status.id!.toString(), status.latitude!, status.longitude!);
        }
      }

      if (_selectedObjectId >= 0) {
        _postSelectCar(_selectedObjectId);
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  // === WebView / IFrame setup (как в TabDashboard) ===
  void _setupWebView(String mapUrl) {
    final uri = Uri.parse(mapUrl);
    _mapOrigin = uri.origin;
    _mapWindowC = Completer<dynamic>();

    if (!_registeredViewTypes.contains(_viewId)) {
      ui.platformViewRegistry.registerViewFactory(_viewId, (_) {
        _iframe = html.IFrameElement()
          ..id = _viewId
          ..src = mapUrl
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';

        _iframe!.onLoad.listen((_) async {
          final start = DateTime.now();
          dynamic win;
          while (win == null && DateTime.now().difference(start) < const Duration(seconds: 5)) {
            win = _iframe?.contentWindow;
            if (win == null) await Future.delayed(const Duration(milliseconds: 50));
          }

          if (mounted) setState(() => _mapReady = win != null);

          if (!(_mapWindowC?.isCompleted ?? true)) {
            _mapWindowC?.complete(win);
          }

          if (win != null && _postQueue.isNotEmpty) {
            for (final p in _postQueue) {
              try {
                (win as dynamic).postMessage(p, _mapOrigin ?? '*');
              } catch (e) {
                debugPrint("postMessage flush error: $e");
              }
            }
            _postQueue.clear();
          }

          if (_selectedObjectId >= 0) {
            _postSelectCar(_selectedObjectId);
          }
        });

        return _iframe!;
      });
      _registeredViewTypes.add(_viewId);
    }

    _msgSub = html.window.onMessage.listen((e) {
      try {
        final data = e.data;
        final parsed = (data is String) ? jsonDecode(data) : data;
        if (parsed is Map) _processMessage(parsed);
      } catch (_) {}
    });

    _mapView = HtmlElementView(viewType: _viewId, key: UniqueKey());
  }

  void _setupNativeWebView(String mapUrl) {
    _wvCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => _mapReady = true);

            for (final payload in _postQueue) {
              final escaped = _escapeJavaScriptString(payload);
              _wvCtrl!.runJavaScript("window.postMessage('$escaped', '*');");
            }
            _postQueue.clear();

            if (_selectedObjectId >= 0) {
              _postSelectCar(_selectedObjectId);
            }
          },
          onWebResourceError: (e) => debugPrint("WebView error: $e"),
        ),
      )
      ..loadRequest(Uri.parse(mapUrl));

    _mapView = WebViewWidget(controller: _wvCtrl!);
  }

  String _escapeJavaScriptString(String input) {
    final withEscapedBackslashes = input.replaceAll(r'\', r'\\');
    final withEscapedQuotes = withEscapedBackslashes.replaceAll("'", r"\'");
    return withEscapedQuotes;
  }

  Future<void> _sendMessageToMap(String jsonPayload) async {
    debugPrint("_sendMessageToMap() $jsonPayload");

    try {
      if (!_mapReady) {
        _postQueue.add(jsonPayload);
        return;
      }

      if (kIsWeb) {
        final win = (_mapWindowC?.isCompleted == true) ? await _mapWindowC!.future : await _mapWindowC?.future;
        if (win != null) {
          (win as dynamic).postMessage(jsonPayload, _mapOrigin ?? '*');
        } else {
          _postQueue.add(jsonPayload);
        }
      } else {
        if (_wvCtrl != null) {
          final escaped = _escapeJavaScriptString(jsonPayload);
          await _wvCtrl!.runJavaScript("window.postMessage('$escaped', '*');");
        } else {
          _postQueue.add(jsonPayload);
        }
      }
    } catch (e, st) {
      debugPrint("[Exception] _sendMessageToMap() e: $e");
      debugPrint("$st");
      _postQueue.add(jsonPayload);
    }
  }

  // === messages to map ===
  void _postMoveCar(String id, double lat, double lng) {
    final payload = jsonEncode({'sender': 'moveCar', 'value': '$id,$lat,$lng;'});
    _sendMessageToMap(payload);
  }

  void _postSelectCar(int objectId) {
    setState(() => _selectedObjectId = objectId);
    final payload = jsonEncode({'sender': 'selectCar', 'id': objectId});
    _sendMessageToMap(payload);
  }

  // === messages from map ===
  void _processMessage(Map data) {
    if (!mounted) return;

    if (data['sender'] == 'onClickCar') {
      final id = int.tryParse(data['message'].toString());
      if (id != null) setState(() => _selectedObjectId = id);
    } else if (data.containsKey('move_res')) {
      final m = data['move_res'];
      final coords = List.from(m['data']['cur_coodi']);
      _postMoveCar(
        m['from'].toString(),
        (coords[0] as num).toDouble(),
        (coords[1] as num).toDouble(),
      );
    }
  }

  Future<void> _refreshMapAfterReturn(int selectedId) async {
    if (!_mapReady) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !_mapReady;
      });
    }
    final list = Get.find<RobotController>().robotStatusList;
    for (final s in list) {
      if (s.id != null && s.latitude != null && s.longitude != null) {
        _postMoveCar(s.id.toString(), s.latitude!, s.longitude!);
      }
    }
    _postSelectCar(selectedId);
  }

  void toggleRightPanel() async {
    _isRightPanelVisible = !_isRightPanelVisible;
    if (_isRightPanelVisible) {
      await Get.find<RobotController>().reqRobotTypes();
      _animationController.forward();
    } else {
      _robotNameController.text = "";
      _serialController.text = "";
      _descController.text = "";
      _selectedRobotType = "";
      _animationController.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabRobotMobile();
    }

    return Stack(
      children: [
        Row(
          children: [
            const SizedBox(width: 396),
            buildRobotStatePanel(),
            const SizedBox(width: 12),
            Expanded(child: buildRobotGraphPanel()),
          ],
        ),
        if (_isRightPanelVisible || _animationController.value > 0)
          Positioned(
            left: 400,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: buildAddRobotPanel(),
            ),
          ),
        Row(
          children: [
            buildRobotListPanel(),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  Widget buildAddRobotPanel() {
    return Container(
      width: 496,
      height: MediaQuery.of(context).size.height - 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(3, 0),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            alignment: Alignment.centerLeft,
            child: Text(
              "로봇 추가",
              style: TextStyle(
                fontFamily: 'pretendard',
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            "종류",
            style: const TextStyle(
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
              if (mounted) {
                setState(() {});
              }
            },
            selectedText: _selectedRobotType,
          ),
          const SizedBox(height: 22),
          Text(
            "이름",
            style: const TextStyle(
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
            onChanged: (value) {
              //
            },
          ),
          const SizedBox(height: 22),
          Text(
            "시리얼 넘버",
            style: const TextStyle(
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
            onChanged: (value) {
              //
            },
          ),
          const SizedBox(height: 22),
          Text(
            "설명",
            style: const TextStyle(
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
            onChanged: (value) {
              //
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  buttonText: "확인",
                  buttonColor: const Color(0xFF005FB8),
                  onTap: addRobot,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GradientButton(
                  buttonText: "취소",
                  onTap: toggleRightPanel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRobotStatePanel() {
    return Container(
      width: 496,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(3, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: GetBuilder<RobotController>(
        init: RobotController(),
        builder: (controller) {
          Robot? selectedRobot;

          List<Robot> robots = controller.robots;
          for (int i = 0; i < robots.length; i++) {
            if (robots[i].id == _selectedObjectId) {
              selectedRobot = robots[i];
              break;
            }
          }

          if (_selectedObjectId == -1 || selectedRobot == null) {
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

          if ((selectedRobot.typeDescription ?? "").toLowerCase() == "taro") {
            return buildTaroStatePanel(selectedRobot);
          } else {
            return buildUntactStatePanel(selectedRobot);
          }
        },
      ),
    );
  }

  Widget buildTaroStatePanel(Robot robot) {
    return GetBuilder<RobotController>(
      init: RobotController(),
      builder: (controller) {
        RobotStatus? robotState;
        List<RobotStatus> robotStatusList = controller.robotStatusList;

        for (int i = 0; i < robotStatusList.length; i++) {
          if (robotStatusList[i].id == robot.id) {
            robotState = robotStatusList[i];
            break;
          }
        }

        double speed = 0.0;
        if (robotState != null) {
          speed = robotState.drivingSpeed ?? 0.0;
          speed = ((speed * 100).floor() / 100);
          speed = speed.abs();
        }

        bool isDeleted = (robot.isDeleted == true);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${robot.typeDescription}_${robot.name}",
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 78,
                            height: 78,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: const Color(0xFFDADADA), width: 1.0),
                              image: DecorationImage(
                                image: ExtendedNetworkImageProvider(
                                  robot.imageUrl ?? robot.typeImageUrl ?? "",
                                  cache: true,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: (isDeleted)
                                ? Container()
                                : Container(
                                    height: 16,
                                    width: 78,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.rectangle,
                                      color: Get.find<RobotController>()
                                          .getTaroStatedColor(robot.serial ?? "")
                                          .withOpacity(0.7),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      Get.find<RobotController>().getTaroStateLabel(robot.serial ?? ""),
                                      style: TextStyle(
                                        fontFamily: 'pretendard',
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                          ),
                          if (isDeleted)
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFDADADA)),
                                color: Color(0xFFD9D9D9).withValues(alpha: 0.5),
                              ),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 16,
                                width: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  color: const Color(0xFF1E1F50),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "삭제됨",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      const Text(
                                        "배터리 %",
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 13,
                                          color: Color(0xFF666565),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        (isDeleted || robotState == null || robotState.wheelBattery == null)
                                            ? "-"
                                            : robotState.wheelBattery!.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 28,
                                          color: (robotState == null || robotState.wheelBattery == null)
                                              ? kHintColor
                                              : Colors.black,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(width: 1, height: 60, color: const Color(0xFFDBDBDB)),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      const Text(
                                        "현재 속도 m/s",
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 13,
                                          color: Color(0xFF666565),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        (isDeleted) ? "-" : speed.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 28,
                                          color: (robotState == null || robotState.drivingSpeed == null)
                                              ? kHintColor
                                              : Colors.black,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(width: 1, height: 60, color: const Color(0xFFDBDBDB)),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      const Text(
                                        "탑승 여부",
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 13,
                                          color: Color(0xFF666565),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: Text(
                                          (isDeleted)
                                              ? "-"
                                              : Get.find<RobotController>().getTaroIsSeated(robot.serial ?? "")
                                                  ? "Seated"
                                                  : "Empty",
                                          style: TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 28,
                                            color: Get.find<RobotController>().getTaroIsSeated(robot.serial ?? "")
                                                ? Colors.black
                                                : Colors.grey,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Text(
                      "로봇 제어",
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
                            if (isDeleted) {
                              return;
                            }

                            Map<String, dynamic> payload = {};
                            payload['Robot_Num'] = robot.serial;
                            payload['Status'] = RobotState.manualMode;
                            payload['Service_Mode'] = 0;
                            payload['Position_X'] = 0.0;
                            payload['Position_Y'] = 0.0;
                            payload['Position_Z'] = 0.0;
                            payload['Position_W'] = 0.0;
                            payload['Goal_X'] = 0.0;
                            payload['Goal_Y'] = 0.0;
                            payload['Goal_Z'] = 0.0;
                            payload['Goal_W'] = 0.0;

                            String jsonPayload = json.encode(payload);
                            Get.find<MqttController>().publishMessage("Info_Display_Sub", jsonPayload);
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
                                  "자율주행",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 14,
                                    color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  (isDeleted)
                                      ? "이용불가"
                                      : (robotState == null)
                                          ? "-"
                                          : Get.find<RobotController>().getIsTaroAutoPilotMode(robot.serial ?? "")
                                              ? "켜짐"
                                              : "꺼짐",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 12,
                                    color: (isDeleted)
                                        ? Color(0xFF666565)
                                        : (robotState == null)
                                            ? kHintColor
                                            : Get.find<RobotController>().getIsTaroAutoPilotMode(robot.serial ?? "")
                                                ? Color(0xFF005FB8)
                                                : Color(0xFF666565),
                                    fontWeight: (isDeleted)
                                        ? FontWeight.w400
                                        : Get.find<RobotController>().getIsTaroAutoPilotMode(robot.serial ?? "")
                                            ? FontWeight.w600
                                            : FontWeight.w400,
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
                            if (isDeleted) {
                              return;
                            }

                            int modeOn = (robotState!.onPromotionMode ?? false)
                                ? RobotState.promotionModeOff
                                : RobotState.promotionModeOn;

                            Map<String, dynamic> data = {};
                            data['Send'] = 1;
                            data['Robot_Num'] = robot.serial;
                            data['Service_Mode'] = 0;
                            data['Bookcase_Num'] = 0;
                            data['Target_X'] = 0.0;
                            data['Target_Y'] = 0.0;
                            data['Target_Z'] = 0.0;
                            data['Target_W'] = 0.0;
                            data['Current_X'] = 0.0;
                            data['Current_Y'] = 0.0;
                            data['Current_Z'] = 0.0;
                            data['Current_W'] = 0.0;
                            data['RobotStatus'] = modeOn;
                            data['channel'] = "MainPage";
                            data['Goal_X'] = 0.0;
                            data['Goal_Y'] = 0.0;
                            data['Goal_Z'] = 0.0;
                            data['Goal_W'] = 0.0;

                            Map<String, dynamic> mainMessage = {};
                            mainMessage['Comm'] = "MainPage";
                            mainMessage['Data'] = data;

                            String jsonPayload = json.encode(mainMessage);
                            Get.find<MqttController>().publishMessage("MainPage_Pub/${robot.serial}", jsonPayload);
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
                                  "홍보모드",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 14,
                                    color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  (isDeleted)
                                      ? "이용불가"
                                      : (robotState == null || robotState.onPromotionMode == null)
                                          ? "-"
                                          : (robotState.onPromotionMode == true)
                                              ? "켜짐"
                                              : "꺼짐",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 12,
                                    color: (isDeleted)
                                        ? Color(0xFF666565)
                                        : (robotState == null || robotState.onPromotionMode == null)
                                            ? kHintColor
                                            : (robotState.onPromotionMode == true)
                                                ? Color(0xFF005FB8)
                                                : Color(0xFF666565),
                                    fontWeight: (isDeleted)
                                        ? FontWeight.w400
                                        : (robotState != null && robotState.onPromotionMode == true)
                                            ? FontWeight.w600
                                            : FontWeight.w400,
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
                        child: GradientButton(
                          buttonText: "위치 초기화",
                          buttonColor: isDeleted ? const Color(0xFFE8E8E8) : Colors.white,
                          fontSize: 14,
                          onTap: () {
                            if (isDeleted) {
                              return;
                            }

                            Map<String, dynamic> data = {};
                            data['Send'] = 1;
                            data['Robot_Num'] = robot.serial ?? "";
                            data['Service_Mode'] = 0;
                            data['Bookcase_Num'] = 0;
                            data['Target_X'] = 0.0;
                            data['Target_Y'] = 0.0;
                            data['Target_Z'] = 0.0;
                            data['Target_W'] = 0.0;
                            data['Current_X'] = kDefaultPosition.x;
                            data['Current_Y'] = kDefaultPosition.y;
                            data['Current_Z'] = 0.0;
                            data['Current_W'] = 0.0;
                            data['RobotStatus'] = RobotState.waiting;
                            data['TimeManual'] = 0.0;
                            data['TimeAuto'] = 0.0;
                            data['DistanceManual'] = 0.0;
                            data['DistanceAuto'] = 0.0;
                            data['Acc_TimeManual'] = 0.0;
                            data['Acc_TimeAuto'] = 0.0;
                            data['Acc_DistanceManual'] = 0.0;
                            data['Acc_DistanceAuto'] = 0.0;
                            data['WheelBattery'] = robotState!.wheelBattery ?? 0.0;
                            data['channel'] = "MainPage";

                            Map<String, dynamic> mainMessage = {};
                            mainMessage['Comm'] = "MainPage";
                            mainMessage['Data'] = data;

                            String jsonPayload = json.encode(mainMessage);
                            Get.find<MqttController>().publishMessage("MainPage_Sub", jsonPayload);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientButton(
                          buttonText: "긴급제동",
                          buttonColor: isDeleted ? const Color(0xFFE8E8E8) : const Color(0xFFC42B1C),
                          fontSize: 14,
                          onTap: () {
                            if (isDeleted) {
                              return;
                            }

                            Map<String, dynamic> payload = {};
                            payload['Robot_Num'] = robot.serial ?? "";
                            payload['Status'] = RobotState.stop;
                            payload['Service_Mode'] = 0;
                            payload['Position_X'] = 0.0;
                            payload['Position_Y'] = 0.0;
                            payload['Position_Z'] = 0.0;
                            payload['Position_W'] = 0.0;
                            payload['Goal_X'] = 0.0;
                            payload['Goal_Y'] = 0.0;
                            payload['Goal_Z'] = 0.0;
                            payload['Goal_W'] = 0.0;

                            String jsonPayload = json.encode(payload);
                            Get.find<MqttController>().publishMessage("Info_Display_Sub", jsonPayload);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                          "누적 주행 거리",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: Color(0xFF666565),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isDeleted
                              ? "-"
                              : (robotState == null || robotState.accDistanceAuto == null)
                                  ? ""
                                  : Utils.numberWithComma(robotState.accDistanceAuto!.round()),
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 20,
                            color:
                                (robotState == null || robotState.accDistanceAuto == null) ? kHintColor : Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "m",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: Color(0xFF666565),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
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
                          "현재 주행 거리",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: Color(0xFF666565),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isDeleted
                              ? "-"
                              : (robotState == null || robotState.distanceAuto == null)
                                  ? ""
                                  : Utils.numberWithComma(robotState.distanceAuto!.round()),
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 20,
                            color: (robotState == null || robotState.distanceAuto == null) ? kHintColor : Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "m",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: Color(0xFF666565),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
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
                          "주행 시간",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: Color(0xFF666565),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isDeleted
                              ? "-"
                              : (robotState == null || robotState.timeAuto == null)
                                  ? ""
                                  : Utils.getTimeString(robotState.timeAuto!.round()),
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 20,
                            color: (robotState == null || robotState.timeAuto == null) ? kHintColor : Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "m",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: Colors.transparent,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      if (isDeleted) {
                        return;
                      }

                      final result = await showDialog(
                        context: Get.context!,
                        builder: (BuildContext context) {
                          return AskDialog(
                            message: '이 로봇을 삭제하시겠습니까?',
                            addMessage: "이 로봇을 삭제하면 관련 데이터도 함께 삭제됩니다.\n정말 삭제하시겠습니까?",
                            leftText: "삭제",
                            rightText: "취소",
                          );
                        },
                        barrierDismissible: false,
                      );

                      if (result != "LEFT") {
                        return;
                      }

                      bool isSuccess = await Get.find<RobotController>().reqDeleteRobot(robot.id!);
                      if (isSuccess) {
                        Utils.showSnackBar("삭제 되었습니다");

                        _selectedObjectId = -1;

                        Get.find<RobotController>().reqRobotTypes();
                        Get.find<RobotController>().reqRobotList();
                        Get.find<RobotController>().reqRobotStatusList();

                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      alignment: Alignment.centerRight,
                      child: Text(
                        "로봇 삭제하기",
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 13,
                          color: (isDeleted) ? Colors.transparent : Color(0xFFC42B1C),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFAAAAAA),
                    child: TaroMapView(selectedTaroSerial: robot.serial, initialScale: 1.2),
                  ),
                  if (isDeleted)
                    Positioned.fill(
                      child: Container(
                        color: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildUntactStatePanel(Robot robot) {
    return GetBuilder<RobotController>(
        init: RobotController(),
        builder: (controller) {
          RobotStatus? robotState;
          List<RobotStatus> robotStatusList = controller.robotStatusList;

          for (int i = 0; i < robotStatusList.length; i++) {
            if (robotStatusList[i].id == robot.id) {
              robotState = robotStatusList[i];
              break;
            }
          }

          bool allOpenDeliveryBox = false;
          if (robotState != null) {
            allOpenDeliveryBox = (robotState.openDeliveryBox01 == true) &&
                (robotState.openDeliveryBox02 == true) &&
                (robotState.openDeliveryBox03 == true) &&
                (robotState.openDeliveryBox04 == true);
          }

          bool isDeleted = (robot.isDeleted == true);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "${robot.typeDescription}_${robot.name}",
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              alignment: Alignment.bottomCenter,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFDADADA), width: 1.0),
                                image: DecorationImage(
                                  image: ExtendedNetworkImageProvider(
                                    robot.imageUrl ?? robot.typeImageUrl ?? "",
                                    cache: true,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: (isDeleted)
                                  ? Container()
                                  : Container(
                                      height: 16,
                                      width: 78,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.rectangle,
                                        color: kStateColor[robotState!.robotStatus ?? 0].withOpacity(0.7),
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        kStateStr[robotState!.robotStatus ?? 0],
                                        style: TextStyle(
                                          fontFamily: 'pretendard',
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                            ),
                            if (isDeleted)
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: const Color(0xFFDADADA)),
                                  color: Color(0xFFD9D9D9).withValues(alpha: 0.5),
                                ),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: 16,
                                  width: 78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    color: const Color(0xFF1E1F50),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    "삭제됨",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        const Text(
                                          "차량용 배터리 (%)",
                                          style: TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 13,
                                            color: Color(0xFF666565),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          (isDeleted || robotState == null || robotState.battery == null)
                                              ? "-"
                                              : robotState.battery!.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 28,
                                            color: (robotState == null || robotState.battery == null)
                                                ? kHintColor
                                                : Colors.black,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 60, color: const Color(0xFFDBDBDB)),
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Column(
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
                                        const SizedBox(height: 12),
                                        Text(
                                          (isDeleted || robotState == null || robotState.drivingSpeed == null)
                                              ? "-"
                                              : robotState.drivingSpeed.toString(),
                                          style: TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 28,
                                            color: (robotState == null || robotState.drivingSpeed == null)
                                                ? kHintColor
                                                : Colors.black,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 60, color: const Color(0xFFDBDBDB)),
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Column(
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
                                        const SizedBox(height: 12),
                                        Text(
                                          (isDeleted || robotState == null || robotState.serviceBattery == null)
                                              ? "-"
                                              : robotState.serviceBattery!.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 28,
                                            color: (robotState == null || robotState.serviceBattery == null)
                                                ? kHintColor
                                                : Colors.black,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (isDeleted) {
                                return;
                              }

                              String setValue = (robotState!.onAutoPilot == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "on_auto_pilot";
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
                                    "자율주행",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 14,
                                      color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isDeleted
                                        ? "이용불가"
                                        : (robotState == null || robotState.onAutoPilot == null)
                                            ? "-"
                                            : (robotState.onAutoPilot == true)
                                                ? "켜짐"
                                                : "꺼짐",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: isDeleted
                                          ? const Color(0xFF666565)
                                          : (robotState == null || robotState.onAutoPilot == null)
                                              ? kHintColor
                                              : (robotState.onAutoPilot == true)
                                                  ? const Color(0xFF005FB8)
                                                  : const Color(0xFF666565),
                                      fontWeight: (robotState != null && robotState.onAutoPilot == true)
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientButton(
                            buttonText: (robotState != null && robotState.onReturning == true) ? "센터복귀중" : "센터복귀",
                            buttonColor: isDeleted ? const Color(0xFFE8E8E8) : Colors.white,
                            fontSize: 14,
                            onTap: () {
                              if (isDeleted) {
                                return;
                              }

                              String setValue = (robotState!.onReturning == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "on_returning";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
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
                              if (isDeleted) {
                                return;
                              }

                              String setValue = (robotState!.onHeadLight == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "on_head_light";
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
                                    "전조등",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 14,
                                      color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isDeleted
                                        ? "이용불가"
                                        : (robotState == null || robotState.onHeadLight == null)
                                            ? "-"
                                            : (robotState.onHeadLight == true)
                                                ? "켜짐"
                                                : "꺼짐",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: isDeleted
                                          ? const Color(0xFF666565)
                                          : (robotState == null || robotState.onHeadLight == null)
                                              ? kHintColor
                                              : (robotState.onHeadLight == true)
                                                  ? Color(0xFF005FB8)
                                                  : Color(0xFF666565),
                                      fontWeight: (robotState != null && robotState.onHeadLight == true)
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientButton(
                            buttonText: (robotState!.onEmergencyStop == true) ? "긴급제동중" : "긴급제동",
                            buttonColor: isDeleted ? const Color(0xFFE8E8E8) : const Color(0xFFC42B1C),
                            fontSize: 14,
                            onTap: () {
                              if (isDeleted) {
                                return;
                              }

                              String setValue = (robotState!.onEmergencyStop == true) ? "wait" : "ready";

                              Map<String, dynamic> data = {};
                              data['message'] = setValue;

                              Map<String, dynamic> payload = {};
                              payload['tag'] = "on_emergency_stop";
                              payload['action'] = "status";
                              payload['data'] = data;

                              String jsonPayload = json.encode(payload);
                              Get.find<MqttController>().publishMessage(robot.serial ?? "", jsonPayload);
                            },
                          ),
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
                              if (isDeleted) {
                                return;
                              }

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
                                      color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isDeleted
                                        ? "이용불가"
                                        : (robotState.openRefrigDoor == null)
                                            ? "-"
                                            : (robotState.openRefrigDoor == true)
                                                ? "열림"
                                                : "닫힘",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: isDeleted
                                          ? const Color(0xFF666565)
                                          : (robotState.openRefrigDoor == null)
                                              ? kHintColor
                                              : (robotState.openRefrigDoor == true)
                                                  ? Color(0xFF005FB8)
                                                  : Color(0xFF666565),
                                      fontWeight:
                                          (robotState.openRefrigDoor == true) ? FontWeight.w600 : FontWeight.w400,
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
                              if (isDeleted) {
                                return;
                              }

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
                                      color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isDeleted
                                        ? "이용불가"
                                        : (robotState.openInnerDoor == null)
                                            ? "-"
                                            : (robotState.openInnerDoor == true)
                                                ? "열림"
                                                : "닫힘",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: isDeleted
                                          ? const Color(0xFF666565)
                                          : (robotState.openInnerDoor == null)
                                              ? kHintColor
                                              : (robotState.openInnerDoor == true)
                                                  ? Color(0xFF005FB8)
                                                  : Color(0xFF666565),
                                      fontWeight:
                                          (robotState.openInnerDoor == true) ? FontWeight.w600 : FontWeight.w400,
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
                              if (isDeleted) {
                                return;
                              }

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
                                      color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isDeleted
                                        ? "이용불가"
                                        : (robotState.onInnerLight == null)
                                            ? "-"
                                            : (robotState.onInnerLight == true)
                                                ? "켜짐"
                                                : "꺼짐",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: isDeleted
                                          ? const Color(0xFF666565)
                                          : (robotState.onInnerLight == null)
                                              ? kHintColor
                                              : (robotState.onInnerLight == true)
                                                  ? Color(0xFF005FB8)
                                                  : Color(0xFF666565),
                                      fontWeight: (robotState.onInnerLight == true) ? FontWeight.w600 : FontWeight.w400,
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
                              if (isDeleted) {
                                return;
                              }

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
                                      fontSize: 14,
                                      color: isDeleted ? const Color(0xFF666565) : Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isDeleted
                                        ? "이용불가"
                                        : (robotState.onOutsideDisplay == null)
                                            ? "-"
                                            : (robotState.onOutsideDisplay == true)
                                                ? "켜짐"
                                                : "꺼짐",
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 12,
                                      color: isDeleted
                                          ? const Color(0xFF666565)
                                          : (robotState.onOutsideDisplay == null)
                                              ? kHintColor
                                              : (robotState.onOutsideDisplay == true)
                                                  ? Color(0xFF005FB8)
                                                  : Color(0xFF666565),
                                      fontWeight:
                                          (robotState.onOutsideDisplay == true) ? FontWeight.w600 : FontWeight.w400,
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
                              color: isDeleted ? const Color(0xFF666565) : Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (isDeleted) {
                                    return;
                                  }

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
                                  isDeleted ? "-" : "1번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color:
                                        (robotState.openDeliveryBox01 == true) ? Color(0xFF005FB8) : Color(0xFF666565),
                                    fontWeight:
                                        (robotState.openDeliveryBox01 == true) ? FontWeight.w500 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (isDeleted) {
                                    return;
                                  }

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
                                  isDeleted ? "-" : "2번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color:
                                        (robotState.openDeliveryBox02 == true) ? Color(0xFF005FB8) : Color(0xFF666565),
                                    fontWeight:
                                        (robotState.openDeliveryBox02 == true) ? FontWeight.w500 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (isDeleted) {
                                    return;
                                  }

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
                                  isDeleted ? "-" : "3번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color:
                                        (robotState.openDeliveryBox03 == true) ? Color(0xFF005FB8) : Color(0xFF666565),
                                    fontWeight:
                                        (robotState.openDeliveryBox03 == true) ? FontWeight.w500 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (isDeleted) {
                                    return;
                                  }

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
                                  isDeleted ? "-" : "4번",
                                  style: TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 15,
                                    color:
                                        (robotState.openDeliveryBox04 == true) ? Color(0xFF005FB8) : Color(0xFF666565),
                                    fontWeight:
                                        (robotState.openDeliveryBox04 == true) ? FontWeight.w500 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              if (isDeleted) {
                                return;
                              }

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
                              isDeleted
                                  ? "이용불가"
                                  : allOpenDeliveryBox
                                      ? "닫기"
                                      : "열기",
                              style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 12,
                                color: isDeleted
                                    ? const Color(0xFF666565)
                                    : allOpenDeliveryBox
                                        ? Color(0xFFC42B1C)
                                        : Color(0xFF005FB8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        if (isDeleted) {
                          return;
                        }

                        final result = await showDialog(
                          context: Get.context!,
                          builder: (BuildContext context) {
                            return AskDialog(
                              message: '이 로봇을 삭제하시겠습니까?',
                              addMessage: "이 로봇을 삭제하면 관련 데이터도 함께 삭제됩니다.\n정말 삭제하시겠습니까?",
                              leftText: "삭제",
                              rightText: "취소",
                            );
                          },
                          barrierDismissible: false,
                        );

                        if (result != "LEFT") {
                          return;
                        }

                        bool isSuccess = await Get.find<RobotController>().reqDeleteRobot(robot.id!);
                        if (isSuccess) {
                          Utils.showSnackBar("삭제 되었습니다");

                          Get.find<RobotController>().reqRobotTypes();
                          Get.find<RobotController>().reqRobotList();
                          Get.find<RobotController>().reqRobotStatusList();

                          if (mounted) {
                            setState(() {});
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        alignment: Alignment.centerRight,
                        child: Text(
                          "로봇 삭제하기",
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 13,
                            color: isDeleted ? Colors.transparent : Color(0xFFC42B1C),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    _mapView,
                    if (isDeleted)
                      Positioned.fill(
                        child: Container(
                          color: Colors.grey.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        });
  }

  Widget buildRobotListPanel() {
    return RobotListView(
      onChanged: (Robot selectedRobot) async {
        final prevId = _selectedObjectId;
        _selectedObjectId = selectedRobot.id ?? 0;

        final robotType = (selectedRobot.typeDescription ?? "").toLowerCase();
        final statuses = Get.find<RobotController>().robotStatusList;
        final status = statuses.firstWhereOrNull((s) => s.id == _selectedObjectId);

        final showingTaro =
            (Get.find<RobotController>().robots.firstWhereOrNull((r) => r.id == prevId)?.typeDescription ?? "")
                    .toLowerCase() ==
                "taro";
        final nowTaro = robotType == "taro";

        if (showingTaro && !nowTaro && _selectedObjectId >= 0) {
          await _refreshMapAfterReturn(_selectedObjectId);
        }

        if (!nowTaro) {
          if (status?.latitude != null && status?.longitude != null) {
            _postMoveCar(_selectedObjectId.toString(), status!.latitude!, status.longitude!);
            await Future.delayed(const Duration(milliseconds: 40));
          }
          _postSelectCar(_selectedObjectId);
        }

        Get.find<GraphController>().setSelectedRobotId(_selectedObjectId);
        Get.find<GraphController>().setSelectedRobotType(robotType);
        Get.find<GraphController>().setSelectedPeriodDistance("daily");
        Get.find<GraphController>().setSelectedPeriodTime("daily");
        Get.find<GraphController>().setSelectedPeriodBattery("daily");
        Get.find<GraphController>().reqUpdateChartItems("daily");

        Get.find<LogController>().clearSelectedIds();
        Get.find<LogController>().setSelectedRobotId(_selectedObjectId);
        Get.find<LogController>().setViewPage(0);
        Get.find<LogController>().reqLogList();

        if (mounted) setState(() {});
      },
      showAddRobotButton: true,
      onRobotButtonTap: toggleRightPanel,
    );
  }

  Future<void> addRobot() async {
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
    for (int i = 0; i < Get.find<RobotController>().robotTypes.length; i++) {
      if (_selectedRobotType == Get.find<RobotController>().robotTypes[i].typeDescription) {
        objectTypeId = Get.find<RobotController>().robotTypes[i].id ?? 0;
      }
    }

    Map<String, dynamic> params = {};
    params['object_type_id'] = objectTypeId;
    params['name'] = _robotNameController.text;
    params['serial'] = _serialController.text;
    if (_descController.text.isNotEmpty) {
      params['description'] = _descController.text;
    }

    bool result = await Get.find<RobotController>().reqAddRobot(params);
    if (result) {
      Utils.showSnackBar("추가되었습니다");

      _selectedRobotType = "";
      _robotNameController.text = "";
      _serialController.text = "";
      _descController.text = "";
      toggleRightPanel();

      Get.find<RobotController>().reqRobotTypes();
      Get.find<RobotController>().reqRobotList();
      Get.find<RobotController>().reqRobotStatusList();
    }
  }

  Widget buildRobotGraphPanel() {
    if (_selectedObjectId == -1) {
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
              TabRobotGraph(),
              TabRobotLogViewer(),
            ],
          ),
        ),
      ],
    );
  }
}
