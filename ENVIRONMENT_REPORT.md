# ENVIRONMENT REPORT — BOMB MATH

**Date:** 2026-10-18 · **Host:** Windows 10 Pro (19045) · **Project:**
`C:\Users\murat\AndroidStudioProjects\MathBomb`

This report distinguishes **verified** (actually executed and observed),
**detected** (present on disk / on PATH but not exercised for this project), and
**not installed**.

---

## 1. Operating system and architecture

| Item | Value | Status |
|---|---|---|
| OS | Microsoft Windows 10 Pro, 22H2, build 19045.6466 | verified |
| Architecture | 64-bit (x86_64) | verified |
| CPU | 12th Gen Intel Core i7-12700F, 12 cores / 20 threads | verified |
| Memory | 31.82 GB RAM | verified |
| GPU | NVIDIA GeForce RTX 3080, driver 32.0.15.8180 | verified |
| Disk at start | C: 930.9 GB total, **87.7 GB free**; F: 3.7 TB, 1.66 TB free | verified |
| Disk after build/test | C: **78.9 GB free** | verified |
| Shell | Windows PowerShell 5.1 (`pwsh` tool), no elevated session | verified |
| Session account | not administrator (`IsAdmin: False`) | verified |

No reboot was required or performed. No system-wide settings were changed.

---

## 2. Detected tools and versions

### Selected toolchain (verified)

| Tool | Version | Location | Verification |
|---|---|---|---|
| Flutter | **3.41.8** stable | `C:\flutter` | `flutter --version`, `flutter doctor -v`, builds |
| Dart | **3.11.5** | `C:\flutter\bin\dart.bat` | build + tests |
| DevTools | 2.54.2 | bundled | `flutter doctor` |
| JDK | **OpenJDK 21.0.10** (Android Studio JBR) | `C:\Program Files\Android\Android Studio\jbr` | `flutter doctor` reports it; Gradle builds |
| Android SDK | **37.0.0** | `%LOCALAPPDATA%\Android\Sdk` | `flutter doctor`; builds |
| SDK platforms | android-29, 33, 34, 35, 36, 36.1, **37.0** | SDK `platforms/` | directory inspection |
| Build-tools | 28.0.3, 34.0.0, 35.0.0, 35.0.1, 36.0.0, 36.1.0, **37.0.0** | SDK `build-tools/` | directory inspection |
| cmdline-tools | `latest` (with `avdmanager`, `sdkmanager`) | SDK `cmdline-tools/latest` | invoked `avdmanager` |
| platform-tools / adb | present, 1.0.41 | SDK `platform-tools` | installs, screenshots, logcat |
| Android Emulator | 36.5.11.0 | SDK `emulator` | booted, ran the app |
| Gradle | **8.14** (wrapper `-all`) | `android/gradle/wrapper` | `assembleDebug` / `assembleRelease` |
| Android Gradle Plugin | 8.11.1 | `android/settings.gradle.kts` | build |
| Kotlin | 2.2.20 | `android/settings.gradle.kts` | build |

### Other tools present (detected, not required by the selected stack)

| Tool | Version | Note |
|---|---|---|
| Git | 2.54.0.windows.1 | available |
| Node.js / npm | 24.15.0 / 11.12.1 | not used |
| Python | 3.12.10 | used only for audio synthesis |
| .NET SDK | 10.0.401 | not used |
| Visual Studio 2022 Community | 17.14.31, Win10 SDK 10.0.26100 | not used |
| Chrome / Edge | 155 | not used |
| Unity Hub + Editors | 6000.3.25f1, 6000.6.4f1 | **detected, not used** |
| Godot | `godot.exe` via WinGet link | **detected, not used** |
| Blender | installed under `C:\Program Files\Blender Foundation` | **detected, not used** |

### Not installed / not required

Gradle standalone (the wrapper is sufficient), separate JDK 17 (JDK 21 is
compatible with this AGP/Gradle pair), iOS tooling, Android NDK usage beyond the
template default, databases, Docker services for the game.

---

## 3. Selected game engine / stack

**Flutter 3.41.8 (Dart 3.11.5) — existing project, native Android build.**

Why this was chosen after inspecting the machine:

1. The target project already exists as a Flutter application
   (`bomb_math`, id `com.valensass.bomb_math`) with a working Android Gradle
   configuration and a previously built debug APK.
2. Flutter is fully installed and validated on this machine; no large download
   or license-gated editor install was necessary.
