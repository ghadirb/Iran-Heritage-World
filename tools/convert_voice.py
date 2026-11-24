#!/usr/bin/env python3
"""Convert source narration and sound effects into small mono OGG game assets.

Narration files use their stable ``level__key`` name and are placed in
``app/audio/voice``.  Named effects belong in ``app/audio/sfx``.  Re-run after
adding or replacing source audio. Requires ffmpeg (libvorbis)."""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets-source" / "audio"
DST_VOICE = ROOT / "app" / "audio" / "voice"
DST_SFX = ROOT / "app" / "audio" / "sfx"
TARGET_LUFS = -18.0
AMBIENT = {"water", "wind", "music_calm"}
# Source file names are deliberately kept in Persian, but runtime identifiers
# stay ASCII so they are safe in exported resource paths.
SFX = {
    "صدای شلیک کمان": "bow_shot",
    "کشیدن و رها کردن تیر از کمان": "bow_draw_release",
}

def measure(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1]) if m else TARGET_LUFS

def destination(source):
    if source.stem in SFX:
        return DST_SFX / (SFX[source.stem] + ".ogg")
    # Source narration is intentionally explicit: do not accidentally ship an
    # unrelated recording just because it was dropped into assets-source.
    if "__" in source.stem:
        return DST_VOICE / (source.stem + ".ogg")
    return None

def main():
    DST_VOICE.mkdir(parents=True, exist_ok=True)
    DST_SFX.mkdir(parents=True, exist_ok=True)
    total = 0
    voices = 0
    effects = 0
    for f in sorted(SRC.iterdir()):
        if f.suffix.lower() not in (".mp3", ".wav") or f.stem in AMBIENT:
            continue
        out = destination(f)
        if out is None:
            print("skipped unrecognised audio:", f.name)
            continue
        gain = max(-12.0, min(12.0, TARGET_LUFS - measure(f)))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(f), "-ac", "1",
                        "-ar", "24000", "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89",
                        "-c:a", "libvorbis", "-q:a", "3", str(out)], check=True)
        total += out.stat().st_size
        if f.stem in SFX:
            effects += 1
        else:
            voices += 1
    print(voices, "voice files,", effects, "sound effects,", total // 1024, "KB")

if __name__ == "__main__":
    sys.exit(main())
