# Color Sort Puzzle

Game Studio 100 | Flutter | Android + iOS

## Implemented prototype
- Tap a source and destination tube to move one top ball
- Matching-color and four-ball capacity validation
- Move counter, undo history, solved-state detection and restart
- Pure Dart rules engine: `lib/game/color_sort_game.dart`
- Rules tests: `test/color_sort_game_test.dart`
- Playable Flutter screen: `lib/main.dart`

This differs from Water Sort Universe: **one ball per move**, instead of
pouring a contiguous same-color liquid group.

## Verify locally
```bash
flutter pub get
flutter test
flutter run
```

The code has been committed to GitHub; build and tests were **not run** in this
ChatGPT session. Demo level, art and UI are development prototypes, not release
quality.

## Roadmap
- Animation and drag/tap input polish
- Generated levels with solver validation
- Classic, timed, limited-move and zen modes
- Save/resume and hints
- Accessibility, localization, analytics and privacy-safe monetization
