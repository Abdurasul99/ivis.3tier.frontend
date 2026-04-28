import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
import 'package:url_launcher/url_launcher_string.dart';

import '../constants/constants.dart';

class Utils {
  /// S3 URL을 백엔드 프록시 URL로 변환 (웹 CORS 우회)
  static String proxyImageUrl(String imageUrl) {
    if (!kIsWeb || imageUrl.isEmpty) return imageUrl;
    final String encoded = Uri.encodeComponent(imageUrl);
    final String server = kApiServer.trim();
    if (server.startsWith('http://') || server.startsWith('https://')) {
      return '$server/api/upload/proxy?url=$encoded';
    }
    return 'http://$server/api/upload/proxy?url=$encoded';
  }
  static String numberWithComma(int? param) {
    if (param == null) {
      return '0';
    }

    return NumberFormat('###,###,###,###').format(param).replaceAll(' ', '');
  }

  static String doubleWithComma(double? param) {
    if (param == null) {
      return '0.0';
    }

    return NumberFormat('###,###,###,###.###').format(param).replaceAll(' ', '');
  }

  static void showSnackBar(String message,
      {bool isError = false, bool isWarning = false, int milliseconds = 1500, SnackbarStatusCallback? callback}) {
    double width = Get.width - 32;
    if (width > 800) {
      width = 800;
    }

    Get.snackbar(
      "",
      "",
      maxWidth: width,
      duration: Duration(milliseconds: milliseconds),
      borderRadius: 8,
      colorText: isError
          ? const Color(0xFF7A0C2E)
          : isWarning
              ? const Color(0xFFE6C12B)
              : const Color(0xFF08660D),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.symmetric(vertical: 44),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      icon: !isError
          ? Container(
              padding: const EdgeInsets.only(left: 8.0),
              child: const Icon(Icons.check_circle, color: Color(0xFF54D62C), size: 22),
            )
          : isWarning
              ? Container(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: const Icon(Icons.warning, color: Color(0xFFE6C12B), size: 22),
                )
              : Container(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: const Icon(Icons.error, color: Color(0xFFFF4842), size: 22),
                ),
      titleText: Container(),
      messageText: Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Text(
          message,
          style: TextStyle(
            fontFamily: 'medium',
            fontSize: 15,
            color: isError ? const Color(0xFF7A0C2E) : const Color(0xFF08660D),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      backgroundColor: isError
          ? const Color(0xFFFFE7D9)
          : isWarning
              ? const Color(0xFFF1EBAE)
              : const Color(0xFFE9FCD4),
    );
  }

  static Duration calcDuration(String startTime, String endTime) {
    // debugPrint("calcDuration() $startTime, $endTime");

    startTime = startTime.replaceAll(":", "");
    endTime = endTime.replaceAll(":", "");

    int startHour = int.tryParse(startTime.substring(0, 2)) ?? 0;
    int startMinute = int.tryParse(startTime.substring(2, 4)) ?? 0;

    int endHour = int.tryParse(endTime.substring(0, 2)) ?? 0;
    int endMinute = int.tryParse(endTime.substring(2, 4)) ?? 0;

    Duration morningDur;
    Duration afternoonDur;

    if (startHour < 12 && endHour > 13) {
      morningDur = DateTime(2023, 01, 01, 12, 0, 0).difference(DateTime(2023, 01, 01, startHour, startMinute, 0));

      afternoonDur = DateTime(2023, 01, 01, endHour, endMinute).difference(DateTime(2023, 01, 01, 13, 0));
    } else {
      morningDur =
          DateTime(2023, 01, 01, endHour, endMinute).difference(DateTime(2023, 01, 01, startHour, startMinute));
      afternoonDur = Duration.zero;
    }

    Duration result = Duration(
      minutes: morningDur.inMinutes + afternoonDur.inMinutes,
    );

    // debugPrint(
    //     "calcDuration() ${(result.inMinutes / 60).floor()}, ${result.inMinutes % 60}");
    return result;
  }

  static Duration calcDurationEx(String startTime, String endTime) {
    // debugPrint("calcDurationEx() $startTime, $endTime");

    startTime = startTime.replaceAll(":", "");
    endTime = endTime.replaceAll(":", "");

    int startHour = int.tryParse(startTime.substring(0, 2)) ?? 0;
    int startMinute = int.tryParse(startTime.substring(2, 4)) ?? 0;

    int endHour = int.tryParse(endTime.substring(0, 2)) ?? 0;
    int endMinute = int.tryParse(endTime.substring(2, 4)) ?? 0;

    Duration result =
        DateTime(2023, 01, 01, endHour, endMinute).difference(DateTime(2023, 01, 01, startHour, startMinute));

    // debugPrint("calcDurationEx() ${(result.inMinutes / 60).floor()}, ${result.inMinutes % 60}");
    return result;
  }

  static String dateFormat(String date) {
    if (date.isEmpty || date.length < 8) {
      return date;
    }

    date = date.replaceAll("-", "");

    if (int.tryParse(date) == null) {
      return date;
    }

    int year = int.tryParse(date.substring(0, 4)) ?? 2023;
    int month = int.tryParse(date.substring(4, 6)) ?? 8;
    int day = int.tryParse(date.substring(6, 8)) ?? 1;

    return "$year-${month > 9 ? month : "0$month"}-${day > 9 ? day : "0$day"}";
  }

  static Future<bool> launchUrl(String url) async {
    if (url.isEmpty) {
      debugPrint("launchUrl() url is Null");
      return false;
    }

    debugPrint("launchUrl() url $url");

    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("launchUrl() Could not launch $url");
        return false;
      }
    } catch (e) {
      debugPrint("launchUrl() Exception ${e.toString()}");
      return false;
    }

    return true;
  }

