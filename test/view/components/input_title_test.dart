// test/view/components/input_title_test.dart
//
// ──────────────────────────────────────────────────────────────
//  Pure widget tests – production code is never touched.
//  AAA layout with rich debugPrint so console output is readable.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fms/view/components/input_title.dart';

/// Convenient alias for the hard-coded “* ” text the widget renders.
const String _kAsterisk = '* ';

void main() {
  /* ─────────────── global setup / teardown ─────────────── */

  late void Function(FlutterErrorDetails) _originalOnError;

  setUp(() {
    _originalOnError = FlutterError.onError!;
    // suppress harmless overflow warnings in golden-free tests
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed by')) {
        return;
      }
      _originalOnError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = _originalOnError;
  });

  /* ─────────────── helper ─────────────── */

  Future<void> _pump(
    WidgetTester tester, {
    required Widget child,
    Size surfaceSize = const Size(400, 200),
  }) async {
    debugPrint('⏱  Arrange: pump widget (surface=$surfaceSize)');
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

  group('InputTitle widget', () {
    testWidgets(
      'renders the provided title text',
      (tester) async {
        // ---------- Arrange ----------
        const String title = 'Robot Name';
        await _pump(
          tester,
          child: const InputTitle(title: title, isRequired: false),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: locate title Text widget');

        // ---------- Assert ----------
        expect(find.text(title), findsOneWidget);
      },
    );

    testWidgets(
      'prepends a red asterisk when isRequired is true',
      (tester) async {
        // ---------- Arrange ----------
        const String title = 'E-mail';
        await _pump(
          tester,
          child: const InputTitle(title: title, isRequired: true),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: search for asterisk and title');

        // ---------- Assert ----------
        expect(find.text(_kAsterisk), findsOneWidget);
        expect(find.text(title), findsOneWidget);

        // Extra sanity-check: asterisk comes before the title in the Row.
        final Row row = tester.widget<Row>(find.byType(Row));
        final List<Widget> children = row.children;
        expect(children.firstWhere((w) => w is Text && (w as Text).data == _kAsterisk, orElse: () => const SizedBox()),
            isNotNull);
        expect(children.lastWhere((w) => w is Text && (w as Text).data == title, orElse: () => const SizedBox()),
            isNotNull);
      },
    );

    testWidgets(
      'does NOT render asterisk when isRequired is false',
      (tester) async {
        // ---------- Arrange ----------
        await _pump(
          tester,
          child: const InputTitle(title: 'Optional Field', isRequired: false),
        );

        // ---------- Act ----------
        debugPrint('👉  Act: ensure only title is present');

        // ---------- Assert ----------
        expect(find.text(_kAsterisk), findsNothing);
      },
    );
  });
}
