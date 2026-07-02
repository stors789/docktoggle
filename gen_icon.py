#!/usr/bin/env python3
"""Generate TapHide app icons from the approved source artwork."""

from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parent
RESOURCES = PROJECT / "Resources"
SOURCE = RESOURCES / "TapHideSource.png"
ICONSET = RESOURCES / "TapHide.iconset"
ICNS = RESOURCES / "TapHide.icns"
README_PREVIEW = PROJECT / "icon.png"

SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

ICNS_SIZES = [
    (16, 16),
    (32, 32),
    (64, 64),
    (128, 128),
    (256, 256),
    (512, 512),
    (1024, 1024),
]


def load_source() -> Image.Image:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source artwork: {SOURCE}")

    img = Image.open(SOURCE).convert("RGBA")
    width, height = img.size
    side = min(width, height)
    left = (width - side) // 2
    top = (height - side) // 2
    return img.crop((left, top, left + side, top + side)).resize(
        (1024, 1024),
        Image.Resampling.LANCZOS,
    )


def main() -> None:
    source = load_source()
    ICONSET.mkdir(parents=True, exist_ok=True)

    README_PREVIEW.write_bytes(
        image_bytes(source.resize((256, 256), Image.Resampling.LANCZOS))
    )

    for name, size in SIZES.items():
        path = ICONSET / name
        path.write_bytes(
            image_bytes(source.resize((size, size), Image.Resampling.LANCZOS))
        )
        print(f"  {name} ({size}x{size})")

    source.save(ICNS, format="ICNS", sizes=ICNS_SIZES)
    print(f"\nPreview written to {README_PREVIEW}")
    print(f"Iconset written to {ICONSET}")
    print(f"ICNS written to {ICNS}")


def image_bytes(image: Image.Image) -> bytes:
    from io import BytesIO

    buf = BytesIO()
    image.save(buf, format="PNG")
    return buf.getvalue()


if __name__ == "__main__":
    main()
