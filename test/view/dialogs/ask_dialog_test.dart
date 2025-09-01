// test/view/dialogs/ask_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/dialogs/ask_dialog.dart';

void main() {
  Widget buildTestApp({required Widget child}) {
    return GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    // Fire off the dialog
                    showDialog<String>(
                      context: context,
                      builder: (BuildContext _) => child,
                    ).then((String? result) {
                      // nothing
                    });
                  },
                  child: const Text('OPEN'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  testWidgets('shows only message and default buttons when only message is provided', (WidgetTester tester) async {
    // arrange
    const String testMessage = 'Are you sure?';

    await tester.pumpWidget(buildTestApp(child: const AskDialog(message: testMessage)));

    // act: open the dialog
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // assert: primary message appears
    expect(find.text(testMessage), findsOneWidget);

    // no addMessage
    expect(find.byKey(const Key('addMessage')), findsNothing);

    // default button labels
    expect(find.text('예'), findsOneWidget);
    expect(find.text('아니요'), findsOneWidget);
  });

  testWidgets('shows both message and addMessage when addMessage is non-empty', (WidgetTester tester) async {
    // arrange
    const String mainMessage = 'Delete all items?';
    const String additional = 'This cannot be undone.';

    await tester.pumpWidget(buildTestApp(
      child: const AskDialog(
        message: mainMessage,
        addMessage: additional,
      ),
    ));

    // act
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // assert
    expect(find.text(mainMessage), findsOneWidget);
    expect(find.text(additional), findsOneWidget);
  });

  testWidgets('uses custom leftText and rightText when provided', (WidgetTester tester) async {
    // arrange
    const String left = '👍 Yes';
    const String right = '👎 No';

    await tester.pumpWidget(buildTestApp(
      child: const AskDialog(
        message: 'Pick one',
        leftText: left,
        rightText: right,
      ),
    ));

    // act
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // assert
    expect(find.text(left), findsOneWidget);
    expect(find.text(right), findsOneWidget);
  });

  testWidgets('tapping left button pops with result "LEFT"', (WidgetTester tester) async {
    // arrange
    String? capturedResult;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext _) => const AskDialog(message: 'Confirm?'),
                ).then((String? result) {
                  capturedResult = result;
                });
              },
              child: const Text('OPEN'),
            );
          }),
        ),
      ),
    );

    // act
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('예'));
    await tester.pumpAndSettle();

    // assert
    expect(capturedResult, 'LEFT');
  });

  testWidgets('tapping right button pops with result "RIGHT"', (WidgetTester tester) async {
    // arrange
    String? capturedResult;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext _) => const AskDialog(message: 'Confirm?'),
                ).then((String? result) {
                  capturedResult = result;
                });
              },
              child: const Text('OPEN'),
            );
          }),
        ),
      ),
    );

    // act
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('아니요'));
    await tester.pumpAndSettle();

    // assert
    expect(capturedResult, 'RIGHT');
  });
}
