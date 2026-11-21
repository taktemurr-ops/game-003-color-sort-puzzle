import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'rules.dart';
import 'sort_engine.dart';

/// Sorting game screen (water or balls): tap a tube, then a target tube.
/// Endless / time attack / zen chain puzzles back to back.
class SortView extends StatefulWidget {
  final PlayContext ctx;
  final SortRules rules;
  const SortView({super.key, required this.ctx, required this.rules});

  @override
  State<SortView> createState() => _SortViewState();
}

class _SortViewState extends State<SortView> with RoundClock {
  late SortGame game;
  int? _selected;
  SortMove? _hint;
  int _hints = 0;
  int _undos = 0;
  int _solved = 0;
  int _totalMoves = 0;
  int _score = 0;
  bool _ended = false;
  late LevelSpec _spec;

  PlayContext get ctx => widget.ctx;
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack, GameModeId.zen].contains(_spec.mode);

  @override
  void initState() {
    super.initState();
    _spec = ctx.spec;
    final level = widget.rules.finalize(ctx.generated as GeneratedLevel<SortLevel>);
    final snap = ctx.resume['snap'];
    game = snap is String ? SortGame.restore(level, snap) : SortGame(level);
    _solved = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    _score = (ctx.resume['score'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    startClock(initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0, limit: level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_chain ? _solved > 0 : game.won);

  void _persist() => ctx.saveResume({
        'snap': game.serialize(),
        'secs': seconds,
        'hints': _hints,
        'solved': _solved,
        'score': _score,
      });

  List<Color> get _colors {
    final base = ctx.pieceColors;
    final out = List<Color>.of(base);
    for (var i = base.length; i < 12; i++) {
      out.add(HSLColor.fromAHSL(1, (i * 53 + 20) % 360.0, 0.65, i.isEven ? 0.4 : 0.7).toColor());
    }
    return out;
  }

  void _tap(int i) {
    if (_ended) return;
    final sel = _selected;
    if (sel == null) {
      if (game.tubes[i].isEmpty || game.isComplete(i)) {
        ctx.sfx(Sfx.error);
        return;
      }
      ctx.sfx(Sfx.tap);
      setState(() => _selected = i);
      return;
    }
    if (sel == i) {
      setState(() => _selected = null);
      return;
    }
    final n = game.move(sel, i);
    if (n == 0) {
      ctx.sfx(Sfx.error);
      setState(() => _selected = game.tubes[i].isNotEmpty && !game.isComplete(i) ? i : null);
      return;
    }
    _hint = null;
    _selected = null;
    _totalMoves++;
    ctx.sfx(game.isComplete(i) ? Sfx.clear : Sfx.place);
    setState(() {});
    _persist();
    _check();
  }

  Future<void> _check() async {
    if (game.won) {
      ctx.sfx(Sfx.combo);
      if (_chain) {
        _solved++;
        _score += 100 + game.level.colors * 20 + (timeLimit > 0 ? timeLeft : 0);
        _nextPuzzle();
        return;
      }
      _end(true);
      return;
    }
    if (game.stuck) {
      if (_spec.mode == GameModeId.zen) {
        setState(() => game.addTube());
        return;
      }
      clockPaused = true;
      final again = await ctx.requestContinue();
      clockPaused = false;
      if (!mounted) return;
      if (again && (game.addTube() || game.canUndo)) {
        if (game.extraTubes == 0 || game.stuck) {
          for (var k = 0; k < 3 && game.canUndo; k++) {
            game.undo();
          }
        }
        setState(() {});
      } else {
        _end(false);
      }
    }
  }

  void _nextPuzzle() {
    final next = _spec.copyWith(
      seed: mixSeed([_spec.seed, _solved]),
      difficulty: (_spec.difficulty + _solved ~/ 3).clamp(1, 10),
    );
    final g = widget.rules.build(next);
    setState(() {
      game = SortGame(widget.rules.finalize(g));
    });
    _persist();
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    final stars = _chain
        ? (_solved >= 10 ? 3 : _solved >= 4 ? 2 : _solved >= 1 ? 1 : 0)
        : SortRules.stars(game);
    final completed = game.tubes.where((t) => t.isNotEmpty && t.length == game.capacity && t.every((c) => c == t.first)).length;
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _score : (won ? 1000 - game.moves * 5 + timeLeft.clamp(0, 999) : 0),
      stars: won ? stars.clamp(1, 3) : 0,
      seconds: seconds,
      moves: _totalMoves,
      hintsUsed: _hints,
      undosUsed: _undos,
      gameStats: {
        'pours': _totalMoves,
        'tubes_sorted': completed + _solved * game.level.colors,
        'puzzles_chain': _solved,
      },
    ));
  }

  Future<void> _useHint() async {
    final m = game.hint();
    if (m == null) {
      ctx.sfx(Sfx.error);
      return;
    }
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hint = m);
  }

  Future<void> _addTube() async {
    if (game.extraTubes > 0) return;
    if (!await ctx.requestBooster()) return;
    setState(game.addTube);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final colors = _colors;
    return Column(children: [
      PlayHud(items: [
        (Icons.swap_vert, '${t('moves')}: ${game.moves}'),
        if (game.level.solution > 0) (Icons.flag, '★★★ ≤ ${(game.level.solution * 1.1).ceil()}'),
        (Icons.timer, timeText),
        if (_chain) (Icons.emoji_events, '$_solved · ${t('score')} $_score'),
      ]),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final n = game.tubes.length;
          final perRow = n <= 6 ? n : (n / 2).ceil();
          final rows = (n / perRow).ceil();
          final tubeW = ((c.maxWidth - 16) / perRow - 10).clamp(28.0, 70.0);
          final tubeH = ((c.maxHeight / rows) - 24).clamp(80.0, tubeW * (game.capacity + 0.6));
          return Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 18,
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: tubeW + 10,
                    child: Center(
                      child: _Tube(
                        segments: game.tubes[i],
                        capacity: game.capacity,
                        hiddenCount: game.hiddenCount[i],
                        width: tubeW,
                        height: tubeH,
                        selected: _selected == i,
                        hintFrom: _hint?.from == i,
                        hintTo: _hint?.to == i,
                        colors: colors,
                        colorBlind: ctx.colorBlind,
                        balls: !game.level.pourAll,
                        symbol: ctx.symbol,
                        reducedMotion: ctx.reducedMotion,
                        onTap: () => _tap(i),
                        label: 'tube ${i + 1}',
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
      BoosterBar(buttons: [
        BoosterButton(Icons.lightbulb, t('hint'), _useHint),
        BoosterButton(Icons.undo, t('undo'), game.canUndo
            ? () {
                setState(() {
                  game.undo();
                  _undos++;
                  _selected = null;
                });
                _persist();
              }
            : null),
        BoosterButton(Icons.add_box, '+1', game.extraTubes == 0 ? _addTube : null),
      ]),
    ]);
  }
}

class _Tube extends StatelessWidget {
  final List<int> segments;
  final int capacity;
  final int hiddenCount;
  final double width;
  final double height;
  final bool selected;
  final bool hintFrom;
  final bool hintTo;
  final List<Color> colors;
  final bool colorBlind;
  final bool balls;
  final bool reducedMotion;
  final String Function(int) symbol;
  final VoidCallback onTap;
  final String label;

  const _Tube({
    required this.segments,
    required this.capacity,
    required this.hiddenCount,
    required this.width,
    required this.height,
    required this.selected,
    required this.hintFrom,
    required this.hintTo,
    required this.colors,
    required this.colorBlind,
    required this.balls,
    required this.reducedMotion,
    required this.symbol,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Inner height = tube - vertical padding (8 + 4) - top/bottom border.
    final borderW = hintFrom || hintTo ? 3.0 : 2.0;
    final seg = (height - 12 - 2 * borderW) / capacity;
    final border = hintFrom || hintTo ? Colors.yellowAccent : Colors.white;
    final tube = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: border, width: borderW),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(6),
          bottom: Radius.circular(width / 2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var k = segments.length - 1; k >= 0; k--)
            _segment(k, seg),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '$label ${segments.length}/$capacity',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedSlide(
          duration: Duration(milliseconds: reducedMotion ? 0 : 150),
          offset: Offset(0, selected ? -0.12 : 0),
          child: tube,
        ),
      ),
    );
  }

  Widget _segment(int k, double seg) {
    final hidden = k < hiddenCount;
    final c = hidden ? Colors.grey.shade700 : colors[segments[k] % colors.length];
    final text = hidden ? '?' : (colorBlind ? symbol(segments[k]) : null);
    final inner = text == null
        ? null
        : Center(child: FittedBox(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
    if (balls) {
      final d = (seg - 4).clamp(1.0, (width - 8).clamp(1.0, double.infinity));
      return Container(
        width: d,
        height: d,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color.lerp(c, Colors.white, 0.45)!, c], center: const Alignment(-0.3, -0.4)),
        ),
        child: inner,
      );
    }
    final isBottom = k == 0;
    return Container(
      height: seg,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(isBottom ? width / 2 : 0)),
      ),
      child: inner,
    );
  }
}
