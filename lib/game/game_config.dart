import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'rules.dart';
import 'sort_view.dart';

final _rules = createRules() as SortRules;

final gameConfig = GameConfig(
  gameId: _rules.gameId,
  title: const ['Renkli Top Sıralama', 'Color Sort Puzzle', 'Farben-Sortier-Puzzle', 'Ordena Colores', 'Tri de Couleurs'],
  tagline: const ['Topları tek tek sırala!', 'Sort the balls, one move at a time!', 'Sortiere die Kugeln!', '¡Ordena las bolas!', 'Triez les boules !'],
  seedColor: const Color(0xFF7E57C2),
  icon: Icons.bubble_chart,
  rules: _rules,
  buildPlay: (ctx) => SortView(ctx: ctx, rules: _rules),
  tutorial: const [
    TutorialStep(Icons.touch_app, [
      'Bir tüpe dokun, en üstteki top seçilir. Sonra hedef tüpe dokun.',
      'Tap a tube to pick its top ball, then tap the target tube.',
      'Tippe eine Röhre an, dann die Zielröhre.',
      'Toca un tubo y luego el tubo de destino.',
      'Touchez un tube puis le tube cible.',
    ]),
    TutorialStep(Icons.circle, [
      'Top sadece aynı renkli topun üstüne ya da boş tüpe gider. Her hamlede tek top taşınır.',
      'A ball can go only onto the same color or into an empty tube. One ball per move.',
      'Nur auf gleiche Farbe oder in leere Röhre, eine Kugel pro Zug.',
      'Solo sobre el mismo color o tubo vacío, una bola por movimiento.',
      'Seulement sur la même couleur ou un tube vide, une boule par coup.',
    ]),
    TutorialStep(Icons.check_circle, [
      'Her tüp tek renkle dolunca kazanırsın. "?" gizli toplar üste çıkınca görünür.',
      'Win when each tube is filled with one color. "?" hidden balls appear on top.',
      'Gewonnen, wenn jede Röhre einfarbig ist.',
      'Ganas cuando cada tubo tiene un solo color.',
      'Gagné quand chaque tube est d\'une seule couleur.',
    ]),
    TutorialStep(Icons.add_box, [
      'İpucu, geri al ve +1 tüp güçlendiricileri her zaman yanında.',
      'Hint, undo and +1 tube boosters are always there.',
      'Tipp, Rückgängig und +1 Röhre helfen dir.',
      'Pista, deshacer y +1 tubo te ayudan.',
      'Indice, annuler et +1 tube vous aident.',
    ]),
  ],
);
