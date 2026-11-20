#!/usr/bin/env python3
"""Desktop staging archive helper for **explicitly user-selected** Gomoku files.
Not automatic iOS sandbox access. Not a replacement for validated Swift import UI.
ZIP verification is streaming and rejects symlinks/traversal/unlisted contents.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import zipfile

SCHEMA = 'gomoku.archive.container.v1'
SINGLE = {'adaptive-board-learning-gomoku-v2.json', 'gomoku-native-selfplay-v1.json', 'formations.json', 'local-match.json'}
HISTORY = 'GomokuMatchHistoryV1'
DEFAULT_MAX_BYTES = 8 * 1024 * 1024 * 1024  # adjustable integrity/resource safety, NOT game-count cap


def allowed(name):
    path = PurePosixPath(name)
    if (not isinstance(name, str) or not name or len(name) > 255 or path.is_absolute()
            or '..' in path.parts or '\\' in name or ':' in name or '\x00' in name
            or any(ord(char) < 32 for char in name) or path.as_posix() != name):
        return False
    if len(path.parts) == 1:
        return name in SINGLE
    return len(path.parts) == 2 and path.parts[0] == HISTORY and path.parts[1].endswith('.json') and not path.parts[1].startswith('.')


def digest_chunks(stream):
    h = hashlib.sha256()
    size = 0
    for part in iter(lambda: stream.read(1 << 20), b''):
        size += len(part)
        h.update(part)
    return size, h.hexdigest()


def make_package(src: Path, dest: Path):
    src = src.resolve()
    if not src.is_dir():
        raise ValueError('input must be an explicitly selected directory')
    if dest.resolve().is_relative_to(src):
        raise ValueError('output cannot be inside input tree')
    files = []
    for f in sorted(src.rglob('*')):
        if f.is_symlink():
            raise ValueError('symlink rejected: ' + str(f))
        if f.is_file():
            rel = f.relative_to(src).as_posix()
            if not allowed(rel):
                raise ValueError('unrecognized user data file; refusing possible leak: ' + rel)
            files.append((f, rel))
    if not files:
        raise ValueError('no permitted Gomoku files selected')
    if dest.exists():
        raise ValueError('backup destination already exists; refusing overwrite')
    if dest.exists() or dest.is_symlink():
        raise FileExistsError('refusing to overwrite existing archive: ' + str(dest))
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.gomoku-export-', suffix='.zip', dir=dest.parent)
    os.close(fd)
    manifest = {'schema': SCHEMA, 'source': 'user-selected-gomoku-files', 'rules': 'freestyle-15', 'entries': []}
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
            for f, rel in files:
                with f.open('rb') as inp:
                    size, sha = digest_chunks(inp)
                manifest['entries'].append({'name': rel, 'size': size, 'sha256': sha})
                z.write(f, arcname='payload/' + rel)
            z.writestr('manifest.json', json.dumps(manifest, indent=2, ensure_ascii=False)+'\n')
        verify_package(Path(temporary))
        # Hard-link into the same directory atomically WITHOUT replacing an existing export.
        os.link(temporary, dest)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)
    return manifest


def verify_package(archive: Path, max_bytes: int = DEFAULT_MAX_BYTES):
    if max_bytes <= 0:
        raise ValueError('invalid safety limit')
    with zipfile.ZipFile(archive, 'r') as z:
        entries = z.infolist()
        names = [i.filename for i in entries]
        if len(set(names)) != len(names):
            raise ValueError('duplicate zip paths')
        if 'manifest.json' not in names:
            raise ValueError('missing manifest')
        if z.getinfo('manifest.json').file_size > 1 << 24:
            raise ValueError('excessive manifest')
        manifest = json.loads(z.read('manifest.json'))
        if manifest.get('schema') != SCHEMA or manifest.get('rules') != 'freestyle-15':
            raise ValueError('wrong schema / rules')
        expected = manifest.get('entries')
        if not isinstance(expected, list) or not expected:
            raise ValueError('no entries')
        for row in expected:
            if not isinstance(row, dict) or not isinstance(row.get('name'), str) or not isinstance(row.get('sha256'), str) \
                    or not re.fullmatch(r'[0-9a-f]{64}', row['sha256']) or type(row.get('size')) is not int or row['size'] < 0:
                raise ValueError('invalid manifest entry')
        if len(set(row['name'] for row in expected)) != len(expected):
            raise ValueError('duplicate manifest entries')
        expected_paths = {'payload/' + x['name'] for x in expected}
        if set(names) != expected_paths | {'manifest.json'}:
            raise ValueError('zip inventory mismatch')
        total = 0
        for row in expected:
            rel = row['name']
            if not allowed(rel):
                raise ValueError('forbidden archive path: ' + rel)
            zi = z.getinfo('payload/' + rel)
            file_type = stat.S_IFMT(zi.external_attr >> 16)
            if file_type not in (0, stat.S_IFREG):
                raise ValueError('non-regular archive entry rejected')
            if zi.is_dir() or zi.file_size != row.get('size') or zi.file_size < 0:
                raise ValueError('size mismatch or directory')
            if zi.compress_size == 0 and zi.file_size > 0:
                raise ValueError('bad compressed size')
            if zi.compress_size > 0 and zi.file_size > zi.compress_size * 2000:
                raise ValueError('excessive decompression ratio')
            total += zi.file_size
            if total > max_bytes:
                raise ValueError('data exceeds explicit configurable safety maximum')
            with z.open(zi, 'r') as stream:
                size, sha = digest_chunks(stream)
            if size != zi.file_size or sha != row.get('sha256'):
                raise ValueError('streaming integrity check failed: ' + rel)
        return {'entries': len(expected), 'bytes': total, 'verified': True, 'manifest': manifest}


def extract_package(archive: Path, outdir: Path, max_bytes: int = DEFAULT_MAX_BYTES):
    """Extract to an adjacent staging directory, then publish atomically.
    Never remove or overwrite a user-selected destination after an error.
    """
    report = verify_package(archive, max_bytes)
    if outdir.is_symlink() or (outdir.exists() and (not outdir.is_dir() or any(outdir.iterdir()))):
        raise ValueError('destination must be new or empty and not a symlink')
    outdir.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.gomoku-extract-', dir=outdir.parent))
    try:
        with zipfile.ZipFile(archive, 'r') as z:
            for row in report['manifest']['entries']:
                destination = temporary / row['name']
                destination.parent.mkdir(parents=True, exist_ok=True)
                with z.open('payload/' + row['name'], 'r') as src, destination.open('xb') as dst:
                    shutil.copyfileobj(src, dst, 1 << 20)
        # Recheck before publication to avoid silently replacing files.
        if outdir.is_symlink() or (outdir.exists() and (not outdir.is_dir() or any(outdir.iterdir()))):
            raise ValueError('destination changed during extraction; refusing overwrite')
        os.replace(temporary, outdir)
        return report
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    action = p.add_mutually_exclusive_group(required=True)
    action.add_argument('--create', type=Path, help='explicitly selected input directory')
    action.add_argument('--verify', action='store_true')
    action.add_argument('--extract', type=Path, help='new/empty output directory')
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--max-bytes', type=int, default=DEFAULT_MAX_BYTES, help='configurable resource safety bound')
    a = p.parse_args()
    if a.create:
        print(json.dumps(make_package(a.create, a.archive), indent=2))
    elif a.verify:
        print(json.dumps(verify_package(a.archive, a.max_bytes), indent=2))
    else:
        print(json.dumps(extract_package(a.archive, a.extract, a.max_bytes), indent=2))


if __name__ == '__main__': main()
