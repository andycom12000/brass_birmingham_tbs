"""
generate_cards.py
Generates high-quality Victorian industrial-revolution-themed card PNG images
for the Brass: Birmingham TTS mod.
Output: assets/cards/
"""

import os
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "assets" / "cards"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Card dimensions (standard TTS card)
# ---------------------------------------------------------------------------
W, H = 409, 585
BORDER = 18
CORNER_R = 20

# ---------------------------------------------------------------------------
# Colour palette — dark Victorian industrial theme
# ---------------------------------------------------------------------------
BG_BASE         = (26,  16,  8)    # Dark warm brown #1A1008
FRAME_GOLD      = (201, 168, 76)   # Antique gold   #C9A84C
TEXT_CREAM      = (232, 213, 176)  # Parchment      #E8D5B0
TEXT_GOLD_MID   = (168, 144, 96)   # Muted gold     #A89060
TEXT_WHITE      = (255, 255, 255)

INDUSTRY_ACCENT = {
    "cotton":       (212, 197, 160),  # Parchment     #D4C5A0
    "coal":         (58,  58,  58),   # Charcoal      #3A3A3A
    "iron":         (184, 115, 51),   # Copper/bronze #B87333
    "brewery":      (212, 160, 23),   # Gold amber    #D4A017
    "manufacturer": (123, 79,  138),  # Royal purple  #7B4F8A
    "pottery":      (192, 101, 42),   # Terracotta    #C0652A
}

LOCATION_BORDER = {
    "standard": (139, 115, 85),   # Dark gold  #8B7355
    "teal":     (42,  139, 139),  # Teal       #2A8B8B
    "blue":     (59,  107, 155),  # Blue       #3B6B9B
}

WILD_BG     = (18,  28,  68)   # Dark navy
WILD_BORDER = (140, 110, 40)   # Gold

# ---------------------------------------------------------------------------
# City / industry data
# ---------------------------------------------------------------------------
LOCATION_REGIONS = {
    "teal":     ["Belper", "Derby"],
    "blue":     ["Leek", "Stoke-on-Trent", "Stone", "Uttoxeter"],
    "standard": [
        "Birmingham", "Coventry", "Dudley", "Kidderminster", "Wolverhampton",
        "Coalbrookdale", "Nuneaton", "Worcester", "Tamworth", "Walsall",
        "Cannock", "Burton-on-Trent", "Stafford", "Redditch",
    ],
}

CITY_INDUSTRIES = {
    "Birmingham":      ["Cotton", "Iron", "Manufacturer"],
    "Coventry":        ["Cotton", "Coal", "Iron", "Manufacturer", "Pottery"],
    "Dudley":          ["Coal", "Iron", "Brewery"],
    "Kidderminster":   ["Cotton", "Manufacturer"],
    "Wolverhampton":   ["Coal", "Iron", "Manufacturer"],
    "Coalbrookdale":   ["Iron", "Brewery"],
    "Nuneaton":        ["Coal", "Manufacturer"],
    "Worcester":       ["Cotton", "Brewery"],
    "Tamworth":        ["Cotton", "Coal"],
    "Walsall":         ["Cotton", "Manufacturer"],
    "Cannock":         ["Coal", "Manufacturer"],
    "Burton-on-Trent": ["Coal", "Brewery"],
    "Stafford":        ["Cotton", "Pottery"],
    "Stoke-on-Trent":  ["Cotton", "Manufacturer", "Pottery"],
    "Leek":            ["Cotton", "Manufacturer"],
    "Stone":           ["Cotton", "Brewery"],
    "Uttoxeter":       ["Cotton", "Manufacturer"],
    "Belper":          ["Cotton", "Iron", "Manufacturer"],
    "Derby":           ["Cotton", "Iron", "Manufacturer"],
    "Redditch":        ["Coal", "Manufacturer", "Pottery"],
}

INDUSTRY_LIST = ["Cotton Mill", "Coal Mine", "Iron Works", "Brewery", "Manufacturer", "Pottery"]

WILD_CARDS = [
    {"label": "WILD", "sub": "Any Location",  "sub_zh": "任意地點", "key": "wild_location"},
    {"label": "WILD", "sub": "Any Industry",  "sub_zh": "任意產業", "key": "wild_industry"},
]

