"""
generate_misc.py  —  Premium miscellaneous assets for Brass: Birmingham TTS mod.
Output: assets/misc/

Assets:
  player_board_Red/Yellow/Blue/Green.png  (1024x768)
  canal_Red/Yellow/Blue/Green.png         (200x80)
  rail_Red/Yellow/Blue/Green.png          (200x80)
  merchant_Shrewsbury/Gloucester/Oxford/Warrington/Nottingham.png  (200x150)
  help_card_en.png / help_card_zh.png     (600x900)
"""

import os
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR   = REPO_ROOT / "assets" / "misc"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
BG_DARK    = (26,  16,   8)
BG_PANEL   = (36,  24,  12)
BG_SLOT    = (20,  13,   6)
GOLD       = (220, 180,  60)
GOLD_DIM   = (155, 122,  38)
GOLD_BRITE = (255, 220, 100)
CREAM      = (245, 235, 210)
WHITE      = (252, 248, 240)
BLACK      = (8,    6,   4)
LIGHT_TXT  = (240, 228, 200)
MID_TXT    = (172, 160, 136)
DIM_TXT    = (110, 100,  82)

PLAYER_COLORS = {
    "Red":    (210,  52,  52),
    "Yellow": (215, 178,  28),
    "Blue":   (52,  105, 210),
    "Green":  (48,  168,  68),
}

INDUSTRY_COLORS = {
    "cotton":       (192, 198, 218),
    "coal":         (55,   55,  62),
    "iron":         (170,  88,  28),
    "brewery":      (188, 148,  22),
    "manufacturer": (105,  48, 140),
    "pottery":      (178,  68,  38),
}

