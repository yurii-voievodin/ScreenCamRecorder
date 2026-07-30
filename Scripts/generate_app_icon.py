#!/usr/bin/env python3
"""Генерує AppIcon для ScreenCamRecorder: градієнт + вікно "робочого столу" +
кругла бульбашка з силуетом людини в правому нижньому куті (той самий мотив,
що й камера-оверлей у Compositor.swift).

Потребує Pillow: pip3 install pillow

Запуск: python3 Scripts/generate_app_icon.py
Пише PNG прямо в ScreenCamRecorder/Assets.xcassets/AppIcon.appiconset/
(Contents.json там уже містить відповідні "filename" — самі файли не чіпає).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SS = 4                        # supersample factor
BASE = 1024
S = BASE * SS                  # working canvas size

ICONSET_DIR = (
    Path(__file__).resolve().parent.parent
    / "ScreenCamRecorder" / "Assets.xcassets" / "AppIcon.appiconset"
)

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

BLUE = (56, 125, 246)
VIOLET = (109, 40, 217)
MID = tuple((b + v) // 2 for b, v in zip(BLUE, VIOLET))

CARD_FILL = (255, 255, 255, 235)
CARD_HEADER = (219, 227, 247, 235)
DOT_COLORS = [(255, 138, 128, 235), (255, 214, 92, 235), (120, 219, 143, 235)]
SILHOUETTE = (49, 46, 129, 255)  # indigo-900
SHADOW = (17, 17, 40, 110)


def diagonal_gradient(size, c_tl, c_br, c_mix):
    small = Image.new("RGB", (2, 2))
    small.putpixel((0, 0), c_tl)
    small.putpixel((1, 1), c_br)
    small.putpixel((1, 0), c_mix)
    small.putpixel((0, 1), c_mix)
    return small.resize((size, size), Image.BICUBIC)


def squircle_mask(size, corner_frac=0.2237):
    r = int(size * corner_frac)
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return mask


def make_bubble_patch(diameter, head_color, ring_color=None):
    patch = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    d = ImageDraw.Draw(patch)
    R = diameter / 2
    d.ellipse([0, 0, diameter, diameter], fill=(255, 255, 255, 255))

    # head
    head_r = R * 0.34
    head_cx, head_cy = R, R * 0.72
    d.ellipse(
        [head_cx - head_r, head_cy - head_r, head_cx + head_r, head_cy + head_r],
        fill=head_color,
    )

    # shoulders/torso — big circle placed low so the outer circular mask
    # clips it into the classic rounded-shoulder silhouette
    torso_r = R * 0.78
    torso_cx, torso_cy = R, diameter + torso_r * 0.18
    d.ellipse(
        [torso_cx - torso_r, torso_cy - torso_r, torso_cx + torso_r, torso_cy + torso_r],
        fill=head_color,
    )

    circle_mask = Image.new("L", (diameter, diameter), 0)
    ImageDraw.Draw(circle_mask).ellipse([0, 0, diameter, diameter], fill=255)
    patch.putalpha(circle_mask)
    # keep white bubble edge crisp, then re-draw a subtle ring border
    if ring_color:
        d2 = ImageDraw.Draw(patch)
        d2.ellipse([1, 1, diameter - 2, diameter - 2], outline=ring_color, width=max(1, diameter // 90))
    return patch


def build():
    grad = diagonal_gradient(S, BLUE, VIOLET, MID).convert("RGBA")
    layer = grad.copy()

    # --- desktop/window card ---
    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    card_x0, card_y0 = S * 0.13, S * 0.19
    card_x1, card_y1 = S * 0.82, S * 0.67
    card_r = S * 0.045
    od.rounded_rectangle([card_x0, card_y0, card_x1, card_y1], radius=card_r, fill=CARD_FILL)

    header_h = (card_y1 - card_y0) * 0.22
    od.rounded_rectangle(
        [card_x0, card_y0, card_x1, card_y0 + header_h],
        radius=card_r,
        fill=CARD_HEADER,
    )
    # square off the bottom corners of the header rectangle
    od.rectangle([card_x0, card_y0 + header_h - card_r, card_x1, card_y0 + header_h], fill=CARD_HEADER)

    dot_r = (card_y1 - card_y0) * 0.028
    dot_cy = card_y0 + header_h / 2
    dot_spacing = dot_r * 2.6
    dot_start_x = card_x0 + (card_y1 - card_y0) * 0.09
    for i, c in enumerate(DOT_COLORS):
        cx = dot_start_x + i * dot_spacing
        od.ellipse([cx - dot_r, dot_cy - dot_r, cx + dot_r, dot_cy + dot_r], fill=c)

    # a couple of soft content lines to read as "desktop content"
    line_color = (203, 213, 245, 180)
    line_y0 = card_y0 + header_h + (card_y1 - card_y0) * 0.16
    line_h = (card_y1 - card_y0) * 0.07
    for i, w in enumerate([0.55, 0.38]):
        ly = line_y0 + i * line_h * 2.1
        od.rounded_rectangle(
            [card_x0 + (card_y1 - card_y0) * 0.09, ly,
             card_x0 + (card_y1 - card_y0) * 0.09 + (card_x1 - card_x0) * w, ly + line_h],
            radius=line_h / 2,
            fill=line_color,
        )

    layer = Image.alpha_composite(layer, overlay)

    # --- camera bubble (person silhouette), bottom-right, overlapping the card ---
    bubble_d = int(S * 0.30)
    bubble_cx, bubble_cy = S * 0.705, S * 0.705

    shadow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    sr = bubble_d / 2 * 1.06
    sd.ellipse(
        [bubble_cx - sr, bubble_cy - sr + S * 0.012, bubble_cx + sr, bubble_cy + sr + S * 0.012],
        fill=SHADOW,
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(S * 0.012))
    layer = Image.alpha_composite(layer, shadow_layer)

    bubble = make_bubble_patch(bubble_d, SILHOUETTE, ring_color=(255, 255, 255, 90))
    px, py = int(bubble_cx - bubble_d / 2), int(bubble_cy - bubble_d / 2)
    layer.paste(bubble, (px, py), bubble)

    # --- clip everything to the macOS squircle ---
    mask = squircle_mask(S)
    final = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    final.paste(layer, (0, 0), mask)

    master = final.resize((BASE, BASE), Image.LANCZOS)
    return master


if __name__ == "__main__":
    master = build()
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)
    for filename, size in SIZES.items():
        master.resize((size, size), Image.LANCZOS).save(ICONSET_DIR / filename)
    print(f"Wrote {len(SIZES)} icon sizes to {ICONSET_DIR}")
