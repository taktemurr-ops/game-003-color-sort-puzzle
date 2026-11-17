import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/game/game_mode.dart';
import 'package:game_003_color_sort_puzzle/game/sort_levels.dart';
import 'package:game_003_color_sort_puzzle/game/color_sort_game.dart';
import 'package:game_003_color_sort_puzzle/game/color_sort_solver.dart';

void main() {
  test('all campaign levels have a verified winning path', () {
    expect(SortLevels.count, 120);
    for (var i = 0; i < SortLevels.count; i++) {
      final level = SortLevels.get(i);
      final solution = ColorSortSolver.solve(level);
      expect(solution, isNotNull, reason: 'Level $i must be solvable');
      final game = ColorSortGame(level);
      for (final move in solution!) {
        expect(game.move(move.$1, move.$2), isTrue);
      }
      expect(game.solved, isTrue, reason: 'Level $i path must win');
    }
  });

  test('solver is deterministic and does not mutate source board', () {
    final board = SortLevels.get(2);
    final before = board.map((tube) => List<int>.of(tube)).toList();
    final a = ColorSortSolver.solve(board);
    final b = ColorSortSolver.solve(board);
    expect(a, b);
    expect(board, before);
  });

  test('undo does not modify a non-existent history', () {
    final game = ColorSortGame(SortLevels.get(0));
    expect(game.undo(), isFalse);
    expect(game.moves, 0);
  });

  test('invalid ball moves never mutate game board or move counter', () {
    final game = ColorSortGame(SortLevels.get(0));
    final copy = game.snapshot();
    expect(game.move(-1, 0), isFalse);
    expect(game.move(0, 100), isFalse);
    expect(game.move(0, 0), isFalse);
    expect(game.moves, 0);
    expect(game.snapshot(), copy);
  });

  test('reset restores the exact initial board', () {
    final initial = SortLevels.get(0);
    final game = ColorSortGame(initial);
    game.move(0, 2);
    game.reset(initial);
    expect(game.tubes, initial);
    expect(game.canUndo, isFalse);
    expect(game.moves, 0);
  });

  test('multiple restores do not share mutable tube lists', () {
    final a = SortLevels.get(2);
    final b = SortLevels.get(2);
    a[0][0] = 99;
    expect(a, isNot(equals(b)));
  });

  test('timed and daily modes have distinct rules', () {
    expect(GameMode.timed.limitSeconds, 180);
    expect(GameMode.classic.limitSeconds, isNull);
    expect(GameMode.daily.allowsHints, isFalse);
    expect(GameMode.zen.allowsHints, isTrue);
  });

  test('invalid boards are rejected', () {
    expect(() => ColorSortGame(<List<int>>[<int>[]]), throwsArgumentError);
    expect(() => ColorSortGame(<List<int>>[<int>[100], <int>[]]), throwsArgumentError);
    expect(() => ColorSortGame(<List<int>>[<int>[-1], <int>[]]), throwsArgumentError);
  });
}
