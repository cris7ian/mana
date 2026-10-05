#!/usr/bin/env python3
"""Compose Mana's iPhone App Store proposal from unmodified demo captures.

Requires Pillow and numpy, like scripts/social-card.py. No provider access.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "app-store-release-prep"
SOURCE = PACKAGE / "screenshots" / "source"
FONTS = ROOT / "docs" / "assets" / "fonts"
ICON = ROOT / "ios" / "Mana" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
HEX = ROOT / "docs" / "assets" / "hexagon-128.png"
SIZES = {"iphone-6.9": (1320, 2868), "iphone-6.5": (1284, 2778)}
INK = "#0b111c"
WHITE = "#ecf3fc"
CYAN = "#67d9f5"
BODY = "#c6d4e4"
PAPER = "#f3f0e8"
BLUE = "#123baa"
POSTERS = [
    {"slug": "01-save-your-mana", "headline": ["Save your", "mana."],
     "body": ["Your AI usage.", "One clear view."], "theme": "dark", "screen": "usage-dark"},
    {"slug": "02-two-spellbooks", "headline": ["Two spellbooks.", "One place."],
     "body": ["Codex and OpenCode Go.", "See what’s left in both."], "theme": "paper", "screen": "usage-light",
     "crops": [[60, 564, 1260, 1356], [60, 1416, 1260, 2430]]},
    {"slug": "03-reset-countdowns", "headline": ["Know when", "you’re back."],
     "body": ["See when your quotas reset.", "Plan your next spell."], "theme": "blue", "screen": "codex-dark",
     "crops": [[60, 648, 1260, 1410]]},
    {"slug": "04-your-keys", "headline": ["Your keys.", "Your iPhone."],
     "body": ["Credentials stay in Keychain.", "Only the latest usage is saved."], "theme": "paper", "screen": "privacy-light"},
]


def font(size: int, bold: bool = False, kind: str = "sans") -> ImageFont.FreeTypeFont:
    if kind == "script":
        path = FONTS / "PuppiesPlay-Regular.ttf"
    elif kind == "pixel":
        path = FONTS / "PixelifySans-variable.ttf"
    else:
        path = Path("/System/Library/Fonts/Supplemental") / ("Arial Bold.ttf" if bold else "Arial.ttf")
    value = ImageFont.truetype(str(path), size)
    if kind == "pixel":
        value.set_variation_by_axes([650 if bold else 500])
    return value


def text(image: Image.Image, xy: tuple[float, float], value: str, size: int,
         fill: str, bold: bool = False, kind: str = "sans", max_width: int | None = None) -> None:
    draw = ImageDraw.Draw(image)
    face = font(size, bold, kind)
    if max_width is not None and draw.textlength(value, face) > max_width:
        raise ValueError(f"Text exceeds its safe width: {value!r}")
    draw.text(xy, value, font=face, fill=fill, anchor="lt")


def hexagon(cx: float, cy: float, radius: float) -> list[tuple[float, float]]:
    return [(cx + radius * math.cos(math.radians(30 + n * 60)),
             cy + radius * math.sin(math.radians(30 + n * 60))) for n in range(6)]


def backdrop(theme: str) -> Image.Image:
    size = (1320, 2868)
    base = PAPER if theme == "paper" else BLUE if theme == "blue" else INK
    image = Image.new("RGBA", size, base)
    # Render the atmosphere at half resolution. Fixed geometry keeps rerenders deterministic.
    if theme != "paper":
        yy, xx = np.mgrid[0:1434, 0:660].astype(np.float32)
        rgb = np.zeros((1434, 660, 4), dtype=np.float32)
        for cx, cy, radius, color in [(500, 950, 630, (34, 105, 209)), (230, 1330, 360, (28, 167, 193))]:
            falloff = np.maximum(0, 1 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius) ** 2
            rgb[:, :, :3] += falloff[:, :, None] * color
            rgb[:, :, 3] = np.maximum(rgb[:, :, 3], falloff * 160)
        layer = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize(size, Image.Resampling.BICUBIC)
        image.alpha_composite(layer)
    geometry = Image.new("RGBA", size)
    draw = ImageDraw.Draw(geometry)
    stroke = (43, 92, 127, 22) if theme == "paper" else (103, 217, 245, 35)
    for radius in (690, 860, 1030):
        draw.polygon(hexagon(860, 2110, radius), outline=stroke, width=2)
    # Small spell-like marks, not a busy wallpaper.
    for x, y, r in [(1100, 990, 15), (182, 2230, 10), (1130, 2570, 11)]:
        draw.line((x - r, y, x + r, y), fill=stroke, width=3)
        draw.line((x, y - r, x, y + r), fill=stroke, width=3)
    image.alpha_composite(geometry)
    return image


def brand(image: Image.Image, theme: str, number: int | None = None) -> None:
    ink = INK if theme == "paper" else WHITE
    icon = Image.open(HEX).convert("RGBA").resize((64, 64), Image.Resampling.LANCZOS)
    image.alpha_composite(icon, (96, 100))
    text(image, (181, 111), "Mana", 48, ink, True, "pixel")
    text(image, (96, 205), "AI USAGE, AT A GLANCE", 24, "#526775" if theme == "paper" else BODY, True)
    if number is not None:
        text(image, (1110, 116), f"0{number}", 26, "#526775" if theme == "paper" else BODY)


def rounded(source: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", source.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, source.width - 1, source.height - 1), radius=radius, fill=255)
    result = source.convert("RGBA")
    result.putalpha(mask)
    return result


def phone(image: Image.Image, name: str, x: int, y: int, width: int) -> None:
    source = Image.open(SOURCE / f"{name}.png").convert("RGB")
    height = round(width * source.height / source.width)
    bezel = round(width * 0.025)
    radius = round(width * 0.13)
    total_w, total_h = width + 2 * bezel, height + 2 * bezel
    if x < 0 or y < 0 or x + total_w > image.width or y + total_h > image.height:
        raise ValueError(f"Phone is outside the poster: {name}")
    shadow = Image.new("RGBA", image.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x - 12, y + 30, x + total_w + 12, y + total_h + 30),
                                            radius=radius, fill=(1, 8, 24, 90))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(35)))
    frame = Image.new("RGBA", (total_w, total_h))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle((0, 0, total_w - 1, total_h - 1), radius=radius, fill="#111823", outline="#6d7786", width=3)
    resized = source.resize((width, height), Image.Resampling.LANCZOS)
    # No UI reconstruction, recoloring, text replacement, or removal of demo labels.
    frame.alpha_composite(rounded(resized, radius - bezel), (bezel, bezel))
    image.alpha_composite(frame, (x, y))


def pill(image: Image.Image, xy: tuple[int, int], value: str, theme: str) -> None:
    face = font(25, True)
    draw = ImageDraw.Draw(image)
    width = int(draw.textlength(value, face)) + 42
    x, y = xy
    fill, ink = ("#e3e6df", "#314950") if theme == "paper" else ("#214d84", WHITE)
    draw.rounded_rectangle((x, y, x + width, y + 56), radius=28, fill=fill)
    draw.text((x + 21, y + 17), value, font=face, fill=ink, anchor="lt")


def native_card(image: Image.Image, screen: str, crop: list[int], x: int, y: int, width: int) -> None:
    """Enlarge a complete native provider card, including its sample-data label."""
    with Image.open(SOURCE / f"{screen}.png") as source:
        if source.size != (1320, 2868):
            raise ValueError("Card crops require the documented 1320 × 2868 captures.")
        card = source.crop(tuple(crop))
    height = round(width * card.height / card.width)
    if y + height > 2740:
        raise ValueError("Native card overlaps the poster footer")
    radius = round(72 * width / card.width)
    shadow = Image.new("RGBA", image.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 15, x + width, y + height + 15),
                                            radius=radius, fill=(1, 8, 24, 45))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)))
    image.alpha_composite(rounded(card.resize((width, height), Image.Resampling.LANCZOS), radius), (x, y))


def poster(index: int) -> Image.Image:
    spec = POSTERS[index]
    theme = spec["theme"]
    image = backdrop(theme)
    ink = INK if theme == "paper" else WHITE
    secondary = "#435662" if theme == "paper" else BODY
    brand(image, theme, index + 1)
    if index == 0:
        text(image, (90, 310), spec["headline"][0], 172, ink, True, max_width=1130)
        text(image, (92, 476), spec["headline"][1], 360, CYAN, kind="script", max_width=1100)
        body_y = 805
    else:
        for n, line in enumerate(spec["headline"]):
            text(image, (90, 326 + n * 158), line, 144 if index == 1 else 156,
                 CYAN if theme == "blue" and n == 1 else ink, True, max_width=1140)
        body_y = 697
    for n, line in enumerate(spec["body"]):
        text(image, (96, body_y + n * 69), line, 53, secondary, max_width=1120)
    if index == 1:
        native_card(image, spec["screen"], spec["crops"][0], 96, 946, 1128)
        native_card(image, spec["screen"], spec["crops"][1], 96, 1750, 1128)
    elif index == 2:
        pill(image, (96, 947), "FROM CODEX · SAMPLE DATA", theme)
        native_card(image, spec["screen"], spec["crops"][0], 96, 1070, 1128)
        clock = Image.new("RGBA", image.size)
        draw = ImageDraw.Draw(clock)
        draw.ellipse((610, 2110, 1270, 2770), outline=(103, 217, 245, 55), width=4)
        draw.line((940, 2240, 940, 2440, 1070, 2510), fill=(103, 217, 245, 80), width=7)
        draw.ellipse((930, 2430, 950, 2450), fill=(103, 217, 245, 100))
        image.alpha_composite(clock)
        text(image, (96, 1960), "Tap a countdown.", 80, WHITE, True, max_width=1120)
        text(image, (96, 2076), "See the date and time.", 52, BODY, max_width=1120)
    else:
        width = 756 if index == 0 else 780
        y = 1055 if index == 0 else 990
        phone(image, spec["screen"], (1320 - width - round(width * .05)) // 2, y, width)
    # Explain the numbers without pretending they came from a connected account.
    text(image, (96, 2789), "Actual app screens · Sample data", 25, secondary)
    return image.convert("RGB")


def contact_sheet(images: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGB", (1640, 1200), PAPER)
    text(sheet, (60, 42), "Mana / iPhone", 35, INK, True, "pixel")
    text(sheet, (60, 115), "A little magic. A lot of clarity.", 66, INK, True)
    text(sheet, (60, 202), "App Store visual proposal · Actual app screens, synthetic quotas", 25, "#435662")
    for n, image in enumerate(images):
        thumb = image.resize((365, 793), Image.Resampling.LANCZOS)
        x = 60 + n * 386
        sheet.paste(thumb, (x, 270))
        text(sheet, (x, 1089), ["01 / THE PROMISE", "02 / THE PROVIDERS", "03 / THE RESETS", "04 / THE PRIVACY"][n], 18, INK, True)
    text(sheet, (60, 1144), "Save your mana. Spend it well.", 26, "#435662")
    return sheet


def social_card() -> Image.Image:
    card = backdrop("dark").resize((1200, 2607), Image.Resampling.LANCZOS).crop((0, 0, 1200, 630))
    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle((734, 90, 1084, 440), radius=80, fill="#0d2c4d")
    icon = rounded(Image.open(ICON).resize((310, 310), Image.Resampling.LANCZOS), 68)
    card.alpha_composite(icon, (754, 110))
    text(card, (70, 68), "Mana / iPhone", 31, BODY, True, "pixel")
    text(card, (66, 156), "Save your", 96, WHITE, True)
    text(card, (64, 249), "mana.", 194, CYAN, kind="script")
    text(card, (70, 459), "Codex. OpenCode Go. One clear view.", 27, BODY)
    text(card, (70, 555), "mana.salsaparapizza.com", 21, BODY)
    return card.convert("RGB")


def import_captures(directory: Path) -> None:
    manifest = json.loads((directory / "manifest.json").read_text())
    SOURCE.mkdir(parents=True, exist_ok=True)
    imported = []
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.startswith("app-store-"):
                continue
            # Xcode includes a filename suffix in some versions of the export schema.
            name = Path(name).stem.removeprefix("app-store-").split("_", 1)[0]
            if name not in {"usage-light", "usage-dark", "codex-light", "codex-dark", "opencode-light", "settings-light", "privacy-light"}:
                continue
            filename = attachment["exportedFileName"]
            data = (directory / filename).read_bytes()
            (SOURCE / f"{name}.png").write_bytes(data)
            imported.append({"name": name, "sha256": hashlib.sha256(data).hexdigest(),
                             "source": "XCTest screenshot of the real app in isolated demo mode",
                             "synthetic": True})
    if len(imported) != 7:
        raise ValueError(f"Expected seven demo captures; imported {len(imported)}. Inspect Xcode's attachment manifest.")
    (SOURCE / "provenance.json").write_text(json.dumps(imported, indent=2) + "\n")
    print(f"Imported {len(imported)} unmodified demo captures.")


def render() -> None:
    images = [poster(n) for n in range(len(POSTERS))]
    records = []
    for name, size in SIZES.items():
        destination = PACKAGE / "screenshots" / name
        destination.mkdir(parents=True, exist_ok=True)
        for spec, image in zip(POSTERS, images):
            path = destination / f"{spec['slug']}.png"
            image.resize(size, Image.Resampling.LANCZOS).save(path, optimize=True)
            records.append({"file": str(path.relative_to(PACKAGE)), "width": size[0], "height": size[1],
                            "mode": "RGB", "headline": " ".join(spec["headline"]),
                            "source": spec["screen"], "source-crops": spec.get("crops", []),
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    preview = PACKAGE / "proposal"
    preview.mkdir(parents=True, exist_ok=True)
    contact_sheet(images).save(preview / "contact-sheet.jpg", quality=94)
    social_card().save(preview / "social-preview.jpg", quality=94)
    icons = PACKAGE / "icon"
    icons.mkdir(parents=True, exist_ok=True)
    with Image.open(ICON) as source:
        if source.size != (1024, 1024):
            raise ValueError("Expected the app's original 1024px icon.")
        source.convert("RGB").save(icons / "app-icon-1024.png", optimize=True)
    (PACKAGE / "screenshots" / "manifest.json").write_text(json.dumps(records, indent=2) + "\n")
    listing = json.loads((PACKAGE / "metadata" / "listing-en-US.json").read_text())
    for key in ("name", "subtitle", "promotional-text", "description", "keywords", "whats-new"):
        (PACKAGE / "metadata" / f"{key}.txt").write_text(listing[key] + "\n")
    print("Rendered eight RGB screenshots, a contact sheet, a social card, an icon, and copy-ready metadata.")


def verify() -> None:
    listing = json.loads((PACKAGE / "metadata" / "listing-en-US.json").read_text())
    limits = {"name": 30, "subtitle": 30, "promotional-text": 170, "description": 4000, "keywords": 100, "whats-new": 4000}
    for key, limit in limits.items():
        value = listing[key]
        count = len(value.encode("utf-8")) if key == "keywords" else len(value)
        if count > limit:
            raise ValueError(f"{key}: {count} exceeds {limit}")
        if (PACKAGE / "metadata" / f"{key}.txt").read_text() != value + "\n":
            raise ValueError(f"Copy-ready field drifted: {key}")
        print(f"{key}: {count}/{limit}")
    records = json.loads((PACKAGE / "screenshots" / "manifest.json").read_text())
    if len(records) != len(POSTERS) * len(SIZES):
        raise ValueError("Screenshot count mismatch")
    for record in records:
        path = PACKAGE / record["file"]
        with Image.open(path) as image:
            if image.size != (record["width"], record["height"]) or image.mode != "RGB" or image.format != "PNG":
                raise ValueError(f"Invalid screenshot: {path}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
            raise ValueError(f"Screenshot changed without rerender: {path}")
    for record in json.loads((SOURCE / "provenance.json").read_text()):
        if hashlib.sha256((SOURCE / f"{record['name']}.png").read_bytes()).hexdigest() != record["sha256"]:
            raise ValueError(f"Source capture changed: {record['name']}")
    with Image.open(PACKAGE / "icon" / "app-icon-1024.png") as image:
        if image.size != (1024, 1024) or image.mode != "RGB":
            raise ValueError("Invalid App Store icon")
    for filename, size in (("contact-sheet.jpg", (1640, 1200)), ("social-preview.jpg", (1200, 630))):
        with Image.open(PACKAGE / "proposal" / filename) as image:
            if image.size != size or image.mode != "RGB":
                raise ValueError(f"Invalid proposal art: {filename}")
    if (PACKAGE / "web").exists() or any(path.suffix in {".html", ".css"} for path in PACKAGE.rglob("*")):
        raise ValueError("The App Store asset package must not contain a separate website.")
    print("PASS: dimensions, opaque RGB PNGs, metadata limits, generated fields, source/export hashes, and no website artifacts.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["import-captures", "render", "verify"])
    parser.add_argument("directory", type=Path, nargs="?")
    args = parser.parse_args()
    if args.command == "import-captures":
        if args.directory is None:
            parser.error("import-captures requires an attachment directory")
        import_captures(args.directory)
    elif args.command == "render":
        render()
    else:
        verify()


if __name__ == "__main__":
    main()
