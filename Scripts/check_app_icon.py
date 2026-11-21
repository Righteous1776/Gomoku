#!/usr/bin/env python3
"""Verify the compiled primary iOS app icon before packaging."""
import argparse
import plistlib
from pathlib import Path


def check(app: Path) -> None:
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)

    for variant in ("CFBundleIcons", "CFBundleIcons~ipad"):
        primary = info.get(variant, {}).get("CFBundlePrimaryIcon", {})
        if primary.get("CFBundleIconName") != "AppIcon":
            raise ValueError(f"{variant} must reference the compiled AppIcon set")

        files = primary.get("CFBundleIconFiles", [])
        if not files or any(not (app / name).stem.startswith("AppIcon") for name in files):
            raise ValueError(f"{variant} has no AppIcon files declared")
        for name in files:
            stem = Path(name).stem
            images = [*app.glob(f"{stem}@*.png"), *app.glob(f"{stem}~*.png"), app / f"{stem}.png"]
            if not any(image.is_file() and image.stat().st_size for image in images):
                raise ValueError(f"{variant} icon PNG is missing for {stem}")

    print(f"Verified compiled AppIcon for iPhone and iPad in {app.name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    arguments = parser.parse_args()
    try:
        check(arguments.app)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"App icon verification failed: {error}\n")