INDUSTRY_NAMES_ZH = {
    "cotton":       "棉花",
    "coal":         "煤炭",
    "iron":         "鐵礦",
    "brewery":      "釀酒廠",
    "manufacturer": "製造商",
    "pottery":      "陶瓷",
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
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load_font_num(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    paths = (["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/calibrib.ttf"]
             if bold else
             ["C:/Windows/Fonts/arial.ttf",   "C:/Windows/Fonts/calibri.ttf"])
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return load_font(size, bold)


def load_font_cjk(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/msjh.ttc",
        "C:/Windows/Fonts/msjhbd.ttc",
        "C:/Windows/Fonts/mingliu.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return load_font(size)


def center_text(draw, cx, cy, text, font, fill, shadow=None):
    bb = draw.textbbox((0, 0), text, font=font)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    x = cx - tw // 2 - bb[0]
    y = cy - th // 2 - bb[1]
    if shadow:
        draw.text((x + 1, y + 1), text, font=font, fill=shadow)
    draw.text((x, y), text, font=font, fill=fill)


def draw_rrect(draw, xy, r, fill=None, outline=None, width=1):
    draw.rounded_rectangle(list(xy), radius=r,
                           fill=fill, outline=outline, width=width)


def parchment_bg(img: Image.Image, rng: random.Random, alpha: float = 0.18):
    """Blend a subtle noise layer over img in-place."""
    W, H = img.size
    noise = Image.new("RGB", (W, H))
    np = noise.load()
    pp = img.load()
    for y in range(H):
        for x in range(W):
            v = rng.randint(-12, 12)
            base = pp[x, y]
            np[x, y] = (
                max(0, min(255, base[0] + v)),
                max(0, min(255, base[1] + v // 2)),
                max(0, min(255, base[2] + v // 4)),
            )
    return Image.blend(img, noise, alpha)


def gold_panel_border(draw, W, H, pcolor=None):
    """Draw stacked border lines: player color -> dark gold -> bright gold -> dark gold."""
    if pcolor:
        for t in range(5):
            draw.rectangle([t, t, W - 1 - t, H - 1 - t], outline=pcolor)
    for inset, clr, lw in [(6, (90, 68, 28), 2), (10, GOLD, 2), (14, GOLD_DIM, 1)]:
        draw.rectangle([inset, inset, W - 1 - inset, H - 1 - inset],
                       outline=clr, width=lw)


# ---------------------------------------------------------------------------
# 1. Player Boards  (1024 x 768)
# ---------------------------------------------------------------------------
PB_W, PB_H = 1024, 768

INDUSTRY_COLUMNS = [
    ("Cotton",       "cotton",       4),
    ("Coal",         "coal",         4),
    ("Iron",         "iron",         4),
    ("Brewery",      "brewery",      4),
    ("Manufacturer", "manufacturer", 8),
    ("Pottery",      "pottery",      5),
]


def _is_dark(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] < 128


def make_player_board(color_name: str) -> Image.Image:
    pcolor = PLAYER_COLORS[color_name]
    rng    = random.Random(hash(color_name) & 0xFFFF)

    img  = Image.new("RGB", (PB_W, PB_H), BG_DARK)
    img  = parchment_bg(img, rng, 0.22)
    draw = ImageDraw.Draw(img)

    # Panel background inset
    draw_rrect(draw, (16, 16, PB_W - 17, PB_H - 17),
               r=14, fill=BG_PANEL)

    # Player color accent stripe at top
    draw.rectangle([16, 16, PB_W - 17, 62], fill=pcolor)
    # Fade stripe to panel
    for i in range(10):
        a = int(pcolor[0] * (1 - i / 10) + BG_PANEL[0] * (i / 10))
        b_ = int(pcolor[1] * (1 - i / 10) + BG_PANEL[1] * (i / 10))
        c_ = int(pcolor[2] * (1 - i / 10) + BG_PANEL[2] * (i / 10))
        draw.rectangle([16, 52 + i, PB_W - 17, 54 + i], fill=(a, b_, c_))

    gold_panel_border(draw, PB_W, PB_H, pcolor)

    f_title  = load_font(38, bold=True)
    f_color  = load_font(22, bold=True)
    f_col    = load_font(17, bold=True)
    f_zh_hd  = load_font_cjk(15)
    f_slot   = load_font_num(15)
    f_zh_sl  = load_font_cjk(13)

    # Title (over accent stripe)
    center_text(draw, PB_W // 2, 39, "PLAYER BOARD", f_title, WHITE,
                shadow=(20, 10, 4))
    center_text(draw, PB_W - 90, 39, f"— {color_name} —", f_color, WHITE,
                shadow=(20, 10, 4))

    # Industry columns
    n_cols    = len(INDUSTRY_COLUMNS)
    area_x    = 28
    area_y    = 76
    area_w    = PB_W - 56
    area_h    = PB_H - area_y - 30
    col_w     = area_w // n_cols

    for ci, (ind_en, ind_key, n_levels) in enumerate(INDUSTRY_COLUMNS):
        ind_color = INDUSTRY_COLORS[ind_key]
        ind_zh    = INDUSTRY_NAMES_ZH[ind_key]
        cx_l = area_x + ci * col_w
        cx_r = cx_l + col_w - 5

        # Column header
        hdr_y0 = area_y
        hdr_y1 = area_y + 50
        draw_rrect(draw, (cx_l, hdr_y0, cx_r, hdr_y1),
                   r=7, fill=ind_color)
        hdr_cx = (cx_l + cx_r) // 2
        txt_clr = WHITE if _is_dark(ind_color) else BLACK
        draw.text((hdr_cx - draw.textbbox((0,0), ind_en, font=f_col)[2] // 2,
                   hdr_y0 + 6),
                  ind_en, font=f_col, fill=txt_clr)
        # Chinese sub-header
        zh_bb = draw.textbbox((0, 0), ind_zh, font=f_zh_hd)
        draw.text((hdr_cx - (zh_bb[2] - zh_bb[0]) // 2, hdr_y0 + 28),
                  ind_zh, font=f_zh_hd, fill=txt_clr)

        # Tile slots
        slot_margin = 5
        avail_h     = area_h - 55
        slot_h      = min(66, (avail_h - (n_levels - 1) * 5) // n_levels)
        slot_w_px   = col_w - 2 * slot_margin - 5

        for li in range(n_levels):
            sy0 = area_y + 56 + li * (slot_h + 5)
            sy1 = sy0 + slot_h
            sx0 = cx_l + slot_margin
            sx1 = sx0 + slot_w_px

            dark = tuple(max(0, int(c * 0.16)) for c in ind_color)
            draw_rrect(draw, (sx0, sy0, sx1, sy1),
                       r=5, fill=dark, outline=ind_color, width=2)

            # Level number (big)
            lv_str = f"Lv{li + 1}"
            lv_bb  = draw.textbbox((0, 0), lv_str, font=f_slot)
            lv_cx  = (sx0 + sx1) // 2
            lv_cy  = (sy0 + sy1) // 2 - 6
            center_text(draw, lv_cx, lv_cy, lv_str, f_slot, ind_color)

    # Player color swatch bottom-right
    sw = 48
    sw_x = PB_W - 26 - sw
    sw_y = PB_H - 26 - sw
    draw_rrect(draw, (sw_x, sw_y, sw_x + sw, sw_y + sw),
               r=9, fill=pcolor, outline=GOLD, width=2)

    return img


# ---------------------------------------------------------------------------
# 2. Link tiles  (200 x 80)
# ---------------------------------------------------------------------------
LINK_W, LINK_H = 200, 80


def make_link_tile(color_name: str, link_type: str) -> Image.Image:
    pcolor = PLAYER_COLORS[color_name]
    rng    = random.Random(hash((color_name, link_type)) & 0xFFFF)

    if link_type == "canal":
        base_bg  = (22, 52, 105)
        grad_hi  = (38, 80, 148)
        accent   = (80, 155, 220)
        label_en = "CANAL"
        label_zh = "運河"
        symbol   = "≋  ≋  ≋"
    else:
        base_bg  = (44, 44, 50)
        grad_hi  = (68, 68, 75)
        accent   = (160, 160, 168)
        label_en = "RAIL"
        label_zh = "鐵路"
        symbol   = "— — —"

    img  = Image.new("RGB", (LINK_W, LINK_H), base_bg)
    draw = ImageDraw.Draw(img)

    # Simple horizontal gradient
    for x in range(LINK_W):
        t = x / LINK_W
        c = tuple(int(base_bg[i] + (grad_hi[i] - base_bg[i]) * math.sin(t * math.pi))
                  for i in range(3))
        draw.line([(x, 0), (x, LINK_H)], fill=c)

    img  = parchment_bg(img, rng, 0.12)
    draw = ImageDraw.Draw(img)

    # Player color stripe on left edge
    stripe_w = 6
    draw.rectangle([0, 0, stripe_w, LINK_H], fill=pcolor)

    # Decorative border
    draw.rectangle([0, 0, LINK_W - 1, LINK_H - 1], outline=pcolor, width=3)
    draw.rectangle([4, 4, LINK_W - 5, LINK_H - 5], outline=accent, width=1)

    f_en     = load_font(18, bold=True)
    f_zh     = load_font_cjk(15)
    f_sym    = load_font_num(16)
    f_player = load_font(11)

    # English label
    center_text(draw, LINK_W // 2 + 3, 20, label_en, f_en, WHITE, shadow=BLACK)
    # Chinese label
    center_text(draw, LINK_W // 2 + 3, 40, label_zh, f_zh, accent, shadow=BLACK)
    # Symbol/decoration
    center_text(draw, LINK_W // 2 + 3, 60, symbol, f_sym, accent)

    # Player color name (small, bottom-right)
    bb = draw.textbbox((0, 0), color_name, font=f_player)
    draw.text((LINK_W - 6 - (bb[2] - bb[0]), LINK_H - 5 - (bb[3] - bb[1])),
              color_name, font=f_player, fill=pcolor)

    return img


# ---------------------------------------------------------------------------
# 3. Merchant tiles  (200 x 150)
# ---------------------------------------------------------------------------
MERCH_W, MERCH_H = 200, 150

MERCHANT_DATA = [
    {"name": "Shrewsbury", "name_zh": "什魯斯伯里",
     "accepts": ["cotton", "manufacturer"],  "bonus": "+4 VP",       "slots": 1},
    {"name": "Gloucester", "name_zh": "格洛斯特",
     "accepts": ["pottery", "cotton"],       "bonus": "Free Develop", "slots": 2},
    {"name": "Oxford",     "name_zh": "牛津",
     "accepts": ["cotton", "manufacturer"],  "bonus": "+2 Income",    "slots": 2},
    {"name": "Warrington", "name_zh": "沃靈頓",
     "accepts": ["brewery", "manufacturer"], "bonus": "+£5",          "slots": 2},
    {"name": "Nottingham", "name_zh": "諾丁漢",
     "accepts": ["coal", "iron"],            "bonus": "+3 VP",        "slots": 2},
]

MERCHANT_BASE_COLORS = {
    "Shrewsbury": (28, 54, 28),
    "Gloucester": (22, 38, 62),
    "Oxford":     (44, 24, 54),
    "Warrington": (54, 38, 14),
    "Nottingham": (54, 18, 18),
}


def make_merchant_tile(data: dict) -> Image.Image:
    name   = data["name"]
    name_zh = data["name_zh"]
    bonus  = data["bonus"]
    bg_c   = MERCHANT_BASE_COLORS.get(name, (30, 22, 14))
    rng    = random.Random(hash(name) & 0xFFFF)

    img  = Image.new("RGB", (MERCH_W, MERCH_H), bg_c)
    img  = parchment_bg(img, rng, 0.20)
    draw = ImageDraw.Draw(img)

    # Outer gold border + inner line
    draw.rectangle([0, 0, MERCH_W - 1, MERCH_H - 1], outline=GOLD, width=3)
    draw.rectangle([5, 5, MERCH_W - 6, MERCH_H - 6], outline=GOLD_DIM, width=1)

    f_name  = load_font(14, bold=True)
    f_zh    = load_font_cjk(13)
    f_bonus = load_font(13, bold=True)
    f_small = load_font(11)
    f_ind   = load_font_num(10)

    # Name header bar
    draw_rrect(draw, (3, 3, MERCH_W - 4, 32), r=5, fill=(14, 9, 4))
    center_text(draw, MERCH_W // 2, 12, name.upper(), f_name, GOLD,
                shadow=(4, 3, 1))

    # Chinese name
    center_text(draw, MERCH_W // 2, 30, name_zh, f_zh, GOLD_DIM)

    # Separator
    draw.line([(10, 38), (MERCH_W - 10, 38)], fill=GOLD_DIM, width=1)

    # Bonus text
    center_text(draw, MERCH_W // 2, 54, bonus, f_bonus, (155, 220, 135),
                shadow=(8, 5, 2))

    # Accepted industry dots + labels
    accepts  = data.get("accepts", [])
    dot_r    = 9
    dot_y    = 82
    n_dots   = len(accepts)
    total_dw = n_dots * (dot_r * 2 + 6) - 6
    dot_x0   = (MERCH_W - total_dw) // 2

    for j, ind in enumerate(accepts):
        ind_c = INDUSTRY_COLORS.get(ind, (120, 120, 120))
        dx = dot_x0 + j * (dot_r * 2 + 6) + dot_r
        draw.ellipse([(dx - dot_r, dot_y - dot_r),
                      (dx + dot_r, dot_y + dot_r)],
                     fill=ind_c, outline=CREAM, width=1)
        # Industry label below dot
        lbl_en = ind[:3].title()
        lbl_zh = INDUSTRY_NAMES_ZH.get(ind, "")[:2]
        center_text(draw, dx, dot_y + dot_r + 10, lbl_en, f_ind, MID_TXT)
        center_text(draw, dx, dot_y + dot_r + 22, lbl_zh, load_font_cjk(9), DIM_TXT)

    # "Accepts" label
    center_text(draw, MERCH_W // 2, 68, "ACCEPTS:", f_small, DIM_TXT)

    # Slot count
    slot_y = MERCH_H - 20
    center_text(draw, MERCH_W // 2, slot_y,
                f"[ {data['slots']} tile slot{'s' if data['slots'] > 1 else ''} ]",
                f_small, MID_TXT)

    # Star decoration
    f_star = load_font_num(16, bold=True)
    draw.text((8,  8),            "★", font=f_star, fill=GOLD_DIM)
    draw.text((MERCH_W - 22, 8),  "★", font=f_star, fill=GOLD_DIM)

    return img


# ---------------------------------------------------------------------------
# 4. Help Cards  (600 x 900)
# ---------------------------------------------------------------------------
HELP_W, HELP_H = 600, 900

ACTIONS_EN = [
    {"name": "BUILD",
     "icon": "■",
     "color": (165, 58, 58),
     "lines": ["Pay cost (£ + coal / iron).",
               "Place industry tile on your city",
               "or a connected city.",
               "Must start from lowest level."]},
    {"name": "NETWORK",
     "icon": "◆",
     "color": (48, 88, 172),
     "lines": ["Canal era: pay £3.",
               "Rail era: pay £5 + 1 beer.",
               "Place link tile on any route",
               "connected to your network.",
               "Canal: 1 link.   Rail: 2 links."]},
    {"name": "DEVELOP",
     "icon": "▲",
     "color": (55, 148, 62),
     "lines": ["Pay 1 iron per tile removed.",
               "Remove top tile from your",
               "player board to skip a level."]},
    {"name": "SELL",
     "icon": "●",
     "color": (172, 102, 28),
     "lines": ["Sell cotton / pottery / manufacturer",
               "tiles to a connected merchant.",
               "Rail era: each tile needs 1 beer.",
               "(Canal era: no beer required.)"]},
    {"name": "LOAN",
     "icon": "£",
     "color": (48, 130, 122),
     "lines": ["Take £30 from the bank.",
               "Move income track down 3 spaces.",
               "No interest, but reduced income."]},
    {"name": "SCOUT",
     "icon": "★",
     "color": (130, 58, 152),
     "lines": ["Discard 3 cards from your hand.",
               "Receive 2 wild cards:",
               "  • 1 Wild Location card",
               "  • 1 Wild Industry card"]},
]

ACTIONS_ZH = [
    {"name": "建造 BUILD",
     "icon": "■",
     "color": (165, 58, 58),
     "lines": ["支付費用（金錢＋煤炭/鐵礦）",
               "在自己城市或連接城市",
               "放置工業瓦片",
               "必須從最低等級開始建造"]},
    {"name": "聯絡 NETWORK",
     "icon": "◆",
     "color": (48, 88, 172),
     "lines": ["運河時代：支付 £3",
               "鐵路時代：支付 £5 ＋ 啤酒",
               "在已連接路線上放置連絡瓦片",
               "運河：1條　鐵路：2條"]},
    {"name": "發展 DEVELOP",
     "icon": "▲",
     "color": (55, 148, 62),
     "lines": ["每移除一張瓦片需支付 1 鐵礦",
               "從玩家板移除頂部瓦片",
               "跳過一個等級"]},
    {"name": "販賣 SELL",
     "icon": "●",
     "color": (172, 102, 28),
     "lines": ["賣出棉花/陶瓷/製造商瓦片",
               "至相連商人城市",
               "鐵路時代：每張需要 1 啤酒",
               "（運河時代不需要啤酒）"]},
    {"name": "貸款 LOAN",
     "icon": "£",
     "color": (48, 130, 122),
     "lines": ["從銀行取得 £30",
               "收入軌跡下降 3 格",
               "無利息但收入減少"]},
    {"name": "偵查 SCOUT",
     "icon": "★",
     "color": (130, 58, 152),
     "lines": ["棄掉手牌中 3 張卡",
               "取得 2 張萬用牌：",
               "  • 1 張萬用地點",
               "  • 1 張萬用工業"]},
]


def make_help_card(actions: list, lang: str) -> Image.Image:
    is_zh = (lang == "zh")
    rng   = random.Random(42 + (1 if is_zh else 0))

    img  = Image.new("RGB", (HELP_W, HELP_H), BG_DARK)
    img  = parchment_bg(img, rng, 0.20)
    draw = ImageDraw.Draw(img)

    # Inner panel
    draw_rrect(draw, (12, 12, HELP_W - 13, HELP_H - 13),
               r=14, fill=BG_PANEL)

    # Border layers
    for t, clr, lw in [(4, (80, 60, 26), 2), (8, GOLD, 2), (12, GOLD_DIM, 1)]:
        draw.rectangle([t, t, HELP_W - 1 - t, HELP_H - 1 - t],
                       outline=clr, width=lw)

    f_title_en  = load_font(30, bold=True)
    f_title_zh  = load_font_cjk(28)
    f_era       = load_font(18)
    f_era_zh    = load_font_cjk(16)
    f_action_en = load_font(18, bold=True)
    f_action_zh = load_font_cjk(18)
    f_body_en   = load_font(15)
    f_body_zh   = load_font_cjk(15)

    # Title
    if is_zh:
        center_text(draw, HELP_W // 2, 34,
                    "行動摘要", f_title_zh, GOLD, shadow=BLACK)
        center_text(draw, HELP_W // 2, 60,
                    "Brass: Birmingham", f_title_en, GOLD_DIM, shadow=BLACK)
    else:
        center_text(draw, HELP_W // 2, 34,
                    "ACTION SUMMARY", f_title_en, GOLD, shadow=BLACK)
        center_text(draw, HELP_W // 2, 58,
                    "Brass: Birmingham", f_era, GOLD_DIM)

    # Era subtitle
    if is_zh:
        center_text(draw, HELP_W // 2, 82,
                    "運河時代  →  鐵路時代", f_era_zh, MID_TXT)
    else:
        center_text(draw, HELP_W // 2, 82,
                    "Canal Era  →  Rail Era", f_era, MID_TXT)

    # Separator
    draw.line([(22, 96), (HELP_W - 22, 96)], fill=GOLD_DIM, width=1)
    draw.ellipse([(HELP_W // 2 - 4, 93), (HELP_W // 2 + 4, 101)],
                 fill=GOLD)

    # Action blocks
    block_y   = 104
    block_h   = (HELP_H - block_y - 26) // len(actions)
    f_act     = f_action_zh if is_zh else f_action_en
    f_bdy     = f_body_zh   if is_zh else f_body_en

    for i, action in enumerate(actions):
        by  = block_y + i * block_h
        clr = action["color"]

        # Block background
        shade = tuple(max(0, int(c * 0.14)) for c in clr)
        draw_rrect(draw, (18, by + 4, HELP_W - 19, by + block_h - 4),
                   r=8, fill=shade, outline=clr, width=2)

        # Icon circle
        ic_cx, ic_cy = 40, by + 22
        draw.ellipse([(ic_cx - 14, ic_cy - 14), (ic_cx + 14, ic_cy + 14)],
                     fill=clr, outline=None)
        f_icon = load_font_num(18, bold=True)
        center_text(draw, ic_cx, ic_cy, action["icon"], f_icon, WHITE)

        # Action name
        draw.text((60, by + 9), action["name"], font=f_act, fill=clr)

        # Body lines
        line_y = by + 34
        for line in action["lines"]:
            draw.text((62, line_y), line, font=f_bdy, fill=LIGHT_TXT)
            bb = draw.textbbox((0, 0), line, font=f_bdy)
            line_y += (bb[3] - bb[1]) + 3

    # Footer
    f_foot = load_font(11)
    foot_str = ("©版權所有  原著：Roxley Games" if is_zh
                else "Prototype Only — Based on Brass: Birmingham by Roxley Games")
    bb = draw.textbbox((0, 0), foot_str, font=f_foot)
    draw.text(((HELP_W - (bb[2] - bb[0])) // 2, HELP_H - 19),
              foot_str, font=f_foot, fill=DIM_TXT)

    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    total = 0

    print("Generating player boards...")
    for cname in PLAYER_COLORS:
        pb = make_player_board(cname)
        fname = f"player_board_{cname}.png"
        pb.save(OUT_DIR / fname)
        print(f"  Saved {fname}")
        total += 1

    print("\nGenerating link tiles...")
    for cname in PLAYER_COLORS:
        for ltype in ("canal", "rail"):
            lt = make_link_tile(cname, ltype)
            fname = f"{ltype}_{cname}.png"
            lt.save(OUT_DIR / fname)
            print(f"  Saved {fname}")
            total += 1

    print("\nGenerating merchant tiles...")
    for mdata in MERCHANT_DATA:
        mt = make_merchant_tile(mdata)
        fname = f"merchant_{mdata['name']}.png"
        mt.save(OUT_DIR / fname)
        print(f"  Saved {fname}")
        total += 1

    print("\nGenerating help cards...")
    en = make_help_card(ACTIONS_EN, "en")
    en.save(OUT_DIR / "help_card_en.png")
    print("  Saved help_card_en.png")
    total += 1

    zh = make_help_card(ACTIONS_ZH, "zh")
    zh.save(OUT_DIR / "help_card_zh.png")
    print("  Saved help_card_zh.png")
    total += 1

    print(f"\nDone. {total} images written to {OUT_DIR}")


if __name__ == "__main__":
    main()
