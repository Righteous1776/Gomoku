#!/usr/bin/env python3
"""Explicitly stage a personal-only owner IPA resource; never by default."""
from __future__ import annotations
import argparse
import os
from pathlib import Path

from verify_owner_training_evidence import ARCHIVE, ROOT, audit_bytes

DEST = ROOT / ("Apps/iOS/Gomoku/Resources/OwnerPrivate/"
               "VeilLink-Gomoku-OwnerTraining-20261031.vltrain.json")


def main() -> None:
    parser = argparse.ArgumentParser()
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument("--owner-build", action="store_true")
    choice.add_argument("--unstage", action="store_true")
    parser.add_argument("--acknowledge-private-bundle", action="store_true")
    args = parser.parse_args()
    if args.unstage:
        DEST.unlink(missing_ok=True)
        print("Private packaged owner history removed")
        return
    if not args.acknowledge_private_bundle:
        parser.error("Private IPA will contain readable personal games; "
                     "require --acknowledge-private-bundle")
    data = ARCHIVE.read_bytes()
    report = audit_bytes(data)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    temporary = DEST.with_name(DEST.name + ".staging")
    try:
        temporary.write_bytes(data)
        os.replace(temporary, DEST)
    finally:
        temporary.unlink(missing_ok=True)
    print("Owner-only, not for distribution:", DEST.relative_to(ROOT))
    print("Checked", report["legitimateComplete"], "complete games and",
          report["legalIncomplete"], "incomplete saved records")
    print("Use --unstage before preparing any shareable IPA")


if __name__ == "__main__":
    main()
