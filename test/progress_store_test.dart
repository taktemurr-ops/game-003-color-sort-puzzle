import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_003_color_sort_puzzle/game/game_mode.dart';
import 'package:game_003_color_sort_puzzle/services/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save/restore current board and timer', () async {
    final store = ProgressStore();
    const initial = ProgressSnapshot(mode: GameMode.timed, level: 3,
      secondsLeft: 67, moves: 5, board: [[0, 0, 1], [1, 1, 0], []]);
    await store.saveSession(initial);
    final restored = await store.readSession();
    expect(restored, isNotNull);
    expect(restored!.mode, GameMode.timed);
    expect(restored.secondsLeft, 67);
    expect(restored.moves, 5);
    expect(restored.board, initial.board);
  });

  test('corrupted state fails closed', () async {
    final store = ProgressStore();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('color_sort_v1_session', 'invalid-json');
    expect(await store.readSession(), isNull);
    await prefs.setString('color_sort_v1_session', jsonEncode({
      'schema': 1, 'mode': 'classic', 'level': -3,
      'secondsLeft': 10, 'moves': 1, 'board': [[0], []],
    }));
    expect(await store.readSession(), isNull);
  });

  test('winning a level updates best score and unlocks progression', () async {
    final store = ProgressStore();
    await store.complete(3, 14);
    await store.complete(3, 24);
    expect(await store.highestCompletedLevel(), 4);
    expect(await store.bestMoves(3), 14);
    await store.complete(3, 11);
    expect(await store.bestMoves(3), 11);
  });

  test('eraseAll removes only owned preferences', () async {
    final store = ProgressStore();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('other_app_setting', 'preserve');
    await store.setLocale('ar');
    await store.complete(0, 2);
    await store.eraseAll();
    expect(await store.locale(), 'tr');
    expect(await store.highestCompletedLevel(), 0);
    expect(prefs.getString('other_app_setting'), 'preserve');
  });
}
