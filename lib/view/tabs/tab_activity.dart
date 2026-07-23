import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../../viewmodel/controller/activity_controller.dart';
import '../../viewmodel/controller/live_status_controller.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/repository/activity_repository.dart';
import '../../viewmodel/repository/weather_repository.dart';

part 'tab_activity_charts.dart';
part 'tab_activity_calendar.dart';
part 'tab_activity_helpers.dart';

// ─────────────────────────────────────────────
// 상수 — 라이브 상태 색상
// ─────────────────────────────────────────────
const Color _statusMoving = Color(0xFF16A34A);
const Color _statusIdle = Color(0xFFF59E0B);
const Color _statusOffline = Color(0xFFDC2626);
const Color _statusUnknown = Color(0xFF94A3B8);

// ─────────────────────────────────────────────
// 콘텐츠 영역 색상 팔레트
// ─────────────────────────────────────────────
const Color _bg = Color(0xFFE8EDF4);
const Color _surface = Color(0xFFFCFDFE);
const Color _surfaceAlt = Color(0xFFF2F6FA);
const Color _border = Color(0xFFD9E2EC);
const Color _text = Color(0xFF0D1B2A);
const Color _muted = Color(0xFF607087);
const Color _primary = Color(0xFF1380FF);
const Color _primaryDark = Color(0xFF124F9C);
const Color _primarySoft = Color(0xFFDCEEFF);
const Color _primaryTint = Color(0xFFF2F8FF);
const Color _success = Color(0xFF16A777);
const Color _warning = Color(0xFFFF8C42);
const Color _danger = Color(0xFFF04D5E);
const Color _infra = Color(0xFF0FA89D);

// ─────────────────────────────────────────────
// 다크 사이드바 팔레트
// ─────────────────────────────────────────────
const Color _sidebarBg = Color(0xFFF7FAFD);
const Color _sidebarSurface = Color(0xFFFFFFFF);
const Color _sidebarBorder = Color(0xFFDCE7F3);
const Color _sidebarText = Color(0xFF17324D);
const Color _sidebarMuted = Color(0xFF6E8098);
const Color _sidebarSelected = Color(0xFFEAF3FF);

// ─────────────────────────────────────────────
// 차트 따뜻한 색상 팔레트
// ─────────────────────────────────────────────
const Color _chartOrange = Color(0xFFF97316);
const Color _chartOrangeDark = Color(0xFFEA580C);

class TabActivity extends StatefulWidget {
  const TabActivity({super.key});

  @override
  State<TabActivity> createState() => _TabActivityState();
}