  static Future<bool> launchUrlInApp(String url) async {
    if (url.isEmpty) {
      debugPrint("launchUrl() url is Null");
      return false;
    }

    debugPrint("launchUrlInApp() url $url");

    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.inAppWebView);
      } else {
        debugPrint("launchUrlInApp() Could not launch $url");
        return false;
      }
    } catch (e) {
      debugPrint("launchUrlInApp() Exception ${e.toString()}");
      return false;
    }

    return true;
  }

  static Future<bool> launchUrlCall(String phoneNumber) async {
    phoneNumber = phoneNumber.replaceAll("-", "");

    if (phoneNumber.isEmpty) {
      debugPrint("launchUrlCall() url is Null");
      return false;
    }

    debugPrint("launchUrlCall() phoneNumber $phoneNumber");

    final Uri phoneNumberUrl = Uri(scheme: 'tel', path: phoneNumber);

    try {
      if (await UrlLauncher.canLaunchUrl(phoneNumberUrl)) {
        await UrlLauncher.launchUrl(phoneNumberUrl);
      } else {
        debugPrint("launchUrlCall() Could not launch $phoneNumberUrl");
        return false;
      }
    } catch (e) {
      debugPrint("launchUrlCall() Exception ${e.toString()}");
      return false;
    }

    return true;
  }

  static int weekOfYear(DateTime date) {
    DateTime monday = weekStart(date);
    DateTime first = weekYearStartDate(monday.year);

    int week = 1 + (monday.difference(first).inDays / 7).floor();

    if (week == 53 && DateTime(monday.year, 12, 31).weekday < 4) {
      week = 1;
    }

    return week;
  }

  static int weekOfYearEx(String date) {
    DateTime day = weekStart(
        DateTime(int.parse(date.substring(0, 4)), int.parse(date.substring(4, 6)), int.parse(date.substring(6, 8))));
    return weekOfYear(day);
  }

  static DateTime weekStart(DateTime date) {
    DateTime monday = DateTime.utc(date.year, date.month, date.day);
    monday = monday.subtract(Duration(days: monday.weekday - 1));

    return monday;
  }

  static DateTime weekYearStartDate(int year) {
    final firstDayOfYear = DateTime.utc(year, 1, 1);
    final dayOfWeek = firstDayOfYear.weekday;

    return firstDayOfYear.add(Duration(days: (dayOfWeek <= DateTime.thursday ? 1 : 8) - dayOfWeek));
  }

  static String dateTimeToDateStr(DateTime date) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    return "$year${month > 9 ? month : "0$month"}${day > 9 ? day : "0$day"}";
  }

  static int getMaxDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static String getTimeString(int? time) {
    if (time == null) {
      return "00:00:00";
    }

    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = time % 60;

    // Format each value as a 2-digit string using padLeft
    String hoursStr = hours.toString().padLeft(2, '0');
    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');

    return "$hoursStr:$minutesStr:$secondsStr";
  }

  static List<double> calcPOS(double a, double b) {
    double c, d;
    double tempA = a;
    double tempB = -b;

    double offsetXWorld = 237.0 / 20.0;
    double offsetYWorld = 706.0 / 20.0;

    double scaleFactor = 8.9763;

    c = (tempA + offsetXWorld) * scaleFactor;
    d = (tempB + offsetYWorld) * scaleFactor;

    return [c, d];
  }
}
