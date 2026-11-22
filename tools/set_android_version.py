#!/usr/bin/env python3
"""Write the Android version into app/export_presets.cfg.

version/code  = number of commits in the history (always grows, so every store update is accepted)
version/name  = <base>.<commit count>   or the value of --name (e.g. a release tag without the leading 'v')

Usage: python3 tools/set_android_version.py [--name 1.0.0] [--base 0.1]
"""
import argparse, re, subprocess
from pathlib import Path

PRESET = Path(__file__).resolve().parent.parent / "app" / "export_presets.cfg"

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", default="")
    ap.add_argument("--base", default="0.1")
    args = ap.parse_args()
    count = int(subprocess.run(["git", "rev-list", "--count", "HEAD"], check=True, capture_output=True, text=True).stdout.strip())
    name = args.name.strip().lstrip("v") or f"{args.base}.{count}"
    text = PRESET.read_text(encoding="utf-8")
    text, n1 = re.subn(r"^version/code=\d+$", f"version/code={count}", text, flags=re.M)
    text, n2 = re.subn(r'^version/name="[^"]*"$', f'version/name="{name}"', text, flags=re.M)
    if n1 != 1 or n2 != 1:
        raise SystemExit("could not find version/code and version/name in export_presets.cfg")
    PRESET.write_text(text, encoding="utf-8")
    print(f"Android version: code={count} name={name}")

if __name__ == "__main__":
    main()
