#!/usr/bin/env python3
"""Builds the Google Play phone screenshots (1080 x 1920, 9:16) from the raw
emulator captures of the CI "store" job (integration_test/store_screens_test.dart).

    python3 tool/store_screenshots.py <folder with store-S*.png> [out folder]

The raw screens come from store_shots/store_shots_test.dart (rendered on
the CI host) or from the emulator job "store" (integration_test).

Each image: a caption on the brand background and the real app screen in a
phone frame. Nothing is mocked: the screen is the app as captured.
Requires Pillow. Uses the app's own Outfit font (assets/fonts).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "assets", "fonts")
W, H = 1080, 1920

# (raw capture, headline, subline). Order = order in the store listing.
SHOTS = [
    ("S2-gameplay", "Place, pour,\nburst!", "Blocks melt into real flowing sand"),
    ("S7-results", "Fill rows,\nchase combos", "Multi-row bursts score big"),
    ("S4-campaign", "100 levels,\nsix worlds", "Every level proven winnable"),
    ("S3-daily-sheet", "A new puzzle\nevery day", "Win it, keep your streak going"),
    ("S5-modes", "Six ways\nto play", "Classic, Time, Limited Moves, Endless"),
    ("S6-shop", "Power-ups\nand looks", "Boards, sand colours, grains and bursts"),
    ("S1-home", "Missions every\nday", "Earn coins, unlock achievements"),
    ("S8-share-card", "Share your\nbest scores", "Challenge friends to beat you"),
]
# Eight screenshots are used, like Block Burst Magic. The store job also
# captures S9-stats, used in place of any capture that is missing.
SPARE = ("S9-stats", "Track your\nprogress", "Stats and achievements")

# Share of the capture height taken by the status bar (top) and the gesture
# navigation bar (bottom) on the Pixel 6 profile used in CI.
STATUS_BAR = 126 / 2400
NAV_BAR = 62 / 2400

BG_TOP = (21, 29, 69)
BG_BOTTOM = (10, 16, 40)
TEXT = (244, 246, 255)
MUTED = (169, 177, 214)
VIOLET = (140, 92, 255)
FRAME = (38, 46, 96)


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"Outfit-{weight}.ttf"), size)


def background():
    bg = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / (H - 1)
        px.line(
            [(0, y), (W, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)),
        )
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W / 2 - 560, 140, W / 2 + 560, 1100), fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    bg.paste(Image.new("RGB", (W, H), VIOLET), (0, 0), glow.point(lambda v: v * 0.45))
    return bg


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.size[0] - 1, img.size[1] - 1), radius, fill=255
    )
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def compose(raw_path, headline, subline, out_path, card=False):
    raw = Image.open(raw_path).convert("RGB")
    canvas = background()
    d = ImageDraw.Draw(canvas)

    # Caption.
    hf = font("ExtraBold", 84)
    y = 96
    for line in headline.split("\n"):
        w = d.textlength(line, font=hf)
        d.text(((W - w) / 2, y), line, font=hf, fill=TEXT)
        y += 98
    sf = font("Medium", 40)
    w = d.textlength(subline, font=sf)
    d.text(((W - w) / 2, y + 18), subline, font=sf, fill=MUTED)
    top = y + 100

    if card:
        # The share image itself (centre of the capture), slightly tilted
        # like a photo being sent.
        rw, rh = raw.size
        ch = round(rw * 1350 / 1080)
        if rh == ch:
            # The share image itself (rendered directly, not a capture).
            shot = raw
        else:
            # The card is drawn full width on black; find its top edge.
            top_edge = next(
                y for y in range(round(rh * STATUS_BAR), rh)
                if sum(raw.getpixel((4, y))) > 15
            )
            shot = raw.crop((0, top_edge, rw, top_edge + ch))
        avail_h = H - top - 90
        scale = min(880 / shot.width, avail_h / shot.height)
        shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
        shot = rounded(shot, 36)
    else:
        # The app screen without Android's status and navigation bars
        # (their clock and icons only distract), in a simple frame.
        rw, rh = raw.size
        raw = raw.crop((0, round(rh * STATUS_BAR), rw, rh - round(rh * NAV_BAR)))
        avail_h = H - top - 40
        scale = avail_h / raw.height
        sw, sh = round(raw.width * scale), round(raw.height * scale)
        screen = rounded(raw.resize((sw, sh), Image.LANCZOS), 44)
        bezel = 14
        shot = Image.new("RGBA", (sw + bezel * 2, sh + bezel * 2))
        ImageDraw.Draw(shot).rounded_rectangle(
            (0, 0, shot.width - 1, shot.height - 1), 44 + bezel, fill=FRAME + (255,)
        )
        shot.paste(screen, (bezel, bezel), screen)

    x = (W - shot.width) // 2
    if card:
        top += (H - top - shot.height) // 2 - 20
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 10, top + 30, x + shot.width - 10, top + shot.height + 20), 60, fill=170
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.paste(Image.new("RGB", (W, H), (3, 5, 15)), (0, 0), shadow)
    canvas.paste(shot, (x, top), shot)
    canvas.save(out_path, optimize=True)


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "store", "screenshots")
    os.makedirs(out, exist_ok=True)
    n = 0
    spare_used = False
    for name, headline, subline in SHOTS:
        raw = os.path.join(src, f"store-{name}.png")
        if not os.path.exists(raw):
            spare = os.path.join(src, f"store-{SPARE[0]}.png")
            if spare_used or not os.path.exists(spare):
                print(f"missing {raw}, skipped")
                continue
            print(f"missing {raw}, using {SPARE[0]}")
            spare_used = True
            raw = spare
            name, headline, subline = SPARE
        n += 1
        dest = os.path.join(out, f"{n:02d}-{name.split('-', 1)[1]}.png")
        compose(raw, headline, subline, dest, card=name.startswith("S8"))
        print(dest)


if __name__ == "__main__":
    main()
