// test/view/components/input_edit_text_test.dart
//
// ──────────────────────────────────────────────────────────────
//  Pure widget tests – no production code is modified.
//  AAA layout + verbose debugPrint for readable console logs.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/components/input_edit_text.dart';
import 'package:fms/constants/constants.dart';

const Color _kCustomBorderColor = Colors.purple;

void main() {
  /* ─────────────── global setup / teardown ─────────────── */

  late void Function(FlutterErrorDetails) _originalOnError;

  setUp(() {
    debugPrint('🛠  setUp – silence expected overflow warnings');
    _originalOnError = FlutterError.onError!;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed by')) {
        // Ignore visual overflow warnings inside tests.
        return;
      }
      _originalOnError(details); // Bubble up every other error.
    };
    Get.testMode = true;
  });

  tearDown(() {
    debugPrint('🧹  tearDown – restore FlutterError.onError');
    FlutterError.onError = _originalOnError;
    Get.reset();
    Get.clearRouteTree();
  });

  /* ─────────────── helper ─────────────── */

  Future<void> _pump(
    WidgetTester tester, {
    required Widget child,
    Size surfaceSize = const Size(400, 800),
  }) async {
    debugPrint('⏱  Arrange: pump widget, surfaceSize=$surfaceSize');
    await tester.binding.setSurfaceSize(surfaceSize);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  /* ─────────────── tests ─────────────── */

  group('InputEditText widget', () {
    testWidgets(
      'shows title, asterisk (when required) and error text',
      (tester) async {
        // ---------- Arrange ----------
        await _pump(
          tester,
          child: const InputEditText(
            title: 'Username',
            isRequired: true,
            errorText: 'Error!',
          ),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: initial frame – nothing to do');

        // ---------- Assert ----------
        expect(find.text('Username'), findsOneWidget);
        expect(find.text('* '), findsOneWidget);
        expect(find.text('Error!'), findsOneWidget);
      },
    );

    testWidgets(
      'draws bold border with a custom color',
      (tester) async {
        // ---------- Arrange ----------
        await _pump(
          tester,
          child: const InputEditText(
            isBoldBorder: true,
            borderColor: _kCustomBorderColor,
          ),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: inspect Container decoration');
        final BoxDecoration decoration =
            tester.widget<Container>(find.byType(Container).first).decoration as BoxDecoration;
        final Border border = decoration.border as Border;

        // ---------- Assert ----------
        expect(border.top.width, 2.5);
        expect(border.top.color, _kCustomBorderColor);
      },
    );

    testWidgets(
      'uses grey background in read-only mode',
      (tester) async {
        // ---------- Arrange ----------
        await _pump(
          tester,
          child: const InputEditText(
            isReadOnly: true,
          ),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: read Container background color');
        final BoxDecoration decoration =
            tester.widget<Container>(find.byType(Container).first).decoration as BoxDecoration;

        // ---------- Assert ----------
        expect(decoration.color, const Color(0xFFE2E2E2));
      },
    );

    testWidgets(
      'fires onChanged every time the text is updated',
      (tester) async {
        // ---------- Arrange ----------
        String? changed;
        await _pump(
          tester,
          child: InputEditText(
            onChanged: (v) {
              debugPrint('📢  onChanged="$v"');
              changed = v;
            },
          ),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: type "abc"');
        await tester.enterText(find.byType(TextFormField), 'abc');
        await tester.pumpAndSettle();

        // ---------- Assert ----------
        expect(changed, 'abc');
      },
    );

    testWidgets(
      'fires onSubmitted after the “done” keyboard action',
      (tester) async {
        // ---------- Arrange ----------
        String? submitted;
        await _pump(
          tester,
          child: InputEditText(
            controller: TextEditingController(text: 'done'),
            onSubmitted: (v) {
              debugPrint('📢  onSubmitted="$v"');
              submitted = v;
            },
          ),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: focus field and send done action');
        await tester.tap(find.byType(TextFormField));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // ---------- Assert ----------
        expect(submitted, 'done');
      },
    );

    testWidgets(
      'displays hint text with default style',
      (tester) async {
        // ---------- Arrange ----------
        const String hint = 'Enter value';
        await _pump(
          tester,
          child: const InputEditText(
            hintText: hint,
          ),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: locate hint text widget');
        final Finder hintFinder = find.text(hint);

        // ---------- Assert ----------
        expect(hintFinder, findsOneWidget);
        final Text hintTextWidget = tester.widget<Text>(hintFinder);
        expect(hintTextWidget.style!.color, kDarkGrayColor);
        expect(hintTextWidget.style!.fontWeight, FontWeight.w300);
      },
    );
  });
}
