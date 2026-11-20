"""Makes the extra REBOUND sound effects (chip-style, 22050 Hz mono). Run: python tools/make_sfx.py"""
import math, random, struct, wave, os

SR = 22050
random.seed(7)


def save(name, samples, level=0.8):
    peak = max(1e-6, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * level)) * 32767)) for s in samples)
    path = os.path.join(os.path.dirname(__file__), "..", "sfx", name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def tone(dur, f0, f1, shape="square", vol=1.0, decay=4.0, noise=0.0, crush=0):
    out, phase, held, lp = [], 0.0, 0.0, 0.0
    n = int(dur * SR)
    for i in range(n):
        k = i / n
        f = f0 * (f1 / f0) ** k
        phase += f / SR
        if shape == "square":
            s = 1.0 if phase % 1 < 0.5 else -1.0
        elif shape == "saw":
            s = 2 * (phase % 1) - 1
        elif shape == "tri":
            s = 4 * abs(phase % 1 - 0.5) - 1
        else:
            s = math.sin(phase * math.tau)
        if noise:
            if crush == 0 or i % crush == 0:
                held = random.uniform(-1, 1)
            s = s * (1 - noise) + held * noise
        env = math.exp(-decay * k) * min(1.0, i / (0.004 * SR))
        out.append(s * env * vol)
    return out


def chime(notes, gap=0.06, ring=0.45, vol=0.5):
    """Soft bell arpeggio: sine partials with a smooth attack and a full fade-out, so nothing
    clicks and no harsh, aliased square-wave edges (the old gem sound hurt on speakers)."""
    n = int((gap * (len(notes) - 1) + ring) * SR)
    out = [0.0] * n
    for j, f in enumerate(notes):
        start = int(j * gap * SR)
        length = int(ring * SR)
        for i in range(length):
            if start + i >= n:
                break
            t = i / SR
            attack = min(1.0, i / (0.006 * SR))
            release = min(1.0, (length - i) / (0.05 * SR))
            env = attack * release * math.exp(-7.0 * t)
            s = math.sin(math.tau * f * t) + 0.25 * math.sin(math.tau * f * 2.0 * t) * math.exp(-12.0 * t)
            out[start + i] += s * env
    peak = max(1e-6, max(abs(x) for x in out))
    return [x / peak * vol for x in out]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] if i < len(p) else 0.0 for p in parts) for i in range(n)]


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


save("slash", tone(0.16, 2600, 500, "saw", decay=5, noise=0.85, crush=2))
save("hit", mix(tone(0.12, 320, 90, "square", decay=6), tone(0.08, 1800, 600, "saw", decay=9, noise=0.9, crush=3)))
save("hurt", seq(tone(0.09, 520, 300, "square", decay=2), tone(0.16, 300, 120, "square", decay=3)))
save("break", mix(tone(0.22, 240, 60, "tri", decay=5, noise=0.7, crush=6), tone(0.1, 900, 300, "saw", decay=10, noise=0.9, crush=4)))
save("explosion", mix(tone(0.6, 160, 30, "tri", decay=4, noise=0.85, crush=10), tone(0.25, 90, 40, "sine", decay=3, vol=0.9)))
save("zap", tone(0.22, 1900, 240, "saw", decay=3.5, noise=0.35, crush=5))
save("gem", chime([784, 1047, 1319, 1568]), level=0.5)
save("heart", seq(tone(0.09, 660, 660, "tri", decay=1), tone(0.2, 990, 1040, "tri", decay=4)))
save("splash", tone(0.4, 900, 200, "sine", decay=4, noise=0.9, crush=3))
print("ok")
