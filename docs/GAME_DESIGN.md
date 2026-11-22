# BOMB MATH — Game Design & Technical Specification

> **Type fast. Stay alive.**
> A bomb-disposal math arcade for Android, built with Flutter.

---

## 1. Identity

| | |
|---|---|
| **Title** | BOMB MATH |
| **Genre** | Arcade / mental math / turn-based 1v1 |
| **Platform** | Android (Flutter), portrait |
| **Languages** | English + Turkish (full UI localization) |
| **Session length** | Solo 60–180 s · Duel 1–3 min |
| **Package** | `com.valensass.bomb_math` |

**Pitch.** A bomb is on the table. Its display shows an equation. Type the answer on
the keypad before the fuse burns out: every correct answer disarms a module, every
wrong one burns time and costs a strike. Chain correct answers for a combo, clear the
bomb, and face a harder one. In **Face-Off**, two players alternate turns on the same
difficulty ladder; first to four correct answers wins.

There are **no multiple-choice options**. The answer is always typed.

---

## 2. Core loop

1. The bomb screen shows an arithmetic expression (tier 1 is always multiplication).
2. The player types the answer on a numeric keypad (digits, clear, backspace)
   and submits.
3. **Correct:** the module is solved, the score rises, the fuse gains 2.5 s, the combo
   increases and the next problem is one difficulty tier higher.
4. **Wrong:** one strike, −5 s, combo reset; the same problem stays on screen so the
   player can try again.
5. Clear all four modules to defuse the bomb: bonus score, +10 s, next bomb.
6. The run ends at **3 strikes** or when the fuse reaches zero.

The same keypad supports a physical keyboard (digits, backspace, Enter) on
desktop/emulator.

---

## 3. Difficulty ladder

Every run and every duel starts at **multiplication**. Difficulty rises with each
solved module (solo) or every two turns (duel), capped at tier 10.

| Tier | Problem type | Example |
|---|---|---|
| 1 | Multiplication tables (2–9) | `7 × 8` |
| 2 | Two-digit × one-digit (11–19 × 3–9) | `13 × 7` |
| 3 | Multiplication + addition | `13 × 7 + 9` |
| 4 | Multiplication − subtraction | `13 × 7 − 18` |
| 5 | Operator precedence | `24 + 6 × 8` |
| 6 | Parentheses | `(7 + 5) × 6` |
| 7 | Exact division | `96 ÷ 8` |
| 8 | Two products | `7 × 8 + 4 × 6` |
| 9 | Three-term with parentheses | `(8 + 6) × 7 − 25` |
| 10 | Two-digit squares | `15²` |

Answers are never negative: subtractions always use a smaller number than the
value they subtract from.

The generator is deterministic from a seed and is shared by both duel clients.

---

## 4. Modes

### 4.1 DEFUSE — solo survival

- Fuse 45 s (cap 60 s), 4 modules per bomb, 3 strikes.
- Correct answer: `(100 + 25·tier) × combo`, +50 speed bonus under 4 s, +2.5 s.
- Wrong answer: −5 s, one strike, same problem remains.
- Bomb clear: `+300 × bombNumber`, +10 s, next tier.
- Combo multiplier: `1 + 0.1 × min(combo, 20)` → max 3.0×.
- Fastest solve, clean bombs and best combo feed the medals.

### 4.2 FACE-OFF — turn-based 1v1

- Both players share one seed and climb the same tier ladder.
- Players alternate turns; each turn shows **one** problem.
- **15 seconds** per turn. A correct answer scores one point; a wrong answer or a
  timeout passes the turn with no point.
- First to **4 points** wins. A turn cap of 20 resolves stalled matches by score, or
  a draw.
- Two consecutive turns use the same difficulty tier, so the second player is not
  disadvantaged by a harder question.
- Opponents: quick match, private room, friend challenge, or a bot
  (EASY / NORMAL / HARD / MASTER with different accuracy and thinking speed).
- Emotes: `GG`, 🔥, 😬.

---

## 5. Progression & meta

- **Profile:** name, tag, friend code, emblem/colour, rating.
- **Rating:** Elo-style K=24 against the opponent’s stored rating; bot games are
  unrated. Only online duels move the rating.
