#!/usr/bin/env python3
"""Generate a Tabletop Simulator save file for the Brass: Birmingham prototype.

Run `python scripts/serve_assets.py` first so TTS can load images from localhost.
Output: brass_birmingham.json  (place in TTS Saves folder and load directly)

TTS Saves folder:
  Windows: %USERPROFILE%/Documents/My Games/Tabletop Simulator/Saves/
"""

import json
import random
import string
import os
from datetime import datetime

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_used_guids: set = set()

def new_guid() -> str:
    """Generate a unique 6-character hex GUID (TTS convention)."""
    while True:
        g = "".join(random.choices(string.hexdigits[:16], k=6)).lower()
        if g not in _used_guids:
            _used_guids.add(g)
            return g


BASE_URL = "http://localhost:8080"


def img(path: str) -> str:
    return f"{BASE_URL}/{path}"


def transform(x=0, y=1, z=0, rx=0, ry=0, rz=0, sx=1, sy=1, sz=1) -> dict:
    return {
        "posX": x, "posY": y, "posZ": z,
        "rotX": rx, "rotY": ry, "rotZ": rz,
        "scaleX": sx, "scaleY": sy, "scaleZ": sz,
    }


def color_rgb(r, g, b) -> dict:
    return {"r": r, "g": g, "b": b}


# ---------------------------------------------------------------------------
# Card data
# ---------------------------------------------------------------------------

# Location cards — each city gets cards equal to its number of industry slots.
# Merchant cities have 0 slots but do not appear in the draw deck (no cards).
LOCATION_CARDS = [
    # (city_name, filename_slug, count)
    ("Birmingham",      "birmingham",       4),
    ("Coventry",        "coventry",         2),
    ("Dudley",          "dudley",           2),
    ("Kidderminster",   "kidderminster",    2),
    ("Wolverhampton",   "wolverhampton",    2),
    ("Coalbrookdale",   "coalbrookdale",    3),
    ("Nuneaton",        "nuneaton",         2),
    ("Worcester",       "worcester",        2),
    ("Tamworth",        "tamworth",         2),
    ("Walsall",         "walsall",          2),
    ("Cannock",         "cannock",          2),
    ("Burton-on-Trent", "burton_on_trent",  3),
    ("Stafford",        "stafford",         2),
    ("Stoke-on-Trent",  "stoke_on_trent",   3),
    ("Leek",            "leek",             2),
    ("Stone",           "stone",            2),
    ("Uttoxeter",       "uttoxeter",        2),
    ("Belper",          "belper",           3),
    ("Derby",           "derby",            3),
    ("Redditch",        "redditch",         2),
]

# Industry cards — one per industry type (canonical counts from rulebook)
INDUSTRY_CARDS = [
    ("Cotton Mill",   "cotton_mill",  3),
    ("Coal Mine",     "coal_mine",    4),
    ("Iron Works",    "iron_works",   4),
    ("Brewery",       "brewery",      5),
    ("Manufacturer",  "manufacturer", 4),
    ("Pottery",       "pottery",      2),
]

# Wild cards (2 of each)
WILD_LOCATION_COUNT = 2
WILD_INDUSTRY_COUNT = 2

# Building tile data per player
# (industry, max_level)
INDUSTRIES = [
    ("cotton",       4),
    ("coal",         4),
    ("iron",         4),
    ("brewery",      4),
    ("manufacturer", 8),
    ("pottery",      5),
]

PLAYER_COLORS = ["Red", "Blue", "Yellow", "Green"]

# Merchant tiles per city
MERCHANTS = [
    ("Shrewsbury",  "merchant_Shrewsbury"),
    ("Gloucester",  "merchant_Gloucester"),
    ("Oxford",      "merchant_Oxford"),
    ("Warrington",  "merchant_Warrington"),
    ("Nottingham",  "merchant_Nottingham"),
]

# ---------------------------------------------------------------------------
# Table layout constants (TTS Unity coords — Y is up)
# ---------------------------------------------------------------------------

BOARD_X, BOARD_Y, BOARD_Z = 0.0, 1.0, 0.0

# Player areas — corners of the table
PLAYER_POSITIONS = {
    "Red":    (-20, 1,  16),
    "Blue":   ( 20, 1,  16),
    "Yellow": (-20, 1, -16),
    "Green":  ( 20, 1, -16),
}

