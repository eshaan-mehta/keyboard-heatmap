# KeyHeat

A small macOS menu bar utility that counts which keys you press, system-wide,
and shows the result as a heatmap over a tenkeyless Mac keyboard plus a few
charts. Modifier keys (⌘ ⌥ ⌃ ⇧ fn, caps lock) are counted too, left and right
separately.

## Privacy

KeyHeat stores **counts only**: how many times each key was pressed in each
hour. It never records the order keys were typed in, so the database cannot be
turned back into text. Nothing leaves the machine. The data lives in

```
~/Library/Application Support/KeyHeat/keyheat.sqlite
```

as a single table `presses(hour, keycode, count)`.

## Requirements

- macOS 14 or later (built and checked on macOS 26).
- A Swift toolchain. The Xcode Command Line Tools are enough; full Xcode is not
  needed.

## Build and run

```
make run        # build, wrap into build/KeyHeat.app, sign ad-hoc, open it
make install    # copy build/KeyHeat.app to /Applications
```

On first launch macOS asks for **Input Monitoring** permission, which is what
gates listening to key presses. Turn KeyHeat on under
System Settings → Privacy & Security → Input Monitoring. The app polls for the
grant and starts counting as soon as it is allowed; if it does not within a few
seconds, use "Relaunch KeyHeat" in the dashboard banner.

The app is signed ad-hoc with a fixed identifier and designated requirement, so
the permission should survive rebuilds. If tracking ever shows "No permission"
after a rebuild, toggle KeyHeat off and on again in Input Monitoring.

## What you get

**Menu bar**: today's press count, tracking status, pause/resume, open
dashboard, launch at login, quit.

**Dashboard** (⌘D from the menu, or click "Open Dashboard"). Light mode,
black-and-white chrome, color only on the data:

- Range filter: today, 7 days, 30 days, all time. Everything follows it.
- Figures: presses in range, today / all time, most pressed key, peak hour,
  presses per active hour, keys used.
- Keyboard heatmap over an 87-key Mac TKL layout. Classic heat colors, blue →
  green → yellow → orange → red, washed over white so lightly used keys are a
  pale tint and the hottest go solid red. Linear, square-root or log scale;
  optionally print counts on the keys. Hover a key for its count, share, rank.
- Most pressed keys (top 15).
- Presses per day (the Today view shows the last 14 days with today
  highlighted; long histories switch to weeks).
- Hand balance by physical key position (space bar excluded).
- CSV export of the current range, from the ··· menu.

Keys that are not on a TKL board (a numeric keypad, F16–F20, JIS keys) are still
counted and included in the figures and CSV, just not on the heatmap.

## Layout notes

The heatmap uses the Mac TKL arrangement found on boards like the Keychron K8 /
Q3: a function row with F13–F15, `ins · home · pg up` / `del · end · pg dn`, and
a bottom row of `control · option · command · space · command · option · fn ·
control`. Change `Sources/KeyHeat/KeyboardLayout.swift` to match a different
board; positions are in key units.

## How counting works

A listen-only `CGEventTap` receives `keyDown` and `flagsChanged` events. Auto
repeat from a held key is ignored, so one physical press is one count. Modifier
keys arrive as `flagsChanged`; the device-specific bits in the event flags tell
left from right and press from release. Caps lock produces one event per tap.

Counts are buffered in memory and written to SQLite every five seconds and on
quit.

## Development

```
swift build                  # debug build of the bare executable
make bundle                  # release build wrapped into build/KeyHeat.app
```

Environment variables for testing without touching real data or permissions:

| Variable | Effect |
|---|---|
| `KEYHEAT_DB=/path/file.sqlite` | Use another database file. |
| `KEYHEAT_NO_TAP=1` | Never create the event tap or ask for permission. |
| `KEYHEAT_RANGE=today\|week\|month\|all` | Initial range in the dashboard. |
| `KEYHEAT_SNAPSHOT=/path/out.png` | Render the dashboard to a PNG and quit. |
| `KEYHEAT_SNAPSHOT_SCROLL=<points>` | Scroll the dashboard before snapshotting. |

`scripts/seed-demo.py` fills a database with plausible synthetic counts:

```
python3 scripts/seed-demo.py /tmp/demo.sqlite 45
KEYHEAT_DB=/tmp/demo.sqlite KEYHEAT_NO_TAP=1 build/KeyHeat.app/Contents/MacOS/KeyHeat
```

## Project layout

```
Sources/KeyHeat/
  KeyHeatApp.swift      app entry, menu bar extra, app delegate, dashboard window
  AppState.swift        observable state: stats, range, tracking, settings
  KeyTap.swift          CGEventTap wrapper (key down + modifier presses)
  KeyStore.swift        SQLite persistence, hourly buckets
  Stats.swift           aggregation for a time range
  KeyCodes.swift        virtual key code -> name, legend, category, hand
  KeyboardLayout.swift  TKL geometry in key units
  Views/                dashboard, heatmap, charts, bar list, menu, palette
Resources/Info.plist    LSUIElement app bundle metadata
Makefile                build, bundle, sign, run, install
```
