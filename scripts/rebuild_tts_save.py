#!/usr/bin/env python3
"""Rebuild the Brass: Birmingham TTS save file using original game assets.

Run `python scripts/serve_assets.py` first so TTS can load images from localhost.
Original assets are served from assets/original/ at http://localhost:8080/original/.

Output:
  brass_birmingham.json  (project root)
  C:/Users/andyc/OneDrive/ドキュメント/My Games/Tabletop Simulator/Saves/TS_Save_99.json
"""

import json
import os
import random
import shutil
import string
from datetime import datetime

# ---------------------------------------------------------------------------
# Player color mapping
#   Source mod:  purple, grey/white, orange, yellow
#   Our mod:     Red,    Blue,       Green,  Yellow
# ---------------------------------------------------------------------------

# For building tiles and link tiles the source images use these color names:
#   purple -> Red
#   grey   -> Blue
#   orange -> Green
#   yellow -> Yellow

SRC_COLOR = {
    "Red":    "purple",
    "Blue":   "grey",
    "Yellow": "yellow",
    "Green":  "orange",
}

# Merchant portrait pairs (source colour -> (img1, img2))
# red/brown background -> Red player (player 1)
# purple background    -> Blue player (player 2)
# light blue           -> Yellow player (player 3)  [closest to none]
# gold/olive           -> Green player (player 4)
MERCHANT_IMGS = {
    "Red":    ("merchant_red_1.png",    "merchant_red_2.png"),
    "Blue":   ("merchant_purple_1.png", "merchant_purple_2.png"),
    "Yellow": ("merchant_blue_1.png",   "merchant_blue_2.png"),
    "Green":  ("merchant_gold_1.png",   "merchant_gold_2.png"),
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_used_guids: set = set()


def new_guid() -> str:
    while True:
        g = "".join(random.choices(string.hexdigits[:16], k=6)).lower()
        if g not in _used_guids:
            _used_guids.add(g)
            return g


BASE_URL = "http://localhost:8080"


def orig(filename: str) -> str:
    """URL for a file in assets/original/."""
    return f"{BASE_URL}/original/{filename}"


def proto(path: str) -> str:
    """URL for a legacy prototype asset (fallback)."""
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

LOCATION_CARDS = [
    ("Birmingham",      4),
    ("Coventry",        2),
    ("Dudley",          2),
    ("Kidderminster",   2),
    ("Wolverhampton",   2),
    ("Coalbrookdale",   3),
    ("Nuneaton",        2),
    ("Worcester",       2),
    ("Tamworth",        2),
    ("Walsall",         2),
    ("Cannock",         2),
    ("Burton-on-Trent", 3),
    ("Stafford",        2),
    ("Stoke-on-Trent",  3),
    ("Leek",            2),
    ("Stone",           2),
    ("Uttoxeter",       2),
    ("Belper",          3),
    ("Derby",           3),
    ("Redditch",        2),
]

INDUSTRY_CARDS = [
    ("Cotton Mill",   3),
    ("Coal Mine",     4),
    ("Iron Works",    4),
    ("Brewery",       5),
    ("Manufacturer",  4),
    ("Pottery",       2),
]

WILD_LOCATION_COUNT = 2
WILD_INDUSTRY_COUNT = 2

PLAYER_COLORS = ["Red", "Blue", "Yellow", "Green"]

PLAYER_COLOR_RGB = {
    "Red":    (0.8, 0.1, 0.1),
    "Blue":   (0.1, 0.3, 0.9),
    "Yellow": (0.9, 0.8, 0.0),
    "Green":  (0.1, 0.7, 0.1),
}

INDUSTRIES = [
    ("cotton",       4),
    ("coal",         4),
    ("iron",         4),
    ("brewery",      4),
    ("manufacturer", 8),
    ("pottery",      5),
]

TILE_COUNTS = {
    "cotton":       {1: 3, 2: 2, 3: 3, 4: 3},
    "coal":         {1: 1, 2: 2, 3: 2, 4: 2},
    "iron":         {1: 1, 2: 1, 3: 1, 4: 1},
    "brewery":      {1: 2, 2: 2, 3: 2, 4: 1},
    "manufacturer": {1: 1, 2: 2, 3: 1, 4: 1, 5: 2, 6: 1, 7: 1, 8: 2},
    "pottery":      {1: 1, 2: 1, 3: 1, 4: 1, 5: 1},
}

MERCHANTS = [
    "Shrewsbury",
    "Gloucester",
    "Oxford",
    "Warrington",
    "Nottingham",
]

# ---------------------------------------------------------------------------
# Table layout
# ---------------------------------------------------------------------------

BOARD_X, BOARD_Y, BOARD_Z = 0.0, 1.0, 0.0

PLAYER_POSITIONS = {
    "Red":    (-20, 1,  16),
    "Blue":   ( 20, 1,  16),
    "Yellow": (-20, 1, -16),
    "Green":  ( 20, 1, -16),
}

COAL_BAG_POS    = (14, 1,  -3)
IRON_BAG_POS    = (14, 1,   0)
BEER_BAG_POS    = (14, 1,   3)
MONEY1_BAG_POS  = (14, 1,   7)
MONEY5_BAG_POS  = (14, 1,  10)
MONEY15_BAG_POS = (14, 1,  13)

DRAW_DECK_POS   = (-14, 2.5,  0)
WILD_LOC_POS    = (-14, 1,   -6)
WILD_IND_POS    = (-11, 1,   -6)

MERCHANT_POSITIONS = {
    "Shrewsbury":  (-10, 1, 11),
    "Gloucester":  ( -5, 1, 11),
    "Oxford":      (  0, 1, 11),
    "Warrington":  (  5, 1, 11),
    "Nottingham":  ( 10, 1, 11),
}

PLAYER_AID_POSITIONS = {
    "Red":    (-28, 1,  16),
    "Blue":   ( 28, 1,  16),
    "Yellow": (-28, 1, -16),
    "Green":  ( 28, 1, -16),
}

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
            "ImageURL": orig("board.jpg"),
            "ImageSecondaryURL": orig("board.jpg"),
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
    src = SRC_COLOR[color]
    x, y, z = pos
    return {
        "Name": "Custom_Tile",
        "Transform": transform(x, y, z, ry=180, sx=5, sy=1, sz=3.5),
        "Nickname": f"{color} Player Board",
        "Description": f"Player board for {color}",
        "GUID": new_guid(),
        "CustomImage": {
            "ImageURL": orig(f"player_board_{src}.jpg"),
            "ImageSecondaryURL": orig(f"player_board_{src}.jpg"),
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


def make_player_aid(color: str, pos: tuple) -> dict:
    """3-panel player aid: flow, cards, actions — stacked near the player board."""
    x, y, z = pos
    aids = [
        ("player_aid_flow_zh.jpg",    "Game Flow Reference"),
        ("player_aid_cards_zh.jpg",   "Card Distribution Reference"),
        ("player_aid_actions_zh.jpg", "Action Types Reference"),
    ]
    objs = []
    for i, (fname, label) in enumerate(aids):
        objs.append({
            "Name": "Custom_Tile",
            "Transform": transform(x + i * 3.5, y, z, ry=0, sx=2.5, sy=1, sz=3.5),
            "Nickname": f"{label} ({color})",
            "Description": "Player reference card — Traditional Chinese",
            "GUID": new_guid(),
            "CustomImage": {
                "ImageURL": orig(fname),
                "ImageSecondaryURL": orig(fname),
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
        })
    return objs


# ---------------------------------------------------------------------------
# Card helpers — sprite sheet approach
# ---------------------------------------------------------------------------

def make_card_from_sheet(nickname: str, deck_id: int, card_index: int,
                         face_url: str, back_url: str,
                         num_width: int, num_height: int,
                         unique_back: bool = False) -> dict:
    """
    A single card drawn from a sprite sheet.
    card_index: 0-based position in the sheet (row-major).
    CardID = deck_id * 100 + card_index
    """
    card_id = deck_id * 100 + card_index
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
                "NumWidth": num_width,
                "NumHeight": num_height,
                "BackIsHidden": True,
                "UniqueBack": unique_back,
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


# ---------------------------------------------------------------------------
# Draw deck — uses the 6x6 face sheet (deck_id=1) for most cards,
# 4x8 sheet (deck_id=2) for overflow cards beyond 36.
#
# The 6x6 sheet has 36 cells (cols 0-5, rows 0-5), row-major.
# The 4x8 sheet has 32 cells (cols 0-3, rows 0-7), row-major.
# We assign cells sequentially; any leftover cards use the single back image.
# ---------------------------------------------------------------------------

BACK_URL = orig("card_back_single.jpg")
SHEET_6X6_FACE  = orig("cards_face_6x6.jpg")
SHEET_4X8_FACE  = orig("cards_face_4x8.jpg")
SHEET_4X8_BACK  = orig("cards_back_4x8.jpg")

DECK_ID_6X6 = 1   # 6x6 sheet,  max 36 unique card positions
DECK_ID_4X8 = 2   # 4x8 sheet,  max 32 unique card positions


def _all_card_specs() -> list:
    """
    Return list of (nickname, deck_id, card_index) for every card in the draw
    deck, assigning sprite-sheet positions sequentially.
    """
    specs = []
    idx_6x6 = 0   # current position in the 6x6 sheet
    idx_4x8 = 0   # current position in the 4x8 sheet

    def next_pos(nickname):
        nonlocal idx_6x6, idx_4x8
        if idx_6x6 < 36:
            pos = (DECK_ID_6X6, idx_6x6)
            idx_6x6 += 1
        else:
            pos = (DECK_ID_4X8, idx_4x8)
            idx_4x8 += 1
        return pos

    for city, count in LOCATION_CARDS:
        for _ in range(count):
            deck_id, card_idx = next_pos(city)
            specs.append((f"Location: {city}", deck_id, card_idx))

    for ind_name, count in INDUSTRY_CARDS:
        for _ in range(count):
            deck_id, card_idx = next_pos(ind_name)
            specs.append((f"Industry: {ind_name}", deck_id, card_idx))

    for _ in range(WILD_LOCATION_COUNT):
        deck_id, card_idx = next_pos("Wild Location")
        specs.append(("Wild Location", deck_id, card_idx))

    for _ in range(WILD_INDUSTRY_COUNT):
        deck_id, card_idx = next_pos("Wild Industry")
        specs.append(("Wild Industry", deck_id, card_idx))

    return specs


def build_draw_deck() -> dict:
    specs = _all_card_specs()
    cards = []
    for nickname, deck_id, card_idx in specs:
        if deck_id == DECK_ID_6X6:
            card = make_card_from_sheet(
                nickname, deck_id, card_idx,
                SHEET_6X6_FACE, BACK_URL, 6, 6,
            )
        else:
            card = make_card_from_sheet(
                nickname, deck_id, card_idx,
                SHEET_4X8_FACE, SHEET_4X8_BACK, 4, 8,
            )
        cards.append(card)

    random.shuffle(cards)
    return make_deck("Draw Deck", cards, DRAW_DECK_POS)


def make_wild_location_pile() -> dict:
    # 4 supply copies — use first 4 positions of the 4x8 back sheet
    DECK_ID = 10
    cards = []
    for i in range(4):
        card = make_card_from_sheet(
            "Wild Location (Supply)", DECK_ID, i,
            orig("wild_location_back.jpg"), BACK_URL, 1, 1,
        )
        cards.append(card)
    return make_deck("Wild Location Supply", cards, WILD_LOC_POS)


def make_wild_industry_pile() -> dict:
    # 4 supply copies using the wild industry sheet (3x2 grid)
    DECK_ID = 11
    cards = []
    for i in range(4):
        # Cycle through the 6 cells of the 3x2 sheet
        card = make_card_from_sheet(
            "Wild Industry (Supply)", DECK_ID, i % 6,
            orig("wild_industry_sheet.jpg"), BACK_URL, 3, 2,
        )
        cards.append(card)
    return make_deck("Wild Industry Supply", cards, WILD_IND_POS)


# ---------------------------------------------------------------------------
# Building tiles — CustomDeck per player using tile sprite sheets
# ---------------------------------------------------------------------------

def make_tile_deck_for_player(color: str, pos: tuple) -> dict:
    """
    One CustomDeck per player whose face sheet is tiles_front_{src}.jpg (8x7)
    and back sheet is tiles_back_all.jpg.

    We create one CardCustom per (industry, level) combination, repeated for
    each copy of that tile.  Positions are assigned left-to-right, top-to-bottom
    across the 8x7 sheet (56 cells max).
    """
    src = SRC_COLOR[color]
    r, g, b = PLAYER_COLOR_RGB[color]
    DECK_ID = 20 + PLAYER_COLORS.index(color)  # 20, 21, 22, 23

    face_url = orig(f"tiles_front_{src}.jpg")
    back_url = orig("tiles_back_all.jpg")

    tiles = []
    sheet_idx = 0  # position in the 8x7 front sheet

    for industry, max_level in INDUSTRIES:
        for lv in range(1, max_level + 1):
            count = TILE_COUNTS[industry].get(lv, 1)
            for _ in range(count):
                card = make_card_from_sheet(
                    f"{color} {industry.capitalize()} Lv{lv}",
                    DECK_ID, sheet_idx,
                    face_url, back_url, 8, 7,
                )
                tiles.append(card)
                sheet_idx += 1  # each copy occupies a new cell in the sheet

    x, y, z = pos
    contained = []
    deck_ids = []
    custom_deck_merged = {}
    for t in tiles:
        contained.append(t)
        deck_ids.append(t["CardID"])
        custom_deck_merged.update(t["CustomDeck"])

    return {
        "Name": "DeckCustom",
        "Transform": transform(x, y, z, ry=0),
        "Nickname": f"{color} Building Tiles",
        "Description": f"All building tiles for {color} player",
        "GUID": new_guid(),
        "DeckIDs": deck_ids,
        "CustomDeck": custom_deck_merged,
        "ContainedObjects": contained,
        "ColorDiffuse": color_rgb(r, g, b),
        "Locked": False,
        "Grid": True,
        "Snap": True,
        "Autoraise": True,
        "Sticky": True,
        "Tooltip": True,
    }


# ---------------------------------------------------------------------------
# Link tiles — each player colour has canal and rail sprite sheets (2 tiles each)
# We use Custom_Tile objects
# ---------------------------------------------------------------------------

def make_tile_obj(nickname: str, face_url: str, back_url: str, pos: tuple,
                  sx=1.0, sy=0.05, sz=1.0, locked=False) -> dict:
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
        "Transform": transform(x, y, z),
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
        "Transform": transform(x, y, z),
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


def make_player_link_bag(color: str, pos: tuple) -> dict:
    src = SRC_COLOR[color]
    r, g, b = PLAYER_COLOR_RGB[color]
    tiles = []
    for era in ("canal", "rail"):
        face = orig(f"link_{src}_{era}.jpg")
        for _ in range(14):
            tiles.append(make_tile_obj(
                f"{color} {era.capitalize()} Link",
                face, face, (0, 0, 0), sx=0.7, sy=0.05, sz=0.7,
            ))
    return make_bag(
        f"{color} Link Tiles",
        f"Canal and rail link tiles for {color} player",
        pos, r=r, g=g, b=b, contents=tiles,
    )


# ---------------------------------------------------------------------------
# Merchant tiles — circular portrait tokens
# ---------------------------------------------------------------------------

def make_merchant_tile(name: str, color: str, portrait_num: int, pos: tuple) -> dict:
    """One merchant token (Custom_Tile) using the original portrait PNG."""
    img_file = MERCHANT_IMGS[color][portrait_num - 1]
    face = orig(img_file)
    return make_tile_obj(
        f"Merchant: {name}",
        face, face, pos, sx=1.2, sy=0.05, sz=1.2,
    )


def make_all_merchant_tiles() -> list:
    tiles = []
    # Assign one portrait per merchant city; cycle through all four player colours
    color_cycle = ["Red", "Blue", "Yellow", "Green"]
    for i, name in enumerate(MERCHANTS):
        color = color_cycle[i % len(color_cycle)]
        portrait = (i // len(color_cycle)) + 1
        portrait = max(1, min(portrait, 2))
        pos = MERCHANT_POSITIONS[name]
        tiles.append(make_merchant_tile(name, color, portrait, pos))
    return tiles


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

def make_token_cylinder(nickname: str, pos: tuple, r=1.0, g=1.0, b=1.0) -> dict:
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


def make_resource_bags() -> list:
    objs = []
    coal_token = make_token_cylinder("Coal", (0,0,0), r=0.15, g=0.15, b=0.15)
    objs.append(make_infinite_bag("Coal Supply", "Infinite coal cubes",
        COAL_BAG_POS, r=0.2, g=0.2, b=0.2, contents=[coal_token]))

    iron_token = make_token_cylinder("Iron", (0,0,0), r=0.9, g=0.45, b=0.05)
    objs.append(make_infinite_bag("Iron Supply", "Infinite iron cubes",
        IRON_BAG_POS, r=0.9, g=0.5, b=0.1, contents=[iron_token]))

    beer_token = make_token_cylinder("Beer", (0,0,0), r=0.95, g=0.85, b=0.5)
    objs.append(make_infinite_bag("Beer Supply", "Infinite beer barrels",
        BEER_BAG_POS, r=0.9, g=0.8, b=0.4, contents=[beer_token]))

    coin1  = make_coin("£1 Coin",  (0,0,0), r=0.8, g=0.7, b=0.1)
    coin5  = make_coin("£5 Coin",  (0,0,0), r=0.7, g=0.7, b=0.7)
    coin15 = make_coin("£15 Coin", (0,0,0), r=0.85, g=0.65, b=0.2)
    objs.append(make_infinite_bag("£1 Coins",  "Infinite £1 coins",
        MONEY1_BAG_POS,  r=0.8, g=0.7, b=0.1, contents=[coin1]))
    objs.append(make_infinite_bag("£5 Coins",  "Infinite £5 coins",
        MONEY5_BAG_POS,  r=0.7, g=0.7, b=0.7, contents=[coin5]))
    objs.append(make_infinite_bag("£15 Coins", "Infinite £15 coins",
        MONEY15_BAG_POS, r=0.85, g=0.65, b=0.2, contents=[coin15]))
    return objs


# ---------------------------------------------------------------------------
# VP / Income discs
# ---------------------------------------------------------------------------

def make_disc(nickname: str, desc: str, color: str, pos: tuple,
              sx=0.4, sy=0.15, sz=0.4) -> dict:
    r, g, b = PLAYER_COLOR_RGB[color]
    x, y, z = pos
    return {
        "Name": "BlockSquare",
        "Transform": transform(x, y, z, sx=sx, sy=sy, sz=sz),
        "Nickname": nickname,
        "Description": desc,
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
    random.seed(42)
    objects = []

    # 1. Main board
    objects.append(make_board())

    # 2. Player areas
    for color in PLAYER_COLORS:
        px, py, pz = PLAYER_POSITIONS[color]

        # Player board (original asset)
        objects.append(make_player_board(color, (px, py, pz)))

        # Player aids (3 reference cards, zh-TW)
        aid_pos = PLAYER_AID_POSITIONS[color]
        objects.extend(make_player_aid(color, aid_pos))

        # Building tile deck (original sprite sheet)
        bx_offset = -3 if px < 0 else 3
        objects.append(make_tile_deck_for_player(color, (px + bx_offset, py, pz - 5)))

        # Link tiles bag (original canal/rail images)
        objects.append(make_player_link_bag(color, (px + bx_offset, py, pz - 8)))

        # VP and income discs
        disc_x = -6 + PLAYER_COLORS.index(color) * 4
        objects.append(make_disc(f"{color} VP Disc", "Victory point marker",
                                 color, (disc_x, 1.5, -10)))
        objects.append(make_disc(f"{color} Income Disc", "Income track marker",
                                 color, (disc_x, 1.5, -12), sx=0.35, sy=0.15, sz=0.35))

    # 3. Draw deck (sprite-sheet cards)
    objects.append(build_draw_deck())

    # 4. Wild card supply piles
    objects.append(make_wild_location_pile())
    objects.append(make_wild_industry_pile())

    # 5. Resource infinite bags
    objects.extend(make_resource_bags())

    # 6. Merchant tiles (original portrait PNGs)
    objects.extend(make_all_merchant_tiles())

    now = datetime.utcnow().strftime("%m/%d/%Y %H:%M:%S")

    save = {
        "SaveName": "Brass Birmingham (Original Assets)",
        "Date": now,
        "VersionNumber": "v2.0",
        "GameMode": "Brass: Birmingham",
        "Table": "Table_None",
        "Sky": "Sky_Museum",
        "Note": (
            "Brass: Birmingham mod with original game assets.\n"
            "Run scripts/serve_assets.py before loading to serve images from localhost.\n"
            "Assets served from assets/original/ at http://localhost:8080/original/"
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

TTS_SAVES_DIR = (
    r"C:\Users\andyc\OneDrive\ドキュメント\My Games\Tabletop Simulator\Saves"
)
TTS_SAVE_NAME = "TS_Save_99.json"


if __name__ == "__main__":
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_path = os.path.join(project_root, "brass_birmingham.json")

    save_data = build_save()

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(save_data, f, indent=2, ensure_ascii=False)

    total_objects = len(save_data["ObjectStates"])
    print(f"Generated: {out_path}")
    print(f"Top-level objects: {total_objects}")

    # Copy to TTS Saves folder
    tts_dest = os.path.join(TTS_SAVES_DIR, TTS_SAVE_NAME)
    if os.path.isdir(TTS_SAVES_DIR):
        shutil.copy2(out_path, tts_dest)
        print(f"Copied to TTS: {tts_dest}")
    else:
        print(f"WARNING: TTS saves directory not found: {TTS_SAVES_DIR}")
        print(f"  Copy {out_path} manually.")

    print()
    print("Next steps:")
    print("  1. Start the asset server:  python scripts/serve_assets.py")
    print("  2. Launch TTS and load TS_Save_99 from the Saves menu.")
