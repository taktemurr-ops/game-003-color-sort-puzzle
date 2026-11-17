import 'color_sort_game.dart';

/// Stateful breadth-first solver with a fixed exploration budget.
/// Returns an executable next step or null when the search limit is reached.
class ColorSortSolver {
  static const int defaultMaxStates = 120000;

  /// All moves in a shortest known solution, up to [maxStates].
  /// Empty list means already solved; null means no solution found within limit.
  static List<(int, int)>? solve(List<List<int>> initial,
      {int maxStates = defaultMaxStates}) {
    if (maxStates < 1) { throw ArgumentError.value(maxStates, 'maxStates'); }
    final start = ColorSortGame(initial);
    if (start.solved) { return <(int, int)>[]; }
    final queue = <_Node>[_Node(start.snapshot(), const <(int, int)>[])];
    final visited = <String>{_canonicalKey(start.tubes)};
    for (var head = 0; head < queue.length; head++) {
      final node = queue[head];
      final game = ColorSortGame(node.board);
      final visitedEmptyDestinationForSource = <int>{};
      for (final move in game.legalMoves) {
        final source = game.tubes[move.$1];
        final destination = game.tubes[move.$2];
        if (destination.isEmpty) {
          // Empty tubes are interchangeable; skip equivalent choices.
          if (!visitedEmptyDestinationForSource.add(move.$1)) { continue; }
          if (source.length == ColorSortGame.capacity &&
              source.every((color) => color == source.first)) { continue; }
        }
        final next = ColorSortGame(game.snapshot());
        if (!next.move(move.$1, move.$2)) { continue; }
        final path = <(int, int)>[...node.path, move];
        if (next.solved) { return path; }
        final key = _canonicalKey(next.tubes);
        if (!visited.add(key)) { continue; }
        if (visited.length >= maxStates) { return null; }
        queue.add(_Node(next.snapshot(), path));
      }
    }
    return null;
  }

  static (int, int)? hint(List<List<int>> initial,
      {int maxStates = defaultMaxStates}) {
    final answer = solve(initial, maxStates: maxStates);
    return answer == null || answer.isEmpty ? null : answer.first;
  }

  // Color labels remain significant; tube positions do not.
  static String _canonicalKey(List<List<int>> board) {
    final tubes = board.map((tube) => tube.join(',')).toList()..sort();
    return tubes.join('|');
  }
}

class _Node {
  final List<List<int>> board;
  final List<(int, int)> path;
  const _Node(this.board, this.path);
}
