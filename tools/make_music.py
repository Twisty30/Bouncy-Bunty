"""Makes the new REBOUND music loops (chiptune, 22050 Hz mono). Run: python tools/make_music.py
Each song is a list of bars: (chord, melody). Melody is "NOTE:length" in 16th notes, R = rest.
Pass song names to make only those, e.g. python tools/make_music.py desert frost"""
import math, random, struct, wave, os, sys

ONLY = set(sys.argv[1:])

SR = 22050
NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
CHORDS = {"C": "C E G", "G": "G B D", "Am": "A C E", "F": "F A C", "Em": "E G B", "Dm": "D F A",
          "E": "E G# B", "D": "D F# A", "B": "B D# F#", "A": "A C# E", "Bm": "B D F#",
          "A#": "A# D F", "Gm": "G A# D", "Cm": "C D# G", "G#": "G# C D#", "D#": "D# G A#", "Fm": "F G# C"}


def freq(name):
    octave = int(name[-1])
    return 440.0 * 2 ** ((NOTES[name[:-1]] - 9) / 12.0 + octave - 4)


def voice(buf, start, dur, f, shape, vol, duty=0.5):
    n = int(dur * SR)
    a = int(start * SR)
    for i in range(n):
        if a + i >= len(buf):
            break
        t = i / SR
        ph = (f * t) % 1.0
        if shape == "square":
            s = 1.0 if ph < duty else -1.0
        elif shape == "tri":
            s = 4 * abs(ph - 0.5) - 1
        else:
            s = random.uniform(-1, 1)
        env = min(1.0, i / 60.0) * (0.55 + 0.45 * math.exp(-t * 9)) * min(1.0, (n - i) / 300.0)
        buf[a + i] += s * env * vol


def drum(buf, start, kind):
    a = int(start * SR)
    n = int({"kick": 0.11, "snare": 0.12, "hat": 0.03}[kind] * SR)
    ph = 0.0
    held = 0.0
    for i in range(n):
        if a + i >= len(buf):
            break
        k = i / n
        if kind == "kick":
            ph += (150 * (1 - k) + 40) / SR
            s = math.sin(ph * math.tau) * (1 - k) * 0.9
        else:
            if i % (3 if kind == "snare" else 1) == 0:
                held = random.uniform(-1, 1)
            s = held * (1 - k) ** 2 * (0.5 if kind == "snare" else 0.18)
        buf[a + i] += s


## drums: "pop" (the original beat), "desert" (rolling hand-drum feel), "soft" (light, for snow),
## "drive" (four on the floor, busy hats) or "march" (snare rolls). lead: "square" or "tri".
BEATS = {
    "pop": lambda i, b: (["kick"] if i % 8 == 0 or (i == 10 and b % 2 == 1) else [])
        + (["snare"] if i % 8 == 4 else []) + (["hat"] if i % 2 == 0 else []),
    "desert": lambda i, b: (["kick"] if i in (0, 6, 10) else []) + (["snare"] if i in (4, 12) else [])
        + (["hat"] if i % 2 == 1 or i == 14 else []),
    "soft": lambda i, b: (["kick"] if i == 0 or (i == 8 and b % 2 == 1) else []) + (["snare"] if i == 8 else [])
        + (["hat"] if i % 4 == 2 else []),
    "drive": lambda i, b: (["kick"] if i % 4 == 0 else []) + (["snare"] if i % 8 == 4 else []) + ["hat"],
    "march": lambda i, b: (["kick"] if i in (0, 8) else []) + (["snare"] if i in (4, 12) or (b % 2 == 1 and i in (13, 14, 15)) else [])
        + (["hat"] if i % 4 == 2 else []),
}


