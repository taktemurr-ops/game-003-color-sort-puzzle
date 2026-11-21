import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'sort_engine.dart';

/// Shared rules for sort puzzles. Water Sort: pourAll = true.
class SortRules extends GameRules<SortLevel> {
  final bool pourAll;
  final String id;
  SortRules({required this.pourAll, required this.id});

  @override
  String get gameId => id;

  @override
  List<String> get optionalMechanics => const ['hidden', 'tall', 'one_empty', 'timer'];

  @override
  List<GameModeId> get modes => const [
        GameModeId.campaign,
        GameModeId.endless,
        GameModeId.timeAttack,
        GameModeId.zen,
        GameModeId.daily,
        GameModeId.weekly,
        GameModeId.challenge,
      ];

  @override
  List<GameStat> get gameStats => [
        GameStat('pours', pourAll ? 'Dökme' : 'Top taşıma', pourAll ? 'Pours' : 'Ball moves', scale: 50),
        const GameStat('tubes_sorted', 'Tamamlanan tüp', 'Tubes completed', scale: 10),
        const GameStat('puzzles_chain', 'Arka arkaya çözülen', 'Puzzles in a row', scale: 2),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('pours', 'pours', [40, 80, 150]),
        MissionTemplate('tubes', 'tubes_sorted', [10, 20, 40]),
      ];

  @override
  SortLevel generate(LevelSpec spec) => generateSortLevel(spec, pourAll: pourAll);

  @override
  Validation validate(SortLevel level, LevelSpec spec) {
    final counts = <int, int>{};
    for (final t in level.tubes) {
      if (t.length > level.capacity) return const Validation.fail('overfull tube');
      for (final c in t) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    if (counts.length != level.colors || counts.values.any((v) => v != level.capacity)) {
      return const Validation.fail('color counts');
    }
    if (SortGame(level).won) return const Validation.fail('already solved');
    final path = solveSort(level.tubes, level.capacity, pourAll, budget: 80000);
    if (path == null) return const Validation.fail('unsolvable within budget');
    return Validation.ok(path.length);
  }

  SortLevel finalize(GeneratedLevel<SortLevel> g) => g.puzzle.withSolution(g.validation.metric);

  static int stars(SortGame g) {
    final s = g.level.solution;
    if (s <= 0) return 3;
    if (g.moves <= (s * 1.1).ceil() && g.extraTubes == 0) return 3;
    if (g.moves <= (s * 1.6).ceil()) return 2;
    return 1;
  }
}

GameRules createRules() => SortRules(pourAll: false, id: 'game-003-color-sort-puzzle');
