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

const String kApiServer = "192.168.0.76:4090"; //
const String kMapHost = "map.whyrano.com:4001"; //"localhost:3000";//
const String kMqttServer = "ws://192.168.0.76"; //"ws://192.168.0.76"; //

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

final List<String> kStateStr = ["manual", "ready", "autonomous", "parking", "system fail"];

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

const double kStation0Latitude = 35.124864972158605;
const double kStation0Longitude = 126.76918104801685;
const String kStation0Address = "광주광역시 광산구 월전동 59-8";

const double kStation1Latitude = 35.177791663746326;
const double kStation1Longitude = 126.6711729684465;
const String kStation1Address = "광주광역시 광산구 덕립동";

const double kStation2Latitude = 35.169482372043284;
const double kStation2Longitude = 126.6749495613166;
const String kStation2Address = "광주광역시 광산구 덕립동";

const double kStation3Latitude = 35.167019602816744;
const double kStation3Longitude = 126.67250608872548;
const String kStation3Address = "광주광역시 광산구 삼거동";

const double kStation4Latitude = 35.166873275988515;
const double kStation4Longitude = 126.67506970973616;
const String kStation4Address = "광주광역시 광산구 삼거동";

const double kStation5Latitude = 35.166873275988515;
const double kStation5Longitude = 126.67506970973616;
const String kStation5Address = "광주광역시 광산구 삼거동";

// const Map<String, dynamic> kPosInfoUp = {"title": "Info U", "X": 8.400, "Y": 8.296, "Z": 0.709, "W": 0.705};
// const Map<String, dynamic> kPosMulLab = {"title": "멀티미디어LAB실", "X": 22.336, "Y": 0.921, "Z": -0.700, "W": 0.714};
// const Map<String, dynamic> kPosInfoRight = {"title": "인포메이션라운지", "X": 17.125, "Y": 0.921, "Z": -0.700, "W": 0.714};
// const Map<String, dynamic> kPosElevator = {"title": "엘리베이터", "X": 12.674, "Y": -18.021, "Z": -0.999, "W": 0.033};
// const Map<String, dynamic> kPosAtm = {"title": "ATM", "X": 27.079, "Y": 4.894, "Z": -0.697, "W": 0.717};
// const Map<String, dynamic> kPosRestM = {"title": "화장실(남)", "X": 13.955, "Y": -3.851, "Z": -0.690, "W": 0.723};
// const Map<String, dynamic> kPosRestW = {"title": "화장실(여)", "X": 2.728, "Y": 0.228, "Z": -0.703, "W": 0.711};
// const Map<String, dynamic> kPosMidiR = {"title": "미디어라운지", "X": -0.974, "Y": 2.849, "Z": -0.706, "W": 0.708};
// const Map<String, dynamic> kPosDoDam = {"title": "도담마루", "X": -0.974, "Y": 2.849, "Z": -0.706, "W": 0.708};
// const Map<String, dynamic> kPosMidiRoom = {"title": "미디어룸(2번)", "X": 33.693, "Y": 22.145, "Z": -0.002, "W": 0.999};
// const Map<String, dynamic> kPosMultiZ = {"title": "멀티플랙스존", "X": 58.027, "Y": 23.309, "Z": -0.005, "W": 0.999};
// const Map<String, dynamic> kPosImgStudio = {"title": "상상계단", "X": 37.749, "Y": 8.726, "Z": 0.714, "W": 0.700};
// const Map<String, dynamic> kPosCHall = {"title": "컨버전스홀", "X": 40.640, "Y": 5.027, "Z": -0.705, "W": 0.709};
// const Map<String, dynamic> kPosRest = {"title": "화장실", "X": 52.992, "Y": 25.146, "Z": 0.709, "W": 0.705};
// const Map<String, dynamic> kPosReturn = {"title": "반환지점", "X": 0.526, "Y": 4.157, "Z": -0.707, "W": 0.707};
// const Map<String, dynamic> kPosStart = {"title": "시작지점", "X": 2.111, "Y": 2.253, "Z": -0.707, "W": 0.707};
// const Point<double> kDefaultPosition = Point<double>(0.526, 4.157);
//
// const List<Map<String, dynamic>> kTaroMakers = [
//   kPosInfoUp,
//   kPosMulLab,
//   kPosInfoRight,
//   kPosElevator,
//   kPosAtm,
//   kPosRestM,
//   kPosRestW,
//   kPosMidiR,
//   kPosDoDam,
//   kPosMidiRoom,
//   kPosMultiZ,
//   kPosImgStudio,
//   kPosCHall,
//   kPosRest,
//   kPosReturn,
//   kPosStart,
// ];

const Map<String, dynamic> kPosFrontDoor = {
  "title": "출입문",
  "X": 3.43416065340989,
  "Y": -4.2611000076232,
  "Z": 0.709,
  "W": 0.705
};

const Map<String, dynamic> kPosInfoDesk = {
  "title": "인포데스크",
  "X": 12.1250104873140,
  "Y": -4.0123761193138,
  "Z": 0,
  "W": 0
};

const Map<String, dynamic> kPosMeetingRoom = {
  "title": "회의실",
  "X": 1.39592422887166,
  "Y": 0.99323332248150,
  "Z": -0.700,
  "W": 0.714
};

const Map<String, dynamic> kPosStart = {
  "title": "엘리베이터(시작지점)",
  "X": 36.0707063248834,
  "Y": -11.442960568414,
  "Z": -0.999,
  "W": 0.033
};

const Map<String, dynamic> kPosReturn = {
  "title": "반환지점",
  "X": 30.4701335319413,
  "Y": -9.0358916442737,
  "Z": -0.707,
  "W": 0.707
};

const Point<double> kDefaultPosition = Point<double>(30.4701335319413, -9.0358916442737);

const List<Map<String, dynamic>> kTaroMakers = [
  kPosFrontDoor,
  kPosInfoDesk,
  kPosMeetingRoom,
  kPosReturn,
  kPosStart,
];

const kLogListLimit = 14;
const kNotificationListLimit = 16;
