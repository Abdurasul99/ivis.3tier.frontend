import 'package:flutter/material.dart';

class TextTitle extends StatelessWidget {
  const TextTitle({
    super.key,
    this.titleText = "",
    this.cellHeight = 28,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w500,
    this.fontColor = const Color(0xFF363636),
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.fontFamily = 's-dream',
  });

  final String titleText;
  final double cellHeight;
  final double fontSize;
  final FontWeight fontWeight;
  final Color fontColor;
  final String fontFamily;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: cellHeight,
      padding: padding,
      alignment: Alignment.centerLeft,
      child: Text(
        titleText,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.2,
          color: fontColor,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}