3. BOMB MATH is a 2D, UI-heavy, vector-art game. Flutter's CustomPainter,
   animation controllers, hit-testing, localization and widget testing cover
   every requirement without a 3D engine.
4. It gives fast builds (7–11 s incremental), a pure-Dart deterministic game
   core that is easy to unit test, and a single language for client and server.
5. Unity 6000.3/6000.6 is installed, but reusing it would have required a new
   project, Android export modules/signing setup, and much slower iteration for
   no visual benefit. Godot and Blender were likewise unnecessary (no 3D or
   sculpted assets).

**Not installed:** nothing new was required beyond Dart packages.

---

## 4. Installed dependencies

### Client (`pubspec.yaml` / `pubspec.lock`)

| Package | Version | Purpose | Source | Status |
|---|---|---|---|---|
| flutter / flutter_localizations | SDK | UI, Material EN/TR | Flutter SDK | verified |
| provider | 6.1.5+1 | app state injection | pub.dev | verified |
| shared_preferences | 2.5.6 | profile/stats/settings persistence | pub.dev | verified |
| audioplayers | 6.7.1 | SFX + music playback | pub.dev | verified (plugin loaded; see audio note) |
| web_socket_channel | 3.0.3 | multiplayer client | pub.dev | verified |
| cupertino_icons | 1.0.9 | icons | pub.dev | verified |
| intl | 0.20.2 | transitive (localization) | pub.dev | resolved |
| flutter_lints | 6.0.0 | static analysis | pub.dev | verified |

### Server (`server/pubspec.yaml`)

| Package | Version | Purpose | Status |
|---|---|---|---|
| shelf | 1.4.3 | HTTP routing | verified |
| shelf_web_socket | 3.0.0 | WebSocket upgrade | verified |
| web_socket_channel | 3.0.3 | socket abstraction | verified |
| test | 1.33.0 | dev dependency | resolved |

### Assets

Ten original WAV files (click, cut, wrong, tick, defuse, explosion, medal, win,
lose, 8-second music loop) generated by `tool/synth_audio.py` — no downloads, no
licensing dependencies. Total ≈ 1.3 MB.

---

## 5. Environment-variable changes

**No changes were necessary.** The required variables were already set
correctly and were used as-is:

| Variable | Value | Verified by |
|---|---|---|
| `JAVA_HOME` | `C:\Program Files\Android\Android Studio\jbr` | Gradle builds succeed |
| `ANDROID_HOME` | `C:\Users\murat\AppData\Local\Android\Sdk` | `flutter doctor` |
| `ANDROID_SDK_ROOT` | same as above | `flutter doctor` |
| `PATH` | already contains `C:\flutter\bin` and the Android Studio JBR | `flutter`/`java` resolve |

No duplicate PATH entries were added, no unrelated variables were touched, and
no credentials or API keys are stored in the project.

---

## 6. Android SDK configuration

- `android/local.properties` points to
  `sdk.dir=C:\Users\murat\AppData\Local\Android\Sdk` and `flutter.sdk=C:\flutter`.
- `compileSdk` / `targetSdk` follow the Flutter SDK (API 36/37 toolchain).
- `minSdk` follows the Flutter default (21+).
- JDK 21 is used through `JAVA_HOME`; AGP 8.11.1 and Gradle 8.14 support it.
- **Licenses:** initially **1 of 8** not accepted (`microxr-sysimage-license`).
  Accepted through the normal Flutter process:
  `flutter doctor --android-licenses` → **all 8 accepted**. No license file was
  edited by hand.
- Internet permission is declared in the main manifest for online play;
  cleartext `ws://` is explicitly enabled for the local dev server and is
  documented as a development-only posture.

---

## 7. Build-validation results

### Template project (before game code)

| Check | Result |
|---|---|
| `flutter build apk --debug` | **PASS** — 144,654,154-byte APK in 4 s |
| Install on emulator | **FAILED** initially on `Pixel_10`: `INSTALL_FAILED_INSUFFICIENT_STORAGE` (its 5.8 GB `/data` was 94 % full) |
| Resolution | Created fresh AVD `BombMath_Dev` (clone of the API 37 image) with **16 GB** data partition |
| Install x86_64 debug APK | **PASS** (94 MB) |
| Launch `MainActivity` | **PASS** — confirmed via `dumpsys window` |

### Final game

