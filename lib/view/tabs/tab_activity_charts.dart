part of 'tab_activity.dart';

mixin _ActivityChartsMixin on State<TabActivity> {
  // _TabActivityState가 제공하는 필드에 대한 추상 접근자
  ScrollController get _distanceChartScrollController;
  ScrollController get _distanceV3ScrollController;
  ScrollController get _opChartScrollController;
  ScrollController get _objChartScrollController;

  Widget _buildDistanceBarChartV2(
    List<_DistanceChartPoint> points,
    double maxY, {
    required ScrollController scrollController,
  }) {
    return LayoutBuilder(
      builder: (_, BoxConstraints box) {
        final double viewerWidth = box.maxWidth;
        final double viewHeight = box.maxHeight;
        const double barWidth = 16;
        const double defaultGroupsSpace = 24;

        final double naturalWidth = points.isEmpty
            ? viewerWidth
            : 48 +
                (points.length * barWidth) +
                (math.max(points.length - 1, 0) * defaultGroupsSpace);

        double chartWidth = naturalWidth;
        double groupsSpace = defaultGroupsSpace;
        bool showArrow = false;

        if (points.length <= 1) {
          chartWidth = viewerWidth;
          groupsSpace = 0;
        } else if (naturalWidth <= viewerWidth) {
          chartWidth = viewerWidth;
          final double availableSpace = math.max(0, viewerWidth - 48 - (points.length * barWidth));
          groupsSpace = math.max(12, availableSpace / (points.length + 1));
        } else {
          showArrow = true;
        }

        return Stack(
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollController,
              child: SizedBox(
                width: chartWidth,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.center,
                    minY: 0,
                    maxY: maxY,
                    groupsSpace: groupsSpace,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipRoundedRadius: 4,
                        maxContentWidth: 220,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        fitInsideVertically: true,
                        fitInsideHorizontally: true,
                        tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                        getTooltipColor: (BarChartGroupData _) => const Color(0xFFF8F8FB),
                        direction: TooltipDirection.auto,
                        getTooltipItem: (
                          BarChartGroupData group,
                          int groupIndex,
                          BarChartRodData rod,
                          int rodIndex,
                        ) {
                          final int index = group.x.toInt();
                          if (index < 0 || index >= points.length) return null;
                          final _DistanceChartPoint point = points[index];

                          return BarTooltipItem(
                            '${point.tooltipLabel}\n',
                            const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF407BFF),
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: _formatDistanceMeters(point.meters),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF363636),
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                points[index].axisLabel,
                                style: const TextStyle(
                                  fontFamily: 'light',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(
                      show: false,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        bottom: BorderSide(
                          color: Color(0xFFBDBDBD),
                          width: 1,
                        ),
                      ),
                    ),
                    barGroups: List<BarChartGroupData>.generate(
                      points.length,
                      (int index) {
                        final _DistanceChartPoint point = points[index];
                        return BarChartGroupData(
                          x: index,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: point.km,
                              width: barWidth,
                              color: point.meters > 0
                                  ? const Color(0xFF005FB8)
                                  : const Color(0xFFDCE7F3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (showArrow)
              Positioned(
                left: 0,
                top: math.max(0, (viewHeight - 25) / 2),
                child: _buildDistanceChartArrowV2(
                  assetPath: 'assets/images/icons_left.svg',
                  onTap: () => _animateChartScroll(scrollController, -200),
                ),
              ),
            if (showArrow)
              Positioned(
                right: 0,
                top: math.max(0, (viewHeight - 25) / 2),
                child: _buildDistanceChartArrowV2(
                  assetPath: 'assets/images/icons_right.svg',
                  onTap: () => _animateChartScroll(scrollController, 200),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDistancePeriodSelectorV2(ActivityController c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              _resetDistanceChartScrollV2();
              unawaited(c.setSelectedDeviceDistanceChartPeriod('daily'));
            },
            child: _buildDistancePeriodButtonV2(c, l10n('일', 'D'), 'daily'),
          ),
          GestureDetector(
            onTap: () {
              _resetDistanceChartScrollV2();
              unawaited(c.setSelectedDeviceDistanceChartPeriod('weekly'));
            },
            child: _buildDistancePeriodButtonV2(c, l10n('주', 'W'), 'weekly'),
          ),
          GestureDetector(
            onTap: () {
              _resetDistanceChartScrollV2();
              unawaited(c.setSelectedDeviceDistanceChartPeriod('monthly'));
            },
            child: _buildDistancePeriodButtonV2(c, l10n('월', 'M'), 'monthly'),
          ),
          GestureDetector(
            onTap: () {
              _resetDistanceChartScrollV2();
              unawaited(c.setSelectedDeviceDistanceChartPeriod('yearly'));
            },
            child: _buildDistancePeriodButtonV2(c, l10n('년', 'Y'), 'yearly'),
          ),
        ],
      ),
    );
  }

  Widget _buildDistancePeriodButtonV2(
    ActivityController c,
    String title,
    String period,
  ) {
    final bool isSelected = c.selectedDeviceDistanceChartPeriod == period;

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            isSelected ? const Color(0xFF146CBE) : Colors.transparent,
            isSelected ? const Color(0xFF0641C9) : Colors.transparent,
          ],
        ),
      ),
      margin: const EdgeInsets.all(2),
      child: Container(
        width: 31,
        height: 31,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005FB8) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  // ── 운행시간 차트 전용 기간 선택기 ──
  Widget _buildOperationPeriodSelectorV2(ActivityController c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () => unawaited(c.setSelectedOperationChartPeriod('daily')),
            child: _buildOperationPeriodButtonV2(c, l10n('일', 'D'), 'daily'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedOperationChartPeriod('weekly')),
            child: _buildOperationPeriodButtonV2(c, l10n('주', 'W'), 'weekly'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedOperationChartPeriod('monthly')),
            child: _buildOperationPeriodButtonV2(c, l10n('월', 'M'), 'monthly'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedOperationChartPeriod('yearly')),
            child: _buildOperationPeriodButtonV2(c, l10n('년', 'Y'), 'yearly'),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationPeriodButtonV2(ActivityController c, String title, String period) {
    final bool isSelected = c.selectedOperationChartPeriod == period;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            isSelected ? const Color(0xFF146CBE) : Colors.transparent,
            isSelected ? const Color(0xFF0641C9) : Colors.transparent,
          ],
        ),
      ),
      margin: const EdgeInsets.all(2),
      child: Container(
        width: 31,
        height: 31,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005FB8) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  // ── 인프라 감지 객체 차트 전용 기간 선택기 ──
  Widget _buildInfraObjectPeriodSelector(ActivityController c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () => unawaited(c.setSelectedInfraObjectChartPeriod('daily')),
            child: _buildInfraObjectPeriodButton(c, l10n('일', 'D'), 'daily'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedInfraObjectChartPeriod('weekly')),
            child: _buildInfraObjectPeriodButton(c, l10n('주', 'W'), 'weekly'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedInfraObjectChartPeriod('monthly')),
            child: _buildInfraObjectPeriodButton(c, l10n('월', 'M'), 'monthly'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedInfraObjectChartPeriod('yearly')),
            child: _buildInfraObjectPeriodButton(c, l10n('년', 'Y'), 'yearly'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfraObjectPeriodButton(ActivityController c, String title, String period) {
    final bool isSelected = c.selectedInfraObjectChartPeriod == period;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isSelected ? _infra : Colors.transparent,
      ),
      margin: const EdgeInsets.all(2),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  // 차량 일별 감지 객체 패널
  Widget _buildVehicleObjectsPanel(ActivityController c) {
    final List<Map<String, dynamic>> raw = c.vehicleDailyObjectCounts;
    final int totalObjects = raw.fold<int>(
        0, (int s, Map<String, dynamic> r) => s + ((r['total_objects'] as num?)?.toInt() ?? 0));
    final bool hasData = raw.isNotEmpty && totalObjects > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBDBDB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.14),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.radar_rounded, size: 14, color: _warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n('일별 감지 객체', 'Daily Detected Objects'),
                      style: const TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          hasData ? totalObjects.toString() : '--',
                          style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 20,
                              color: _text,
                              fontWeight: FontWeight.w700,
                              height: 1.1),
                        ),
                        if (hasData) ...<Widget>[
                          const SizedBox(width: 4),
                          Text(
                            l10n('개', 'objs'),
                            style: const TextStyle(
                                fontFamily: 'pretendard', fontSize: 11, color: _muted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildVehicleObjectPeriodSelector(c),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: c.isVehicleObjectChartLoading
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _warning)))
                : !hasData
                    ? SizedBox(
                        height: 80,
                        child: _emptyPanel(l10n('감지된 객체 데이터가 없습니다.', 'No detected object data')))
                    : _buildVehicleObjectAggregatedChart(c),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleObjectPeriodSelector(ActivityController c) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () => unawaited(c.setSelectedVehicleObjectChartPeriod('daily')),
            child: _buildVehicleObjectPeriodButton(c, l10n('일', 'D'), 'daily'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedVehicleObjectChartPeriod('weekly')),
            child: _buildVehicleObjectPeriodButton(c, l10n('주', 'W'), 'weekly'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedVehicleObjectChartPeriod('monthly')),
            child: _buildVehicleObjectPeriodButton(c, l10n('월', 'M'), 'monthly'),
          ),
          GestureDetector(
            onTap: () => unawaited(c.setSelectedVehicleObjectChartPeriod('yearly')),
            child: _buildVehicleObjectPeriodButton(c, l10n('년', 'Y'), 'yearly'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleObjectPeriodButton(ActivityController c, String title, String period) {
    final bool isSelected = c.selectedVehicleObjectChartPeriod == period;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isSelected ? _warning : Colors.transparent,
      ),
      margin: const EdgeInsets.all(2),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildVehicleObjectAggregatedChart(ActivityController c) {
    final List<Map<String, dynamic>> raw = c.vehicleDailyObjectCounts;
    if (raw.isEmpty) {
      return _emptyPanel(l10n('감지된 객체 데이터가 없습니다.', 'No detected object data available.'));
    }

    final String period = c.selectedVehicleObjectChartPeriod;
    // 인프라 집계 함수와 포맷이 동일 { date_kst, total_objects }
    final List<(String, int)> points = _aggregateInfraObjectPoints(raw, period);

    if (points.every(((String, int) p) => p.$2 == 0)) {
      return _emptyPanel(l10n('감지된 객체 데이터가 없습니다.', 'No detected object data available.'));
    }

    final double maxY = _maxY(points.map(((String, int) p) => p.$2.toDouble()).toList());

    return LayoutBuilder(builder: (_, BoxConstraints box) {
      final double barW = points.length > 14 ? 10 : 16;
      // 막대당 슬롯 폭 확보: 모든 일자 라벨(06/08 ≈ 30px)이 겹치지 않게
      final double minW = points.length * (barW + 26) + 40.0;
      final double w = math.max(box.maxWidth, minW);
      // 자연 폭이 화면보다 크면 좌우 스크롤 화살표 표시
      final bool showArrow = minW > box.maxWidth;
      final double viewHeight = box.maxHeight;
      return Stack(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _objChartScrollController,
            child: SizedBox(
              width: w,
              child: BarChart(BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List<BarChartGroupData>.generate(
                  points.length,
                  (int i) => BarChartGroupData(
                    x: i,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: points[i].$2.toDouble(),
                        width: barW,
                        color: points[i].$2 > 0 ? _warning : _border,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: _axisInterval(maxY),
                      getTitlesWidget: (double v, TitleMeta _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontFamily: 'pretendard', fontSize: 9, color: _muted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (double v, TitleMeta _) {
                        final int i = v.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        // 모든 일자 라벨 표시 — 일/주/월 피커에서 날짜 누락 없이 전부 노출
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            points[i].$1,
                            style: const TextStyle(
                                fontFamily: 'pretendard', fontSize: 9, color: _muted),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    // 툴팁이 차트 경계 밖으로 넘치지 않도록 안쪽에 고정
                    fitInsideVertically: true,
                    fitInsideHorizontally: true,
                    getTooltipColor: (_) => _warning,
                    getTooltipItem:
                        (BarChartGroupData group, int gi, BarChartRodData rod, int ri) {
                      final int i = group.x;
                      if (i < 0 || i >= points.length) return null;
                      return BarTooltipItem(
                        '${points[i].$1}\n${points[i].$2}개',
                        const TextStyle(
                            color: Colors.white, fontSize: 10, fontFamily: 'pretendard'),
                      );
                    },
                  ),
                ),
              )),
            ),
          ),
          if (showArrow)
            Positioned(
              left: 0,
              top: math.max(0, (viewHeight - 28) / 2),
              child: _buildDistanceChartArrowV2(
                assetPath: 'assets/images/icons_left.svg',
                onTap: () => _animateChartScroll(_objChartScrollController, -200),
              ),
            ),
          if (showArrow)
            Positioned(
              right: 0,
              top: math.max(0, (viewHeight - 28) / 2),
              child: _buildDistanceChartArrowV2(
                assetPath: 'assets/images/icons_right.svg',
                onTap: () => _animateChartScroll(_objChartScrollController, 200),
              ),
            ),
        ],
      );
    });
  }

  // ── 인프라 감지 객체 집계 차트 (기간별) ──
  Widget _buildInfraObjectAggregatedChart(ActivityController c) {
    final List<Map<String, dynamic>> raw = c.infraDailyObjectCounts;
    if (raw.isEmpty) {
      return _emptyPanel(l10n('감지된 객체 데이터가 없습니다.', 'No detected object data available.'));
    }

    final String period = c.selectedInfraObjectChartPeriod;
    final List<(String, int)> points = _aggregateInfraObjectPoints(raw, period);

    if (points.every(((String, int) p) => p.$2 == 0)) {
      return _emptyPanel(l10n('감지된 객체 데이터가 없습니다.', 'No detected object data available.'));
    }

    final double maxY = _maxY(points.map(((String, int) p) => p.$2.toDouble()).toList());

    return LayoutBuilder(builder: (_, BoxConstraints box) {
      final double barW = points.length > 14 ? 10 : 16;
      // 막대당 슬롯 폭 확보: 모든 일자 라벨(06/08 ≈ 30px)이 겹치지 않게
      final double minW = points.length * (barW + 26) + 40.0;
      final double w = math.max(box.maxWidth, minW);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: BarChart(BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List<BarChartGroupData>.generate(
              points.length,
              (int i) => BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: points[i].$2.toDouble(),
                    width: barW,
                    color: points[i].$2 > 0 ? _infra : _border,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: _axisInterval(maxY),
                  getTitlesWidget: (double v, TitleMeta _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontFamily: 'pretendard', fontSize: 9, color: _muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (double v, TitleMeta _) {
                    final int i = v.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox.shrink();
                    // 모든 일자 라벨 표시 — 일/주/월 피커에서 날짜 누락 없이 전부 노출
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        points[i].$1,
                        style: const TextStyle(
                            fontFamily: 'pretendard', fontSize: 9, color: _muted),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideVertically: true,
                fitInsideHorizontally: true,
                getTooltipColor: (_) => _infra,
                getTooltipItem: (BarChartGroupData group, int gi, BarChartRodData rod, int ri) {
                  final int i = group.x;
                  if (i < 0 || i >= points.length) return null;
                  return BarTooltipItem(
                    '${points[i].$1}\n${points[i].$2}개',
                    const TextStyle(
                        color: Colors.white, fontSize: 10, fontFamily: 'pretendard'),
                  );
                },
              ),
            ),
          )),
        ),
      );
    });
  }

  Widget _buildDistanceChartArrowV2({
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 28,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: SvgPicture.asset(
          assetPath,
          width: 12,
          height: 20,
        ),
      ),
    );
  }

  void _resetDistanceChartScrollV2() {
    if (_distanceV3ScrollController.hasClients) {
      _distanceV3ScrollController.jumpTo(0);
    }
    if (_opChartScrollController.hasClients) {
      _opChartScrollController.jumpTo(0);
    }
  }

  void _animateChartScroll(ScrollController controller, double delta) {
    if (!controller.hasClients) return;

    final ScrollPosition position = controller.position;
    final double target = (controller.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildActivityChartPanelV3(ActivityController c, bool isVehicle) {
    if (!isVehicle) {
      // ── 인프라: 선택 인프라 시간별 차트 (상단) + 인프라 비교 차트 (하단) ──
      final int? selectedId = c.selectedDeviceId;
      return Column(
        children: <Widget>[
          // ── 상단: 선택된 인프라 시간별 감지 객체 차트 ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBDBDB)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.14),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _infra.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.sensors_rounded, size: 14, color: _infra),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              selectedId != null
                                  ? l10n('Infra $selectedId 감지 객체', 'Infra $selectedId Objects')
                                  : l10n('감지 객체 추이', 'Detected Objects'),
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 11,
                                color: _muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // 총 합계 표시
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: <Widget>[
                                Text(
                                  c.infraDailyObjectCounts.fold<int>(
                                    0,
                                    (int s, Map<String, dynamic> r) =>
                                        s + ((r['total_objects'] as num?)?.toInt() ?? 0),
                                  ).toString(),
                                  style: const TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 20,
                                    color: _text,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n('개', 'objs'),
                                  style: const TextStyle(
                                    fontFamily: 'pretendard',
                                    fontSize: 11,
                                    color: _muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildInfraObjectPeriodSelector(c),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: c.isInfraObjectChartLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _infra),
                            ),
                          )
                        : _buildInfraObjectAggregatedChart(c),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // ── 하단: 인프라별 전체 감지 객체 비교 차트 ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBDBDB)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.14),
                    offset: const Offset(2, 0),
                    blurRadius: 6,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _infra.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.bar_chart_rounded, size: 14, color: _infra),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n('인프라별 감지 객체 합계', 'Objects Per Infra'),
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 11,
                                color: _muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l10n('최근 ${c.chartDays_}일 비교', 'Last ${c.chartDays_}d comparison'),
                              style: const TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 13,
                                color: _text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c.isInfraTotalChartLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _infra),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: c.isInfraTotalChartLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _infra),
                            ),
                          )
                        : _buildInfraTotalObjectsChart(c),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── 차량: 주행거리 차트 (위) + 운행시간 차트 (아래) ──
    final VehicleDistanceStat? chartDistance =
        c.selectedVehicleDistanceChart ?? c.selectedVehicleDistance;
    final List<DailyDistancePoint> daily = chartDistance?.daily ?? <DailyDistancePoint>[];
    // points에 distanceKm + operationHours + movingHours 모두 포함 (거리 차트용)
    final List<_VehicleMetricChartPointV3> points =
        _aggregateVehicleChartPointsV3(daily, c.selectedDeviceDistanceChartPeriod);
    // 운행시간 차트용: 동일 daily 데이터를 운행시간 기간으로 재집계
    final List<_VehicleMetricChartPointV3> opPointsFromDist =
        _aggregateVehicleChartPointsV3(daily, c.selectedOperationChartPeriod);
    final List<_VehicleMetricChartPointV3> fallbackOpPoints = _aggregateVehicleChartPointsV3(
      _legacyOperationDailyToDistancePoints(c.vehicleDailyOperationStats),
      c.selectedOperationChartPeriod,
    );

    // 거리 차트
    final bool hasDistData = points.any((p) => p.distanceM > 0);
    final double distMaxY = _maxY(points.map((p) => p.distanceKm).toList());
    final double totalDistanceM = chartDistance?.totalM ?? 0;
    final ({String value, String unit}) distParts = _distanceDisplayParts(totalDistanceM);

    // 운행시간: distanceStats daily의 operationSec/movingSec 활용 (getRuntimeStats 기반)
    final bool hasRuntimeOpData = opPointsFromDist.any((p) => p.movingSec > 0);
    final List<_VehicleMetricChartPointV3> opPoints = hasRuntimeOpData ? opPointsFromDist : fallbackOpPoints;
    final bool hasOpData = opPoints.any((p) => p.movingSec > 0);
    final double opMaxY = _maxY(opPoints.map((p) => p.movingHours).toList());
    final double totalMoveSec = hasRuntimeOpData
        ? (chartDistance?.totalMovingSec ?? 0)
        : opPoints.fold<double>(
            0,
            (double sum, _VehicleMetricChartPointV3 point) => sum + point.movingSec,
          );
    // ── 거리 차트 패널 ──
    final Widget distPanel = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBDBDB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.18),
            offset: const Offset(2, 0),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.route_rounded, size: 14, color: _primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '누적 주행 거리',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          distParts.value,
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 20,
                            color: _text,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distParts.unit,
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 11,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildDistancePeriodSelectorV2(c),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: c.isDeviceDistanceChartLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    ),
                  )
                : !hasDistData
                    ? SizedBox(height: 80, child: _emptyPanel('이동 거리 이력 없음'))
                    : _buildVehicleChartBarChartV3(
                        points: points,
                        maxY: distMaxY,
                        showTimeMetric: false,
                        scrollController: _distanceV3ScrollController,
                      ),
          ),
        ],
      ),
    );

    // ── 운행시간 차트 패널 ──
    final double totalOpMin = totalMoveSec / 60;
    final String opTotalLabel = totalOpMin >= 60
        ? '${(totalOpMin / 60).toStringAsFixed(1)} h'
        : '${totalOpMin.toStringAsFixed(0)} min';

    final Widget opPanel = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBDBDB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.14),
            offset: const Offset(2, 0),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.timer_rounded, size: 14, color: _success),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '일별 이동 시간',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          hasOpData ? opTotalLabel : '--',
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 20,
                            color: _text,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        if (hasOpData) ...<Widget>[
                          const SizedBox(width: 4),
                          const Text(
                            '총 이동',
                            style: TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 11,
                              color: _muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 운행시간 차트 전용 기간 선택기
              _buildOperationPeriodSelectorV2(c),
              if (c.isOperationStatsLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _success),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: !hasOpData
                ? SizedBox(height: 80, child: _emptyPanel('이동 기록 없음'))
                : _buildVehicleChartBarChartV3(
                    points: opPoints,
                    maxY: opMaxY,
                    showTimeMetric: true,
                    scrollController: _opChartScrollController,
                  ),
          ),
        ],
      ),
    );

    return Column(
      children: <Widget>[
        Expanded(child: distPanel),
        const SizedBox(height: 6),
        Expanded(child: opPanel),
        const SizedBox(height: 6),
        // ── 차량 감지 객체 패널 ──
        Expanded(child: _buildVehicleObjectsPanel(c)),
      ],
    );
  }

  Widget _buildVehicleChartBarChartV3({
    required List<_VehicleMetricChartPointV3> points,
    required double maxY,
    required bool showTimeMetric,
    required ScrollController scrollController,
  }) {
    return LayoutBuilder(
      builder: (_, BoxConstraints box) {
        final double viewerWidth = box.maxWidth;
        final double viewHeight = box.maxHeight;
        const double barWidth = 14;
        const double defaultGroupsSpace = 18;

        final double naturalWidth = points.isEmpty
            ? viewerWidth
            : 48 +
                (points.length * barWidth) +
                (math.max(points.length - 1, 0) * defaultGroupsSpace);

        double chartWidth = naturalWidth;
        double groupsSpace = defaultGroupsSpace;
        bool showArrow = false;

        if (points.length <= 1) {
          chartWidth = viewerWidth;
          groupsSpace = 0;
        } else if (naturalWidth <= viewerWidth) {
          chartWidth = viewerWidth;
          final double availableSpace = math.max(0, viewerWidth - 48 - (points.length * barWidth));
          groupsSpace = math.max(10, availableSpace / (points.length + 1));
        } else {
          showArrow = true;
        }

        return Stack(
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollController,
              child: SizedBox(
                width: chartWidth,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.center,
                    minY: 0,
                    maxY: maxY,
                    groupsSpace: groupsSpace,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipRoundedRadius: 4,
                        maxContentWidth: 220,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        fitInsideVertically: true,
                        fitInsideHorizontally: true,
                        tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                        getTooltipColor: (BarChartGroupData _) => const Color(0xFFF8F8FB),
                        direction: TooltipDirection.auto,
                        getTooltipItem: (
                          BarChartGroupData group,
                          int groupIndex,
                          BarChartRodData rod,
                          int rodIndex,
                        ) {
                          final int index = group.x.toInt();
                          if (index < 0 || index >= points.length) return null;
                          final _VehicleMetricChartPointV3 point = points[index];

                          return BarTooltipItem(
                            '${point.tooltipLabel}\n',
                            const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF407BFF),
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                            children: showTimeMetric
                                ? <TextSpan>[
                                    TextSpan(
                                      text:
                                          "${l10n('이동', 'Moving')} ${_formatDurationCompact(point.movingSec)}\n",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF16A777),
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          "${l10n('공회전', 'Idle')} ${_formatDurationCompact(math.max(0, point.operationSec - point.movingSec))}\n",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF607087),
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          "${l10n('거리', 'Distance')} ${_formatDistanceMeters(point.distanceM)}",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF363636),
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ]
                                : <TextSpan>[
                                    TextSpan(
                                      text: '${_formatDistanceMeters(point.distanceM)}\n',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF363636),
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          "${l10n('이동', 'Moving')} ${_formatDurationCompact(point.movingSec)}",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF607087),
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                points[index].axisLabel,
                                style: const TextStyle(
                                  fontFamily: 'light',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(
                      show: false,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        bottom: BorderSide(
                          color: Color(0xFFBDBDBD),
                          width: 1,
                        ),
                      ),
                    ),
                    barGroups: List<BarChartGroupData>.generate(
                      points.length,
                      (int index) {
                        final _VehicleMetricChartPointV3 point = points[index];
                        return BarChartGroupData(
                          x: index,
                          barRods: <BarChartRodData>[
                            BarChartRodData(
                              toY: showTimeMetric ? point.movingHours : point.distanceKm,
                              width: barWidth,
                              color: showTimeMetric
                                  ? _primary
                                  : point.distanceM > 0
                                      ? const Color(0xFF005FB8)
                                      : const Color(0xFFDCE7F3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              rodStackItems: const <BarChartRodStackItem>[],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (showArrow)
              Positioned(
                left: 0,
                top: math.max(0, (viewHeight - 25) / 2),
                child: _buildDistanceChartArrowV2(
                  assetPath: 'assets/images/icons_left.svg',
                  onTap: () => _animateChartScroll(scrollController, -200),
                ),
              ),
            if (showArrow)
              Positioned(
                right: 0,
                top: math.max(0, (viewHeight - 25) / 2),
                child: _buildDistanceChartArrowV2(
                  assetPath: 'assets/images/icons_right.svg',
                  onTap: () => _animateChartScroll(scrollController, 200),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleChartMetricSelectorV3(ActivityController c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              _resetDistanceChartScrollV2();
              c.setSelectedVehicleChartMetric('distance');
            },
            child: _buildVehicleChartMetricButtonV3(
              title: 'Distance',
              selected: c.selectedVehicleChartMetric == 'distance',
            ),
          ),
          GestureDetector(
            onTap: () {
              _resetDistanceChartScrollV2();
              c.setSelectedVehicleChartMetric('time');
            },
            child: _buildVehicleChartMetricButtonV3(
              title: 'Time',
              selected: c.selectedVehicleChartMetric == 'time',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleChartMetricButtonV3({
    required String title,
    required bool selected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF005FB8) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  BoxDecoration _shellPanelDecoration({
    required Color accent,
    bool dark = false,
    double radius = 28,
  }) {
    final List<Color> gradientColors = dark
        ? <Color>[
            Colors.white,
            accent.withValues(alpha: 0.06),
            _primaryTint,
          ]
        : <Color>[
            Colors.white,
            accent.withValues(alpha: 0.08),
            _surfaceAlt,
          ];

    return BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: dark ? accent.withValues(alpha: 0.12) : accent.withValues(alpha: 0.14),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: accent.withValues(alpha: dark ? 0.08 : 0.08),
          blurRadius: dark ? 18 : 24,
          offset: const Offset(0, 8),
        ),
        const BoxShadow(
          color: Color(0x12091A2B),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildInfraTotalObjectsChart(ActivityController c) {
    final List<Map<String, dynamic>> raw = c.infraTotalByInfra;
    final int? selectedId = c.selectedDeviceId;

    if (raw.isEmpty) {
      return SizedBox(
        height: 160,
        child: _emptyPanel(
          l10n('감지된 객체 데이터가 없습니다.', 'No detected object data available.'),
        ),
      );
    }

    // infra_id별 total_objects 목록
    final List<(int, int)> points = raw.map((Map<String, dynamic> row) {
      final int id = (row['infra_id'] as num?)?.toInt() ?? 0;
      final int total = (row['total_objects'] as num?)?.toInt() ?? 0;
      return (id, total);
    }).toList();

    final double maxY = _maxY(points.map(((int, int) p) => p.$2.toDouble()).toList());

    return LayoutBuilder(builder: (_, BoxConstraints box) {
      final double barW = points.length > 10 ? 20 : 30;
      final double minW = points.length * (barW + 24) + 60.0;
      final double w = math.max(box.maxWidth, minW);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: BarChart(BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List<BarChartGroupData>.generate(
              points.length,
              (int i) {
                final bool isSelected = points[i].$1 == selectedId;
                return BarChartGroupData(
                  x: i,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: points[i].$2.toDouble(),
                      width: barW,
                      color: isSelected ? _infra : _infra.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: isSelected,
                        toY: maxY,
                        color: _infra.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: _axisInterval(maxY),
                  getTitlesWidget: (double v, TitleMeta meta) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (double v, TitleMeta meta) {
                    final int i = v.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox.shrink();
                    final bool isSelected = points[i].$1 == selectedId;
                    return Text(
                      'Infra ${points[i].$1}',
                      style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? _infra : _muted,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _infra,
                getTooltipItem: (BarChartGroupData group, int gi, BarChartRodData rod, int ri) {
                  final int i = group.x;
                  if (i < 0 || i >= points.length) return null;
                  return BarTooltipItem(
                    'Infra ${points[i].$1}\n${points[i].$2}개',
                    const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'pretendard'),
                  );
                },
              ),
            ),
          )),
        ),
      );
    });
  }

  // ── 인프라 일별 감지 객체 바차트 ──────────────
  Widget _buildInfraObjectChart(ActivityController c) {
    final List<Map<String, dynamic>> raw = c.infraDailyObjectCounts;

    // days 슬라이스와 동일한 날짜 레이블 생성 (KST 기준 최근 30일)
    final List<String> labels = c.kstDateLabels(c.chartDays_);
    final Map<String, int> byDate = <String, int>{
      for (final Map<String, dynamic> row in raw)
        (row['date_kst'] as String? ?? ''): (row['total_objects'] as int? ?? 0),
    };

    // (label, count) 쌍 목록
    final List<(String, int)> points = labels.map((String d) => (d, byDate[d] ?? 0)).toList();

    if (points.every(((String, int) p) => p.$2 == 0)) {
      return _emptyPanel(
        l10n('감지된 객체 데이터가 없습니다.', 'No detected object data available.'),
      );
    }

    final double maxY = _maxY(
      points.map(((String, int) p) => p.$2.toDouble()).toList(),
    );

    return LayoutBuilder(builder: (_, BoxConstraints box) {
      final double barW = points.length > 14 ? 10 : 14;
      final double w = math.max(box.maxWidth, points.length * (barW + 18) + 40);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: BarChart(BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List<BarChartGroupData>.generate(
              points.length,
              (int i) => BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: points[i].$2.toDouble(),
                    width: barW,
                    color: points[i].$2 > 0 ? _infra : _border,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: _axisInterval(maxY),
                  getTitlesWidget: (double v, TitleMeta meta) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (double v, TitleMeta meta) {
                    final int i = v.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox.shrink();
                    // 모든 일자 라벨 표시 — 일/주/월 피커에서 날짜 누락 없이 전부 노출
                    return Text(
                      _mmdd(points[i].$1),
                      style: const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _infra,
                getTooltipItem: (BarChartGroupData group, int gi, BarChartRodData rod, int ri) {
                  final int i = group.x;
                  if (i < 0 || i >= points.length) return null;
                  return BarTooltipItem(
                    '${points[i].$1}\n${points[i].$2}개',
                    const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'pretendard'),
                  );
                },
              ),
            ),
          )),
        ),
      );
    });
  }

  // ── 이벤트 바차트 (인프라 / 공통) ─────────────
  Widget _buildEventChart(ActivityController c) {
    final List<ActivityChartDay> days = c.deviceChartDaysSlice(c.chartDays_);
    final double maxY = _maxY(days.map((ActivityChartDay d) => d.total.toDouble()).toList());

    if (days.every((ActivityChartDay d) => d.total == 0)) {
      return _emptyPanel(l10n('이 디바이스의 이벤트 이력이 없습니다.', 'No event history for this device.'));
    }

    return SizedBox(
      height: 220,
      child: LayoutBuilder(builder: (_, BoxConstraints box) {
        final double width = math.max(box.maxWidth, days.length * 32.0 + 28);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: BarChart(BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List<BarChartGroupData>.generate(days.length, (int index) {
                final ActivityChartDay day = days[index];
                final int warning = day.byType['high_speed'] ?? 0;
                final int danger = day.byType['emergency_stop'] ?? 0;
                final int normal = math.max(0, day.total - warning - danger);
                return BarChartGroupData(x: index, barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: day.total.toDouble(),
                    width: days.length > 14 ? 10 : 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    rodStackItems: <BarChartRodStackItem>[
                      BarChartRodStackItem(0, normal.toDouble(), _primary),
                      BarChartRodStackItem(
                          normal.toDouble(), (normal + warning).toDouble(), _warning),
                      BarChartRodStackItem(
                          (normal + warning).toDouble(), day.total.toDouble(), _danger),
                    ],
                  ),
                ]);
              }),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: _axisInterval(maxY),
                  getTitlesWidget: (double value, TitleMeta meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted),
                  ),
                )),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= days.length) {
                      return const SizedBox.shrink();
                    }
                    if (days.length > 8 && index.isOdd) {
                      return const SizedBox.shrink();
                    }
                    return Text(_mmdd(days[index].dateKst),
                        style:
                            const TextStyle(fontFamily: 'pretendard', fontSize: 10, color: _muted));
                  },
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final ActivityChartDay day = days[group.x];
                    return BarTooltipItem(
                      _eventTooltipLabel(day.dateKst, day.total),
                      const TextStyle(fontFamily: 'pretendard', fontSize: 11, color: Colors.white),
                    );
                  },
                ),
              ),
            )),
          ),
        );
      }),
    );
  }

  // ── 활동 피드 ───────────────────────────────────
}