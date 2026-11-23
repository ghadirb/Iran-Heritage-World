#!/usr/bin/env python3
"""Print the signing certificate of an APK and (optionally) check it against the project's permanent key.

Usage: python3 tools/verify_apk_signature.py app/build/x.apk [--expect A7:83:...:AF]
Needs `apksigner` (Android build-tools) on PATH or under $ANDROID_HOME/build-tools/*/apksigner.
"""
import argparse, glob, os, re, shutil, subprocess, sys

def find_apksigner() -> str:
    exe = shutil.which("apksigner")
    if exe:
        return exe
    root = os.environ.get("ANDROID_HOME", "/usr/local/lib/android/sdk")
    cands = sorted(glob.glob(os.path.join(root, "build-tools", "*", "apksigner")))
    if not cands:
        raise SystemExit("apksigner not found")
    return cands[-1]

def norm(fp: str) -> str:
    return re.sub(r"[^0-9a-f]", "", fp.lower())

def gh_error(msg: str) -> None:
    """Show the reason as a GitHub annotation (readable without downloading the raw log)."""
    if os.environ.get("GITHUB_ACTIONS"):
        print("::error title=APK signature::" + msg.replace("\n", " | ")[:900])

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--expect", default="")
    args = ap.parse_args()
    try:
        signer = find_apksigner()
    except SystemExit as e:
        gh_error(str(e) + " ANDROID_HOME=" + os.environ.get("ANDROID_HOME", "") + " ANDROID_SDK_ROOT=" + os.environ.get("ANDROID_SDK_ROOT", ""))
        raise
    out = subprocess.run([signer, "verify", "--print-certs", args.apk], capture_output=True, text=True)
    print(out.stdout)
    if out.returncode != 0:
        print(out.stderr)
        gh_error("apksigner verify failed: " + (out.stderr or out.stdout)[:600])
        raise SystemExit("APK signature does not verify")
    m = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)", out.stdout)
    if not m:
        gh_error("no fingerprint in apksigner output: " + out.stdout[:600])
        raise SystemExit("could not read the certificate fingerprint")
    found = m.group(1).lower()
    print(f"Signing certificate SHA-256: {found}")
    if args.expect and norm(args.expect) != found:
        print(f"EXPECTED: {norm(args.expect)}")
        gh_error(f"WRONG KEY: found {found} expected {norm(args.expect)}")
        raise SystemExit("WRONG SIGNING KEY: this APK is not signed with the project's permanent key")
    if args.expect:
        print("OK: signed with the project's permanent key")

if __name__ == "__main__":
    main()