# Resource bags — right side of table
COAL_BAG_POS      = (14, 1,  -3)
IRON_BAG_POS      = (14, 1,   0)
BEER_BAG_POS      = (14, 1,   3)
MONEY1_BAG_POS    = (14, 1,   7)
MONEY5_BAG_POS    = (14, 1,  10)
MONEY15_BAG_POS   = (14, 1,  13)

# Draw deck — left side of board
DRAW_DECK_POS     = (-14, 2.5,  0)

# Wild card supplies — top-left of board
WILD_LOC_POS      = (-14, 1,  -6)
WILD_IND_POS      = (-11, 1,  -6)

# Merchant tiles — bottom-centre strip
MERCHANT_POSITIONS = {
    "Shrewsbury":  (-10, 1, 11),
    "Gloucester":  ( -5, 1, 11),
    "Oxford":      (  0, 1, 11),
    "Warrington":  (  5, 1, 11),
    "Nottingham":  ( 10, 1, 11),
}

# Language toggle — far corner
LANG_TOGGLE_POS = (-18, 1, 11)

# ---------------------------------------------------------------------------
# Object builders
# ---------------------------------------------------------------------------

def make_board() -> dict:
    return {
        "Name": "Custom_Tile",
        "Transform": transform(BOARD_X, BOARD_Y, BOARD_Z, ry=180, sx=7, sy=1, sz=7),
        "Nickname": "Main Board",
        "Description": "Brass: Birmingham game board",
        "GUID": new_guid(),
        "CustomImage": {
            "ImageURL": img("board/main_board.png"),
            "ImageSecondaryURL": "",
            "WidthScale": 0,
            "CustomTile": {
                "Type": 0,
                "Thickness": 0.1,
                "Stackable": False,
                "Stretch": True,
            },
        },
        "Locked": True,
        "Grid": True,
        "Snap": True,
        "Autoraise": False,
        "Sticky": True,
        "Tooltip": True,
    }


def make_player_board(color: str, pos: tuple) -> dict:
    x, y, z = pos
    return {
        "Name": "Custom_Tile",
        "Transform": transform(x, y, z, ry=180, sx=5, sy=1, sz=3.5),
        "Nickname": f"{color} Player Board",
        "Description": f"Player board for {color}",
        "GUID": new_guid(),
        "CustomImage": {
            "ImageURL": img(f"misc/player_board_{color}.png"),
            "ImageSecondaryURL": "",
            "WidthScale": 0,
            "CustomTile": {
                "Type": 0,
                "Thickness": 0.1,
                "Stackable": False,
                "Stretch": True,
            },
        },
        "Locked": True,
        "Grid": False,
        "Snap": False,
        "Autoraise": False,
        "Sticky": True,
        "Tooltip": True,
    }


