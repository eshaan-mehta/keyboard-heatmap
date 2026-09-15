#!/usr/bin/env python3
"""Fill a KeyHeat database with plausible synthetic counts for previewing the UI.

Usage: scripts/seed-demo.py /tmp/keyheat-demo.sqlite [days]
Then:  KEYHEAT_DB=/tmp/keyheat-demo.sqlite KEYHEAT_NO_TAP=1 build/KeyHeat.app/Contents/MacOS/KeyHeat
"""
import random, sqlite3, sys, time
from collections import Counter

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/keyheat-demo.sqlite"
days = int(sys.argv[2]) if len(sys.argv) > 2 else 45
random.seed(7)

# key code -> relative weight (roughly English prose plus editing habits)
W = {
    0x31: 18.0,                                   # space
    0x0E: 9.0, 0x11: 7.0, 0x00: 6.5, 0x1F: 6.0, 0x22: 5.5, 0x2D: 5.5, 0x01: 5.0,
    0x0F: 5.0, 0x04: 4.0, 0x25: 3.5, 0x02: 3.0, 0x08: 2.5, 0x20: 2.5, 0x2E: 2.0,
    0x03: 2.0, 0x23: 1.8, 0x05: 1.6, 0x0D: 1.5, 0x10: 1.5, 0x0B: 1.3, 0x09: 0.9,
    0x28: 0.7, 0x07: 0.2, 0x26: 0.15, 0x0C: 0.1, 0x06: 0.08,
    0x33: 4.0, 0x24: 2.0, 0x30: 1.0,               # backspace, return, tab
    0x38: 3.0, 0x3C: 1.0,                          # shifts
    0x37: 2.5, 0x36: 0.3,                          # commands
    0x3A: 0.6, 0x3D: 0.1,                          # options
    0x3B: 0.5, 0x3E: 0.05,                         # controls
    0x3F: 0.2, 0x39: 0.05,                         # fn, caps
    0x2F: 1.2, 0x2B: 1.0, 0x27: 0.5, 0x29: 0.3, 0x1B: 0.4, 0x18: 0.2, 0x2C: 0.3,
    0x21: 0.2, 0x1E: 0.2, 0x2A: 0.05, 0x32: 0.1,
    0x7B: 0.8, 0x7C: 0.8, 0x7E: 0.5, 0x7D: 0.5,    # arrows
    0x35: 0.4, 0x73: 0.1, 0x77: 0.1, 0x74: 0.05, 0x79: 0.05, 0x72: 0.005, 0x75: 0.1,
    0x7A: 0.02, 0x78: 0.02, 0x63: 0.05, 0x76: 0.02, 0x60: 0.03, 0x61: 0.01,
    0x62: 0.01, 0x64: 0.01, 0x65: 0.01, 0x6D: 0.01, 0x67: 0.01, 0x6F: 0.03,
    0x69: 0.02, 0x6B: 0.01, 0x71: 0.01,
}
for c in (0x12,0x13,0x14,0x15,0x17,0x16,0x1A,0x1C,0x19,0x1D):
    W[c] = 0.3
codes = list(W); weights = [W[c] for c in codes]

# hour-of-day activity curve (local time)
curve = {h: 0 for h in range(24)}
for h, v in {8: .3, 9: .8, 10: 1.0, 11: 1.0, 12: .5, 13: .7, 14: 1.0, 15: 1.0,
             16: .9, 17: .6, 18: .3, 19: .2, 20: .3, 21: .3, 22: .15}.items():
    curve[h] = v

db = sqlite3.connect(path)
db.execute("""CREATE TABLE IF NOT EXISTS presses (hour INTEGER NOT NULL, keycode INTEGER NOT NULL,
              count INTEGER NOT NULL, PRIMARY KEY (hour, keycode)) WITHOUT ROWID""")
db.execute("DELETE FROM presses")

now = time.time()
midnight = time.mktime(time.localtime(now)[:3] + (0, 0, 0, 0, 0, -1))
rows = 0
for d in range(days):
    day_start = midnight - d * 86400
    weekday = time.localtime(day_start).tm_wday
    day_scale = 0.25 if weekday >= 5 else random.uniform(0.7, 1.3)
    for h in range(24):
        t = day_start + h * 3600
        if t > now: continue
        expect = 4200 * curve[h] * day_scale
        if expect < 30: continue
        n = max(0, int(random.gauss(expect, expect * 0.35)))
        if n == 0: continue
        counts = Counter(random.choices(codes, weights, k=n))
        bucket = int(t // 3600)
        db.executemany("INSERT INTO presses VALUES (?,?,?)", [(bucket, c, k) for c, k in counts.items()])
        rows += len(counts)
db.commit()
total = db.execute("SELECT SUM(count) FROM presses").fetchone()[0]
print(f"seeded {rows} rows, {total:,} presses over {days} days into {path}")
