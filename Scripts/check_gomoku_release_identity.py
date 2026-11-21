#!/usr/bin/env python3
"""Stop unsigned Gomoku IPA packaging if app identity or icons are wrong.

App release is Gomoku V2.0.0 build 200, distinct from model generation and checkpoint identity.
The application must contain the owner's exact committed AppIcon.
"""
from __future__ import annotations
import argparse
import plistlib
import sys
from pathlib import Path
from zipfile import ZipFile

EXPECTED = {
    "CFBundleIdentifier": "studio.zeo.gomoku",
    "CFBundleDisplayName": "Gomoku",
    "CFBundleShortVersionString": "2.0.0",
    "CFBundleVersion": "200",
}

def verify(info: dict, names: set[str], prefix: str) -> None:
    for key, wanted in EXPECTED.items():
        value = str(info.get(key, ""))
        if value != wanted:
            raise ValueError(f"{key}: expected {wanted!r}; actual {value!r}")
    for variant in ("CFBundleIcons", "CFBundleIcons~ipad"):
        icon = info.get(variant, {}).get("CFBundlePrimaryIcon", {})
        if icon.get("CFBundleIconName") != "AppIcon":
            raise ValueError(f"{variant}: approved AppIcon not declared")
        files = icon.get("CFBundleIconFiles", [])
        if not files:
            raise ValueError(f"{variant}: no primary icon files declared")
        for item in files:
            stem = Path(item).stem
            found = any(
                name.startswith(prefix + stem) and name.lower().endswith(".png")
                for name in names
            )
            if not found:
                raise ValueError(f"{variant}: compiled icon {item} absent")
    if prefix + "Assets.car" not in names:
        raise ValueError("Compiled icon asset catalog Assets.car missing")

def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--app", type=Path)
    group.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    try:
        if args.app:
            root = args.app
            with (root / "Info.plist").open("rb") as stream:
                data = plistlib.load(stream)
            names = {str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()}
            verify(data, names, "")
        else:
            with ZipFile(args.ipa) as z:
                prefix = "Payload/Gomoku.app/"
                names = set(z.namelist())
                data = plistlib.loads(z.read(prefix + "Info.plist"))
                verify(data, names, prefix)
        print("GOMOKU_RELEASE_IDENTITY_PASS: V2.0.0 Build 200; owner AppIcon installed")
        return 0
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException) as e:
        print("GOMOKU_RELEASE_IDENTITY_BLOCKED:", str(e), file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
