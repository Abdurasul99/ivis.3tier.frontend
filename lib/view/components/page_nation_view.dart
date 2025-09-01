import 'package:flutter/material.dart';

import '../../constants/constants.dart';

class PageNationView extends StatefulWidget {
  const PageNationView({
    super.key,
    this.viewPage = 0,
    this.maxPage = 1,
    this.onViewPageChanged,
  });

  final int viewPage;
  final int maxPage;
  final ValueChanged<int>? onViewPageChanged;

  @override
  State<PageNationView> createState() => _PageNationViewState();
}

class _PageNationViewState extends State<PageNationView> {
  final TextEditingController _pageNoController = TextEditingController();
  final FocusNode _pageNoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pageNoController.text = (widget.viewPage + 1).toString();
  }

  @override
  void dispose() {
    super.dispose();

    _pageNoController.dispose();
    _pageNoFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: MediaQuery.of(context).size.width,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (widget.viewPage == 0) {
                return;
              }

              _pageNoController.text = "1";
              widget.onViewPageChanged!(0);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: kMainColor, width: 1.0),
                borderRadius: BorderRadius.circular(4.0),
              ),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_double_arrow_left,
                color: (widget.viewPage == 0) ? Colors.grey : kMainColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              if (widget.viewPage == 0) {
                return;
              }

              int viewPage = widget.viewPage - 1;
              if ((viewPage + 1) <= 0) {
                viewPage = 0;
              }

              _pageNoController.text = (viewPage + 1).toString();
              widget.onViewPageChanged!(viewPage);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: kMainColor, width: 1.0),
                borderRadius: BorderRadius.circular(4.0),
              ),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_left,
                color: (widget.viewPage == 0) ? Colors.grey : kMainColor,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Row(
            children: makePageIndexesWidgets(),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              if (widget.viewPage == (widget.maxPage - 1)) {
                return;
              }

              int viewPage = widget.viewPage + 1;
              if ((viewPage + 1) > widget.maxPage) {
                viewPage = widget.maxPage + 1;
              }
              _pageNoController.text = (viewPage + 1).toString();
              widget.onViewPageChanged!(viewPage);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: kMainColor, width: 1.0),
                borderRadius: BorderRadius.circular(4.0),
              ),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_right,
                color: (widget.viewPage == (widget.maxPage - 1)) ? Colors.grey : kMainColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              if (widget.viewPage == widget.maxPage) {
                return;
              }

              int viewPage = widget.maxPage - 1;
              _pageNoController.text = (viewPage + 1).toString();
              widget.onViewPageChanged!(viewPage);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: kMainColor, width: 1.0),
                borderRadius: BorderRadius.circular(4.0),
              ),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_double_arrow_right,
                color: (widget.viewPage == (widget.maxPage - 1)) ? Colors.grey : kMainColor,
              ),
            ),
          ),
          // const SizedBox(width: 30),
          // Container(
          //   width: 100,
          //   height: 60,
          //   alignment: Alignment.center,
          //   child: Stack(
          //     children: [
          //       Center(
          //         child: Container(
          //           width: 100,
          //           height: 40,
          //           alignment: Alignment.center,
          //           padding: const EdgeInsets.symmetric(horizontal: 10),
          //           decoration: BoxDecoration(
          //             border: Border.all(color: kMainColor, width: 1.0),
          //             borderRadius: BorderRadius.circular(4.0),
          //           ),
          //         ),
          //       ),
          //       Center(
          //         child: TextFormField(
          //           controller: _pageNoController,
          //           decoration: const InputDecoration(
          //             border: InputBorder.none,
          //             contentPadding: EdgeInsets.symmetric(horizontal: 10),
          //             hintText: "Page No",
          //             hintStyle: TextStyle(
          //               color: Colors.grey,
          //               fontWeight: FontWeight.w700,
          //               fontSize: 12.0,
          //               height: 1.0,
          //             ),
          //           ),
          //           textAlign: TextAlign.center,
          //           style: const TextStyle(
          //             color: Colors.black,
          //             fontWeight: FontWeight.w700,
          //             fontSize: 12.0,
          //             height: 1.0,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(width: 10),
          // GestureDetector(
          //   onTap: () {
          //     String pageNoStr = _pageNoController.text;
          //
          //     int? pageNo = int.tryParse(pageNoStr);
          //     if (pageNo == null) {
          //       Utils.showSnackBar("숫자를 입력하세요.", isError: true);
          //       return;
          //     }
          //
          //     if (pageNo <= 0) {
          //       Utils.showSnackBar("최소 페이지를 벗어났습니다.(최소값: 1)", isError: true);
          //       return;
          //     }
          //
          //     if (pageNo > widget.maxPage) {
          //       Utils.showSnackBar("최대 페이지를 벗어났습니다.(최대값: $widget.maxPage)", isError: true);
          //       return;
          //     }
          //
          //     widget.onViewPageChanged!(pageNo - 1);
          //   },
          //   child: Container(
          //     width: 60,
          //     height: 40,
          //     alignment: Alignment.center,
          //     padding: const EdgeInsets.symmetric(horizontal: 10),
          //     decoration: BoxDecoration(
          //       color: kMainColor,
          //       borderRadius: BorderRadius.circular(4.0),
          //     ),
          //     child: const Text(
          //       "GO",
          //       style: TextStyle(
          //         color: Colors.white,
          //         fontSize: 15,
          //         fontWeight: FontWeight.w700,
          //         height: 1.1,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  List<Widget> makePageIndexesWidgets() {
    List<Widget> result = [];

    int div = (widget.viewPage / 10).floor();
    int mod = ((widget.viewPage + 1) % 10);

    // debugPrint("div $div, mod $mod");

    if (div == 0) {
      for (int i = 1; i <= 10; i++) {
        if (i == widget.maxPage + 1) {
          break;
        }

        result.add(
          GestureDetector(
            onTap: () {
              _pageNoController.text = i.toString();
              widget.onViewPageChanged!(i - 1);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                i.toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: (i == (widget.viewPage + 1)) ? Colors.black : Colors.grey,
                  fontWeight: (i == (widget.viewPage + 1)) ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }

      return result;
    }

    for (int i = 1; i <= 10; i++) {
      int index = (div * 10) + i;

      if (index == widget.maxPage + 1) {
        break;
      }

      result.add(
        GestureDetector(
          onTap: () {
            _pageNoController.text = index.toString();
            widget.onViewPageChanged!(index - 1);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              index.toString(),
              style: TextStyle(
                fontSize: 13,
                color: (index == (widget.viewPage + 1)) ? Colors.black : Colors.grey,
                fontWeight: (index == (widget.viewPage + 1)) ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return result;
  }
}
