#!/usr/bin/env python3
"""Convert the story clips in assets-source/Video/*.mp4 to Ogg Theora (the only video format Godot 4 plays)
into app/video/. Mapping of the Persian source names to stable ASCII ids lives in CLIPS below.
Usage: python3 tools/convert_video.py   (needs ffmpeg with libtheora + libvorbis)"""
import subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets-source" / "Video"
DST = ROOT / "app" / "video"
# source file name -> game clip id (see app/scripts/cutscene_data.gd)
CLIPS = {
    "زال و سیمرغ.1.mp4": "zal_nest",
    "زال و سیمرغ.2.mp4": "simorgh_flight",
    "زال و سیمرغ.3.3.mp4": "simorgh_feather",
}

def main() -> int:
    DST.mkdir(parents=True, exist_ok=True)
    bad = 0
    for name, clip_id in CLIPS.items():
        src = SRC / name
        if not src.exists():
            print(f"missing source: {src}")
            bad += 1
            continue
        out = DST / f"{clip_id}.ogv"
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
               "-vf", "scale=640:360:flags=lanczos", "-c:v", "libtheora", "-q:v", "5",
               "-c:a", "libvorbis", "-q:a", "1", "-ac", "1", "-ar", "32000", str(out)]
        subprocess.run(cmd, check=True)
        print(f"{out.name}: {out.stat().st_size / 1e6:.1f} MB")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
