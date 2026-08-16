#!/usr/bin/env python3
"""Generate the full iOS image asset set for Checkera from SVG sources.

The brand assets are not part of this repository. Point CHECKERA_ASSETS at a
checkout of the private asset library, or place it alongside this repo as
../Checkera/bucket (the default).

Inputs (in $CHECKERA_ASSETS/SVG/):
- app_launch_ios.svg — green ground + light glyph (App Icon source)
- icon_white.svg — glyph alone, white on transparent
- logo.svg — horizontal wordmark (uses #3bae00)

Outputs:
- Assets.xcassets/AppIcon.appiconset/Icon-1024-{Light,Dark,Tinted}.png + Contents.json
- Assets.xcassets/LaunchLogo.imageset/logo_white{,@2x,@3x}.png + Contents.json
- Assets.xcassets/LaunchBackground.colorset/Contents.json (color updated to #49D700)
- $CHECKERA_ASSETS/AppStore/iphone-*.png, ipad-*.png + README.md

Requirements:
- rsvg-convert (brew install librsvg)
- Python 3 + Pillow
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


# --- Constants -------------------------------------------------------------

GREEN_BRIGHT_RGB = (0x49, 0xD7, 0x00)   # canonical brand green
GREEN_DARK_RGB = (0x3B, 0xAE, 0x00)     # darker green (gradient bottom)
DARK_BG_RGB = (0x0A, 0x0F, 0x0A)        # near-black ground for Dark variant
TAGLINE = "Daily checks, kept simple."
HELVETICA = "/System/Library/Fonts/Helvetica.ttc"

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
# Brand assets live outside this repo; see the module docstring.
BRAND_ASSETS = Path(
    os.environ.get("CHECKERA_ASSETS", REPO_ROOT.parent / "Checkera" / "bucket")
).expanduser()
SVG_DIR = BRAND_ASSETS / "SVG"
ASSETS = REPO_ROOT / "Checkera" / "Resources" / "Assets.xcassets"
APP_ICON_DIR = ASSETS / "AppIcon.appiconset"
LAUNCH_LOGO_DIR = ASSETS / "LaunchLogo.imageset"
LAUNCH_BG_DIR = ASSETS / "LaunchBackground.colorset"
APPSTORE_DIR = BRAND_ASSETS / "AppStore"
BUILD_DIR = SCRIPT_DIR / "build"


def require_brand_assets() -> None:
    """Fail early and legibly when the private asset library isn't reachable."""
    if SVG_DIR.is_dir():
        return
    sys.exit(
        f"Brand assets not found at {BRAND_ASSETS}\n"
        "These SVG sources are kept in a separate private repository.\n"
        "Set CHECKERA_ASSETS to its bucket/ directory, e.g.\n"
        "  CHECKERA_ASSETS=../Checkera/bucket Scripts/generate-ios-assets.sh"
    )

APP_STORE_SIZES = [
    ("iphone-6.9.png", 1320, 2868),
    ("iphone-6.7.png", 1290, 2796),
    ("iphone-6.5.png", 1242, 2688),
    ("iphone-5.5.png", 1242, 2208),
    ("ipad-12.9.png",  2048, 2732),
    ("ipad-13.png",    2064, 2752),
]


# --- Helpers ---------------------------------------------------------------

def run_rsvg(svg: Path, out: Path, *, width: int | None = None, height: int | None = None) -> None:
    cmd = ["rsvg-convert"]
    if width is not None:
        cmd += ["-w", str(width)]
    if height is not None:
        cmd += ["-h", str(height)]
    cmd += [str(svg), "-o", str(out)]
    subprocess.run(cmd, check=True, capture_output=True)


def render_with_replacements(svg: Path, replacements: dict[str, str], out: Path,
                             *, width: int | None = None, height: int | None = None) -> None:
    text = svg.read_text()
    for old, new in replacements.items():
        text = text.replace(old, new)
    tmp = BUILD_DIR / f"{svg.stem}_{out.stem}.svg"
    tmp.write_text(text)
    try:
        run_rsvg(tmp, out, width=width, height=height)
    finally:
        tmp.unlink(missing_ok=True)


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def rel(p: Path) -> str:
    """Shortest readable form of a path, which may sit outside this repo now
    that the brand assets are external."""
    for root in (REPO_ROOT, BRAND_ASSETS):
        try:
            return str(p.relative_to(root))
        except ValueError:
            continue
    return str(p)


# --- App Icon variants -----------------------------------------------------

def build_app_icon_light() -> None:
    """Green ground + light glyph at 1024×1024, no rounded corners, no alpha."""
    out = APP_ICON_DIR / "Icon-1024-Light.png"
    tmp = BUILD_DIR / "icon_light.png"
    run_rsvg(SVG_DIR / "app_launch_ios.svg", tmp, width=1024, height=1024)
    rendered = Image.open(tmp).convert("RGBA")
    # Composite onto opaque green to flatten rounded corners and strip alpha.
    canvas = Image.new("RGB", (1024, 1024), GREEN_BRIGHT_RGB)
    canvas.paste(rendered, (0, 0), rendered)
    canvas.save(out, "PNG", optimize=True)
    tmp.unlink()
    print(f"  ✓ {rel(out)}")


