import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/game_mode.dart';
import '../game/color_sort_game.dart';

/// Local-only progress. No account, advertising ID or personal data is collected.
/// Reject corrupt saves rather than crashing the game on startup.
class ProgressSnapshot {
  final GameMode mode;
  final int level;
  final int secondsLeft;
  final int moves;
  final List<List<int>> board;
  const ProgressSnapshot({
    required this.mode,
    required this.level,
    required this.secondsLeft,
    required this.moves,
    required this.board,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': 1,
        'mode': mode.name,
        'level': level,
        'secondsLeft': secondsLeft,
        'moves': moves,
        'board': board,
      };

  static ProgressSnapshot? parse(Object? input) {
    try {
      if (input is! Map<String, dynamic> || input['schema'] != 1) { return null; }
      final mode = GameMode.values.where((value) => value.name == input['mode']);
      if (mode.isEmpty) { return null; }
      final level = input['level'];
      final secondsLeft = input['secondsLeft'];
      final moves = input['moves'];
      final rawBoard = input['board'];
      if (level is! int || level < 0 || level >= 120 ||
          moves is! int || moves < 0 || moves > 1000000 ||
          secondsLeft is! int || secondsLeft < 0 || secondsLeft > 3600 ||
          rawBoard is! List || rawBoard.length < 2 || rawBoard.length > 8) { return null; }
      final board = <List<int>>[];
      for (final item in rawBoard) {
        if (item is! List || item.any((color) => color is! int)) { return null; }
        board.add(item.cast<int>().toList());
      }
      final validated = ColorSortGame(board);
      if (validated.totalLayers > 32) { return null; }
      return ProgressSnapshot(mode: mode.first, level: level,
          secondsLeft: secondsLeft, moves: moves, board: board);
    } catch (_) {
      return null;
    }
  }
}

class ProgressStore {
  static const _session = 'color_sort_v1_session';
  static const _completed = 'color_sort_v1_completed';
  static const _best = 'color_sort_v1_best';
  static const _locale = 'color_sort_v1_locale';
  static const _sound = 'color_sort_v1_sound';
  static const _haptics = 'color_sort_v1_haptics';

  Future<ProgressSnapshot?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_session);
    if (raw == null) { return null; }
    try { return ProgressSnapshot.parse(jsonDecode(raw)); } catch (_) { return null; }
  }

  Future<void> saveSession(ProgressSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_session, jsonEncode(snapshot.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_session);
  }

  Future<int> highestCompletedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_completed) ?? 0;
  }

  Future<int?> bestMoves(int level) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_best$level');
  }

  Future<void> complete(int level, int moves) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getInt(_completed) ?? 0;
    if (level + 1 > previous) { await prefs.setInt(_completed, level + 1); }
    final key = '$_best$level';
    final best = prefs.getInt(key);
    if (best == null || moves < best) { await prefs.setInt(key, moves); }
    await prefs.remove(_session);
  }

  Future<String> locale() async =>
      (await SharedPreferences.getInstance()).getString(_locale) ?? 'tr';
  Future<void> setLocale(String value) async =>
      (await SharedPreferences.getInstance()).setString(_locale, value);
  Future<bool> sound() async =>
      (await SharedPreferences.getInstance()).getBool(_sound) ?? true;
  Future<void> setSound(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_sound, value);
  Future<bool> haptics() async =>
      (await SharedPreferences.getInstance()).getBool(_haptics) ?? true;
  Future<void> setHaptics(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_haptics, value);

  Future<void> eraseAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('color_sort_v1_'));
    for (final key in keys.toList()) { await prefs.remove(key); }
  }
}
