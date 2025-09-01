// test/view/components/layout_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/view/components/layout.dart';

void main() {
  group('LayoutExt on BuildContext', () {
    // Utility to get a BuildContext with specified screen width
    Future<BuildContext> _getContext(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: MaterialApp(
            home: Builder(
              key: const ValueKey('test-context'),
              builder: (BuildContext context) {
                return Container();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder finder = find.byKey(const ValueKey('test-context'));
      final Element element = tester.element(finder);
      return element;
    }

    testWidgets('isMobile returns true below kMobileWidth', (WidgetTester tester) async {
      final BuildContext ctx = await _getContext(tester, kMobileWidth - 1.0);

      expect(ctx.isMobile(), isTrue);
      expect(ctx.isTablet(), isFalse);
      expect(ctx.isDesktop(), isFalse);
    });

    testWidgets('isTablet returns true between kMobileWidth and kTabletWidth', (WidgetTester tester) async {
      final double mid = (kMobileWidth + kTabletWidth) / 2.0;
      final BuildContext ctx = await _getContext(tester, mid);

      expect(ctx.isMobile(), isFalse);
      expect(ctx.isTablet(), isTrue);
      expect(ctx.isDesktop(), isFalse);
    });

    testWidgets('isDesktop returns true at or above kTabletWidth', (WidgetTester tester) async {
      final BuildContext ctx = await _getContext(tester, kTabletWidth + 10.0);

      expect(ctx.isMobile(), isFalse);
      expect(ctx.isTablet(), isFalse);
      expect(ctx.isDesktop(), isTrue);
    });

    testWidgets('layout picks mobile override when below kMobileWidth', (WidgetTester tester) async {
      const String base = 'base';
      const String mobile = 'm';
      const String tablet = 't';
      const String desktop = 'd';

      final BuildContext ctx = await _getContext(tester, kMobileWidth - 0.5);
      final String result = ctx.layout<String>(
        base,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
      expect(result, equals(mobile));
    });

    testWidgets('layout picks tablet override when between widths', (WidgetTester tester) async {
      const String base = 'base';
      const String mobile = 'm';
      const String tablet = 't';
      const String desktop = 'd';
      final double mid = (kMobileWidth + kTabletWidth) / 2.0;

      final BuildContext ctx = await _getContext(tester, mid);
      final String result = ctx.layout<String>(
        base,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
      expect(result, equals(tablet));
    });

    testWidgets('layout picks desktop override when at least kTabletWidth', (WidgetTester tester) async {
      const String base = 'base';
      const String mobile = 'm';
      const String tablet = 't';
      const String desktop = 'd';

      final BuildContext ctx = await _getContext(tester, kTabletWidth + 1.0);
      final String result = ctx.layout<String>(
        base,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
      expect(result, equals(desktop));
    });

    testWidgets('layout falls back to base when no override provided', (WidgetTester tester) async {
      const String base = 'base';
      const String mobile = 'm';
      const String tablet = 't';
      const String desktop = 'd';

      // mobile branch
      final BuildContext ctxMobile = await _getContext(tester, kMobileWidth - 0.5);
      final String resultMobile = ctxMobile.layout<String>(
        base,
        tablet: tablet,
        desktop: desktop,
      );
      expect(resultMobile, equals(base));

      // tablet branch
      final double mid = (kMobileWidth + kTabletWidth) / 2.0;
      final BuildContext ctxTablet = await _getContext(tester, mid);
      final String resultTablet = ctxTablet.layout<String>(
        base,
        mobile: mobile,
        desktop: desktop,
      );
      expect(resultTablet, equals(base));

      // desktop branch
      final BuildContext ctxDesktop = await _getContext(tester, kTabletWidth + 1.0);
      final String resultDesktop = ctxDesktop.layout<String>(
        base,
        mobile: mobile,
        tablet: tablet,
      );
      expect(resultDesktop, equals(base));
    });
  });
}
