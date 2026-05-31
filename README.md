# OnCue

OnCue is a local-only macOS menu-bar app that turns calendar reminders into a playful screen flyby.

A small runner crosses your display with the meeting name before your next event, even over full-screen calls.

No accounts. No OAuth. No telemetry.

Inspired by [@conniecodes](https://www.instagram.com/conniecodes/).

## Demo

<video src="docs/demo.mp4" controls muted playsinline width="100%"></video>

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

- No accounts, no OAuth, no API keys, and no third-party SDKs.
- No telemetry, analytics, crash reporting, or background uploads.
- No network client code. The app does not fetch `webcal://`, `http://`, or `https://` calendar URLs itself.
- Apple Calendar events are read locally through EventKit after macOS permission is granted.
- Imported `.ics` files are copied into `~/Library/Application Support/OnCue/Calendars/`.
- A custom reminder image, if chosen, is stored as `~/Library/Application Support/OnCue/reminder-image.png`.
- Settings are stored in local `UserDefaults`.

## Limitations

- macOS only.
- Main display only — multi-monitor support is on the roadmap.
- `.ics` imports are snapshots. Re-drop the file to refresh.
- Complex `.ics` recurrence rules are intentionally limited for v0.1.

## License

MIT — see [`LICENSE`](LICENSE).

## Credit

Concept by [@conniecodes](https://www.instagram.com/conniecodes/).
