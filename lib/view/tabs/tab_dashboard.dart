import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fms/view/components/layout.dart';
import 'package:fms/view/dashboard_widgets/moving_distance_by_day_widget.dart';
import 'package:fms/view/dashboard_widgets/moving_distance_widget.dart';
import 'package:fms/view/dashboard_widgets/operation_time_by_day_widget.dart';
import 'package:fms/view/dashboard_widgets/used_battery_by_day_widget.dart';
import 'package:fms/view/tabs/mobile/tab_dashboard_mobile.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../model/dashboard_model.dart';
import '../../model/robot_model.dart';
import '../../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../utils/ui_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;
import '../../view/dashboard_widgets/alarm_widget.dart';
import '../../view/dashboard_widgets/device_status_widget.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../../viewmodel/controller/map_controller.dart';
import '../../viewmodel/controller/robot_controller.dart';
import '../components/robot_list_view.dart';
import '../dashboard_widgets/operation_time_widget.dart';
import '../dashboard_widgets/used_battery_widget.dart';

class TabDashboard extends StatefulWidget {
  const TabDashboard({super.key, required this.gotoAlarmSet});
  final VoidCallback gotoAlarmSet;

  @override
  State<TabDashboard> createState() => _TabDashboardState();
}

class _TabDashboardState extends State<TabDashboard> {
  int? _selectedObjectId;

  late final String _viewId;
  Widget _mapView = const Center(
    child: CupertinoActivityIndicator(radius: 18, color: Colors.grey),
  );
  static final Set<String> _registeredViewTypes = {};

  bool _mapReady = false;
  final List<String> _postQueue = [];
  html.IFrameElement? _iframe;
  WebViewController? _wvCtrl;
  Completer<dynamic>? _mapWindowC;
  String? _mapOrigin;
  StreamSubscription<html.MessageEvent>? _msgSub;

  List<bool> _layoutSetRow0 = [false, false, false];
  List<bool> _layoutSetRow1 = [false, false, false];
  bool _showRow1st = false;
  bool _showRow2nd = false;

  bool _followSelected = true;
  Timer? _centerDebounceTimer;
  static const _kCenterDebounce = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();

    loadDashboardLayoutSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _viewId = 'kakao-map-frame-${DateTime.now().millisecondsSinceEpoch}';
      Get.find<DashboardController>().setMapViewId(_viewId);

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

