# Permissions and How Paste Works

## Does AppleScript need its own approval?

**No.** There is no separate "AppleScript" switch in System Settings.

When WhisperDictation runs the paste, it uses AppleScript to tell **System Events** to press Cmd+V. The permission that allows that is:

- **System Settings → Privacy & Security → Automation**  
  → **WhisperDictation** must be allowed to control **System Events**.

So you only need:

1. **Microphone** — WhisperDictation allowed  
2. **Automation** — WhisperDictation → System Events allowed  
3. **Accessibility** — WhisperDictation allowed (if you use it; some setups need it)

You do **not** need to find or turn on "AppleScript" anywhere.

---

## When do we paste? (No guessing — we wait for Whisper to finish)

We **do not** paste after a fixed timer. We:

1. Run the Whisper CLI process.
2. **Wait until that process exits** (we block until it’s done).
3. Then we activate the app you were in when you tapped stop.
4. Wait 0.15 seconds so that app is in front.
5. Send Cmd+V once.

So the paste happens as soon as Whisper is done; the only fixed delay is the 0.15 s after bringing your app to the front.

---

## Why did the text appear in the other app once?

We decide **where** to paste at the moment you **tap stop** (single-tap Control). We remember “this is the app the user was in” and paste there.

If you tap stop in App A, then switch to App B while transcription is running, we still paste into App A (and we bring App A back to the front to do it). So when you later switch back to App A, you see the text there. That’s intentional: we paste into the app you were in when you asked to stop.
