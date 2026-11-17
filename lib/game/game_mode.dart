enum GameMode { classic, timed, daily, zen }

extension GameModeDetails on GameMode {
  String get storageName => name;
  int? get limitSeconds => this == GameMode.timed ? 180 : null;
  bool get allowsHints => this != GameMode.daily;
}
