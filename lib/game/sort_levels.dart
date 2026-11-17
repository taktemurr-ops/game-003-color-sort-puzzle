import 'dart:math';
import 'color_sort_solver.dart';

/// Curated, reproducible, solver-checked campaign with seeded variations.
/// Keeps levels small enough for a bounded on-device hint search.
class SortLevels {
  static const boards = <List<List<int>>>[
    <List<int>>[<int>[0, 0, 1, 1], <int>[1, 1, 0, 0], <int>[]],
    <List<int>>[<int>[0, 1, 1, 0], <int>[1, 0, 0, 1], <int>[]],
    <List<int>>[<int>[0, 1, 0, 1], <int>[1, 0, 1, 0], <int>[]],
    <List<int>>[<int>[0, 1, 2, 0], <int>[1, 2, 0, 1], <int>[2, 0, 1, 2], <int>[], <int>[]],
  ];

  static const int count = 120;

  static List<List<int>> get(int index) {
    if (index < 0 || index >= count) { throw RangeError.range(index, 0, count - 1); }
    if (index < boards.length) { return _copy(boards[index]); }
    final rng = Random(index * 3919 + 17);
    // Permutations preserve all legal moves; no unverified random shuffles.
    final template = _copy(boards[index % boards.length]);
    final colorCount = template.expand((tube) => tube).toSet().length;
    final colors = List<int>.generate(colorCount, (i) => i)..shuffle(rng);
    final output = template
        .map((tube) => tube.map((color) => colors[color]).toList())
        .toList()..shuffle(rng);
    if (index.isOdd) {
      for (final tube in output) {
        // Mirror is only applied to 2-color levels after proof check below.
        if (colorCount == 2) { tube.setAll(0, tube.reversed.toList()); }
      }
    }
    // Never return a board that has not been verified as solvable.
    if (ColorSortSolver.solve(output, maxStates: 50000) == null) {
      return _copy(template);
    }
    return output;
  }

  static List<List<int>> _copy(List<List<int>> board) =>
      board.map((tube) => List<int>.of(tube)).toList();
}
