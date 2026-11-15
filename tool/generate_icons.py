"""Builds every Sand Burst Magic icon asset from the official icon artwork.

Source (never modified): tool/icon_source/sand_burst_magic_icon_master.png
(1254 x 1254 RGB, the supplied official icon artwork).

Outputs
  store/icon-512.png                     Google Play icon, 512 x 512, 32-bit PNG
  store/feature-graphic-1024x500.png     Google Play feature graphic
  android/app/src/main/res/
    mipmap-<dpi>/ic_launcher.png             legacy square icon (Android 7.x)
    mipmap-<dpi>/ic_launcher_round.png       legacy round icon (Android 7.1)
    mipmap-<dpi>/ic_launcher_foreground.png  adaptive foreground (Android 8+)
    mipmap-<dpi>/ic_launcher_background.png  adaptive background
    mipmap-<dpi>/ic_launcher_monochrome.png  themed icon (Android 13+)
    drawable-<dpi>/splash_mark.png           launch screen (Android 7-11)
  tool/icon_source/preview-masks.png     the adaptive icon under common
                                         launcher masks, at small sizes (check)

Adaptive icons are 108 dp layers of which launchers show a masked region;
only the central 66 dp circle is guaranteed visible under every mask
(circle, squircle, rounded square, teardrop). The artwork is scaled so the
farthest point of its neon frame (the rounded corners) sits inside that
circle, so the piece, the sand and the whole frame survive every common mask.
Outside the frame the artwork's own navy surround fades into a matching
background layer, so there is no visible seam.

Same method as Block Burst Magic's tool/generate_icons.py, with this
artwork's frame measured below.

Run from the project root:  python3 tool/generate_icons.py
Requires Pillow and numpy.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'tool/icon_source/sand_burst_magic_icon_master.png'
RES = ROOT / 'android/app/src/main/res'
STORE = ROOT / 'store'

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

# Geometry of the neon frame in the 1254 px master, measured from the image
# (outermost bright pixels on the middle row/column and near the corners).
FRAME_LEFT, FRAME_TOP, FRAME_RIGHT, FRAME_BOTTOM = 18, 18, 1234, 1216
FRAME_RADIUS = 290          # corner radius of the outer frame line, px

ADAPTIVE_DP = 108
SAFE_RADIUS_DP = 33          # radius of the 66 dp always-visible circle
FRAME_TARGET_DP = 31.5       # keep the frame corners 1.5 dp inside it


def load_master():
    img = Image.open(SOURCE).convert('RGB')
    if img.size[0] != img.size[1]:
        raise SystemExit(f'Icon master must be square, got {img.size}')
    return img


def frame_sdf(size):
    """Signed distance (px, master scale) to the frame's rounded rectangle;
    negative inside."""
    h = w = size
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    cx = (FRAME_LEFT + FRAME_RIGHT) / 2
    cy = (FRAME_TOP + FRAME_BOTTOM) / 2
    hx = (FRAME_RIGHT - FRAME_LEFT) / 2 - FRAME_RADIUS
    hy = (FRAME_BOTTOM - FRAME_TOP) / 2 - FRAME_RADIUS
    qx = np.abs(xx - cx) - hx
    qy = np.abs(yy - cy) - hy
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - FRAME_RADIUS


def frame_reach(size):
    """Farthest point of the frame outline from the image centre, px."""
    sdf = frame_sdf(size)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    on = np.abs(sdf) < 1.0
    c = (size - 1) / 2
    return float(np.hypot(xx[on] - c, yy[on] - c).max())


def cutout(master):
    """The artwork with its navy surround faded out beyond the frame glow."""
    sdf = frame_sdf(master.size[0])
    # Fully opaque up to 20 px outside the frame (keeps the neon glow),
    # then a soft 60 px fade to transparent.
    alpha = np.clip(1 - (sdf - 20) / 60, 0, 1)
    rgba = np.dstack([np.asarray(master), (alpha * 255).astype(np.uint8)])
    return Image.fromarray(rgba, 'RGBA')


def surround_colors(master):
    """Average colours of the artwork's surround (outside the frame), top and
    bottom, used for the adaptive background so layers blend seamlessly."""
    a = np.asarray(master).astype(float)
    sdf = frame_sdf(master.size[0])
    outside = sdf > 40
    half = master.size[1] // 2
    top = a[:half][outside[:half]].mean(axis=0)
    bottom = a[half:][outside[half:]].mean(axis=0)
    return tuple(int(v) for v in top), tuple(int(v) for v in bottom)


def background_layer(px, top, bottom):
    """Vertical gradient in the artwork's surround colours with a soft glow."""
    yy, xx = np.mgrid[0:px, 0:px].astype(float) / max(px - 1, 1)
    t = yy[..., None]
    grad = np.array(top) * (1 - t) + np.array(bottom) * t
    glow = np.exp(-(((xx - 0.5) ** 2 + (yy - 0.45) ** 2) / 0.06))[..., None]
    grad = grad + glow * np.array([20, 28, 80])
    return Image.fromarray(np.clip(grad, 0, 255).astype(np.uint8), 'RGB')


