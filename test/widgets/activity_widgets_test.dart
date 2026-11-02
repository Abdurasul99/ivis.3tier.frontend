// test/widgets/activity_widgets_test.dart
// ACTIVITY 영역 위젯 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// tab_activity.dart / tab_activity_charts.dart / tab_activity_calendar.dart 는
// ActivityController, LiveStatusController, VehicleController, InfraController,
// fl_chart, GoogleMap 등 무거운 의존성을 요구하므로 본 테스트는
// 각 UI 요소의 핵심 동작(상태 토글 + 콜백 디스패치) 만을 격리한
// Harness 위젯으로 추출하여 검증한다.
//
// 검증 항목:
//   1. Period Chip (7D / 30D) → chartDays_ 갱신
//   2. Refresh 버튼 → 로딩 콜백 트리거
//   3. Mark All Read 버튼 → unreadCount 0 으로 초기화
//   4. Vehicle / Infra 사이드바 필터 → selectedDeviceType / selectedDeviceId 갱신
//   5. Chart Tab 전환 (운행거리 / 운영시간 / 배터리)
//   6. Distance Chart Period 토글 (daily / weekly / monthly)
//   7. Calendar 날짜 선택 → setDateRange / openDetail
//   8. Vehicle ID 필터 드롭다운
//   9. 검색 필드 텍스트 입력
//  10. Export 버튼 트리거
//  11. History Event 리스트 아이템 클릭 → openDetail
//  12. Pagination 버튼 (prev / next)
//  13. Filter Clear 버튼

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FakeActivityState — Harness 위젯이 공유하는 가벼운 상태 컨테이너
// 실제 ActivityController 를 임포트하지 않고 동일한 필드만 흉내낸다.
// ─────────────────────────────────────────────────────────────────────────────
class FakeActivityState {
  int chartDays = 7;
  bool isChartLoading = false;
  bool isFeedLoading = false;
  bool isCatalogLoading = false;
  int unreadCount = 5;
  String? selectedDeviceType;
  int? selectedDeviceId;
  String distancePeriod = 'daily'; // daily / weekly / monthly
  String chartMetric = 'distance'; // distance / time / battery
  DateTime? selectedCalendarDate;
  String searchText = '';
  int currentPage = 0;
  final List<String> events = <String>[];

  void log(String e) => events.add(e);
}

// ─────────────────────────────────────────────────────────────────────────────
// ActivityHarness — 테스트 격리용 ACTIVITY UI 위젯 모음
// ─────────────────────────────────────────────────────────────────────────────
class ActivityHarness extends StatefulWidget {
  final FakeActivityState state;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> historyItems;
  final void Function(String type, int id)? onOpenDetail;
  final VoidCallback? onExport;
  final VoidCallback? onRefresh;
  final ValueChanged<String>? onSearchChanged;

  const ActivityHarness({
    super.key,
    required this.state,
    this.devices = const <Map<String, dynamic>>[],
    this.historyItems = const <Map<String, dynamic>>[],
    this.onOpenDetail,
    this.onExport,
    this.onRefresh,
    this.onSearchChanged,
  });

  @override
  State<ActivityHarness> createState() => _ActivityHarnessState();
}