def build_app_icon_dark() -> None:
    """Dark ground + green glyph at 1024×1024, no rounded corners, no alpha."""
    out = APP_ICON_DIR / "Icon-1024-Dark.png"
    tmp = BUILD_DIR / "icon_dark.png"
    render_with_replacements(
        SVG_DIR / "app_launch_ios.svg",
        {
            "#49d700": "#0a0f0a",  # ground -> dark
            "#f2f2f2": "#49d700",  # glyph -> green
        },
        tmp, width=1024, height=1024,
    )
    rendered = Image.open(tmp).convert("RGBA")
    canvas = Image.new("RGB", (1024, 1024), DARK_BG_RGB)
    canvas.paste(rendered, (0, 0), rendered)
    canvas.save(out, "PNG", optimize=True)
    tmp.unlink()
    print(f"  ✓ {rel(out)}")


def build_app_icon_tinted() -> None:
    """White glyph on transparent background; iOS applies user tint."""
    out = APP_ICON_DIR / "Icon-1024-Tinted.png"
    glyph_tmp = BUILD_DIR / "tinted_glyph.png"
    # Render glyph at ~73% width to match its visual size in the Light variant.
    run_rsvg(SVG_DIR / "icon_white.svg", glyph_tmp, width=750)
    glyph = Image.open(glyph_tmp).convert("RGBA")
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    px = (1024 - glyph.width) // 2
    py = (1024 - glyph.height) // 2
    canvas.paste(glyph, (px, py), glyph)
    canvas.save(out, "PNG", optimize=True)
    glyph_tmp.unlink()
    print(f"  ✓ {rel(out)}")