def place(art, canvas_px, art_px):
    """Centres a square RGBA image of size art_px on a transparent canvas."""
    canvas = Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
    scaled = art.resize((art_px, art_px), Image.LANCZOS)
    off = (canvas_px - art_px) // 2
    canvas.alpha_composite(scaled, (off, off))
    return canvas


def artwork_dp(canvas_dp, reach, master_px):
    """Width (dp) the master must have so its frame reach is FRAME_TARGET_DP
    from the centre. Same ratio is used for any canvas."""
    return FRAME_TARGET_DP * master_px / reach * (canvas_dp / ADAPTIVE_DP)


# Themed-icon geometry, measured from the master (px): the four blocks of
# the T piece (left, top, size), the falling grains, and the dune's top.
THEMED_BLOCKS = [(400, 195, 152), (400, 343, 152), (555, 343, 152),
                 (710, 343, 152), (555, 490, 152)]
THEMED_GRAINS = [(x, y) for y in (660, 705, 750) for x in range(470, 800, 46)]


def sand_mask(master):
    """Clean silhouette for the themed icon (Android 13+): the T piece, a
    few falling grains and the sand dune, as flat shapes. Android tints it
    with the wallpaper colour."""
    import math
    n = master.size[0]
    k = 4  # supersampling
    img = Image.new('L', (n * k, n * k), 0)
    d = ImageDraw.Draw(img)
    for x, y, size in THEMED_BLOCKS[:1] + THEMED_BLOCKS[1:]:
        d.rounded_rectangle(
            [(x + 6) * k, (y + 6) * k, (x + size - 6) * k, (y + size - 6) * k],
            radius=26 * k, fill=255)
    for x, y in THEMED_GRAINS:
        r = 13
        d.ellipse([(x - r) * k, (y - r) * k, (x + r) * k, (y + r) * k], fill=255)
    # Dune: a soft wave across the frame, filled to the bottom.
    pts = []
    for i in range(0, 61):
        x = 70 + (1184 - 70) * i / 60
        y = 820 - 55 * math.sin(math.pi * (x - 70) / (1184 - 70)) \
            + 18 * math.sin(4 * math.pi * (x - 70) / (1184 - 70))
        pts.append((x * k, y * k))
    pts += [(1184 * k, 1180 * k), (70 * k, 1180 * k)]
    d.polygon(pts, fill=255)
    img = img.resize((n, n), Image.LANCZOS)
    inside = Image.fromarray(((frame_sdf(n) < -60) * 255).astype(np.uint8), 'L')
    return Image.fromarray(np.minimum(np.asarray(img), np.asarray(inside)), 'L')


