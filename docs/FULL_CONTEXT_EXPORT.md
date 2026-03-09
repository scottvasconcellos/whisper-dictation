1) CURRENT MILESTONE
- **Project type / stack**: macOS background dictation utility using Swift (AppKit/AVFoundation), shell scripts, Karabiner-Elements, Hammerspoon, and whisper-cpp.
- **Current milestone / phase**: Gate A reliability pass for WhisperDictation (>=95% successful auto-paste across 30+ cycles).
- **HEAD commit / branch**: `d279ff43916e05ae0f2672b2d3ccd3008ac1b2c9` | branch: _detached HEAD_ (no named branch reported).
- **Git tags**: `checkpoint-auto-paste-working` → `57d2dfe6c7c438288a4520a75a114281afeb47a0`.
- **Version info**:
  - `WhisperDictation/Info.plist`: `CFBundleShortVersionString = 1.0.0`, `CFBundleVersion = 1`.
  - `WhisperPaste/WhisperPaste/Info.plist`: `CFBundleShortVersionString = 1.0.0`, `CFBundleVersion = 1`.

2) HEALTH CHECK STATUS
- **PASS**: `bash WhisperDictation/build.sh` (ran as `bash build.sh` inside `WhisperDictation/`) — builds `WhisperDictation.app` successfully and replaces existing signature.
- **PASS**: `bash WhisperPaste/build.sh` — builds `WhisperPaste.app` at `WhisperPaste/build/WhisperPaste.app`.
- **PASS**: `bash install.sh` — symlinks trigger scripts into `~/bin`, generates `karabiner/rules-absolute.json`, builds `WhisperDictation.app`, installs LaunchAgent, and restarts the app.
- **FAIL**: `./scripts/verify-autopaste.sh` — Autopaste verification: 5 cycles analyzed, H4 paste success fails in 3 cycles with AppleScript errorNumber 1002; overall verification failed.
- **FAIL**: `./scripts/verify-reliability.sh` — Reliability verification: 798 cycles, only 2 successful (0.3%); Gate A criteria (>=95% success) not met; manual and silence stops frequently fail acceptance tests.

3) CORE GUARANTEES & INVARIANTS
- **Build reproducibility / determinism**:
  - `WhisperDictation/build.sh`, `WhisperPaste/WhisperPaste/build.sh`, and `install.sh` provide scripted, repeatable builds for the two apps and their LaunchAgent wiring, avoiding manual Xcode steps.
- **Public API / contract stability**:
  - Contract is the end-to-end behavior: Karabiner double-tap/single-tap Control → trigger files in `~/.whisper-trigger` → WhisperDictation state machine → transcript to clipboard → paste trigger → Hammerspoon/WhisperPaste sends Cmd+V; this flow is encoded in `karabiner/rules.json`, `scripts/whisper-*.sh`, `WhisperDictation/AppDelegate.swift`, and `docs/HAMMERSPOON_PASTE.md`.
- **Architecture / scope boundaries**:
  - Swift app (`WhisperDictation`) owns recording, session lifecycle, transcription, clipboard, and writing paste triggers; shell scripts/Karabiner only emit start/stop triggers; Hammerspoon or `WhisperPaste` exclusively own sending Cmd+V; config loading is centralized in `WhisperDictation/Config.swift` with canonical trigger paths.
- **Quality and testing gates**:
  - `scripts/verify-reliability.sh` implements Gate A acceptance tests (AT1–AT7) with explicit thresholds (>=95% success, latency targets); `scripts/verify-autopaste.sh` exercises autopaste behavior across multiple cycles to detect AppleScript/Accessibility/paste failures.
- **Release safety**:
  - README and `install.sh` tie DMG creation (`scripts/build-dmg.sh`) to meeting Gate A; DMG build is gated on passing reliability checks rather than being run unconditionally.
- **Other invariants**:
  - Session storage under `~/whisper-sessions` is pruned by count, not age: `WhisperDictation/AppDelegate.swift` keeps only the N most recent session folders (`sessionRetentionCount`, default 5) and deletes older ones.
  - Trigger directory is canonical and eagerly created: `WhisperDictation/Config.swift` forces `~/.whisper-trigger`, and `AppDelegate.applicationDidFinishLaunching` ensures both `~/.whisper-trigger` and `~/.whisper-paste-trigger` exist.

