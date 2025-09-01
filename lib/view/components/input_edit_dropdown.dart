import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import '../../constants/constants.dart';

class InputEditDropDown extends StatelessWidget {
  const InputEditDropDown({
    super.key,
    this.onChanged,
    this.hintText = "",
    required this.items,
    this.selectedText = "",
    this.borderColor = const Color(0xFFD9D9D9),
    this.mainColor = kBlackFontColor,
    this.selectedItemAlignment = Alignment.centerLeft,
    this.borderWidth = 1,
    this.buttonPadding = const EdgeInsets.only(right: 8),
  });

  final ValueChanged<String?>? onChanged;
  final String hintText;
  final List<String> items;
  final String selectedText;
  final Color borderColor;
  final Color mainColor;
  final Alignment selectedItemAlignment;
  final double borderWidth;
  final EdgeInsetsGeometry buttonPadding;

  @override
  Widget build(BuildContext context) {
    return DropdownButton2<String>(
      value: (selectedText.isEmpty) ? null : selectedText,
      underline: Container(),
      buttonStyleData: ButtonStyleData(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: buttonPadding,
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
      menuItemStyleData: const MenuItemStyleData(
        height: 44,
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF4F5A6F),
          size: 20,
        ),
      ),
      isExpanded: true,
      onChanged: onChanged!,
      style: const TextStyle(
        fontFamily: 'pretendard',
        color: Colors.black,
        fontWeight: FontWeight.w400,
        fontSize: 14.0,
      ),
      hint: Container(
        height: 40,
        alignment: Alignment.centerLeft,
        child: Text(
          hintText,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontFamily: 'pretendard',
            color: Color(0xFF666565),
            fontWeight: FontWeight.w400,
            fontSize: 14.0,
          ),
        ),
      ),
      selectedItemBuilder: (context) {
        return items.map<Widget>(
          (item) {
            return Container(
              height: 44,
              alignment: selectedItemAlignment,
              child: Text(
                item,
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontWeight: FontWeight.w400,
                  color: kBlackFontColor,
                  fontSize: 14,
                ),
              ),
            );
          },
        ).toList();
      },
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: (value == selectedText) ? const Color(0xFF407BFF) : kBlackFontColor,
                  ),
                ),
              ),
              Icon(
                Icons.check,
                color: (value == selectedText) ? const Color(0xFF407BFF) : Colors.transparent,
                size: 20,
              )
            ],
          ),
        );
      }).toList(),
    );
  }
}