CITY_NAMES_ZH = {
    "Birmingham":      "伯明翰",
    "Coventry":        "考文垂",
    "Dudley":          "達德利",
    "Kidderminster":   "基德明斯特",
    "Wolverhampton":   "伍爾弗漢普頓",
    "Coalbrookdale":   "煤溪谷",
    "Nuneaton":        "納尼頓",
    "Worcester":       "伍斯特",
    "Tamworth":        "塔姆沃思",
    "Walsall":         "沃爾索爾",
    "Cannock":         "坎諾克",
    "Burton-on-Trent": "特倫特河畔伯頓",
    "Stafford":        "斯塔福德",
    "Stoke-on-Trent":  "特倫特河畔斯托克",
    "Leek":            "利克",
    "Stone":           "斯通",
    "Uttoxeter":       "厄托克塞特",
    "Belper":          "貝爾珀",
    "Derby":           "德比",
    "Redditch":        "雷迪奇",
}

INDUSTRY_NAMES_ZH = {
    "Cotton Mill":  "棉花廠",
    "Coal Mine":    "煤礦",
    "Iron Works":   "鐵工廠",
    "Brewery":      "釀酒廠",
    "Manufacturer": "製造廠",
    "Pottery":      "陶瓷廠",
}

# Industry icons (Unicode) and colours for the industry dots on location cards
INDUSTRY_ICON = {
    "Cotton":       ("◈", (212, 197, 160)),
    "Coal":         ("⬤", (90,  90,  90)),
    "Iron":         ("◆", (184, 115, 51)),
    "Brewery":      ("⬟", (212, 160, 23)),
    "Manufacturer": ("■", (123, 79,  138)),
    "Pottery":      ("◉", (192, 101, 42)),
}

INDUSTRY_FLAVOUR = {
    "Cotton Mill":  "Sell cotton to distant markets",
    "Coal Mine":    "Fuel the industrial revolution",
    "Iron Works":   "Forge the tools of progress",
    "Brewery":      "Provide beer for building links",
    "Manufacturer": "Manufacture consumer goods",
    "Pottery":      "Craft fine Staffordshire ware",
}

INDUSTRY_BIG_ICON = {
    "Cotton Mill":  "◈",
    "Coal Mine":    "⬤",
    "Iron Works":   "◆",
    "Brewery":      "⬟",
    "Manufacturer": "■",
    "Pottery":      "◉",
}

# ---------------------------------------------------------------------------
# Font helpers
# ---------------------------------------------------------------------------
_font_cache: dict = {}

