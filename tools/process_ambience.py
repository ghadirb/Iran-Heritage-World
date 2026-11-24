#!/usr/bin/env python3
"""Make seamless loops from assets-source/audio/*.wav and encode them as OGG
into app/audio/. The tail is cross-faded (equal power) over the head so the
loop point has no dip. Requires numpy + ffmpeg (libvorbis)."""
import subprocess, wave, sys, pathlib
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets-source" / "audio"
DST = ROOT / "app" / "audio"
# name -> (output, crossfade seconds, peak target)
JOBS = {
    "water.wav": ("ambient_water.ogg", 2.0, 0.85),
    "wind.wav": ("ambient_wind.ogg", 3.0, 0.85),
    "music_calm.wav": ("music_calm.ogg", 4.0, 0.80),
}

def load(path):
    with wave.open(str(path)) as w:
        sr, ch = w.getframerate(), w.getnchannels()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    return sr, data.reshape(-1, ch)

def loop_crossfade(x, sr, secs):
    n = int(sr * secs)
    t = np.linspace(0.0, np.pi / 2, n, dtype=np.float32)[:, None]
    blend = x[-n:] * np.cos(t) + x[:n] * np.sin(t)
    return np.concatenate([blend, x[n:-n]], axis=0)

def main():
    DST.mkdir(parents=True, exist_ok=True)
    for name, (out, xf, peak) in JOBS.items():
        sr, x = load(SRC / name)
        y = loop_crossfade(x, sr, xf)
        y *= peak / max(float(np.abs(y).max()), 1e-6)
        pcm = (y * 32767).astype(np.int16).tobytes()
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(sr),
               "-ac", str(y.shape[1]), "-i", "-", "-c:a", "libvorbis", "-q:a", "3", str(DST / out)]
        subprocess.run(cmd, input=pcm, check=True)
        print(out, round(len(y) / sr, 1), "s", (DST / out).stat().st_size // 1024, "KB")

if __name__ == "__main__":
    sys.exit(main())