class _ActivityHarnessState extends State<ActivityHarness> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.state.searchText);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setChartPeriod(int days) {
    setState(() {
      widget.state.chartDays = days;
      widget.state.log('chartDays:$days');
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      widget.state.isChartLoading = true;
      widget.state.isFeedLoading = true;
      widget.state.isCatalogLoading = true;
      widget.state.log('refresh:start');
    });
    widget.onRefresh?.call();
    // 짧은 비동기 후 로딩 종료
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() {
      widget.state.isChartLoading = false;
      widget.state.isFeedLoading = false;
      widget.state.isCatalogLoading = false;
      widget.state.log('refresh:done');
    });
  }

  void _markAllRead() {
    setState(() {
      widget.state.unreadCount = 0;
      widget.state.log('mark_all_read');
    });
  }

  void _selectDevice(String type, int id) {
    setState(() {
      widget.state.selectedDeviceType = type;
      widget.state.selectedDeviceId = id;
      widget.state.log('select:$type:$id');
    });
  }

  void _clearFilter() {
    setState(() {
      widget.state.selectedDeviceType = null;
      widget.state.selectedDeviceId = null;
      widget.state.searchText = '';
      _searchCtrl.clear();
      widget.state.log('filter:clear');
    });
  }

  void _setDistancePeriod(String period) {
    setState(() {
      widget.state.distancePeriod = period;
      widget.state.log('distance_period:$period');
    });
  }

  void _setChartMetric(String metric) {
    setState(() {
      widget.state.chartMetric = metric;
      widget.state.log('chart_metric:$metric');
    });
  }

  void _onCalendarSelect(DateTime date) {
    setState(() {
      widget.state.selectedCalendarDate = date;
      widget.state.log('calendar:${date.year}-${date.month}-${date.day}');
    });
  }

  void _onPageChange(int delta) {
    setState(() {
      final int next = widget.state.currentPage + delta;
      if (next < 0) return;
      widget.state.currentPage = next;
      widget.state.log('page:$next');
    });
  }

  @override
  Widget build(BuildContext context) {
    final FakeActivityState s = widget.state;

    return Material(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 1) Period Chip (7D / 30D)
            Row(children: <Widget>[
              ChoiceChip(
                key: const Key('chip-7d'),
                label: const Text('7일'),
                selected: s.chartDays == 7,
                onSelected: (_) => _setChartPeriod(7),
              ),
              ChoiceChip(
                key: const Key('chip-30d'),
                label: const Text('30일'),
                selected: s.chartDays == 30,
                onSelected: (_) => _setChartPeriod(30),
              ),
            ]),

            // 2) Refresh + Mark All Read 버튼 영역
            Row(children: <Widget>[
              IconButton(
                key: const Key('refresh-button'),
                icon: const Icon(Icons.refresh),
                onPressed: _onRefresh,
              ),
              TextButton(
                key: const Key('mark-all-read-button'),
                onPressed: s.unreadCount > 0 ? _markAllRead : null,
                child: Text('모두 읽음 (${s.unreadCount})'),
              ),
              if (s.isChartLoading || s.isFeedLoading || s.isCatalogLoading)
                const SizedBox(
                  key: Key('refresh-progress'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ]),

            // 3) 검색 필드
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                key: const Key('search-field'),
                controller: _searchCtrl,
                decoration: const InputDecoration(hintText: '디바이스 검색'),
                onChanged: (String v) {
                  setState(() {
                    s.searchText = v;
                    s.log('search:$v');
                  });
                  widget.onSearchChanged?.call(v);
                },
              ),
            ),

            // 4) Vehicle / Infra Dropdown — Vehicle ID 필터
            DropdownButton<int>(
              key: const Key('vehicle-dropdown'),
              value: s.selectedDeviceType == 'vehicle' ? s.selectedDeviceId : null,
              hint: const Text('차량 선택'),
              items: widget.devices
                  .where((Map<String, dynamic> d) => d['type'] == 'vehicle')
                  .map((Map<String, dynamic> d) => DropdownMenuItem<int>(
                        value: d['id'] as int,
                        child: Text('Vehicle ${d['id']}'),
                      ))
                  .toList(),
              onChanged: (int? id) {
                if (id != null) _selectDevice('vehicle', id);
              },
            ),

            // 5) 사이드바 필터 — Vehicle / Infra 타일
            ...widget.devices.map((Map<String, dynamic> d) {
              final String type = d['type'] as String;
              final int id = d['id'] as int;
              final bool selected =
                  s.selectedDeviceType == type && s.selectedDeviceId == id;
              return ListTile(
                key: Key('device-tile-$type-$id'),
                title: Text('$type-$id'),
                selected: selected,
                onTap: () => _selectDevice(type, id),
              );
            }),

            // 6) Chart Tab 전환 (운행거리 / 운영시간 / 배터리)
            Row(children: <Widget>[
              TextButton(
                key: const Key('tab-distance'),
                onPressed: () => _setChartMetric('distance'),
                child: const Text('운행거리'),
              ),
              TextButton(
                key: const Key('tab-time'),
                onPressed: () => _setChartMetric('time'),
                child: const Text('운영시간'),
              ),
              TextButton(
                key: const Key('tab-battery'),
                onPressed: () => _setChartMetric('battery'),
                child: const Text('배터리'),
              ),
            ]),

            // 7) Distance Chart Period 토글
            Row(children: <Widget>[
              ChoiceChip(
                key: const Key('period-daily'),
                label: const Text('일별'),
                selected: s.distancePeriod == 'daily',
                onSelected: (_) => _setDistancePeriod('daily'),
              ),
              ChoiceChip(
                key: const Key('period-weekly'),
                label: const Text('주별'),
                selected: s.distancePeriod == 'weekly',
                onSelected: (_) => _setDistancePeriod('weekly'),
              ),
              ChoiceChip(
                key: const Key('period-monthly'),
                label: const Text('월별'),
                selected: s.distancePeriod == 'monthly',
                onSelected: (_) => _setDistancePeriod('monthly'),
              ),
            ]),

            // 8) Calendar (간단한 날짜 버튼)
            Row(children: <Widget>[
              for (int day = 1; day <= 3; day++)
                TextButton(
                  key: Key('calendar-day-$day'),
                  onPressed: () => _onCalendarSelect(DateTime(2026, 6, day)),
                  child: Text('$day'),
                ),
              if (s.selectedCalendarDate != null)
                Text(
                  'Selected: ${s.selectedCalendarDate!.day}',
                  key: const Key('calendar-selected-label'),
                ),
            ]),

            // 9) History Event List
            ...widget.historyItems.map((Map<String, dynamic> item) {
              final int id = item['id'] as int;
              return ListTile(
                key: Key('history-item-$id'),
                title: Text(item['title'] as String),
                onTap: () {
                  s.log('open_detail:$id');
                  widget.onOpenDetail?.call(item['type'] as String, id);
                },
              );
            }),

            // 10) Export 버튼
            ElevatedButton(
              key: const Key('export-button'),
              onPressed: () {
                s.log('export');
                widget.onExport?.call();
              },
              child: const Text('내보내기'),
            ),

            // 11) Pagination
            Row(children: <Widget>[
              IconButton(
                key: const Key('page-prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: s.currentPage > 0 ? () => _onPageChange(-1) : null,
              ),
              Text(
                '페이지 ${s.currentPage + 1}',
                key: const Key('page-label'),
              ),
              IconButton(
                key: const Key('page-next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _onPageChange(1),
              ),
            ]),

            // 12) Filter Clear 버튼
            TextButton(
              key: const Key('filter-clear'),
              onPressed: _clearFilter,
              child: const Text('필터 초기화'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 공통 Pump 헬퍼
// ─────────────────────────────────────────────────────────────────────────────
Future<FakeActivityState> _pumpHarness(
  WidgetTester tester, {
  List<Map<String, dynamic>> devices = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> historyItems = const <Map<String, dynamic>>[],
  void Function(String type, int id)? onOpenDetail,
  VoidCallback? onExport,
  VoidCallback? onRefresh,
  ValueChanged<String>? onSearchChanged,
}) async {
  final FakeActivityState state = FakeActivityState();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ActivityHarness(
          state: state,
          devices: devices,
          historyItems: historyItems,
          onOpenDetail: onOpenDetail,
          onExport: onExport,
          onRefresh: onRefresh,
          onSearchChanged: onSearchChanged,
        ),
      ),
    ),
  );
  return state;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // 1) Period Chip (7D / 30D)
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Period Chip (7D / 30D)', () {
    testWidgets('기본값은 7일이 선택되어 있다', (WidgetTester tester) async {
      // Arrange & Act
      final FakeActivityState state = await _pumpHarness(tester);

      // Assert
      expect(state.chartDays, equals(7));
      expect(find.byKey(const Key('chip-7d')), findsOneWidget);
      expect(find.byKey(const Key('chip-30d')), findsOneWidget);
    });

    testWidgets('30일 칩 탭하면 chartDays 가 30 으로 갱신된다',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);

      // Act
      await tester.tap(find.byKey(const Key('chip-30d')));
      await tester.pump();

      // Assert
      expect(state.chartDays, equals(30));
      expect(state.events, contains('chartDays:30'));
    });

    testWidgets('30일 → 7일 토글이 정상 동작한다', (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);
      await tester.tap(find.byKey(const Key('chip-30d')));
      await tester.pump();

      // Act
      await tester.tap(find.byKey(const Key('chip-7d')));
      await tester.pump();

      // Assert
      expect(state.chartDays, equals(7));
      expect(
        state.events,
        containsAllInOrder(<String>['chartDays:30', 'chartDays:7']),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2) Refresh 버튼
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Refresh 버튼', () {
    testWidgets('Refresh 탭하면 로딩 상태가 활성화되었다가 종료된다',
        (WidgetTester tester) async {
      // Arrange
      bool refreshCalled = false;
      final FakeActivityState state = await _pumpHarness(
        tester,
        onRefresh: () => refreshCalled = true,
      );

      // Act
      await tester.tap(find.byKey(const Key('refresh-button')));
      await tester.pump(); // 로딩 시작 프레임

      // Assert — 로딩 인디케이터 표시
      expect(find.byKey(const Key('refresh-progress')), findsOneWidget);
      expect(state.isChartLoading, isTrue);
      expect(state.isFeedLoading, isTrue);
      expect(state.isCatalogLoading, isTrue);
      expect(refreshCalled, isTrue);

      // Settle — 비동기 종료
      await tester.pumpAndSettle();
      expect(state.isChartLoading, isFalse);
      expect(state.isFeedLoading, isFalse);
      expect(state.isCatalogLoading, isFalse);
      expect(state.events, containsAllInOrder(<String>['refresh:start', 'refresh:done']));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3) Mark All Read 버튼
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Mark All Read 버튼', () {
    testWidgets('탭하면 unreadCount 가 0 으로 초기화된다',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);
      expect(state.unreadCount, equals(5));

      // Act
      await tester.tap(find.byKey(const Key('mark-all-read-button')));
      await tester.pump();

      // Assert
      expect(state.unreadCount, equals(0));
      expect(state.events, contains('mark_all_read'));
    });

    testWidgets('unreadCount 가 0 이면 버튼이 비활성화된다',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);
      await tester.tap(find.byKey(const Key('mark-all-read-button')));
      await tester.pump();

      // Act — 다시 탭 시도
      final TextButton btn = tester.widget<TextButton>(
        find.byKey(const Key('mark-all-read-button')),
      );

      // Assert
      expect(btn.onPressed, isNull);
      expect(state.unreadCount, equals(0));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4) Vehicle / Infra 사이드바 필터
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Vehicle / Infra 사이드바 필터', () {
    testWidgets('Vehicle 타일 탭하면 selectedDeviceType / Id 갱신',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(
        tester,
        devices: const <Map<String, dynamic>>[
          <String, dynamic>{'type': 'vehicle', 'id': 1},
          <String, dynamic>{'type': 'infra', 'id': 10},
        ],
      );

      // Act
      await tester.tap(find.byKey(const Key('device-tile-vehicle-1')));
      await tester.pump();

      // Assert
      expect(state.selectedDeviceType, equals('vehicle'));
      expect(state.selectedDeviceId, equals(1));
      expect(state.events, contains('select:vehicle:1'));
    });

    testWidgets('Infra 타일 탭하면 selectedDeviceType=infra 로 전환',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(
        tester,
        devices: const <Map<String, dynamic>>[
          <String, dynamic>{'type': 'vehicle', 'id': 1},
          <String, dynamic>{'type': 'infra', 'id': 10},
        ],
      );

      // Act
      await tester.tap(find.byKey(const Key('device-tile-vehicle-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('device-tile-infra-10')));
      await tester.pump();

      // Assert
      expect(state.selectedDeviceType, equals('infra'));
      expect(state.selectedDeviceId, equals(10));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5) Chart Tab 전환 (운행거리 / 운영시간 / 배터리)
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Chart Metric Tab', () {
    testWidgets('운영시간 탭하면 chartMetric=time', (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);
      expect(state.chartMetric, equals('distance'));

      // Act
      await tester.tap(find.byKey(const Key('tab-time')));
      await tester.pump();

      // Assert
      expect(state.chartMetric, equals('time'));
      expect(state.events, contains('chart_metric:time'));
    });

    testWidgets('배터리 탭하면 chartMetric=battery', (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);

      // Act
      await tester.tap(find.byKey(const Key('tab-battery')));
      await tester.pump();

      // Assert
      expect(state.chartMetric, equals('battery'));
    });

    testWidgets('운행거리 → 운영시간 → 배터리 순으로 전환',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);

      // Act
      await tester.tap(find.byKey(const Key('tab-time')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tab-battery')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tab-distance')));
      await tester.pump();

      // Assert
      expect(state.chartMetric, equals('distance'));
      expect(
        state.events,
        containsAllInOrder(<String>[
          'chart_metric:time',
          'chart_metric:battery',
          'chart_metric:distance',
        ]),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 6) Distance Chart Period 토글 (daily / weekly / monthly)
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Distance Chart Period', () {
    testWidgets('주별 칩 탭하면 distancePeriod=weekly',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);

      // Act
      await tester.tap(find.byKey(const Key('period-weekly')));
      await tester.pump();

      // Assert
      expect(state.distancePeriod, equals('weekly'));
      expect(state.events, contains('distance_period:weekly'));
    });

    testWidgets('월별 칩 탭하면 distancePeriod=monthly',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);

      // Act
      await tester.tap(find.byKey(const Key('period-monthly')));
      await tester.pump();

      // Assert
      expect(state.distancePeriod, equals('monthly'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 7) Calendar 날짜 선택
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Calendar 날짜 선택', () {
    testWidgets('날짜 버튼 탭하면 selectedCalendarDate 갱신',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);
      expect(state.selectedCalendarDate, isNull);

      // Act
      await tester.tap(find.byKey(const Key('calendar-day-2')));
      await tester.pump();

      // Assert
      expect(state.selectedCalendarDate, equals(DateTime(2026, 6, 2)));
      expect(find.byKey(const Key('calendar-selected-label')), findsOneWidget);
      expect(state.events, contains('calendar:2026-6-2'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 8) Vehicle ID 필터 드롭다운
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Vehicle ID 드롭다운', () {
    testWidgets('드롭다운 항목 선택 시 selectedDeviceId 갱신',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(
        tester,
        devices: const <Map<String, dynamic>>[
          <String, dynamic>{'type': 'vehicle', 'id': 1},
          <String, dynamic>{'type': 'vehicle', 'id': 2},
        ],
      );

      // Act — 드롭다운 열기 후 항목 선택
      await tester.tap(find.byKey(const Key('vehicle-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vehicle 2').last);
      await tester.pumpAndSettle();

      // Assert
      expect(state.selectedDeviceType, equals('vehicle'));
      expect(state.selectedDeviceId, equals(2));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 9) 검색 필드 텍스트 입력
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — 검색 필드', () {
    testWidgets('텍스트 입력 시 onSearchChanged 콜백 호출',
        (WidgetTester tester) async {
      // Arrange
      String? captured;
      final FakeActivityState state = await _pumpHarness(
        tester,
        onSearchChanged: (String v) => captured = v,
      );

      // Act
      await tester.enterText(find.byKey(const Key('search-field')), '차량1');
      await tester.pump();

      // Assert
      expect(captured, equals('차량1'));
      expect(state.searchText, equals('차량1'));
      expect(state.events, contains('search:차량1'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 10) Export 버튼
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Export 버튼', () {
    testWidgets('Export 탭하면 onExport 콜백 호출', (WidgetTester tester) async {
      // Arrange
      bool exportCalled = false;
      final FakeActivityState state = await _pumpHarness(
        tester,
        onExport: () => exportCalled = true,
      );

      // Act
      await tester.tap(find.byKey(const Key('export-button')));
      await tester.pump();

      // Assert
      expect(exportCalled, isTrue);
      expect(state.events, contains('export'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 11) History Event 리스트 아이템 클릭
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — History 리스트 아이템', () {
    testWidgets('아이템 탭하면 openDetail 콜백에 id 전달',
        (WidgetTester tester) async {
      // Arrange
      String? capturedType;
      int? capturedId;
      final FakeActivityState state = await _pumpHarness(
        tester,
        historyItems: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 100, 'type': 'vehicle', 'title': '과속 이벤트'},
          <String, dynamic>{'id': 101, 'type': 'infra', 'title': '연결 끊김'},
        ],
        onOpenDetail: (String t, int id) {
          capturedType = t;
          capturedId = id;
        },
      );

      // Act
      await tester.tap(find.byKey(const Key('history-item-100')));
      await tester.pump();

      // Assert
      expect(capturedType, equals('vehicle'));
      expect(capturedId, equals(100));
      expect(state.events, contains('open_detail:100'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 12) Pagination 버튼
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Pagination', () {
    testWidgets('첫 페이지에서는 prev 버튼이 비활성화', (WidgetTester tester) async {
      // Arrange
      await _pumpHarness(tester);

      // Act
      final IconButton prev = tester.widget<IconButton>(
        find.byKey(const Key('page-prev')),
      );

      // Assert
      expect(prev.onPressed, isNull);
    });

    testWidgets('next 탭하면 페이지 인덱스 증가', (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);
      expect(state.currentPage, equals(0));

      // Act
      await tester.tap(find.byKey(const Key('page-next')));
      await tester.pump();

      // Assert
      expect(state.currentPage, equals(1));
      expect(find.text('페이지 2'), findsOneWidget);
      expect(state.events, contains('page:1'));
    });

    testWidgets('next → prev 순으로 이동하면 다시 0 페이지',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(tester);

      // Act
      await tester.tap(find.byKey(const Key('page-next')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('page-prev')));
      await tester.pump();

      // Assert
      expect(state.currentPage, equals(0));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 13) Filter Clear 버튼
  // ───────────────────────────────────────────────────────────────────────────
  group('ACTIVITY — Filter Clear', () {
    testWidgets('필터 초기화 누르면 선택/검색 모두 해제',
        (WidgetTester tester) async {
      // Arrange
      final FakeActivityState state = await _pumpHarness(
        tester,
        devices: const <Map<String, dynamic>>[
          <String, dynamic>{'type': 'vehicle', 'id': 1},
        ],
      );
      await tester.tap(find.byKey(const Key('device-tile-vehicle-1')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('search-field')), '검색어');
      await tester.pump();
      expect(state.selectedDeviceId, equals(1));
      expect(state.searchText, equals('검색어'));

      // Act
      await tester.tap(find.byKey(const Key('filter-clear')));
      await tester.pump();

      // Assert
      expect(state.selectedDeviceType, isNull);
      expect(state.selectedDeviceId, isNull);
      expect(state.searchText, isEmpty);
      expect(state.events, contains('filter:clear'));
    });
  });
}
