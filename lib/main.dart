import 'package:flutter/material.dart';
import 'game/color_sort_game.dart';
import 'game/sort_levels.dart';

void main() => runApp(const ColorSortPuzzle());

class ColorSortPuzzle extends StatelessWidget {
  const ColorSortPuzzle({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Color Sort Puzzle',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const ColorSortScreen(),
  );
}

class ColorSortScreen extends StatefulWidget {
  const ColorSortScreen({super.key});

  @override
  State<ColorSortScreen> createState() => _ColorSortScreenState();
}

class _ColorSortScreenState extends State<ColorSortScreen> {
  int levelIndex = 0;
  ColorSortGame game = ColorSortGame(SortLevels.get(0));
  int? source;
  String feedback = 'Choose a tube, then a destination.';

  static const ballColors = [
    Color(0xFFFF697D), Color(0xFF52B7FF), Color(0xFFFFC857),
    Color(0xFF6FDBAD), Color(0xFFAF85FA),
  ];

  void select(int index) {
    setState(() {
      if (source == null) {
        if (game.tubes[index].isEmpty) {
          feedback = 'Select a nonempty tube.';
        } else {
          source = index;
          feedback = 'Select destination tube.';
        }
        return;
      }
      if (index == source) {
        source = null;
        feedback = 'Selection cancelled.';
        return;
      }
      final moved = game.move(source!, index);
      source = null;
      feedback = moved
          ? game.solved ? 'Well done — puzzle solved!' : 'One ball moved.'
          : 'Invalid move.';
    });
  }

  void loadLevel(int index) {
    if (index < 0 || index >= SortLevels.count) return;
    setState(() {
      levelIndex = index;
      game = ColorSortGame(SortLevels.get(levelIndex));
      source = null;
      feedback = 'Level ${levelIndex + 1}: sort each color into a full tube.';
    });
  }

  Widget buildTube(int index) {
    final balls = game.tubes[index];
    return InkWell(
      key: ValueKey('tube-$index'),
      onTap: game.solved ? null : () => select(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tube ${index + 1}'),
          const SizedBox(height: 8),
          Container(
            width: 76,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10), bottom: Radius.circular(28)),
              border: Border.all(
                color: source == index ? Colors.cyanAccent : Colors.white54,
                width: source == index ? 3 : 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: balls.reversed.map((ball) => Container(
                width: 39, height: 39,
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ballColors[ball % ballColors.length],
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Color Sort Puzzle')),
        
    body: SafeArea(child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Moves: ${game.moves}',
              style: Theme.of(context).textTheme.headlineMedium),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: levelIndex > 0 ? () => loadLevel(levelIndex - 1) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous level',
              ),
              Text('Level ${levelIndex + 1} / ${SortLevels.count}'),
              IconButton(
                onPressed: levelIndex + 1 < SortLevels.count ? () => loadLevel(levelIndex + 1) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next level',
              ),
            ]),
            const SizedBox(height: 24),
            Wrap(spacing: 24, runSpacing: 22,
              alignment: WrapAlignment.center,
              children: List.generate(game.tubes.length, buildTube)),
            const SizedBox(height: 24),
            Text(feedback, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Wrap(spacing: 12, children: [
              OutlinedButton.icon(
                onPressed: game.history.isNotEmpty
                  ? () => setState(() {
                      game.undo();
                      source = null;
                      feedback = 'Last move undone.';
                    })
                  : null,
                icon: const Icon(Icons.undo), label: const Text('Undo'),
              ),
              FilledButton.icon(
                onPressed: () => setState(() {
                  game = ColorSortGame(SortLevels.get(levelIndex));
                  source = null;
                  feedback = 'Level restarted.';
                }),
                icon: const Icon(Icons.refresh), label: const Text('Restart'),
              ),
            ]),
          ]),
        ),
      ),
    )),
  );
}
