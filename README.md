# KeyHeat

A macOS menu bar app that counts every key you press and shows which ones you
use most as a heatmap over a tenkeyless Mac keyboard.

It runs quietly in the background. Open the dashboard to see:

- A heat overlay on the keyboard, blue for rarely used keys through to red for
  the hottest, over today, the last 7 or 30 days, or all time.
- Your most pressed keys, presses per day, and left vs right hand balance.
- Modifier keys too: ⌘ ⌥ ⌃ ⇧ fn and caps lock, left and right counted
  separately.

Only counts are stored, per key and per hour, in a local SQLite file. The
order you typed keys in is never recorded, so nothing can be turned back into
text, and nothing leaves your Mac.

Written in Swift and SwiftUI. Needs macOS 14 or later.

## Running it

```
make run
```

This builds the app, wraps it in `build/KeyHeat.app`, and opens it. On first
launch macOS asks for Input Monitoring permission (System Settings → Privacy &
Security → Input Monitoring); counting starts as soon as it is granted.
`make install` copies the app to `/Applications`.
