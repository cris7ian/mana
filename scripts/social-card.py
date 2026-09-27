#!/usr/bin/env python3
"""Generate the 1200x630 social preview card for mana.salsaparapizza.com.

Composes a branded Open Graph / Twitter card with the app icon or an
optional screenshot crop. Requires Pillow and numpy.

Variants:
    icon  - copy on the left, floating app icon on the right (default)
    hero  - copy on the left, menu-bar popover on the right

Usage:
    python3 scripts/social-card.py --variant icon --out docs/assets/social-preview.jpg
"""

from __future__ import annotations

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "docs", "assets")
FONTS = os.path.join(ASSETS, "fonts")

SCREENSHOT = os.path.join(ASSETS, "mana-app-preview.jpg")
ICON = os.path.join(ASSETS, "app-icon.png")

# Palette lifted from docs/styles.css and docs/hero.css.
BG = (11, 17, 28)
TEXT = (236, 243, 252)
BODY = (198, 212, 228)
MUTED = (143, 160, 180)
CYAN = (103, 217, 245)
CTA_BG = (120, 189, 255)
CTA_TEXT = (7, 23, 37)
PANEL_BORDER = (140, 179, 227)

W, H = 1200, 630
PAD = 76
KICKER = "M A C   M E N U   B A R"
HEADLINE = "Save your mana."
TAGLINE = "Track Codex, OpenCode Go, and Antigravity's Gemini usage in your Mac menu bar."
URL = "mana.salsaparapizza.com"
FOOTER = "Free and open source · macOS 13 or later"

# Popover bounding box inside mana-app-preview.jpg (1280x640), measured from
# the panel's luminance edges plus a small margin for corners and shadow.
POPOVER_BOX = (395, 102, 915, 598)


def font(name: str, size: int, weight: int | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(os.path.join(FONTS, name), size)
    if weight is not None and "variable" in name:
        f.set_variation_by_axes([weight])
    return f


def glow(size: tuple[int, int], centers: list[tuple[float, float, float, tuple[int, int, int]]]) -> Image.Image:
    """Soft additive glow. Each center is (x, y, radius, rgb)."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    acc = np.zeros((h, w, 4), dtype=np.float32)
    for cx, cy, radius, color in centers:
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
        falloff = np.clip(1.0 - dist, 0.0, 1.0) ** 2.2
        for i in range(3):
            acc[..., i] += color[i] * falloff
        acc[..., 3] = np.maximum(acc[..., 3], falloff)
    acc[..., :3] = np.clip(acc[..., :3], 0, 255)
    acc[..., 3] = np.clip(acc[..., 3] * 255.0, 0, 255)
    return Image.fromarray(acc.astype(np.uint8))


def grid_layer(size: tuple[int, int], step: int = 44, alpha: int = 20) -> Image.Image:
    """1px grid echoing the hero's .art-grid, faded with a radial mask."""
    w, h = size
    lines = Image.new("L", size, 0)
    d = ImageDraw.Draw(lines)
    for x in range(0, w, step):
        d.line([(x, 0), (x, h)], fill=alpha, width=1)
    for y in range(0, h, step):
        d.line([(0, y), (w, y)], fill=alpha, width=1)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dist = np.sqrt(((xx - w * 0.70) / (w * 0.60)) ** 2 + ((yy - h * 0.5) / (h * 0.75)) ** 2)
    mask = Image.fromarray((np.clip(1.0 - dist, 0, 1) ** 1.5 * 255).astype(np.uint8))
    faded = Image.composite(lines, Image.new("L", size, 0), mask)
    return Image.merge("RGBA", (Image.new("L", size, 255),) * 3 + (faded,))


def rounded(img: Image.Image, radius: int, outline: tuple[int, int, int, int] | None = None, width: int = 2) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    if outline:
        ImageDraw.Draw(out).rounded_rectangle(
            [width // 2, width // 2, img.size[0] - 1 - width // 2, img.size[1] - 1 - width // 2],
            radius=radius,
            outline=outline,
            width=width,
        )
    return out


def drop_shadow(size: tuple[int, int], radius: int, blur: int, alpha: int, offset: tuple[int, int]) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [offset[0], offset[1], size[0] - 1 + offset[0], size[1] - 1 + offset[1]],
        radius=radius,
        fill=(2, 8, 21, alpha),
    )
    return layer.filter(ImageFilter.GaussianBlur(blur))


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_width: float) -> list[str]:
    lines: list[str] = []
    cur = ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if not cur or draw.textlength(trial, font=fnt) <= max_width:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def brand(img: Image.Image, x: int, y: int, icon_px: int = 40) -> None:
    icon = Image.open(ICON).convert("RGBA").resize((icon_px, icon_px), Image.LANCZOS)
    img.alpha_composite(icon, (x, y))
    ImageDraw.Draw(img).text(
        (x + icon_px + 14, y + icon_px / 2),
        "Mana",
        font=font("PixelifySans-variable.ttf", int(icon_px * 0.78), 650),
        fill=TEXT,
        anchor="lm",
    )


