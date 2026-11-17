import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'game/game_mode.dart';
import 'game/sort_levels.dart';
import 'game/color_sort_game.dart';
import 'game/color_sort_solver.dart';
import 'services/local_text.dart';
import 'services/progress_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ColorSortPuzzle());
}

class ColorSortPuzzle extends StatefulWidget {
  const ColorSortPuzzle({super.key});
  @override
  State<ColorSortPuzzle> createState() => _ColorSortPuzzleState();
}

class _ColorSortPuzzleState extends State<ColorSortPuzzle> {
  String locale = 'tr';
  bool highContrast = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Color Sort Puzzle',
        locale: Locale(locale),
        supportedLocales: const <Locale>[Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: highContrast ? Colors.yellow : const Color(0xFF1DDBBE),
            brightness: Brightness.dark,
            surface: const Color(0xFF0D1930),
          ),
          scaffoldBackgroundColor: const Color(0xFF081224),
          cardTheme: const CardThemeData(
            color: Color(0xFF17273D),
            margin: EdgeInsets.symmetric(vertical: 6),
          ),
        ),
        home: ColorSortScreen(
          locale: locale,
          onLocaleChanged: (value) => setState(() => locale = value),
          highContrast: highContrast,
          onHighContrastChanged: (value) => setState(() => highContrast = value),
        ),
      );
}

enum _Page { menu, game, settings, progress }

class ColorSortScreen extends StatefulWidget {
  const ColorSortScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required this.highContrast,
    required this.onHighContrastChanged,
  });
  final String locale;
  final ValueChanged<String> onLocaleChanged;
  final bool highContrast;
  final ValueChanged<bool> onHighContrastChanged;
  @override
  State<ColorSortScreen> createState() => _ColorSortScreenState();
}

