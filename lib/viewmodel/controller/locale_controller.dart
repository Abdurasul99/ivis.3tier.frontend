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

  // Restores the saved language (shared_preferences). Korean when nothing is
  // saved or the saved value is unknown. Get.locale is set right away so that
  // t()/l10n() already resolve correctly before the first frame.
  Future<void> loadSavedLocale() async {
    final String savedCode = await _localRepository.getLocaleCode();
    _locale = savedCode == english.languageCode ? english : korean;
    Get.locale = _locale;
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    await _localRepository.saveLocaleCode(locale.languageCode);
    // Get.updateLocale rebuilds the whole widget tree; update() refreshes the
    // GetBuilder<LocaleController> listeners (toggle, cached grid labels).
    await Get.updateLocale(locale);
    update();
  }
}
