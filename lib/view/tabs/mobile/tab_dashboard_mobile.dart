// lib/view/tabs/mobile/tab_dashboard_mobile.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../model/dashboard_model.dart';
import '../mobile/dashboard_widgets_mobile/alarm_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/device_status_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/moving_distance_by_day_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/moving_distance_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/operation_time_by_day_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/operation_time_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/used_battery_by_day_widget_mobile.dart';
import '../mobile/dashboard_widgets_mobile/used_battery_widget_mobile.dart';

import '../../../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../../utils/ui_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;
import '../../../viewmodel/controller/dashboard_controller.dart';
import '../../../viewmodel/controller/map_controller.dart';
import '../../../viewmodel/controller/robot_controller.dart';

class MobileTabDashboard extends StatefulWidget {
  const MobileTabDashboard({
    Key? key,
    required this.gotoAlarmSet,
  }) : super(key: key);

  final VoidCallback gotoAlarmSet;

  @override
  State<MobileTabDashboard> createState() => _MobileTabDashboardState();
}

class _MobileTabDashboardState extends State<MobileTabDashboard> {
  //bool _loading = true;
  bool _firstLoad = true;
  bool _mapReady = false;
  final List<String> _postQueue = [];

  late List<LayoutSet> _orderedSets;

  late final Widget _mapView;
  html.IFrameElement? _iframe;
  WebViewController? _wvCtrl;
  StreamSubscription<html.MessageEvent>? _msgSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Future<void> _init() async {
  //   await _loadLayoutSettings();
  //   await _prepareMap();
  //   _dispatchInitialPositions();
  //   if (mounted) setState(() => _loading = false);
  // }

  Future<void> _init() async {
    await _loadLayoutSettings();
    await _prepareMap();
    _dispatchInitialPositions();
    if (mounted) setState(() => _firstLoad = false);
  }

  Future<void> _loadLayoutSettings() async {
    final dc = Get.find<DashboardController>();
    await dc.reqDashboardLayoutSetting();

    _orderedSets = [...dc.layoutSets]..sort((a, b) {
        if (a.rowIndex != b.rowIndex) {
          return (a.rowIndex ?? 0).compareTo(b.rowIndex ?? 0);
        }
        return (a.columnIndex ?? 0).compareTo(b.columnIndex ?? 0);
      });

    if (_orderedSets.isEmpty) {
      _orderedSets = [
        LayoutSet(title: '주요 알림', rowIndex: 0, columnIndex: 0),
        LayoutSet(title: '기기 운행 현황', rowIndex: 1, columnIndex: 0),
        LayoutSet(title: '전체 로봇의 누적 사용배터리', rowIndex: 2, columnIndex: 0),
      ];
    }
  }

  Future<void> _prepareMap() async {
    if (kIsWeb ? _iframe != null : _wvCtrl != null) return;

    final viewId = 'kakao-map-${DateTime.now().millisecondsSinceEpoch}';
    Get.find<DashboardController>().setMapViewId(viewId);
    final url = Get.find<MapController>().mapUri.toString();

    if (kIsWeb) {
      ui.platformViewRegistry.registerViewFactory(viewId, (_) {
        _iframe = html.IFrameElement()
          ..id = viewId
          ..src = url
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';

        _iframe!.onLoad.listen((_) {
          _mapReady = true;
          _flushQueue();
        });

        return _iframe!;
      });

      _mapView = HtmlElementView(viewType: viewId, key: UniqueKey());
      _msgSub = html.window.onMessage.listen((e) => _onMsg(e.data));
    } else {
      _wvCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(onPageFinished: (_) {
            _mapReady = true;
            _flushQueue();
          }),
        )
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: (msg) => _onMsg(jsonDecode(msg.message)),
        )
        ..loadRequest(Uri.parse(url));

      _mapView = WebViewWidget(controller: _wvCtrl!);
    }
  }

  // Future<void> _prepareMap() async {
  //   if (kIsWeb) {
  //     if (_iframe != null) return;
  //   } else {
  //     if (_wvCtrl != null) return;
  //   }
  //   final viewId = 'kakao-map-${DateTime.now().millisecondsSinceEpoch}';
  //   Get.find<DashboardController>().setMapViewId(viewId);
  //   final url = Get.find<MapController>().mapUri.toString();

  //   if (kIsWeb) {
  //     ui.platformViewRegistry.registerViewFactory(viewId, (_) {
  //       _iframe = html.IFrameElement()
  //         ..id = viewId
  //         ..src = url
  //         ..style.border = '0'
  //         ..style.width = '100%'
  //         ..style.height = '100%';
  //       return _iframe!;
  //     });
  //     _mapView = HtmlElementView(viewType: viewId, key: UniqueKey());
  //     _msgSub = html.window.onMessage.listen((e) => _onMsg(e.data));
  //   } else {
  //     _wvCtrl = WebViewController()
  //       ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //       ..addJavaScriptChannel(
  //         'FlutterChannel',
  //         onMessageReceived: (msg) => _onMsg(jsonDecode(msg.message)),
  //       )
  //       ..loadRequest(Uri.parse(url));
  //     _mapView = WebViewWidget(controller: _wvCtrl!);
  //   }
  // }

  void _sendToMap(String payload) {
    if (_mapReady) {
      if (kIsWeb) {
        _iframe?.contentWindow?.postMessage(payload, '*');
      } else {
        final esc = payload.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
        _wvCtrl?.runJavaScript("window.postMessage('$esc','*');");
      }
    } else {
      _postQueue.add(payload);
    }
  }

  void _flushQueue() {
    if (_postQueue.isEmpty) return;
    final copy = List<String>.from(_postQueue);
    _postQueue.clear();
    for (final p in copy) {
      _sendToMap(p);
    }
  }

  void _dispatchInitialPositions() {
    for (final s in Get.find<RobotController>().robotStatusList) {
      if (s.id != null && s.latitude != null && s.longitude != null) {
        _postMoveCar(s.id.toString(), s.latitude!, s.longitude!);
      }
    }
  }

  void _onMsg(dynamic data) {}

  // void _postMoveCar(String id, double lat, double lng) {
  //   final payload = jsonEncode({'sender': 'moveCar', 'value': '$id,$lat,$lng;'});
  //   if (kIsWeb) {
  //     _iframe?.contentWindow?.postMessage(payload, '*');
  //   } else {
  //     _wvCtrl?.runJavaScript("window.dispatchEvent(new MessageEvent('message',{data:'$payload'}));");
  //   }
  // }

  void _postMoveCar(String id, double lat, double lng) {
    _sendToMap(jsonEncode({'sender': 'moveCar', 'value': '$id,$lat,$lng;'}));
  }

  void _refreshMap() {
    final url = Get.find<MapController>().mapUri.toString();
    if (kIsWeb) {
      _iframe?.src = url;
    } else {
      _wvCtrl?.loadRequest(Uri.parse(url));
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLoad) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: _InvisibleRefresh(
          onRefresh: () async {
            await _loadLayoutSettings();
            await Get.find<RobotController>().reqRobotStatusList();
            _dispatchInitialPositions();
          },
          child: ScrollConfiguration(
            behavior: const _NoBounceBehavior(),
            child: RepaintBoundary(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics().applyTo(const AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          for (final set in _orderedSets) ...[
                            ClipRect(
                              child: RepaintBoundary(
                                child: SizedBox(
                                  height: 289,
                                  child: buildLayout(set),
                                ),
                              ),
                            ),
                            const Divider(
                              color: Color(0xFFE8E8E8),
                              thickness: 0.1,
                            ),
                            const SizedBox(height: 12),
                          ],
                          ClipRect(
                            child: RepaintBoundary(
                              child: SizedBox(
                                height: 345,
                                child: _mapView,
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
        ),
      ),
    );
  }

  Widget buildLayout(LayoutSet layout) {
    switch (layout.title) {
      case '기기 운행 현황':
        return const DeviceStatusWidgetMobile();
      case '주요 알림':
        return AlarmWidgetMobile(onViewAll: widget.gotoAlarmSet);
      case '전체 로봇의 누적 주행거리':
        return const MovingDistanceWidgetMobile();
      case '전체 로봇의 누적 운영시간':
        return const OperationTimeWidgetMobile();
      case '전체 로봇의 누적 사용배터리':
      case '전체 로봇의 누적 사용베터리':
        return const UsedBatteryWidgetMobile();
      case '로봇별 일평균 주행거리':
      case '일평균 주행거리':
        return const MovingDistanceByDayWidgetMobile();
      case '로봇별 일평균 운영시간':
      case '일평균 운영시간':
        return const OperationTimeByDayWidgetMobile();
      case '로봇별 일평균 사용배터리':
      case '로봇별 일평균 사용베터리':
      case '일평균 사용배터리':
      case '일평균 사용베터리':
        return const UsedBatteryByDayWidgetMobile();
      default:
        return Center(child: Text('지원 안됨: ${layout.title}'));
    }
  }
}

class _NoBounceBehavior extends ScrollBehavior {
  const _NoBounceBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _InvisibleRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const _InvisibleRefresh({Key? key, required this.onRefresh, required this.child}) : super(key: key);
  @override
  State<_InvisibleRefresh> createState() => _InvisibleRefreshState();
}

class _InvisibleRefreshState extends State<_InvisibleRefresh> {
  bool _refreshing = false;
  double _pull = 0;
  static const double _trigger = 90;

  Future<void> _runRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await widget.onRefresh();
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) {
          _pull = 0;
        } else if (n is ScrollUpdateNotification) {
          if (n.metrics.pixels <= n.metrics.minScrollExtent && (n.scrollDelta ?? 0) < 0) {
            _pull += -(n.scrollDelta ?? 0);
            if (_pull >= _trigger) {
              _pull = 0;
              _runRefresh();
            }
          }
        } else if (n is OverscrollNotification) {
          if (n.overscroll > 0 && n.metrics.pixels <= n.metrics.minScrollExtent + 1) {
            _pull += n.overscroll;
            if (_pull >= _trigger) {
              _pull = 0;
              _runRefresh();
            }
          }
        } else if (n is ScrollEndNotification) {
          _pull = 0;
        }
        return false;
      },
      child: widget.child,
    );
  }
}
