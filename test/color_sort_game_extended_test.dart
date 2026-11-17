import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/game/color_sort_game.dart';
import 'package:game_003_color_sort_puzzle/game/sort_levels.dart';
import 'package:game_003_color_sort_puzzle/game/color_sort_solver.dart';

void main() {
  test('a move carries exactly one ball, never a stack', () {
    final game = ColorSortGame(<List<int>>[<int>[2,2,2], <int>[], <int>[]]);
    expect(game.move(0, 1), isTrue);
    expect(game.tubes[0], <int>[2,2]);
    expect(game.tubes[1], <int>[2]);
    expect(game.moves, 1);
  });
  test('mismatched color, full tube and invalid indexes are refused', () {
    final game = ColorSortGame(<List<int>>[<int>[0], <int>[1,1,1,1], <int>[]]);
    final original = game.snapshot();
    expect(game.move(0, 1), isFalse);
    expect(game.move(-1, 2), isFalse);
    expect(game.move(0, 0), isFalse);
    expect(game.snapshot(), original);
    expect(game.moves, 0);
  });
  test('undo, reset and restored snapshot remain independent', () {
    final initial = SortLevels.get(0);
    final game = ColorSortGame(initial);
    expect(game.move(0, 2), isTrue);
    expect(game.undo(), isTrue);
    expect(game.snapshot(), initial);
    expect(game.canUndo, isFalse);
    final snapshot = game.snapshot();
    snapshot[0][0] = 99;
    expect(game.snapshot(), initial);
    expect(game.move(0, 2), isTrue);
    game.reset(initial);
    expect(game.moves, 0);
    expect(game.snapshot(), initial);
  });
  test('all levels preserve four of each color and have a winning sequence', () {
    for (var i=0; i < SortLevels.count; i++) {
      final board = SortLevels.get(i);
      final histogram = <int,int>{};
      for (final color in board.expand((tube) => tube)) {
        histogram[color] = (histogram[color] ?? 0) + 1;
      }
      expect(histogram.values.every((total) => total == 4), isTrue);
      final solution = ColorSortSolver.solve(board);
      expect(solution, isNotNull, reason: 'Level $i lacks a solution');
      final game = ColorSortGame(board);
      for (final pair in solution!) { expect(game.move(pair.$1,pair.$2), isTrue); }
      expect(game.solved, isTrue);
    }
  });
  test('solver leaves its input unchanged', () {
    final board = SortLevels.get(3);
    final frozen = board.map((tube)=>List<int>.of(tube)).toList();
    ColorSortSolver.hint(board);
    expect(board, frozen);
  });
}
