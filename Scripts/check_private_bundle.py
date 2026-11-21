#!/usr/bin/env python3
"""Fail-closed privacy gate for shareable Gomoku iOS builds.

Private original VeilLink owner histories are held for authorised import only.
No public/dev CI build or uploaded artifact may contain those records. This
script never reads or rewrites the owner evidence source repository directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile

OWNER_RESOURCE = Path("Apps/iOS/Gomoku/Resources/OwnerPrivate")
PINNED_PRIVATE_SHA256 = frozenset({
    "d5cf13940bbb84dc937783700aa129303c4ec1d54a781992099675c3e6325d8b",
    "050f5abbac2c3f7991db5dbcad4b4d1bd33f49eb1aeeacb5025b17d0696ce325",
})
# Older original has an authenticated git blob and SHA verification in the
# source audit; checking the original JSON envelope also catches this file.
MAX_JSON_INSPECTION = 64 * 1024 * 1024


class PrivateBundleError(RuntimeError):
    pass


def source_preflight(root: Path) -> None:
    private = root / OWNER_RESOURCE
    if private.is_symlink():
        raise PrivateBundleError(f"private resource symlink forbidden: {private}")
    if private.exists():
        if not private.is_dir():
            raise PrivateBundleError(f"unexpected private resource path: {private}")
        if any(private.iterdir()):
            raise PrivateBundleError(
                f"owner-only resources staged at {private}; "
                "unstage them before any shared/CI build"
            )


def _is_owner_envelope(data: bytes) -> bool:
    if not data.lstrip().startswith(b"{"):
        return False
    try:
        obj = json.loads(data)
    except (UnicodeError, ValueError):
        return False
    return (isinstance(obj, dict)
            and obj.get("format") == "veillink.board-learning.export.v1"
            and isinstance(obj.get("payload"), dict)
            and "recentGames" in obj["payload"])


def _inspect_stream(name: str, stream, size: int) -> tuple[str, bytes]:
    parts = PurePosixPath(name.replace("\\", "/")).parts
    if "OwnerPrivate" in parts or name.lower().endswith(".vltrain.json"):
        return "owner archive path", b""
    digest = hashlib.sha256()
    payload = bytearray() if size <= MAX_JSON_INSPECTION else None
    while True:
        chunk = stream.read(1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)
        if payload is not None:
            payload.extend(chunk)
    if digest.hexdigest() in PINNED_PRIVATE_SHA256:
        return "private source SHA256", digest.digest()
    if payload is not None and _is_owner_envelope(payload):
        return "private VeilLink training envelope", digest.digest()
    return "", digest.digest()


def inspect_artifact(path: Path) -> str:
    """Validate actual .app / IPA bytes, returning deterministic content digest."""
    if not path.exists():
        raise PrivateBundleError(f"build artifact missing: {path}")
    aggregate = hashlib.sha256()
    if path.is_dir() and path.suffix == ".app":
        for file in sorted(path.rglob("*")):
            if file.is_symlink():
                raise PrivateBundleError(f"unexpected app resource symlink: {file}")
            if not file.is_file():
                continue
            name = file.relative_to(path).as_posix()
            aggregate.update(name.encode())
            with file.open("rb") as handle:
                reason, file_digest = _inspect_stream(name, handle, file.stat().st_size)
            if reason:
                raise PrivateBundleError(f"private training data in {path}: {name} ({reason})")
            aggregate.update(file_digest)
    elif path.is_file() and path.suffix.lower() == ".ipa":
        if not zipfile.is_zipfile(path):
            raise PrivateBundleError(f"invalid IPA archive: {path}")
        with zipfile.ZipFile(path) as archive:
            for entry in sorted(archive.infolist(), key=lambda e: e.filename):
                if entry.is_dir():
                    continue
                aggregate.update(entry.filename.encode())
                with archive.open(entry) as handle:
                    reason, file_digest = _inspect_stream(entry.filename, handle, entry.file_size)
                if reason:
                    raise PrivateBundleError(
                        f"private training data in {path}: {entry.filename} ({reason})"
                    )
                aggregate.update(file_digest)
    else:
        raise PrivateBundleError(f"expected .app directory or .ipa file: {path}")
    return aggregate.hexdigest()


def verify(root: Path, artifacts: list[Path]) -> dict:
    source_preflight(root)
    found = []
    for artifact in artifacts:
        found.append({"path": str(artifact), "content_sha256": inspect_artifact(artifact)})
    return {"privacy_profile": "public-dev", "result": "pass", "artifacts": found}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--app", type=Path, action="append", default=[])
    parser.add_argument("--ipa", type=Path, action="append", default=[])
    parser.add_argument("--manifest", type=Path, help="optional public-build privacy provenance JSON")
    args = parser.parse_args(argv)
    try:
        report = verify(args.root, args.app + args.ipa)
        if args.manifest:
            args.manifest.parent.mkdir(parents=True, exist_ok=True)
            args.manifest.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("PUBLIC_BUILD_PRIVACY_PASS", json.dumps(report, sort_keys=True))
        return 0
    except (PrivateBundleError, OSError, zipfile.BadZipFile) as exc:
        print(f"PUBLIC_BUILD_PRIVACY_BLOCKED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
