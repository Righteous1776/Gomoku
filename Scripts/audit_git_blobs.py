#!/usr/bin/env python3
"""Fail-closed byte integrity audit of staged Gomoku original source.
Use --emit-sha256 after success to generate the preexisting SHA256 audit contract.
Does not require network, does not alter Legacy/Original, never imports into app.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROOF = ROOT / "Provenance/original_source_git_blobs.json"
SHA_OUT = ROOT / "Provenance/migrated_sources.sha256.json"

def audit(emit=False):
    manifest = json.loads(PROOF.read_text(encoding="utf-8"))
    assert manifest["schema"] == "gomoku.original-git-blob-proof.v1"
    assert manifest["critical_inventory_entries"] == 57
    entries = manifest["files"]
    assert len(entries) == manifest["critical_expanded_files"] + manifest["additional_reference_files"]
    results = []
    errors = []
    seen = set()
    root = ROOT.resolve()
    for row in entries:
        relative = Path(row["destination"])
        raw = relative.as_posix()
        if relative.is_absolute() or ".." in relative.parts or not raw.startswith("Legacy/Original/") or raw in seen:
            errors.append(f"UNSAFE PATH: {raw}")
            continue
        seen.add(raw)
        path = ROOT / relative
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
            errors.append(f"UNREADABLE: {raw}")
            continue
        content = path.read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(content)).encode("ascii") + b"\0" + content).hexdigest()
        if blob != row["git_blob_sha"]:
            errors.append(f"MODIFIED: {raw} expected {row['git_blob_sha']} got {blob}")
            continue
        results.append({
            "source": row["source"], "destination": raw,
            "sha256": hashlib.sha256(content).hexdigest(), "category": row["category"]
        })
    print(f"GOMOKU SOURCE BYTE AUDIT: {len(results)}/{len(entries)} matched")
    if errors:
        for item in errors: print("FAIL", item, file=sys.stderr)
        return 1
    if emit:
        payload = {
            "schema": "gomoku.source-stage-proof.v1", "upstream": manifest["upstream"],
            "pinned_commit": manifest["pinned_commit"], "files": results,
            "missing_optional": [], "stage_only": True,
            "note": "Only explicitly selected original source and review reference files included; unrelated optional folders/assets not mass-imported."
        }
        SHA_OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print("EMITTED", SHA_OUT.relative_to(ROOT))
    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--emit-sha256", action="store_true")
    args = parser.parse_args()
    sys.exit(audit(args.emit_sha256))