class _TabActivityState extends State<TabActivity>
    with AutomaticKeepAliveClientMixin, _ActivityChartsMixin, _ActivityCalendarMixin {
  ActivityController get _ctrl => Get.find<ActivityController>();

  // 디바이스 이동거리 차트 기간 (일/주/월)
  final ScrollController _distanceChartScrollController = ScrollController();
  // 차량별 거리/운행시간 차트는 서로 다른 스크롤 컨트롤러 사용 (동시 렌더 시 충돌 방지)
  final ScrollController _distanceV3ScrollController = ScrollController();
  final ScrollController _opChartScrollController = ScrollController();
  final ScrollController _objChartScrollController = ScrollController();
  String _deviceDistancePeriod = 'day';
  double peakKm = 0;
  String peakLabel = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _distanceChartScrollController.dispose();
    _distanceV3ScrollController.dispose();
    _opChartScrollController.dispose();
    _objChartScrollController.dispose();
    super.dispose();
  }

  Widget _buildHeaderDeck(ActivityController c) {
    final String fleetLabel = isEnglishLocale
        ? '${c.vehicleCatalog.length} vehicles · ${c.infraCatalog.length} infra · ${c.feedTotal} events'
        : '차량 ${c.vehicleCatalog.length}대 · 인프라 ${c.infraCatalog.length}식 · 이벤트 ${c.feedTotal}건';
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n('활동 분석', 'Activity Analytics'),
                style: const TextStyle(
                  fontFamily: 'gm-medium',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              Text(
                fleetLabel,
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 11,
                  color: _muted,
                ),
              ),
            ],
          ),
          const Spacer(),
          _PeriodChip(
            label: l10n('7일', '7D'),
            selected: c.chartDays_ == 7,
            onTap: () => c.setChartPeriod(7),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: l10n('30일', '30D'),
            selected: c.chartDays_ == 30,
            onTap: () => c.setChartPeriod(30),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: c.refreshAll,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Center(
                child: c.isChartLoading || c.isFeedLoading || c.isCatalogLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: _text, size: 18),
              ),
            ),
          ),
          if (c.unreadCount > 0) ...<Widget>[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: c.markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _warning.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      l10n('모두 읽음', 'Mark all read'),
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarDeck(ActivityController c, LiveStatusController live) {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 사이드바 헤더
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.radar_rounded, color: _primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  l10n('플릿 목록', 'Fleet'),
                  style: const TextStyle(
                    fontFamily: 'gm-medium',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _sidebarText,
                  ),
                ),
                const Spacer(),
                if (c.isCatalogLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: <Widget>[
                _buildSidebarRailSection(
                  c: c,
                  live: live,
                  label: l10n('차량', 'Vehicles'),
                  icon: Icons.directions_car_rounded,
                  accent: _primary,
                  items: c.vehicleCatalog,
                ),
                const SizedBox(height: 12),
                _buildSidebarRailSection(
                  c: c,
                  live: live,
                  label: l10n('인프라', 'Infrastructure'),
                  icon: Icons.cell_tower_rounded,
                  accent: _infra,
                  items: c.infraCatalog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarRailSection({
    required ActivityController c,
    required LiveStatusController live,
    required String label,
    required IconData icon,
    required Color accent,
    required List<ActivityCatalogItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              l10n('등록된 장치가 없습니다.', 'No devices.'),
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 12,
                color: _sidebarMuted,
              ),
            ),
          )
        else
          ...items.map((ActivityCatalogItem item) {
            return _buildSidebarRailTile(
              c: c,
              live: live,
              item: item,
              accent: accent,
            );
          }),
      ],
    );
  }

  Widget _buildSidebarRailTile({
    required ActivityController c,
    required LiveStatusController live,
    required ActivityCatalogItem item,
    required Color accent,
  }) {
    final bool selected =
        c.selectedDeviceType == item.deviceType && c.selectedDeviceId == item.deviceId;
    final Color statusColor = _deviceStatusColor(live, item);
    final String statusLabel = _deviceStatusLabel(live, item);

    return GestureDetector(
      onTap: () => c.selectDevice(item.deviceType, item.deviceId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? _sidebarSelected : _sidebarSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.48) : _sidebarBorder,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12, top: 5),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.42),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'gm-medium',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? accent : _sidebarText,
                          ),
                        ),
                      ),
                      Text(
                        '#${item.deviceId}',
                        style: const TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 10.5,
                          color: _sidebarMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 11.5,
                      color: _sidebarMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _signalBadge(
                        icon: Icons.circle,
                        label: statusLabel,
                        accent: statusColor,
                        dark: true,
                      ),
                      _signalBadge(
                        icon: item.deviceType == 'vehicle'
                            ? Icons.route_rounded
                            : Icons.place_rounded,
                        label: item.location,
                        accent: accent,
                        dark: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _deviceStatusColor(LiveStatusController live, ActivityCatalogItem item) {
    final DeviceStatus status = item.deviceType == 'vehicle'
        ? live.vehicleDeviceStatus(item.deviceId)
        : live.infraDeviceStatus(item.deviceId);
    switch (status) {
      case DeviceStatus.moving:
        return _statusMoving;
      case DeviceStatus.idle:
        return _statusIdle;
      case DeviceStatus.offline:
        return _statusOffline;
      case DeviceStatus.unknown:
        return _statusUnknown;
    }
  }

  String _deviceStatusLabel(LiveStatusController live, ActivityCatalogItem item) {
    final DeviceStatus status = item.deviceType == 'vehicle'
        ? live.vehicleDeviceStatus(item.deviceId)
        : live.infraDeviceStatus(item.deviceId);
    switch (status) {
      case DeviceStatus.moving:
        return item.deviceType == 'infra'
            ? l10n('온라인', 'Online')
            : l10n('이동 중', 'Moving');
      case DeviceStatus.idle:
        return l10n('정지', 'Idle');
      case DeviceStatus.offline:
        return l10n('오프라인', 'Offline');
      case DeviceStatus.unknown:
        return item.deviceType == 'infra'
            ? l10n('인프라', 'Infra')
            : l10n('대기', 'Waiting');
    }
  }

  Widget _signalBadge({
    required IconData icon,
    required String label,
    required Color accent,
    bool dark = false,
  }) {
    final Color bg = dark ? Colors.white.withValues(alpha: 0.76) : accent.withValues(alpha: 0.10);
    final Color border = dark ? accent.withValues(alpha: 0.18) : accent.withValues(alpha: 0.18);
    final Color textColor = dark ? _text : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'pretendard',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    bool dark = false,
  }) {
    final Color titleColor = dark ? _muted : _muted;
    final Color valueColor = dark ? _text : _text;
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.78) : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? accent.withValues(alpha: 0.14) : accent.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'gm-medium',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBodyDeck(ActivityController c) {
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 1080;

        final Widget intro = Container(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
          decoration: _shellPanelDecoration(
            accent: _primary,
            radius: 32,
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -24,
                right: -18,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                bottom: -34,
                left: -12,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _infra.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _signalBadge(
                    icon: Icons.motion_photos_auto_rounded,
                    label: l10n('Ready for selection', 'Ready for selection'),
                    accent: _primary,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF0D1B2A),
                          Color(0xFF155A8E),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.26),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n('Select a unit from the rail', 'Select a unit from the rail'),
                    style: const TextStyle(
                      fontFamily: 'gm-medium',
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _text,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      l10n(
                        'Pick any vehicle or infrastructure node to open live health, motion pattern, weather context, and a readable event timeline in one operational screen.',
                        'Pick any vehicle or infrastructure node to open live health, motion pattern, weather context, and a readable event timeline in one operational screen.',
                      ),
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 13,
                        height: 1.6,
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _signalBadge(
                        icon: Icons.directions_car_filled_rounded,
                        label: '${c.vehicleCatalog.length} vehicles',
                        accent: _primary,
                      ),
                      _signalBadge(
                        icon: Icons.cell_tower_rounded,
                        label: '${c.infraCatalog.length} infra nodes',
                        accent: _infra,
                      ),
                      _signalBadge(
                        icon: Icons.notifications_active_rounded,
                        label: '${c.unreadCount} unread',
                        accent: c.unreadCount > 0 ? _warning : _success,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );

        final Widget metrics = Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _statDeckCard(
                    label: l10n('Fleet inventory', 'Fleet inventory'),
                    value: '${c.vehicleCatalog.length + c.infraCatalog.length}',
                    accent: _primary,
                    icon: Icons.widgets_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _statDeckCard(
                    label: l10n('Global feed', 'Global feed'),
                    value: '${c.feedTotal}',
                    accent: _warning,
                    icon: Icons.auto_graph_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              decoration: _shellPanelDecoration(
                accent: _infra,
                radius: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _infra.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: _infra,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n('What this deck shows', 'What this deck shows'),
                              style: const TextStyle(
                                fontFamily: 'gm-medium',
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n('Operational context, not just raw feed lines',
                                  'Operational context, not just raw feed lines'),
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _deckNarrativePoint(
                    accent: _primary,
                    title: l10n('Live status profile', 'Live status profile'),
                    body: l10n(
                        'Connection state, last activity, object count, coordinates, and live motion summary.',
                        'Connection state, last activity, object count, coordinates, and live motion summary.'),
                  ),
                  const SizedBox(height: 14),
                  _deckNarrativePoint(
                    accent: _warning,
                    title: l10n('Readable timeline', 'Readable timeline'),
                    body: l10n(
                        'Warnings and event types are grouped into cards that are easier to scan than raw backend logs.',
                        'Warnings and event types are grouped into cards that are easier to scan than raw backend logs.'),
                  ),
                  const SizedBox(height: 14),
                  _deckNarrativePoint(
                    accent: _infra,
                    title: l10n('Behavior trend', 'Behavior trend'),
                    body: l10n(
                        'Distance history or event activity chart stays visible next to weather and monthly context.',
                        'Distance history or event activity chart stays visible next to weather and monthly context.'),
                  ),
                ],
              ),
            ),
          ],
        );

        return SingleChildScrollView(
          child: stacked
              ? Column(
                  children: <Widget>[
                    intro,
                    const SizedBox(height: 14),
                    metrics,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: intro),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: metrics),
                  ],
                ),
        );
      },
    );
  }

  Widget _deckNarrativePoint({
    required Color accent,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5, right: 12),
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _text)),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(
                      fontFamily: 'pretendard', fontSize: 11.5, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyDeck(ActivityController c) {
    final bool isVehicle = c.selectedDeviceType == 'vehicle';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 장치 컴팩트 헤더
        _buildCompactHero(c, isVehicle),
        const SizedBox(height: 6),
        // 4개 통계 카드
        _buildStatsGrid(c, isVehicle),
        const SizedBox(height: 6),
        // 차트 + 달력 (스크롤 없이 Expanded로 채움)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _buildActivityChartPanelV3(c, isVehicle),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildAppleCalendarWidgetV2(c),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 장치 선택 후 상단 컴팩트 헤더 (56px 단일 행)
  Widget _buildCompactHero(ActivityController c, bool isVehicle) {
    final Color accent = isVehicle ? _primary : _infra;
    final Color statusColor = c.selectedIsOnline ? _success : _danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isVehicle ? Icons.directions_car_filled_rounded : Icons.cell_tower_rounded,
              color: accent,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            c.selectedDeviceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'gm-medium',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            c.selectedDeviceSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 10,
              color: _muted,
            ),
          ),
          const Spacer(),
          Text(
            c.selectedLocationLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 10,
              color: _muted,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            c.selectedLastSeenLabel,
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 10,
              color: _muted,
            ),
          ),
          const SizedBox(width: 10),
          // 온라인/오프라인 칩
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  c.selectedIsOnline ? l10n('온라인', 'Online') : l10n('오프라인', 'Offline'),
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ActivityController c, bool isVehicle) {
    final VehicleDistanceStat? dist = c.selectedVehicleDistance;
    final double totalKm = dist?.totalKm ?? 0;
    final double totalMovingSec = isVehicle ? _resolveSelectedVehicleMovingTotalSec(c, dist) : 0;
    final double? speed = c.selectedSpeedKph;
    final int objects = c.selectedObjectCount ?? 0;

    final List<Widget> cards = <Widget>[
      _statDeckCard(
        label: isVehicle ? '주행 거리' : '이벤트',
        value: isVehicle ? _formatKm(totalKm) : '${c.selectedEventCount}',
        accent: isVehicle ? _primary : _infra,
        icon: isVehicle ? Icons.route_rounded : Icons.analytics_rounded,
      ),
      _statDeckCard(
        label: isVehicle ? '이동 시간' : '감지 객체',
        value: isVehicle
            ? (totalMovingSec > 0
                ? _formatDurationCompact(totalMovingSec)
                : (c.isOperationStatsLoading ? '--' : '0s'))
            : '$objects',
        accent: isVehicle ? _success : _primaryDark,
        icon: isVehicle ? Icons.schedule_rounded : Icons.hub_rounded,
      ),
      _statDeckCard(
        label: isVehicle ? '현재 속도' : '연결 상태',
        value: isVehicle
            ? (speed != null ? '${speed.toStringAsFixed(0)} km/h' : '--')
            : (c.selectedIsOnline ? '온라인' : '오프라인'),
        accent: c.selectedIsOnline ? _success : _danger,
        icon: isVehicle
            ? Icons.speed_rounded
            : (c.selectedIsOnline ? Icons.wifi_tethering_rounded : Icons.portable_wifi_off_rounded),
      ),
      _statDeckCard(
        label: '경고',
        value: '${c.selectedWarningCount}',
        accent: _warning,
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return Row(
      children: cards.asMap().entries.map((MapEntry<int, Widget> e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < cards.length - 1 ? 10 : 0),
            child: e.value,
          ),
        );
      }).toList(),
    );
  }

  Widget _statDeckCard({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'gm-medium',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) {
        return GetBuilder<ActivityController>(
          init: _ctrl,
          builder: (ActivityController c) {
            return Container(
              color: const Color(0xFFF3F6FA),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // 사이드바: LiveStatusController만 구독 → 차트 GetBuilder를 건드리지 않음
                          GetBuilder<LiveStatusController>(
                            builder: (LiveStatusController live) =>
                                _buildSidebarDeck(c, live),
                          ),
                          const SizedBox(width: 16),
                          // 차트/본문: ActivityController만 구독 → live 타이머에 반응하지 않음
                          Expanded(
                            child: c.selectedDeviceId == null
                                ? _buildEmptyBodyDeck(c)
                                : _buildBodyDeck(c),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
