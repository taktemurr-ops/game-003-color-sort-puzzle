/// Color Sort Puzzle: move one top ball between capacity-4 tubes.
/// Contents are stored bottom to top; the last element is the top ball.
class ColorSortGame {
  static const int capacity = 4;
  final List<List<int>> tubes;
  final List<List<List<int>>> history = [];
  int moves = 0;

  ColorSortGame(List<List<int>> initial)
      : tubes = initial.map((tube) => List<int>.from(tube)).toList() {
    if (tubes.any((tube) => tube.length > capacity || tube.any((c) => c < 0))) {
      throw ArgumentError('Invalid tube');
    }
  }

  factory ColorSortGame.demo() => ColorSortGame([
    [0, 1, 0, 1], [1, 0, 1, 0], [],
  ]);

  /// Legal source/destination pairs for hint UI; does not mutate game state.
  List<(int, int)> get legalMoves {
    final result = <(int, int)>[];
    for (var from = 0; from < tubes.length; from++) {
      for (var to = 0; to < tubes.length; to++) {
        if (canMove(from, to)) result.add((from, to));
      }
    }
    return result;
  }

  bool canMove(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= tubes.length || to >= tubes.length) {
      return false;
    }
    if (tubes[from].isEmpty || tubes[to].length == capacity) return false;
    return tubes[to].isEmpty || tubes[to].last == tubes[from].last;
  }

  bool move(int from, int to) {
    if (!canMove(from, to)) return false;
    history.add(tubes.map((t) => List<int>.from(t)).toList());
    tubes[to].add(tubes[from].removeLast());
    moves++;
    return true;
  }

  bool undo() {
    if (history.isEmpty) return false;
    final previous = history.removeLast();
    for (var i = 0; i < tubes.length; i++) {
      tubes[i]..clear()..addAll(previous[i]);
    }
    moves--;
    return true;
  }

  bool get solved => tubes.every((tube) => tube.isEmpty ||
      (tube.length == capacity && tube.every((c) => c == tube.first)));
}