# Vertical gaps between stacked copy elements; headline values are measured,
# not guessed, so the rhythm stays even across variants.
GAP_KICKER_HEAD = 26
GAP_HEAD_BODY = 26
GAP_BODY_PILL = 30
GAP_PILL_FOOTER = 16
BODY_LEADING = 36
PILL_H = 48


def measure(width: float) -> dict:
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    kicker_f = font("PixelifySans-variable.ttf", 17, 600)
    head_f = font("PuppiesPlay-Regular.ttf", 116)
    body_f = font("PixelifySans-variable.ttf", 26, 520)
    pill_f = font("PixelifySans-variable.ttf", 22, 620)
    lines = wrap(probe, TAGLINE, body_f, width)
    head_h = probe.textbbox((0, 0), HEADLINE, head_f)[3]
    kicker_h = probe.textbbox((0, 0), KICKER, kicker_f)[3] + 6
    body_h = (len(lines) - 1) * BODY_LEADING + probe.textbbox((0, 0), lines[-1], body_f)[3]
    total = (
        kicker_h + GAP_KICKER_HEAD + head_h + GAP_HEAD_BODY + body_h
        + GAP_BODY_PILL + PILL_H + GAP_PILL_FOOTER + 20
    )
    return {
        "kicker_f": kicker_f, "head_f": head_f, "body_f": body_f, "pill_f": pill_f,
        "lines": lines, "kicker_h": kicker_h, "head_h": head_h, "body_h": body_h,
        "total": total,
    }


def copy_block(img: Image.Image, x: int, top: int, width: float) -> int:
    """Draw kicker, headline, tagline, URL pill and footer. Returns bottom y."""
    m = measure(width)
    d = ImageDraw.Draw(img)
    y = top
    d.text((x, y), KICKER, font=m["kicker_f"], fill=CYAN, anchor="lt")
    y += m["kicker_h"] + GAP_KICKER_HEAD
    d.text((x - 5, y), HEADLINE, font=m["head_f"], fill=TEXT, anchor="lt", stroke_width=1, stroke_fill=TEXT)
    y += m["head_h"] + GAP_HEAD_BODY
    for line in m["lines"]:
        d.text((x, y), line, font=m["body_f"], fill=BODY, anchor="lt")
        y += BODY_LEADING
    y += GAP_BODY_PILL
    label_w = d.textlength(URL, font=m["pill_f"])
    d.rounded_rectangle([x, y, x + label_w + 44, y + PILL_H], radius=PILL_H // 2, fill=CTA_BG)
    d.text((x + 22, y + PILL_H / 2), URL, font=m["pill_f"], fill=CTA_TEXT, anchor="lm")
    y += PILL_H + GAP_PILL_FOOTER
    d.text((x, y), FOOTER, font=font("PixelifySans-variable.ttf", 18, 500), fill=MUTED, anchor="lt")
    return int(y + 20)


def backdrop() -> Image.Image:
    card = Image.new("RGBA", (W, H), BG + (255,))
    card.alpha_composite(glow((W, H), [
        (880, 300, 520, (36, 91, 200)),
        (930, 470, 300, (40, 190, 219)),
    ]))
    card.alpha_composite(grid_layer((W, H)))
    return card


def copy_top(width: float) -> int:
    """Centre the copy stack in the band below the brand lockup."""
    region_top, region_bottom = 130, H - 40
    return region_top + (region_bottom - region_top - measure(width)["total"]) // 2


def build_hero() -> Image.Image:
    card = backdrop()
    src = Image.open(SCREENSHOT).convert("RGB").crop(POPOVER_BOX)
    pan_height = 470
    scale = pan_height / src.height
    pan = src.resize((round(src.width * scale), pan_height), Image.LANCZOS)
    px = W - PAD - pan.width
    py = (H - pan.height) // 2
    card.alpha_composite(drop_shadow(pan.size, 30, 34, 170, (0, 20)), (px, py))
    card.alpha_composite(rounded(pan, 30, outline=PANEL_BORDER + (70,)), (px, py))

    brand(card, PAD, 54)
    copy_block(card, PAD, copy_top(560), 560)
    return card


def build_icon() -> Image.Image:
    card = backdrop()
    size = 350
    icon = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS).rotate(
        -5, resample=Image.BICUBIC, expand=True
    )
    shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
    shape = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    shape.paste(Image.new("RGBA", icon.size, (2, 8, 21, 255)), (0, 0), icon.getchannel("A"))
    shadow.alpha_composite(shape, (870 - icon.width // 2 + 8, 330 - icon.height // 2 + 30))
    card.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    card.alpha_composite(icon, (870 - icon.width // 2, 330 - icon.height // 2))

    brand(card, PAD, 54)
    copy_block(card, PAD, copy_top(540), 540)
    return card


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=["hero", "icon"], default="icon")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    card = build_hero() if args.variant == "hero" else build_icon()
    if card.size != (W, H):
        raise SystemExit(f"unexpected size {card.size}")

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    if args.out.endswith(".png"):
        card.convert("RGB").save(args.out, "PNG", optimize=True)
    else:
        card.convert("RGB").save(args.out, "JPEG", quality=90, optimize=True, progressive=True)
    print(f"wrote {args.out} {card.size[0]}x{card.size[1]}")


if __name__ == "__main__":
    main()
