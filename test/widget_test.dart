import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_003_color_sort_puzzle/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home starts playable classic mode on phone', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ColorSortPuzzle());
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-classic')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mode-classic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game')), findsOneWidget);
    expect(find.byKey(const ValueKey('tube-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('hint')), findsOneWidget);
  });

  testWidgets('tapping a tube selects it and hint is shown', (tester) async {
    await tester.pumpWidget(const ColorSortPuzzle());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-classic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tube-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('hint')));
    await tester.tap(find.byKey(const ValueKey('hint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game')), findsOneWidget);
  });
}
