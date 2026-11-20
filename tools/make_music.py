"""Makes the new REBOUND music loops (chiptune, 22050 Hz mono). Run: python tools/make_music.py
Each song is a list of bars: (chord, melody). Melody is "NOTE:length" in 16th notes, R = rest."""
import math, random, struct, wave, os

SR = 22050
NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
CHORDS = {"C": "C E G", "G": "G B D", "Am": "A C E", "F": "F A C", "Em": "E G B", "Dm": "D F A",
          "E": "E G# B", "D": "D F# A", "B": "B D# F#"}


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


def render(name, bpm, bars, lead_duty=0.25, swing_hats=True):
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
                voice(buf, t0 + pos * step, length * step * 0.92, freq(note), "square", 0.30, lead_duty)
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
            if i % 8 == 0 or (i == 10 and b % 2 == 1):
                drum(buf, t0 + i * step, "kick")
            if i % 8 == 4:
                drum(buf, t0 + i * step, "snare")
            if i % 2 == 0:
                drum(buf, t0 + i * step, "hat")
    peak = max(abs(s) for s in buf)
    data = b"".join(struct.pack("<h", int(s / peak * 0.72 * 32767)) for s in buf)
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
