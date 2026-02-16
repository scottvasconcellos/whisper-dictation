# Kill list — do not try again

Everything below has already been tried. It did not get the user: (1) a permission pop-up, or (2) double-tap doing anything. **Do not suggest or rely on these again.** Only try new things.

---

## 1. Permission timing / when we request

- **Defer first-run to first double-tap** — so prompts appear "when user is at keyboard." Double-tap never worked, so user never saw prompts.
- **Request mic + automation at launch** (in `applicationDidFinishLaunching`) — so when the app starts, system shows dialogs. User never got a pop-up. (Likely cause: app run by LaunchAgent may not be in a session where macOS shows dialogs.)

## 2. Trigger path

- **Normalize `.whisper-paste-trigger` → `.whisper-trigger`** in both script (`common.sh`) and app (`Config.swift`) so script and app use the same path. Done. Double-tap still does nothing for the user.
- **Telling user to "ensure config uses same path"** — already normalized in code.

## 3. LaunchAgent and install

- **Run the app binary directly** from the LaunchAgent (`ProgramArguments` = path to `WhisperDictation` binary). This is how the plist is set up. The app may be running in a launchd context where permission dialogs never appear.
- **"Run install.sh, then unload/load LaunchAgent"** as the fix — user has done this. No change.
- **"Open the app manually to trigger prompts"** (`open .../WhisperDictation.app`) — if the app never gets run in a GUI session by the user, they may never have tried this; but repeating "open the app once" without changing how the agent launches the app is on the kill list.

## 4. Karabiner

- **"Add the rule once from karabiner/rules.json"** — user has rules (even duplicate). Re-adding or "add once" is not a new fix.
- **"Remove duplicate rule"** — we can't do it for them; telling them again is not new.

## 5. System Settings

- **"Grant Microphone / Automation in System Settings"** — if WhisperDictation never successfully requested access, it may not appear in the list. Telling them to "go grant it" without fixing why the app never shows in the list is on the kill list.

## 6. Info.plist and in-process paste

- **Adding `NSAppleEventsUsageDescription`** — done. Needed for Automation prompt; not sufficient if the app never runs in a context where the dialog is shown.
- **Using NSAppleScript in-process for paste** — already done. Not the cause of "no pop-up."

## 7. Recorder and diagnostics

- **Recorder: installTap before engine.start()** — fixed for correct tap order. Does not fix "nothing happens."
- **Diagnostic logs** in `~/whisper-sessions/whisper-dictation-debug.log` and `whisper-debug.log` — we added them. Adding more logging is not a new fix; the issue is the app/dialogs/double-tap not working at all.

## 8. Checklist / docs

- **Repeating the setup checklist** (install whisper-cpp, model, Karabiner, grant mic, grant automation, load LaunchAgent, test) — user has followed it. No pop-up, no double-tap. Stop suggesting the same checklist as the solution.

---

## What to try instead (new only)

- **Launch the app in the user's GUI session** — LaunchAgent runs `open -n .../WhisperDictation.app` (done). **Use Login Items** if still no dialogs: add WhisperDictation.app in System Settings → General → Login Items.
- **Force trigger path** — implemented: trigger path is always `~/.whisper-trigger` in script and app; config is ignored for that. If you try forcing trigger path again, add it to the kill list.
- **Verify Karabiner → script** — add `TRIGGER_TEST=1` to config; if no "Whisper — Start trigger ran" on double-tap, try the rule from **karabiner/rules-absolute.json** (absolute paths, no `$HOME`).
- **LimitLoadToSessionType Aqua** in the LaunchAgent — implemented once. If you try it again, add to kill list.
- **Startup notification** ("WhisperDictation started…") — implemented once. If you try it again, add to kill list.
- **Double-tap delay 600ms** (was 400ms) in rules.json — implemented once. If you try changing the delay again without a new idea, add to kill list.
