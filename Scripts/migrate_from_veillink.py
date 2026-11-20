#!/usr/bin/env python3
"""Reproducible exact-byte staging from PINNED upstream VeilLink checkout.
Default: safe dry-run. Requires --execute to write. Never touches original repo.
Staged files are not automatically linked to iOS app. Review and port dependencies.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'Migration/source_inventory.json'
OUT = ROOT / 'Provenance/migrated_sources.sha256.json'


def git(source: Path, *args):
    return subprocess.check_output(['git', '-C', str(source), *args], text=True, stderr=subprocess.STDOUT).strip()


def sha256(p):
    h = hashlib.sha256()
    with p.open('rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()


def all_files(path):
    if path.is_file():
        return [path]
    if path.is_dir():
        return sorted(p for p in path.rglob('*') if p.is_file())
    return []


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True, help='local VeilLink repo checked out at pinned source commit')
    p.add_argument('--execute', action='store_true', help='perform exact-byte staging; default dry-run')
    args = p.parse_args()
    source = args.source.resolve()
    if not source.is_dir():
        raise SystemExit('ERROR: source directory missing')
    config = json.loads(CONFIG.read_text(encoding='utf-8'))
    head = git(source, 'rev-parse', 'HEAD')
    if head != config['upstream_commit']:
        raise SystemExit(f"ERROR: pinned SHA mismatch: got {head}; expected {config['upstream_commit']}")
    if git(source, 'status', '--porcelain', '--untracked-files=no'):
        raise SystemExit('ERROR: source tracked files are dirty. Use a fresh checkout.')
    dest_prefix = ROOT / config['destination_prefix']
    files = []
    missing_optional = []
    source_root = source.resolve()
    for item in config['entries']:
        rel = Path(item['path'])
        if rel.is_absolute() or '..' in rel.parts:
            raise SystemExit(f'ERROR: unsafe manifest path {rel}')
        origin = source / rel
        if not origin.exists():
            if item['critical']:
                raise SystemExit(f'ERROR: critical upstream file absent: {rel}')
            missing_optional.append(str(rel))
            continue
        for file in all_files(origin):
            if file.is_symlink() or not file.resolve().is_relative_to(source_root):
                raise SystemExit(f'ERROR: symlink or path escape: {file}')
            target = dest_prefix / file.relative_to(source)
            files.append((file, target, item['category']))
    print(f"PINNED HEAD: {head}\nfiles to stage: {len(files)}\noptional entries missing: {len(missing_optional)}")
    if not args.execute:
        for origin, target, _ in files[:25]:
            print('COPY', origin.relative_to(source), '->', target.relative_to(ROOT))
        print('DRY RUN ONLY. Re-run with --execute after review.')
        return 0
    hashes = []
    for origin, target, category in files:
        data_hash = sha256(origin)
        if target.exists():
            if sha256(target) != data_hash:
                raise SystemExit(f'ERROR: staged file differs, refusing overwrite: {target}')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(origin, target)
        hashes.append({'source': str(origin.relative_to(source)), 'destination': str(target.relative_to(ROOT)), 'sha256': data_hash, 'category': category})
    evidence = {'schema': 'gomoku.source-stage-proof.v1', 'upstream': config['upstream'], 'pinned_commit': head, 'files': hashes, 'missing_optional': missing_optional, 'stage_only': True}
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(evidence,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(f"STAGED {len(hashes)} files; proof: {OUT}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
