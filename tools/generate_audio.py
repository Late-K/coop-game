"""Generates the placeholder sound set into audio/placeholder/ (standard library only).

Aims at Signalis (industrial drones, crunchy lo-fi effects, radio static, distant
machinery) and Undertale's lab areas (fluorescent hum, drips, eerie detuned pads,
text blips). Everything is 22 kHz mono, a little bitcrushed. Loops carry a WAV
'smpl' loop chunk, which Godot's importer picks up ("Detect From WAV").

Replace any file with a real recording of the same name and the game uses it.
Run from the project root:  python tools/generate_audio.py [sound names...]
(no names: all of them)
"""
import math
import os
import random
import struct
import sys

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "placeholder")
TAU = 2 * math.pi


# --- building blocks -------------------------------------------------------------

def silence(seconds):
    return [0.0] * int(seconds * SR)


def length(seconds):
    return int(seconds * SR)


def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(n)]


def tone(freq, n, shape="sine", phase=0.0, vibrato=(0.0, 0.0)):
    """freq may be a number or a function of time (seconds)."""
    out = []
    rate, depth = vibrato
    for i in range(n):
        t = i / SR
        f = freq(t) if callable(freq) else freq
        f += depth * math.sin(TAU * rate * t)
        phase += f / SR
        p = phase % 1.0
        if shape == "sine":
            out.append(math.sin(TAU * p))
        elif shape == "square":
            out.append(1.0 if p < 0.5 else -1.0)
        elif shape == "saw":
            out.append(2 * p - 1)
    return out


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a number or a per-sample function of time."""
    y, out = 0.0, []
    for i, s in enumerate(x):
        c = cutoff(i / SR) if callable(cutoff) else cutoff
        a = 1 - math.exp(-TAU * c / SR)
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    low = lowpass(x, cutoff)
    return [s - l for s, l in zip(x, low)]


def bandpass(x, low_cut, high_cut):
    return lowpass(highpass(x, low_cut), high_cut)


def envelope(n, attack=0.005, decay=None, release=0.01):
    """Linear attack, optional exponential decay (time constant), short release."""
    out = []
    a, r = max(1, int(attack * SR)), max(1, int(release * SR))
    for i in range(n):
        v = min(1.0, i / a)
        if decay:
            v *= math.exp(-i / SR / decay)
        if i > n - r:
            v *= (n - i) / r
        out.append(v)
    return out


def mul(x, y):
    return [a * b for a, b in zip(x, y)]


def gain(x, g):
    return [s * g for s in x]


def mix(n, *layers):
    """Each layer is (samples, offset_seconds) or just samples."""
    out = [0.0] * n
    for layer in layers:
        samples, offset = layer if isinstance(layer, tuple) else (layer, 0.0)
        start = int(offset * SR)
        for i, s in enumerate(samples):
            if 0 <= start + i < n:
                out[start + i] += s
    return out


def drive(x, amount):
    return [math.tanh(s * amount) / math.tanh(amount) for s in x]


def crush(x, bits=10, hold=1):
    """Bit depth and sample-and-hold: the lo-fi crunch."""
    steps = 2 ** (bits - 1)
    out, held = [], 0.0
    for i, s in enumerate(x):
        if i % hold == 0:
            held = round(s * steps) / steps
        out.append(held)
    return out


def normalize(x, peak=0.8):
    m = max(1e-9, max(abs(s) for s in x))
    return [s * peak / m for s in x]


def normalize_rms(x, target_db):
    """Sets the average level (what the ear judges loudness by), keeping peaks below 0 dBFS."""
    r = math.sqrt(sum(s * s for s in x) / len(x)) or 1e-9
    g = 10 ** (target_db / 20) / r
    peak = max(abs(s) for s in x) * g
    if peak > 0.98:
        g *= 0.98 / peak
    return [s * g for s in x]


def resonator(x, center, q):
    """Two-pole band-pass (RBJ). center may be a function of time: a swept howl."""
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for i, s in enumerate(x):
        f = center(i / SR) if callable(center) else center
        w0 = TAU * f / SR
        alpha = math.sin(w0) / (2 * q)
        a0 = 1 + alpha
        y = (alpha * s - alpha * x2 + 2 * math.cos(w0) * y1 - (1 - alpha) * y2) / a0
        x2, x1, y2, y1 = x1, s, y1, y
        out.append(y)
    return out


def phrases(n, seed, on=(2.0, 4.0), off=(1.5, 3.5), fade=0.8):
    """An envelope that plays in phrases with silences between, like a sparse score."""
    rng = random.Random(seed)
    env, i, playing = [0.0] * n, 0, True
    while i < n:
        span = int(rng.uniform(*(on if playing else off)) * SR)
        if playing:
            f = int(fade * SR)
            for k in range(min(span, n - i)):
                env[i + k] = min(1.0, k / f, (span - k) / f)
        i += span
        playing = not playing
    return env


def loopify(x, fade=1.0):
    """Crossfades the tail into the head so the loop point is seamless."""
    f = int(fade * SR)
    body = x[: len(x) - f]
    for i in range(f):
        w = i / f
        body[i] = body[i] * w + x[len(x) - f + i] * (1 - w)
    return body


def metal(n, partials, decay, seed=0):
    """Inharmonic struck metal: clanks, rings."""
    rng = random.Random(seed)
    out = [0.0] * n
    for p in partials:
        amp = rng.uniform(0.4, 1.0)
        d = decay * rng.uniform(0.6, 1.2)
        for i, s in enumerate(tone(p, n)):
            out[i] += s * amp * math.exp(-i / SR / d)
    return out


def write_wav(name, x, loop=False):
    os.makedirs(OUT, exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in x)
    chunks = [b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16),
              b"data" + struct.pack("<I", len(data)) + data]
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    body = b"WAVE" + b"".join(chunks)
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(f"  {name}.wav  {len(x) / SR:.2f}s{'  (loop)' if loop else ''}")


# --- ambience (loops) -------------------------------------------------------------

def amb_facility():
    """Signalis-style industrial bed: a deep sub drone under detuned low tones, machinery in the
    low mids, slow swells that sink into lulls, sparse distant events. Very dark."""
    n = length(13)
    swell = [0.55 + 0.45 * math.sin(TAU * 0.06 * i / SR) * math.sin(TAU * 0.023 * i / SR + 1) for i in range(n)]
    drone = mix(n, gain(tone(82.0, n), 0.5), gain(tone(83.1, n), 0.45), gain(tone(110.5, n), 0.3),
                gain(lowpass(tone(164.8, n, "saw"), 600), 0.3), gain(tone(41.0, n), 0.42),
                gain(tone(41.4, n), 0.3), gain(lowpass(tone(246.9, n, "saw"), 700), 0.12),
                gain(tone(311.1, n, vibrato=(0.2, 1.0)), 0.3), gain(lowpass(tone(370.0, n, "saw"), 700), 0.14))
    machine = mul(bandpass(noise(n, 2), 250, 600),
                  [0.3 + 0.5 * max(0.0, math.sin(TAU * 0.31 * i / SR)) ** 4 for i in range(n)])
    rumble = gain(bandpass(noise(n, 1), 60, 300), 1.2)
    clank = bandpass(metal(length(2.5), [173, 296, 467, 731, 1012], 0.9, seed=3), 150, 1500)
    thump = mul(tone(lambda t: 55 + 40 * math.exp(-t / 0.08), length(1.2)), envelope(length(1.2), 0.01, 0.3))
    out = mul(mix(n, drone, gain(machine, 2.5), rumble), swell)
    out = mix(n, out, (gain(clank, 0.4), 4.2), (gain(clank, 0.14), 4.55), (gain(clank, 0.25), 9.8),
              (gain(thump, 0.5), 7.1))
    return crush(normalize_rms(loopify(out), -22), bits=11)


def amb_whiteout():
    """Wind as a muffled, tonal howl (swept resonance) over dark gusts, not white hiss."""
    n = length(13)
    gust = lambda t: 0.5 + 0.3 * math.sin(TAU * 0.09 * t) + 0.2 * math.sin(TAU * 0.23 * t + 1.3)
    body = lowpass(highpass(noise(n, 4), 70), lambda t: 100 + 280 * gust(t) ** 2)
    body = mul(body, [0.4 + 0.6 * gust(i / SR) for i in range(n)])
    howl = resonator(noise(n, 40), lambda t: 210 + 150 * gust(t), 9.0)
    howl = mul(howl, [gust(i / SR) ** 2 for i in range(n)])
    buffet = lowpass(noise(n, 5), 60)
    out = mix(n, gain(body, 2.5), gain(howl, 0.8), gain(buffet, 0.8))
    return crush(normalize_rms(loopify(lowpass(out, 1400)), -23), bits=11)


def amb_lab():
    """Undertale-lab feeling: fluorescent buzz (mostly its harmonics, not the 60 Hz), an eerie
    detuned pad in the low mids that plays in phrases with silence between, and drips."""
    n = length(13)
    rng = random.Random(6)
    hum = mix(n, gain(tone(60, n), 0.05), gain(tone(120, n), 0.1), gain(tone(180, n), 0.06),
              gain(lowpass(tone(240, n, "square"), 900), 0.03))
    flicker = [1.0] * n
    for _ in range(5):
        start, dur = rng.randint(0, n - 4000), rng.randint(300, 2500)
        for i in range(start, start + dur):
            flicker[i] = 0.2 if rng.random() < 0.5 else 1.4
    hum = mul(hum, flicker)
    pad = mix(n, tone(277.2, n), tone(293.7, n), gain(tone(415.3, n, vibrato=(0.3, 1.5)), 0.6),
              gain(tone(349.2, n), 0.35))
    pad = gain(mul(lowpass(pad, 1300), phrases(n, 41)), 0.8)
    drip_n = length(0.6)
    drip = mul(tone(lambda t: 900 + 900 * math.exp(-t / 0.02), drip_n), envelope(drip_n, 0.001, 0.12))
    out = mix(n, hum, pad, (gain(drip, 0.35), 2.1), (gain(drip, 0.12), 2.35), (gain(drip, 0.3), 7.4),
              (gain(drip, 0.1), 7.65), (gain(drip, 0.25), 11.0))
    return crush(normalize_rms(loopify(out), -24), bits=11)


def heater_loop():
    n = length(4)
    rng = random.Random(7)
    crackle = [0.0] * n
    for _ in range(60):
        i = rng.randint(0, n - 200)
        for k in range(rng.randint(20, 120)):
            crackle[i + k] += rng.uniform(-1, 1) * math.exp(-k / 30)
    out = mix(n, gain(tone(50, n), 0.3), gain(lowpass(noise(n, 8), 400), 1.2), gain(highpass(crackle, 800), 0.5))
    return crush(normalize(loopify(out, 0.4), 0.6), bits=10)


def lamp_hum():
    n = length(2)
    out = mix(n, gain(lowpass(tone(120, n, "square"), 700), 0.6), gain(tone(240, n), 0.2),
              gain(lowpass(noise(n, 9), 2000), 0.08))
    return crush(normalize_rms(out, -22), bits=10)


# --- effects ------------------------------------------------------------------------

def step(surface):
    n = length(0.12)
    if surface == "snow":
        grains = mul(noise(n, 10), [random.Random(11 + i // 60).uniform(0.2, 1.0) for i in range(n)])
        out = mul(lowpass(grains, 1600), envelope(n, 0.004, 0.04))
    else:
        out = mix(n, mul(bandpass(noise(n, 12), 600, 3000), envelope(n, 0.001, 0.015)),
                  gain(metal(n, [430, 1190, 2210], 0.05, seed=13), 0.3))
    return crush(normalize(out, 0.7), bits=9)


def gunshot():
    n = length(1.1)
    thump = mul(tone(lambda t: 45 + 110 * math.exp(-t / 0.05), n), envelope(n, 0.001, 0.12))
    crack = mul(noise(n, 14), envelope(n, 0.0005, 0.03))
    tail = mul(lowpass(noise(n, 15), 900), envelope(n, 0.01, 0.35))
    return crush(drive(normalize(mix(n, thump, gain(crack, 0.9), gain(tail, 1.4)), 1.0), 2.5), bits=8, hold=2)


def click(seed=16):
    n = length(0.05)
    out = mix(n, mul(noise(n, seed), envelope(n, 0.0005, 0.004)), mul(tone(2300, n), envelope(n, 0.0005, 0.012)))
    return normalize(out, 0.5)


def reload():
    n = length(0.8)
    slide = mul(bandpass(noise(length(0.12), 17), 800, 4000), envelope(length(0.12), 0.01, 0.05))
    return crush(normalize(mix(n, click(18), (gain(slide, 0.5), 0.25), (click(19), 0.62)), 0.6), bits=9)


def door():
    """Electric bulkhead: a rising servo whine over a short rumble, ending in a bright clank."""
    n = length(1.15)
    servo_n = length(0.85)
    servo = mul(lowpass(tone(lambda t: 170 + 110 * t / 0.85, servo_n, "saw"), 2500),
                envelope(servo_n, 0.08, None, 0.12))
    hiss = mul(bandpass(noise(n, 20), 1500, 6000), envelope(n, 0.01, 0.15))
    rumble = mul(bandpass(noise(n, 21), 80, 400), [min(1.0, i / SR / 0.15) for i in range(n)])
    clank = bandpass(metal(length(0.4), [240, 397, 610, 980, 1450], 0.15, seed=22), 200, 4000)
    out = mix(n, gain(servo, 0.5), gain(hiss, 0.25), gain(mul(rumble, envelope(n, 0.05, 0.5)), 1.2), (clank, 0.78))
    return crush(normalize(out, 0.7), bits=10)


def tube(arriving):
    n = length(1.2)
    sweep = (lambda t: 3000 - 2600 * t / 1.0) if arriving else (lambda t: 300 + 2700 * t / 1.0)
    whoosh = mul(lowpass(noise(n, 23), sweep), envelope(n, 0.05, 0.5))
    thunk = mul(tone(lambda t: 60 + 80 * math.exp(-t / 0.03), length(0.3)), envelope(length(0.3), 0.001, 0.07))
    return crush(normalize(mix(n, gain(whoosh, 1.5), (thunk, 0.85 if arriving else 0.0)), 0.7), bits=10)


def blip_pair(f1, f2):
    n1 = length(0.05)
    a = mul(lowpass(tone(f1, n1, "square"), 3500), envelope(n1, 0.002, None, 0.01))
    b = mul(lowpass(tone(f2, n1, "square"), 3500), envelope(n1, 0.002, None, 0.01))
    return crush(normalize(a + b, 0.45), bits=8)


def keypad_press():
    n = length(0.06)
    return crush(normalize(mix(n, mul(tone(1250, n, "square"), envelope(n, 0.001, 0.02)), click(24)), 0.4), bits=8)


def code_wrong():
    n = length(0.5)
    buzz = mix(n, tone(110, n, "square"), tone(116, n, "square"))
    gate = [1.0 if (i // length(0.08)) % 2 == 0 else 0.0 for i in range(n)]
    return crush(normalize(mul(lowpass(buzz, 1500), mul(gate, envelope(n))), 0.5), bits=8)


def code_right():
    n = length(1.8)
    bell = mix(n, metal(n, [523.3, 787.0, 1310.0], 0.7, seed=25), gain(metal(n, [528.0, 1580.0], 0.4, seed=26), 0.4))
    return crush(normalize(lowpass(bell, 3000), 0.5), bits=10)


def lights_on():
    """Breaker clunk, an electric zap, then a buzzing tube flickering into life."""
    n = length(1.0)
    clunk = mul(tone(lambda t: 80 + 80 * math.exp(-t / 0.03), length(0.25)), envelope(length(0.25), 0.001, 0.06))
    zap = mul(bandpass(noise(length(0.3), 37), 1000, 6000), envelope(length(0.3), 0.001, 0.05))
    rng = random.Random(27)
    flicker = [(1.0 if rng.random() < 0.8 else 0.1) for _ in range(n // 300 + 1)]
    buzz = mul(lowpass(tone(120, n, "square"), 3000),
               [min(1.0, i / SR / 0.3) * flicker[i // 300] * math.exp(-i / SR / 0.6) for i in range(n)])
    return crush(normalize(mix(n, gain(clunk, 0.6), gain(zap, 2.2), (gain(buzz, 0.6), 0.05)), 0.7), bits=9)


def hurt():
    """A body hit with weight in the low mids (not sub) and a crunchy edge."""
    n = length(0.45)
    thud = mul(tone(lambda t: 110 + 90 * math.exp(-t / 0.05), n), envelope(n, 0.001, 0.12))
    crunch = mul(bandpass(noise(n, 28), 300, 1800), envelope(n, 0.001, 0.05))
    return crush(drive(normalize(mix(n, thud, gain(crunch, 1.5)), 1.0), 3.0), bits=8)


def death():
    n = length(2.8)
    swell = [min(1.0, (i / SR / 2.2) ** 2) for i in range(n)]
    drone = mix(n, tone(55, n), tone(58.3, n), gain(tone(82.4, n, "saw"), 0.2))
    rev_noise = mul(lowpass(noise(n, 29), lambda t: 200 + 2500 * (t / 2.8) ** 3), swell)
    out = mul(mix(n, gain(drone, 0.7), gain(rev_noise, 2.0)), swell)
    cut = length(2.45)
    out = [s if i < cut else s * math.exp(-(i - cut) / 300) for i, s in enumerate(out)]
    return crush(drive(normalize(out, 1.0), 1.8), bits=8, hold=2)


def enemy_growl():
    n = length(1.3)
    body = tone(lambda t: 62 + 10 * math.sin(TAU * 6 * t), n, "saw")
    rasp = mul(bandpass(noise(n, 30), 300, 900), [0.5 + 0.5 * math.sin(TAU * 11 * i / SR) for i in range(n)])
    static = crush(noise(n, 31), bits=3, hold=8)
    out = mul(mix(n, body, gain(rasp, 1.2), gain(lowpass(static, 3000), 0.15)), envelope(n, 0.15, 0.6))
    return crush(drive(normalize(out, 1.0), 3.0), bits=8, hold=2)


def enemy_hit():
    n = length(0.5)
    out = mix(n, metal(n, [311, 497, 851, 1303, 1777], 0.15, seed=32), mul(noise(n, 33), envelope(n, 0.0005, 0.01)))
    return crush(normalize(out, 0.6), bits=9)


def text_blip(voice):
    """Undertale-style text sounds: short, bright, tonal. ZP-SYS sits near Undertale's generic
    text blip; PROCTOR is bright and tonal like Flowey's voice, but two detuned tones beat
    against each other so it is subtly wrong."""
    if voice == "sys":
        n = length(0.06)
        out = mul(lowpass(tone(900, n, "square"), 4000), envelope(n, 0.001, 0.025, 0.01))
        return crush(normalize(out, 0.4), bits=7)
    if voice == "proctor":
        n = length(0.065)
        out = mix(n, tone(600, n, "square"), gain(tone(617, n, "square"), 0.8))
        return crush(normalize(mul(lowpass(out, 5000), envelope(n, 0.001, 0.03, 0.01)), 0.4), bits=6)
    n = length(0.04)  # narration
    return normalize(mul(tone(520, n), envelope(n, 0.006, 0.02, 0.012)), 0.2)


def static_burst():
    """Bright radio static: full-band crackle, lightly crushed."""
    n = length(0.3)
    out = mul(highpass(crush(noise(n, 35), bits=5, hold=2), 400), envelope(n, 0.003, 0.1))
    return normalize(out, 0.45)


def radio_key():
    """Push-to-talk: a switch click, then the short rising chirp of a handheld radio."""
    n = length(0.12)
    click = mul(highpass(noise(length(0.008), 37), 1500), envelope(length(0.008), 0.0003, 0.002))
    low = mul(tone(1200, length(0.04), "square"), envelope(length(0.04), 0.002, None, 0.01))
    high = mul(tone(1600, length(0.05), "square"), envelope(length(0.05), 0.002, None, 0.01))
    chirp = bandpass(mix(length(0.1), low, (high, 0.045)), 400, 3000)
    return crush(normalize(mix(n, click, (chirp, 0.012)), 0.5), bits=7)


def radio_unkey():
    """Release: the squelch tail, a short burst of band-limited static that cuts off."""
    n = length(0.2)
    out = mul(bandpass(crush(noise(n, 38), bits=5, hold=2), 400, 3200), envelope(n, 0.002, None, 0.03))
    return normalize(out, 0.4)


def radio_static():
    """Hiss between stations: crushed band-limited noise, slowly fading, with crackle. Loops."""
    n = length(4.3)
    hiss = bandpass(crush(noise(n, 40), bits=6, hold=2), 300, 3500)
    fade = [0.75 + 0.25 * math.sin(TAU * 0.4 * i / SR) * math.sin(TAU * 0.13 * i / SR + 1) for i in range(n)]
    rng = random.Random(41)
    pops = [0.0] * n
    for _ in range(14):
        p = rng.randrange(n - 200)
        for k in range(rng.randrange(20, 120)):
            pops[p + k] = rng.uniform(-1, 1)
    return loopify(normalize(mix(n, mul(hiss, fade), gain(pops, 0.5)), 0.5), 0.3)


def radio_beacon():
    """Distress beacon: a 1 kHz tone keyed in Morse (SOS), then a pause. Loops."""
    unit, t, layers = 0.09, 0.3, []
    for ch in "... --- ...":
        if ch == " ":
            t += unit * 2
            continue
        d = unit if ch == "." else unit * 3
        layers.append((mul(tone(1000, length(d), "square"), envelope(length(d), 0.004, None, 0.006)), t))
        t += d + unit
    return crush(normalize(lowpass(mix(length(4.0), *layers), 3000), 0.45), bits=8)


def radio_numbers():
    """A numbers station: a two-note interval chime, then flat synthetic syllables. Loops."""
    rng = random.Random(39)
    layers = [(mul(tone(784, length(0.25)), envelope(length(0.25), 0.005, 0.08)), 0.1),
              (mul(tone(587, length(0.35)), envelope(length(0.35), 0.005, 0.1)), 0.35)]
    vowels = [(700, 1200), (400, 2000), (300, 900), (500, 1500)]
    t = 1.2
    for i in range(8):
        d = 0.32
        f1, f2 = vowels[rng.randrange(4)]
        src = tone(110, length(d), "saw")
        syllable = mix(length(d), resonator(src, f1, 6), gain(resonator(src, f2, 8), 0.6))
        layers.append((mul(syllable, envelope(length(d), 0.03, None, 0.08)), t))
        t += d + (0.25 if i % 2 == 0 else 0.55)
    return crush(normalize(mix(length(6.5), *layers), 0.5), bits=8)


def shove():
    """A shove: a dull body thud and a scuff of cloth."""
    n = length(0.22)
    thud = mul(lowpass(noise(n, 42), 400), envelope(n, 0.002, 0.05))
    scuff = mul(bandpass(noise(n, 43), 800, 2500), envelope(n, 0.01, 0.06))
    body = mul(tone(lambda t: 90 - 120 * t, n), envelope(n, 0.002, 0.07))
    return crush(normalize(mix(n, thud, gain(scuff, 0.4), gain(body, 0.8)), 0.6), bits=9)


def sting_chapter():
    n = length(7)
    wobble = lambda t: 1 + 0.004 * math.sin(TAU * 0.3 * t)
    chord = mix(n, tone(lambda t: 55 * wobble(t), n), tone(lambda t: 82.4 * wobble(t), n),
                gain(tone(lambda t: 116.5 * wobble(t), n), 0.7), gain(tone(lambda t: 164.8 * wobble(t), n, "saw"), 0.08))
    env = [min(1.0, i / SR / 2.5) * (1.0 if i < length(4.5) else math.exp(-(i - length(4.5)) / SR / 0.8)) for i in range(n)]
    air = mul(lowpass(noise(n, 36), 600), env)
    return crush(normalize(mix(n, mul(lowpass(chord, 1200), env), gain(air, 1.5)), 0.7), bits=10)


SOUNDS = {
    "amb_facility": (amb_facility, True),
    "amb_whiteout": (amb_whiteout, True),
    "amb_lab": (amb_lab, True),
    "heater_loop": (heater_loop, True),
    "lamp_hum": (lamp_hum, True),
    "step_snow": (lambda: step("snow"), False),
    "step_metal": (lambda: step("metal"), False),
    "gunshot": (gunshot, False),
    "gun_empty": (click, False),
    "reload": (reload, False),
    "door": (door, False),
    "tube_send": (lambda: tube(False), False),
    "tube_arrive": (lambda: tube(True), False),
    "pickup": (lambda: blip_pair(660, 990), False),
    "keypad_press": (keypad_press, False),
    "code_wrong": (code_wrong, False),
    "code_right": (code_right, False),
    "lights_on": (lights_on, False),
    "hurt": (hurt, False),
    "death": (death, False),
    "enemy_growl": (enemy_growl, False),
    "enemy_hit": (enemy_hit, False),
    "blip_sys": (lambda: text_blip("sys"), False),
    "blip_proctor": (lambda: text_blip("proctor"), False),
    "blip_narration": (lambda: text_blip("narration"), False),
    "static": (static_burst, False),
    "radio_key": (radio_key, False),
    "radio_unkey": (radio_unkey, False),
    "shove": (shove, False),
    "radio_static": (radio_static, True),
    "radio_beacon": (radio_beacon, True),
    "radio_numbers": (radio_numbers, True),
    "sting_chapter": (sting_chapter, False),
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(SOUNDS)
    print(f"Writing {len(names)} sounds to {OUT}")
    for name in names:
        make, loop = SOUNDS[name]
        write_wav(name, make(), loop)
