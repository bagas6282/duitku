#!/usr/bin/env python3
"""Generate the Duitku launcher icon set.

Design: a deep-ink rounded square with a mint upward trend line and a coin
dot — reads at 48px, no text (text is illegible at launcher sizes), and stays
legible on both light and dark home screens.
"""
import os
from PIL import Image, ImageDraw

MINT = (20, 184, 122, 255)
PAPER = (255, 255, 255, 255)
INK = (16, 19, 26, 255)

MASTER = 1024
OUT = "android/app/src/main/res"


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_icon(size, padded=False, bg=True, scale=1.0, glyph=True):
    """Render one icon variant.

    padded=True leaves the safe-zone margin Android's adaptive icons need
    (the launcher may crop up to 33% of the canvas).

    glyph=False drops the mark inside the coin. Below ~72px that mark
    antialiases into an indistinct speck, and a plain white coin reads
    cleanly as money at every density — so small renders omit it.
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if bg:
        d.rounded_rectangle(
            [0, 0, size - 1, size - 1],
            radius=int(size * 0.24),
            fill=INK,
        )

    # Content box: shrunk for adaptive safe zone, otherwise a small margin.
    inset = size * (0.30 if padded else 0.20)
    box = [inset, inset, size - inset, size - inset]
    w = box[2] - box[0]
    h = box[3] - box[1]
    lw = max(2, int(size * 0.062 * scale))

    # One clean upward bend. A zigzag compresses into a knot below 96px, and
    # chart furniture (grid lines, extra nodes) turns into texture at launcher
    # sizes, so the mark carries the idea on its own.
    coin_cr = size * 0.125 * scale
    coin_cx = box[2] - coin_cr * 0.45
    coin_cy = box[1] + coin_cr * 0.75

    pts = [
        (box[0], box[3] - h * 0.16),
        (box[0] + w * 0.52, box[3] - h * 0.44),
        (box[2], box[3] - h * 0.78),
    ]
    d.line(pts, fill=MINT, width=lw, joint="curve")

    # Tether segment: a short, deliberately thinner stalk that ties the line's
    # end to the coin. Making the connection explicit beats the ambiguous
    # near-touch, which reads as a mistake rather than a choice.
    tether_from = pts[-1]
    tether_to = (
        coin_cx - coin_cr * 0.72,
        coin_cy + coin_cr * 0.72,
    )
    d.line(
        [tether_from, tether_to],
        fill=MINT,
        width=max(2, int(lw * 0.62)),
    )

    # Endpoint node on the line start, and one on the peak.
    r = lw * 1.2
    d.ellipse(
        [pts[0][0] - r, pts[0][1] - r, pts[0][0] + r, pts[0][1] + r],
        fill=MINT,
    )

    # A soft halo reads as a second, sloppier stroke once the icon is
    # downscaled, so the line is drawn as one clean pass instead.

    # The coin: a paper disc sitting above the line's peak.
    cr = coin_cr
    cx, cy = coin_cx, coin_cy
    d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=PAPER)

    # One thick vertical bar with a single cross-stroke. Below 72px it cannot
    # survive antialiasing, so small variants render the coin blank instead.
    if glyph and size >= 72:
        stroke = max(5, int(cr * 0.40))
        d.line(
            [(cx, cy - cr * 0.66), (cx, cy + cr * 0.66)],
            fill=INK,
            width=stroke,
        )
        d.line(
            [
                (cx - cr * 0.48, cy - cr * 0.19),
                (cx + cr * 0.48, cy - cr * 0.19),
            ],
            fill=INK,
            width=stroke,
        )

    return img


def main():
    os.makedirs(f"{OUT}/mipmap-anydpi-v26", exist_ok=True)

    # Legacy square/rounded icons per density.
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in sizes.items():
        os.makedirs(f"{OUT}/{folder}", exist_ok=True)
        icon = draw_icon(px)
        icon.save(f"{OUT}/{folder}/ic_launcher.png")
        # Round variant for launchers that ask for it.
        rnd = draw_icon(px)
        rnd.putalpha(rounded_mask(px, px // 2))
        rnd.save(f"{OUT}/{folder}/ic_launcher_round.png")

    # Adaptive icon layers (Android 8+): foreground plus solid background.
    fg_px = 432
    fg = draw_icon(fg_px, padded=True, bg=False)
    fg.save(f"{OUT}/mipmap-anydpi-v26/ic_launcher_foreground.png")

    for folder, px in sizes.items():
        fg = draw_icon(px * 2, padded=True, bg=False)
        fg.save(f"{OUT}/{folder}/ic_launcher_foreground.png")

    bg = Image.new("RGBA", (108, 108), INK)
    os.makedirs(f"{OUT}/drawable", exist_ok=True)
    bg.save(f"{OUT}/drawable/ic_launcher_background.png")

    with open(f"{OUT}/mipmap-anydpi-v26/ic_launcher.xml", "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n'
        )
    with open(f"{OUT}/mipmap-anydpi-v26/ic_launcher_round.xml", "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n'
        )

    # Color resource the adaptive background points at.
    os.makedirs(f"{OUT}/values", exist_ok=True)
    with open(f"{OUT}/values/colors.xml", "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#10131A</color>\n'
            "</resources>\n"
        )

    # Keep a copy of the master for the report.
    os.makedirs("assets/branding", exist_ok=True)
    draw_icon(MASTER).save("assets/branding/icon_master.png")
    print("icons generated")


if __name__ == "__main__":
    main()