def write_png(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def mask_preview(fg, bg, mono):
    """The adaptive icon under four launcher masks at 48 and 108 px, and
    the themed version, for a visual check of the safe zone."""
    size = 216
    shapes = []
    for name in ('circle', 'squircle', 'rounded', 'teardrop'):
        m = Image.new('L', (size * 4, size * 4), 0)
        d = ImageDraw.Draw(m)
        s4 = size * 4
        if name == 'circle':
            d.ellipse([0, 0, s4 - 1, s4 - 1], fill=255)
        elif name == 'squircle':
            d.rounded_rectangle([0, 0, s4 - 1, s4 - 1], radius=s4 * 0.38, fill=255)
        elif name == 'rounded':
            d.rounded_rectangle([0, 0, s4 - 1, s4 - 1], radius=s4 * 0.16, fill=255)
        else:
            d.rounded_rectangle([0, 0, s4 - 1, s4 - 1], radius=s4 * 0.5, fill=255)
            d.rectangle([s4 // 2, s4 // 2, s4 - 1, s4 - 1], fill=255)
        shapes.append(m.resize((size, size), Image.LANCZOS))
    # The launcher shows the central 72 of the 108 dp layer.
    def visible(layer):
        px = layer.size[0]
        inset = round(px * 18 / 108)
        return layer.crop((inset, inset, px - inset, px - inset)).resize((size, size), Image.LANCZOS)
    full = bg.convert('RGBA')
    full.alpha_composite(fg)
    icon = visible(full)
    tile = Image.new('RGBA', mono.size, (36, 46, 96, 255))
    white = Image.new('RGBA', mono.size, (214, 224, 255, 255))
    tile.paste(white, (0, 0), mono.split()[3])
    themed = visible(tile)
    out = Image.new('RGBA', (size * 5 + 60, size * 2 + 40), (245, 246, 250, 255))
    for i, m in enumerate(shapes):
        for row, src in enumerate((icon, icon.resize((48, 48), Image.LANCZOS).resize((size, size), Image.NEAREST))):
            cell = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            cell.paste(src, (0, 0), m)
            out.alpha_composite(cell, (10 + i * (size + 10), 10 + row * (size + 20)))
    cell = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cell.paste(themed, (0, 0), shapes[0])
    out.alpha_composite(cell, (10 + 4 * (size + 10), 10))
    return out


def main():
    master = load_master()
    n = master.size[0]
    reach = frame_reach(n)
    art = cutout(master)
    top, bottom = surround_colors(master)
    mono = sand_mask(master)

    previews = {}
    for name, f in DENSITIES.items():
        mip = RES / f'mipmap-{name}'
        # Adaptive layers: 108 dp.
        px = round(ADAPTIVE_DP * f)
        art_px = round(artwork_dp(ADAPTIVE_DP, reach, n) * f)
        fg = place(art, px, art_px)
        bg = background_layer(px, top, bottom)
        write_png(fg, mip / 'ic_launcher_foreground.png')
        write_png(bg, mip / 'ic_launcher_background.png')
        mono_rgba = Image.new('RGBA', mono.size, (255, 255, 255, 0))
        mono_rgba.putalpha(mono)
        mono_layer = place(mono_rgba, px, art_px)
        write_png(mono_layer, mip / 'ic_launcher_monochrome.png')
        previews[name] = (fg, bg, mono_layer)

        # Legacy icons: 48 dp.
        legacy = round(48 * f)
        write_png(master.resize((legacy, legacy), Image.LANCZOS), mip / 'ic_launcher.png')
        round_icon = background_layer(legacy, top, bottom).convert('RGBA')
        # Frame corners at 46 % of the diameter from the centre: inside the circle.
        round_art = round(0.46 * legacy * n / reach)
        round_icon.alpha_composite(place(art, legacy, round_art))
        mask = Image.new('L', (legacy * 4, legacy * 4), 0)
        ImageDraw.Draw(mask).ellipse([0, 0, legacy * 4 - 1, legacy * 4 - 1], fill=255)
        round_icon.putalpha(mask.resize((legacy, legacy), Image.LANCZOS))
        write_png(round_icon, mip / 'ic_launcher_round.png')

        # Launch-screen mark (Android 7-11), 128 dp, on the window colour.
        splash = round(128 * f)
        write_png(place(art, splash, splash), RES / f'drawable-{name}' / 'splash_mark.png')

    # Google Play icon: exact 512 x 512, 32-bit RGBA, straight from the master.
    STORE.mkdir(exist_ok=True)
    play = master.resize((512, 512), Image.LANCZOS).convert('RGBA')
    write_png(play, STORE / 'icon-512.png')

    feature_graphic(art)
    fg, bg, mono_layer = previews['xxxhdpi']
    write_png(mask_preview(fg, bg, mono_layer), ROOT / 'tool/icon_source/preview-masks.png')
    print('Icons written from', SOURCE.relative_to(ROOT), f'(frame reach {reach:.1f} px)')


# Studio banner background, identical to Block Burst Magic's feature graphic
# so the two games look like one family on Google Play.
STUDIO_TOP = (4, 18, 109)
STUDIO_BOTTOM = (9, 9, 89)


def feature_graphic(art, top=STUDIO_TOP, bottom=STUDIO_BOTTOM):
    W, H = 2048, 1000
    grad = np.zeros((H, W, 3))
    t = np.linspace(0, 1, H)[:, None, None]
    grad[:] = np.array(top) * (1 - t) + np.array(bottom) * t
    bg = Image.fromarray(grad.astype(np.uint8), 'RGB').convert('RGBA')
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([60, 80, 900, 920], fill=(140, 92, 255, 70))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    icon = art.resize((820, 820), Image.LANCZOS)
    bg.alpha_composite(icon, (90, 90))
    d = ImageDraw.Draw(bg)
    # "Sand Burst" / "Magic" (gold, like the app's wordmark) / studio.
    bold = str(ROOT / 'assets/fonts/Outfit-ExtraBold.ttf')
    size = 200
    while ImageFont.truetype(bold, size).getlength('Sand Burst') > W - 980 - 70:
        size -= 4
    title = ImageFont.truetype(bold, size)
    sub = ImageFont.truetype(str(ROOT / 'assets/fonts/Outfit-Medium.ttf'), 80)
    y = 500 - (size * 2 + 120) // 2
    d.text((980, y), 'Sand Burst', font=title, fill=(243, 245, 255))
    d.text((980, y + size), 'Magic', font=title, fill=(246, 196, 83))
    d.text((988, y + size * 2 + 30), 'by Magivix Studio', font=sub,
           fill=(166, 176, 218))
    out = bg.resize((1024, 500), Image.LANCZOS).convert('RGB')
    write_png(out, STORE / 'feature-graphic-1024x500.png')


if __name__ == '__main__':
    main()