def make_help_card(color: str, pos: tuple, lang: str = "en") -> dict:
    x, y, z = pos
    return {
        "Name": "Custom_Tile",
        "Transform": transform(x + 7, y, z, ry=0, sx=2.5, sy=1, sz=3.5),
        "Nickname": f"Help Card ({lang.upper()}) — {color}",
        "Description": "Quick reference card",
        "GUID": new_guid(),
        "CustomImage": {
            "ImageURL": img(f"misc/help_card_{lang}.png"),
            "ImageSecondaryURL": "",
            "WidthScale": 0,
            "CustomTile": {
                "Type": 0,
                "Thickness": 0.1,
                "Stackable": False,
                "Stretch": True,
            },
        },
        "Locked": False,
        "Grid": False,
        "Snap": False,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_card(nickname: str, face_url: str, back_url: str, deck_id: int,
              card_pos_in_sheet: int = 0) -> dict:
    """Single CardCustom object (1x1 sheet = one face image per card)."""
    card_id = deck_id * 100 + card_pos_in_sheet
    return {
        "Name": "CardCustom",
        "Transform": transform(sx=1, sy=1, sz=1),
        "Nickname": nickname,
        "Description": "",
        "GUID": new_guid(),
        "CardID": card_id,
        "CustomDeck": {
            str(deck_id): {
                "FaceURL": face_url,
                "BackURL": back_url,
                "NumWidth": 1,
                "NumHeight": 1,
                "BackIsHidden": True,
                "UniqueBack": False,
            }
        },
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_deck(nickname: str, cards: list, pos: tuple) -> dict:
    """
    Wrap a list of CardCustom objects into a TTS Deck container.
    TTS requires:
      - ContainedObjects: the card objects (each with their own CustomDeck)
      - DeckIDs: list of CardID values in the same order
      - CustomDeck: merged dict of all unique deck definitions
    """
    x, y, z = pos
    contained = []
    deck_ids = []
    custom_deck_merged = {}

    for card in cards:
        contained.append(card)
        deck_ids.append(card["CardID"])
        custom_deck_merged.update(card["CustomDeck"])

    return {
        "Name": "DeckCustom",
        "Transform": transform(x, y, z, ry=180),
        "Nickname": nickname,
        "Description": "",
        "GUID": new_guid(),
        "DeckIDs": deck_ids,
        "CustomDeck": custom_deck_merged,
        "ContainedObjects": contained,
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_tile(nickname: str, face_url: str, back_url: str, pos: tuple,
              sx=1.0, sy=0.1, sz=1.0, locked=False) -> dict:
    x, y, z = pos
    return {
        "Name": "Custom_Tile",
        "Transform": transform(x, y, z, sx=sx, sy=sy, sz=sz),
        "Nickname": nickname,
        "Description": "",
        "GUID": new_guid(),
        "CustomImage": {
            "ImageURL": face_url,
            "ImageSecondaryURL": back_url,
            "WidthScale": 0,
            "CustomTile": {
                "Type": 0,
                "Thickness": 0.1,
                "Stackable": True,
                "Stretch": True,
            },
        },
        "Locked": locked,
        "Grid": False,
        "Snap": False,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_bag(nickname: str, description: str, pos: tuple,
             r=1.0, g=1.0, b=1.0, contents: list = None) -> dict:
    x, y, z = pos
    return {
        "Name": "Bag",
        "Transform": transform(x, y, z, sx=1, sy=1, sz=1),
        "Nickname": nickname,
        "Description": description,
        "GUID": new_guid(),
        "ColorDiffuse": color_rgb(r, g, b),
        "ContainedObjects": contents or [],
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_infinite_bag(nickname: str, description: str, pos: tuple,
                      r=1.0, g=1.0, b=1.0, contents: list = None) -> dict:
    x, y, z = pos
    return {
        "Name": "Infinite_Bag",
        "Transform": transform(x, y, z, sx=1, sy=1, sz=1),
        "Nickname": nickname,
        "Description": description,
        "GUID": new_guid(),
        "ColorDiffuse": color_rgb(r, g, b),
        "ContainedObjects": contents or [],
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_token_cylinder(nickname: str, pos: tuple, r=1.0, g=1.0, b=1.0) -> dict:
    """A simple BlockSquare token used for resources."""
    x, y, z = pos
    return {
        "Name": "BlockSquare",
        "Transform": transform(x, y, z, sx=0.5, sy=0.5, sz=0.5),
        "Nickname": nickname,
        "Description": "",
        "GUID": new_guid(),
        "ColorDiffuse": color_rgb(r, g, b),
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_coin(nickname: str, pos: tuple, r=0.9, g=0.75, b=0.1) -> dict:
    """A BlockSquare used as a coin token."""
    x, y, z = pos
    return {
        "Name": "BlockSquare",
        "Transform": transform(x, y, z, sx=0.4, sy=0.2, sz=0.4),
        "Nickname": nickname,
        "Description": "",
        "GUID": new_guid(),
        "ColorDiffuse": color_rgb(r, g, b),
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_link_tile(color: str, era: str, pos: tuple) -> dict:
    slug = "canal" if era == "canal" else "rail"
    face = img(f"misc/{slug}_{color}.png")
    back = img(f"misc/{slug}_{color}.png")
    return make_tile(f"{color} {era.capitalize()} Link", face, back, pos,
                     sx=0.7, sy=0.05, sz=0.7)


def make_merchant_tile(name: str, slug: str, pos: tuple) -> dict:
    face = img(f"misc/{slug}.png")
    back = img(f"misc/card_back.png")
    return make_tile(f"Merchant: {name}", face, back, pos, sx=1.2, sy=0.05, sz=0.8)


def make_language_toggle(pos: tuple) -> dict:
    face = img("misc/help_card_en.png")
    back = img("misc/help_card_zh.png")
    x, y, z = pos
    return {
        "Name": "Custom_Tile",
        "Transform": transform(x, y, z, sx=1.5, sy=0.1, sz=1.0),
        "Nickname": "Language Toggle (EN / ZH-TW)",
        "Description": "Flip to switch between English and Traditional Chinese",
        "GUID": new_guid(),
        "CustomImage": {
            "ImageURL": face,
            "ImageSecondaryURL": back,
            "WidthScale": 0,
            "CustomTile": {
                "Type": 0,
                "Thickness": 0.1,
                "Stackable": False,
                "Stretch": True,
            },
        },
        "Locked": False,
        "Grid": False,
        "Snap": False,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


# ---------------------------------------------------------------------------
# Building tile bags per player
# ---------------------------------------------------------------------------

# Tile counts per (industry, level) from BoardData.buildingCosts
TILE_COUNTS = {
    "cotton":       {1: 3, 2: 2, 3: 3, 4: 3},
    "coal":         {1: 1, 2: 2, 3: 2, 4: 2},
    "iron":         {1: 1, 2: 1, 3: 1, 4: 1},
    "brewery":      {1: 2, 2: 2, 3: 2, 4: 1},
    "manufacturer": {1: 1, 2: 2, 3: 1, 4: 1, 5: 2, 6: 1, 7: 1, 8: 2},
    "pottery":      {1: 1, 2: 1, 3: 1, 4: 1, 5: 1},
}


def make_building_tiles_for_industry(color: str, industry: str, max_level: int,
                                     bag_pos: tuple) -> dict:
    """One bag per industry per player, containing stacked front/back tile pairs."""
    tiles = []
    for lv in range(1, max_level + 1):
        count = TILE_COUNTS[industry].get(lv, 1)
        for _ in range(count):
            face = img(f"tiles/{industry}_lv{lv}_front.png")
            back = img(f"tiles/{industry}_lv{lv}_back.png")
            t = make_tile(
                f"{color} {industry.capitalize()} Lv{lv}",
                face, back, (0, 0, 0), sx=0.7, sy=0.05, sz=0.7,
            )
            tiles.append(t)

    color_map = {
        "Red":    (0.8, 0.1, 0.1),
        "Blue":   (0.1, 0.3, 0.9),
        "Yellow": (0.9, 0.8, 0.0),
        "Green":  (0.1, 0.7, 0.1),
    }
    r, g, b = color_map[color]
    return make_bag(
        f"{color} {industry.capitalize()} Tiles",
        f"Building tiles: {industry} for {color} player",
        bag_pos, r=r, g=g, b=b, contents=tiles,
    )


def make_player_building_bag(color: str, pos: tuple) -> dict:
    """One master bag per player containing all industry sub-bags."""
    color_map = {
        "Red":    (0.8, 0.1, 0.1),
        "Blue":   (0.1, 0.3, 0.9),
        "Yellow": (0.9, 0.8, 0.0),
        "Green":  (0.1, 0.7, 0.1),
    }
    r, g, b = color_map[color]

    industry_bags = []
    for i, (industry, max_level) in enumerate(INDUSTRIES):
        industry_bags.append(
            make_building_tiles_for_industry(color, industry, max_level, (0, 0, 0))
        )

    return make_bag(
        f"{color} Buildings",
        f"All building tiles for the {color} player",
        pos, r=r, g=g, b=b, contents=industry_bags,
    )


def make_player_link_bag(color: str, pos: tuple) -> dict:
    """Canal + rail link tiles for one player (14 links total each era)."""
    color_map = {
        "Red":    (0.8, 0.1, 0.1),
        "Blue":   (0.1, 0.3, 0.9),
        "Yellow": (0.9, 0.8, 0.0),
        "Green":  (0.1, 0.7, 0.1),
    }
    r, g, b = color_map[color]

    tiles = []
    for era in ("canal", "rail"):
        for _ in range(14):
            tiles.append(make_link_tile(color, era, (0, 0, 0)))

    return make_bag(
        f"{color} Link Tiles",
        f"Canal and rail link tiles for {color} player",
        pos, r=r, g=g, b=b, contents=tiles,
    )


# ---------------------------------------------------------------------------
# Draw deck builder
# ---------------------------------------------------------------------------

def build_draw_deck() -> dict:
    cards = []
    back_url = img("cards/card_back.png")
    deck_id = 1  # incremented per unique card face

    # Location cards
    for city, slug, count in LOCATION_CARDS:
        face_url = img(f"cards/{slug}_location.png")
        for _ in range(count):
            cards.append(make_card(f"Location: {city}", face_url, back_url, deck_id))
            deck_id += 1

    # Industry cards
    for ind_name, slug, count in INDUSTRY_CARDS:
        face_url = img(f"cards/{slug}.png")
        for _ in range(count):
            cards.append(make_card(f"Industry: {ind_name}", face_url, back_url, deck_id))
            deck_id += 1

    # Wild Location cards
    face_url = img("cards/wild_location.png")
    for _ in range(WILD_LOCATION_COUNT):
        cards.append(make_card("Wild Location", face_url, back_url, deck_id))
        deck_id += 1

    # Wild Industry cards
    face_url = img("cards/wild_industry.png")
    for _ in range(WILD_INDUSTRY_COUNT):
        cards.append(make_card("Wild Industry", face_url, back_url, deck_id))
        deck_id += 1

    # Shuffle
    random.shuffle(cards)

    return make_deck("Draw Deck", cards, DRAW_DECK_POS)


# ---------------------------------------------------------------------------
# Wild card supply stacks
# ---------------------------------------------------------------------------

def make_wild_location_pile() -> dict:
    back = img("cards/card_back.png")
    face = img("cards/wild_location.png")
    cards = []
    deck_id = 900
    for _ in range(4):
        cards.append(make_card("Wild Location (Supply)", face, back, deck_id))
        deck_id += 1
    return make_deck("Wild Location Supply", cards, WILD_LOC_POS)


def make_wild_industry_pile() -> dict:
    back = img("cards/card_back.png")
    face = img("cards/wild_industry.png")
    cards = []
    deck_id = 950
    for _ in range(4):
        cards.append(make_card("Wild Industry (Supply)", face, back, deck_id))
        deck_id += 1
    return make_deck("Wild Industry Supply", cards, WILD_IND_POS)


# ---------------------------------------------------------------------------
# Resource bags
# ---------------------------------------------------------------------------

def make_resource_bags() -> list:
    objs = []

    # Coal (dark grey cubes)
    coal_token = make_token_cylinder("Coal", (0, 0, 0), r=0.15, g=0.15, b=0.15)
    objs.append(make_infinite_bag(
        "Coal Supply", "Infinite coal cubes",
        COAL_BAG_POS, r=0.2, g=0.2, b=0.2,
        contents=[coal_token],
    ))

    # Iron (orange cubes)
    iron_token = make_token_cylinder("Iron", (0, 0, 0), r=0.9, g=0.45, b=0.05)
    objs.append(make_infinite_bag(
        "Iron Supply", "Infinite iron cubes",
        IRON_BAG_POS, r=0.9, g=0.5, b=0.1,
        contents=[iron_token],
    ))

    # Beer (cream/tan cylinders)
    beer_token = make_token_cylinder("Beer", (0, 0, 0), r=0.95, g=0.85, b=0.5)
    objs.append(make_infinite_bag(
        "Beer Supply", "Infinite beer barrels",
        BEER_BAG_POS, r=0.9, g=0.8, b=0.4,
        contents=[beer_token],
    ))

    # Money bags
    coin1  = make_coin("£1 Coin",  (0, 0, 0), r=0.8, g=0.7, b=0.1)
    coin5  = make_coin("£5 Coin",  (0, 0, 0), r=0.7, g=0.7, b=0.7)
    coin15 = make_coin("£15 Coin", (0, 0, 0), r=0.85, g=0.65, b=0.2)

    objs.append(make_infinite_bag(
        "£1 Coins", "Infinite £1 coins",
        MONEY1_BAG_POS, r=0.8, g=0.7, b=0.1,
        contents=[coin1],
    ))
    objs.append(make_infinite_bag(
        "£5 Coins", "Infinite £5 coins",
        MONEY5_BAG_POS, r=0.7, g=0.7, b=0.7,
        contents=[coin5],
    ))
    objs.append(make_infinite_bag(
        "£15 Coins", "Infinite £15 coins",
        MONEY15_BAG_POS, r=0.85, g=0.65, b=0.2,
        contents=[coin15],
    ))

    return objs


# ---------------------------------------------------------------------------
# Merchant tiles
# ---------------------------------------------------------------------------

def make_all_merchant_tiles() -> list:
    tiles = []
    for name, slug in MERCHANTS:
        pos = MERCHANT_POSITIONS[name]
        tiles.append(make_merchant_tile(name, slug, pos))
    return tiles


# ---------------------------------------------------------------------------
# Score/VP marker (simple disc per player on a score track)
# ---------------------------------------------------------------------------

def make_vp_disc(color: str, pos: tuple) -> dict:
    color_map = {
        "Red":    (0.8, 0.1, 0.1),
        "Blue":   (0.1, 0.3, 0.9),
        "Yellow": (0.9, 0.8, 0.0),
        "Green":  (0.1, 0.7, 0.1),
    }
    r, g, b = color_map[color]
    x, y, z = pos
    return {
        "Name": "BlockSquare",
        "Transform": transform(x, y, z, sx=0.4, sy=0.15, sz=0.4),
        "Nickname": f"{color} VP Disc",
        "Description": "Victory point marker",
        "GUID": new_guid(),
        "ColorDiffuse": color_rgb(r, g, b),
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


def make_income_disc(color: str, pos: tuple) -> dict:
    color_map = {
        "Red":    (0.8, 0.1, 0.1),
        "Blue":   (0.1, 0.3, 0.9),
        "Yellow": (0.9, 0.8, 0.0),
        "Green":  (0.1, 0.7, 0.1),
    }
    r, g, b = color_map[color]
    x, y, z = pos
    return {
        "Name": "BlockSquare",
        "Transform": transform(x, y, z, sx=0.35, sy=0.15, sz=0.35),
        "Nickname": f"{color} Income Disc",
        "Description": "Income track marker",
        "GUID": new_guid(),
        "ColorDiffuse": color_rgb(r, g, b),
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


# ---------------------------------------------------------------------------
# Main assembly
# ---------------------------------------------------------------------------

def build_save() -> dict:
    random.seed(42)  # deterministic shuffle for reproducibility
    objects = []

    # 1. Main board
    objects.append(make_board())

    # 2. Player areas
    for color in PLAYER_COLORS:
        px, py, pz = PLAYER_POSITIONS[color]

        # Player board
        objects.append(make_player_board(color, (px, py, pz)))

        # Help card (EN by default; ZH-TW face on the back via flip)
        objects.append(make_help_card(color, (px, py, pz), lang="en"))

        # Building tiles bag
        bx_offset = -3 if px < 0 else 3
        objects.append(make_player_building_bag(color, (px + bx_offset, py, pz - 5)))

        # Link tiles bag
        objects.append(make_player_link_bag(color, (px + bx_offset, py, pz - 8)))

        # VP and income disc — starting at track position 0 on the main board
        # We place them near the top-edge of the board in player colour order
        disc_x = -6 + PLAYER_COLORS.index(color) * 4
        objects.append(make_vp_disc(color,     (disc_x, 1.5, -10)))
        objects.append(make_income_disc(color, (disc_x, 1.5, -12)))

    # 3. Draw deck
    objects.append(build_draw_deck())

    # 4. Wild card supply piles
    objects.append(make_wild_location_pile())
    objects.append(make_wild_industry_pile())

    # 5. Resource infinite bags
    objects.extend(make_resource_bags())

    # 6. Merchant tiles
    objects.extend(make_all_merchant_tiles())

    # 7. Language toggle
    objects.append(make_language_toggle(LANG_TOGGLE_POS))

    now = datetime.utcnow().strftime("%m/%d/%Y %H:%M:%S")

    save = {
        "SaveName": "Brass Birmingham Prototype",
        "Date": now,
        "VersionNumber": "v1.0",
        "GameMode": "Brass: Birmingham",
        "Table": "Table_None",
        "Sky": "Sky_Museum",
        "Note": (
            "Brass: Birmingham prototype mod.\n"
            "Run scripts/serve_assets.py before loading to serve images from localhost."
        ),
        "LuaScript": "-- Global script: load via TTS Scripting Editor #include\n",
        "LuaScriptState": "",
        "XmlUI": "",
        "ObjectStates": objects,
    }
    return save


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_path = os.path.join(project_root, "brass_birmingham.json")

    save_data = build_save()

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(save_data, f, indent=2, ensure_ascii=False)

    total_objects = len(save_data["ObjectStates"])
    print(f"Generated: {out_path}")
    print(f"Top-level objects: {total_objects}")
    print()
    print("Next steps:")
    print("  1. Start the asset server:  python scripts/serve_assets.py")
    print(f"  2. Copy {os.path.basename(out_path)} to your TTS Saves folder:")
    print("       %USERPROFILE%/Documents/My Games/Tabletop Simulator/Saves/")
    print("  3. Launch TTS and load the save.")
