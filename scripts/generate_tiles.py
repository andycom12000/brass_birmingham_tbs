"""
generate_tiles.py
Generates all building tile PNG images for the Brass: Birmingham TTS mod prototype.
Output: assets/tiles/
Naming: {industry}_lv{level}_front.png  /  {industry}_lv{level}_back.png
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

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
BORDER = 8
CORNER_R = 14

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
# Colour palette
# ---------------------------------------------------------------------------
INDUSTRY_COLORS = {
    "cotton":       (210, 210, 225),
    "coal":         (55,  55,  60),
    "iron":         (175, 95,  35),
    "brewery":      (195, 155, 25),
    "manufacturer": (105, 50,  145),
    "pottery":      (185, 75,  45),
}

INDUSTRY_TEXT_COLOR = {
    "cotton":       (30,  20,  10),
    "coal":         (235, 230, 220),
    "iron":         (240, 230, 220),
    "brewery":      (30,  20,  10),
    "manufacturer": (240, 230, 220),
    "pottery":      (240, 230, 220),
}

# Muted/darkened back colours
def darken(color, factor=0.45):
    return tuple(int(c * factor) for c in color)

def lighten(color, factor=1.5):
    return tuple(min(255, int(c * factor)) for c in color)

WHITE  = (255, 255, 255)
BLACK  = (10,  10,  10)
GOLD   = (220, 175, 40)

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


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------
def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=0):
    draw.rounded_rectangle(list(xy), radius=radius, fill=fill,
                           outline=outline, width=width)


def center_text(draw, cx, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2, cy - th // 2), text, font=font, fill=fill)


def left_text(draw, x, cy, text, font, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    th = bbox[3] - bbox[1]
    draw.text((x, cy - th // 2), text, font=font, fill=fill)


def stat_badge(draw, cx, cy, value, label, font_val, font_lbl, bg, fg):
    """Draw a small badge: coloured circle with value and label underneath."""
    r = 14
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=bg)
    center_text(draw, cx, cy, str(value), font_val, fg)
    lbl_bbox = draw.textbbox((0, 0), label, font=font_lbl)
    lw = lbl_bbox[2] - lbl_bbox[0]
    draw.text((cx - lw // 2, cy + r + 2), label, font=font_lbl, fill=fg)


# ---------------------------------------------------------------------------
# Resource cost row builder
# ---------------------------------------------------------------------------
def draw_cost_row(draw, data, y, text_color, bg_color):
    """Draw £ cost and coal/iron resource icons in a compact row."""
    f_small = load_font(12, bold=True)
    f_tiny  = load_font(11)

    parts = []
    if data.get("money", 0) > 0:
        parts.append(f"\u00a3{data['money']}")      # £
    if data.get("coal", 0) > 0:
        parts.append(f"\u25a0{data['coal']} Coal")  # ■ (coal block)
    if data.get("iron", 0) > 0:
        parts.append(f"\u25c6{data['iron']} Iron")  # ◆

    cost_str = "  ".join(parts) if parts else "Free"
    center_text(draw, W // 2, y, cost_str, f_small, text_color)


# ---------------------------------------------------------------------------
# Front tile
# ---------------------------------------------------------------------------
def make_front_tile(industry: str, data: dict) -> Image.Image:
    bg = INDUSTRY_COLORS[industry]
    text_color = INDUSTRY_TEXT_COLOR[industry]
    border = darken(bg, 0.6)

    img = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(img)

    # Border
    draw_rounded_rect(draw, (0, 0, W - 1, H - 1), CORNER_R,
                      fill=None, outline=border, width=BORDER)

    f_title  = load_font(13, bold=True)
    f_level  = load_font(11, bold=True)
    f_stat   = load_font(13, bold=True)
    f_label  = load_font(9)
    f_small  = load_font(10)
    f_tiny   = load_font(9)

    cx = W // 2
    lv = data["level"]
    industry_display = industry.title()

    # ---- Header band ----
    header_h = 32
    draw_rounded_rect(draw, (BORDER, BORDER, W - BORDER, BORDER + header_h),
                      CORNER_R - 6, fill=border)
    header_text = f"{industry_display}  Lv{lv}"
    center_text(draw, cx, BORDER + header_h // 2, header_text, f_title, WHITE)

    # Flags (rail_only / no_develop)
    flag_y = BORDER + header_h + 6
    flags = []
    if data.get("rail_only"):
        flags.append("Rail Era Only")
    if data.get("no_develop"):
        flags.append("No Develop")
    if flags:
        center_text(draw, cx, flag_y + 5, " | ".join(flags), f_tiny,
                    lighten(border, 1.8))
        flag_y += 14

    # ---- Cost row ----
    cost_y = flag_y + 18
    draw_cost_row(draw, data, cost_y, text_color, bg)

    # Thin separator
    sep_y = cost_y + 14
    draw.line([(20, sep_y), (W - 20, sep_y)], fill=border, width=1)

    # ---- Stats grid ----
    # Layout: 4 stats across two rows
    stat_y1 = sep_y + 20
    stat_y2 = stat_y1 + 44

    # VP
    vp_bg = (180, 30, 30)
    stat_badge(draw, 38, stat_y1, data["vp"], "VP",
               f_stat, f_label, vp_bg, WHITE)

    # Income
    inc_bg = (30, 130, 60)
    stat_badge(draw, 102, stat_y1, f"+{data['income']}", "Inc",
               f_stat, f_label, inc_bg, WHITE)

    # Links
    lnk_bg = (50, 80, 170)
    stat_badge(draw, 162, stat_y1, data["links"], "Lnk",
               f_stat, f_label, lnk_bg, WHITE)

    # Produces / Beer row
    produces = data.get("produces")
    beer_sell = data.get("beer_sell")

    if produces is not None:
        prod_label = "Beer" if industry == "brewery" else "Res"
        prd_bg = (150, 100, 30) if industry == "brewery" else (80, 120, 80)
        stat_badge(draw, cx, stat_y2, produces, prod_label,
                   f_stat, f_label, prd_bg, WHITE)
    elif beer_sell is not None and beer_sell > 0:
        stat_badge(draw, cx, stat_y2, beer_sell, "Beer",
                   f_stat, f_label, (150, 100, 30), WHITE)

    # Coal / Iron cost repeat as small icons in bottom row if non-zero
    icon_y = H - BORDER - 22
    if data.get("coal", 0) or data.get("iron", 0):
        icon_parts = []
        if data.get("coal", 0):
            icon_parts.append(f"\u25a0\u00d7{data['coal']}")
        if data.get("iron", 0):
            icon_parts.append(f"\u25c6\u00d7{data['iron']}")
        center_text(draw, cx, icon_y, "  ".join(icon_parts), f_small, text_color)

    return img


# ---------------------------------------------------------------------------
# Back tile
# ---------------------------------------------------------------------------
def make_back_tile(industry: str, data: dict) -> Image.Image:
    base_bg = INDUSTRY_COLORS[industry]
    bg = darken(base_bg, 0.4)
    border = darken(base_bg, 0.25)
    text_color = (200, 190, 175)

    img = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(img)

    # Border
    draw_rounded_rect(draw, (0, 0, W - 1, H - 1), CORNER_R,
                      fill=None, outline=border, width=BORDER)

    f_flipped = load_font(12, bold=True)
    f_vp_big  = load_font(52, bold=True)
    f_lnk     = load_font(18, bold=True)
    f_label   = load_font(11)

    cx, cy = W // 2, H // 2

    # FLIPPED label at top
    draw_rounded_rect(draw, (BORDER, BORDER, W - BORDER, BORDER + 24),
                      CORNER_R - 6, fill=border)
    center_text(draw, cx, BORDER + 12, "FLIPPED", f_flipped, (180, 170, 155))

    # VP value — big centred
    vp_str = str(data["vp"])
    center_text(draw, cx, cy - 10, vp_str, f_vp_big, GOLD)

    # VP label below
    center_text(draw, cx, cy + 35, "VP", f_label, text_color)

    # Links row at bottom
    lnk_str = f"Links: {data['links']}"
    center_text(draw, cx, H - BORDER - 24, lnk_str, f_lnk, text_color)

    # Level indicator in corner
    lv_str = f"Lv{data['level']}"
    draw.text((BORDER + 6, H - BORDER - 20), lv_str, font=f_label, fill=text_color)

    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    total = 0

    for industry, levels in TILE_DATA.items():
        print(f"Generating tiles for: {industry} ({len(levels)} levels)...")
        for data in levels:
            lv = data["level"]

            # Front
            front = make_front_tile(industry, data)
            fname_f = f"{industry}_lv{lv}_front.png"
            front.save(OUT_DIR / fname_f)
            print(f"  Saved {fname_f}")
            total += 1

            # Back
            back = make_back_tile(industry, data)
            fname_b = f"{industry}_lv{lv}_back.png"
            back.save(OUT_DIR / fname_b)
            print(f"  Saved {fname_b}")
            total += 1

    print(f"\nDone. {total} tile images written to {OUT_DIR}")


if __name__ == "__main__":
    main()
