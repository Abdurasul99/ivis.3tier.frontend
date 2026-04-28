import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../ui.dart';

class PlutoColumnFilter extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  PlutoColumnFilter({
    required this.stateManager,
    required this.column,
    Key? key,
  }) : super(key: ValueKey('column_filter_${column.key}'));

  @override
  PlutoColumnFilterState createState() => PlutoColumnFilterState();
}

class PlutoColumnFilterState extends PlutoStateWithChange<PlutoColumnFilter> {
  List<PlutoRow> _filterRows = [];

  String _text = '';

  bool _enabled = false;

  late final StreamSubscription _event;

  late final FocusNode _focusNode;

  late final TextEditingController _controller;

  String get _filterValue {
    return _filterRows.isEmpty
        ? ''
        : _filterRows.first.cells[FilterHelper.filterFieldValue]!.value
            .toString();
  }

  bool get _hasCompositeFilter {
    return _filterRows.length > 1 ||
        stateManager
            .filterRowsByField(FilterHelper.filterFieldAllColumns)
            .isNotEmpty;
  }

  InputBorder get _border => OutlineInputBorder(
        borderSide: BorderSide(
            color: stateManager.configuration.style.borderColor, width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  InputBorder get _enabledBorder => OutlineInputBorder(
        borderSide: BorderSide(
            color: stateManager.configuration.style.activatedBorderColor,
            width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  InputBorder get _disabledBorder => OutlineInputBorder(
        borderSide: BorderSide(
            color: stateManager.configuration.style.inactivatedBorderColor,
            width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  Color get _textFieldColor => _enabled
      ? stateManager.configuration.style.cellColorInEditState
      : stateManager.configuration.style.cellColorInReadOnlyState;

  EdgeInsets get _padding =>
      widget.column.filterPadding ??
      stateManager.configuration.style.defaultColumnFilterPadding;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  initState() {
    super.initState();

    _focusNode = FocusNode(onKeyEvent: _handleOnKey);

    widget.column.setFilterFocusNode(_focusNode);

    _controller = TextEditingController(text: _filterValue);

    _event = stateManager.eventManager!.listener(_handleFocusFromRows);

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  dispose() {
    _event.cancel();

    _controller.dispose();

    _focusNode.dispose();

    super.dispose();
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _filterRows = update<List<PlutoRow>>(
      _filterRows,
      stateManager.filterRowsByField(widget.column.field),
      compare: listEquals,
    );

    if (_focusNode.hasPrimaryFocus != true) {
      _text = update<String>(_text, _filterValue);

      if (changed) {
        _controller.text = _text;
      }
    }

    _enabled = update<bool>(
      _enabled,
      widget.column.enableFilterMenuItem && !_hasCompositeFilter,
    );
  }

  void _moveDown({required bool focusToPreviousCell}) {
    if (!focusToPreviousCell || stateManager.currentCell == null) {
      stateManager.setCurrentCell(
        stateManager.refRows.first.cells[widget.column.field],
        0,
        notify: false,
      );

      stateManager.scrollByDirection(PlutoMoveDirection.down, 0);
    }

    stateManager.setKeepFocus(true, notify: false);

    stateManager.gridFocusNode.requestFocus();

    stateManager.notifyListeners();
  }

  KeyEventResult _handleOnKey(FocusNode node, KeyEvent event) {
    var keyManager = PlutoKeyManagerEvent(
      focusNode: node,
      event: event,
    );

    if (keyManager.isKeyUpEvent) {
      return KeyEventResult.handled;
    }

    final handleMoveDown =
        (keyManager.isDown || keyManager.isEnter || keyManager.isEsc) &&
            stateManager.refRows.isNotEmpty;

    final handleMoveHorizontal = keyManager.isTab ||
        (_controller.text.isEmpty && keyManager.isHorizontal);

    final skip = !(handleMoveDown || handleMoveHorizontal || keyManager.isF3);

    if (skip) {
      if (keyManager.isUp) {
        return KeyEventResult.handled;
      }

      return stateManager.keyManager!.eventResult.skip(
        KeyEventResult.ignored,
      );
    }

    if (handleMoveDown) {
      _moveDown(focusToPreviousCell: keyManager.isEsc);
    } else if (handleMoveHorizontal) {
      stateManager.nextFocusOfColumnFilter(
        widget.column,
        reversed: keyManager.isLeft || keyManager.isShiftPressed,
      );
    } else if (keyManager.isF3) {
      stateManager.showFilterPopup(
        _focusNode.context!,
        calledColumn: widget.column,
        onClosed: () {
          stateManager.setKeepFocus(true, notify: false);
          _focusNode.requestFocus();
        },
      );
    }

    return KeyEventResult.handled;
  }

  void _handleFocusFromRows(PlutoGridEvent plutoEvent) {
    if (!_enabled) {
      return;
    }

    if (plutoEvent is PlutoGridCannotMoveCurrentCellEvent &&
        plutoEvent.direction.isUp) {
      var isCurrentColumn = widget
              .stateManager
              .refColumns[stateManager.columnIndexesByShowFrozen[
                  plutoEvent.cellPosition.columnIdx!]]
              .key ==
          widget.column.key;

      if (isCurrentColumn) {
        stateManager.clearCurrentCell(notify: false);
        stateManager.setKeepFocus(false);
        _focusNode.requestFocus();
      }
    }
  }

  void _handleOnTap() {
    stateManager.setKeepFocus(false);
  }

  void _handleOnChanged(String changed) {
    stateManager.eventManager!.addEvent(
      PlutoGridChangeColumnFilterEvent(
        column: widget.column,
        filterType: widget.column.defaultFilter,
        filterValue: changed,
        debounceMilliseconds:
            stateManager.configuration.columnFilter.debounceMilliseconds,
      ),
    );
  }

  void _handleOnEditingComplete() {
    // empty for ignore event of OnEditingComplete.
  }

  // 컬럼 필드명에 따라 입력 포매터 반환
  List<TextInputFormatter> _getInputFormatters() {
    final String field = widget.column.field;

    // 정수 컬럼: 숫자만
    const Set<String> _intFields = <String>{
      'history_id', 'vehicle_info_id', 'infra_info_id',
      'vehicle_id', 'infra_id', 'msg_id', 'msg_seq',
      'msg_length', 'number_of_objects', 'transmission_gear',
      'signal_light', 'time_stamp_ms', 'navsat',
    };
    if (_intFields.contains(field)) {
      return <TextInputFormatter>[
        // 정수 범위(30~80) + 와일드카드(*) 지원
        FilteringTextInputFormatter.allow(RegExp(r'[0-9~*]')),
      ];
    }

    // 소수/음수 컬럼: 숫자, 소수점, 마이너스, 틸다, 와일드카드 (범위/와일드카드 검색 지원)
    const Set<String> _decimalFields = <String>{
      'kph', 'mps', 'pos_x_m', 'pos_y_m', 'pos_z_m',
      'heading_deg', 'accel_x_mps2', 'accel_y_mps2', 'accel_z_mps2',
      'gyro_x_dps', 'gyro_y_dps', 'gyro_z_dps',
      'angle_deg', 'torque_nm', 'accel_pct', 'brake_pct',
    };
    if (_decimalFields.contains(field)) {
      return <TextInputFormatter>[
        // 소수 범위(-10.5~20.3) + 와일드카드(*) 지원
        FilteringTextInputFormatter.allow(RegExp(r'[-0-9.~*]')),
      ];
    }

    // 날짜 컬럼: 숫자, 하이픈, 틸다, 와일드카드 (YYYY-MM-DD~YYYY-MM-DD)
    const Set<String> _dateFields = <String>{
      'changed_at_date', 'created_ts_date', 'updated_ts_date',
    };
    if (_dateFields.contains(field)) {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\-~*]')),
        LengthLimitingTextInputFormatter(23),
      ];
    }

    // 시간 컬럼: 숫자, 콜론, 틸다, 와일드카드 (HH:MM:SS~HH:MM:SS)
    const Set<String> _timeFields = <String>{
      'changed_at_time', 'created_ts_time', 'updated_ts_time',
    };
    if (_timeFields.contains(field)) {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:~*]')),
        LengthLimitingTextInputFormatter(17),
      ];
    }

    return <TextInputFormatter>[];
  }

  @override
  Widget build(BuildContext context) {
    final style = stateManager.style;

    return SizedBox(
      height: stateManager.columnFilterHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: BorderSide(color: style.borderColor),
            end: style.enableColumnBorderVertical
                ? BorderSide(color: style.borderColor)
                : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: _padding,
          child: Center(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _controller,
                    enabled: _enabled,
                    style: style.cellTextStyle,
                    textAlign: TextAlign.center,
                    inputFormatters: _getInputFormatters(),
                    onTap: _handleOnTap,
                    onChanged: _handleOnChanged,
                    onEditingComplete: _handleOnEditingComplete,
                    decoration: InputDecoration(
                      hintText: _enabled
                          ? (widget.column.filterHintText ?? widget.column.defaultFilter.title)
                          : '',
                      hintStyle: style.cellTextStyle.copyWith(
                        fontSize: 11.5,
                        color: (style.cellTextStyle.color ?? const Color(0xFF9E9E9E))
                            .withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: _textFieldColor,
                      border: _border,
                      enabledBorder: _border,
                      disabledBorder: _disabledBorder,
                      focusedBorder: _enabledBorder,
                      contentPadding: const EdgeInsets.all(5),
                    ),
                  ),
                ),
                if (widget.column.filterSuffixBuilder != null)
                  widget.column.filterSuffixBuilder!(widget.column),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
