#!/usr/bin/env python3
"""Composite App Store marketing screenshots from raw simulator captures.

Reads raw screenshots from bucket/AppStore/raw/{iphone,ipad}/0{1,2,3}-*.png
and emits finals at exact Apple-required dimensions:

- bucket/AppStore/iphone-6.5/0{1,2,3}-*.png  at 1242 x 2688
- bucket/AppStore/ipad-13/0{1,2,3}-*.png     at 2064 x 2752

Each final image: brand green gradient background, headline at top in white,
device screenshot below with rounded corners and a soft drop shadow.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

GREEN_BRIGHT = (0x49, 0xD7, 0x00)
GREEN_DARK = (0x3B, 0xAE, 0x00)
WHITE = (255, 255, 255)

SF_BOLD = "/System/Library/Fonts/SFNS.ttf"
SF_DISPLAY = "/System/Library/Fonts/SFNSRounded.ttf"

SCRIPT_DIR = Path(__file__).resolve().parent
MOBILE_APP = SCRIPT_DIR.parent
REPO_ROOT = MOBILE_APP.parent
RAW_DIR = REPO_ROOT / "bucket" / "AppStore" / "raw"
OUT_IPHONE = REPO_ROOT / "bucket" / "AppStore" / "iphone-6.5"
OUT_IPAD = REPO_ROOT / "bucket" / "AppStore" / "ipad-13"

HEADLINES = [
    ("01-home.png", "Plan your day,\nhour by hour."),
    ("02-editor.png", "Add tasks\nin seconds."),
    ("03-settings.png", "Notifications that\nrespect your sleep."),
]


def make_background(width: int, height: int) -> Image.Image:
    bg = Image.new("RGB", (width, height), GREEN_BRIGHT)
    px = bg.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        r = int(GREEN_BRIGHT[0] + (GREEN_DARK[0] - GREEN_BRIGHT[0]) * t)
        g = int(GREEN_BRIGHT[1] + (GREEN_DARK[1] - GREEN_BRIGHT[1]) * t)
        b = int(GREEN_BRIGHT[2] + (GREEN_DARK[2] - GREEN_BRIGHT[2]) * t)
        for x in range(width):
            px[x, y] = (r, g, b)
    return bg


def draw_headline(canvas: Image.Image, text: str, top_pad: int, font_size: int, line_spacing: float = 1.05) -> int:
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(SF_BOLD, font_size)
    lines = text.split("\n")
    line_h = int(font_size * line_spacing)
    width = canvas.width
    y = top_pad
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        text_w = bbox[2] - bbox[0]
        x = (width - text_w) // 2
        draw.text((x, y), line, font=font, fill=WHITE)
        y += line_h
    return y


def round_corners(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0], img.size[1]), radius=radius, fill=255)
    rounded = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rounded.paste(img.convert("RGBA"), (0, 0), mask)
    return rounded


def paste_screenshot_with_shadow(
    canvas: Image.Image,
    screenshot_path: Path,
    top: int,
    bottom_pad: int,
    side_pad: int,
    corner_radius: int,
) -> None:
    canvas_w, canvas_h = canvas.size
    available_h = canvas_h - top - bottom_pad
    available_w = canvas_w - 2 * side_pad

    raw = Image.open(screenshot_path).convert("RGB")
    sw, sh = raw.size
    scale = min(available_w / sw, available_h / sh)
    new_w = int(sw * scale)
    new_h = int(sh * scale)
    scaled = raw.resize((new_w, new_h), Image.LANCZOS)
    rounded = round_corners(scaled, corner_radius)

    x = (canvas_w - new_w) // 2
    y = top

    shadow = Image.new("RGBA", (new_w + 200, new_h + 200), (0, 0, 0, 0))
    shadow_mask = rounded.split()[-1].point(lambda a: int(a * 0.45))
    shadow_layer = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
    shadow_layer.paste((0, 0, 0, 255), (100, 100), shadow_mask)
    shadow_blur = shadow_layer.filter(ImageFilter.GaussianBlur(radius=40))
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba.alpha_composite(shadow_blur, (x - 100, y - 100 + 20))
    canvas_rgba.alpha_composite(rounded, (x, y))
    canvas.paste(canvas_rgba.convert("RGB"))


def composite(
    raw_path: Path,
    out_path: Path,
    canvas_size: tuple[int, int],
    headline: str,
    font_size: int,
    top_pad: int,
    screenshot_top: int,
    bottom_pad: int,
    side_pad: int,
    corner_radius: int,
) -> None:
    canvas = make_background(*canvas_size)
    draw_headline(canvas, headline, top_pad=top_pad, font_size=font_size)
    paste_screenshot_with_shadow(
        canvas,
        raw_path,
        top=screenshot_top,
        bottom_pad=bottom_pad,
        side_pad=side_pad,
        corner_radius=corner_radius,
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path.relative_to(REPO_ROOT)}  ({canvas_size[0]}x{canvas_size[1]})")


def main() -> None:
    for filename, headline in HEADLINES:
        composite(
            raw_path=RAW_DIR / "iphone" / filename,
            out_path=OUT_IPHONE / filename,
            canvas_size=(1242, 2688),
            headline=headline,
            font_size=104,
            top_pad=160,
            screenshot_top=500,
            bottom_pad=120,
            side_pad=110,
            corner_radius=56,
        )

    for filename, headline in HEADLINES:
        composite(
            raw_path=RAW_DIR / "ipad" / filename,
            out_path=OUT_IPAD / filename,
            canvas_size=(2064, 2752),
            headline=headline,
            font_size=128,
            top_pad=170,
            screenshot_top=540,
            bottom_pad=160,
            side_pad=200,
            corner_radius=48,
        )


if __name__ == "__main__":
    main()
