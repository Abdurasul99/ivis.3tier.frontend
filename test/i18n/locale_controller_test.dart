// Language selection: Korean by default, saved choice restored, live switch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ivis/i18n/app_locale.dart';
import 'package:ivis/view/components/app_language_toggle.dart';
import 'package:ivis/viewmodel/controller/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Get.updateLocale() rebuilds the tree through performReassemble(), which in
// the test binding paints its own warm-up frame. Wait for that frame to end
// (post-frame callback) before pumping, so the two frames never overlap.
Future<void> _waitForLocaleRebuild(WidgetTester tester) async {
  final Completer<void> rebuilt = Completer<void>();
  tester.binding.addPostFrameCallback((_) {
    if (!rebuilt.isCompleted) rebuilt.complete();
  });
  await rebuilt.future;
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
    Get.locale = null;
  });

  group('LocaleController.loadSavedLocale', () {
    test('defaults to Korean when nothing is saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final LocaleController controller = LocaleController();

      await controller.loadSavedLocale();

      expect(controller.locale, LocaleController.korean);
      expect(controller.isKorean, isTrue);
      expect(Get.locale?.languageCode, 'ko');
      expect(t('차량'), '차량');
    });

    test('restores a saved English choice', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'localeCode': 'en'});
      final LocaleController controller = LocaleController();

      await controller.loadSavedLocale();

      expect(controller.locale, LocaleController.english);
      expect(controller.isEnglish, isTrue);
      expect(Get.locale?.languageCode, 'en');
      expect(t('차량'), 'Vehicle');
    });

    test('falls back to Korean for an unknown saved code', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'localeCode': 'fr'});
      final LocaleController controller = LocaleController();

      await controller.loadSavedLocale();

      expect(controller.locale, LocaleController.korean);
    });
  });

  testWidgets('toggle switches the language live and persists the choice',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final LocaleController controller = Get.put(LocaleController());
    await controller.loadSavedLocale();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const AppLanguageToggle(compact: true),
              // Plain build-time translation, no explicit listener
              Builder(builder: (_) => Text(t('대시보드'))),
            ],
          ),
        ),
      ),
    );
    expect(find.text('대시보드'), findsOneWidget);

    await tester.tap(find.text('English'));
    await _waitForLocaleRebuild(tester);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(controller.isEnglish, isTrue);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('localeCode'), 'en');

    await tester.tap(find.text('한국어'));
    await _waitForLocaleRebuild(tester);

    expect(find.text('대시보드'), findsOneWidget);
    expect(prefs.getString('localeCode'), 'ko');
  });

  group('server messages', () {
    test('backend activity event texts are translated by pattern', () {
      Get.locale = LocaleController.english;

      expect(t('차량 3 온라인 복귀'), 'Vehicle 3 back online');
      expect(t('차량 12 → 대구역 도착'), 'Vehicle 12 arrived at Daegu Station');
      expect(t('인프라 2 오프라인'), 'Infra 2 offline');
      expect(t('속도 42.5 km/h'), 'Speed 42.5 km/h');
      expect(t('텔레메트리 수신 중단'), 'Telemetry stopped');
      // Unknown text (user data) is returned unchanged
      expect(t('대구광역시 중구 태평로 141'), '대구광역시 중구 태평로 141');
    });

    test('Korean mode keeps server texts and localizes known English errors', () {
      Get.locale = LocaleController.korean;

      expect(t('차량 3 온라인 복귀'), '차량 3 온라인 복귀');
      expect(serverText('Code expired'), '인증번호가 만료되었습니다.');
      expect(serverText('Something new'), 'Something new');

      Get.locale = LocaleController.english;
      expect(serverText('Code expired'), 'Code expired');
    });
  });
}
