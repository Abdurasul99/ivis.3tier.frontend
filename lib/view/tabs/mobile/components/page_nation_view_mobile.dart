// File: lib/view/tabs/mobile/components/page_nation_view_mobile.dart
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';

class PageNationViewMobile extends StatelessWidget {
  final int viewPage; // 0-based
  final int maxPage; // ≥ 1
  final ValueChanged<int>? onPageChanged;

  const PageNationViewMobile({
    Key? key,
    required this.viewPage,
    required this.maxPage,
    this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isFirst = viewPage <= 0;
    final bool isLast = viewPage >= maxPage - 1;
    const int windowSize = 5;

    int startPage = viewPage - 2;
    if (startPage < 1) startPage = 1;
    if (startPage + windowSize - 1 > maxPage) {
      startPage = maxPage - windowSize + 1;
    }
    if (startPage < 1) startPage = 1;
    final int endPage = (startPage + windowSize - 1).clamp(1, maxPage);

    const disabledColor = Color(0xFF666565);
    const activeBgColor = Color(0xFF666565);
    const activeTextColor = Colors.white;
    const inactiveTextColor = Color(0xFF666565);

    Widget arrow(IconData icon, bool enabled, int goto) {
      return GestureDetector(
        onTap: enabled ? () => onPageChanged?.call(goto) : null,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border.all(color: enabled ? activeBgColor : disabledColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? activeBgColor : disabledColor,
          ),
        ),
      );
    }

    Widget pageButton(int page) {
      final bool isCurrent = (page - 1) == viewPage;
      return GestureDetector(
        onTap: () => onPageChanged?.call(page - 1),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrent ? activeBgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 14,
              color: isCurrent ? activeTextColor : inactiveTextColor,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    final List<Widget> items = [
      arrow(Icons.keyboard_double_arrow_left, !isFirst, 0),
      arrow(Icons.keyboard_arrow_left, !isFirst, viewPage - 1),
    ];

    for (int p = startPage; p <= endPage; p++) {
      items.add(pageButton(p));
    }

    items.addAll([
      arrow(Icons.keyboard_arrow_right, !isLast, viewPage + 1),
      arrow(Icons.keyboard_double_arrow_right, !isLast, maxPage - 1),
    ]);

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items,
        ),
      ),
    );
  }
}
