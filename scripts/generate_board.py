"""
generate_board.py  —  Premium board image for Brass: Birmingham TTS mod.
Output: assets/board/main_board.png  (4096 x 3072)
"""

import os
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR   = REPO_ROOT / "assets" / "board"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
W, H = 4096, 3072

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
BG_DEEP       = (26,  16,   8)     # #1A1008
BG_MID        = (38,  26,  14)
BG_LIGHT      = (50,  38,  22)
PANEL_BG      = (32,  22,  12)
PANEL_BORDER  = (80,  62,  32)
GOLD          = (220, 180,  60)
GOLD_DIM      = (160, 128,  40)
GOLD_BRIGHT   = (255, 220, 100)
CREAM         = (245, 235, 210)
WHITE         = (252, 248, 240)
BLACK         = (8,    6,   4)

CITY_FILL     = (52,  38,  20)
CITY_OUTLINE  = (210, 170,  70)
CITY_TEXT     = (240, 228, 200)
MERCHANT_FILL = (42,  28,  14)
MERCHANT_RING = (240, 200,  80)

CANAL_COLOR   = (59, 107, 155)     # #3B6B9B
RAIL_COLOR    = (128, 128, 128)    # #808080
ROUTE_GLOW    = (80, 140, 200)

MARKET_BG     = (22,  14,   6)
MARKET_BORDER = (100,  76,  36)
VP_BG         = (18,  12,   5)
VP_FG         = (200, 162,  72)

IND_COLORS = {
    "cotton":       (190, 195, 215),
    "coal":         (55,   55,  62),
    "iron":         (170,  88,  28),
    "brewery":      (188, 148,  22),
    "manufacturer": (105,  48, 140),
    "pottery":      (178,  68,  38),
}

IND_NAMES_ZH = {
    "cotton":       "棉花",
    "coal":         "煤炭",
    "iron":         "鐵礦",
    "brewery":      "釀酒廠",
    "manufacturer": "製造商",
    "pottery":      "陶瓷",
}

# ---------------------------------------------------------------------------
# Chinese city names
# ---------------------------------------------------------------------------
CITY_NAMES_ZH = {
    "Birmingham":     "伯明翰",
    "Coventry":       "考文垂",
    "Dudley":         "達德利",
    "Kidderminster":  "基德明斯特",
    "Wolverhampton":  "伍爾弗漢普頓",
    "Coalbrookdale":  "煤溪谷",
    "Nuneaton":       "納尼頓",
    "Worcester":      "伍斯特",
    "Tamworth":       "塔姆沃思",
    "Walsall":        "沃爾索爾",
    "Cannock":        "坎諾克",
    "Burton-on-Trent":"伯頓",
    "Stafford":       "斯塔福德",
    "Stoke-on-Trent": "斯托克",
    "Leek":           "利克",
    "Stone":          "斯通",
    "Uttoxeter":      "厄托克塞特",
    "Belper":         "貝爾珀",
    "Derby":          "德比",
    "Redditch":       "雷迪奇",
    "Shrewsbury":     "什魯斯伯里",
    "Gloucester":     "格洛斯特",
    "Oxford":         "牛津",
    "Warrington":     "沃靈頓",
    "Nottingham":     "諾丁漢",
}