class _ColorSortScreenState extends State<ColorSortScreen>
    with WidgetsBindingObserver {
  final ProgressStore _store = ProgressStore();
  ColorSortGame game = ColorSortGame(SortLevels.get(0));
  GameMode mode = GameMode.classic;
  _Page page = _Page.menu;
  int levelIndex = 0;
  int unlockedCount = 0;
  int secondsLeft = 180;
  int? selected;
  (int, int)? suggested;
  bool paused = false;
  bool timeExpired = false;
  bool soundEnabled = true;
  bool hapticsEnabled = true;
  bool hasSavedGame = false;
  String notice = '';
  Timer? _clock;
  int? bestMoves;

  static const shades = <Color>[
    Color(0xFF54C9F1), Color(0xFFF66A94), Color(0xFFFFC85A),
    Color(0xFF7ADAAC), Color(0xFFAA8CFC), Color(0xFFF37C53),
    Color(0xFF65D7CE), Color(0xFFDA84DF),
  ];

  String tr(String key) => LocalText.get(widget.locale, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final loaded = await Future.wait<Object?>([
        _store.readSession(),
        _store.highestCompletedLevel(),
        _store.locale(),
        _store.sound(),
        _store.haptics(),
      ]);
      if (!mounted) { return; }
      final save = loaded[0] as ProgressSnapshot?;
      setState(() {
        unlockedCount = loaded[1] as int;
        soundEnabled = loaded[3] as bool;
        hapticsEnabled = loaded[4] as bool;
        hasSavedGame = save != null;
      });
      widget.onLocaleChanged(loaded[2] as String);
    } catch (_) {
      // Preferences unavailable: keep the fully playable offline defaults.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && page == _Page.game) {
      if (mounted) { setState(() => paused = true); }
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clock?.cancel();
    if (mode != GameMode.timed || secondsLeft <= 0) { return; }
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || page != _Page.game || paused || game.solved || timeExpired) { return; }
      setState(() {
        if (secondsLeft > 0) { secondsLeft--; }
        if (secondsLeft == 0) {
          timeExpired = true;
          paused = true;
          timer.cancel();
        }
      });
      if (secondsLeft % 15 == 0) { unawaited(_save()); }
    });
  }

  Future<void> _save() async {
    if (game.solved) { return; }
    try {
      await _store.saveSession(ProgressSnapshot(
        mode: mode, level: levelIndex, secondsLeft: secondsLeft,
        moves: game.moves, board: game.snapshot(),
      ));
      if (mounted) { setState(() => hasSavedGame = true); }
    } catch (_) { /* Local saving is best-effort; gameplay never blocks. */ }
  }

  void _begin(GameMode selectedMode, {int? level}) {
    final index = selectedMode == GameMode.daily
        ? DateTime.now().toUtc().difference(DateTime.utc(2025, 1, 1)).inDays % SortLevels.count
        : (level ?? unlockedCount.clamp(0, SortLevels.count - 1).toInt());
    setState(() {
      mode = selectedMode;
      levelIndex = index;
      game = ColorSortGame(SortLevels.get(index));
      page = _Page.game;
      selected = null;
      suggested = null;
      paused = false;
      timeExpired = false;
      secondsLeft = mode.limitSeconds ?? 180;
      notice = tr('tapSource');
      bestMoves = null;
    });
    unawaited(_store.bestMoves(index).then((value) {
      if (mounted && levelIndex == index) { setState(() => bestMoves = value); }
    }));
    _startClock();
    unawaited(_save());
  }

  Future<void> _resumeSaved() async {
    final saved = await _store.readSession();
    if (!mounted) { return; }
    if (saved == null) {
      _begin(GameMode.classic);
      return;
    }
    setState(() {
      page = _Page.game;
      mode = saved.mode;
      levelIndex = saved.level;
      secondsLeft = saved.secondsLeft;
      game = ColorSortGame(saved.board)..moves = saved.moves;
      selected = null;
      suggested = null;
      paused = false;
      timeExpired = saved.mode == GameMode.timed && secondsLeft == 0;
      notice = tr('tapSource');
    });
    _startClock();
  }

  Future<void> _finishLevel() async {
    final completedIndex = levelIndex;
    final finalMoves = game.moves;
    _clock?.cancel();
    try {
      await _store.complete(completedIndex, finalMoves);
      final progress = await _store.highestCompletedLevel();
      final record = await _store.bestMoves(completedIndex);
      if (!mounted || levelIndex != completedIndex) { return; }
      setState(() {
        unlockedCount = progress;
        bestMoves = record;
        hasSavedGame = false;
      });
    } catch (_) {
      if (mounted) { setState(() => unlockedCount = completedIndex + 1); }
    }
  }

  void _selectTube(int index) {
    if (paused || timeExpired || game.solved) { return; }
    if (hapticsEnabled) { unawaited(HapticFeedback.selectionClick()); }
    if (soundEnabled) { unawaited(SystemSound.play(SystemSoundType.click)); }
    if (selected == null) {
      setState(() {
        if (game.tubes[index].isEmpty) {
          notice = tr('choose');
        } else {
          selected = index;
          suggested = null;
          notice = tr('selected');
        }
      });
      return;
    }
    if (selected == index) {
      setState(() {
        selected = null;
        notice = tr('cancel');
      });
      return;
    }
    final moved = game.move(selected!, index);
    setState(() {
      selected = null;
      suggested = null;
      notice = !moved ? tr('invalid') : game.solved ? tr('complete') : tr('tapSource');
    });
    if (moved) {
      if (game.solved) {
        unawaited(_finishLevel());
      } else {
        unawaited(_save());
      }
    }
  }

  void _hint() {
    if (paused || game.solved || timeExpired || !mode.allowsHints) { return; }
    final move = ColorSortSolver.hint(game.snapshot());
    setState(() {
      selected = move?.$1;
      suggested = move;
      notice = move == null ? tr('noHint') : '${tr('hintHere')}: ${move.$1 + 1} → ${move.$2 + 1}';
    });
  }

  void _undo() {
    if (paused || game.solved || timeExpired || !game.canUndo) { return; }
    setState(() {
      game.undo();
      selected = null;
      suggested = null;
      notice = tr('tapSource');
    });
    unawaited(_save());
  }

  void _menu() {
    _clock?.cancel();
    if (!game.solved && page == _Page.game) { unawaited(_save()); }
    setState(() {
      page = _Page.menu;
      paused = true;
    });
  }

  Widget _pill(String label, IconData icon, VoidCallback? action,
      {Key? key, bool filled = false}) {
    final content = Text(label, textAlign: TextAlign.center);
    if (filled) {
      return FilledButton.icon(key: key, onPressed: action, icon: Icon(icon), label: content);
    }
    return OutlinedButton.icon(key: key, onPressed: action, icon: Icon(icon), label: content);
  }

  Widget _home() => ListView(
        key: const ValueKey('home'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        children: [
          const SizedBox(height: 28),
          const Icon(Icons.bubble_chart_rounded, size: 86, color: Color(0xFF6CDBEF)),
          const SizedBox(height: 20),
          Text(tr('title'), textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${tr('completedLevels')}: $unlockedCount / ${SortLevels.count}', textAlign: TextAlign.center),
          const SizedBox(height: 38),
          if (hasSavedGame)
            _pill(tr('continue'), Icons.play_arrow, _resumeSaved,
                key: const ValueKey('continue'), filled: true),
          for (final item in <(GameMode, IconData)>[
            (GameMode.classic, Icons.extension_rounded),
            (GameMode.timed, Icons.timer_outlined),
            (GameMode.daily, Icons.today_outlined),
            (GameMode.zen, Icons.spa_outlined),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _pill(tr(item.$1.name), item.$2, () => _begin(item.$1),
                  key: ValueKey('mode-${item.$1.name}'),
                  filled: item.$1 == GameMode.classic && !hasSavedGame),
            ),
          const SizedBox(height: 18),
          _pill(tr('progress'), Icons.emoji_events_outlined,
              () => setState(() => page = _Page.progress)),
          _pill(tr('settings'), Icons.settings_outlined,
              () => setState(() => page = _Page.settings)),
        ],
      );

  Widget _tube(int index, double width) {
    final layers = game.tubes[index];
    final active = selected == index;
    final isHintTarget = suggested?.$2 == index;
    final tubeWidth = width.clamp(45.0, 76.0).toDouble();
    return Semantics(
      label: '${tr('level')} ${levelIndex + 1}: ${index + 1}, ${layers.length} balls',
      button: true,
      enabled: !paused && !timeExpired && !game.solved,
      child: InkWell(
        key: ValueKey('tube-$index'),
        onTap: () => _selectTube(index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                transform: Matrix4.translationValues(0, active ? -9 : 0, 0),
                width: tubeWidth,
                height: tubeWidth * 2.28,
                padding: const EdgeInsets.fromLTRB(3, 6, 3, 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF142C42),
                  border: Border.all(
                    color: active || isHintTarget ? Colors.yellowAccent : Colors.white70,
                    width: active || isHintTarget ? 3 : 2,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8), bottom: Radius.circular(21),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: layers.reversed.map((color) => Flexible(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        width: tubeWidth * 0.52,
                        height: tubeWidth * 0.52,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.38, -0.48),
                            radius: 0.85,
                            colors: <Color>[
                              Color.lerp(shades[color % shades.length], Colors.white, 0.50)!,
                              shades[color % shades.length],
                              Color.lerp(shades[color % shades.length], Colors.black, 0.35)!,
                            ],
                            stops: const <double>[0, 0.52, 1],
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _game() {
    final disabled = paused || game.solved || timeExpired;
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final tubesPerRow = maxWidth < 340 ? 3 : maxWidth < 520 ? 4 : 6;
      final width = ((maxWidth - 32) / tubesPerRow - 12).clamp(45.0, 76.0).toDouble();
      return ListView(
        key: const ValueKey('game'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.arrow_back), tooltip: tr('back'), onPressed: _menu),
            Text('${tr('level')} ${levelIndex + 1}', style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              tooltip: paused ? tr('resume') : tr('pause'),
              onPressed: timeExpired || game.solved ? null : () => setState(() => paused = !paused),
            ),
          ]),
          Text(tr(mode.name), textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 18, children: [
            Chip(label: Text('${tr('moves')}: ${game.moves}')),
            if (mode == GameMode.timed)
              Chip(label: Text('${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}')),
            if (bestMoves != null) Chip(label: Text('${tr('best')}: $bestMoves')),
          ]),
          const SizedBox(height: 15),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 24,
            children: List.generate(game.tubes.length, (i) => _tube(i, width)),
          ),
          const SizedBox(height: 24),
          Text(notice, key: const ValueKey('message'),
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          if (paused && !timeExpired)
            _pill(tr('resume'), Icons.play_arrow, () => setState(() => paused = false), filled: true),
          if (timeExpired)
            Column(children: [
              Text(tr('timeup'), style: Theme.of(context).textTheme.headlineSmall),
              _pill(tr('restart'), Icons.restart_alt, () => _begin(mode, level: levelIndex), filled: true),
            ]),
          if (game.solved)
            Column(children: [
              Text(tr('complete'), style: Theme.of(context).textTheme.headlineSmall),
              _pill(tr('next'), Icons.arrow_forward,
                () => _begin(mode, level: (levelIndex + 1) % SortLevels.count), filled: true),
            ]),
          if (!disabled)
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
              _pill(tr('undo'), Icons.undo, game.canUndo ? _undo : null,
                  key: const ValueKey('undo')),
              _pill(tr('hint'), Icons.lightbulb_outline, mode.allowsHints ? _hint : null,
                  key: const ValueKey('hint')),
              _pill(tr('restart'), Icons.restart_alt, () => _begin(mode, level: levelIndex),
                  key: const ValueKey('restart')),
            ]),
          if (mode == GameMode.classic || mode == GameMode.zen)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: 'Previous', icon: const Icon(Icons.chevron_left),
                onPressed: levelIndex > 0 ? () => _begin(mode, level: levelIndex - 1) : null,
              ),
              Text('${levelIndex + 1} / ${SortLevels.count}'),
              IconButton(
                tooltip: 'Next', icon: const Icon(Icons.chevron_right),
                onPressed: levelIndex + 1 < SortLevels.count && levelIndex < unlockedCount
                    ? () => _begin(mode, level: levelIndex + 1) : null,
              ),
            ]),
        ],
      );
    });
  }

  Widget _settings() => ListView(padding: const EdgeInsets.all(18), children: [
        ListTile(title: Text(tr('settings')), leading: IconButton(
          icon: const Icon(Icons.arrow_back), onPressed: _menu)),
        Card(child: Column(children: [
          ListTile(title: Text(tr('language')), trailing: DropdownButton<String>(
            value: <String>['tr', 'en', 'ar'].contains(widget.locale) ? widget.locale : 'tr',
            items: const [
              DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
            ],
            onChanged: (value) {
              if (value != null) {
                widget.onLocaleChanged(value);
                unawaited(_store.setLocale(value));
              }
            },
          )),
          SwitchListTile(title: Text(tr('sound')), value: soundEnabled,
            onChanged: (value) {
              setState(() => soundEnabled = value);
              unawaited(_store.setSound(value));
            }),
          SwitchListTile(title: Text(tr('haptics')), value: hapticsEnabled,
            onChanged: (value) {
              setState(() => hapticsEnabled = value);
              unawaited(_store.setHaptics(value));
            }),
          SwitchListTile(title: const Text('High contrast'), value: widget.highContrast,
            onChanged: widget.onHighContrastChanged),
        ])),
        Card(child: Column(children: [
          ListTile(title: Text(tr('privacy')), subtitle: Text(tr('privacyBody')),
            leading: const Icon(Icons.privacy_tip_outlined)),
          ListTile(title: Text(tr('erase')), leading: const Icon(Icons.delete_outline),
            onTap: () async {
              final confirmed = await showDialog<bool>(context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(tr('erase')), content: Text(tr('confirmErase')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('no'))),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('yes'))),
                  ],
                ));
              if (confirmed != true) { return; }
              await _store.eraseAll();
              if (!mounted) { return; }
              setState(() {
                unlockedCount = 0;
                hasSavedGame = false;
                game = ColorSortGame(SortLevels.get(0));
                page = _Page.menu;
              });
            }),
        ])),
      ]);

  Widget _progress() => ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _menu),
          title: Text(tr('progress'))),
        Text('${tr('completedLevels')}: $unlockedCount / ${SortLevels.count}',
          textAlign: TextAlign.center),
        LinearProgressIndicator(value: (unlockedCount / SortLevels.count).clamp(0.0, 1.0).toDouble()),
        const SizedBox(height: 18),
        for (var i = 0; i < SortLevels.count; i++)
          Card(child: ListTile(
            leading: Icon(i < unlockedCount ? Icons.check_circle : Icons.lock_outline),
            title: Text('${tr('level')} ${i + 1}'),
            enabled: i <= unlockedCount,
            onTap: i <= unlockedCount ? () => _begin(GameMode.classic, level: i) : null,
          )),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(page == _Page.menu ? tr('title') :
        page == _Page.game ? tr('level') :
        page == _Page.settings ? tr('settings') : tr('progress'))),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: switch (page) {
        _Page.menu => _home(), _Page.game => _game(),
        _Page.settings => _settings(), _Page.progress => _progress(),
      },
    ))),
  );
}
