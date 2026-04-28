import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import 'gradient_button.dart';

class InputEditDropDownMultiSelect extends StatefulWidget {
  const InputEditDropDownMultiSelect({
    super.key,
    this.onChanged,
    this.hintText = "",
    required this.items,
    this.selectedItems = "",
    this.borderColor = const Color(0xFFD9D9D9),
    this.mainColor = kBlackFontColor,
    this.selectedItemAlignment = Alignment.centerLeft,
    this.borderWidth = 1,
    this.buttonPadding = const EdgeInsets.only(right: 8),
  });

  final ValueChanged<String>? onChanged;
  final String hintText;
  final List<String> items;
  final String selectedItems;
  final Color borderColor;
  final Color mainColor;
  final Alignment selectedItemAlignment;
  final double borderWidth;
  final EdgeInsetsGeometry buttonPadding;

  @override
  State<InputEditDropDownMultiSelect> createState() => _InputEditDropDownMultiSelectState();
}

class _InputEditDropDownMultiSelectState extends State<InputEditDropDownMultiSelect> {
  late List<String> _tempSelectedItems;
  bool _isSelectAll = false;

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = _stringToList(widget.selectedItems);
    _updateSelectAllState();
  }

  @override
  void didUpdateWidget(InputEditDropDownMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedItems != widget.selectedItems) {
      _tempSelectedItems = _stringToList(widget.selectedItems);
      _updateSelectAllState();
    }

    // debugPrint("didUpdateWidget() _tempSelectedItems $_tempSelectedItems");
  }

  List<String> _stringToList(String str) {
    if (str.isEmpty) {
      return [];
    }
    return str.split(',').map((item) {
      return item.trim();
    }).where((item) {
      return item.isNotEmpty;
    }).toList();
  }

  String _listToString(List<String> list) {
    return list.join(',');
  }

  void _updateSelectAllState() {
    _isSelectAll = _tempSelectedItems.length == widget.items.length;
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _tempSelectedItems = List.from(widget.items);
        _isSelectAll = true;
      } else {
        _tempSelectedItems.clear();
        _isSelectAll = false;
      }
    });
  }

  void _toggleItem(String item, bool? value) {
    debugPrint("_toggleItem() item $item, value $value");

    if (value == true) {
      if (!_tempSelectedItems.contains(item)) {
        _tempSelectedItems.add(item);
      }
    } else {
      _tempSelectedItems.remove(item);
    }
    _updateSelectAllState();

    if (mounted) {
      setState(() {});
    }

    debugPrint("_toggleItem() _tempSelectedItems $_tempSelectedItems");
  }

  void _applySelection() {
    if (widget.onChanged != null) {
      widget.onChanged!(_listToString(_tempSelectedItems));
    }
    Get.back();
  }

  void _cancelSelection() {
    setState(() {
      _tempSelectedItems = _stringToList(widget.selectedItems);
      _updateSelectAllState();
    });
    Get.back();
  }

  String _getDisplayText() {
    if (widget.selectedItems.isEmpty) {
      return widget.hintText;
    } else {
      List<String> selectedList = _stringToList(widget.selectedItems);
      return selectedList.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton2<String>(
      value: null,
      underline: Container(),
      buttonStyleData: ButtonStyleData(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: widget.borderColor, width: widget.borderWidth),
        ),
        padding: widget.buttonPadding,
      ),
      dropdownStyleData: DropdownStyleData(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.40),
              offset: const Offset(0, 1),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
      menuItemStyleData: MenuItemStyleData(
        padding: EdgeInsets.zero,
        height: (widget.items.length + 2) * 40 + 12,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF4F5A6F),
          size: 20,
        ),
      ),
      isExpanded: true,
      onChanged: (value) {},
      style: const TextStyle(
        fontFamily: 'pretendard',
        color: Colors.black,
        fontWeight: FontWeight.w400,
        fontSize: 14.0,
      ),
      hint: Container(
        height: 40,
        alignment: widget.selectedItemAlignment,
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          _getDisplayText(),
          textAlign: TextAlign.left,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'pretendard',
            color: widget.selectedItems.isEmpty ? const Color(0xFF666565) : widget.mainColor,
            fontWeight: FontWeight.w400,
            fontSize: 14.0,
          ),
        ),
      ),
      items: [
        DropdownMenuItem<String>(
          value: 'custom',
          child: StatefulBuilder(
            builder: (context, menuSetState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        _toggleSelectAll(!_isSelectAll);
                        menuSetState(() {});
                      },
                      child: Container(
                        height: 40,
                        color: Colors.transparent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 20),
                            SvgPicture.asset(
                              _isSelectAll
                                  ? "assets/images/icons_checkbox_checked.svg"
                                  : "assets/images/icons_checkbox_unchecked.svg",
                              width: 14,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Select All',
                                style: TextStyle(
                                  fontFamily: 'pretendard',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                  color: _isSelectAll ? const Color(0xFF005FB8) : kBlackFontColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...widget.items.map(
                      (item) {
                        return GestureDetector(
                          onTap: () {
                            bool value = !_tempSelectedItems.contains(item);
                            _toggleItem(item, value);
                            menuSetState(() {});
                          },
                          child: Container(
                            height: 40,
                            color: Colors.transparent,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 20),
                                SvgPicture.asset(
                                  _tempSelectedItems.contains(item)
                                      ? "assets/images/icons_checkbox_checked.svg"
                                      : "assets/images/icons_checkbox_unchecked.svg",
                                  width: 14,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      color:
                                          _tempSelectedItems.contains(item) ? const Color(0xFF005FB8) : kBlackFontColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              buttonText: 'Apply',
                              buttonColor: const Color(0xFF005FB8),
                              onTap: _applySelection,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GradientButton(
                              buttonText: 'Cancel',
                              onTap: _cancelSelection,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
