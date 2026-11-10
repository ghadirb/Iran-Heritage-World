#!/usr/bin/env python3
"""Convert narration mp3/wav files from assets-source/audio into small mono OGG
files in app/audio/voice/, levelled to the same loudness (-18 LUFS).
Re-run after adding or replacing files. Requires ffmpeg (libvorbis)."""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets-source" / "audio"
DST = ROOT / "app" / "audio" / "voice"
TARGET_LUFS = -18.0
AMBIENT = {"water", "wind", "music_calm"}

def measure(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1]) if m else TARGET_LUFS

def main():
    DST.mkdir(parents=True, exist_ok=True)
    total = 0
    count = 0
    for f in sorted(SRC.iterdir()):
        if f.suffix.lower() not in (".mp3", ".wav") or f.stem in AMBIENT:
            continue
        gain = max(-12.0, min(12.0, TARGET_LUFS - measure(f)))
        out = DST / (f.stem + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(f), "-ac", "1",
                        "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89", "-c:a", "libvorbis", "-q:a", "3", str(out)], check=True)
        total += out.stat().st_size
        count += 1
    print(count, "files,", total // 1024, "KB")

if __name__ == "__main__":
    sys.exit(main())