4) KEY ARTIFACTS (PATHS)
- **Main configuration / manifest files**:
  - `config.example` (template for `~/.config/whisper-dictation/config`).
  - `WhisperDictation/Info.plist`, `WhisperPaste/WhisperPaste/Info.plist`.
  - `LaunchAgents/com.whisper.dictation.plist`, `LaunchAgents/com.whisper.paste.plist`.
  - `karabiner/rules.json`, `karabiner/rules-absolute.json`.
- **Version stamp files**:
  - `WhisperDictation/Info.plist` (`CFBundleShortVersionString`, `CFBundleVersion`).
  - `WhisperPaste/WhisperPaste/Info.plist` (`CFBundleShortVersionString`, `CFBundleVersion`).
- **Core definitions / contracts / schemas**:
  - `WhisperDictation/AppDelegate.swift` (dictation state machine, trigger polling, transcription, paste triggering, session pruning).
  - `WhisperDictation/Recorder.swift` (16 kHz mono recording, silence detection).
  - `WhisperDictation/Config.swift` (key=value config, canonical trigger paths, `sessionRetentionCount`).
  - `scripts/common.sh` (shared config/paths/logging for shell scripts).
- **Release manifest or build outputs**:
  - `WhisperDictation/build/WhisperDictation.app`.
  - `WhisperPaste/build/WhisperPaste.app`.
  - DMG builder: `scripts/build-dmg.sh` (Gate-A-dependent).
- **Important snapshot / proof files**:
  - Event logs (via `WhisperDictation/EventLogger.swift`, typically under `~/whisper-sessions/` per run).
  - Verification outputs from `scripts/verify-autopaste.sh` and `scripts/verify-reliability.sh` (console output used in this export).
- **Changelog or release notes**:
  - No dedicated `CHANGELOG.md`; checkpoint tag `checkpoint-auto-paste-working` with commit message “Checkpoint: Hammerspoon paste working — single paste path, no fallbacks” serves as the latest documented behavioral milestone.
- **This export file**:
  - `docs/FULL_CONTEXT_EXPORT.md` (absolute path: `/Users/scottvasconcellos/Documents/My Apps/whisper-dictation/docs/FULL_CONTEXT_EXPORT.md`).

5) RECENT COMMIT LOG (LAST 10 COMMITS)
- `d279ff4` | Checkpoint: Hammerspoon paste working — single paste path, no fallbacks | **scripts + paste orchestration**.
- (No additional commits visible beyond this checkpoint in the current clone; repository history before this point is not present locally.)

6) OPEN RISKS (TOP 5)
- **R1 – Auto-paste reliability well below Gate A (0.3% success)**:
  - `scripts/verify-reliability.sh` shows 2/798 successful cycles; AT1/AT2 failures and repeated paste retries indicate that the end-to-end flow (trigger → transcription → paste) is not yet production-grade.
- **R2 – Autopaste AppleScript failures (errorNumber 1002)**:
  - `scripts/verify-autopaste.sh` reports repeated AppleScript failures and missing results, likely tied to Accessibility trust, window focus, or watcher mismatches; this directly impacts user-perceived “it sometimes doesn’t paste.”
- **R3 – Detached HEAD / minimal visible history**:
  - `git branch --show-current` returns empty and only one visible commit exists; this limits ability to bisect regressions or cleanly branch for release work.
- **R4 – Strong dependence on local environment configuration**:
  - Successful behavior depends on whisper-cpp installation, GGML model placement, Karabiner rule selection (`rules-absolute.json` vs `rules.json`), Hammerspoon or WhisperPaste being active, and macOS Microphone/Automation/Accessibility permissions; misconfiguration can silently degrade reliability.
- **R5 – Verification gate failures block DMG-level release**:
  - README’s Gate A criteria tie DMG building to a high reliability threshold; until `scripts/verify-reliability.sh` and `scripts/verify-autopaste.sh` pass consistently, any external release (even for testing) remains high-risk.

7) NEXT STEP (SINGLE RECOMMENDED ARC)
- **Why this is highest-leverage**: The most impactful move is to raise end-to-end reliability (especially auto-paste and stop/start behavior) to pass Gate A, since all release and user trust hinges on consistent dictation → transcription → paste performance.
- **Copy-pasteable prompt**: 
  - “Using the current `whisper-dictation` repo state (HEAD `d279ff43916e05ae0f2672b2d3ccd3008ac1b2c9`), analyze why `scripts/verify-reliability.sh` and `scripts/verify-autopaste.sh` are failing (based on their code and recent outputs), then implement and test concrete fixes to bring Gate A success rate to at least 95% across 30+ cycles without regressing the newly added background Whisper, dual paste triggers, and session pruning behavior.”

