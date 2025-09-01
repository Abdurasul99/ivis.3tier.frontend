import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '/view/components/gradient_button.dart';

class PeriodSelectDialogMobile extends StatefulWidget {
  const PeriodSelectDialogMobile({Key? key, this.startDate, this.endDate}) : super(key: key);
  final String? startDate;
  final String? endDate;

  @override
  State<PeriodSelectDialogMobile> createState() => _PeriodSelectDialogMobileState();
}

class _PeriodSelectDialogMobileState extends State<PeriodSelectDialogMobile> {
  final GlobalKey _startKey = GlobalKey();
  final GlobalKey _endKey = GlobalKey();

  final _fmt = DateFormat('yyyy-MM-dd');
  String _quick = '';
  late String _start;
  late String _end;

  OverlayEntry? _calOv;

  @override
  void initState() {
    super.initState();
    _start = widget.startDate?.isNotEmpty == true ? widget.startDate! : '2025-01-01';
    _end = widget.endDate?.isNotEmpty == true ? widget.endDate! : _fmt.format(DateTime.now());
  }

  @override
  void dispose() {
    _removeCal();
    super.dispose();
  }

  /* ────────── UI ────────── */
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('조회기간', style: TextStyle(fontFamily: 'pretendard', fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _quickRow(),
          const SizedBox(height: 12),
          _dateRow(),
          const SizedBox(height: 16),
          _buttons(),
        ],
      );

  /* quick buttons */
  Widget _quickRow() {
    const labels = ['1일', '1주일', '1개월', '직접설정'];
    return Row(
      children: labels.map((l) {
        final sel = _quick == l;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: l == '직접설정' ? 0 : 8),
            child: GestureDetector(
              onTap: () => _selectQuick(l),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: sel ? const Color(0xFF005FB8) : const Color(0xFFDDDDDD)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l,
                    style: TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: sel ? const Color(0xFF005FB8) : Color(0xFF666565))),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _selectQuick(String l) {
    setState(() {
      _quick = l;
      final now = DateTime.now();
      if (l == '1일') {
        _start = _fmt.format(now.subtract(const Duration(days: 1)));
        _end = _fmt.format(now);
      } else if (l == '1주일') {
        _start = _fmt.format(now.subtract(const Duration(days: 7)));
        _end = _fmt.format(now);
      } else if (l == '1개월') {
        _start = _fmt.format(now.subtract(const Duration(days: 30)));
        _end = _fmt.format(now);
      }
      _removeCal();
    });
  }

  /* date pickers */
  Widget _dateRow() => Row(
        children: [
          _dateBox(_startKey, _start, true),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12), child: Text('~', style: TextStyle(fontSize: 15))),
          _dateBox(_endKey, _end, false),
        ],
      );

  Widget _dateBox(GlobalKey k, String txt, bool start) => Expanded(
        child: GestureDetector(
          key: k,
          onTap: _quick == '직접설정' ? () => _showCal(start) : null,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(txt, style: const TextStyle(fontFamily: 'pretendard', fontSize: 15, color: Color(0xFF666565))),
          ),
        ),
      );

  void _showCal(bool start) {
    _removeCal();
    final rb = (start ? _startKey : _endKey).currentContext!.findRenderObject() as RenderBox;
    final pos = rb.localToGlobal(Offset.zero);
    const calW = 300.0;
    final left = (MediaQuery.of(context).size.width - calW) / 2;
    final init = _fmt.parse(start ? _start : _end);

    _calOv = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: pos.dy + rb.size.height + 4,
        width: calW,
        child: Material(
          color: Colors.white,
          elevation: 12,
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.antiAlias,
          child: CalendarDatePicker(
            initialDate: init,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: (d) {
              setState(() {
                if (start) {
                  _start = _fmt.format(d);
                } else {
                  _end = _fmt.format(d);
                }
                _quick = '직접설정';
              });
              _removeCal();
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_calOv!);
  }

  void _removeCal() {
    _calOv?.remove();
    _calOv = null;
  }

  Widget _buttons() => Row(
        children: [
          Expanded(
            child: GradientButton(
              buttonText: '확인',
              buttonColor: const Color(0xFF005FB8),
              onTap: () => Get.back(result: {'start': _start, 'end': _end}),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: GradientButton(buttonText: '취소', onTap: Get.back)),
        ],
      );
}
