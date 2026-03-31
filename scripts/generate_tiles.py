"""
generate_tiles.py
Generates visually polished Victorian-industrial building tile PNG images
for the Brass: Birmingham TTS mod prototype.
Output: assets/tiles/
Naming: {industry}_lv{level}_front.png  /  {industry}_lv{level}_back.png
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "assets" / "tiles"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Tile dimensions
# ---------------------------------------------------------------------------
W = H = 200          # square tiles for TTS Custom Tile
BORDER_W = 3         # accent border width
CORNER_R = 12        # rounded corner radius
PAD = 6              # inner padding

# ---------------------------------------------------------------------------
# Tile data from the game
# ---------------------------------------------------------------------------
TILE_DATA = {
    "cotton": [
        {"level": 1, "money": 12, "coal": 0, "iron": 0, "vp": 5,  "income": 5, "links": 1, "beer_sell": 1},
        {"level": 2, "money": 14, "coal": 1, "iron": 0, "vp": 5,  "income": 4, "links": 2, "beer_sell": 1},
        {"level": 3, "money": 16, "coal": 1, "iron": 1, "vp": 9,  "income": 3, "links": 1, "beer_sell": 1},
        {"level": 4, "money": 18, "coal": 1, "iron": 1, "vp": 12, "income": 2, "links": 1, "beer_sell": 1},
    ],
    "coal": [
        {"level": 1, "money": 5,  "coal": 0, "iron": 0, "vp": 1, "income": 4, "links": 2, "produces": 2},
        {"level": 2, "money": 7,  "coal": 0, "iron": 0, "vp": 2, "income": 7, "links": 1, "produces": 3},
        {"level": 3, "money": 8,  "coal": 0, "iron": 1, "vp": 3, "income": 6, "links": 1, "produces": 4},
        {"level": 4, "money": 10, "coal": 0, "iron": 1, "vp": 4, "income": 5, "links": 1, "produces": 5},
    ],
    "iron": [
        {"level": 1, "money": 5,  "coal": 1, "iron": 0, "vp": 3, "income": 3, "links": 1, "produces": 4},
        {"level": 2, "money": 7,  "coal": 1, "iron": 0, "vp": 5, "income": 3, "links": 1, "produces": 4},
        {"level": 3, "money": 9,  "coal": 1, "iron": 0, "vp": 7, "income": 2, "links": 1, "produces": 5},
        {"level": 4, "money": 12, "coal": 1, "iron": 0, "vp": 9, "income": 1, "links": 1, "produces": 6},
    ],
    "brewery": [
        {"level": 1, "money": 5, "coal": 0, "iron": 1, "vp": 4,  "income": 4, "links": 2, "produces": 1},
        {"level": 2, "money": 7, "coal": 0, "iron": 1, "vp": 5,  "income": 5, "links": 2, "produces": 1},
        {"level": 3, "money": 9, "coal": 0, "iron": 1, "vp": 7,  "income": 5, "links": 2, "produces": 1},
        {"level": 4, "money": 9, "coal": 0, "iron": 1, "vp": 10, "income": 5, "links": 2, "produces": 2, "rail_only": True},
    ],
    "manufacturer": [
        {"level": 1, "money": 8,  "coal": 1, "iron": 0, "vp": 3,  "income": 5, "links": 2, "beer_sell": 1},
        {"level": 2, "money": 10, "coal": 0, "iron": 1, "vp": 5,  "income": 1, "links": 1, "beer_sell": 1},
        {"level": 3, "money": 12, "coal": 2, "iron": 0, "vp": 4,  "income": 4, "links": 0, "beer_sell": 0},
        {"level": 4, "money": 8,  "coal": 0, "iron": 1, "vp": 3,  "income": 6, "links": 1, "beer_sell": 1},
        {"level": 5, "money": 16, "coal": 1, "iron": 0, "vp": 8,  "income": 2, "links": 2, "beer_sell": 2},
        {"level": 6, "money": 20, "coal": 0, "iron": 0, "vp": 7,  "income": 6, "links": 1, "beer_sell": 1},
        {"level": 7, "money": 16, "coal": 1, "iron": 1, "vp": 9,  "income": 4, "links": 0, "beer_sell": 0},
        {"level": 8, "money": 20, "coal": 0, "iron": 2, "vp": 11, "income": 1, "links": 1, "beer_sell": 1},
    ],
    "pottery": [
        {"level": 1, "money": 17, "coal": 0, "iron": 1, "vp": 10, "income": 5, "links": 1, "beer_sell": 1, "no_develop": True},
        {"level": 2, "money": 0,  "coal": 1, "iron": 0, "vp": 1,  "income": 1, "links": 1, "beer_sell": 1},
        {"level": 3, "money": 22, "coal": 2, "iron": 0, "vp": 11, "income": 5, "links": 1, "beer_sell": 2, "no_develop": True},
        {"level": 4, "money": 0,  "coal": 1, "iron": 0, "vp": 1,  "income": 1, "links": 1, "beer_sell": 1},
        {"level": 5, "money": 24, "coal": 2, "iron": 0, "vp": 20, "income": 5, "links": 1, "beer_sell": 2, "rail_only": True},
    ],
}

# ---------------------------------------------------------------------------
# Chinese industry names
# ---------------------------------------------------------------------------
INDUSTRY_ZH = {
    "cotton":       "棉花廠",
    "coal":         "煤礦",
    "iron":         "鐵工廠",
    "brewery":      "釀酒廠",
    "manufacturer": "製造廠",
    "pottery":      "陶瓷廠",
}

INDUSTRY_EN = {
    "cotton":       "Cotton Mill",
    "coal":         "Coal Mine",
    "iron":         "Iron Works",
    "brewery":      "Brewery",
    "manufacturer": "Manufactory",
    "pottery":      "Pottery",
}

# ---------------------------------------------------------------------------
# Colour palette — Victorian industrial theme
# ---------------------------------------------------------------------------
INDUSTRY_PALETTE = {
    #             base_rgb          accent_rgb          text_rgb
    "cotton":       ((232, 220, 200), (139, 115,  85), ( 40,  28,  12)),
    "coal":         (( 42,  42,  42), ( 85,  85,  85), (235, 228, 215)),
    "iron":         (( 92,  58,  30), (184, 115,  51), (240, 228, 210)),
    "brewery":      (( 58,  42,  10), (212, 160,  23), (240, 225, 190)),
    "manufacturer": (( 58,  32,  64), (155, 107, 186), (240, 228, 245)),
    "pottery":      (( 74,  32,  16), (192, 101,  42), (240, 228, 215)),
}

WHITE       = (255, 255, 255)
BLACK       = (  8,   8,   8)
GOLD        = (212, 168,  32)
GOLD_LIGHT  = (240, 200,  80)

# Stat icon colors
VP_COLOR     = (200,  40,  40)   # red/crimson
INCOME_COLOR = ( 40, 160,  70)   # green
LINK_COLOR   = ( 50,  90, 200)   # blue
BEER_COLOR   = (190, 130,  20)   # amber
COAL_PROD_COLOR = ( 80,  80,  80)  # dark gray
IRON_PROD_COLOR = (180, 100,  30)  # orange-bronze
BREW_PROD_COLOR = (180, 140,  20)  # gold

# ---------------------------------------------------------------------------
# Font helpers
# ---------------------------------------------------------------------------
def load_font(size: int, bold: bool = False, serif: bool = False, chinese: bool = False) -> ImageFont.FreeTypeFont:
    if chinese:
        candidates = [
            "C:/Windows/Fonts/msjh.ttc",
            "C:/Windows/Fonts/NotoSansTC-VF.ttf",
            "C:/Windows/Fonts/mingliu.ttc",
        ]
    elif serif:
        candidates = [
            "C:/Windows/Fonts/georgiab.ttf" if bold else "C:/Windows/Fonts/georgia.ttf",
            "C:/Windows/Fonts/timesbd.ttf"  if bold else "C:/Windows/Fonts/times.ttf",
        ]
    elif bold:
        candidates = [
            "C:/Windows/Fonts/calibrib.ttf",
            "C:/Windows/Fonts/arialbd.ttf",
            "C:/Windows/Fonts/verdanab.ttf",
        ]
    else:
        candidates = [
            "C:/Windows/Fonts/calibri.ttf",
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/verdana.ttf",
        ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Color utilities
# ---------------------------------------------------------------------------
def darken(color, factor=0.5):
    return tuple(max(0, int(c * factor)) for c in color)

def lighten(color, factor=1.4):
    return tuple(min(255, int(c * factor)) for c in color)

def blend(c1, c2, t):
    """Blend two RGB tuples; t=0 -> c1, t=1 -> c2."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def with_alpha(color, alpha):
    if len(color) == 3:
        return color + (alpha,)
    return color[:3] + (alpha,)


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------
def draw_text_centered(draw, cx, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2 - bbox[0], cy - th // 2 - bbox[1]), text, font=font, fill=fill)


def draw_text_left(draw, x, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    th = bbox[3] - bbox[1]
    draw.text((x - bbox[0], cy - th // 2 - bbox[1]), text, font=font, fill=fill)


def text_width(draw, text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]


def text_height(draw, text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[3] - bbox[1]


# ---------------------------------------------------------------------------
# Gradient fill helpers (vertical)
# ---------------------------------------------------------------------------
def draw_gradient_rect(img, x0, y0, x1, y1, color_top, color_bot, radius=0):
    """Draw a vertical gradient rectangle directly onto img (RGBA)."""
    draw = ImageDraw.Draw(img)
    h = y1 - y0
    if h <= 0:
        return
    for row in range(h):
        t = row / max(h - 1, 1)
        c = blend(color_top, color_bot, t)
        if img.mode == "RGBA":
            c = c + (255,)
        draw.line([(x0, y0 + row), (x1, y0 + row)], fill=c)

    # Clip to rounded corners if requested
    if radius > 0:
        # Draw corner masks
        mask = Image.new("L", (x1 - x0, y1 - y0), 255)
        mdraw = ImageDraw.Draw(mask)
        # Carve out corners using black circles
        r = radius
        w_m = x1 - x0
        h_m = y1 - y0
        for corner in [
            (0, 0, r * 2, r * 2),
            (w_m - r * 2, 0, w_m, r * 2),
            (0, h_m - r * 2, r * 2, h_m),
            (w_m - r * 2, h_m - r * 2, w_m, h_m),
        ]:
            mdraw.ellipse(corner, fill=255)


def gradient_band(img_draw_tuple, x0, y0, x1, y1, color_top, color_bot):
    """Simple line-by-line gradient band on a regular ImageDraw."""
    draw, img = img_draw_tuple
    h = y1 - y0
    if h <= 0:
        return
    for row in range(h):
        t = row / max(h - 1, 1)
        c = blend(color_top, color_bot, t)
        draw.line([(x0, y0 + row), (x1, y0 + row)], fill=c)


# ---------------------------------------------------------------------------
# Vignette / inner shadow
# ---------------------------------------------------------------------------
def apply_vignette(img: Image.Image, strength: float = 0.45) -> Image.Image:
    """Darken edges of an RGBA image with a radial vignette."""
    vig = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(vig)
    cx, cy = img.width // 2, img.height // 2
    steps = 30
    for i in range(steps, 0, -1):
        t = i / steps
        alpha = int(strength * 255 * (1 - t) ** 1.8)
        pad_x = int(cx * (1 - t))
        pad_y = int(cy * (1 - t))
        draw.rounded_rectangle(
            [pad_x, pad_y, img.width - pad_x, img.height - pad_y],
            radius=max(2, CORNER_R - pad_x // 2),
            fill=(0, 0, 0, alpha),
        )
    out = Image.alpha_composite(img.convert("RGBA"), vig)
    return out


# ---------------------------------------------------------------------------
# Rounded-rect clipping mask
# ---------------------------------------------------------------------------
def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


# ---------------------------------------------------------------------------
# Mini badge: icon circle + number
# ---------------------------------------------------------------------------
def draw_stat_pill(draw, cx, cy, icon_char, value_str, icon_color, text_color, font_icon, font_val):
    """Draw an icon circle next to a value string. Returns total width."""
    r = 9
    # Circle
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=icon_color)
    # Icon char centered in circle
    draw_text_centered(draw, cx, cy, icon_char, font_icon, WHITE)
    # Value to the right
    val_x = cx + r + 3
    draw_text_left(draw, val_x, cy, value_str, font_val, text_color)
    val_w = text_width(draw, value_str, font_val)
    return r * 2 + 3 + val_w


# ---------------------------------------------------------------------------
# Flag badge (RAIL / LOCK)
# ---------------------------------------------------------------------------
def draw_flag_badge(draw, x, y, label, bg_color, text_color, font):
    """Draw a small pill badge at (x, y) top-right."""
    tw = text_width(draw, label, font)
    th = text_height(draw, label, font)
    pad_x, pad_y = 5, 3
    bw = tw + pad_x * 2
    bh = th + pad_y * 2
    draw.rounded_rectangle([x - bw, y, x, y + bh], radius=4, fill=bg_color)
    draw_text_centered(draw, x - bw // 2, y + bh // 2, label, font, text_color)
    return bh


# ---------------------------------------------------------------------------
# Front tile
# ---------------------------------------------------------------------------
def make_front_tile(industry: str, data: dict) -> Image.Image:
    base, accent, text_col = INDUSTRY_PALETTE[industry]
    lv = data["level"]
    zh_name = INDUSTRY_ZH[industry]
    en_name = INDUSTRY_EN[industry]

    # Create RGBA canvas
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # --- Background fill (rounded rect) ---
    bg_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_layer)
    bg_draw.rounded_rectangle([0, 0, W - 1, H - 1], radius=CORNER_R, fill=base + (255,))
    img = Image.alpha_composite(img, bg_layer)

    # Subtle texture: slightly lighten center vs edges (warm glow)
    glow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    for i in range(6):
        t = i / 5
        pad = int(40 * (1 - t))
        alpha = int(18 * (1 - t))
        glow_draw.rounded_rectangle([pad, pad, W - pad, H - pad],
                                     radius=max(4, CORNER_R - pad // 3),
                                     fill=(255, 245, 220, alpha))
    img = Image.alpha_composite(img, glow_layer)

    draw = ImageDraw.Draw(img)

    # --- Header gradient band ---
    header_top = PAD
    header_h = 36
    header_bot = header_top + header_h
    header_dark = darken(accent, 0.55)
    header_mid  = darken(accent, 0.75)

    # Draw gradient band within rounded rect boundary
    for row in range(header_h):
        t = row / max(header_h - 1, 1)
        c = blend(header_dark, header_mid, t) + (255,)
        # Clip to rounded corners at top
        row_y = header_top + row
        if row_y < CORNER_R:
            arc_dx = int(CORNER_R - math.sqrt(max(0, CORNER_R**2 - (CORNER_R - row_y)**2)))
        else:
            arc_dx = 0
        x_start = max(PAD, arc_dx)
        x_end   = min(W - PAD, W - arc_dx)
        draw.line([(x_start, row_y), (x_end, row_y)], fill=c)

    # Accent line under header
    draw.line([(PAD + 2, header_bot), (W - PAD - 2, header_bot)], fill=accent + (220,), width=1)

    # --- Fonts ---
    f_title    = load_font(11, bold=True)        # header industry label
    f_lv       = load_font(11, bold=True, serif=True)
    f_zh       = load_font(12, chinese=True)
    f_en       = load_font(10, serif=True)
    f_cost_big = load_font(22, bold=True, serif=True)
    f_cost_lbl = load_font(9)
    f_icon     = load_font(8, bold=True)
    f_stat_val = load_font(11, bold=True)
    f_badge    = load_font(7, bold=True)
    f_flag     = load_font(7, bold=True)

    cx = W // 2

    # --- Header text: industry name + level ---
    industry_label = industry.upper()
    lv_label = f"Lv.{lv}"
    header_cy = header_top + header_h // 2
    # Left-align industry name, right-align level
    draw_text_left(draw, PAD + 8, header_cy, industry_label, f_title, WHITE)
    lv_w = text_width(draw, lv_label, f_lv)
    draw_text_left(draw, W - PAD - 8 - lv_w, header_cy, lv_label, f_lv, GOLD_LIGHT)

    # --- Flags (RAIL / LOCK) in top-right of name row ---
    flag_y = header_bot + 3
    flags_drawn = 0
    if data.get("rail_only"):
        draw_flag_badge(draw, W - PAD - 2, flag_y, "RAIL",
                        (80, 80, 90, 220), WHITE, f_flag)
        flags_drawn += 1
    if data.get("no_develop"):
        badge_x = W - PAD - 2 - (flags_drawn * 34)
        draw_flag_badge(draw, badge_x, flag_y, "LOCK",
                        (130, 80, 20, 220), WHITE, f_flag)
        flags_drawn += 1

    # --- Chinese + English name ---
    name_row_y = header_bot + 6
    draw_text_left(draw, PAD + 8, name_row_y + 7, zh_name, f_zh, text_col)
    en_x = PAD + 8 + text_width(draw, zh_name, f_zh) + 6
    draw_text_left(draw, en_x, name_row_y + 7, en_name, f_en, darken(text_col, 0.85) if text_col != (40, 28, 12) else (80, 60, 30))

    # Thin separator
    sep1_y = name_row_y + 20
    draw.line([(PAD + 4, sep1_y), (W - PAD - 4, sep1_y)],
              fill=darken(accent, 0.6) + (160,), width=1)

    # --- Cost section background highlight ---
    cost_section_top = sep1_y + 3
    cost_section_h   = 52
    cost_section_bot = cost_section_top + cost_section_h
    # Very subtle lighter rectangle
    cost_bg = blend(base, (255, 255, 255), 0.07) + (120,)
    draw.rounded_rectangle(
        [PAD + 3, cost_section_top, W - PAD - 3, cost_section_bot],
        radius=6, fill=cost_bg
    )

    # Build cost: £ amount (large)
    cost_cy = cost_section_top + 18
    money = data.get("money", 0)
    if money > 0:
        cost_str = f"\u00a3{money}"
    else:
        cost_str = "Free"
    draw_text_centered(draw, cx, cost_cy, cost_str, f_cost_big, text_col)

    # Coal + Iron cost icons row
    resource_row_y = cost_cy + 18
    coal_cost = data.get("coal", 0)
    iron_cost = data.get("iron", 0)

    res_parts = []
    if coal_cost > 0:
        res_parts.append(("\u25cf", f"\u00d7{coal_cost}", COAL_PROD_COLOR))  # ● coal
    if iron_cost > 0:
        res_parts.append(("\u25c6", f"\u00d7{iron_cost}", IRON_PROD_COLOR))  # ◆ iron

    if res_parts:
        total_w = 0
        spacer = 14
        widths = []
        for icon_ch, val_s, _col in res_parts:
            w = 9 * 2 + 3 + text_width(draw, val_s, f_stat_val) + spacer
            widths.append(w)
            total_w += w
        total_w -= spacer

        start_x = cx - total_w // 2 + 9
        for (icon_ch, val_s, col), w in zip(res_parts, widths):
            draw_stat_pill(draw, start_x, resource_row_y, icon_ch, val_s,
                           col, text_col, f_icon, f_stat_val)
            start_x += w
    else:
        draw_text_centered(draw, cx, resource_row_y, "No resource cost", f_cost_lbl, darken(text_col, 0.7) if industry != "coal" else (130, 130, 130))

    # Separator above stats bar
    sep2_y = cost_section_bot + 4
    draw.line([(PAD + 4, sep2_y), (W - PAD - 4, sep2_y)],
              fill=darken(accent, 0.6) + (160,), width=1)

    # --- Stats bar ---
    stats_y = sep2_y + 14

    # Determine stats to show
    produces     = data.get("produces")
    beer_sell    = data.get("beer_sell", 0)

    if industry in ("coal", "iron"):
        prod_icon  = "\u25cf" if industry == "coal" else "\u25c6"
        prod_color = COAL_PROD_COLOR if industry == "coal" else IRON_PROD_COLOR
        last_stat  = (prod_icon, str(produces), prod_color)
        last_label = "Prod"
    elif industry == "brewery":
        last_stat  = ("\u25df", str(produces), BREW_PROD_COLOR)  # ⬟ beer barrel
        last_label = "Brew"
    else:
        # sellable industry — show beer
        if beer_sell and beer_sell > 0:
            last_stat  = ("\u25b2", str(beer_sell), BEER_COLOR)  # ▲ beer
            last_label = "Beer"
        else:
            last_stat  = None
            last_label = None

    # Build stat list: VP, Income, Links, [last]
    stats = [
        ("\u2605", str(data["vp"]),       VP_COLOR,     "VP"),    # ★
        ("\u2191", f"+{data['income']}",  INCOME_COLOR, "Inc"),   # ↑
        ("\u29c6", str(data["links"]),     LINK_COLOR,   "Lnk"),  # ⧆
    ]
    if last_stat:
        stats.append(last_stat + (last_label,))

    n_stats = len(stats)
    stat_spacing = (W - PAD * 2 - 16) // n_stats
    stat_x_start = PAD + 8 + stat_spacing // 2

    for i, (icon_ch, val_s, col, _lbl) in enumerate(stats):
        sx = stat_x_start + i * stat_spacing
        draw_stat_pill(draw, sx, stats_y, icon_ch, val_s,
                       col, text_col, f_icon, f_stat_val)

    # --- Bottom label row: icon legend ---
    legend_y = H - PAD - 12
    legend_items = []
    for icon_ch, val_s, col, lbl in stats:
        legend_items.append(f"{icon_ch}={lbl}")
    legend_str = "  ".join(legend_items)
    draw_text_centered(draw, cx, legend_y, legend_str, f_cost_lbl,
                       darken(text_col, 0.65) if industry != "coal" else (100, 100, 100))

    # --- Accent border ---
    border_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border_layer)
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=CORNER_R,
                          outline=accent + (210,), width=BORDER_W)
    # Inner thin gold line
    bd.rounded_rectangle([BORDER_W + 1, BORDER_W + 1, W - BORDER_W - 2, H - BORDER_W - 2],
                          radius=CORNER_R - 2, outline=darken(accent, 0.8) + (120,), width=1)
    img = Image.alpha_composite(img, border_layer)

    # --- Vignette ---
    img = apply_vignette(img, strength=0.30)

    # Clip to rounded rect
    mask = rounded_mask((W, H), CORNER_R)
    result = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    result.paste(img, mask=mask)

    return result.convert("RGB")


# ---------------------------------------------------------------------------
# Back tile
# ---------------------------------------------------------------------------
def make_back_tile(industry: str, data: dict) -> Image.Image:
    base, accent, _text_col = INDUSTRY_PALETTE[industry]
    lv = data["level"]

    # Darkened/muted background
    bg = darken(base, 0.45)
    bg_mid = darken(blend(base, accent, 0.15), 0.50)

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Background fill
    bg_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_layer)
    bg_draw.rounded_rectangle([0, 0, W - 1, H - 1], radius=CORNER_R, fill=bg + (255,))
    img = Image.alpha_composite(img, bg_layer)

    draw = ImageDraw.Draw(img)

    # Header gradient band
    header_h = 28
    header_dark = darken(accent, 0.25)
    header_mid  = darken(accent, 0.35)
    for row in range(header_h):
        t = row / max(header_h - 1, 1)
        c = blend(header_dark, header_mid, t) + (255,)
        row_y = PAD + row
        if row_y < CORNER_R:
            arc_dx = int(CORNER_R - math.sqrt(max(0, CORNER_R**2 - (CORNER_R - row_y)**2)))
        else:
            arc_dx = 0
        x_start = max(PAD, arc_dx)
        x_end   = min(W - PAD, W - arc_dx)
        draw.line([(x_start, row_y), (x_end, row_y)], fill=c)

    # Accent line under header
    header_bot = PAD + header_h
    draw.line([(PAD + 2, header_bot), (W - PAD - 2, header_bot)],
              fill=darken(accent, 0.6) + (200,), width=1)

    # Fonts
    f_flipped   = load_font(10, bold=True)
    f_vp_big    = load_font(48, bold=True, serif=True)
    f_vp_label  = load_font(11, bold=True)
    f_links     = load_font(14, bold=True)
    f_footer    = load_font(9)

    cx = W // 2

    # "FLIPPED" header text
    header_cy = PAD + header_h // 2
    # Hatching effect: draw striped pattern
    stripe_col = darken(accent, 0.30) + (180,)
    for sx in range(PAD + 4, W - PAD - 4, 8):
        draw.line([(sx, PAD + 1), (sx, header_bot - 1)], fill=stripe_col, width=2)
    draw_text_centered(draw, cx, header_cy, "\u25a0\u25a0 FLIPPED \u25a0\u25a0", f_flipped, (180, 168, 150))

    # Large VP value
    vp_str   = str(data["vp"])
    vp_label = "VP"
    vp_y = header_bot + 52
    draw_text_centered(draw, cx, vp_y, vp_str, f_vp_big, GOLD)

    # Gold glow effect around VP number (soft outline)
    for offset in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        vp_bbox = draw.textbbox((0, 0), vp_str, font=f_vp_big)
        vp_tw = vp_bbox[2] - vp_bbox[0]
        vp_th = vp_bbox[3] - vp_bbox[1]
        ox, oy = offset
        draw.text(
            (cx - vp_tw // 2 - vp_bbox[0] + ox,
             vp_y - vp_th // 2 - vp_bbox[1] + oy),
            vp_str, font=f_vp_big,
            fill=darken(GOLD, 0.55) + (80,)
        )

    draw_text_centered(draw, cx, vp_y + 30, "★  " + vp_label + "  ★", f_vp_label,
                       darken(GOLD, 0.85))

    # Links row
    links_y = vp_y + 54
    links_str = f"\u29c6  {data['links']}  Link{'s' if data['links'] != 1 else ''}"
    draw_text_centered(draw, cx, links_y, links_str, f_links, (160, 180, 220))

    # Industry + level footer
    zh_name = INDUSTRY_ZH[industry]
    footer_y = H - PAD - 10
    footer_str = f"{zh_name} / {INDUSTRY_EN[industry]}  Lv.{lv}"
    draw_text_centered(draw, cx, footer_y, footer_str, f_footer, (130, 120, 105))

    # Accent border
    border_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border_layer)
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=CORNER_R,
                          outline=darken(accent, 0.65) + (200,), width=BORDER_W)
    bd.rounded_rectangle([BORDER_W + 1, BORDER_W + 1, W - BORDER_W - 2, H - BORDER_W - 2],
                          radius=CORNER_R - 2,
                          outline=darken(accent, 0.45) + (100,), width=1)
    img = Image.alpha_composite(img, border_layer)

    # Vignette
    img = apply_vignette(img, strength=0.40)

    # Clip to rounded rect
    mask = rounded_mask((W, H), CORNER_R)
    result = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    result.paste(img, mask=mask)

    return result.convert("RGB")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    total = 0

    for industry, levels in TILE_DATA.items():
        print(f"Generating tiles for: {industry} ({len(levels)} levels) ...")
        for data in levels:
            lv = data["level"]

            # Front
            front = make_front_tile(industry, data)
            fname_f = f"{industry}_lv{lv}_front.png"
            front.save(OUT_DIR / fname_f)
            print(f"  [front] {fname_f}")
            total += 1

            # Back
            back = make_back_tile(industry, data)
            fname_b = f"{industry}_lv{lv}_back.png"
            back.save(OUT_DIR / fname_b)
            print(f"  [back]  {fname_b}")
            total += 1

    print(f"\nDone. {total} tile images written to {OUT_DIR}")


if __name__ == "__main__":
    main()
