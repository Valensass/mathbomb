# BOMB MATH — Implementation Report

**Status: complete, playable Android game with typed answers and turn-based Face-Off.**
Environment bootstrap and game implementation were verified on an Android 17
(API 37) emulator.

- Project: `C:\Users\murat\AndroidStudioProjects\MathBomb`
- Package: `com.valensass.bomb_math`
- Stack: Flutter 3.41.8 / Dart 3.11.5, Android SDK 37, JDK 21
- Artifacts: `build/app/outputs/flutter-apk/app-*-release.apk`,
  `dist/BOMB-MATH-1.0.0-arm64.apk`
- Tests: **34/34 passing**, `flutter analyze` clean (client + server)
- Design: [`GAME_DESIGN.md`](GAME_DESIGN.md) · Environment:
  [`../ENVIRONMENT_REPORT.md`](../ENVIRONMENT_REPORT.md)

---

## 1. Gameplay delivered

### No options — typed answers

The four coloured wires were removed. Every problem is answered on a numeric keypad
(digits 0–9, clear, backspace, wide submit). A display shows the typed value
and turns green/red for correct/wrong. Physical keyboards work too: digits,
Backspace and Enter are mapped through a `Focus` handler (used for emulator testing).

### Multiplication-first difficulty ladder

Tier 1 is always multiplication. Each solved module raises the tier; in duels each
pair of turns shares a tier.

| Tier | Type |
|---|---|
| 1 | 2–9 × 2–9 |
| 2 | 11–19 × 3–9 (two-digit × one-digit) |
| 3 | a×b + c |
| 4 | a×b − c (always positive) |
| 5 | a + b×c |
| 6 | (a+b)×c |
| 7 | exact division |
| 8 | two products |
| 9 | three-term with parentheses |
| 10 | two-digit squares |

No tier produces a negative answer.

### DEFUSE (solo)

- 45 s fuse, 60 s cap, 3 strikes, 4 modules per bomb.
- Correct: score `(100+25·tier)·combo`, +50 speed bonus, +2.5 s, next tier.
- Wrong: −5 s, strike, combo reset, same problem remains.
- Bomb clear: +300·bomb, +10 s, “BOMB DEFUSED” interlude.
- Pause, lifecycle pause, quit confirmation, explosion, result screen with new best,
  accuracy, combo, medals.
- Combo cap 3×, fastest-solve and clean-bomb tracking for medals.

### FACE-OFF (turn-based, bots + online)

- One shared seed; players alternate turns.
- 15 s per turn; one question per turn.
- Correct = 1 point; wrong or timeout = turn passes, no point.
- First to **4 points** wins; 20-turn cap resolves to score/draw.
- Both clients derive the problem from `(seed, turnIndex)`; the server owns turn
  order and the deadline.
- Four bot difficulties with distinct accuracy (55–95 %) and thinking speed.
- Live score cards, “YOUR TURN” indicator, per-turn countdown bar, emotes, anonymous
  online opponent info, Elo-style rating for online games only.

### Meta

Profile/friend code, friends with presence and challenge, 18 medals with updated
typed-answer descriptions, statistics (solved modules, fastest solve, accuracy ring,
trend, history), EN/TR localization, settings (SFX, music, haptics, motion, contrast,
language, server, reset), onboarding and a 4-page how-to.

### Presentation

Procedural bomb with animated fuse, hazard stripes and LEDs; keypad and answer display;
green/red feedback, screen shake, explosion particles; synthesized WAV effects and
music; custom launcher icon.

---

## 2. Architecture

```
lib/
  core/      theme, l10n (EN/TR), audio, haptics
  game/      math_problem.dart (ladder + deterministic generator)
             defuse_engine.dart (typed-answer solo rules)
             duel_engine.dart   (TurnDuelEngine, DuelSequence, TurnBot)
             achievements.dart
  data/      models, persistence state
  services/  app_state.dart, multiplayer_service.dart
  ui/        answer_pad.dart (display + keypad), bomb_device.dart, fx.dart,
             screens, sheets
server/      shelf + WebSocket turn authority, JSON store
tool/        synth_audio.py, mp_smoke_test.dart, opponent_bot.dart
test/        34 tests
```

Key decisions:

- **Determinism:** `MathGenerator(seed)` and `DuelSequence.problemFor(seed, turn)`
  produce identical problems on both clients; no problem payload crosses the wire.
