# DEMOED

**Version:** 1.1.0

## What we're building
An iOS app for capturing clean website demos (screenshots + screen recordings) without the Safari browser chrome leaking in or iOS's red screen-recording indicator appearing.

## Why
Designers and PMs often need to record a website demo on an iPhone without the Safari URL bar or the iOS system recording pill showing up. DEMOED is a lightweight wrapper that:
- Loads any URL on launch (user enters it)
- Lets you toggle between "Fullscreen" (just webview + 9:41 status bar) and "With Safari UI" (address bar + nav buttons) per session
- Captures screenshots and videos of the app's own content using ReplayKit, so the system recording indicator never appears
- Always displays a fake "9:41" status bar on top instead of the real one

## Key features
- Launch screen asks for URL + mode (Safari UI or Fullscreen)
- Fake status bar (9:41, full signal, full battery) — real status bar hidden
- WKWebView with back/forward swipe gestures, loading progress
- Optional Safari-style chrome: editable URL bar, back/forward, reload, share
- Screenshot button — saves full screen (minus capture UI) to Photos
- Record button — ReplayKit in-app recording, saves .mov to Photos
- Double-tap to hide/show capture controls
- No iOS system screen-recording indicator (because ReplayKit in-app capture doesn't trigger it)

## Tech stack
- SwiftUI (iOS 17+)
- WKWebView for browsing
- ReplayKit (RPScreenRecorder) for in-app video recording
- Photos framework for saving captures
- XcodeGen for project generation (run `xcodegen generate` after editing `project.yml`)

## Important decisions / constraints
- **iOS system recording indicator cannot be hidden.** DEMOED sidesteps this by using ReplayKit in-app capture, which records only the app's content and never triggers the system red pill.
- Status bar is hidden via Info.plist + SwiftUI modifiers; fake bar is drawn in-app.
- Portrait only for v1.
- No code signing team configured yet — will need to set in Xcode on first run to device.

## Changelog
- ✅ **2026-04-20 16:10** — v1.1.0. Fixed fake status bar dimensions to match real iPhone Dynamic Island (17pt semibold time, proper vertical alignment, correct battery icon size). Replaced tiny stop-record button with a clearly-labeled red "• Stop" pill. Added tap-the-clock as a secondary stop-recording gesture. Added adaptive status bar: samples webpage's `meta[name=theme-color]` or top-element background via JS, and tints the fake bar accordingly (dark icons on light pages, light icons on dark pages) — matches iOS 26 adaptive status bar.
- ❌ **2026-04-20 16:00** — v1.0.0 feedback: stop-recording button too small to hit, status bar sizing/alignment wrong (was guessed from memory, not measured). Also missing adaptive-color behavior.
- ✅ **2026-04-20 15:35** — v1.0.0 scaffolded. Clean build verified via `xcodebuild -scheme DEMOED`. Launch → browser → screenshot/record flow wired. Ready for first device run.

## Case Study

**2026-04-20** — Project kicked off. Kevin wanted an iOS app for clean website demos: a Safari-like webview with the 9:41 clock always showing and no system screen-recording indicator. Initial scope discussion clarified two key constraints: (1) Apple does not allow third-party apps to hide the red screen-recording pill (it's a privacy indicator), and (2) you can't spoof the real status bar clock without jailbreaking. The solution to both: hide the real status bar entirely, draw a fake one with "9:41" in app, and use ReplayKit's in-app recording API so the system recording indicator is never invoked in the first place. Then Kevin asked to keep the Safari browser chrome (URL bar, nav buttons) and wanted both screenshots AND videos, with Safari UI being optional per-session. Final shape: launch screen asks for URL and mode, browser view shows fake status bar + optional bottom Safari chrome + floating capture controls (screenshot / record / exit). Double-tap hides controls so they don't pollute screenshots/videos.

**2026-04-20 (v1.1.0)** — First real-device test revealed two things. (1) The fake status bar dimensions were wrong because Claude eyeballed them from memory rather than measuring — time was too low, too small, and off-center vs. the Dynamic Island. Fixed by referencing Kevin's side-by-side screenshot: SF system 17pt semibold, time/icons row sits ~4pt below notch baseline on a 54pt total bar, battery icon 25×12 with 2.5pt corner radius. (2) The recording stop button was a 16pt red dot — nearly invisible and unreliable to tap. Replaced with a labeled red "• Stop" pill (capsule), and added a secondary gesture: tapping the 9:41 clock also stops recording. Third change: added iOS 26-style adaptive tint. Injected a WKUserScript that reads `<meta name="theme-color">` (or falls back to the top-most element's background color), posts it to Swift via `webkit.messageHandlers`, and the fake bar re-tints its background + icons based on luminance. Re-runs on scroll, load, and DOM mutations.

**2026-04-20** — Scaffolded with SwiftUI + XcodeGen. Chose XcodeGen over hand-written pbxproj so Kevin can tweak `project.yml` later without editing binary Xcode project files. First `xcodebuild` pass succeeded cleanly against iOS 17.0 deployment target.

## Feature Parking Lot
- **2026-04-20** — Add "landscape mode" toggle for wider demos *(suggested by Claude)*
- **2026-04-20** — Let users save favorite URLs so they don't re-enter them each launch *(suggested by Claude)*
- **2026-04-20** — Let user customize the fake status bar time (not just 9:41) *(suggested by Claude)*
- **2026-04-20** — Optional dark / light fake-status-bar tint based on site *(suggested by Claude)*
- **2026-04-20** — Add mic-audio toggle for recordings *(suggested by Claude)*