# ---------------------------------------------------------------------------
# Font helpers
# ---------------------------------------------------------------------------
def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    if bold:
        candidates = [
            "C:/Windows/Fonts/georgiab.ttf",
            "C:/Windows/Fonts/timesbd.ttf",
            "C:/Windows/Fonts/arialbd.ttf",
            "C:/Windows/Fonts/calibrib.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        ]
    else:
        candidates = [
            "C:/Windows/Fonts/georgia.ttf",
            "C:/Windows/Fonts/times.ttf",
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/calibri.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def load_font_num(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    candidates = (
        ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/calibrib.ttf"]
        if bold else
        ["C:/Windows/Fonts/arial.ttf",   "C:/Windows/Fonts/calibri.ttf"]
    )
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return load_font(size, bold)


def load_font_cjk(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/msjh.ttc",
        "C:/Windows/Fonts/msjhbd.ttc",
        "C:/Windows/Fonts/mingliu.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return load_font(size)


def text_size(draw, text, font):
    bb = draw.textbbox((0, 0), text, font=font)
    return bb[2] - bb[0], bb[3] - bb[1]


def center_text(draw, cx, cy, text, font, fill, shadow=None):
    bb = draw.textbbox((0, 0), text, font=font)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    x = cx - tw // 2 - bb[0]
    y = cy - th // 2 - bb[1]
    if shadow:
        draw.text((x + 2, y + 2), text, font=font, fill=shadow)
    draw.text((x, y), text, font=font, fill=fill)


# ---------------------------------------------------------------------------
# Background: gradient + parchment noise
# ---------------------------------------------------------------------------
def make_background() -> Image.Image:
    img = Image.new("RGB", (W, H))
    pix = img.load()

    # Radial gradient from center (slightly warm) to dark corners
    cx, cy = W // 2, H // 2
    max_dist = math.hypot(cx, cy)
    for y in range(H):
        for x in range(0, W, 4):   # step=4 for speed, fill in below
            dist = math.hypot(x - cx, y - cy) / max_dist
            t = dist * dist   # quadratic falloff
            r = int(BG_DEEP[0] + (BG_MID[0] - BG_DEEP[0]) * (1 - t))
            g = int(BG_DEEP[1] + (BG_MID[1] - BG_DEEP[1]) * (1 - t))
            b = int(BG_DEEP[2] + (BG_MID[2] - BG_DEEP[2]) * (1 - t))
            for dx in range(4):
                if x + dx < W:
                    pix[x + dx, y] = (r, g, b)

    # Parchment/canvas noise overlay
    rng = random.Random(42)
    noise = Image.new("RGB", (W, H))
    np = noise.load()
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            v = rng.randint(-10, 10)
            base = pix[x, y]
            nr = max(0, min(255, base[0] + v))
            ng = max(0, min(255, base[1] + v // 2))
            nb = max(0, min(255, base[2] + v // 4))
            for dx in range(2):
                for dy in range(2):
                    if x + dx < W and y + dy < H:
                        np[x + dx, y + dy] = (nr, ng, nb)

    # Blend noise at 30%
    out = Image.blend(img, noise, 0.30)
    return out


# ---------------------------------------------------------------------------
# Gold decorative border
# ---------------------------------------------------------------------------
def draw_gold_border(draw):
    # Outermost thick gold line
    for t in range(4):
        clr = (int(GOLD[0] * (0.6 + 0.1 * t)),
               int(GOLD[1] * (0.6 + 0.1 * t)),
               int(GOLD[2] * (0.4 + 0.1 * t)))
        draw.rectangle([t, t, W - 1 - t, H - 1 - t], outline=clr)

    # Inner inset lines
    for t, clr in [(8, GOLD_DIM), (14, GOLD), (18, GOLD_DIM)]:
        draw.rectangle([t, t, W - 1 - t, H - 1 - t], outline=clr, width=2)

    # Corner ornament squares
    corner_size = 32
    corners = [(20, 20), (W - 20 - corner_size, 20),
               (20, H - 20 - corner_size), (W - 20 - corner_size, H - 20 - corner_size)]
    for cx, cy in corners:
        draw.rectangle([cx, cy, cx + corner_size, cy + corner_size],
                       fill=BG_DEEP, outline=GOLD_BRIGHT, width=2)
        # diagonal cross in corner
        draw.line([(cx, cy), (cx + corner_size, cy + corner_size)], fill=GOLD, width=1)
        draw.line([(cx + corner_size, cy), (cx, cy + corner_size)], fill=GOLD, width=1)


# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------
def draw_title(draw):
    f_title_en  = load_font(96, bold=True)
    f_title_zh  = load_font_cjk(52)
    f_subtitle  = load_font(34)
    shadow_clr  = (8, 5, 2)

    title_y = 72
    center_text(draw, W // 2, title_y, "BRASS: BIRMINGHAM",
                f_title_en, GOLD, shadow=shadow_clr)

    zh_y = title_y + 68
    center_text(draw, W // 2, zh_y, "工業革命：伯明翰",
                f_title_zh, GOLD_DIM, shadow=shadow_clr)

    sub_y = zh_y + 44
    center_text(draw, W // 2, sub_y, "Tabletop Simulator Mod",
                f_subtitle, (140, 118, 78))

    # Decorative rule under title
    rule_y = sub_y + 28
    rule_x0 = W // 2 - 600
    rule_x1 = W // 2 + 600
    draw.line([(rule_x0, rule_y), (rule_x1, rule_y)], fill=GOLD_DIM, width=2)
    draw.ellipse([(W // 2 - 6, rule_y - 5), (W // 2 + 6, rule_y + 5)],
                 fill=GOLD, outline=None)


# ---------------------------------------------------------------------------
# City data  (x, y) on 4096×3072
# ---------------------------------------------------------------------------
CITIES = {
    "Shrewsbury":     ( 310,  640),
    "Coalbrookdale":  ( 390,  890),
    "Kidderminster":  ( 445, 1240),
    "Worcester":      ( 430, 1540),
    "Gloucester":     ( 400, 1850),

    "Wolverhampton":  ( 700,  940),
    "Dudley":         ( 740, 1170),
    "Birmingham":     ( 820, 1400),
    "Redditch":       ( 800, 1660),

    "Walsall":        ( 940,  980),
    "Cannock":        ( 980,  770),
    "Tamworth":       (1140, 1180),

    "Stafford":       (1120,  600),
    "Stone":          (1220,  820),
    "Burton-on-Trent":(1340, 1040),
    "Nuneaton":       (1300, 1300),
    "Coventry":       (1320, 1540),

    "Stoke-on-Trent": (1400,  560),
    "Leek":           (1640,  580),
    "Uttoxeter":      (1580,  860),
    "Derby":          (1780, 1000),
    "Belper":         (1820,  790),
    "Nottingham":     (2000, 1120),

    "Warrington":     ( 820,  300),
    "Oxford":         (1080, 1860),
}

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
ROUTES = [
    ("Birmingham",     "Coventry",        "both"),
    ("Birmingham",     "Dudley",          "both"),
    ("Birmingham",     "Redditch",        "both"),
    ("Birmingham",     "Tamworth",        "both"),
    ("Birmingham",     "Walsall",         "both"),
    ("Birmingham",     "Wolverhampton",   "both"),
    ("Birmingham",     "Worcester",       "both"),
    ("Birmingham",     "Cannock",         "rail"),
    ("Coventry",       "Nuneaton",        "both"),
    ("Coventry",       "Oxford",          "both"),
    ("Dudley",         "Kidderminster",   "both"),
    ("Dudley",         "Wolverhampton",   "both"),
    ("Dudley",         "Walsall",         "rail"),
    ("Kidderminster",  "Worcester",       "both"),
    ("Coalbrookdale",  "Kidderminster",   "both"),
    ("Cannock",        "Wolverhampton",   "both"),
    ("Shrewsbury",     "Wolverhampton",   "both"),
    ("Coalbrookdale",  "Wolverhampton",   "both"),
    ("Coalbrookdale",  "Shrewsbury",      "both"),
    ("Cannock",        "Walsall",         "both"),
    ("Cannock",        "Stafford",        "both"),
    ("Burton-on-Trent","Tamworth",        "both"),
    ("Burton-on-Trent","Cannock",         "rail"),
    ("Burton-on-Trent","Uttoxeter",       "both"),
    ("Nuneaton",       "Tamworth",        "both"),
    ("Nottingham",     "Nuneaton",        "rail"),
    ("Stafford",       "Stone",           "both"),
    ("Stafford",       "Uttoxeter",       "rail"),
    ("Leek",           "Stoke-on-Trent",  "both"),
    ("Stone",          "Stoke-on-Trent",  "both"),
    ("Stoke-on-Trent", "Warrington",      "both"),
    ("Shrewsbury",     "Warrington",      "both"),
    ("Leek",           "Uttoxeter",       "rail"),
    ("Stone",          "Uttoxeter",       "both"),
    ("Derby",          "Uttoxeter",       "both"),
    ("Belper",         "Derby",           "both"),
    ("Belper",         "Leek",            "rail"),
    ("Derby",          "Nottingham",      "both"),
    ("Burton-on-Trent","Derby",           "rail"),
    ("Gloucester",     "Redditch",        "both"),
    ("Oxford",         "Redditch",        "both"),
    ("Redditch",       "Worcester",       "both"),
    ("Gloucester",     "Worcester",       "both"),
    ("Walsall",        "Wolverhampton",   "rail"),
]

# ---------------------------------------------------------------------------
# City slots
# ---------------------------------------------------------------------------
CITY_SLOTS = {
    "Birmingham":     ["cotton", "manufacturer", "iron", "manufacturer"],
    "Coventry":       ["pottery", "manufacturer"],
    "Dudley":         ["coal", "iron"],
    "Kidderminster":  ["cotton", "cotton"],
    "Wolverhampton":  ["manufacturer", "manufacturer"],
    "Coalbrookdale":  ["iron", "iron", "brewery"],
    "Nuneaton":       ["manufacturer", "cotton"],
    "Worcester":      ["cotton", "cotton"],
    "Tamworth":       ["cotton", "coal"],
    "Walsall":        ["manufacturer", "brewery"],
    "Cannock":        ["coal", "manufacturer"],
    "Burton-on-Trent":["brewery", "brewery", "coal"],
    "Stafford":       ["manufacturer", "pottery"],
    "Stoke-on-Trent": ["cotton", "manufacturer", "pottery"],
    "Leek":           ["cotton", "manufacturer"],
    "Stone":          ["cotton", "manufacturer"],
    "Uttoxeter":      ["manufacturer", "brewery"],
    "Belper":         ["cotton", "manufacturer", "pottery"],
    "Derby":          ["cotton", "brewery", "manufacturer"],
    "Redditch":       ["coal", "iron"],
    "Shrewsbury":     [],
    "Gloucester":     [],
    "Oxford":         [],
    "Warrington":     [],
    "Nottingham":     [],
}

MERCHANTS = [
    {"name": "Shrewsbury", "name_zh": "什魯斯伯里", "bonus": "+4 VP"},
    {"name": "Gloucester", "name_zh": "格洛斯特",   "bonus": "Free Develop"},
    {"name": "Oxford",     "name_zh": "牛津",       "bonus": "+2 Income"},
    {"name": "Warrington", "name_zh": "沃靈頓",     "bonus": "+£5"},
    {"name": "Nottingham", "name_zh": "諾丁漢",     "bonus": "+3 VP"},
]
MERCHANT_NAMES = {m["name"] for m in MERCHANTS}

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------
def draw_dashed_line(draw, x0, y0, x1, y1, fill, width, dash=20, gap=10):
    length = math.hypot(x1 - x0, y1 - y0)
    if length < 1:
        return
    dx = (x1 - x0) / length
    dy = (y1 - y0) / length
    pos = 0
    drawing = True
    while pos < length:
        seg = dash if drawing else gap
        end = min(pos + seg, length)
        if drawing:
            draw.line(
                [(x0 + dx * pos, y0 + dy * pos),
                 (x0 + dx * end, y0 + dy * end)],
                fill=fill, width=width,
            )
        pos = end
        drawing = not drawing


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(list(xy), radius=radius,
                           fill=fill, outline=outline, width=width)


def city_edge_point(cx, cy, tx, ty, radius):
    """Return the point on the circle boundary of (cx,cy,r) towards (tx,ty)."""
    dx = tx - cx
    dy = ty - cy
    dist = math.hypot(dx, dy) or 1
    return cx + dx / dist * radius, cy + dy / dist * radius


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
CITY_R = 44   # city circle radius (used in routes + cities drawing)

def draw_routes(draw):
    for city_a, city_b, era in ROUTES:
        if city_a not in CITIES or city_b not in CITIES:
            continue
        ax, ay = CITIES[city_a]
        bx, by = CITIES[city_b]

        # Start/end at circle edges
        ex0, ey0 = city_edge_point(ax, ay, bx, by, CITY_R + 4)
        ex1, ey1 = city_edge_point(bx, by, ax, ay, CITY_R + 4)

        if era == "canal":
            draw_dashed_line(draw, ex0, ey0, ex1, ey1,
                             CANAL_COLOR, 7, dash=22, gap=9)
        elif era == "rail":
            draw_dashed_line(draw, ex0, ey0, ex1, ey1,
                             RAIL_COLOR, 6, dash=14, gap=11)
        else:  # both — parallel canal + rail lines
            length = math.hypot(ex1 - ex0, ey1 - ey0) or 1
            px = -(ey1 - ey0) / length * 5
            py =  (ex1 - ex0) / length * 5

            # Canal (blue, offset one side)
            draw_dashed_line(draw,
                             ex0 + px, ey0 + py, ex1 + px, ey1 + py,
                             CANAL_COLOR, 5, dash=22, gap=9)
            # Rail (gray, opposite side)
            draw_dashed_line(draw,
                             ex0 - px, ey0 - py, ex1 - px, ey1 - py,
                             RAIL_COLOR, 4, dash=14, gap=11)


# ---------------------------------------------------------------------------
# Cities
# ---------------------------------------------------------------------------
def draw_cities(draw):
    SLOT_DOT_R = 7
    SLOT_GAP   = 5

    f_en  = load_font(22, bold=True)
    f_zh  = load_font_cjk(18)
    f_bon = load_font(19)
    shadow_c = (8, 5, 2)

    for name, (cx, cy) in CITIES.items():
        is_merchant = (name in MERCHANT_NAMES)

        # Drop shadow
        draw.ellipse([(cx - CITY_R + 4, cy - CITY_R + 4),
                      (cx + CITY_R + 4, cy + CITY_R + 4)],
                     fill=(10, 6, 2))

        # Outer glow ring for merchant cities
        if is_merchant:
            for r_off, alpha in [(CITY_R + 8, 60), (CITY_R + 5, 100)]:
                glow_c = (int(MERCHANT_RING[0] * alpha / 255),
                          int(MERCHANT_RING[1] * alpha / 255),
                          int(MERCHANT_RING[2] * alpha / 255))
                draw.ellipse([(cx - r_off, cy - r_off),
                              (cx + r_off, cy + r_off)],
                             outline=glow_c, width=2)

        # Fill circle
        fill_c   = MERCHANT_FILL  if is_merchant else CITY_FILL
        ring_c   = MERCHANT_RING  if is_merchant else CITY_OUTLINE

        draw.ellipse([(cx - CITY_R, cy - CITY_R),
                      (cx + CITY_R, cy + CITY_R)],
                     fill=fill_c, outline=ring_c, width=4)

        # Inner highlight ring
        inner_r = CITY_R - 8
        inner_c = tuple(min(255, c + 30) for c in ring_c)
        draw.ellipse([(cx - inner_r, cy - inner_r),
                      (cx + inner_r, cy + inner_r)],
                     fill=None, outline=inner_c, width=1)

        # Crown/star for merchant city (★ above circle)
        if is_merchant:
            star_y = cy - CITY_R - 18
            f_star = load_font_num(26, bold=True)
            center_text(draw, cx, star_y, "★", f_star, GOLD)

        # City name in cream (above circle)
        name_y = cy - CITY_R - 26
        if is_merchant:
            name_y = cy - CITY_R - 46  # pushed up to make room for star
        center_text(draw, cx, name_y, name, f_en, CREAM, shadow=shadow_c)

        # Chinese name below English
        zh = CITY_NAMES_ZH.get(name, "")
        if zh:
            center_text(draw, cx, name_y + 24, zh, f_zh,
                        (190, 175, 140), shadow=shadow_c)

        # Industry slot dots below circle
        slots = CITY_SLOTS.get(name, [])
        if slots:
            n = len(slots)
            total_w = n * (SLOT_DOT_R * 2 + SLOT_GAP) - SLOT_GAP
            sx0 = cx - total_w // 2
            dot_y = cy + CITY_R + 14
            for j, ind in enumerate(slots):
                dx = sx0 + j * (SLOT_DOT_R * 2 + SLOT_GAP) + SLOT_DOT_R
                color = IND_COLORS.get(ind, (120, 120, 120))
                # dot fill
                draw.ellipse([(dx - SLOT_DOT_R, dot_y - SLOT_DOT_R),
                              (dx + SLOT_DOT_R, dot_y + SLOT_DOT_R)],
                             fill=color, outline=(220, 200, 170), width=1)

        # Merchant bonus text
        if is_merchant:
            for m in MERCHANTS:
                if m["name"] == name:
                    center_text(draw, cx, cy + CITY_R + 22, m["bonus"],
                                f_bon, (160, 215, 130), shadow=shadow_c)
                    break


# ---------------------------------------------------------------------------
# Map area frame
# ---------------------------------------------------------------------------
MAP_X = 76
MAP_Y = 196
MAP_W = 2180
MAP_H = H - 380

def draw_map_frame(draw):
    # Subtle panel tint
    draw_rounded_rect(draw,
                      (MAP_X, MAP_Y, MAP_X + MAP_W, MAP_Y + MAP_H),
                      radius=18, fill=(28, 18, 9), outline=None)
    # Gold frame lines
    for inset, clr, lw in [
        (0,  PANEL_BORDER, 3),
        (5,  GOLD_DIM,     1),
        (10, PANEL_BORDER, 1),
    ]:
        draw_rounded_rect(draw,
                          (MAP_X + inset, MAP_Y + inset,
                           MAP_X + MAP_W - inset, MAP_Y + MAP_H - inset),
                          radius=max(4, 18 - inset),
                          fill=None, outline=clr, width=lw)


# ---------------------------------------------------------------------------
# Market panel  (right side)
# ---------------------------------------------------------------------------
MP_X = 2300
MP_Y = 196
MP_W = 1740
MP_H = 1020

COAL_PRICES = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 8]
IRON_PRICES = [1, 1, 2, 2, 3, 3, 4, 5, 6, 6]


def draw_market_panel(draw):
    px, py, pw, ph = MP_X, MP_Y, MP_W, MP_H

    # Panel background
    draw_rounded_rect(draw, (px, py, px + pw, py + ph),
                      radius=22, fill=MARKET_BG, outline=MARKET_BORDER, width=3)
    draw_rounded_rect(draw, (px + 6, py + 6, px + pw - 6, py + ph - 6),
                      radius=16, fill=None, outline=GOLD_DIM, width=1)

    f_title  = load_font(46, bold=True)
    f_header = load_font(30, bold=True)
    f_price  = load_font_num(32, bold=True)
    f_idx    = load_font_num(18)

    center_text(draw, px + pw // 2, py + 46, "MARKET", f_title, GOLD)
    draw.line([(px + 40, py + 72), (px + pw - 40, py + 72)],
              fill=GOLD_DIM, width=1)

    def draw_market_row(label, prices, row_color, row_y):
        n = len(prices)
        cell_w = min((pw - 80) // n, 108)
        total_w = n * cell_w
        row_x = px + (pw - total_w) // 2

        center_text(draw, px + pw // 2, row_y - 28, label, f_header, row_color)

        for i, price in enumerate(prices):
            bx0 = row_x + i * cell_w + 4
            bx1 = bx0 + cell_w - 8
            cell_cx = bx0 + (bx1 - bx0) // 2
            cell_cy = row_y + 44

            dark = tuple(max(0, int(c * 0.22)) for c in row_color)
            draw_rounded_rect(draw, (bx0, row_y, bx1, row_y + 88),
                              radius=9, fill=dark, outline=row_color, width=2)

            # Price number
            center_text(draw, cell_cx, cell_cy, f"£{price}", f_price, row_color)
            # Space index (right-to-left: last space = cheapest remaining)
            center_text(draw, cell_cx, row_y + 78, str(n - i), f_idx,
                        (110, 100, 85))

    draw_market_row("COAL MARKET  /  煤炭市場", COAL_PRICES,
                    (185, 185, 195), py + 102)
    draw_market_row("IRON MARKET  /  鐵礦市場", IRON_PRICES,
                    (205, 115, 45),  py + 322)

    # Note
    f_note = load_font(22)
    center_text(draw, px + pw // 2, py + 520,
                "← cubes placed here drop price →",
                f_note, (130, 118, 95))


# ---------------------------------------------------------------------------
# Merchant panel  (right side)
# ---------------------------------------------------------------------------
MERCH_X = 2300
MERCH_Y = 1256
MERCH_W = 1740
MERCH_H = 740

def draw_merchant_panel(draw):
    px, py, pw, ph = MERCH_X, MERCH_Y, MERCH_W, MERCH_H

    draw_rounded_rect(draw, (px, py, px + pw, py + ph),
                      radius=22, fill=MARKET_BG, outline=MARKET_BORDER, width=3)
    draw_rounded_rect(draw, (px + 6, py + 6, px + pw - 6, py + ph - 6),
                      radius=16, fill=None, outline=GOLD_DIM, width=1)

    f_title = load_font(46, bold=True)
    f_name  = load_font(26, bold=True)
    f_zh    = load_font_cjk(20)
    f_bonus = load_font(22)
    f_slots = load_font(18)

    center_text(draw, px + pw // 2, py + 46, "MERCHANTS  /  商人", f_title, GOLD)
    draw.line([(px + 40, py + 72), (px + pw - 40, py + 72)],
              fill=GOLD_DIM, width=1)

    n = len(MERCHANTS)
    slot_w = pw // n
    circle_r = 58

    for i, m in enumerate(MERCHANTS):
        cx = px + i * slot_w + slot_w // 2
        cy = py + 180

        # Slot box background
        bx0 = px + i * slot_w + 8
        bx1 = bx0 + slot_w - 16
        draw_rounded_rect(draw, (bx0, py + 90, bx1, py + ph - 20),
                          radius=12, fill=(28, 18, 9), outline=GOLD_DIM, width=1)

        # Glow ring
        draw.ellipse([(cx - circle_r - 4, cy - circle_r - 4),
                      (cx + circle_r + 4, cy + circle_r + 4)],
                     outline=GOLD_DIM, width=2)
        # Circle
        draw.ellipse([(cx - circle_r, cy - circle_r),
                      (cx + circle_r, cy + circle_r)],
                     fill=MERCHANT_FILL, outline=GOLD, width=3)
        # Star
        f_star = load_font_num(38, bold=True)
        center_text(draw, cx, cy, "★", f_star, GOLD)

        # Name (EN)
        center_text(draw, cx, cy + circle_r + 22, m["name"], f_name, CREAM)
        # Name (ZH)
        center_text(draw, cx, cy + circle_r + 50, m["name_zh"], f_zh,
                    (190, 175, 140))
        # Bonus
        center_text(draw, cx, cy + circle_r + 80, m["bonus"], f_bonus,
                    (155, 215, 130))
        # Slot label
        center_text(draw, cx, cy + circle_r + 108, "[ Tile Slot ]", f_slots,
                    (100, 90, 72))


# ---------------------------------------------------------------------------
# Income track
# ---------------------------------------------------------------------------
INC_X = 2300
INC_Y = 2040
INC_W = 1740
INC_H = 910

INCOME_TABLE = [
    (0, -3), (1,-2), (2,-1), (3,  0), (4,  1),
    (5,  1), (6, 2), (7, 2), (8,  3), (9,  3),
    (10, 4), (11,4), (12,5), (13, 5), (14, 6),
    (15, 6), (16,7), (17,7), (18, 8), (19, 8),
    (20, 9), (21,9), (22,10),(23,10), (24,11),
    (25,11), (26,12),(27,12),(28,13), (29,13),
    (30,14), (31,15),(32,16),(33,17),
]


def draw_income_track(draw):
    px, py, pw, ph = INC_X, INC_Y, INC_W, INC_H

    draw_rounded_rect(draw, (px, py, px + pw, py + ph),
                      radius=22, fill=MARKET_BG, outline=MARKET_BORDER, width=3)
    draw_rounded_rect(draw, (px + 6, py + 6, px + pw - 6, py + ph - 6),
                      radius=16, fill=None, outline=GOLD_DIM, width=1)

    f_title = load_font(46, bold=True)
    f_val   = load_font_num(24, bold=True)
    f_space = load_font_num(16)

    center_text(draw, px + pw // 2, py + 46, "INCOME TRACK  /  收入軌跡",
                f_title, GOLD)
    draw.line([(px + 40, py + 72), (px + pw - 40, py + 72)],
              fill=GOLD_DIM, width=1)

    n    = len(INCOME_TABLE)
    cols = 17
    cw   = (pw - 60) // cols
    ch   = 82
    sx   = px + 30
    sy   = py + 88

    def income_color(income):
        if income < 0:   return (160, 40, 40)
        if income == 0:  return (90, 90, 90)
        if income <= 5:  return (45, 135, 65)
        if income <= 10: return (45, 95, 175)
        return (165, 45, 165)

    for idx, (space, income) in enumerate(INCOME_TABLE):
        col = idx % cols
        row = idx // cols
        cx  = sx + col * cw + cw // 2
        cy  = sy + row * (ch + 8) + ch // 2
        bx0 = sx + col * cw + 3
        bx1 = bx0 + cw - 6

        clr  = income_color(income)
        dark = tuple(max(0, int(c * 0.24)) for c in clr)
        draw_rounded_rect(draw,
                          (bx0, cy - ch // 2, bx1, cy + ch // 2),
                          radius=7, fill=dark, outline=clr, width=2)

        # Space number (small, top)
        center_text(draw, cx, cy - 18, str(space), f_space, (160, 150, 132))
        # Income value (large, center)
        istr = f"£{income}" if income >= 0 else f"-£{abs(income)}"
        center_text(draw, cx, cy + 12, istr, f_val, clr)


# ---------------------------------------------------------------------------
# VP Track  (bottom strip, 0-100)
# ---------------------------------------------------------------------------
def draw_vp_track(draw):
    strip_y = H - 152
    strip_h = 118
    n_cells = 101       # 0..100
    cell_w  = max(36, (W - 200) // n_cells)
    total_w = n_cells * cell_w
    start_x = (W - total_w) // 2

    # Background
    draw_rounded_rect(draw,
                      (start_x - 14, strip_y - 12,
                       start_x + total_w + 14, strip_y + strip_h + 12),
                      radius=14, fill=VP_BG, outline=VP_FG, width=3)

    f_num = load_font_num(20, bold=True)
    f_lbl = load_font(32, bold=True)

    for i in range(n_cells):
        cx   = start_x + i * cell_w + cell_w // 2
        cy   = strip_y + strip_h // 2
        bx0  = start_x + i * cell_w
        bx1  = bx0 + cell_w - 1

        # Alternating shading; every-10 distinctly brighter
        if i % 10 == 0:
            shade = (58, 44, 24)
            num_c = GOLD_BRIGHT
        elif i % 5 == 0:
            shade = (46, 34, 18)
            num_c = GOLD
        else:
            shade = (32, 22, 10) if i % 2 == 0 else (28, 18, 8)
            num_c = VP_FG

        draw.rectangle([bx0, strip_y, bx1, strip_y + strip_h], fill=shade)

        # Milestone dividers
        if i % 10 == 0 and i > 0:
            draw.line([(bx0, strip_y), (bx0, strip_y + strip_h)],
                      fill=GOLD_BRIGHT, width=2)
        elif i % 5 == 0 and i > 0:
            draw.line([(bx0, strip_y), (bx0, strip_y + strip_h)],
                      fill=GOLD_DIM, width=1)

        center_text(draw, cx, cy, str(i), f_num, num_c)

    # Redraw border on top
    draw_rounded_rect(draw,
                      (start_x - 14, strip_y - 12,
                       start_x + total_w + 14, strip_y + strip_h + 12),
                      radius=14, fill=None, outline=VP_FG, width=3)

    # Label
    draw.text((start_x - 80, strip_y + strip_h // 2 - 18),
              "VP", font=f_lbl, fill=GOLD)


# ---------------------------------------------------------------------------
# Legend
# ---------------------------------------------------------------------------
def draw_legend(draw):
    lx = MAP_X + 20
    ly = MAP_Y + MAP_H + 14
    f_lbl = load_font(22, bold=True)
    f_sm  = load_font(20)

    items = [
        ("Canal + Rail", CANAL_COLOR, "both"),
        ("Rail only",    RAIL_COLOR,  "rail"),
        ("Canal only",   CANAL_COLOR, "canal"),
    ]
    for i, (lbl, clr, style) in enumerate(items):
        x0 = lx + i * 360
        y  = ly + 18
        x1 = x0 + 80
        if style == "both":
            draw.line([(x0, y),     (x1, y)    ], fill=CANAL_COLOR, width=4)
            draw.line([(x0, y + 9), (x1, y + 9)], fill=RAIL_COLOR,  width=3)
        elif style == "rail":
            draw_dashed_line(draw, x0, y, x1, y, RAIL_COLOR, 3, dash=10, gap=8)
        else:
            draw_dashed_line(draw, x0, y, x1, y, CANAL_COLOR, 4, dash=16, gap=6)
        draw.text((x1 + 12, y - 10), lbl, font=f_sm, fill=(170, 158, 132))

    # Industry colour swatch row
    ind_x = lx + 1200
    for i, (ind, color) in enumerate(IND_COLORS.items()):
        ix = ind_x + i * 220
        iy = ly + 8
        draw.ellipse([(ix, iy), (ix + 18, iy + 18)],
                     fill=color, outline=(200, 190, 170), width=1)
        draw.text((ix + 24, iy), ind.title(), font=f_sm, fill=(165, 152, 125))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("Generating premium main_board.png ...")

    print("  Rendering background gradient + noise...")
    img  = make_background()
    draw = ImageDraw.Draw(img)

    print("  Drawing gold border...")
    draw_gold_border(draw)

    print("  Drawing title...")
    draw_title(draw)

    print("  Drawing map frame...")
    draw_map_frame(draw)

    print("  Drawing routes...")
    draw_routes(draw)

    print("  Drawing cities...")
    draw_cities(draw)

    print("  Drawing market panel...")
    draw_market_panel(draw)

    print("  Drawing merchant panel...")
    draw_merchant_panel(draw)

    print("  Drawing income track...")
    draw_income_track(draw)

    print("  Drawing VP track (0-100)...")
    draw_vp_track(draw)

    print("  Drawing legend...")
    draw_legend(draw)

    out_path = OUT_DIR / "main_board.png"
    print(f"  Saving {out_path} ...")
    img.save(str(out_path), optimize=False)
    print(f"\nDone. Saved to {out_path}")


if __name__ == "__main__":
    main()
