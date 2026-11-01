import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordblocks/main.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const WordBlocksApp());
  // Asset and preference loading run on real async I/O, outside the test's fake clock.
  for (var i = 0; i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('explore: open a root and one of its words', (tester) async {
    await pumpApp(tester);
    expect(find.text('今日字根'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('explore-search')), 'struct');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'struct'));
    await tester.pumpAndSettle();
    expect(find.text('struct / stroy'), findsOneWidget);

    await tester.ensureVisible(find.text('摧毀'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('摧毀'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The storm destroyed'), findsOneWidget);
  });

  testWidgets('split: reviewed word and a guessed word', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('拆解').last);
    await tester.pumpAndSettle();
    expect(find.text('詞庫收錄'), findsOneWidget); // progressive is pre-filled

    await tester.enterText(find.byKey(const Key('split-input')), 'transportation');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('自動推測'), findsOneWidget);
    expect(find.text('ation'), findsOneWidget);
  });

  testWidgets('review: answer a new card and grade it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('複習'));
    await tester.pumpAndSettle();
    expect(find.text('新卡'), findsOneWidget);

    await tester.tap(find.text('顯示答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('良好'));
    await tester.pumpAndSettle();
    expect(find.text('已學會'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // learned count
  });

  testWidgets('puzzle: build forewarn from blocks', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('積木'));
    await tester.pumpAndSettle();
    expect(find.text('預先警告'), findsOneWidget);

    Finder block(String text) => find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;
    await tester.tap(block('fore'));
    await tester.pump();
    await tester.tap(block('warn').last);
    await tester.pump();
    await tester.tap(find.text('檢查'));
    await tester.pumpAndSettle();
    expect(find.textContaining('拼對了'), findsOneWidget);
    expect(find.textContaining('premonition'), findsOneWidget);
  });
}
