# Microphone Access (macOS Sonoma/Sequoia+)

To use the microphone, your app **must** declare its intent and then request permission. In your **Info.plist**, include the **Privacy - Microphone Usage Description** key (`NSMicrophoneUsageDescription`) with a user-facing string explaining why you need the mic. (Eclectic Light notes that a sandboxed app also needs the microphone entitlement `com.apple.security.device.audio-input`.) At runtime, before recording, call the AVFoundation API to prompt for access. For example in Swift/Obj‑C you can do:

```swift
switch AVCaptureDevice.authorizationStatus(for: .audio) {
case .notDetermined:
    AVCaptureDevice.requestAccess(for: .audio) { granted in /*…*/ }
case .authorized:
    /* already authorized */
default:
    /* denied or restricted */
}
```

Calling `AVCaptureDevice.requestAccess(for: .audio)` will cause macOS to display the microphone permission dialog, and if granted your app will then appear in **System Settings → Privacy & Security → Microphone**. Note that your app must be a proper signed `.app` bundle with a unique `CFBundleIdentifier` (and/or `CFBundleURLName`) so the system can identify it. In practice, launching an unsigned or mis‑bundled app (for example by directly running a binary in Terminal) may cause macOS to attribute the request to the wrong process. Always distribute as a signed app bundle with its own bundle ID.

# Automation (AppleScript / Apple Events)

For **Automation** (allowing your app to control another app or System Events), similar rules apply. Your app must include a **Privacy - Apple Events Usage Description** key (`NSAppleEventsUsageDescription`) in its Info.plist. This string explains why your app sends Apple Events to other apps. **Without it, macOS will simply block Apple Events without prompting.** Once this key is present, when your app sends an Apple Event (e.g. via `NSAppleScript`, ScriptingBridge, or the AppleEvent API) to System Events (or any other target app), macOS will prompt "<YourApp> would like to control <TargetApp>." After the user allows it, your app will appear under **Privacy & Security → Automation** with the target app listed.

Importantly, **the source of the Apple Event must be your app's own process**. If you instead invoke a helper (for example running `osascript` or `sh` from your app), the prompt will be attributed to that helper (e.g. Terminal or osascript) rather than your app. In other words, use `NSAppleScript` or the AppleEvents APIs in-process so that your app's name shows up. For hardened‑runtime (App Store) apps, you must also enable the **Apple Events** entitlement: add `com.apple.security.automation.apple-events = true` to your entitlements.

# Triggering the Prompts

To ensure both prompts appear, trigger them when your app first needs the features. Common practice is to request microphone access when the user initiates recording (or early on first launch if the app's main function is audio), by calling `requestAccess(for: .audio)`. For automation, perform a trivial AppleScript action (like a no-op or simple System Events query) from your app so that macOS will show the "wants to control System Events" prompt.

A background/agent app (with `LSUIElement=true`) is treated the same as any other app for these permissions: it still has its own bundle ID and can appear in System Settings. It will still trigger the same dialogs with its app name (even though it has no Dock icon).

# Summary of Requirements

- **Info.plist keys:**  
  - **Microphone:** `NSMicrophoneUsageDescription` with explanatory text.  
  - **Automation:** `NSAppleEventsUsageDescription` with a usage message.  
- **Entitlements (if sandboxed/hardened):**  
  - For microphone: `com.apple.security.device.audio-input`.  
  - For Apple Events: `com.apple.security.automation.apple-events = true`.  
- **API calls:**  
  - Call `AVCaptureDevice.requestAccess(for: .audio)` to prompt mic access.  
  - Send an AppleEvent (via `NSAppleScript` or similar) to the target app to prompt automation access.  
- **App bundle:** Must be a standard signed `.app` with a unique bundle identifier (so TCC can recognize it).

---

# Implementation Notes (WhisperDictation)

- **Defer first-run to first user action:** When the app is launched by the LaunchAgent at login, the user may not be at the machine; permission dialogs can appear on another Space or be missed. Trigger both Microphone and Automation prompts on **first double-tap** (first `handleStart()`), not at `applicationDidFinishLaunching`, so the user is present when the dialogs appear.
- **Paste in-process:** Use `NSAppleScript` (e.g. in `PasteHelper`) from the app process only; do not run `osascript` or shell scripts for paste, or the Automation prompt will be attributed to the wrong process.
- **LaunchAgent:** Run the app’s binary inside the `.app` bundle (e.g. `WhisperDictation.app/Contents/MacOS/WhisperDictation`) so TCC attributes permissions to WhisperDictation.
