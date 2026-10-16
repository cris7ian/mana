#!/usr/bin/env python3
"""Render the approved centered Mana header with white Puppies Play lettering."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'app-store-release-prep/proposal'
SIZE = (3840, 1646)
SAFE = (1097, 493, 2743, 1154)


def background():
    yy, xx = np.mgrid[0:412, 0:960].astype(float)
    a = np.empty((412, 960, 3)); a[:] = (8, 18, 37)
    glow = np.exp(-(((xx - 480) / 250)**2 + ((yy - 206) / 200)**2) * 2)
    a += glow[:, :, None] * np.array((8, 49, 105))
    im = Image.fromarray(np.clip(a, 0, 255).astype('uint8')).resize(SIZE, Image.Resampling.BICUBIC).convert('RGBA')
    layer = Image.new('RGBA', SIZE); d = ImageDraw.Draw(layer)
    tile = 80
    for y in range(0, SIZE[1], tile):
        for x in range(0, SIZE[0], tile):
            cx, cy = x / 4, y / 4
            wave = math.sin(cx * .017 + cy * .027 - 1.8)
            eddy = math.sin(cy * .019 - cx * .009 + .825)
            wind = max(0, (wave + eddy + .4) / 2.4)**2
            seed = math.sin((x / tile + 1) * 127.1 + (y / tile + 1) * 311.7) * 43758.5453
            grain = seed - math.floor(seed)
            dist = abs(x + tile / 2 - SIZE[0] / 2) / (SIZE[0] / 2)
            quiet = .25 + .75 * dist**.8
            alpha = int((.025 + .17 * wind + .09 * grain) * quiet * 210)
            d.rectangle((x+2, y+2, x+tile-3, y+tile-3), fill=(76, 157, 247, alpha))
    im.alpha_composite(layer)
    return im


def main():
    canvas = background()
    with Image.open(ROOT / 'docs/assets/hexagon-128.png') as opened:
        logo = opened.convert('RGBA').resize((304, 304), Image.Resampling.LANCZOS)
    font = ImageFont.truetype(str(ROOT / 'docs/assets/fonts/PuppiesPlay-Regular.ttf'), 270)
    box = tuple(int(n) for n in font.getbbox('mana.', stroke_width=2))
    name = Image.new('RGBA', (box[2]-box[0]+8, box[3]-box[1]+8))
    ImageDraw.Draw(name).text((4-box[0], 4-box[1]), 'mana.', font=font, fill='#ffffff', stroke_width=2)
    y = (SIZE[1] - logo.height - 55 - name.height) // 2
    for art, top in ((logo, y), (name, y + logo.height + 55)):
        x = (SIZE[0] - art.width) // 2
        assert x >= SAFE[0] and top >= SAFE[1] and x+art.width <= SAFE[2] and top+art.height <= SAFE[3]
        canvas.alpha_composite(art, (x, top))
    final = canvas.convert('RGB')
    OUT.mkdir(parents=True, exist_ok=True)
    final.save(OUT / 'product-page-header-21x9.png', optimize=True)
    final.save(OUT / 'product-page-header-21x9.jpg', quality=96, subsampling=0)
    final.resize((1600, 686), Image.Resampling.LANCZOS).save(OUT / 'product-page-header-preview.jpg', quality=95, subsampling=0)
    print('PASS: approved centered header; 3840 x 1646 RGB; white script; Apple safe area.')


if __name__ == '__main__':
    main()