def write_app_icon_contents() -> None:
    contents = {
        "images": [
            {
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
                "filename": "Icon-1024-Light.png",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
                "filename": "Icon-1024-Dark.png",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "tinted"}],
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
                "filename": "Icon-1024-Tinted.png",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    out = APP_ICON_DIR / "Contents.json"
    write_json(out, contents)
    print(f"  ✓ {rel(out)}")


def cleanup_legacy_app_icon_pngs() -> None:
    keep = {
        "Icon-1024-Light.png", "Icon-1024-Dark.png", "Icon-1024-Tinted.png",
        "Contents.json",
    }
    for f in sorted(APP_ICON_DIR.iterdir()):
        if f.name not in keep:
            f.unlink()
            print(f"  ✗ {rel(f)}")


# --- Launch Logo -----------------------------------------------------------

def build_launch_logo() -> None:
    sizes = [("logo_white.png", 200), ("logo_white@2x.png", 400), ("logo_white@3x.png", 600)]
    for fname, w in sizes:
        out = LAUNCH_LOGO_DIR / fname
        run_rsvg(SVG_DIR / "icon_white.svg", out, width=w)
        print(f"  ✓ {rel(out)}")
    contents = {
        "images": [
            {"idiom": "universal", "scale": "1x", "filename": "logo_white.png"},
            {"idiom": "universal", "scale": "2x", "filename": "logo_white@2x.png"},
            {"idiom": "universal", "scale": "3x", "filename": "logo_white@3x.png"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    out = LAUNCH_LOGO_DIR / "Contents.json"
    write_json(out, contents)
    print(f"  ✓ {rel(out)}")


# --- Launch Background color ----------------------------------------------

def update_launch_background_color() -> None:
    contents = {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue":  "0x00",
                        "green": "0xD7",
                        "red":   "0x49",
                    },
                },
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    out = LAUNCH_BG_DIR / "Contents.json"
    write_json(out, contents)
    print(f"  ✓ {rel(out)}")


# --- App Store mockups -----------------------------------------------------

def make_vertical_gradient(width: int, height: int, top, bottom) -> Image.Image:
    strip = Image.new("RGB", (1, height))
    px = strip.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        px[0, y] = (
            int(top[0] + (bottom[0] - top[0]) * t),
            int(top[1] + (bottom[1] - top[1]) * t),
            int(top[2] + (bottom[2] - top[2]) * t),
        )
    return strip.resize((width, height))


def build_app_store_mockups() -> None:
    APPSTORE_DIR.mkdir(parents=True, exist_ok=True)
    icon_master = BUILD_DIR / "mockup_icon_master.png"
    wm_master = BUILD_DIR / "mockup_wordmark_white.png"

    # Render the icon (full green tile) for the mockups.
    run_rsvg(SVG_DIR / "app_launch_ios.svg", icon_master, width=1024, height=1024)
    icon_img = Image.open(icon_master).convert("RGBA")

    # Render the wordmark with white fill (override the SVG's #3bae00).
    render_with_replacements(
        SVG_DIR / "logo.svg",
        {"#3bae00": "#ffffff", "#3BAE00": "#ffffff"},
        wm_master, width=2000,
    )
    wm_img = Image.open(wm_master).convert("RGBA")

    for fname, w, h in APP_STORE_SIZES:
        out = APPSTORE_DIR / fname
        canvas = make_vertical_gradient(w, h, GREEN_BRIGHT_RGB, GREEN_DARK_RGB).convert("RGBA")

        # Icon, ~33% of width, anchored ~22% from top.
        icon_w = int(w * 0.33)
        icon = icon_img.resize((icon_w, icon_w), Image.LANCZOS)

        # Soft drop shadow under the icon.
        shadow = Image.new("RGBA", (icon_w, icon_w), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rounded_rectangle(
            (0, 0, icon_w - 1, icon_w - 1),
            radius=int(icon_w * 0.22),
            fill=(0, 0, 0, 90),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(int(icon_w * 0.05)))

        sx = (w - icon_w) // 2
        sy = int(h * 0.22)
        canvas.alpha_composite(shadow, (sx + int(icon_w * 0.02), sy + int(icon_w * 0.05)))
        canvas.alpha_composite(icon, (sx, sy))

        # Wordmark, ~50% of width, below the icon.
        wm_w = int(w * 0.50)
        wm_h = int(wm_w / wm_img.width * wm_img.height)
        wm = wm_img.resize((wm_w, wm_h), Image.LANCZOS)
        wx = (w - wm_w) // 2
        wy = sy + icon_w + int(h * 0.05)
        canvas.alpha_composite(wm, (wx, wy))

        # Tagline below wordmark.
        font_size = max(int(h * 0.026), 16)
        font = ImageFont.truetype(HELVETICA, font_size)
        draw = ImageDraw.Draw(canvas)
        bbox = draw.textbbox((0, 0), TAGLINE, font=font)
        tw = bbox[2] - bbox[0]
        tx = (w - tw) // 2
        ty = wy + wm_h + int(h * 0.025)
        draw.text((tx, ty), TAGLINE, fill=(255, 255, 255, 255), font=font)

        canvas.convert("RGB").save(out, "PNG", optimize=True)
        print(f"  ✓ {rel(out)} ({w}×{h})")

    icon_master.unlink()
    wm_master.unlink()


def write_appstore_readme() -> None:
    out = APPSTORE_DIR / "README.md"
    out.write_text(
        "# App Store Screenshots — Placeholders\n"
        "\n"
        "These PNGs are synthetic mockups generated by `Scripts/generate-ios-assets.sh` in the\n"
        "[Checkera iOS repo](https://github.com/arcarruda/Checkera), which reads this directory\n"
        "via the `CHECKERA_ASSETS` environment variable.\n"
        "They show the app icon, wordmark, and tagline on a green gradient — useful for App Store\n"
        "Connect previewing, marketing pages, and internal mockups, but **not** acceptable as the\n"
        "final App Store submission. Apple expects screenshots showing the actual app UI.\n"
        "\n"
        "Replace these before submission via either:\n"
        "\n"
        "1. Manual capture with `xcrun simctl io booted screenshot iphone-6.7.png` per simulator.\n"
        "2. Automated `fastlane snapshot` driving a UITest target across every device class.\n"
        "\n"
        "## Sizes\n"
        "\n"
        "| File | Display | Pixels |\n"
        "|---|---|---|\n"
        "| `iphone-6.9.png` | 6.9\" iPhone (16 Pro Max) | 1320×2868 |\n"
        "| `iphone-6.7.png` | 6.7\" iPhone (15 Pro Max) | 1290×2796 |\n"
        "| `iphone-6.5.png` | 6.5\" iPhone (XS Max)     | 1242×2688 |\n"
        "| `iphone-5.5.png` | 5.5\" iPhone (8 Plus)     | 1242×2208 |\n"
        "| `ipad-12.9.png`  | 12.9\" iPad Pro           | 2048×2732 |\n"
        "| `ipad-13.png`    | 13\" iPad Pro (M4)        | 2064×2752 |\n"
    )
    print(f"  ✓ {rel(out)}")


# --- Main ------------------------------------------------------------------

def main() -> int:
    require_brand_assets()
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    try:
        print("→ App Icon variants")
        build_app_icon_light()
        build_app_icon_dark()
        build_app_icon_tinted()
        write_app_icon_contents()
        cleanup_legacy_app_icon_pngs()

        print("→ Launch Logo")
        build_launch_logo()

        print("→ Launch Background color")
        update_launch_background_color()

        print("→ App Store mockups")
        build_app_store_mockups()
        write_appstore_readme()
    finally:
        shutil.rmtree(BUILD_DIR, ignore_errors=True)

    print("\n✓ Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
