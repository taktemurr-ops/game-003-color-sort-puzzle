/// Curated, solver-verified level packs shared by the two sorting variants.
/// Each level contains complete color sets (four of each color), with empty
/// buffer tubes. The Water and Ball rule engines use different move counts.
class SortLevels {
  static const boards = <List<List<int>>>[
    [[0, 0, 1, 1], [1, 1, 0, 0], []],
    [[0, 1, 1, 0], [1, 0, 0, 1], []],
    [[0, 1, 0, 1], [1, 0, 1, 0], []],
    [[0, 1, 2, 0], [1, 2, 0, 1], [2, 0, 1, 2], [], []],
  ];

  static List<List<int>> get(int index) {
    if (index < 0 || index >= boards.length) {
      throw RangeError.index(index, boards, 'index');
    }
    return boards[index].map((tube) => List<int>.from(tube)).toList();
  }

  static int get count => boards.length;
}
