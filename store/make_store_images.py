#!/usr/bin/env python3
"""Generate Connect IQ store assets for OsMo Tracker."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
BLUE = (45, 130, 210)
NAVY = (11, 48, 82)
WHITE = (255, 255, 255)
SOFT = (186, 220, 245)
MUTED = (168, 196, 222)
ACCENT = (80, 170, 230)

BOLD = "/usr/share/fonts/TTF/FiraSans-Bold.ttf"
HEAVY = "/usr/share/fonts/TTF/FiraSans-Heavy.ttf"
REGULAR = "/usr/share/fonts/TTF/FiraSans-Book.ttf"
MEDIUM = "/usr/share/fonts/TTF/FiraSans-Medium.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def save_rgb(img: Image.Image, path: Path) -> None:
    rgb = img.convert("RGB")
    if path.suffix.lower() in {".jpg", ".jpeg"}:
        rgb.save(path, "JPEG", quality=90, optimize=True, subsampling=1)
    else:
        rgb.save(path, "PNG", optimize=True)
    print(f"{path.name}: {path.stat().st_size} bytes, {rgb.size}, mode={rgb.mode}")


def save_indexed_64(img: Image.Image, path: Path) -> None:
    """On-device store icon for MIP: 128x128 PNG, max 64 colors, no alpha."""
    rgb = img.convert("RGB")
    indexed = rgb.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    indexed.save(path, "PNG", optimize=True)
    colors = len(indexed.getcolors() or [])
    print(f"{path.name}: {path.stat().st_size} bytes, {indexed.size}, mode={indexed.mode}, colors={colors}")


def draw_mark(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int) -> None:
    """OsMo mark: blue disc with soft ring and 'Os' wordmark."""
    bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
    draw.ellipse(bbox, fill=BLUE)
    ring = radius - max(4, radius // 18)
    draw.ellipse(
        [cx - ring, cy - ring, cx + ring, cy + ring],
        outline=SOFT,
        width=max(2, radius // 40),
    )
    # All-caps OS — clearer than "Os" at small sizes (O≠0).
    label = "OS"
    size = max(16, int(radius * 0.78))
    t = font(HEAVY, size)
    draw.text((cx, cy + radius * 0.02), label, font=t, fill=WHITE, anchor="mm")


def make_device_icon() -> Image.Image:
    """On-device store icon 128x128 with ~10px padding (Garmin guideline)."""
    size = 128
    pad = 10
    img = Image.new("RGB", (size, size), NAVY)
    draw = ImageDraw.Draw(img)
    radius = (size - pad * 2) // 2
    draw_mark(draw, size // 2, size // 2, radius)
    return img


def make_cover() -> Image.Image:
    size = 500
    img = Image.new("RGB", (size, size), NAVY)
    draw = ImageDraw.Draw(img)
    pad = 10
    radius = (size - pad * 2) // 2
    draw_mark(draw, size // 2, size // 2, radius)
    return img


def track_points(w: int, h: int) -> list[tuple[int, int]]:
    return [
        (int(w * 0.64), int(h * 0.80)),
        (int(w * 0.70), int(h * 0.64)),
        (int(w * 0.76), int(h * 0.72)),
        (int(w * 0.82), int(h * 0.44)),
        (int(w * 0.89), int(h * 0.52)),
        (int(w * 0.95), int(h * 0.30)),
    ]


def make_hero(title: str, tagline: str, sub: str) -> Image.Image:
    w, h = 1440, 720
    img = Image.new("RGB", (w, h), NAVY)
    draw = ImageDraw.Draw(img)

    for i in range(h):
        t = i / (h - 1)
        r = int(NAVY[0] + (18 - NAVY[0]) * t * 0.25)
        g = int(NAVY[1] + (70 - NAVY[1]) * t * 0.15)
        b = int(NAVY[2] + (120 - NAVY[2]) * t * 0.12)
        draw.line([(0, i), (w, i)], fill=(r, g, b))

    # Soft glow behind mark
    glow_r = 175
    for k in range(6, 0, -1):
        a = 12
        rr = glow_r + k * 8
        # Approximate glow with darker navy rings (no alpha channel)
        draw.ellipse(
            [220 - rr, 360 - rr, 220 + rr, 360 + rr],
            outline=(NAVY[0] + a * k, NAVY[1] + a * k, NAVY[2] + a * k),
            width=3,
        )

    draw_mark(draw, 220, 360, 150)

    title_font = font(BOLD, 62)
    tag_font = font(MEDIUM, 38)
    sub_font = font(REGULAR, 30)
    x_text = 430
    draw.text((x_text, 235), title, font=title_font, fill=WHITE, anchor="ls")
    draw.text((x_text, 325), tagline, font=tag_font, fill=SOFT, anchor="ls")
    draw.text((x_text, 385), sub, font=sub_font, fill=MUTED, anchor="ls")

    # Version chip
    chip = "v2.3.20"
    chip_font = font(MEDIUM, 24)
    bbox = draw.textbbox((0, 0), chip, font=chip_font)
    cw = bbox[2] - bbox[0] + 28
    ch = bbox[3] - bbox[1] + 16
    cx0, cy0 = x_text, 445
    draw.rounded_rectangle([cx0, cy0, cx0 + cw, cy0 + ch], radius=10, fill=(20, 70, 110))
    draw.text((cx0 + cw // 2, cy0 + ch // 2), chip, font=chip_font, fill=ACCENT, anchor="mm")

    pts = track_points(w, h)
    draw.line(pts, fill=BLUE, width=8, joint="curve")
    for x, y in pts[:-1]:
        draw.ellipse([x - 8, y - 8, x + 8, y + 8], fill=WHITE)
    end = pts[-1]
    draw.ellipse([end[0] - 10, end[1] - 10, end[0] + 10, end[1] + 10], fill=WHITE)
    draw.ellipse([end[0] - 18, end[1] - 18, end[0] + 18, end[1] + 18], outline=SOFT, width=4)

    return img


def main() -> None:
    cover = make_cover()
    save_rgb(cover, ROOT / "cover-500x500.png")
    save_rgb(cover, ROOT / "cover-500x500.jpg")

    device_icon = make_device_icon()
    save_rgb(device_icon, ROOT / "icon-128x128-24bit.png")
    save_indexed_64(device_icon, ROOT / "icon-128x128-64color.png")

    hero_en = make_hero(
        "OsMo Tracker by Treyceya",
        "Live tracking for Traceya",
        "GPS status, sensors and FIT charts",
    )
    hero_ru = make_hero(
        "ОсМо Трекер от Трейсеи",
        "Онлайн-трекинг для Трейсеи",
        "Статус GPS, датчики и графики FIT",
    )
    save_rgb(hero_en, ROOT / "hero-1440x720-en.png")
    save_rgb(hero_ru, ROOT / "hero-1440x720-ru.png")
    save_rgb(hero_en, ROOT / "hero-1440x720-en.jpg")
    save_rgb(hero_ru, ROOT / "hero-1440x720-ru.jpg")


if __name__ == "__main__":
    main()
