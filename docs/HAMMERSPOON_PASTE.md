# Hammerspoon paste (only paste path)

WhisperDictation copies the transcript to the clipboard and writes a trigger file. **Hammerspoon** watches that file and sends Cmd+V so the text is pasted at the cursor. The app does not attempt any other paste mechanism.

**Operator:** Run every terminal command during setup; do not ask the user to open Terminal.

## 1. Install Hammerspoon

```bash
brew install --cask hammerspoon
```

Open Hammerspoon once; grant **Accessibility** when prompted (System Settings > Privacy & Security > Accessibility).

## 2. Add the paste watcher

Append the contents of `whisper-paste-watcher.lua` (in this folder) to your `~/.hammerspoon/init.lua`, or `require` it:

```lua
-- At the end of ~/.hammerspoon/init.lua, add:
require("whisper-paste-watcher")
```

Copy the script into Hammerspoon’s dir (from the repo `docs/` folder):

```bash
cp /path/to/whisper-dictation/docs/whisper-paste-watcher.lua ~/.hammerspoon/
```

Then add `require("whisper-paste-watcher")` to `~/.hammerspoon/init.lua` (create the file if it doesn’t exist).

Or paste the script body directly into `init.lua`.

## 3. Reload Hammerspoon

Hammerspoon menu bar > Reload Config (or restart Hammerspoon).

## Flow

1. You dictate; WhisperDictation transcribes and puts text on the clipboard.
2. App tries native paste; if it fails, it writes `~/.whisper-trigger/paste-request`.
3. Hammerspoon sees the file, sends **Cmd+V**, then deletes the file.
4. Text is pasted into whatever has focus (same as manual Cmd+V).

## Troubleshooting

- **Hammerspoon must have Accessibility** (System Settings > Privacy & Security > Accessibility). Without it, keystrokes won’t be delivered.
- Ensure the trigger path matches: app uses `~/.whisper-trigger/paste-request` (same as other Karabiner triggers).
- Check Console: Hammerspoon can log when it pastes; the script logs once at load.
