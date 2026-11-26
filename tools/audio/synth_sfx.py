"""Sound effects synthesised in code (batch 17), for sounds the CC0 packs have no good
sample for: the bow and crossbow had creaking door samples (creak1/creak2) in them.
make_audio.py loads these as layers "synth:<name>" and gives them the same treatment as
everything else (low-pass, stone-room reflection, trim, fade, peak -1 dBFS).
Every function returns mono float32 at SR, deterministic (fixed seeds).

  bow_draw         0.42 s  the string pulled back: a soft rising stretch of filtered noise and
                           a faint tone, a cloth rustle at the start; no stick-slip pulses
                           (those are what makes a creak)
  crossbow_shot    0.40 s  trigger click, a low string twang (plucked string, Karplus-Strong)
                           with a wooden thump, the bolt's short whoosh
  crossbow_reload  0.62 s  a ratchet of six clicks speeding up, then the latch: a metal clack
                           over a wooden knock
"""
import numpy as np
from scipy import signal

SR = 44100


def _t(seconds):
    return np.arange(int(seconds * SR)) / SR


def _band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def _env(n, attack, decay):
    """Attack (s) then exponential decay (time constant, s)."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def _place(out, x, at):
    i = int(at * SR)
    end = min(len(out), i + len(x))
    out[i:end] += x[:end - i]


def _pluck(freq, seconds, damping, rnd):
    """Karplus-Strong plucked string."""
    n = int(seconds * SR)
    period = int(SR / freq)
    buf = rnd.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = damping * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out


def _click(rnd, freq, decay=0.004, partials=(1.0, 1.62, 2.41), ring_gain=0.6):
    """A short metal click: a noise tick plus a few inharmonic ringing partials."""
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    tick = _band(rnd.normal(0, 1, n), 2500, 9000) * np.exp(-t / 0.0015)
    ring = sum(np.sin(2 * np.pi * freq * p * t + rnd.uniform(0, 6)) / (k + 1)
               for k, p in enumerate(partials)) * np.exp(-t / decay)
    return tick * 0.8 + ring * ring_gain


def bow_draw():
    rnd = np.random.default_rng(31)
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    # stretch: smooth band noise, its band sliding up a little as the string tightens
    noise = rnd.normal(0, 1, n)
    low = _band(noise, 300, 1400)
    high = _band(noise, 1400, 3200)
    slide = np.clip(t / 0.35, 0, 1)
    stretch = low * (1 - 0.5 * slide) + high * 0.6 * slide
    swell = np.clip(t / 0.30, 0, 1) ** 1.5 * (1 - np.clip((t - 0.34) / 0.08, 0, 1))
    stretch *= swell * 0.5
    # a faint string tone rising 150 -> 210 Hz (sine with its 2nd harmonic), no pulses
    f = 150 + 60 * slide
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = (np.sin(phase) + 0.35 * np.sin(2 * phase)) * swell * 0.18
    # cloth / leather rustle as the hand pulls
    rustle = _band(rnd.normal(0, 1, n), 1800, 6000) * _env(n, 0.01, 0.05) * 0.35
    return (stretch + tone + rustle).astype(np.float32)


def crossbow_shot():
    rnd = np.random.default_rng(47)
    n = int(0.40 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    _place(out, _click(rnd, 2600, 0.006) * 0.7, 0.0)                     # trigger
    twang = _pluck(98, 0.32, 0.993, rnd) * _env(int(0.32 * SR), 0.001, 0.09)
    _place(out, twang * 1.0, 0.008)                                      # the string
    thump = np.sin(2 * np.pi * 72 * t[:int(0.12 * SR)]) * _env(int(0.12 * SR), 0.002, 0.03)
    _place(out, thump * 0.9, 0.008)                                      # the stock kicks
    whoosh_n = int(0.22 * SR)
    whoosh = _band(rnd.normal(0, 1, whoosh_n), 900, 4500)
    w_env = np.sin(np.pi * np.clip(np.arange(whoosh_n) / whoosh_n, 0, 1)) ** 2
    _place(out, whoosh * w_env * 0.35, 0.02)                             # the bolt leaves
    return out.astype(np.float32)


def crossbow_reload():
    rnd = np.random.default_rng(59)
    out = np.zeros(int(0.62 * SR))
    at = 0.0
    gaps = [0.085, 0.078, 0.070, 0.064, 0.058, 0.0]
    for k, gap in enumerate(gaps):  # the ratchet: six clicks, faster and a little higher
        _place(out, _click(rnd, 1700 + 90 * k, 0.0025, ring_gain=0.25) * (0.5 + 0.04 * k), at)
        at += gap
    latch_at = at + 0.12
    _place(out, _click(rnd, 1250, 0.03, (1.0, 1.48, 2.17, 3.1)) * 1.0, latch_at)   # metal clack
    knock_n = int(0.1 * SR)
    knock = np.sin(2 * np.pi * 160 * np.arange(knock_n) / SR) * _env(knock_n, 0.001, 0.02)
    _place(out, knock * 0.7, latch_at)                                   # wooden knock
    return out.astype(np.float32)


SYNTH = {"bow_draw": bow_draw, "crossbow_shot": crossbow_shot, "crossbow_reload": crossbow_reload}
