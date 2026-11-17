# Game 003 – Color Sort Puzzle

A Flutter 3.3+ offline-friendly **ball sorting** game with 120 reproducible, solver-checked levels.
Each valid move transports **exactly one** colored ball to an empty tube or a tube whose top ball matches.

## Implemented in source
- Classic, timed (180 s), daily (UTC) and Zen campaigns
- Bounded shortest-path hints and reversible moves
- 120 deterministic puzzles and independent completion checks
- Local auto-save, continue, best moves, progress and erase-all
- Turkish, English and Arabic UI; accessibility labels and touch targets
- Animated glossy balls and responsive bottle layout
- Local-only privacy default, no enabled tracking or paid SDK
- Unit and widget tests, Android quality CI and unsigned release compile workflow

## Development validation
Run `flutter pub get && flutter analyze --fatal-infos && flutter test` and then
`flutter build apk --debug`. On macOS, validate iOS using `flutter build ios --no-codesign`.

**Not release-ready:** real emulator/device tests, signing, full content art/audio, store assets, actual privacy forms, SDK-verified ads/IAP and live publisher review are not confirmed.
Never close issue #1 without independent evidence.
