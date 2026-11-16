import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/game/color_sort_game.dart';

void main() {
  test('one ball moves per turn', () {
    final game = ColorSortGame([[1, 1], [], []]);
    expect(game.move(0, 1), true);
    expect(game.tubes[0], [1]);
    expect(game.tubes[1], [1]);
    expect(game.moves, 1);
  });
  test('different colors may not mix', () {
    final game = ColorSortGame([[1], [2], []]);
    expect(game.move(0, 1), false);
  });
  test('moves are reversible', () {
    final game = ColorSortGame([[1], [], []]);
    game.move(0, 1);
    expect(game.undo(), true);
    expect(game.tubes, [[1], <int>[], <int>[]]);
    expect(game.moves, 0);
  });
  test('winning state has only full single-color tubes', () {
    expect(ColorSortGame([[1, 1, 1, 1], []]).solved, true);
    expect(ColorSortGame([[1, 1], []]).solved, false);
  });
  test('legal move hints do not mutate the board', () {
    final game = ColorSortGame([[1], [], [2]]);
    final before = game.tubes.map((t) => List<int>.from(t)).toList();
    expect(game.legalMoves, contains((0, 1)));
    expect(game.legalMoves, isNot(contains((0, 2))));
    expect(game.tubes, before);
    expect(game.moves, 0);
  });

}
