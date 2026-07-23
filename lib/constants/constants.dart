// ivis.3tier.frontend/lib/constants/constants.dart

import 'dart:math';
import 'package:flutter/material.dart';

const Color kMainColor = Color(0xFF33383A);
const Color kNavyColor = Color(0xFF002C5F);
const Color kGrayColor = Color(0xFFEAE7ED);
const Color kBlueFontColor = Color(0xFF005FB7);
const Color kDarkBlueColor = Color(0xFF8392a6);
const Color kDarkGrayColor = Color(0xFF666565);
const Color kGrayFontColor = Color(0xFF898D93);
const Color kBlackFontColor = Color(0xFF363636);
const Color kBackgroundColor = Color(0xFFFEFEFE);
const Color kHoverColor = Color(0xFFE6E7EB);
const Color kLineColor = Color(0xFFF3F3F4);
const Color kHintColor = Color(0xFFD0D0D0);
const Color kDarkBlueHintColor = Color(0xffa7b8d0);
const Color kDisableColor = Color(0xFFF2F2F2);
const Color kCellTitleColor = Color(0xFFE6E9ED);
const Color kCellGrayColor = Color(0xFFF9F9F9);

const double kMobileWidth = 700;
const double kTabletWidth = 1300;
const double kDesktopWidth = 1290;

const String kApiServer = "<SERVER_DOMAIN>:4090"; //"localhost:4090"; //
const String kMqttServer = "ws://<SERVER_DOMAIN>:9001"; //"ws://192.168.0.76"; //

final List<Color> kRandomColor = [
  Colors.yellow,
  Colors.blue,
  Colors.brown,
  Colors.orange,
  Colors.green,
  Colors.pink,
  Colors.amber,
  Colors.cyanAccent,
  Colors.deepPurpleAccent,
  Colors.indigoAccent,
  Colors.teal,
];

final List<Color> kStateColor = [
  Color(0xFF666565),
  Color(0xFF60CDFF),
  Color(0xFF005FB8),
  Color(0xFFFFAE00),
  Color(0xFFC42B1C),
];

final List<Color> kWorkTypeColors = [
  Colors.transparent,
  Colors.green,
  Colors.red,
  Colors.orange,
  Colors.brown,
  Colors.pink,
  Colors.grey,
  Colors.blue,
];

final ColorScheme kAppColorScheme = ColorScheme.light(
  primary: kBlueFontColor,
  onPrimary: Colors.white,
  surface: Colors.white,
  onSurface: kBlackFontColor,
);

final DatePickerThemeData kAppDatePickerTheme = DatePickerThemeData(
  headerForegroundColor: kBlueFontColor,
);

const kLogListLimit = 14;
const kNotificationListLimit = 16;
