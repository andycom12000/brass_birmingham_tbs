"""
generate_board.py
Generates the main board image for the Brass: Birmingham TTS mod prototype.
Output: assets/board/main_board.png  (4096 x 3072)
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

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
BG            = (42,  31,  20)      # dark warm brown
PANEL_BG      = (55,  42,  28)      # slightly lighter panel
PANEL_BORDER  = (90,  70,  40)      # panel outline
CITY_FILL     = (72,  56,  35)      # city circle fill
CITY_OUTLINE  = (195, 160, 90)      # city circle outline
CITY_TEXT     = (240, 230, 210)     # city name text
CANAL_COLOR   = (60,  130, 200)     # blue for canal routes
RAIL_COLOR    = (150, 150, 155)     # gray for rail-only routes
BOTH_COLOR    = (80,  160, 215)     # lighter blue for both-era routes
ROUTE_DASH    = 18                  # dash length in pixels
TITLE_COLOR   = (225, 185, 80)      # gold title
GOLD          = (220, 175, 40)
WHITE         = (250, 245, 235)
BLACK         = (10,  10,  10)
MARKET_BG     = (38,  28,  16)
MARKET_BORDER = (110, 85,  45)
COAL_MARKET   = (50,  50,  55)
IRON_MARKET   = (160, 80,  25)
VP_TRACK_BG   = (35,  25,  14)
VP_TRACK_FG   = (195, 160, 90)

# Industry slot colours
IND_COLORS = {
    "cotton":       (200, 200, 215),
    "coal":         (50,  50,  55),
    "iron":         (165, 85,  25),
    "brewery":      (185, 145, 20),
    "manufacturer": (100, 45,  135),
    "pottery":      (175, 65,  35),
}

# ---------------------------------------------------------------------------
# Font helpers
# ---------------------------------------------------------------------------
def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates_bold = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/calibrib.ttf",
        "C:/Windows/Fonts/verdanab.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    candidates_regular = [
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/calibri.ttf",
        "C:/Windows/Fonts/verdana.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    candidates = candidates_bold if bold else candidates_regular
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def center_text(draw, cx, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2 - bbox[0], cy - th // 2 - bbox[1]),
              text, font=font, fill=fill)


# ---------------------------------------------------------------------------
# City data: (x, y) positions on 4096x3072 canvas
# These positions approximate the real Brass: Birmingham geography.
# ---------------------------------------------------------------------------
CITIES = {
    # ---- Left column ----
    "Shrewsbury":     (300,  620),
    "Coalbrookdale":  (370,  870),
    "Kidderminster":  (430, 1220),
    "Worcester":      (420, 1520),
    "Gloucester":     (390, 1830),

    # ---- Center-left ----
    "Wolverhampton":  (680,  920),
    "Dudley":         (720, 1150),
    "Birmingham":     (800, 1380),
    "Redditch":       (780, 1640),

    # ---- Center ----
    "Walsall":        (920,  960),
    "Cannock":        (960,  750),
    "Tamworth":       (1120, 1160),

    # ---- Center-right ----
    "Stafford":       (1100,  580),
    "Stone":          (1200,  800),
    "Burton-on-Trent":(1320, 1020),
    "Nuneaton":       (1280, 1280),
    "Coventry":       (1300, 1520),

    # ---- Right column ----
    "Stoke-on-Trent": (1380,  540),
    "Leek":           (1620,  560),
    "Uttoxeter":      (1560,  840),
    "Derby":          (1760,  980),
    "Belper":         (1800,  770),
    "Nottingham":     (1980, 1100),

    # ---- Merchant cities ----
    "Warrington":     (800,  280),
    "Oxford":         (1060, 1840),
}

# ---------------------------------------------------------------------------
# Route data (from BoardData.lua)
# Each entry: (cityA, cityB, era_types)
#   era_types: "both" | "canal" | "rail"
# ---------------------------------------------------------------------------
ROUTES = [
    # Birmingham connections
    ("Birmingham",  "Coventry",         "both"),
    ("Birmingham",  "Dudley",           "both"),
    ("Birmingham",  "Redditch",         "both"),
    ("Birmingham",  "Tamworth",         "both"),
    ("Birmingham",  "Walsall",          "both"),
    ("Birmingham",  "Wolverhampton",    "both"),
    ("Birmingham",  "Worcester",        "both"),
    ("Birmingham",  "Cannock",          "rail"),

    # Coventry
    ("Coventry",    "Nuneaton",         "both"),
    ("Coventry",    "Oxford",           "both"),

    # Dudley
    ("Dudley",      "Kidderminster",    "both"),
    ("Dudley",      "Wolverhampton",    "both"),
    ("Dudley",      "Walsall",          "rail"),

    # Kidderminster
    ("Kidderminster", "Worcester",      "both"),
    ("Coalbrookdale", "Kidderminster",  "both"),

    # Wolverhampton
    ("Cannock",     "Wolverhampton",    "both"),
    ("Shrewsbury",  "Wolverhampton",    "both"),
    ("Coalbrookdale","Wolverhampton",   "both"),

    # Coalbrookdale
    ("Coalbrookdale","Shrewsbury",      "both"),

    # Cannock
    ("Cannock",     "Walsall",          "both"),
    ("Cannock",     "Stafford",         "both"),

    # Burton-on-Trent
    ("Burton-on-Trent","Tamworth",      "both"),
    ("Burton-on-Trent","Cannock",       "rail"),
    ("Burton-on-Trent","Uttoxeter",     "both"),

    # Tamworth
    ("Nuneaton",    "Tamworth",         "both"),

    # Nuneaton
    ("Nottingham",  "Nuneaton",         "rail"),

    # Stafford
    ("Stafford",    "Stone",            "both"),
    ("Stafford",    "Uttoxeter",        "rail"),

    # Stoke-on-Trent
    ("Leek",        "Stoke-on-Trent",   "both"),
    ("Stone",       "Stoke-on-Trent",   "both"),
    ("Stoke-on-Trent","Warrington",     "both"),
    ("Shrewsbury",  "Warrington",       "both"),

    # Leek
    ("Leek",        "Uttoxeter",        "rail"),

    # Stone
    ("Stone",       "Uttoxeter",        "both"),

    # Uttoxeter
    ("Derby",       "Uttoxeter",        "both"),

    # Belper
    ("Belper",      "Derby",            "both"),
    ("Belper",      "Leek",             "rail"),

    # Derby
    ("Derby",       "Nottingham",       "both"),
    ("Burton-on-Trent","Derby",         "rail"),

    # Redditch
    ("Gloucester",  "Redditch",         "both"),
    ("Oxford",      "Redditch",         "both"),
    ("Redditch",    "Worcester",        "both"),

    # Worcester
    ("Gloucester",  "Worcester",        "both"),

    # Walsall
    ("Walsall",     "Wolverhampton",    "rail"),
]

# ---------------------------------------------------------------------------
# Industry slots per city (from BoardData.lua)
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
    # Merchant-only (no industry slots)
    "Shrewsbury":     [],
    "Gloucester":     [],
    "Oxford":         [],
    "Warrington":     [],
    "Nottingham":     [],
}

# Merchants with bonus text
MERCHANTS = [
    {"name": "Shrewsbury", "bonus": "+4 VP"},
    {"name": "Gloucester", "bonus": "Free Dev"},
    {"name": "Oxford",     "bonus": "+2 Income"},
    {"name": "Warrington", "bonus": "+£5"},
    {"name": "Nottingham", "bonus": "+3 VP"},
]

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------
def draw_dashed_line(draw, x0, y0, x1, y1, fill, width, dash=18, gap=10):
    """Draw a dashed line from (x0,y0) to (x1,y1)."""
    import math
    length = math.hypot(x1 - x0, y1 - y0)
    if length == 0:
        return
    dx = (x1 - x0) / length
    dy = (y1 - y0) / length
    pos = 0
    drawing = True
    while pos < length:
        seg = dash if drawing else gap
        end = min(pos + seg, length)
        if drawing:
            sx0 = x0 + dx * pos
            sy0 = y0 + dy * pos
            sx1 = x0 + dx * end
            sy1 = y0 + dy * end
            draw.line([(sx0, sy0), (sx1, sy1)], fill=fill, width=width)
        pos = end
        drawing = not drawing


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(list(xy), radius=radius,
                           fill=fill, outline=outline, width=width)


# ---------------------------------------------------------------------------
# Section: VP Track (bottom strip)
# ---------------------------------------------------------------------------
def draw_vp_track(img, draw):
    """Draw a 0-30+ VP track as a strip across the bottom of the board."""
    strip_y  = H - 140
    strip_h  = 110
    cell_w   = 96
    n_cells  = 40   # 0..39 shown (wraps at 30+)

    total_w  = n_cells * cell_w
    start_x  = (W - total_w) // 2
    strip_x  = start_x - 12

    # Background strip
    draw_rounded_rect(draw,
                      (strip_x, strip_y - 10,
                       strip_x + total_w + 24, strip_y + strip_h + 10),
                      radius=12, fill=VP_TRACK_BG, outline=VP_TRACK_FG, width=3)

    f_label = load_font(22, bold=True)
    f_num   = load_font(26, bold=True)

    for i in range(n_cells):
        cx = start_x + i * cell_w + cell_w // 2
        cy = strip_y + strip_h // 2

        # Alternating cell shading
        shade = (48, 36, 20) if i % 2 == 0 else (38, 28, 14)
        cell_x0 = start_x + i * cell_w
        draw.rectangle([cell_x0, strip_y, cell_x0 + cell_w - 2, strip_y + strip_h],
                       fill=shade)

        # Milestone marks at multiples of 5
        if i % 5 == 0:
            draw.line([(cx, strip_y), (cx, strip_y + strip_h)],
                      fill=VP_TRACK_FG, width=2)

        # Number
        center_text(draw, cx, cy, str(i), f_num, VP_TRACK_FG)

    # Outer border again on top
    draw_rounded_rect(draw,
                      (strip_x, strip_y - 10,
                       strip_x + total_w + 24, strip_y + strip_h + 10),
                      radius=12, fill=None, outline=VP_TRACK_FG, width=3)

    # Label
    lbl = load_font(30, bold=True)
    draw.text((strip_x - 120, strip_y + strip_h // 2 - 16), "VP", font=lbl, fill=GOLD)


# ---------------------------------------------------------------------------
# Section: Market panel (right side)
# ---------------------------------------------------------------------------
MARKET_PANEL_X  = 2300
MARKET_PANEL_Y  = 200
MARKET_PANEL_W  = 1680
MARKET_PANEL_H  = 1000

def draw_market_panel(draw):
    """Draw coal and iron market tracks."""
    px, py, pw, ph = (MARKET_PANEL_X, MARKET_PANEL_Y,
                      MARKET_PANEL_W, MARKET_PANEL_H)

    draw_rounded_rect(draw, (px, py, px + pw, py + ph),
                      radius=20, fill=MARKET_BG, outline=MARKET_BORDER, width=4)

    f_title  = load_font(44, bold=True)
    f_header = load_font(34, bold=True)
    f_price  = load_font(36, bold=True)
    f_small  = load_font(24)

    center_text(draw, px + pw // 2, py + 44, "MARKET", f_title, GOLD)

    COAL_PRICES = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 8]
    IRON_PRICES = [1, 1, 2, 2, 3, 3, 4, 5, 6, 6]

    def draw_market_row(label, prices, color, row_y):
        n = len(prices)
        cell_w = min(pw - 80, n * 110) // n
        total_w = n * cell_w
        row_x = px + (pw - total_w) // 2

        # Row label
        center_text(draw, px + pw // 2, row_y - 30, label, f_header, color)

        for i, price in enumerate(prices):
            cx = row_x + i * cell_w + cell_w // 2
            # Cell box
            bx0 = row_x + i * cell_w + 4
            bx1 = bx0 + cell_w - 8
            draw_rounded_rect(draw, (bx0, row_y, bx1, row_y + 80),
                              radius=8,
                              fill=(int(color[0] * 0.25),
                                    int(color[1] * 0.25),
                                    int(color[2] * 0.25)),
                              outline=color, width=2)
            # Price number
            center_text(draw, cx, row_y + 40, f"£{price}", f_price, color)
            # Space index (last filled = most expensive)
            center_text(draw, cx, row_y + 70, str(n - i), f_small,
                        (140, 130, 115))

    draw_market_row("COAL MARKET", COAL_PRICES, (180, 180, 185), py + 120)
    draw_market_row("IRON MARKET", IRON_PRICES, (200, 110, 40),  py + 320)

    # Current price arrow indicator note
    note_y = py + 500
    center_text(draw, px + pw // 2, note_y,
                "← prices drop as cubes are placed →",
                f_small, (160, 145, 120))


# ---------------------------------------------------------------------------
# Section: Merchant panel (right side, below market)
# ---------------------------------------------------------------------------
MERCH_PANEL_X = 2300
MERCH_PANEL_Y = 1240
MERCH_PANEL_W = 1680
MERCH_PANEL_H = 700

def draw_merchant_panel(draw):
    px, py, pw, ph = (MERCH_PANEL_X, MERCH_PANEL_Y,
                      MERCH_PANEL_W, MERCH_PANEL_H)

    draw_rounded_rect(draw, (px, py, px + pw, py + ph),
                      radius=20, fill=MARKET_BG, outline=MARKET_BORDER, width=4)

    f_title  = load_font(44, bold=True)
    f_name   = load_font(30, bold=True)
    f_bonus  = load_font(26)
    f_small  = load_font(22)

    center_text(draw, px + pw // 2, py + 44, "MERCHANTS", f_title, GOLD)

    slot_w = pw // len(MERCHANTS)
    for i, m in enumerate(MERCHANTS):
        cx = px + i * slot_w + slot_w // 2
        cy = py + 160

        # Merchant circle
        r = 60
        draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)],
                     fill=PANEL_BG, outline=GOLD, width=3)

        # Initials inside circle
        initial = m["name"][0]
        f_init = load_font(48, bold=True)
        center_text(draw, cx, cy, initial, f_init, GOLD)

        # Name below
        center_text(draw, cx, cy + r + 24, m["name"], f_name, CITY_TEXT)
        # Bonus
        center_text(draw, cx, cy + r + 56, m["bonus"], f_bonus, (180, 210, 140))
        # Slots
        center_text(draw, cx, cy + r + 84, "Slot", f_small, (150, 140, 120))


# ---------------------------------------------------------------------------
# Section: Income track (right side, below merchants)
# ---------------------------------------------------------------------------
INCOME_PANEL_X = 2300
INCOME_PANEL_Y = 1980
INCOME_PANEL_W = 1680
INCOME_PANEL_H = 900

def draw_income_track(draw):
    px, py, pw, ph = (INCOME_PANEL_X, INCOME_PANEL_Y,
                      INCOME_PANEL_W, INCOME_PANEL_H)

    draw_rounded_rect(draw, (px, py, px + pw, py + ph),
                      radius=20, fill=MARKET_BG, outline=MARKET_BORDER, width=4)

    f_title  = load_font(44, bold=True)
    f_val    = load_font(28, bold=True)
    f_small  = load_font(20)

    center_text(draw, px + pw // 2, py + 44, "INCOME TRACK", f_title, GOLD)

    # Income steps: spaces 0-30, with income values
    # Official income track: positions 0-30+ map to specific £/turn values
    income_table = [
        (0,  -3), (1, -2), (2, -1), (3,  0), (4,  1),
        (5,   1), (6,  2), (7,  2), (8,  3), (9,  3),
        (10,  4), (11, 4), (12, 5), (13, 5), (14, 6),
        (15,  6), (16, 7), (17, 7), (18, 8), (19, 8),
        (20,  9), (21, 9), (22,10), (23,10), (24,11),
        (25, 11), (26,12), (27,12), (28,13), (29,13),
        (30, 14), (31,15), (32,16), (33,17),
    ]

    n      = len(income_table)
    cols   = 17
    rows   = (n + cols - 1) // cols
    cell_w = (pw - 60) // cols
    cell_h = 80
    start_x = px + 30
    start_y = py + 100

    for idx, (space, income) in enumerate(income_table):
        col = idx % cols
        row = idx // cols
        cx  = start_x + col * cell_w + cell_w // 2
        cy  = start_y + row * (cell_h + 10) + cell_h // 2
        bx0 = start_x + col * cell_w + 3
        bx1 = bx0 + cell_w - 6

        # Color based on income tier
        if income < 0:
            clr = (160, 40,  40)
        elif income == 0:
            clr = (90,  90,  90)
        elif income <= 5:
            clr = (40,  130, 60)
        elif income <= 10:
            clr = (40,  90, 170)
        else:
            clr = (160, 40, 160)

        draw_rounded_rect(draw, (bx0, cy - cell_h // 2, bx1, cy + cell_h // 2),
                          radius=6,
                          fill=(max(0, clr[0] - 30),
                                max(0, clr[1] - 30),
                                max(0, clr[2] - 30)),
                          outline=clr, width=2)
        center_text(draw, cx, cy - 12, str(space), f_small, (180, 170, 155))
        income_str = f"£{income}" if income >= 0 else f"-£{abs(income)}"
        center_text(draw, cx, cy + 14, income_str, f_val, clr)


# ---------------------------------------------------------------------------
# Main board drawing
# ---------------------------------------------------------------------------
def draw_routes(draw, cities):
    """Draw all route connections."""
    f_none = None
    for (city_a, city_b, era) in ROUTES:
        if city_a not in cities or city_b not in cities:
            continue
        x0, y0 = cities[city_a]
        x1, y1 = cities[city_b]

        if era == "canal":
            color = CANAL_COLOR
            width = 6
            draw_dashed_line(draw, x0, y0, x1, y1, color, width, dash=20, gap=8)
        elif era == "rail":
            color = RAIL_COLOR
            width = 5
            draw_dashed_line(draw, x0, y0, x1, y1, color, width, dash=12, gap=10)
        else:  # "both"
            # Draw a slightly offset pair: canal on top, rail below
            import math
            length = math.hypot(x1 - x0, y1 - y0) or 1
            perp_x = -(y1 - y0) / length * 4
            perp_y =  (x1 - x0) / length * 4

            # Canal line (blue, offset +perp)
            draw_dashed_line(draw,
                             x0 + perp_x, y0 + perp_y,
                             x1 + perp_x, y1 + perp_y,
                             CANAL_COLOR, 5, dash=20, gap=8)
            # Rail line (gray, offset -perp)
            draw_dashed_line(draw,
                             x0 - perp_x, y0 - perp_y,
                             x1 - perp_x, y1 - perp_y,
                             RAIL_COLOR, 4, dash=12, gap=10)


def draw_cities(draw, cities):
    """Draw city nodes (circles + name + industry slots)."""
    CITY_R    = 46   # city circle radius
    SLOT_SIZE = 14   # industry slot square size
    SLOT_GAP  = 5

    f_city    = load_font(24, bold=True)
    f_merch   = load_font(20)

    merchant_names = {m["name"] for m in MERCHANTS}

    for name, (cx, cy) in cities.items():
        # Shadow
        draw.ellipse([(cx - CITY_R + 3, cy - CITY_R + 3),
                      (cx + CITY_R + 3, cy + CITY_R + 3)],
                     fill=(15, 10, 5))

        # Main circle
        is_merchant = name in merchant_names and not CITY_SLOTS.get(name)
        fill_color = (55, 40, 20) if is_merchant else CITY_FILL
        outline_color = (175, 140, 75) if is_merchant else CITY_OUTLINE
        draw.ellipse([(cx - CITY_R, cy - CITY_R),
                      (cx + CITY_R, cy + CITY_R)],
                     fill=fill_color, outline=outline_color, width=3)

        # City name (below circle)
        name_y = cy + CITY_R + 18
        center_text(draw, cx, name_y, name, f_city, CITY_TEXT)

        # Industry slot indicators (small colored squares above/to the side)
        slots = CITY_SLOTS.get(name, [])
        if slots:
            n_slots = len(slots)
            total_w = n_slots * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
            slot_x0 = cx - total_w // 2
            slot_y  = cy - CITY_R - SLOT_SIZE - 8
            for j, ind in enumerate(slots):
                sx = slot_x0 + j * (SLOT_SIZE + SLOT_GAP)
                sy = slot_y
                color = IND_COLORS.get(ind, (120, 120, 120))
                draw.rectangle([sx, sy, sx + SLOT_SIZE, sy + SLOT_SIZE],
                               fill=color, outline=(200, 190, 170), width=1)

        # Merchant label
        if is_merchant:
            for m in MERCHANTS:
                if m["name"] == name:
                    bonus_y = cy + CITY_R + 42
                    center_text(draw, cx, bonus_y, m["bonus"], f_merch,
                                (160, 210, 130))
                    break


# ---------------------------------------------------------------------------
# Legend
# ---------------------------------------------------------------------------
def draw_legend(draw):
    lx, ly = 80, H - 300
    f_lbl = load_font(26, bold=True)
    f_sm  = load_font(22)

    items = [
        ("Canal + Rail route",  CANAL_COLOR,  "both"),
        ("Rail-only route",     RAIL_COLOR,   "rail"),
        ("Canal-only route",    CANAL_COLOR,  "canal"),
    ]

    for i, (label, color, style) in enumerate(items):
        x0 = lx
        y  = ly + i * 44
        x1 = x0 + 80
        if style == "both":
            draw.line([(x0, y), (x1, y)], fill=CANAL_COLOR, width=4)
            draw.line([(x0, y + 8), (x1, y + 8)], fill=RAIL_COLOR, width=3)
        elif style == "rail":
            draw_dashed_line(draw, x0, y, x1, y, RAIL_COLOR, 3, dash=10, gap=8)
        else:
            draw_dashed_line(draw, x0, y, x1, y, CANAL_COLOR, 4, dash=16, gap=6)
        draw.text((x1 + 16, y - 12), label, font=f_sm, fill=(180, 170, 150))

    # Industry colour legend
    ind_lx = lx + 500
    f_ind  = load_font(22)
    for i, (ind, color) in enumerate(IND_COLORS.items()):
        ix = ind_lx + (i % 3) * 260
        iy = ly + (i // 3) * 44
        draw.rectangle([ix, iy - 10, ix + 20, iy + 10],
                       fill=color, outline=(200, 190, 170), width=1)
        draw.text((ix + 28, iy - 12), ind.title(), font=f_ind,
                  fill=(180, 170, 150))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("Generating main_board.png ...")
    img  = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    # ---- Background texture lines ----
    for y in range(0, H, 60):
        draw.line([(0, y), (W, y)], fill=(46, 34, 22), width=1)
    for x in range(0, W, 60):
        draw.line([(x, 0), (x, H)], fill=(46, 34, 22), width=1)

    # ---- Outer border ----
    border_clr = (120, 90, 45)
    for t in range(6):
        draw.rectangle([t, t, W - 1 - t, H - 1 - t], outline=border_clr)
    draw.rectangle([14, 14, W - 15, H - 15], outline=GOLD, width=3)

    # ---- Title ----
    f_title    = load_font(110, bold=True)
    f_subtitle = load_font(46)
    center_text(draw, W // 2, 90, "BRASS: BIRMINGHAM", f_title, TITLE_COLOR)
    center_text(draw, W // 2, 165, "Tabletop Simulator Prototype", f_subtitle,
                (160, 140, 100))

    # ---- Map area label ----
    map_x = 80
    map_y = 200
    map_w = 2160
    map_h = H - 360
    draw_rounded_rect(draw, (map_x, map_y, map_x + map_w, map_y + map_h),
                      radius=16, fill=None, outline=PANEL_BORDER, width=2)

    # ---- Routes (draw first, under cities) ----
    print("  Drawing routes...")
    draw_routes(draw, CITIES)

    # ---- Cities ----
    print("  Drawing cities...")
    draw_cities(draw, CITIES)

    # ---- Market panel ----
    print("  Drawing market panel...")
    draw_market_panel(draw)

    # ---- Merchant panel ----
    print("  Drawing merchant panel...")
    draw_merchant_panel(draw)

    # ---- Income track ----
    print("  Drawing income track...")
    draw_income_track(draw)

    # ---- VP track ----
    print("  Drawing VP track...")
    draw_vp_track(img, draw)

    # ---- Legend ----
    print("  Drawing legend...")
    draw_legend(draw)

    # ---- Route type key labels ----
    f_key = load_font(28, bold=True)
    draw.text((2340, H - 200),
              "Blue dashes = Canal   Gray dashes = Rail",
              font=f_key, fill=(160, 150, 130))

    # ---- Save ----
    out_path = OUT_DIR / "main_board.png"
    img.save(out_path)
    print(f"\nDone. Saved to {out_path}")


if __name__ == "__main__":
    main()
