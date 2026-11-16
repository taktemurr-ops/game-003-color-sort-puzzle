import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/main.dart';

void main() {
  testWidgets('Color Sort Puzzle initial screen renders on a phone', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ColorSortPuzzle());
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Color Sort Puzzle'), findsOneWidget);
  });
}
