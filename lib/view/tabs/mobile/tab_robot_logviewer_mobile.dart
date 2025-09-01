// lib/view/tabs/mobile/tab_robot_log_viewer_mobile.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:fms/constants/constants.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/view/tabs/mobile/components/input_edit_text_logviewer_mobile.dart';
import 'package:fms/viewmodel/controller/log_controller.dart';

class TabRobotLogViewerMobile extends StatefulWidget {
  const TabRobotLogViewerMobile({Key? key}) : super(key: key);

  @override
  State<TabRobotLogViewerMobile> createState() => _TabRobotLogViewerMobileState();
}

class _TabRobotLogViewerMobileState extends State<TabRobotLogViewerMobile> {
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();

  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _startKey = GlobalKey();
  final GlobalKey _endKey = GlobalKey();

  OverlayEntry? _periodOv;
  OverlayEntry? _calendarOv;

  final ScrollController _listCtrl = ScrollController();

  bool _orderAsc = false;
  int _quickIdx = 0;
  bool _filterApplied = false;

  bool _overlayOpen = false;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 1)),
    end: DateTime.now(),
  );

  final _fmt = DateFormat('yyyy-MM-dd');

  // ---- A D A P T I V E  C A L E N D A R  S I Z E S ----
  double _calWidth(BuildContext c) {
    final w = MediaQuery.of(c).size.width;
    if (w <= 340) return 260;
    if (w <= 380) return 280;
    return 320;
  }

  double _calHeight(BuildContext c) {
    final h = MediaQuery.of(c).size.height;
    if (h <= 640) return 280;
    if (h <= 720) return 300;
    return 340;
  }
  // ------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reqLogs();
      setState(() => _filterApplied = true);
    });
  }

  @override
  void dispose() {
    _removePeriodPanel();
    _removeCalendar();
    _searchCtl.dispose();
    _searchFocus.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _reqLogs() => Get.find<LogController>().reqLogList(
        startDate: _fmt.format(_range.start),
        endDate: _fmt.format(_range.end),
        keyword: _searchCtl.text,
      );

  void _removePeriodPanel() {
    _periodOv?.remove();
    _periodOv = null;
    _removeCalendar();
    if (_overlayOpen) setState(() => _overlayOpen = false);
  }

  void _removeCalendar() {
    _calendarOv?.remove();
    _calendarOv = null;
    if (_periodOv == null && _overlayOpen) {
      setState(() => _overlayOpen = false);
    }
  }

  void _togglePeriod() => _periodOv == null ? _showPeriod() : _removePeriodPanel();

  void _showPeriod() {
    _removePeriodPanel();

    const targetW = 374.0;
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final panelW = screenW - 16;
    final width = panelW < targetW ? panelW : targetW;
    final left = ((screenW - width) / 2).clamp(8.0, double.infinity);

    final RenderBox btn = _filterKey.currentContext!.findRenderObject() as RenderBox;
    final top = btn.localToGlobal(Offset.zero).dy + btn.size.height + 8;

    setState(() => _overlayOpen = true);

    _periodOv = OverlayEntry(
      builder: (_) => Stack(
        children: [
          ModalBarrier(
            dismissible: true,
            onDismiss: _removePeriodPanel,
            color: Colors.transparent,
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              elevation: 12,
              clipBehavior: Clip.antiAlias,
              child: _periodPanel(),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_periodOv!);
  }

  Widget _periodPanel() {
    const labels = ['1일', '1주일', '1개월', '직접설정'];
    return StatefulBuilder(
      builder: (_, setPanel) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(labels.length, (i) {
                final sel = _quickIdx == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () {
                        setPanel(() {
                          _quickIdx = i;
                          final now = DateTime.now();
                          if (i == 0) {
                            _range = DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now);
                          } else if (i == 1) {
                            _range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
                          } else if (i == 2) {
                            _range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
                          }
                        });
                      },
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: sel ? const Color(0xFF005FB8) : const Color(0xFFDDDDDD)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 15,
                            color: sel ? const Color(0xFF005FB8) : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: _startKey,
                    onTap: _quickIdx == 3 ? () => _showCal(true) : null,
                    child: _dateBox(_fmt.format(_range.start)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child:
                      Text('~', style: TextStyle(fontFamily: 'pretendard', fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: GestureDetector(
                    key: _endKey,
                    onTap: _quickIdx == 3 ? () => _showCal(false) : null,
                    child: _dateBox(_fmt.format(_range.end)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005FB8),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () {
                      setState(() => _filterApplied = true);
                      _reqLogs();
                      _removePeriodPanel();
                    },
                    child:
                        const Text('확인', style: TextStyle(fontFamily: 'pretendard', fontSize: 14, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () {
                      setState(() {
                        _quickIdx = 0;
                        final now = DateTime.now();
                        _range = DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now);
                        _filterApplied = false;
                      });
                      _removePeriodPanel();
                    },
                    child:
                        const Text('취소', style: TextStyle(fontFamily: 'pretendard', fontSize: 14, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(String t) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(t, style: const TextStyle(fontFamily: 'pretendard', fontSize: 13)),
      );

  Future<void> _scrollToReveal(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.05,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<double> _prepareAnchorAndSpace(bool start) async {
    await _scrollToReveal(start ? _startKey : _endKey);

    // Используем реальную высоту компактного календаря
    final estCalHeight = _calHeight(context) + 16; // +padding
    final mq = MediaQuery.of(context);

    for (int i = 0; i < 3; i++) {
      final rb = (start ? _startKey : _endKey).currentContext!.findRenderObject() as RenderBox;
      final anchorTop = rb.localToGlobal(Offset.zero).dy + rb.size.height + 4;

      final maxBottom = mq.size.height - mq.padding.bottom - mq.viewInsets.bottom - 8;
      final overflow = (anchorTop + estCalHeight) - maxBottom;

      if (!_listCtrl.hasClients || overflow <= 0) {
        return anchorTop;
      }

      final target = (_listCtrl.position.pixels + overflow + 12).clamp(0.0, _listCtrl.position.maxScrollExtent);
      await _listCtrl.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      await WidgetsBinding.instance.endOfFrame;
    }

    final rb = (start ? _startKey : _endKey).currentContext!.findRenderObject() as RenderBox;
    return rb.localToGlobal(Offset.zero).dy + rb.size.height + 4;
  }

  bool _isTinyScreen(BuildContext c) => MediaQuery.of(c).size.width <= 360;

  Future<void> _showCal(bool start) async {
    if (_isTinyScreen(context)) {
      final picked = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) {
          final initial = start ? _range.start : _range.end;

          final calW = _calWidth(ctx);
          final calH = _calHeight(ctx);

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12, top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: calW,
                      height: calH,
                      child: CalendarDatePicker(
                        initialDate: initial,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        onDateChanged: (d) {
                          Navigator.of(ctx).pop(d);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );

      if (picked != null) {
        setState(() {
          _range =
              start ? DateTimeRange(start: picked, end: _range.end) : DateTimeRange(start: _range.start, end: picked);
          _quickIdx = 3;
        });
      }
      return;
    }

    _removeCalendar();

    final anchorTop = await _prepareAnchorAndSpace(start);

    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final maxBottom = mq.size.height - mq.padding.bottom - mq.viewInsets.bottom - 8;

    final horizontalMargin = screenW <= 360 ? 4.0 : 8.0;
    final panelWidth = screenW - horizontalMargin * 2;

    final left = horizontalMargin;
    // учитываем реальную высоту календаря
    final estCalHeight = _calHeight(context) + 16; // +padding
    final top = (anchorTop).clamp(mq.padding.top + 8, maxBottom - estCalHeight);

    if (!_overlayOpen) setState(() => _overlayOpen = true);

    final picker = CalendarDatePicker(
      initialDate: start ? _range.start : _range.end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      onDateChanged: (d) {
        setState(() {
          _range = start ? DateTimeRange(start: d, end: _range.end) : DateTimeRange(start: _range.start, end: d);
          _quickIdx = 3;
        });
        _removeCalendar();
      },
    );

    final calW = _calWidth(context);
    final calH = _calHeight(context);

    _calendarOv = OverlayEntry(
      builder: (_) => Stack(
        children: [
          ModalBarrier(
            dismissible: true,
            onDismiss: _removeCalendar,
            color: Colors.transparent,
          ),
          Positioned(
            left: left,
            top: top,
            child: SizedBox(
              width: panelWidth,
              child: RepaintBoundary(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  elevation: 12,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    // Внутри панели центрируем компактный календарь
                    child: Center(
                      child: SizedBox(
                        width: calW,
                        height: calH,
                        child: FocusScope(canRequestFocus: false, child: picker),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context)!.insert(_calendarOv!);
  }

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          controller: _listCtrl,
          // Lock background scrolling while any overlay is open (iPhone SE fix).
          physics: _overlayOpen
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            const SizedBox(height: 15),
            _topButtons(),
            const SizedBox(height: 12),
            InputEditTextLogViewer(
              controller: _searchCtl,
              focusNode: _searchFocus,
              hintText: '검색',
              onSubmitted: (_) => _reqLogs(),
            ),
            const SizedBox(height: 12),
            _orderPeriodRow(),
            const SizedBox(height: 12),
            _logList(),
            const SizedBox(height: 16),
          ],
        ),
      );

  Widget _topButtons() => Row(
        children: [
          Expanded(
            child: GradientButton(
              buttonText: '전체 선택',
              onTap: () {
                final c = Get.find<LogController>();
                setState(() {
                  c.robotLogs.where((e) => e.id != null).forEach((e) => c.addSelectedId(e.id!));
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GradientButton(
              buttonText: '선택 해제',
              onTap: () {
                final c = Get.find<LogController>();
                setState(() => c.clearSelectedIds());
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GradientButton(
              buttonText: '문서 저장',
              buttonColor: const Color(0xFF005FB8),
              onTap: () => Get.find<LogController>().reqLogListForDocument(),
            ),
          ),
        ],
      );

  Widget _orderPeriodRow() => Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _orderAsc = !_orderAsc),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4)),
                child: const Text('알림 위치 ↑↓', style: TextStyle(fontFamily: 'pretendard', fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              key: _filterKey,
              onTap: _togglePeriod,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('날짜, 시간', style: TextStyle(fontFamily: 'pretendard', fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(CupertinoIcons.line_horizontal_3_decrease, size: 16, color: Color(0xFF666565)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _logList() => GetBuilder<LogController>(
        init: LogController(),
        builder: (c) {
          if (c.isLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 20));
          }
          if (c.robotLogs.isEmpty) {
            return Center(child: Text('조건에 맞는 로그가 없습니다. 😑', style: TextStyle(color: kHintColor, fontSize: 18)));
          }

          final logs = List.from(c.robotLogs)
            ..sort((a, b) {
              final la = a.level ?? '';
              final lb = b.level ?? '';
              final cmp = la.compareTo(lb);
              return _orderAsc ? cmp : -cmp;
            });

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final e = logs[i];
              final sel = c.isSelectedId(e.id ?? -1);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: sel,
                            activeColor: const Color(0xFF005FB8),
                            onChanged: (_) {
                              setState(() {
                                if (e.id != null) {
                                  sel ? c.removeSelectedId(e.id!) : c.addSelectedId(e.id!);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e.level ?? '',
                            style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            e.createdTs ?? '',
                            style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.message ?? '',
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 14,
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              );
            },
          );
        },
      );
}