- **Server turn authority:** the server sends `match.turn` with an epoch deadline,
  receives `match.answer {correct}`, updates scores, broadcasts `match.score`, and
  advances/ends the match. It enforces turn ownership and prevents double answers.
- **UI-free engines:** scoring, strikes, fuse, tiers, alternating turns and win
  conditions are pure Dart and heavily unit-tested.
- **Soft failure:** offline play is complete; online failures fall back to OFFLINE and
  bot play.
- **Persistence:** one atomic JSON string per profile/stats/medals/friends/history/
  settings key in `shared_preferences`.

---

## 3. Verification evidence

| Check | Command | Result |
|---|---|---|
| Analysis | `flutter analyze` | **No issues** |
| Tests | `flutter test` | **34 passed** |
| Server analysis | `dart analyze` (server) | **No issues** |
| Turn-based multiplayer | `dart run tool/mp_smoke_test.dart` | **PASS** — 2 clients, turn agreement, deadlines, score updates, first-to-4, room join, forfeit |
| App ↔ scripted opponent | manual + `opponent_bot.dart` | **PASS** — online turns, scores 1–1, opponent win, rating 992 → 984 |
| Debug APK | x86_64 split | builds, installs, runs |
| Release APKs | `--split-per-abi` | 19.0 / 16.7 / 20.4 MB |
| Typed input | emulator keyboard + keypad | `7×6=42` scored; wrong answer cost a strike |
| Turn timer | server deadline | 15 s countdown shown; timeout passes turn |
| Localization | Turkish UI | displays correct Turkish chars and emoji after encoding repair |

### Manual scenarios exercised on the running app

- Fresh run starts with a multiplication question.
- Type a correct answer → module +1, score, combo, fuse bonus, tier rises.
- Type a wrong answer → red flash, strike, fuse penalty, same question remains.
- Three strikes → detonation → result screen with stats.
- Face-Off bot: score 1/4, alternate CPU turn, next turn at tier 2.
- Face-Off online: scripted VIPER, live 1–1 score, opponent turn disabled keypad,
  match end → defeat screen, rating delta.
- Medals, statistics, friends, settings, how-to, pause.
- Turkish and English strings.

### Screenshots (`docs/screenshots/`)

`home.png`, `defuse.png`, `typed-answer.png`, `wrong-answer.png`,
`faceoff-turn.png`, `faceoff-score.png`, `online-turn.png`, `online-result.png`,
`solo-result.png`, `pause.png`, `medals.png`, `stats.png`, `friends.png`,
`settings-tr.png`, `how-to.png`.

---

## 4. Known limitations

1. **Release signing** still uses the Flutter template debug key.
2. **Answer trust:** the server enforces turns and scores but trusts the active
   client’s `correct` flag. It does not independently solve the problem or recompute
   Elo. Acceptable for LAN/dev; needs server-side validation for public play.
3. **Server scope:** no TLS, accounts or anti-cheat; default URL targets the emulator.
4. **Audio** was not audibly verified (headless emulator with `-no-audio`); plugin
   load and focus activity were observed.
5. **Physical device** unavailable; validation used the API 37 x86_64 emulator.
   Release arm64/v7 APKs were built but not installed on hardware.
6. **iOS** not configured.
7. Debug builds on the emulator disable Impeller; release keeps Impeller and ran.
8. The 15-second turn timer is tuned for touch play; automated testing via `adb`
   occasionally missed a turn due to command latency (not a runtime defect — the
   timeout path worked).

---

## 5. How to run

```powershell
cd C:\Users\murat\AndroidStudioProjects\MathBomb
flutter pub get

flutter build apk --release --split-per-abi
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk

# optional multiplayer
cd server
dart pub get
dart run bin/server.dart
```

In the app: **Settings → ONLINE → MANAGE** → `ws://10.0.2.2:8080/ws` (emulator) or
`ws://<LAN-IP>:8080/ws` (phone).

Tests:

```powershell
flutter analyze
flutter test
dart run tool/mp_smoke_test.dart
```

---

## 6. Next steps

1. Configure a release keystore and build an `.aab`.
2. Install the arm64 release on a phone; play-test the 15 s timer and tier ramp.
3. Add server-side answer validation (share the generator or send the expected answer)
   and recompute rating on the server.
4. Tune difficulty/timer from real playtest data.
5. Add TLS and accounts before exposing multiplayer beyond the LAN.
