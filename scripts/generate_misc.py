"""
generate_misc.py
Generates miscellaneous asset images for the Brass: Birmingham TTS mod prototype.
Output: assets/misc/

Assets generated:
  - player_board_Red.png / _Yellow.png / _Blue.png / _Green.png
  - canal_Red.png / rail_Red.png  (and for all 4 player colours)
  - merchant_Shrewsbury.png (and for each merchant)
  - help_card_en.png / help_card_zh.png
"""

import os
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
BG_DARK   = (42,  31,  20)
PANEL_BG  = (55,  42,  28)
GOLD      = (220, 175, 40)
WHITE     = (250, 245, 235)
BLACK     = (10,  10,  10)
LIGHT_TXT = (240, 230, 210)
MID_TXT   = (180, 170, 150)

PLAYER_COLORS = {
    "Red":    (200,  50,  50),
    "Yellow": (210, 175,  25),
    "Blue":   (50,  100, 200),
    "Green":  (45,  160,  65),
}

INDUSTRY_COLORS = {
    "cotton":       (200, 200, 215),
    "coal":         (50,  50,  55),
    "iron":         (165, 85,  25),
    "brewery":      (185, 145, 20),
    "manufacturer": (100, 45,  135),
    "pottery":      (175, 65,  35),
}

MERCHANT_COLORS = {
    "Shrewsbury": (80,  120, 80),
    "Gloucester": (60,  100, 150),
    "Oxford":     (120, 80,  140),
    "Warrington": (140, 100, 40),
    "Nottingham": (140, 50,  50),
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


def load_font_cjk(size: int) -> ImageFont.FreeTypeFont:
    """Try to load a CJK font for Traditional Chinese text."""
    candidates = [
        "C:/Windows/Fonts/msjh.ttc",      # Microsoft JhengHei (TC)
        "C:/Windows/Fonts/msjhbd.ttc",
        "C:/Windows/Fonts/mingliu.ttc",    # MingLiU
        "C:/Windows/Fonts/msgothic.ttc",   # MS Gothic (JP fallback)
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJKtc-Regular.otf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return load_font(size)   # fall back to Latin font


def center_text(draw, cx, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2 - bbox[0], cy - th // 2 - bbox[1]),
              text, font=font, fill=fill)


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(list(xy), radius=radius,
                           fill=fill, outline=outline, width=width)


# ---------------------------------------------------------------------------
# 1. Player Boards
# ---------------------------------------------------------------------------
PB_W, PB_H = 1024, 768

# Industry columns: name, number of levels, colour
INDUSTRY_COLUMNS = [
    ("Cotton",       4, INDUSTRY_COLORS["cotton"]),
    ("Coal",         4, INDUSTRY_COLORS["coal"]),
    ("Iron",         4, INDUSTRY_COLORS["iron"]),
    ("Brewery",      4, INDUSTRY_COLORS["brewery"]),
    ("Manufacturer", 8, INDUSTRY_COLORS["manufacturer"]),
    ("Pottery",      5, INDUSTRY_COLORS["pottery"]),
]


def make_player_board(player_color_name: str) -> Image.Image:
    pcolor = PLAYER_COLORS[player_color_name]
    border_clr = pcolor

    img  = Image.new("RGB", (PB_W, PB_H), BG_DARK)
    draw = ImageDraw.Draw(img)

    # Outer border (player colour accent)
    for t in range(6):
        draw.rectangle([t, t, PB_W - 1 - t, PB_H - 1 - t], outline=border_clr)
    draw.rectangle([10, 10, PB_W - 11, PB_H - 11], outline=GOLD, width=2)

    # Background panel
    draw_rounded_rect(draw, (14, 14, PB_W - 15, PB_H - 15),
                      radius=12, fill=PANEL_BG)

    # Title
    f_title  = load_font(42, bold=True)
    f_sub    = load_font(26)
    f_col    = load_font(20, bold=True)
    f_slot   = load_font(16)

    center_text(draw, PB_W // 2, 42, "PLAYER BOARD", f_title, GOLD)
    center_text(draw, PB_W // 2, 80, f"— {player_color_name} —", f_sub, pcolor)

    # ---- Industry columns ----
    n_cols     = len(INDUSTRY_COLUMNS)
    col_area_x = 30
    col_area_y = 110
    col_area_w = PB_W - 60
    col_area_h = PB_H - 140

    col_w_total = col_area_w // n_cols

    for ci, (ind_name, n_levels, ind_color) in enumerate(INDUSTRY_COLUMNS):
        cx_left  = col_area_x + ci * col_w_total
        cx_right = cx_left + col_w_total - 6

        # Column header band
        header_h = 32
        draw_rounded_rect(draw,
                          (cx_left, col_area_y, cx_right, col_area_y + header_h),
                          radius=6, fill=ind_color)
        center_text(draw, (cx_left + cx_right) // 2, col_area_y + 16,
                    ind_name, f_col, WHITE if _is_dark(ind_color) else BLACK)

        # Tile slots (empty rectangles)
        slot_margin = 6
        slot_h      = min(70, (col_area_h - header_h - 20) // n_levels)
        slot_w      = col_w_total - 2 * slot_margin - 6

        for li in range(n_levels):
            sy0 = col_area_y + header_h + 8 + li * (slot_h + 6)
            sy1 = sy0 + slot_h
            sx0 = cx_left + slot_margin
            sx1 = sx0 + slot_w

            # Slot background
            draw_rounded_rect(draw, (sx0, sy0, sx1, sy1),
                              radius=5,
                              fill=(int(ind_color[0] * 0.18),
                                    int(ind_color[1] * 0.18),
                                    int(ind_color[2] * 0.18)),
                              outline=ind_color, width=2)

            # Level number
            lv_str = f"Lv{li + 1}"
            center_text(draw, (sx0 + sx1) // 2, (sy0 + sy1) // 2,
                        lv_str, f_slot, ind_color)

    # Player colour swatch bottom-right
    sw_size = 60
    sw_x = PB_W - 30 - sw_size
    sw_y = PB_H - 30 - sw_size
    draw_rounded_rect(draw, (sw_x, sw_y, sw_x + sw_size, sw_y + sw_size),
                      radius=10, fill=pcolor, outline=GOLD, width=2)

    return img


def _is_dark(color):
    r, g, b = color
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return luminance < 128


# ---------------------------------------------------------------------------
# 2. Link tiles
# ---------------------------------------------------------------------------
LINK_W, LINK_H = 200, 80

def make_link_tile(player_color_name: str, link_type: str) -> Image.Image:
    """link_type: 'canal' or 'rail'"""
    pcolor = PLAYER_COLORS[player_color_name]

    if link_type == "canal":
        base_bg = (30, 70, 130)
        accent  = (80, 160, 220)
        label   = "CANAL"
        symbol  = "≋"
    else:
        base_bg = (60, 60, 65)
        accent  = (160, 160, 165)
        label   = "RAIL"
        symbol  = "▬▬"

    img  = Image.new("RGB", (LINK_W, LINK_H), base_bg)
    draw = ImageDraw.Draw(img)

    # Border (player colour)
    draw.rectangle([0, 0, LINK_W - 1, LINK_H - 1], outline=pcolor, width=4)

    # Inner accent line
    draw.rectangle([5, 5, LINK_W - 6, LINK_H - 6], outline=accent, width=1)

    f_label  = load_font(20, bold=True)
    f_symbol = load_font(22)
    f_player = load_font(14)

    center_text(draw, LINK_W // 2, 28, label,  f_label,  WHITE)
    center_text(draw, LINK_W // 2, 52, symbol, f_symbol, accent)

    # Player name in bottom-right corner
    draw.text((LINK_W - 4, LINK_H - 16), player_color_name,
              font=f_player, fill=pcolor, anchor="rs")

    return img


# ---------------------------------------------------------------------------
# 3. Merchant tiles
# ---------------------------------------------------------------------------
MERCH_W, MERCH_H = 200, 150

MERCHANT_DATA = [
    {
        "name":      "Shrewsbury",
        "accepts":   ["cotton", "manufacturer"],
        "bonus":     "+4 VP",
        "slots":     1,
    },
    {
        "name":      "Gloucester",
        "accepts":   ["pottery", "cotton"],
        "bonus":     "Free Develop",
        "slots":     2,
    },
    {
        "name":      "Oxford",
        "accepts":   ["cotton", "manufacturer"],
        "bonus":     "+2 Income",
        "slots":     2,
    },
    {
        "name":      "Warrington",
        "accepts":   ["brewery", "manufacturer"],
        "bonus":     "+£5",
        "slots":     2,
    },
    {
        "name":      "Nottingham",
        "accepts":   ["coal", "iron"],
        "bonus":     "+3 VP",
        "slots":     2,
    },
]


def make_merchant_tile(data: dict) -> Image.Image:
    name   = data["name"]
    bonus  = data["bonus"]
    slots  = data["slots"]

    bg_color = MERCHANT_COLORS.get(name, (70, 60, 40))
    border   = tuple(min(255, int(c * 1.6)) for c in bg_color)

    img  = Image.new("RGB", (MERCH_W, MERCH_H), bg_color)
    draw = ImageDraw.Draw(img)

    # Border
    draw.rectangle([0, 0, MERCH_W - 1, MERCH_H - 1], outline=GOLD, width=3)

    f_name   = load_font(16, bold=True)
    f_bonus  = load_font(14, bold=True)
    f_small  = load_font(12)
    f_ind    = load_font(11)

    # Name header
    draw_rounded_rect(draw, (3, 3, MERCH_W - 4, 30),
                      radius=5, fill=(20, 15, 8))
    center_text(draw, MERCH_W // 2, 17, name.upper(), f_name, GOLD)

    # Bonus
    center_text(draw, MERCH_W // 2, 52, bonus, f_bonus, (160, 220, 140))

    # Accepted industry dots
    accepts = data.get("accepts", [])
    slot_y  = 80
    dot_r   = 8
    total_w = len(accepts) * (dot_r * 2 + 4) - 4
    dot_x   = (MERCH_W - total_w) // 2

    for ind in accepts:
        color = INDUSTRY_COLORS.get(ind, (120, 120, 120))
        draw.ellipse([(dot_x, slot_y - dot_r),
                      (dot_x + dot_r * 2, slot_y + dot_r)],
                     fill=color, outline=WHITE, width=1)
        # Industry label
        lbl = ind[:3].title()
        center_text(draw, dot_x + dot_r, slot_y + dot_r + 10, lbl, f_ind, MID_TXT)
        dot_x += dot_r * 2 + 12

    # Slot count indicator
    center_text(draw, MERCH_W // 2, MERCH_H - 22,
                f"Slots: {slots}", f_small, MID_TXT)

    return img


# ---------------------------------------------------------------------------
# 4. Help cards
# ---------------------------------------------------------------------------
HELP_W, HELP_H = 600, 900

ACTIONS_EN = [
    {
        "name":  "BUILD",
        "icon":  "\u25a0",
        "lines": [
            "Pay cost (£ + coal/iron).",
            "Place industry tile on your",
            "city or connected city.",
            "Must be lowest level first.",
        ],
    },
    {
        "name":  "NETWORK",
        "icon":  "\u25c6",
        "lines": [
            "Pay 3£ (canal) or 5£+beer (rail).",
            "Place link tile on a route",
            "connected to your network.",
            "Canal: 1 link.  Rail: 2 links.",
        ],
    },
    {
        "name":  "DEVELOP",
        "icon":  "\u25b2",
        "lines": [
            "Pay 1 iron per tile removed.",
            "Remove top tile from your",
            "player board to skip a level.",
        ],
    },
    {
        "name":  "SELL",
        "icon":  "\u25cf",
        "lines": [
            "Sell cotton/pottery/manufacturer",
            "tiles to a connected merchant.",
            "Each tile needs 1 beer to sell",
            "(except in Canal era).",
        ],
    },
    {
        "name":  "LOAN",
        "icon":  "\u00a3",
        "lines": [
            "Take £30 from the bank.",
            "Move income track down 3 spaces.",
            "No interest, but less income.",
        ],
    },
    {
        "name":  "SCOUT",
        "icon":  "\u2605",
        "lines": [
            "Discard 3 cards from your hand.",
            "Take 2 wild cards:",
            "  1 Wild Location",
            "  1 Wild Industry",
        ],
    },
]

ACTIONS_ZH = [
    {
        "name":  "建造 BUILD",
        "icon":  "\u25a0",
        "lines": [
            "支付費用（金錢＋煤炭/鐵礦）",
            "在自己城市或連接城市",
            "放置工業瓦片",
            "必須從最低等級開始建造",
        ],
    },
    {
        "name":  "聯絡 NETWORK",
        "icon":  "\u25c6",
        "lines": [
            "運河時代：支付 £3",
            "鐵路時代：支付 £5 ＋ 啤酒",
            "在已連接路線上放置連絡瓦片",
            "運河：1條　鐵路：2條",
        ],
    },
    {
        "name":  "發展 DEVELOP",
        "icon":  "\u25b2",
        "lines": [
            "每移除一張瓦片需支付 1 鐵礦",
            "從玩家板移除頂部瓦片",
            "跳過一個等級",
        ],
    },
    {
        "name":  "販賣 SELL",
        "icon":  "\u25cf",
        "lines": [
            "賣出棉花/陶瓷/製造商瓦片",
            "至相連商人城市",
            "每張需要 1 啤酒",
            "（運河時代不需要）",
        ],
    },
    {
        "name":  "貸款 LOAN",
        "icon":  "\u00a3",
        "lines": [
            "從銀行取得 £30",
            "收入軌跡下降 3 格",
            "無利息但收入減少",
        ],
    },
    {
        "name":  "偵查 SCOUT",
        "icon":  "\u2605",
        "lines": [
            "棄掉手牌中 3 張卡",
            "取得 2 張萬用牌：",
            "  1 張萬用地點",
            "  1 張萬用工業",
        ],
    },
]


def make_help_card(actions: list, lang: str) -> Image.Image:
    img  = Image.new("RGB", (HELP_W, HELP_H), BG_DARK)
    draw = ImageDraw.Draw(img)

    # Background panels (alternating)
    for t in range(5):
        draw.rectangle([t, t, HELP_W - 1 - t, HELP_H - 1 - t],
                       outline=(90, 70, 40))
    draw.rectangle([10, 10, HELP_W - 11, HELP_H - 11], outline=GOLD, width=2)

    is_zh = (lang == "zh")
    f_cjk = load_font_cjk(18) if is_zh else None

    f_title  = load_font(36, bold=True)
    f_action = load_font(20, bold=True)
    f_body   = load_font(16)
    f_icon   = load_font(22, bold=True)

    # Title
    title_str = ("行動摘要 — Brass: Birmingham" if is_zh
                 else "ACTION SUMMARY — Brass: Birmingham")
    center_text(draw, HELP_W // 2, 36, title_str, f_title, GOLD)

    # Era note
    era_str = ("運河時代 → 鐵路時代" if is_zh
               else "Canal Era  →  Rail Era")
    center_text(draw, HELP_W // 2, 72, era_str, f_body, (160, 145, 120))

    sep_y = 90
    draw.line([(20, sep_y), (HELP_W - 20, sep_y)], fill=GOLD, width=1)

    # Action blocks
    ACTION_COLORS = [
        (160, 60,  60),
        (50,  90, 170),
        (60, 150,  60),
        (170, 100, 30),
        (50, 130, 120),
        (130, 60, 150),
    ]

    block_y  = 106
    block_h  = (HELP_H - block_y - 20) // len(actions)

    for i, action in enumerate(actions):
        by  = block_y + i * block_h
        clr = ACTION_COLORS[i % len(ACTION_COLORS)]

        # Block background (subtle)
        shade = (int(clr[0] * 0.12), int(clr[1] * 0.12), int(clr[2] * 0.12))
        draw_rounded_rect(draw, (18, by + 3, HELP_W - 19, by + block_h - 3),
                          radius=8, fill=shade, outline=clr, width=2)

        # Icon
        center_text(draw, 44, by + 22, action["icon"], f_icon, clr)

        # Action name
        f_nm = f_cjk if is_zh and f_cjk else f_action
        draw.text((62, by + 10), action["name"], font=f_nm, fill=clr)

        # Body lines
        line_y = by + 36
        f_ln = f_cjk if is_zh and f_cjk else f_body
        for line in action["lines"]:
            draw.text((66, line_y), line, font=f_ln, fill=LIGHT_TXT)
            bbox = draw.textbbox((0, 0), line, font=f_ln)
            line_y += (bbox[3] - bbox[1]) + 4

    # Footer
    footer_str = ("©版權所有  原著：Roxley Games" if is_zh
                  else "Prototype Only — Based on Brass: Birmingham by Roxley Games")
    f_footer = load_font(13)
    center_text(draw, HELP_W // 2, HELP_H - 16, footer_str, f_footer,
                (110, 100, 85))

    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    total = 0

    # ---- 1. Player boards ----
    print("Generating player boards...")
    for color_name in PLAYER_COLORS:
        pb = make_player_board(color_name)
        fname = f"player_board_{color_name}.png"
        pb.save(OUT_DIR / fname)
        print(f"  Saved {fname}")
        total += 1

    # ---- 2. Link tiles ----
    print("\nGenerating link tiles...")
    for color_name in PLAYER_COLORS:
        for link_type in ("canal", "rail"):
            lt = make_link_tile(color_name, link_type)
            fname = f"{link_type}_{color_name}.png"
            lt.save(OUT_DIR / fname)
            print(f"  Saved {fname}")
            total += 1

    # ---- 3. Merchant tiles ----
    print("\nGenerating merchant tiles...")
    for mdata in MERCHANT_DATA:
        mt = make_merchant_tile(mdata)
        fname = f"merchant_{mdata['name']}.png"
        mt.save(OUT_DIR / fname)
        print(f"  Saved {fname}")
        total += 1

    # ---- 4. Help cards ----
    print("\nGenerating help cards...")
    en_card = make_help_card(ACTIONS_EN, "en")
    en_card.save(OUT_DIR / "help_card_en.png")
    print("  Saved help_card_en.png")
    total += 1

    zh_card = make_help_card(ACTIONS_ZH, "zh")
    zh_card.save(OUT_DIR / "help_card_zh.png")
    print("  Saved help_card_zh.png")
    total += 1

    print(f"\nDone. {total} images written to {OUT_DIR}")


if __name__ == "__main__":
    main()
