import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../components/gradient_button.dart';

class PeriodSelectDialog extends StatefulWidget {
  const PeriodSelectDialog({
    super.key,
    this.startDate,
    this.endDate,
  });

  final String? startDate;
  final String? endDate;

  @override
  State<PeriodSelectDialog> createState() => _PeriodSelectDialogState();
}

class _PeriodSelectDialogState extends State<PeriodSelectDialog> {
  final GlobalKey _startDateKey = GlobalKey();
  final GlobalKey _endDateKey = GlobalKey();

  String _selectedPeriodItem = "";
  String _startDate = "";
  String _endDate = "";

  // Track which date picker is currently open
  bool _isStartDatePickerShown = false;
  bool _isEndDatePickerShown = false;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    _startDate = "2025-01-01";
    _endDate = _dateFormat.format(DateTime.now());

    if (widget.startDate != null && widget.startDate!.isNotEmpty) {
      _startDate = widget.startDate ?? "";
    }

    if (widget.endDate != null && widget.endDate!.isNotEmpty) {
      _endDate = widget.endDate ?? "";
    }
  }

  @override
  void dispose() {
    removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: 373,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: Offset(0, 0),
              blurRadius: 3,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              alignment: Alignment.centerLeft,
              child: const Text(
                "조회기간",
                style: TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: buildPeriodItem("1일")),
                const SizedBox(width: 8),
                Expanded(child: buildPeriodItem("1주일")),
                const SizedBox(width: 8),
                Expanded(child: buildPeriodItem("1개월")),
                const SizedBox(width: 8),
                Expanded(child: buildPeriodItem("직접설정")),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: _startDateKey,
                    onTap: () {
                      if (_selectedPeriodItem != "직접설정") {
                        return;
                      }

                      if (_isStartDatePickerShown) {
                        removeOverlay();
                        _isStartDatePickerShown = false;
                      } else {
                        showDatePicker(context, true);
                        _isStartDatePickerShown = true;
                        _isEndDatePickerShown = false;
                      }
                    },
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.0),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _startDate,
                        style: const TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 15,
                          color: Color(0xFF666565),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "~",
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    key: _endDateKey,
                    onTap: () {
                      if (_selectedPeriodItem != "직접설정") {
                        return;
                      }

                      if (_isEndDatePickerShown) {
                        removeOverlay();
                        _isEndDatePickerShown = false;
                      } else {
                        showDatePicker(context, false);
                        _isEndDatePickerShown = true;
                        _isStartDatePickerShown = false;
                      }
                    },
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.0),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _endDate,
                        style: const TextStyle(
                          fontFamily: 'pretendard',
                          fontSize: 15,
                          color: Color(0xFF666565),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    buttonText: "조회",
                    buttonColor: const Color(0xFF005FB8),
                    onTap: () {
                      Map<String, String> params = {};
                      params['start'] = _startDate;
                      params['end'] = _endDate;

                      Get.back(result: params);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GradientButton(
                    buttonText: "취소",
                    onTap: () {
                      Get.back();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isStartDatePickerShown = false;
    _isEndDatePickerShown = false;
  }

  void showDatePicker(BuildContext context, bool isStart) {
    removeOverlay();

    DateTime initialDate = DateTime.now();
    if (isStart && _startDate.isNotEmpty) {
      try {
        initialDate = _dateFormat.parse(_startDate);
      } catch (e) {
        initialDate = _dateFormat.parse("2025-01-01");
      }
    } else if (!isStart && _endDate.isNotEmpty) {
      try {
        initialDate = _dateFormat.parse(_endDate);
      } catch (e) {
        initialDate = DateTime.now();
      }
    }

    final RenderBox renderBox = (isStart ? _startDateKey : _endDateKey).currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + size.height,
        width: 300,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 0),
                  blurRadius: 2,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 260,
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onDateChanged: (DateTime date) {
                      String formattedDate = _dateFormat.format(date);
                      setState(() {
                        if (isStart) {
                          _startDate = formattedDate;
                        } else {
                          _endDate = formattedDate;
                        }
                      });
                      removeOverlay();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget buildPeriodItem(String period) {
    return GestureDetector(
      onTap: () {
        _selectedPeriodItem = period;

        if (_selectedPeriodItem != "직접설정") {
          DateTime now = DateTime.now();
          _endDate = _dateFormat.format(now);

          if (_selectedPeriodItem == "1일") {
            _startDate = _dateFormat.format(now.subtract(Duration(days: 1)));
          } else if (_selectedPeriodItem == "1주일") {
            _startDate = _dateFormat.format(now.subtract(Duration(days: 7)));
          } else if (_selectedPeriodItem == "1개월") {
            _startDate = _dateFormat.format(now.subtract(Duration(days: 30)));
          }

          removeOverlay();
          _isStartDatePickerShown = false;
          _isEndDatePickerShown = false;
        }

        if (mounted) {
          setState(() {});
        }
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: (_selectedPeriodItem == period) ? const Color(0xFF005FB8) : const Color(0xFFD9D9D9),
            width: 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          period,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: 15,
            color: (_selectedPeriodItem == period) ? const Color(0xFF005FB8) : const Color(0xFF666565),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
