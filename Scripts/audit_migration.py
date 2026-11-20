#!/usr/bin/env python3
"""Verify exact-byte match for all staged upstream sources after migration."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
manifest=ROOT/'Provenance/migrated_sources.sha256.json'
if not manifest.exists():
    raise SystemExit('NO MIGRATION PROOF: stage the pinned source before auditing.')
items=json.loads(manifest.read_text(encoding='utf-8'))
issues=[]
for row in items['files']:
    p=ROOT/row['destination']
    if not p.is_file():
        issues.append(f"MISSING: {p}")
    elif hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']:
        issues.append(f"CHANGED: {p}")
print('audited',len(items['files']),'files; problems',len(issues))
if issues:
    print('\n'.join(issues))
    raise SystemExit(1)
