import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/core/level_plan.dart';
import 'package:game_003_color_sort_puzzle/game/rules.dart';
import 'package:game_003_color_sort_puzzle/game/sort_engine.dart';

void main() {
  final rules = createRules() as SortRules;
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  SortLevel lvl(List<List<int>> tubes, {int cap = 4, bool hidden = false}) => SortLevel(
        capacity: cap,
        tubes: tubes,
        hidden: hidden,
        pourAll: rules.pourAll,
        timeLimit: 0,
        seed: 1,
        difficulty: 1,
        colors: 2,
      );

  test('move rules: same color or empty, capacity, completed tubes locked', () {
    final g = SortGame(lvl([
      [0, 1, 0, 1],
      [1, 0, 1, 0],
      [],
    ]));
    expect(g.canMove(0, 2), isTrue);
    expect(g.canMove(0, 1), isFalse, reason: 'tube 1 is full');
    expect(g.move(0, 2), 1);
    expect(g.canMove(1, 2), isFalse, reason: 'different top color');
    expect(g.canMove(1, 0), isTrue);
  });

  test('pour moves the whole run (water) or one ball (balls)', () {
    final g = SortGame(lvl([
      [0, 1, 1],
      [],
    ]));
    final n = g.move(0, 1);
    expect(n, rules.pourAll ? 2 : 1);
  });

  test('win detection and undo', () {
    final g = SortGame(lvl([
      [0, 0, 0],
      [0],
      [1, 1, 1, 1],
    ]));
    expect(g.won, isFalse);
    g.move(1, 0);
    expect(g.won, isTrue);
    g.undo();
    expect(g.won, isFalse);
  });

  test('hidden colors are revealed when they reach the top', () {
    final g = SortGame(lvl([
      [0, 1, 0, 1],
      [1, 0, 1, 0],
      [],
      [],
    ], hidden: true));
    expect(g.isHidden(0, 2), isTrue);
    g.move(0, 2);
    expect(g.isHidden(0, 2), isFalse);
  });

  test('hint follows a real solution to the end', () {
    final g = SortGame(rules.finalize(rules.build(planner.spec(40))));
    var guard = 0;
    while (!g.won && guard++ < 400) {
      final m = g.hint();
      expect(m, isNotNull);
      expect(g.move(m!.from, m.to), greaterThan(0));
    }
    expect(g.won, isTrue);
  });

  test('resume restores the exact state', () {
    final l = rules.finalize(rules.build(planner.spec(12)));
    final g = SortGame(l);
    final m = g.hint()!;
    g.move(m.from, m.to);
    expect(SortGame.restore(l, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..150 solvable, sample to 50.000', () {
    for (var n = 1; n <= 150; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
    for (var n = 2000; n <= 50000; n += 4800) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
