import 'package:flutter/material.dart';

const Color _brandBlue = Color(0xFF005FB8);
const Color _borderGrey = Color(0xFFC4C4C4);
const Color _cancelText = Color(0xFF000000);
const TextStyle _txtStyle = TextStyle(
  fontFamily: 'pretendard',
  fontSize: 15,
  fontWeight: FontWeight.w400,
);

class MultiSelectFilter extends StatelessWidget {
  const MultiSelectFilter({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.hint = 'Robot Filter',
  });

  final List<String> items;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    bool _hasSelectAll(List<String> v) => v.any((e) => _lc(e) == 'select all');

    final bool showHint = _hasSelectAll(selected) || selected.isEmpty;

    return InkWell(
      onTap: () => _showPopup(context),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _borderGrey),
          borderRadius: BorderRadius.circular(3),
          color: Colors.white,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                showHint ? hint : selected.join(', '),
                overflow: TextOverflow.ellipsis,
                style: _txtStyle,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF4F5A6F)),
          ],
        ),
      ),
    );
  }

  String _lc(String s) => s.trim().toLowerCase();

  Future<void> _showPopup(BuildContext outerCtx) async {
    final box = outerCtx.findRenderObject() as RenderBox;
    final fieldSize = box.size;
    final fieldPos = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(outerCtx).size;
    final isMobile = screen.width < 600;

    final hasDeletedItem = items.any((e) {
      final l = _lc(e);
      return l == '삭제됨' || l == 'deleted';
    });

    final typeItems = <String>[
      for (final e in items)
        if (_lc(e) != 'select all' && _lc(e) != '삭제됨' && _lc(e) != 'deleted') e
    ];

    final tmpSelected = <String>{
      for (final e in selected)
        if (_lc(e) != 'select all' && _lc(e) != '삭제됨' && _lc(e) != 'deleted') e
    };

    bool selectAll = tmpSelected.length == typeItems.length;
    bool deletedOn = selected.any((e) => _lc(e) == '삭제됨' || _lc(e) == 'deleted');

    await showGeneralDialog(
      context: outerCtx,
      barrierDismissible: true,
      barrierLabel: 'multi_select',
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(outerCtx),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: isMobile ? 16.0 : fieldPos.dx,
              top: fieldPos.dy + fieldSize.height + 4,
              width: isMobile ? screen.width - 32 : fieldSize.width,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: StatefulBuilder(
                  builder: (ctx, setSt) {
                    Widget buildTile(String label) {
                      final isChecked = tmpSelected.contains(label);
                      return CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          label,
                          style: _txtStyle.copyWith(color: isChecked ? _brandBlue : Colors.black),
                        ),
                        value: isChecked,
                        activeColor: _brandBlue,
                        checkColor: Colors.white,
                        side: BorderSide(color: _borderGrey, width: 2),
                        onChanged: (v) => setSt(() {
                          if (v == true) {
                            tmpSelected.add(label);
                          } else {
                            tmpSelected.remove(label);
                          }
                          selectAll = tmpSelected.length == typeItems.length;
                        }),
                      );
                    }

                    final tiles = typeItems.map(buildTile).toList();
                    final listSection = typeItems.length <= 6
                        ? Column(children: tiles)
                        : ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: screen.height * 0.6),
                            child: ListView(shrinkWrap: true, children: tiles),
                          );

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // SELECT ALL
                        CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            'Select All',
                            style: _txtStyle.copyWith(color: selectAll ? _brandBlue : Colors.black),
                          ),
                          value: selectAll,
                          activeColor: _brandBlue,
                          checkColor: Colors.white,
                          side: BorderSide(color: _borderGrey, width: 2),
                          onChanged: (v) => setSt(() {
                            selectAll = v ?? false;
                            tmpSelected
                              ..clear()
                              ..addAll(selectAll ? typeItems : const <String>{});
                          }),
                        ),

                        listSection,

                        // 삭제됨 (Deleted)
                        if (hasDeletedItem)
                          Theme(
                            data: Theme.of(ctx).copyWith(
                              hoverColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: CheckboxListTile(
                              dense: true,
                              tileColor: Colors.white,
                              selectedTileColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(
                                '삭제됨',
                                style: _txtStyle.copyWith(color: deletedOn ? _brandBlue : Colors.black),
                              ),
                              value: deletedOn,
                              activeColor: _brandBlue,
                              checkColor: Colors.white,
                              side: BorderSide(color: _borderGrey, width: 2),
                              onChanged: (v) => setSt(() => deletedOn = v ?? false),
                            ),
                          ),

                        // Кнопки
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 145,
                                height: 40,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: _brandBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  onPressed: () {
                                    final out = <String>[];
                                    if (selectAll) {
                                      out.add('Select All');
                                    } else {
                                      out.addAll(tmpSelected);
                                    }
                                    if (hasDeletedItem && deletedOn) {
                                      out.add('삭제됨');
                                    }
                                    Navigator.pop(outerCtx);
                                    onChanged(out);
                                  },
                                  child: const Text('확 인', style: _txtStyle),
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 145,
                                height: 40,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: _cancelText,
                                    side: BorderSide(color: _borderGrey),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  onPressed: () => Navigator.pop(outerCtx),
                                  child: const Text('취 소', style: _txtStyle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
