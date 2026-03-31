"""
generate_cards.py
Generates all card PNG images for the Brass: Birmingham TTS mod prototype.
Output: assets/cards/
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

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
BORDER = 18          # border thickness
CORNER_R = 24        # corner radius

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
COLORS = {
    # Industry card backgrounds
    "cotton":       (230, 230, 240),
    "coal":         (55,  55,  60),
    "iron":         (180, 100, 40),
    "brewery":      (200, 160, 30),
    "manufacturer": (110, 55,  150),
    "pottery":      (190, 80,  50),

    # Wild cards
    "wild":         (20,  40,  100),

    # Card back
    "back":         (60,  35,  20),

    # Location card base
    "location_base": (180, 145, 100),

    # Location region borders
    "border_teal":  (30,  160, 145),
    "border_blue":  (40,  80,  200),
    "border_brown": (100, 65,  35),

    # Text
    "white":        (255, 255, 255),
    "black":        (10,  10,  10),
    "light_text":   (240, 235, 225),
    "dark_text":    (30,  20,  10),
    "mid_gray":     (160, 160, 165),
}

# Industry text colour (ensure contrast)
INDUSTRY_TEXT = {
    "cotton":       COLORS["dark_text"],
    "coal":         COLORS["light_text"],
    "iron":         COLORS["light_text"],
    "brewery":      COLORS["dark_text"],
    "manufacturer": COLORS["light_text"],
    "pottery":      COLORS["light_text"],
}

# ---------------------------------------------------------------------------
# Location card data
# ---------------------------------------------------------------------------
# Region determines border colour
LOCATION_REGIONS = {
    "teal":  ["Belper", "Derby"],
    "blue":  ["Leek", "Stoke-on-Trent", "Stone", "Uttoxeter"],
    "brown": [
        "Birmingham", "Coventry", "Dudley", "Kidderminster", "Wolverhampton",
        "Coalbrookdale", "Nuneaton", "Worcester", "Tamworth", "Walsall",
        "Cannock", "Burton-on-Trent", "Stafford", "Redditch",
    ],
}

# Industries available per city (from Brass: Birmingham rules)
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
    {"label": "WILD", "sub": "Any Location",  "key": "wild_location"},
    {"label": "WILD", "sub": "Any Industry",  "key": "wild_industry"},
]

# ---------------------------------------------------------------------------
# Font helpers
# ---------------------------------------------------------------------------
def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """Load the best available font at the requested size."""
    candidates_bold = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/calibrib.ttf",
        "C:/Windows/Fonts/verdanab.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    candidates_regular = [
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/calibri.ttf",
        "C:/Windows/Fonts/verdana.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    candidates = candidates_bold if bold else candidates_regular
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Drawing primitives
# ---------------------------------------------------------------------------
def draw_rounded_rect(draw: ImageDraw.ImageDraw,
                      xy: tuple, radius: int, fill, outline=None, width: int = 0):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill,
                           outline=outline, width=width)


def center_text(draw: ImageDraw.ImageDraw, cx: int, cy: int,
                text: str, font: ImageFont.FreeTypeFont, fill):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2, cy - th // 2), text, font=font, fill=fill)


def wrapped_center_text(draw: ImageDraw.ImageDraw, cx: int, cy: int,
                        text: str, font: ImageFont.FreeTypeFont,
                        fill, max_width: int):
    """Word-wrap text and center each line around (cx, cy)."""
    words = text.split()
    lines = []
    current = ""
    for word in words:
        test = (current + " " + word).strip()
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)

    # measure total height
    line_h = draw.textbbox((0, 0), "Ag", font=font)[3] + 4
    total_h = line_h * len(lines)
    y = cy - total_h // 2
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        draw.text((cx - tw // 2, y), line, font=font, fill=fill)
        y += line_h


# ---------------------------------------------------------------------------
# Card base builders
# ---------------------------------------------------------------------------
def make_card_base(bg_color, border_color) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), bg_color)
    draw = ImageDraw.Draw(img)
    # Outer rounded border
    draw_rounded_rect(draw, (0, 0, W - 1, H - 1), CORNER_R,
                      fill=None, outline=border_color, width=BORDER)
    return img, draw


def label_pill(draw: ImageDraw.ImageDraw, cx: int, cy: int,
               text: str, font: ImageFont.FreeTypeFont,
               bg, fg):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pad_x, pad_y = 14, 7
    rx0 = cx - tw // 2 - pad_x
    ry0 = cy - th // 2 - pad_y
    rx1 = cx + tw // 2 + pad_x
    ry1 = cy + th // 2 + pad_y
    draw_rounded_rect(draw, (rx0, ry0, rx1, ry1), 10, fill=bg)
    draw.text((rx0 + pad_x, ry0 + pad_y), text, font=font, fill=fg)


def divider_line(draw: ImageDraw.ImageDraw, y: int, color, margin: int = 40):
    draw.line([(margin, y), (W - margin, y)], fill=color, width=2)


# ---------------------------------------------------------------------------
# Individual card generators
# ---------------------------------------------------------------------------
def make_location_card(city: str) -> Image.Image:
    # Determine border colour
    border_color = COLORS["border_brown"]
    for region, cities in LOCATION_REGIONS.items():
        if city in cities:
            border_color = COLORS[f"border_{region}"]
            break

    bg = COLORS["location_base"]
    img, draw = make_card_base(bg, border_color)

    # Fonts
    f_label  = load_font(22, bold=True)
    f_city   = load_font(44, bold=True)
    f_small  = load_font(20)
    f_ind    = load_font(18)

    cx = W // 2

    # Top label pill
    label_pill(draw, cx, 55, "LOCATION", f_label,
               bg=border_color, fg=COLORS["white"])

    # City name — wrapped if long
    wrapped_center_text(draw, cx, 200, city.upper(), f_city,
                        fill=COLORS["dark_text"], max_width=W - 60)

    # Divider
    divider_line(draw, 285, border_color)

    # Industries section
    draw.text((40, 305), "Industries:", font=f_small, fill=COLORS["dark_text"])
    industries = CITY_INDUSTRIES.get(city, [])
    y_ind = 335
    for ind in industries:
        dot_x = 52
        draw.ellipse([(dot_x - 5, y_ind + 5), (dot_x + 5, y_ind + 15)],
                     fill=border_color)
        draw.text((dot_x + 14, y_ind), ind, font=f_ind, fill=COLORS["dark_text"])
        y_ind += 30

    # Bottom border accent
    draw_rounded_rect(draw, (BORDER, H - 55, W - BORDER, H - BORDER),
                      8, fill=border_color)
    center_text(draw, cx, H - 37, "BRASS: BIRMINGHAM", f_label,
                fill=COLORS["white"])

    return img


def make_industry_card(industry_name: str) -> Image.Image:
    key = industry_name.lower().replace(" ", "_")
    # Map display names to colour keys
    key_map = {
        "cotton_mill":  "cotton",
        "coal_mine":    "coal",
        "iron_works":   "iron",
        "brewery":      "brewery",
        "manufacturer": "manufacturer",
        "pottery":      "pottery",
    }
    color_key = key_map.get(key, key)
    bg = COLORS.get(color_key, COLORS["location_base"])
    text_color = INDUSTRY_TEXT.get(color_key, COLORS["dark_text"])

    # Slightly darker shade for border
    border = tuple(max(0, c - 40) for c in bg)

    img, draw = make_card_base(bg, border)

    f_label   = load_font(22, bold=True)
    f_name    = load_font(42, bold=True)
    f_sub     = load_font(20)

    cx = W // 2

    # Top label
    label_pill(draw, cx, 55, "INDUSTRY", f_label,
               bg=border, fg=COLORS["white"] if color_key in ("coal", "iron", "manufacturer", "pottery") else COLORS["dark_text"])

    # Large industry name
    wrapped_center_text(draw, cx, 220, industry_name.upper(), f_name,
                        fill=text_color, max_width=W - 60)

    # Divider
    divider_line(draw, 320, border)

    # Flavour note
    flavour = {
        "Cotton Mill":  "Sell cotton to distant markets",
        "Coal Mine":    "Fuel the industrial revolution",
        "Iron Works":   "Forge the tools of progress",
        "Brewery":      "Provide beer for building links",
        "Manufacturer": "Manufacture consumer goods",
        "Pottery":      "Craft fine Staffordshire ware",
    }.get(industry_name, "")
    draw.text((40, 340), flavour, font=f_sub, fill=text_color)

    # Bottom bar
    draw_rounded_rect(draw, (BORDER, H - 55, W - BORDER, H - BORDER),
                      8, fill=border)
    center_text(draw, cx, H - 37, "BRASS: BIRMINGHAM", f_label,
                fill=COLORS["white"] if color_key in ("coal", "iron", "manufacturer", "pottery") else COLORS["dark_text"])

    return img


def make_wild_card(label: str, sub: str) -> Image.Image:
    bg = COLORS["wild"]
    border = (10, 25, 70)
    img, draw = make_card_base(bg, border)

    f_wild  = load_font(64, bold=True)
    f_sub   = load_font(30, bold=True)
    f_label = load_font(22, bold=True)
    f_small = load_font(18)

    cx = W // 2

    # Stars decoration row
    stars = "★  ★  ★"
    center_text(draw, cx, 70, stars, load_font(20), COLORS["mid_gray"])

    # WILD text
    center_text(draw, cx, 200, label, f_wild, COLORS["white"])

    # Divider
    divider_line(draw, 265, COLORS["mid_gray"])

    # Sub label
    center_text(draw, cx, 320, sub, f_sub, COLORS["light_text"])

    # Flavour
    flavour = "May be played as\nany location" if "Location" in sub else "May be played as\nany industry"
    y = 380
    for line in flavour.split("\n"):
        center_text(draw, cx, y, line, f_small, COLORS["mid_gray"])
        y += 26

    # Bottom bar
    draw_rounded_rect(draw, (BORDER, H - 55, W - BORDER, H - BORDER), 8, fill=border)
    center_text(draw, cx, H - 37, "BRASS: BIRMINGHAM", f_label, fill=COLORS["white"])

    return img


def make_card_back() -> Image.Image:
    bg = COLORS["back"]
    border = (30, 18, 8)
    img, draw = make_card_base(bg, border)

    f_big   = load_font(48, bold=True)
    f_small = load_font(26, bold=True)
    f_tiny  = load_font(16)

    cx, cy = W // 2, H // 2

    # Decorative outer ring
    margin = 32
    draw_rounded_rect(draw, (margin, margin, W - margin, H - margin),
                      CORNER_R - 4, fill=None,
                      outline=(120, 80, 40), width=3)

    # Inner frame
    inner = 56
    draw_rounded_rect(draw, (inner, inner, W - inner, H - inner),
                      CORNER_R - 12, fill=None,
                      outline=(90, 58, 28), width=2)

    # Title
    center_text(draw, cx, cy - 40, "BRASS", f_big, COLORS["light_text"])
    center_text(draw, cx, cy + 30, "BIRMINGHAM", f_small, (200, 160, 80))

    # Decorative diamonds
    for dx in [-60, 0, 60]:
        center_text(draw, cx + dx, cy + 80, "◆", load_font(14), (120, 80, 40))

    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    total = 0

    # --- Location cards ---
    all_cities = []
    for cities in LOCATION_REGIONS.values():
        all_cities.extend(cities)

    print(f"Generating {len(all_cities)} location cards...")
    for city in all_cities:
        img = make_location_card(city)
        fname = city.lower().replace(" ", "_").replace("-", "_") + "_location.png"
        out = OUT_DIR / fname
        img.save(out)
        print(f"  Saved {fname}")
        total += 1

    # --- Industry cards ---
    print(f"\nGenerating {len(INDUSTRY_LIST)} industry cards...")
    for name in INDUSTRY_LIST:
        img = make_industry_card(name)
        fname = name.lower().replace(" ", "_") + ".png"
        out = OUT_DIR / fname
        img.save(out)
        print(f"  Saved {fname}")
        total += 1

    # --- Wild cards ---
    print("\nGenerating 2 wild cards...")
    for card in WILD_CARDS:
        img = make_wild_card(card["label"], card["sub"])
        out = OUT_DIR / f"{card['key']}.png"
        img.save(out)
        print(f"  Saved {card['key']}.png")
        total += 1

    # --- Card back ---
    print("\nGenerating card back...")
    img = make_card_back()
    out = OUT_DIR / "card_back.png"
    img.save(out)
    print("  Saved card_back.png")
    total += 1

    print(f"\nDone. {total} card images written to {OUT_DIR}")


if __name__ == "__main__":
    main()