- **Statistics:** runs, solved modules, accuracy, best score/combo, bombs, fastest
  solve, duels, wins, win streak, recent-score graph, match history.
- **Medals (18):** first solve, first bomb, 10 bombs, 10× and 25× combos, clean bomb,
  five clean bombs, sub-2-second solve, 30 s left, 10 000 points, five bombs in a run,
  first duel win, ten duel wins, 95 % accuracy over 100 answers, 50 runs, first friend,
  rating 1200, rating 1400.
- **Friends:** add by friend code (server lookup), presence, direct challenge, remove.
- **Settings:** SFX, music, haptics, reduce motion, high contrast, EN/TR/system,
  server URL/connection, reset progress, about.
- **How to play:** four pages covering keypad, fuse, combos and turn-based Face-Off.

---

## 6. Presentation

- Procedural bomb casing: hazard stripes, rivets, live screen, LEDs, animated fuse.
- Keypad: large 3×4 grid, clear key, backspace, wide submit button.
- Feedback: correct-value glow, green pulse; wrong-answer red flash, screen shake,
  strike lamp; bomb-cleared banner; explosion with flash, fireball, shockwave and
  sparks.
- Original synthesized audio (click, submit, wrong, tick, defuse, explosion, medal,
  win/lose, 8 s ambient loop) generated by `tool/synth_audio.py`.
- Accessibility: reduced motion, high contrast, haptics toggle, large targets,
  high-contrast digits; hardware-keyboard support for testing/desktop.

---

## 7. Architecture

```
lib/
  core/      theme, EN/TR localization, audio pool, haptics
  game/      math_problem.dart  (multiplication-first generator)
             defuse_engine.dart (typed-answer solo rules)
             duel_engine.dart   (TurnDuelEngine, DuelSequence, TurnBot)
             achievements.dart
  data/      models (profile, stats, medals, friends, settings)
  services/  app_state.dart (persistence, Elo, medal checks)
             multiplayer_service.dart (WebSocket client)
  ui/        screens, answer keypad/display, bomb painter, FX, sheets
server/      shelf + WebSocket turn-based match server
tool/        audio synthesis, turn-based multiplayer smoke test, opponent bot
test/        generator, solo engine, duel engine, medals, widget tests
```

**Determinism.** `MathGenerator(seed)` and `DuelSequence.problemFor(seed, turn)`
reproduce identical problems on every client; only the server decides whose turn it is.

**Persistence.** `shared_preferences` stores profile, stats, medals, friends, settings
and the last 20 matches as atomic JSON strings.

**State.** `AppState` is the single source of truth; engines are UI-free and
synchronous; screens animate their own controllers.

---

## 8. Multiplayer protocol (turn-based)

Client → server:

| Message | Purpose |
|---|---|
| `hello` | profile + friend ids |
| `queue.join` / `queue.cancel` | quick match |
| `room.create` / `room.join` / `room.leave` | private room |
| `invite.send` / `invite.reply` | friend challenge |
| `friend.lookup` | add by code |
| `match.answer {correct}` | answer on your turn |
| `match.emote {kind}` | GG / fire / shock |
| `match.forfeit` | concede |

Server → client:

| Message | Purpose |
|---|---|
| `match.start {seed, opponent…}` | match begins |
| `match.turn {index, playerId, deadline}` | whose turn and server deadline |
| `match.score {scores}` | authoritative points |
| `match.answer {playerId, correct}` | answer broadcast |
| `match.timeout {playerId}` | turn expired |
| `match.end {winnerId, reason}` | 4 points, forfeit, disconnect or turn limit |

The server owns turn order and the 15-second deadline. Both clients derive the
question from `seed` and `turnIndex`; the server trusts the active client’s
`correct` flag (development/LAN posture — see limitations).

---

## 9. Verification targets

1. `flutter analyze` clean; test suite covers the generator ladder, solo rules,
   turn alternation/scoring/win conditions, bots, medals and onboarding.
2. Turn-based multiplayer smoke test: two clients, alternating answers, score
   updates, first-to-4 end, room join and forfeit.
3. Debug and release APKs install and launch; screenshots captured from the running
   app for home, solo, typed answer, wrong answer, Face-Off, online turn, results,
   medals, stats, friends, settings, how-to and pause.