| Check | Result |
|---|---|
| `flutter analyze` | **PASS** — no issues (client and server) |
| `flutter test` | **PASS** — 34/34 tests |
| Debug APK (x86_64) | **PASS** — 94.4 MB |
| Release APKs | **PASS** — arm64-v8a 19.0 MB, armeabi-v7a 16.7 MB, x86_64 20.4 MB |
| Install release on emulator | **PASS** |
| Launch, onboarding, home, Defuse (typed answers), pause, result, Face-Off turn-based bot, online turn-based duel, stats, medals, friends, settings, Turkish UI, How-to | **PASS** — exercised on the running emulator and captured (`docs/screenshots/` and `build/shots/`) |
| Multiplayer server (`dart analyze`) | **PASS** |
| Multiplayer smoke test | **PASS** — two clients, turn agreement, server deadlines, score updates, first-to-4, room create/join, forfeit |
| App ↔ server end-to-end | **PASS** — the app quick-matched a scripted `VIPER` opponent, played alternating turns (1–1), lost at 4 points, and rating changed **1000 → 984** over two rated matches |
| Audio | Plugin loaded and Android audio-focus requests observed; the AVD is headless with `-no-audio`, so sound was **not audibly verified** |
| Layout errors | No `RenderFlex overflow` entries in logcat during the exercised screens |

### Emulator issues found and resolved (recorded for reproducibility)

1. `Pixel_10` `/data` was 94 % full (383 MB free) — 6 GB image.
   → Created `BombMath_Dev` with a 16 GB partition.
2. First boot of the new AVD ran with only **2048 MB** despite the config.
   The app was killed by Android with `ApplicationExitInfo reason=3
   (LOW_MEMORY)`.
   → Set `hw.ramSize=4096` and launched with `-memory 4096`.
3. With `-gpu swiftshader_indirect` + Impeller, opening the animated gameplay
   screen terminated the emulator process (host-side virtual GPU crash).
   → Run the emulator with **`-gpu host`**, and disable Impeller for **debug**
   builds only via `android/app/src/debug/AndroidManifest.xml`.
   Release builds keep Impeller and were launched successfully.

### Useful emulator command used

```powershell
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd BombMath_Dev `
  -no-snapshot -no-audio -no-boot-anim -no-window -gpu host -memory 4096
```

---

## 8. Failed installations

| Attempt | Error | Resolution |
|---|---|---|
| 145 MB debug APK → `Pixel_10` | `INSTALL_FAILED_INSUFFICIENT_STORAGE` (`/data` 383 MB free) | new 16 GB AVD |
| 60 MB split APK → `Pixel_10` | same | new AVD |
| First app run on 2 GB AVD | killed by `LOW_MEMORY` | raise RAM to 4096 MB |
| App on SwiftShader | emulator process exit 1 while opening gameplay | `-gpu host` + debug-only Skia |

No downloads failed. No TLS verification, firewall, antivirus, or OS security
setting was disabled.

---

## 9. Missing permissions or approvals

- No administrator rights were required for any step; the session is
  non-elevated and no elevation was attempted.
- Android SDK licenses were the only agreement gate; they were accepted through
  `flutter doctor --android-licenses` (8/8), as documented in §6.
- No accounts, paid services, cloud deployments, or credentials were created or
  requested.

---

## 10. Remaining blockers

| Item | Severity | Notes |
|---|---|---|
| Physical Android device | optional | none connected (`adb devices` empty at start). All validation used the API 37 x86_64 emulator. |
| Production signing | required before store release | release APKs currently use the template debug signing config. |
| Public multiplayer | not configured | the server is a LAN/dev service (no TLS/auth); local and emulator play work. |
| Audible audio QA | minor | emulator launched with `-no-audio`; assets and plugin load verified, not listened to. |
| Server-authoritative rating | design limitation | rating is computed on-device and stored in the server snapshot; the server does not recompute Elo. |

There is **no blocker** to installing and playing the complete game locally.

---

## 11. Exact next steps

1. Install the phone build:
   `adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`.
2. Start the match server on the PC: `cd server; dart run bin/server.dart`.
3. On the phone, open **Settings → ONLINE → MANAGE** and set
   `ws://<PC-LAN-IP>:8080/ws` (the emulator default is `10.0.2.2`).
4. Create a real signing key and replace the debug `signingConfig` before any
   distribution; build an `.aab` with `flutter build appbundle --release`.
5. Optional: add TLS (`wss://`) and authentication to the match server before
   exposing it beyond the LAN.
6. Re-run `flutter analyze`, `flutter test`, and
   `dart run tool/mp_smoke_test.dart` after any gameplay changes.