def load_font(size: int, bold: bool = False, serif: bool = False) -> ImageFont.FreeTypeFont:
    key = (size, bold, serif)
    if key in _font_cache:
        return _font_cache[key]

    if serif:
        serif_bold = ["C:/Windows/Fonts/georgiab.ttf", "C:/Windows/Fonts/timesbd.ttf"]
        serif_reg  = ["C:/Windows/Fonts/georgia.ttf",  "C:/Windows/Fonts/times.ttf"]
        candidates = serif_bold if bold else serif_reg
    else:
        candidates = (
            ["C:/Windows/Fonts/arialbd.ttf",   "C:/Windows/Fonts/calibrib.ttf"]
            if bold else
            ["C:/Windows/Fonts/arial.ttf",     "C:/Windows/Fonts/calibri.ttf"]
        )
    # Fallback
    candidates += [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            font = ImageFont.truetype(path, size)
            _font_cache[key] = font
            return font
    font = ImageFont.load_default()
    _font_cache[key] = font
    return font


def load_cjk_font(size: int) -> ImageFont.FreeTypeFont:
    key = ("cjk", size)
    if key in _font_cache:
        return _font_cache[key]
    candidates = [
        "C:/Windows/Fonts/msjh.ttc",       # Microsoft JhengHei
        "C:/Windows/Fonts/msjhbd.ttc",
        "C:/Windows/Fonts/mingliu.ttc",    # PMingLiU
        "C:/Windows/Fonts/msgothic.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                font = ImageFont.truetype(path, size)
                _font_cache[key] = font
                return font
            except Exception:
                continue
    return load_font(size)


# ---------------------------------------------------------------------------
# Low-level drawing helpers
# ---------------------------------------------------------------------------
def lerp_color(c1, c2, t):
    """Linear interpolation between two RGB tuples."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_vertical_gradient(img: Image.Image, x0: int, y0: int, x1: int, y1: int,
                           top_color, bottom_color):
    """Fill a rectangle with a vertical gradient."""
    draw = ImageDraw.Draw(img)
    height = y1 - y0
    if height <= 0:
        return
    for y in range(y0, y1 + 1):
        t = (y - y0) / height
        color = lerp_color(top_color, bottom_color, t)
        draw.line([(x0, y), (x1, y)], fill=color)


def add_noise_texture(img: Image.Image, intensity: float = 0.06) -> Image.Image:
    """Blend a subtle noise layer onto the image to simulate aged paper/metal."""
    rng = random.Random(42)
    noise = Image.new("RGB", img.size)
    pixels = noise.load()
    for y in range(img.height):
        for x in range(img.width):
            v = int(rng.gauss(128, 30))
            v = max(0, min(255, v))
            pixels[x, y] = (v, v, v)
    noise = noise.filter(ImageFilter.GaussianBlur(radius=0.5))
    blended = ImageChops.blend(img, noise, intensity)
    return blended


def text_size(draw: ImageDraw.ImageDraw, text: str, font) -> tuple[int, int]:
    bb = draw.textbbox((0, 0), text, font=font)
    return bb[2] - bb[0], bb[3] - bb[1]


def center_text(draw: ImageDraw.ImageDraw, cx: int, cy: int,
                text: str, font, fill, stroke_fill=None, stroke_width: int = 0):
    w, h = text_size(draw, text, font)
    x = cx - w // 2
    y = cy - h // 2
    if stroke_fill and stroke_width > 0:
        draw.text((x, y), text, font=font, fill=stroke_fill,
                  stroke_width=stroke_width, stroke_fill=stroke_fill)
    draw.text((x, y), text, font=font, fill=fill)


def draw_rounded_rect(draw: ImageDraw.ImageDraw, xy, radius: int,
                      fill=None, outline=None, width: int = 1):
    draw.rounded_rectangle(list(xy), radius=radius, fill=fill,
                           outline=outline, width=width)


def draw_decorative_divider(draw: ImageDraw.ImageDraw, y: int, color,
                            margin: int = 36, label: str = ""):
    """Ornate divider line with optional centred label."""
    cx = W // 2
    lw = 1
    draw.line([(margin, y), (W - margin, y)], fill=color, width=lw)
    # Small diamond at each end
    d = 4
    for x in (margin, W - margin):
        draw.polygon([(x, y - d), (x + d, y), (x, y + d), (x - d, y)], fill=color)
    if label:
        f = load_font(13, bold=False, serif=True)
        tw, th = text_size(draw, label, f)
        gap = 8
        # Erase line under text
        draw.line([(cx - tw // 2 - gap, y), (cx + tw // 2 + gap, y)],
                  fill=None)
        draw.text((cx - tw // 2, y - th // 2), label, font=f, fill=color)


def draw_corner_flourishes(draw: ImageDraw.ImageDraw, color, margin: int = 14,
                           size: int = 22, lw: int = 2):
    """Draw simple geometric corner decorations inside the card border."""
    corners = [
        (margin, margin),
        (W - margin, margin),
        (margin, H - margin),
        (W - margin, H - margin),
    ]
    signs = [(1, 1), (-1, 1), (1, -1), (-1, -1)]
    for (cx, cy), (sx, sy) in zip(corners, signs):
        # L-shaped lines
        draw.line([(cx, cy), (cx + sx * size, cy)], fill=color, width=lw)
        draw.line([(cx, cy), (cx, cy + sy * size)], fill=color, width=lw)
        # Small square dot at corner
        dot = 3
        draw.rectangle([(cx - dot, cy - dot), (cx + dot, cy + dot)], fill=color)


def draw_double_border(draw: ImageDraw.ImageDraw, color_outer, color_inner,
                       gap: int = 5):
    """Draw a double-line card border for extra elegance."""
    # Outer border
    draw_rounded_rect(draw, (2, 2, W - 3, H - 3), CORNER_R,
                      fill=None, outline=color_outer, width=3)
    # Inner border
    off = gap + 3
    draw_rounded_rect(draw, (off, off, W - off - 1, H - off - 1),
                      max(4, CORNER_R - 6),
                      fill=None, outline=color_inner, width=1)


# ---------------------------------------------------------------------------
# Card background builders
# ---------------------------------------------------------------------------
def make_dark_base() -> Image.Image:
    """Create a dark warm brown gradient background with subtle noise."""
    img = Image.new("RGB", (W, H), BG_BASE)
    # Subtle vertical gradient: slightly lighter at centre
    top_col    = (32, 20, 10)
    bottom_col = (20, 12, 5)
    draw_vertical_gradient(img, 0, 0, W, H, top_col, bottom_col)
    img = add_noise_texture(img, intensity=0.05)
    return img


def make_industry_base(accent: tuple) -> Image.Image:
    """Dark base with a subtle glow of the industry accent colour."""
    img = make_dark_base()
    # Blend a faint accent rectangle in the upper half
    overlay = Image.new("RGB", (W, H), (0, 0, 0))
    ov_draw = ImageDraw.Draw(overlay)
    r, g, b = accent
    # Very faint centre glow
    ov_draw.ellipse([(W // 4, 60), (3 * W // 4, H // 2)],
                    fill=(r // 6, g // 6, b // 6))
    img = ImageChops.add(img, overlay)
    img = add_noise_texture(img, intensity=0.04)
    return img


# ---------------------------------------------------------------------------
# Location card
# ---------------------------------------------------------------------------
def make_location_card(city: str) -> Image.Image:
    # Determine region border colour
    region_key = "standard"
    for rk, cities in LOCATION_REGIONS.items():
        if city in cities:
            region_key = rk
            break
    border_color = LOCATION_BORDER[region_key]

    img = make_dark_base()
    draw = ImageDraw.Draw(img)

    # --- Outer double border ---
    gold_dim = lerp_color(FRAME_GOLD, (80, 60, 20), 0.5)
    draw_double_border(draw, FRAME_GOLD, gold_dim, gap=5)

    # --- Corner flourishes in border colour ---
    draw_corner_flourishes(draw, border_color, margin=16, size=18, lw=2)

    # --- Top label banner ---
    banner_top    = 30
    banner_bottom = 68
    bcolor_dark = lerp_color(border_color, (0, 0, 0), 0.55)
    draw_vertical_gradient(img, BORDER + 4, banner_top, W - BORDER - 5, banner_bottom,
                           border_color, bcolor_dark)
    draw = ImageDraw.Draw(img)
    f_label = load_font(15, bold=True)
    center_text(draw, W // 2, (banner_top + banner_bottom) // 2,
                "L O C A T I O N", f_label, TEXT_CREAM)

    # --- City name banner (accent colour background) ---
    name_banner_top = 84
    name_banner_bot = 200
    nb_dark = lerp_color(border_color, (0, 0, 0), 0.65)
    draw_vertical_gradient(img, BORDER + 4, name_banner_top,
                           W - BORDER - 5, name_banner_bot,
                           nb_dark, lerp_color(nb_dark, BG_BASE, 0.6))
    draw = ImageDraw.Draw(img)

    # Thin rule lines above/below city banner
    draw.line([(BORDER + 4, name_banner_top),     (W - BORDER - 5, name_banner_top)],
              fill=border_color, width=1)
    draw.line([(BORDER + 4, name_banner_bot),     (W - BORDER - 5, name_banner_bot)],
              fill=border_color, width=1)

    # City name — serif, large
    cx = W // 2
    f_city_big  = load_font(36, bold=True, serif=True)
    f_city_med  = load_font(28, bold=True, serif=True)
    f_city_sml  = load_font(22, bold=True, serif=True)

    city_upper = city.upper()
    tw, _ = text_size(draw, city_upper, f_city_big)
    if tw > W - 60:
        tw, _ = text_size(draw, city_upper, f_city_med)
        font_city = f_city_med if tw <= W - 60 else f_city_sml
    else:
        font_city = f_city_big

    city_cy = (name_banner_top + name_banner_bot) // 2 - 14
    center_text(draw, cx, city_cy, city_upper, font_city,
                fill=TEXT_CREAM,
                stroke_fill=lerp_color(border_color, (0, 0, 0), 0.6),
                stroke_width=2)

    # Chinese name
    zh_name = CITY_NAMES_ZH.get(city, "")
    if zh_name:
        f_zh = load_cjk_font(18)
        center_text(draw, cx, city_cy + 36, zh_name, f_zh, TEXT_GOLD_MID)

    # --- Decorative divider ---
    div_y = 216
    draw_decorative_divider(draw, div_y, border_color, margin=30)

    # --- Industries section ---
    f_section = load_font(13, bold=True)
    f_ind     = load_font(14, bold=False, serif=True)
    f_icon    = load_font(14)

    draw.text((38, 228), "AVAILABLE INDUSTRIES", font=f_section, fill=TEXT_GOLD_MID)

    industries = CITY_INDUSTRIES.get(city, [])
    # Lay out in two columns if more than 3
    col_items = 3
    y_start = 252
    row_h   = 28

    for i, ind in enumerate(industries):
        col = i // col_items
        row = i % col_items
        ix  = 44 + col * 190
        iy  = y_start + row * row_h

        icon_char, icon_color = INDUSTRY_ICON.get(ind, ("•", TEXT_GOLD_MID))
        # Icon dot
        try:
            draw.text((ix, iy - 1), icon_char, font=f_icon, fill=icon_color)
        except Exception:
            draw.ellipse([(ix, iy + 2), (ix + 10, iy + 12)], fill=icon_color)

        # Industry name
        draw.text((ix + 20, iy), ind, font=f_ind, fill=TEXT_CREAM)

    # --- Horizontal rule before bottom bar ---
    rule_y = H - 72
    draw.line([(BORDER + 4, rule_y), (W - BORDER - 5, rule_y)],
              fill=gold_dim, width=1)

    # --- Bottom bar ---
    bar_top = H - 68
    bar_bot = H - BORDER - 2
    draw_vertical_gradient(img, BORDER + 4, bar_top, W - BORDER - 5, bar_bot,
                           bcolor_dark, border_color)
    draw = ImageDraw.Draw(img)
    f_footer = load_font(13, bold=True)
    center_text(draw, cx, (bar_top + bar_bot) // 2,
                "— BRASS: BIRMINGHAM —", f_footer, TEXT_CREAM)

    # Final noise pass
    img = add_noise_texture(img, intensity=0.03)
    return img


# ---------------------------------------------------------------------------
# Industry card
# ---------------------------------------------------------------------------
def _industry_key(name: str) -> str:
    return {
        "Cotton Mill":  "cotton",
        "Coal Mine":    "coal",
        "Iron Works":   "iron",
        "Brewery":      "brewery",
        "Manufacturer": "manufacturer",
        "Pottery":      "pottery",
    }.get(name, "cotton")


def make_industry_card(industry_name: str) -> Image.Image:
    key    = _industry_key(industry_name)
    accent = INDUSTRY_ACCENT[key]

    img = make_industry_base(accent)
    draw = ImageDraw.Draw(img)

    gold_dim = lerp_color(FRAME_GOLD, (80, 60, 20), 0.5)
    draw_double_border(draw, FRAME_GOLD, gold_dim, gap=5)

    # Corner flourishes in accent colour
    draw_corner_flourishes(draw, accent, margin=16, size=18, lw=2)

    cx = W // 2

    # --- Top label banner ---
    banner_top    = 30
    banner_bottom = 68
    acc_dark = lerp_color(accent, (0, 0, 0), 0.60)
    draw_vertical_gradient(img, BORDER + 4, banner_top, W - BORDER - 5, banner_bottom,
                           acc_dark, lerp_color(acc_dark, BG_BASE, 0.5))
    draw = ImageDraw.Draw(img)
    f_label = load_font(15, bold=True)
    center_text(draw, cx, (banner_top + banner_bottom) // 2,
                "I N D U S T R Y", f_label, TEXT_CREAM)

    # --- Big icon in centre top ---
    icon_char = INDUSTRY_BIG_ICON.get(industry_name, "◆")
    f_icon_big = load_font(54)
    icon_y = 118
    # Shadow
    center_text(draw, cx + 2, icon_y + 2, icon_char, f_icon_big,
                fill=lerp_color(accent, (0, 0, 0), 0.7))
    # Main icon
    center_text(draw, cx, icon_y, icon_char, f_icon_big, fill=accent)

    # --- Accent rule under icon ---
    rule_top = 158
    draw.line([(BORDER + 30, rule_top), (W - BORDER - 30, rule_top)],
              fill=accent, width=1)

    # --- Industry name ---
    f_name_big = load_font(38, bold=True, serif=True)
    f_name_med = load_font(30, bold=True, serif=True)
    f_name_sml = load_font(24, bold=True, serif=True)

    name_upper = industry_name.upper()
    tw, _ = text_size(draw, name_upper, f_name_big)
    if tw > W - 60:
        tw, _ = text_size(draw, name_upper, f_name_med)
        font_name = f_name_med if tw <= W - 60 else f_name_sml
    else:
        font_name = f_name_big

    name_cy = 196
    center_text(draw, cx, name_cy, name_upper, font_name,
                fill=TEXT_CREAM,
                stroke_fill=lerp_color(accent, (0, 0, 0), 0.7),
                stroke_width=2)

    # Chinese name
    zh_name = INDUSTRY_NAMES_ZH.get(industry_name, "")
    if zh_name:
        f_zh = load_cjk_font(20)
        center_text(draw, cx, name_cy + 38, zh_name, f_zh, TEXT_GOLD_MID)

    # --- Decorative divider ---
    div_y = 252
    draw_decorative_divider(draw, div_y, accent, margin=30)

    # --- Flavour text ---
    flavour = INDUSTRY_FLAVOUR.get(industry_name, "")
    f_flavour = load_font(15, bold=False, serif=True)
    if flavour:
        # Word-wrap into max 2 lines
        words = flavour.split()
        lines = []
        current = ""
        for w in words:
            test = (current + " " + w).strip()
            tw2, _ = text_size(draw, test, f_flavour)
            if tw2 <= W - 80:
                current = test
            else:
                if current:
                    lines.append(current)
                current = w
        if current:
            lines.append(current)

        line_h = 22
        total_h = line_h * len(lines)
        y_fl = 276 - total_h // 2
        for line in lines:
            tw_l, _ = text_size(draw, line, f_flavour)
            draw.text(((W - tw_l) // 2, y_fl), line, font=f_flavour, fill=TEXT_GOLD_MID)
            y_fl += line_h

    # --- Decorative divider 2 ---
    div2_y = 318
    draw_decorative_divider(draw, div2_y, gold_dim, margin=40)

    # --- Attributes section (era slots placeholder) ---
    f_attr = load_font(13, bold=False, serif=True)
    attrs_y = 334
    center_text(draw, cx, attrs_y,
                "Canal Era  ·  Rail Era",
                f_attr, TEXT_GOLD_MID)

    # Draw 5 small pip slots to suggest tech levels
    pip_y = attrs_y + 24
    pip_r = 5
    pip_gap = 18
    pip_count = 5
    pip_x0 = cx - ((pip_count - 1) * pip_gap) // 2
    for i in range(pip_count):
        px = pip_x0 + i * pip_gap
        fill_col = accent if i < 2 else lerp_color(accent, BG_BASE, 0.65)
        draw.ellipse([(px - pip_r, pip_y - pip_r), (px + pip_r, pip_y + pip_r)],
                     fill=fill_col, outline=gold_dim, width=1)

    # --- Resource cost row ---
    cost_y = pip_y + 28
    f_cost_label = load_font(12, bold=True)
    f_cost_val   = load_font(16, bold=True, serif=True)
    cost_items = [("COAL", "2"), ("IRON", "1"), ("BEER", "0")]
    col_w = (W - 2 * 40) // len(cost_items)
    for ci, (cname, cval) in enumerate(cost_items):
        col_cx = 40 + ci * col_w + col_w // 2
        draw.text(
            (col_cx - text_size(draw, cname, f_cost_label)[0] // 2, cost_y),
            cname, font=f_cost_label, fill=TEXT_GOLD_MID,
        )
        draw.text(
            (col_cx - text_size(draw, cval, f_cost_val)[0] // 2, cost_y + 16),
            cval, font=f_cost_val, fill=TEXT_CREAM,
        )

    # --- Horizontal rule before bottom bar ---
    rule_y2 = H - 72
    draw.line([(BORDER + 4, rule_y2), (W - BORDER - 5, rule_y2)],
              fill=gold_dim, width=1)

    # --- Bottom bar ---
    bar_top = H - 68
    bar_bot = H - BORDER - 2
    draw_vertical_gradient(img, BORDER + 4, bar_top, W - BORDER - 5, bar_bot,
                           lerp_color(accent, (0, 0, 0), 0.6),
                           lerp_color(accent, (0, 0, 0), 0.3))
    draw = ImageDraw.Draw(img)
    f_footer = load_font(13, bold=True)
    center_text(draw, cx, (bar_top + bar_bot) // 2,
                "— BRASS: BIRMINGHAM —", f_footer, TEXT_CREAM)

    img = add_noise_texture(img, intensity=0.03)
    return img


# ---------------------------------------------------------------------------
# Wild card
# ---------------------------------------------------------------------------
def make_wild_card(label: str, sub: str, sub_zh: str) -> Image.Image:
    # Deep navy gradient base
    img = Image.new("RGB", (W, H), WILD_BG)
    top_col = (28, 42, 100)
    bot_col = (10, 16, 50)
    draw_vertical_gradient(img, 0, 0, W, H, top_col, bot_col)
    img = add_noise_texture(img, intensity=0.05)
    draw = ImageDraw.Draw(img)

    gold_dim = lerp_color(WILD_BORDER, (40, 30, 10), 0.5)
    draw_double_border(draw, WILD_BORDER, gold_dim, gap=5)
    draw_corner_flourishes(draw, WILD_BORDER, margin=16, size=22, lw=2)

    cx = W // 2

    # --- Star row top ---
    f_star = load_font(18)
    center_text(draw, cx, 52, "★   ★   ★   ★   ★", f_star, WILD_BORDER)

    # --- "WILD" in huge serif ---
    f_wild = load_font(72, bold=True, serif=True)
    # Gold drop shadow
    center_text(draw, cx + 3, 158 + 3, label, f_wild,
                fill=lerp_color(WILD_BORDER, (0, 0, 0), 0.7))
    # Gold gradient approximation: single gold tone
    center_text(draw, cx, 158, label, f_wild, fill=WILD_BORDER)

    # Thin rule under WILD
    rule_y = 208
    draw.line([(BORDER + 30, rule_y), (W - BORDER - 30, rule_y)],
              fill=gold_dim, width=1)

    # Sub label (e.g. "Any Location") with decorative bars
    f_sub = load_font(26, bold=True, serif=True)
    sub_y = 240
    center_text(draw, cx, sub_y, sub.upper(), f_sub, fill=TEXT_CREAM)

    # Chinese subtitle
    if sub_zh:
        f_zh = load_cjk_font(20)
        center_text(draw, cx, sub_y + 34, sub_zh, f_zh, fill=TEXT_GOLD_MID)

    # --- Decorative divider ---
    draw_decorative_divider(draw, 302, WILD_BORDER, margin=40)

    # --- Flavour text ---
    if "Location" in sub:
        flavour_en = "May be played as any location"
        flavour_zh = "可作任意地點使用"
    else:
        flavour_en = "May be played as any industry"
        flavour_zh = "可作任意產業使用"

    f_fl  = load_font(15, bold=False, serif=True)
    f_flz = load_cjk_font(15)
    center_text(draw, cx, 324, flavour_en, f_fl, fill=TEXT_GOLD_MID)
    center_text(draw, cx, 348, flavour_zh, f_flz, fill=TEXT_GOLD_MID)

    # --- Crown / ornament ---
    f_crown = load_font(32)
    center_text(draw, cx, 400, "♛", f_crown, fill=WILD_BORDER)

    # --- Star row bottom ---
    center_text(draw, cx, H - 90, "★   ★   ★   ★   ★", f_star, WILD_BORDER)

    # --- Bottom bar ---
    bar_top = H - 68
    bar_bot = H - BORDER - 2
    draw_vertical_gradient(img, BORDER + 4, bar_top, W - BORDER - 5, bar_bot,
                           lerp_color(WILD_BORDER, (0, 0, 0), 0.65),
                           lerp_color(WILD_BORDER, (0, 0, 0), 0.35))
    draw = ImageDraw.Draw(img)
    f_footer = load_font(13, bold=True)
    center_text(draw, cx, (bar_top + bar_bot) // 2,
                "— BRASS: BIRMINGHAM —", f_footer, TEXT_CREAM)

    img = add_noise_texture(img, intensity=0.03)
    return img


# ---------------------------------------------------------------------------
# Card back
# ---------------------------------------------------------------------------
def make_card_back() -> Image.Image:
    # Rich dark brown gradient
    img = Image.new("RGB", (W, H), (40, 24, 10))
    draw_vertical_gradient(img, 0, 0, W, H, (55, 33, 14), (22, 13, 5))
    img = add_noise_texture(img, intensity=0.07)
    draw = ImageDraw.Draw(img)

    gold_dim = lerp_color(FRAME_GOLD, (80, 60, 20), 0.5)

    # Outer gold border
    draw.rounded_rectangle([2, 2, W - 3, H - 3], radius=CORNER_R,
                            outline=FRAME_GOLD, width=3)
    # Second gold line
    draw.rounded_rectangle([8, 8, W - 9, H - 9], radius=CORNER_R - 4,
                            outline=gold_dim, width=1)
    # Inner thin border
    draw.rounded_rectangle([20, 20, W - 21, H - 21], radius=CORNER_R - 10,
                            outline=gold_dim, width=1)

    # Corner geometric flourishes
    draw_corner_flourishes(draw, FRAME_GOLD, margin=24, size=26, lw=2)

    cx, cy = W // 2, H // 2

    # Horizontal rule lines
    for ry in (cy - 110, cy + 110):
        draw.line([(40, ry), (W - 40, ry)], fill=gold_dim, width=1)

    # Decorative diamond row above title
    f_dmd = load_font(14)
    center_text(draw, cx, cy - 90, "◆  ◆  ◆", f_dmd, fill=FRAME_GOLD)

    # "BRASS" — huge serif
    f_brass  = load_font(80, bold=True, serif=True)
    # Shadow
    center_text(draw, cx + 3, cy - 28 + 3, "BRASS", f_brass,
                fill=lerp_color(FRAME_GOLD, (0, 0, 0), 0.75))
    center_text(draw, cx, cy - 28, "BRASS", f_brass, fill=FRAME_GOLD)

    # "BIRMINGHAM" — smaller serif
    f_birm = load_font(30, bold=True, serif=True)
    center_text(draw, cx + 2, cy + 50 + 2, "BIRMINGHAM", f_birm,
                fill=lerp_color(FRAME_GOLD, (0, 0, 0), 0.7))
    center_text(draw, cx, cy + 50, "BIRMINGHAM", f_birm, fill=TEXT_CREAM)

    # Decorative diamonds below
    center_text(draw, cx, cy + 90, "◆  ◆  ◆", f_dmd, fill=FRAME_GOLD)

    # Subtitle / edition note
    f_ed = load_font(13, bold=False, serif=True)
    center_text(draw, cx, cy + 124, "TABLETOP SIMULATOR EDITION", f_ed,
                fill=TEXT_GOLD_MID)

    img = add_noise_texture(img, intensity=0.04)
    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    total = 0

    # Gather all cities in a stable order
    all_cities: list[str] = []
    for cities in LOCATION_REGIONS.values():
        all_cities.extend(cities)

    print(f"Generating {len(all_cities)} location cards...")
    for city in all_cities:
        img = make_location_card(city)
        fname = city.lower().replace(" ", "_").replace("-", "_") + "_location.png"
        img.save(OUT_DIR / fname)
        print(f"  Saved {fname}")
        total += 1

    print(f"\nGenerating {len(INDUSTRY_LIST)} industry cards...")
    for name in INDUSTRY_LIST:
        img = make_industry_card(name)
        fname = name.lower().replace(" ", "_") + ".png"
        img.save(OUT_DIR / fname)
        print(f"  Saved {fname}")
        total += 1

    print("\nGenerating 2 wild cards...")
    for card in WILD_CARDS:
        img = make_wild_card(card["label"], card["sub"], card["sub_zh"])
        img.save(OUT_DIR / f"{card['key']}.png")
        print(f"  Saved {card['key']}.png")
        total += 1

    print("\nGenerating card back...")
    img = make_card_back()
    img.save(OUT_DIR / "card_back.png")
    print("  Saved card_back.png")
    total += 1

    print(f"\nDone. {total} card images written to {OUT_DIR}")


if __name__ == "__main__":
    main()
