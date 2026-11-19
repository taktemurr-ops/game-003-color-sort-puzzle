import '../core/level_plan.dart';
import '../core/rng.dart';

/// Shared sorting engine. [pourAll] = true: liquid (the whole top run of
/// one color pours at once, Water Sort). false: one ball per move.
class SortLevel {
  final int capacity;
  final List<List<int>> tubes;
  final bool hidden;
  final bool pourAll;
  final int timeLimit;
  final int seed;
  final int difficulty;
  final int colors;

  /// Length of the solver's solution (used for stars).
  final int solution;

  const SortLevel({
    required this.capacity,
    required this.tubes,
    required this.hidden,
    required this.pourAll,
    required this.timeLimit,
    required this.seed,
    required this.difficulty,
    required this.colors,
    this.solution = 0,
  });

  SortLevel withSolution(int s) => SortLevel(
        capacity: capacity,
        tubes: tubes,
        hidden: hidden,
        pourAll: pourAll,
        timeLimit: timeLimit,
        seed: seed,
        difficulty: difficulty,
        colors: colors,
        solution: s,
      );
}

class SortMove {
  final int from;
  final int to;
  const SortMove(this.from, this.to);
}

class SortGame {
  final SortLevel level;
  late List<List<int>> tubes;

  /// Number of hidden (unknown) segments counted from the bottom.
  late List<int> hiddenCount;
  int moves = 0;
  int extraTubes = 0;
  final List<String> _undo = [];

  SortGame(this.level) {
    tubes = level.tubes.map((t) => List.of(t)).toList();
    hiddenCount = tubes.map((t) => level.hidden ? (t.length - 1).clamp(0, 99) : 0).toList();
  }

  int get capacity => level.capacity;

  bool _complete(List<int> t) => t.length == capacity && t.every((c) => c == t.first);

  bool isComplete(int i) => _complete(tubes[i]);

  bool get won => tubes.every((t) => t.isEmpty || _complete(t));

  int _runLength(List<int> t) {
    if (t.isEmpty) return 0;
    var n = 1;
    for (var i = t.length - 2; i >= 0 && t[i] == t.last; i--) {
      n++;
    }
    return n;
  }

  bool canMove(int a, int b) {
    if (a == b || a < 0 || b < 0 || a >= tubes.length || b >= tubes.length) return false;
    final from = tubes[a], to = tubes[b];
    if (from.isEmpty || to.length >= capacity) return false;
    if (_complete(from)) return false;
    if (to.isNotEmpty && to.last != from.last) return false;
    return true;
  }

  /// Returns how many segments moved (0 = illegal).
  int move(int a, int b) {
    if (!canMove(a, b)) return 0;
    _undo.add(_snap());
    if (_undo.length > 50) _undo.removeAt(0);
    final from = tubes[a], to = tubes[b];
    var n = level.pourAll ? _runLength(from) : 1;
    n = n.clamp(1, capacity - to.length);
    for (var i = 0; i < n; i++) {
      to.add(from.removeLast());
    }
    // Reveal the new top of the source tube.
    if (hiddenCount[a] > from.length - 1) hiddenCount[a] = (from.length - 1).clamp(0, 99);
    moves++;
    if (_plan.isNotEmpty && _plan.first.from == a && _plan.first.to == b) {
      _plan = _plan.sublist(1);
      _planState = _tubesKey;
    } else {
      _plan = [];
    }
    return n;
  }

  bool get canUndo => _undo.isNotEmpty;

  void undo() {
    if (_undo.isEmpty) return;
    _restore(_undo.removeLast());
  }

  /// Booster: one more empty tube (max 1 per level).
  bool addTube() {
    if (extraTubes >= 1) return false;
    _undo.add(_snap());
    tubes.add(<int>[]);
    hiddenCount.add(0);
    extraTubes++;
    return true;
  }

  bool isHidden(int tube, int index) => index < hiddenCount[tube];

  List<SortMove> legalMoves() {
    final out = <SortMove>[];
    for (var a = 0; a < tubes.length; a++) {
      for (var b = 0; b < tubes.length; b++) {
        if (canMove(a, b)) out.add(SortMove(a, b));
      }
    }
    return out;
  }

  List<SortMove> _plan = [];
  String _planState = '';

  String get _tubesKey => tubes.map((t) => t.join(',')).join('|');

  /// Next move of a full solution from the current state (null = stuck).
  /// The solution is cached so following hints never loops.
  SortMove? hint({int budget = 60000}) {
    if (_plan.isNotEmpty && _planState == _tubesKey) return _plan.first;
    final path = solveSort(tubes, capacity, level.pourAll, budget: budget);
    if (path == null || path.isEmpty) return null;
    _plan = path;
    _planState = _tubesKey;
    return path.first;
  }

  bool get stuck => !won && legalMoves().isEmpty;

