part of 'tab_activity.dart';

mixin _ActivityCalendarMixin on State<TabActivity> {
  Widget _buildAppleCalendarWidgetV2(ActivityController c) {
    // 날짜 선택 시 — 캘린더 자리에 인라인 티켓 표시
    if (c.selectedCalendarDate != null) {
      return _buildCalendarDayTicketInline(c);
    }

    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);

    // 이번 달 이벤트가 있는 날 집합
    final int activeDays = c.calendarMonthActiveDaysCount;

    // 오늘 이벤트 (최대 3)
    final List<ActivityEventItem> todayEvents = c.deviceFeedEvents
        .where((ActivityEventItem e) {
          final DateTime t =
              DateTime.fromMillisecondsSinceEpoch(e.occurredAtMs, isUtc: true).toLocal();
          return _isSameLocalDay(t, todayStart);
        })
        .take(3)
        .toList();

    // 최근 이벤트 (오늘 제외, 최대 2)
    final List<ActivityEventItem> recentEvents = c.deviceFeedEvents
        .where((ActivityEventItem e) {
          final DateTime t =
              DateTime.fromMillisecondsSinceEpoch(e.occurredAtMs, isUtc: true).toLocal();
          return !_isSameLocalDay(t, todayStart);
        })
        .take(2)
        .toList();

    final int totalHidden =
        math.max(0, c.deviceFeedEvents.length - todayEvents.length - recentEvents.length);

    final ActivityWeatherSummary? weather = c.selectedWeather;
    final String currentTemp = _weatherTemperatureLabel(weather?.currentTempC);
    final String tempRange = weather?.maxTempC != null || weather?.minTempC != null
        ? '${_weatherTemperatureLabel(weather?.maxTempC)} / ${_weatherTemperatureLabel(weather?.minTempC)}'
        : '--° / --°';
    final String weatherDesc = weather != null
        ? _weatherLabel(weather.weatherCode)
        : c.isWeatherLoading
            ? l10n('동기화 중', 'Syncing...')
            : l10n('날씨 없음', 'No weather');
    final Color weatherAccent = _weatherAccent(weather?.weatherCode);

    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final double activityRatio = daysInMonth > 0 ? activeDays / daysInMonth : 0;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x080F172A), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── 날씨 헤더 ──
            Row(children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: weatherAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_weatherIcon(weather?.weatherCode), color: weatherAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(weatherDesc,
                      style: const TextStyle(
                        fontFamily: 'gm-medium',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      )),
                  Text(c.selectedLocationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 11,
                        color: _muted,
                      )),
                ],
              )),
              if (c.isWeatherLoading)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: _primary),
                )
              else
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                  Text(currentTemp,
                      style: const TextStyle(
                        fontFamily: 'gm-medium',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _text,
                        height: 1.0,
                      )),
                  Text(tempRange,
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 10,
                        color: _muted,
                      )),
                ]),
            ]),

            const SizedBox(height: 14),
            Container(height: 1, color: _border),
            const SizedBox(height: 14),

            // ── 활동 요약 ──
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              // 활동일 / 이벤트 수 나란히
              Row(children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n('활동일', 'Active Days'),
                          style: const TextStyle(
                              fontFamily: 'pretendard', fontSize: 10, color: _primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$activeDays / $daysInMonth',
                          style: const TextStyle(
                            fontFamily: 'gm-medium',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _primary,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n('이번 달 이벤트', 'Month Events'),
                          style: const TextStyle(
                              fontFamily: 'pretendard', fontSize: 10, color: _muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.calendarMonthTotalEvents}',
                          style: const TextStyle(
                            fontFamily: 'gm-medium',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _text,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // 활동률 바
              Row(children: <Widget>[
                Text(
                  l10n('활동률', 'Activity Rate'),
                  style: const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted),
                ),
                const Spacer(),
                Text(
                  '${(activityRatio * 100).round()}%',
                  style: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _primary),
                ),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: activityRatio,
                  minHeight: 5,
                  backgroundColor: _border,
                  valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
            ]),

            const SizedBox(height: 14),
            Container(height: 1, color: _border),
            const SizedBox(height: 14),

            // ── 미니 캘린더 그리드 ──
            _buildMiniCalendarGrid(c, now),

            const SizedBox(height: 14),
            Container(height: 1, color: _border),
            const SizedBox(height: 12),

            // ── 오늘 이벤트 ──
            _buildLightEventSection(
              label: l10n('오늘', 'TODAY'),
              events: todayEvents,
              loading: c.isDeviceFeedLoading,
              emptyLabel: l10n('오늘 기록된 이벤트가 없습니다', 'No events today'),
            ),

            if (recentEvents.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _buildLightEventSection(
                label: l10n('최근', 'RECENT'),
                events: recentEvents,
                loading: false,
                emptyLabel: '',
              ),
            ],

            if (totalHidden > 0) ...<Widget>[
              const SizedBox(height: 8),
              Row(children: <Widget>[
                const Icon(Icons.more_horiz_rounded, size: 14, color: _muted),
                const SizedBox(width: 5),
                Text(
                  isEnglishLocale ? '$totalHidden more events' : '이벤트 $totalHidden건 더 있음',
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 11,
                    color: _muted,
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 12),

            // ── 상태 칩 ──
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              _lightStatusChip(
                icon: c.selectedIsOnline
                    ? Icons.wifi_tethering_rounded
                    : Icons.portable_wifi_off_rounded,
                label: c.selectedIsOnline ? l10n('온라인', 'Online') : l10n('오프라인', 'Offline'),
                accent: c.selectedIsOnline ? _success : _danger,
              ),
              _lightStatusChip(
                icon: Icons.notifications_rounded,
                label: isEnglishLocale
                    ? '${c.calendarMonthTotalEvents} events'
                    : '${c.calendarMonthTotalEvents}건',
                accent: _primary,
              ),
              if (c.selectedWarningCount > 0)
                _lightStatusChip(
                  icon: Icons.warning_amber_rounded,
                  label: isEnglishLocale
                      ? '${c.selectedWarningCount} warn'
                      : '경고 ${c.selectedWarningCount}',
                  accent: _warning,
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── 활동 메트릭 행 ────────────────────────────────
  // ignore: unused_element
  Widget _activityMetricRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted)),
        Text(value,
            style: const TextStyle(
                fontFamily: 'gm-medium', fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
      ],
    );
  }

  // ── 미니 달력 그리드 ──────────────────────────────
  Widget _buildMiniCalendarGrid(ActivityController c, DateTime now) {
    final int firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1=Mon..7=Sun
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final String monthHeader = isEnglishLocale
        ? '${_monthAbbr(now.month).toUpperCase()}  ${now.year}'
        : '${now.year}년 ${now.month}월';
    final int activeDays = c.calendarMonthActiveDaysCount;

    const List<String> weekLabels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final int leadingBlanks = firstWeekday - 1;
    final int totalCells = leadingBlanks + daysInMonth;
    final int rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 월/년 헤더
        Row(children: <Widget>[
          Text(monthHeader,
              style: const TextStyle(
                fontFamily: 'gm-medium',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _text,
                letterSpacing: -0.3,
              )),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n('$activeDays일', '$activeDays d'),
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // 요일 헤더 행
        Row(
            children: weekLabels.map((String d) {
          return Expanded(
            child: Center(
              child: Text(d,
                  style: const TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.5,
                  )),
            ),
          );
        }).toList()),
        const SizedBox(height: 6),
        // 날짜 그리드
        for (int row = 0; row < rows; row++) ...<Widget>[
          Row(
              children: List<Widget>.generate(7, (int col) {
            final int cellIndex = row * 7 + col;
            final int dayNum = cellIndex - leadingBlanks + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 28));
            }
            final DateTime dayDate = DateTime(now.year, now.month, dayNum);
            final int eventCount = c.calendarEventCountForDate(dayDate);
            final bool isToday = dayNum == now.day;
            final bool hasEvents = eventCount > 0;
            final bool isSelected = c.isSelectedCalendarDate(dayDate);
            // 셀 스타일 계산
            final Color cellBg = isSelected
                ? _primary.withValues(alpha: 0.10)
                : isToday
                    ? Colors.white
                    : hasEvents
                        ? _primarySoft.withValues(alpha: 0.55)
                        : Colors.transparent;
            final Border? cellBorder = isToday
                ? Border.all(color: _primary, width: 1.5)
                : isSelected
                    ? Border.all(color: _primary, width: 1.5)
                    : null;
            final Color numColor = isToday || isSelected
                ? _primary
                : hasEvents
                    ? _primaryDark
                    : _text.withValues(alpha: 0.65);
            final FontWeight numWeight = isToday || isSelected
                ? FontWeight.w800
                : hasEvents
                    ? FontWeight.w700
                    : FontWeight.w400;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showCalendarDayTicket(c, dayDate),
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: cellBg,
                    borderRadius: BorderRadius.circular(8),
                    border: cellBorder,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 12,
                          fontWeight: numWeight,
                          color: numColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (hasEvents) ...<Widget>[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected ? _primary : _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          })),
          const SizedBox(height: 2),
        ],
      ],
    );
  }

  // ── 날짜 클릭 → 인라인 티켓으로 전환 ────────────────
  void _showCalendarDayTicket(ActivityController c, DateTime dayDate) {
    unawaited(c.openCalendarDayTicket(dayDate));
    // update()는 openCalendarDayTicket 내부에서 호출되므로
    // GetBuilder가 자동으로 _buildAppleCalendarWidgetV2를 재빌드함
  }

  // ── 인라인 티켓 (캘린더 자리에 표시) ────────────────
  Widget _buildCalendarDayTicketInline(ActivityController c) {
    final DateTime selected = c.selectedCalendarDate ?? DateTime.now();
    final String dateLabel = isEnglishLocale
        ? '${_monthAbbr(selected.month)} ${selected.day}, ${selected.year}'
        : '${selected.year}.${selected.month.toString().padLeft(2, '0')}.${selected.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x080F172A), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: <Widget>[
          // ── 헤더 ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: _primaryTint,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: const Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: <Widget>[
                // 뒤로가기 버튼
                GestureDetector(
                  onTap: c.closeCalendarDayTicket,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: _text, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontFamily: 'gm-medium',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _text,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        c.selectedDeviceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 11,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (c.selectedCalendarDayTotal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${c.selectedCalendarDayTotal}',
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── 이벤트 목록 ──
          Expanded(
            child: c.isCalendarDayLoading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : c.selectedCalendarDayEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _primarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.event_busy_rounded,
                                  color: _primary, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n('이 날 이벤트가 없습니다', 'No events on this day'),
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 13,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: c.selectedCalendarDayEvents
                              .map(
                                (ActivityEventItem event) => _feedTile(
                                  event,
                                  event.isRead ? null : () => c.markRead(event.id),
                                ),
                              )
                              .toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightEventSection({
    required String label,
    required List<ActivityEventItem> events,
    required bool loading,
    required String emptyLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: <Widget>[
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
                color: _primary,
              )),
          const Spacer(),
          if (loading)
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: _primary),
            ),
        ]),
        const SizedBox(height: 8),
        if (events.isEmpty && emptyLabel.isNotEmpty)
          Text(emptyLabel,
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 12,
                color: _muted,
              ))
        else
          ...events.map((ActivityEventItem event) => _buildLightEventRow(event)),
      ],
    );
  }

  Widget _buildLightEventRow(ActivityEventItem event) {
    final Color accent = _severityColor(event.severity);
    final DateTime t =
        DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs, isUtc: true).toLocal();
    final String hhmm =
        '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 4, right: 10),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _text,
                  letterSpacing: -0.1,
                )),
            const SizedBox(height: 1),
            Text(hhmm,
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 10,
                  color: _muted,
                )),
          ],
        )),
      ]),
    );
  }

  // ignore: unused_element
  Widget _lightStatusChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(icon, size: 11, color: accent),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              fontFamily: 'pretendard',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            )),
      ]),
    );
  }

  // ── 인프라별 전체 감지 객체 비교 바차트 ──────────────
  Widget _buildFeed(ActivityController c) {
    final List<ActivityEventItem> events = c.deviceFeedEvents;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: _panel(
        title: l10n('활동 피드', 'Activity Feed'),
        subtitle: l10n('선택한 디바이스의 최신 이벤트', 'Latest events for the selected device'),
        loading: c.isDeviceFeedLoading,
        child: events.isEmpty
            ? SizedBox(
                height: 140,
                child: _emptyPanel(l10n('표시할 디바이스 이벤트가 없습니다.', 'No device events to show.')))
            : Column(
                children: events
                    .map((ActivityEventItem event) =>
                        _feedTile(event, event.isRead ? null : () => c.markRead(event.id)))
                    .toList(),
              ),
      ),
    );
  }


  Widget _feedTile(ActivityEventItem event, VoidCallback? onTap) {
    final Color accent = _severityColor(event.severity);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: event.isRead ? _surfaceAlt : accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: event.isRead ? _border : accent.withValues(alpha: 0.16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_eventIcon(event.eventType), color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(
                      child: Text(event.title,
                          style: const TextStyle(
                              fontFamily: 'gm-medium',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _text)),
                    ),
                    if (!event.isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(l10n('신규', 'NEW'),
                            style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accent)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(event.subtitle.isEmpty ? '-' : event.subtitle,
                      style: const TextStyle(
                          fontFamily: 'pretendard', fontSize: 12, height: 1.45, color: _muted)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                    _miniBadge(_severityLabel(event.severity), accent),
                    _miniBadge(
                        '${_deviceTypeLabel(event.deviceType)} #${event.deviceId}', _primaryDark),
                    _miniBadge(_relativeLabel(event.occurredAtMs), _muted),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: accent == _muted ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'pretendard', fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
    );
  }

}
