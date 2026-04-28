import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../repository/local_repository.dart';

class LocaleController extends GetxController {
  static const Locale korean = Locale('ko', 'KR');
  static const Locale english = Locale('en', 'US');

  final LocalRepository _localRepository = LocalRepository();

  Locale _locale = korean;

  Locale get locale => _locale;
  bool get isKorean => _locale.languageCode == 'ko';
  bool get isEnglish => _locale.languageCode == 'en';

  Future<void> loadSavedLocale() async {
    // 항상 한국어 고정 (영어 토글 제거됨)
    _locale = korean;
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    await _localRepository.saveLocaleCode(locale.languageCode);
    await Get.updateLocale(locale);
    update();
  }
}