      final robotStatusList = Get.find<RobotController>().robotStatusList;
      if (mounted) {
        for (final status in robotStatusList) {
          if (status.id == null || status.latitude == null || status.longitude == null) continue;
          _postMoveCar(status.id.toString(), status.latitude!, status.longitude!);
        }
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _centerDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadDashboardLayoutSettings() async {
    _layoutSetRow0 = [false, false, false];
    _layoutSetRow1 = [false, false, false];

    await Get.find<DashboardController>().reqDashboardLayoutSetting();
    final sets = Get.find<DashboardController>().layoutSets;

    for (int i = 0; i < sets.length; i++) {
      if (sets[i].rowIndex == 0) {
        _layoutSetRow0[sets[i].columnIndex ?? 0] = true;
        _showRow1st = true;
      } else if (sets[i].rowIndex == 1) {
        _layoutSetRow1[sets[i].columnIndex ?? 0] = true;
        _showRow2nd = true;
      }
    }

    if (mounted) setState(() {});
  }

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
                (win as dynamic).postMessage(p, '*');
              } catch (e) {}
            }
            _postQueue.clear();
          }

          if (_selectedObjectId != null) {
            _postSelectCar(_selectedObjectId!);
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

            if (_selectedObjectId != null) {
              _postSelectCar(_selectedObjectId!);
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
    try {
      if (!_mapReady) {
        _postQueue.add(jsonPayload);
        return;
      }
      if (kIsWeb) {
        final win = (_mapWindowC?.isCompleted == true) ? await _mapWindowC!.future : await _mapWindowC?.future;
        if (win != null) {
          (win as dynamic).postMessage(jsonPayload, '*');
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
    } catch (e) {
      _postQueue.add(jsonPayload);
    }
  }

  void _postMoveCar(String id, double lat, double lng) {
    final payload = jsonEncode({'sender': 'moveCar', 'value': '$id,$lat,$lng;'});
    _sendMessageToMap(payload);
    _maybeCenterOnMove(id, lat, lng);
  }

  void _postSelectCar(int objectId) {
    setState(() {
      _selectedObjectId = objectId;
      _followSelected = true;
    });
    final payload = jsonEncode({'sender': 'selectCar', 'id': objectId});
    _sendMessageToMap(payload);
  }

  void _postCenterTo(double lat, double lng) {
    final payload = jsonEncode({'sender': 'centerMap', 'value': '$lat,$lng'});
    _sendMessageToMap(payload);
  }

  void _maybeCenterOnMove(String id, double lat, double lng) {
    if (!_followSelected) return;
    final selId = _selectedObjectId;
    if (selId == null) return;
    if (int.tryParse(id) != selId) return;

    _centerDebounceTimer?.cancel();
    _centerDebounceTimer = Timer(_kCenterDebounce, () {
      _postCenterTo(lat, lng);
    });
  }

  void _processMessage(Map data) {
    if (!mounted) return;
    if (data['sender'] == 'onClickCar') {
      final id = int.tryParse(data['message'].toString());
      if (id != null) {
        setState(() {
          _selectedObjectId = id;
          _followSelected = true;
        });
      }
    } else if (data['sender'] == 'map_interaction') {
      _followSelected = false;
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

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return MobileTabDashboard(gotoAlarmSet: widget.gotoAlarmSet);
    }
    return Row(
      children: [
        buildRobotListPanel(),
        Expanded(
          child: Column(
            children: [
              GetBuilder<DashboardController>(
                init: DashboardController(),
                builder: (controller) {
                  if (controller.isLoading) {
                    return const Center(
                      child: CupertinoActivityIndicator(radius: 20, color: Colors.grey),
                    );
                  }
                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      if (_showRow1st) buildRow(0),
                      if (_showRow2nd) buildRow(1),
                    ],
                  );
                },
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  color: Colors.transparent,
                  child: _mapView,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildRobotListPanel() {
    return RobotListView(
      onChanged: (Robot selectedRobot) {
        _selectedObjectId = selectedRobot.id ?? -1;
        _followSelected = true;
        if (mounted) setState(() {});
        if (selectedRobot.id != null) {
          _postSelectCar(selectedRobot.id!);
        }
      },
    );
  }

  Widget buildLayout(LayoutSet? layout, int row, int column) {
    if (layout == null || layout.title == null || layout.title!.isEmpty) {
      return Container();
    }
    Widget dashboardWidget;
    if (layout.title == '기기 운행 현황') {
      dashboardWidget = const DeviceStatusWidget();
    } else if (layout.title == '주요 알림') {
      dashboardWidget = AlarmWidget(gotoAlarmSet: widget.gotoAlarmSet);
    } else if (layout.title == '전체 로봇의 누적 주행거리') {
      dashboardWidget = const MovingDistanceWidget();
    } else if (layout.title == '전체 로봇의 누적 운영시간') {
      dashboardWidget = const OperationTimeWidget();
    } else if (layout.title == '전체 로봇의 누적 사용배터리') {
      dashboardWidget = const UsedBatteryWidget();
    } else if (layout.title == '로봇별 일평균 주행거리') {
      dashboardWidget = const MovingDistanceByDayWidget();
    } else if (layout.title == '로봇별 일평균 운영시간') {
      dashboardWidget = const OperationTimeByDayWidget();
    } else if (layout.title == '로봇별 일평균 사용배터리') {
      dashboardWidget = const UsedBatteryByDayWidget();
    } else {
      dashboardWidget = Center(child: Text('Unknown: ${layout.title}'));
    }
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1.0),
      ),
      child: dashboardWidget,
    );
  }

  Widget buildRow(int rowIndex) {
    final layout1 = getLayoutSet(rowIndex, 0);
    final layout2 = getLayoutSet(rowIndex, 1);
    final layout3 = getLayoutSet(rowIndex, 2);

    final isExist2ndColumn = rowIndex == 0 ? _layoutSetRow0[1] : _layoutSetRow1[1];
    final isExist3rdColumn = rowIndex == 0 ? _layoutSetRow0[2] : _layoutSetRow1[2];

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Row(
              children: [
                const SizedBox(width: 2),
                Expanded(child: buildLayout(layout1, rowIndex, 0)),
                if (isExist2ndColumn) const SizedBox(width: 10),
                if (isExist2ndColumn) Expanded(child: buildLayout(layout2, rowIndex, 1)),
                if (isExist3rdColumn) const SizedBox(width: 10),
                if (isExist3rdColumn) Expanded(child: buildLayout(layout3, rowIndex, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LayoutSet? getLayoutSet(int row, int column) {
    final sets = Get.find<DashboardController>().layoutSets;
    for (int i = 0; i < sets.length; i++) {
      final layoutSet = sets[i];
      if (layoutSet.rowIndex == row && layoutSet.columnIndex == column) {
        return layoutSet;
      }
    }
    return null;
  }
}
