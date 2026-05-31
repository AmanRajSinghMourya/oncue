# OnCue

Meetings should not start with a panic tab search.

OnCue lives in your Mac menu bar and sends a tiny runner across your screen before your next calendar event, carrying the meeting name on a bright banner. It is playful enough to notice, quiet enough to stay out of your way, and visible even when you are buried in a full-screen call, IDE, or browser.

Built for people who want useful reminders without another account, cloud sync, or calendar bot. OnCue reads Apple Calendar locally, imports `.ics` files, and keeps everything on your Mac.

No accounts. No OAuth. No telemetry.

Inspired by [@conniecodes](https://www.instagram.com/conniecodes/).

## Demo
https://github.com/user-attachments/assets/f410c9e4-0b80-4b5b-810d-2c3bcad738f1


## Screenshots

| Calendar | Settings |
| --- | --- |
| ![OnCue calendar view](docs/calendar.png) | ![OnCue settings view](docs/settings.png) |

## Features

- Animated reminder flyby before meetings.
- Works above full-screen calls.
- Reads Apple Calendar locally through EventKit.
- Imports `.ics` calendar files with no account login.
- Supports custom reminder images, per-calendar toggles, sound, and 1–120 minute lead times.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ if building from source

## Install

Download the latest DMG from [GitHub Releases](https://github.com/AmanRajSinghMourya/oncue/releases/latest):

1. Download `OnCue.dmg`.
2. Open it.
3. Drag `OnCue.app` to Applications.
4. Open OnCue from Applications.
5. Grant calendar access on first launch.
6. Click the menu-bar icon to set reminder timing, preview the animation, or import `.ics` calendars.

The GitHub Actions release workflow can publish an unsigned DMG without an Apple Developer account. macOS may require right-click → Open on first launch. A no-warning public install requires Apple Developer ID signing and notarization.

## Build From Source

1. Clone this repo.
2. Open `OnCue.xcodeproj` in Xcode.
3. Select the `OnCue` scheme and your Mac as the destination.
4. In Signing & Capabilities, pick your team if Xcode asks. The project intentionally has no App Sandbox entitlement so EventKit and file imports work without extra configuration.
5. Build & run (⌘R).
6. Grant calendar access on first launch. Optionally drop a `.ics` file into Settings → Import .ics calendars.

CLI build/test:

```sh
xcodebuild -project OnCue.xcodeproj -scheme OnCue -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project OnCue.xcodeproj -scheme OnCue -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Create a local DMG:

```sh
Scripts/package_dmg.sh
```

## Usage

- The app lives in your menu bar as a small reminder icon.
- Click the icon to open the popover.
- Set reminder timing, choose an image, manage event sources, import `.ics` files, or preview the animation.
- Re-importing a `.ics` file with the same filename refreshes it.

## Privacy & security

- No accounts, OAuth, telemetry, or analytics.
- No calendar data is uploaded anywhere.
- Apple Calendar and imported `.ics` files are read locally on your Mac.

## Limitations

- macOS only.
- Main display only — multi-monitor support is on the roadmap.
- `.ics` imports are snapshots. Re-drop the file to refresh.
- Complex `.ics` recurrence rules are intentionally limited for v0.1.

## License

MIT — see [`LICENSE`](LICENSE).

## Credit

Concept by [@conniecodes](https://www.instagram.com/conniecodes/).