  String _snap() =>
      '${tubes.map((t) => t.join(',')).join('|')}#${hiddenCount.join(',')}#$moves#$extraTubes';

  void _restore(String s) {
    final p = s.split('#');
    tubes = p[0].split('|').map((t) => t.isEmpty ? <int>[] : t.split(',').map(int.parse).toList()).toList();
    hiddenCount = p[1].split(',').map(int.parse).toList();
    moves = int.parse(p[2]);
    extraTubes = int.parse(p[3]);
  }

  String serialize() => _snap();

  static SortGame restore(SortLevel l, String s) => SortGame(l).._restore(s);
}

/// Depth-first solver with memo + pruning. Returns moves or null.
List<SortMove>? solveSort(List<List<int>> start, int cap, bool pourAll, {int budget = 60000}) {
  final seen = <String>{};
  final path = <SortMove>[];
  var nodes = 0;

  bool complete(List<int> t) => t.length == cap && t.every((c) => c == t.first);
  bool done(List<List<int>> s) => s.every((t) => t.isEmpty || complete(t));
  String key(List<List<int>> s) {
    final parts = s.map((t) => t.join(',')).toList()..sort();
    return parts.join('|');
  }

  int run(List<int> t) {
    var n = 1;
    for (var i = t.length - 2; i >= 0 && t[i] == t.last; i--) {
      n++;
    }
    return n;
  }

  bool dfs(List<List<int>> s) {
    if (done(s)) return true;
    if (++nodes > budget) return false;
    final k = key(s);
    if (!seen.add(k)) return false;
    // Candidate moves, best first: onto same color, then into empty.
    final cands = <List<int>>[];
    for (var a = 0; a < s.length; a++) {
      final from = s[a];
      if (from.isEmpty || complete(from)) continue;
      final r = run(from);
      final uniform = r == from.length;
      var triedEmpty = false;
      for (var b = 0; b < s.length; b++) {
        if (a == b) continue;
        final to = s[b];
        if (to.length >= cap) continue;
        if (to.isEmpty) {
          if (uniform || triedEmpty) continue; // pointless / symmetric
          triedEmpty = true;
          cands.add([a, b, 1]);
        } else if (to.last == from.last) {
          final space = cap - to.length;
          final fits = pourAll ? (r <= space ? 3 : 2) : 2;
          cands.add([a, b, fits + (to.every((c) => c == to.first) ? 1 : 0)]);
        }
      }
    }
    cands.sort((x, y) => y[2].compareTo(x[2]));
    for (final c in cands) {
      final a = c[0], b = c[1];
      final from = s[a], to = s[b];
      var n = pourAll ? run(from) : 1;
      n = n.clamp(1, cap - to.length);
      final moved = from.sublist(from.length - n);
      from.removeRange(from.length - n, from.length);
      to.addAll(moved);
      path.add(SortMove(a, b));
      if (dfs(s)) return true;
      path.removeLast();
      to.removeRange(to.length - n, to.length);
      from.addAll(moved);
    }
    return false;
  }

  final copy = start.map((t) => List.of(t)).toList();
  return dfs(copy) ? List.of(path) : null;
}

/// Builds a shuffled level. [pourAll] selects water vs balls.
SortLevel generateSortLevel(LevelSpec spec, {required bool pourAll}) {
  final r = SeededRandom(spec.seed);
  final d = spec.difficulty;
  final cap = spec.has('tall') ? 5 : 4;
  var colors = (2 + d).clamp(3, pourAll ? 11 : 9);
  if (spec.levelId > 0 && spec.levelId <= 3 && spec.mode == GameModeId.campaign) colors = 2 + spec.levelId;
  final empties = (spec.has('one_empty') && colors <= 7) ? 1 : 2;
  final pool = <int>[];
  for (var c = 0; c < colors; c++) {
    for (var i = 0; i < cap; i++) {
      pool.add(c);
    }
  }
  r.shuffle(pool);
  final tubes = <List<int>>[];
  for (var t = 0; t < colors; t++) {
    tubes.add(pool.sublist(t * cap, (t + 1) * cap));
  }
  // Avoid tubes that start already sorted.
  for (var t = 0; t < tubes.length; t++) {
    if (tubes[t].every((c) => c == tubes[t].first)) {
      final o = (t + 1) % tubes.length;
      final tmp = tubes[t][0];
      tubes[t][0] = tubes[o][0];
      tubes[o][0] = tmp;
    }
  }
  for (var e = 0; e < empties; e++) {
    tubes.add(<int>[]);
  }
  return SortLevel(
    capacity: cap,
    tubes: tubes,
    hidden: spec.has('hidden'),
    pourAll: pourAll,
    timeLimit: spec.mode == GameModeId.timeAttack ? 90 + colors * 10 : (spec.has('timer') ? 60 + colors * 25 : 0),
    seed: spec.seed,
    difficulty: d,
    colors: colors,
  );
}
