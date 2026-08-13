"""Build windows/runner/resources/app_icon.ico from app_icon_source.png.

Sizes: 16, 32, 48, 256 (Windows multi-resolution ICO).
Replace app_icon_source.png with the final marketing badge, then re-run:

    python tool/build_app_icon.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "windows" / "runner" / "resources" / "app_icon_source.png"
OUT = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
SIZES = [(16, 16), (32, 32), (48, 48), (256, 256)]


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source PNG: {SRC}")

    img = Image.open(SRC).convert("RGBA")
    width, height = img.size
    side = min(width, height)
    left = (width - side) // 2
    top = (height - side) // 2
    img = img.crop((left, top, left + side, top + side))

    frames = [img.resize(size, Image.Resampling.LANCZOS) for size in SIZES]
    # Save using the largest frame; append smaller sizes for a proper multi-res ICO.
    frames[-1].save(
        OUT,
        format="ICO",
        sizes=SIZES,
        append_images=frames[:-1],
    )

    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes) with sizes {SIZES}")


if __name__ == "__main__":
    main()
