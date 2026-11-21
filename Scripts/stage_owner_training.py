#!/usr/bin/env python3
"""Prepare three verified original owner archives for an explicitly personal IPA.

Never run in general CI or for public distribution. A bundled archive is
readable in the IPA; the generated private resource directory is gitignored.
"""
from __future__ import annotations
import argparse
import os
from pathlib import Path
from verify_owner_training_evidence import (
    ARCHIVE, ROOT, NOVEMBER_EXPORTS, audit_bytes,
    audit_november_export, november_path,
)

DESTINATION = ROOT / "Apps/iOS/Gomoku/Resources/OwnerPrivate"
OCT_NAME = "VeilLink-Gomoku-OwnerTraining-20261031.vltrain.json"


def main() -> None:
    parser = argparse.ArgumentParser()
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument("--owner-build", action="store_true")
    choice.add_argument("--unstage", action="store_true")
    parser.add_argument("--acknowledge-private-bundle", action="store_true")
    args = parser.parse_args()
    names = [OCT_NAME] + [entry["name"] for entry in NOVEMBER_EXPORTS]
    if args.unstage:
        for name in names:
            (DESTINATION / name).unlink(missing_ok=True)
        print("Unstaged all original owner-only training archives")
        return
    if not args.acknowledge_private_bundle:
        parser.error("Personal records are readable inside this IPA. "
                     "Use --acknowledge-private-bundle only for private use.")

    # All three files must pass authenticity checks before touching the
    # private application resource directory.
    content = {OCT_NAME: ARCHIVE.read_bytes()}
    audit_bytes(content[OCT_NAME])
    for entry in NOVEMBER_EXPORTS:
        data = november_path(entry).read_bytes()
        audit_november_export(data, entry)
        content[entry["name"]] = data
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for name, data in content.items():
        destination = DESTINATION / name
        staging = destination.with_suffix(destination.suffix + ".staging")
        try:
            staging.write_bytes(data)
            os.replace(staging, destination)
        finally:
            staging.unlink(missing_ok=True)
    print("Private owner bundle prepared with", len(content),
          "original source archives; never distribute this IPA")
    print("After personal tests, run --unstage before releasing.")


if __name__ == "__main__":
    main()
