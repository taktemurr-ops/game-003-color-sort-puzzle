/// Color Sort Puzzle -- one-ball-at-a-time logic independent of Flutter.
/// Tube contents are stored bottom-to-top. All snapshots own their lists.
class ColorSortGame {
  static const int capacity = 4;
  final List<List<int>> tubes;
  final List<List<List<int>>> _history = <List<List<int>>>[];
  int moves = 0;

  ColorSortGame(List<List<int>> initial)
      : tubes = initial.map((tube) => List<int>.of(tube)).toList() {
    _validate(initial);
  }

  static void _validate(List<List<int>> initial) {
    if (initial.length < 2 || initial.length > 8 ||
        initial.any((tube) => tube.length > capacity ||
            tube.any((color) => color < 0 || color > 99))) {
      throw ArgumentError('Invalid tube puzzle: 2-8 tubes, 0-4 balls each, color IDs 0..99.');
    }
  }

  factory ColorSortGame.demo() => ColorSortGame(<List<int>>[
    <int>[0, 1, 0, 1], <int>[1, 0, 1, 0], <int>[],
  ]);

  bool get solved => tubes.every((tube) => tube.isEmpty ||
      (tube.length == capacity && tube.every((ball) => ball == tube.first)));
  bool get canUndo => _history.isNotEmpty;
  int get usedColors => tubes.expand((tube) => tube).toSet().length;
  int get totalLayers => tubes.fold(0, (sum, tube) => sum + tube.length);

  bool canMove(int from, int to) {
    if (from == to || from < 0 || to < 0 ||
        from >= tubes.length || to >= tubes.length) { return false; }
    final source = tubes[from];
    final target = tubes[to];
    if (source.isEmpty || target.length >= capacity) { return false; }
    return target.isEmpty || target.last == source.last;
  }

  List<(int, int)> get legalMoves {
    final result = <(int, int)>[];
    for (var from = 0; from < tubes.length; from++) {
      for (var to = 0; to < tubes.length; to++) {
        if (canMove(from, to)) { result.add((from, to)); }
      }
    }
    return result;
  }

  /// Moves precisely one ball, even when the source has several same-color balls.
  bool move(int from, int to) {
    if (!canMove(from, to)) { return false; }
    _history.add(snapshot());
    if (_history.length > 500) { _history.removeAt(0); }
    tubes[to].add(tubes[from].removeLast());
    moves++;
    return true;
  }

  List<List<int>> snapshot() => tubes.map((tube) => List<int>.of(tube)).toList();

  bool undo() {
    if (_history.isEmpty) { return false; }
    _replaceBoard(_history.removeLast());
    moves--;
    return true;
  }

  void reset(List<List<int>> initial) {
    _validate(initial);
    if (initial.length != tubes.length) { throw ArgumentError('Tube count changed.'); }
    _replaceBoard(initial);
    _history.clear();
    moves = 0;
  }

  void _replaceBoard(List<List<int>> replacement) {
    for (var i = 0; i < tubes.length; i++) {
      tubes[i]..clear()..addAll(replacement[i]);
    }
  }
}