## loud: bring the song up to the loudness of the original level song (soft-limiting the peaks).
def render(name, bpm, bars, lead_duty=0.25, swing_hats=True, lead="square", drums="pop", loud=False):
    if ONLY and name not in ONLY:
        return
    random.seed(3)
    step = 60.0 / bpm / 4.0
    total = len(bars) * 16 * step
    buf = [0.0] * int(total * SR)
    for b, (chord, melody) in enumerate(bars):
        t0 = b * 16 * step
        tones = CHORDS[chord].split()
        # melody
        pos = 0
        for item in melody.split():
            note, length = item.split(":")
            length = int(length)
            if note != "R":
                voice(buf, t0 + pos * step, length * step * 0.92, freq(note), lead, 0.30 if lead == "square" else 0.5, lead_duty)
            pos += length
        # bass: root and fifth in eighths
        for i in range(8):
            n = tones[0] if i % 4 != 2 else tones[2]
            voice(buf, t0 + i * 2 * step, step * 1.7, freq(n + "2"), "tri", 0.42)
        # arpeggio sparkle
        for i in range(16):
            voice(buf, t0 + i * step, step * 0.8, freq(tones[i % 3] + ("4" if i % 6 < 3 else "5")), "square", 0.07, 0.5)
        # drums
        for i in range(16):
            for kind in BEATS[drums](i, b):
                drum(buf, t0 + i * step, kind)
    peak = max(abs(s) for s in buf)
    buf = [s / peak * 0.72 for s in buf]
    if loud:
        rms = math.sqrt(sum(s * s for s in buf) / len(buf))
        k = 0.21 / rms

        def limit(x):
            a = abs(x)
            return x if a < 0.8 else math.copysign(0.8 + 0.15 * math.tanh((a - 0.8) / 0.15), x)
        buf = [limit(s * k) for s in buf]
    data = b"".join(struct.pack("<h", int(s * 32767)) for s in buf)
    path = os.path.join(os.path.dirname(__file__), "..", "music", name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(name, round(total, 1), "s")


A = [("C", "E5:2 G5:2 C6:4 G5:2 E5:2 G5:4"), ("G", "D5:2 G5:2 B5:4 G5:2 D5:2 G5:4"),
     ("Am", "C5:2 E5:2 A5:4 G5:2 E5:2 C5:4"), ("F", "F5:2 A5:2 C6:4 A5:2 G5:2 F5:2 G5:2")]
render("title", 132, A + A[:3] + [("F", "F5:2 A5:2 C6:2 D6:2 C6:8")] + [
    ("F", "A5:4 C6:4 A5:2 F5:2 A5:4"), ("G", "B5:4 D6:4 B5:2 G5:2 B5:4"),
    ("Em", "G5:4 B5:4 G5:2 E5:2 G5:4"), ("Am", "A5:2 G5:2 E5:2 C5:2 E5:4 R:4"),
    ("F", "F5:2 A5:2 C6:4 F5:2 A5:2 C6:4"), ("G", "G5:2 B5:2 D6:4 G5:2 B5:2 D6:4"),
    ("C", "E6:4 D6:2 C6:2 G5:4 E5:4"), ("C", "C6:8 G5:4 R:4")])

N = [("Am", "A4:4 C5:2 E5:2 A5:4 G5:2 E5:2"), ("F", "F5:4 A5:2 C6:2 A5:4 F5:4"),
     ("C", "E5:4 G5:2 C6:2 G5:4 E5:4"), ("G", "D5:4 G5:2 B5:2 D6:4 B5:2 G5:2")]
render("night", 118, N + N[:3] + [("G", "G5:4 B5:4 D6:8")] + [
    ("Dm", "D5:2 F5:2 A5:4 D6:4 A5:4"), ("Am", "C5:2 E5:2 A5:4 C6:4 A5:4"),
    ("E", "B4:2 E5:2 G#5:4 B5:4 G#5:4"), ("E", "E5:2 G#5:2 B5:2 E6:2 B5:8")] + N, lead_duty=0.5)

Fi = [("Em", "E5:2 G5:2 B5:2 E6:2 D6:2 B5:2 G5:2 B5:2"), ("C", "E5:2 G5:2 C6:2 E6:2 D6:2 C6:2 G5:2 C6:2"),
      ("D", "F#5:2 A5:2 D6:2 F#6:2 E6:2 D6:2 A5:2 D6:2"), ("B", "F#5:2 B5:2 D#6:2 F#6:2 D#6:4 B5:4")]
render("final", 164, Fi + Fi + [
    ("Em", "B5:4 E6:4 G6:4 E6:4"), ("G", "B5:4 D6:4 G6:4 D6:4"),
    ("D", "A5:4 D6:4 F#6:4 D6:4"), ("B", "B5:2 D#6:2 F#6:2 B6:2 F#6:8")] + Fi)


# ---------------------------------------------------------------- one song per world
# World 1 (Bouncy Hills) keeps the original "level" song.

# World 2, Dune Desert: E with a desert flavour (the F and G# give it the sandy sound)
D1 = [("E", "E5:2 F5:2 G#5:4 F5:2 E5:2 R:4"), ("Dm", "D5:2 E5:2 F5:4 E5:2 D5:2 C5:4"),
      ("Am", "C5:2 B4:2 A4:4 B4:2 C5:2 E5:4"), ("E", "F5:2 E5:2 D5:2 C5:2 B4:4 G#4:4")]
D2 = [("F", "A5:4 G#5:2 F5:2 E5:4 F5:4"), ("E", "G#5:2 A5:2 B5:4 A5:2 G#5:2 F5:4"),
      ("Am", "E5:2 F5:2 E5:2 C5:2 A4:8"), ("E", "B4:2 C5:2 D5:2 E5:2 F5:2 E5:2 G#5:4")]
render("desert", 124, D1 + D2 + D1 + D2[:2] + [("Dm", "F5:4 E5:4 D5:4 C5:4"), ("E", "B4:4 G#4:4 E4:8")],
       lead_duty=0.125, drums="desert", loud=True)

# World 3, Frost Peaks: bright D major on a soft triangle lead
F1 = [("D", "F#5:2 A5:2 D6:4 C#6:2 A5:2 F#5:4"), ("G", "G5:2 B5:2 D6:4 B5:2 G5:2 D5:4"),
      ("Bm", "F#5:2 B5:2 D6:4 C#6:2 B5:2 F#5:4"), ("A", "E5:2 A5:2 C#6:4 B5:2 A5:2 E5:4")]
F2 = [("G", "B5:4 A5:2 G5:2 F#5:4 G5:4"), ("D", "A5:4 F#5:2 D5:2 F#5:4 A5:4"),
      ("Em", "G5:2 F#5:2 E5:2 G5:2 B5:4 E6:4"), ("A", "C#6:4 B5:2 A5:2 E5:4 R:4")]
render("frost", 108, F1 + F2 + F1 + [("G", "D6:4 B5:4 G5:4 B5:4"), ("A", "C#6:4 E6:4 A5:8"),
       ("D", "D6:8 A5:4 F#5:4"), ("D", "D6:8 R:8")], lead="tri", drums="soft", loud=True)

# World 4, Thunder Heights: fast, driving D minor
S1 = [("Dm", "D5:2 D5:2 F5:2 A5:2 D6:4 A5:4"), ("A#", "D5:2 D5:2 F5:2 A#5:2 D6:4 A#5:4"),
      ("F", "C5:2 C5:2 F5:2 A5:2 C6:4 A5:4"), ("C", "C5:2 E5:2 G5:2 C6:2 E6:4 D6:4")]
S2 = [("Gm", "G5:4 A#5:4 D6:4 A#5:4"), ("Dm", "F5:4 A5:4 D6:4 A5:4"),
      ("A#", "F5:2 A#5:2 D6:2 F6:2 D6:4 A#5:4"), ("A", "E5:2 A5:2 C#6:2 E6:2 C#6:8")]
render("storm", 150, S1 + S1 + S2 + S1[:2] + [("A", "A5:4 C#6:4 E6:8"), ("A", "E6:4 C#6:4 A5:4 E5:4")],
       lead_duty=0.5, drums="drive", loud=True)

# World 5, King's Castle: a dark C minor march
C1 = [("Cm", "C5:4 D#5:2 G5:2 C6:6 G5:2"), ("G#", "C6:4 G#5:2 D#5:2 C5:6 D#5:2"),
      ("Fm", "F5:4 G#5:2 C6:2 F6:4 D#6:2 C6:2"), ("G", "D6:4 B5:2 G5:2 D5:4 G5:4")]
C2 = [("D#", "D#5:2 G5:2 A#5:4 G5:2 D#5:2 A#4:4"), ("A#", "D5:2 F5:2 A#5:4 F5:2 D5:2 A#4:4"),
      ("G#", "C5:2 D#5:2 G#5:4 G5:2 F5:2 D#5:4"), ("G", "D5:4 G5:4 B5:4 D6:4")]
render("castle", 104, C1 + C2 + C1 + [("Fm", "G#5:4 F5:4 C5:8"), ("G", "B4:4 D5:4 G5:8"),
       ("Cm", "C5:8 G4:4 C5:4"), ("Cm", "C5:12 R:4")], drums="march", loud=True)
