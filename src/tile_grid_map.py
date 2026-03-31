"""
Brass: Birmingham — Tile Sprite Sheet Grid Mapping

The tile sprite sheets (9 cols x 7 rows = 63 positions) contain two player sets:
  Upper half (pos 0-30): Player set A (purple bg / orange bg)
  Lower half (pos 31-62): Player set B (blue bg / yellow bg)

Both halves have identical tile layouts, just different player colors.

Each grid position maps to (industry, level).
Multiple copies of the same tile type use different grid positions.
"""

# Upper half: pos 0-30
UPPER_HALF = {
    # Row 0: Cotton I-IV, Iron I-IV, Brewery I
    0: ("cotton", 1),
    1: ("cotton", 2),
    2: ("cotton", 3),
    3: ("cotton", 4),
    4: ("iron", 1),
    5: ("iron", 2),
    6: ("iron", 3),
    7: ("iron", 4),
    8: ("brewery", 1),
    # Row 1: Brewery II-IV, Coal I-IV, Pottery I(no-dev), Pottery II
    9: ("brewery", 2),
    10: ("brewery", 3),
    11: ("brewery", 4),
    12: ("coal", 1),
    13: ("coal", 2),
    14: ("coal", 3),
    15: ("coal", 4),
    16: ("pottery", 1),     # has no-develop icon
    17: ("pottery", 2),
    # Row 2: Pottery III(no-dev), IV, V, Mfr I, Mfr II, Mfr II(copy2), Mfr III, Mfr IV, Mfr V
    18: ("pottery", 3),     # has no-develop icon
    19: ("pottery", 4),
    20: ("pottery", 5),
    21: ("manufacturer", 1),
    22: ("manufacturer", 2),
    23: ("manufacturer", 2),  # 2nd copy
    24: ("manufacturer", 3),
    25: ("manufacturer", 4),
    26: ("manufacturer", 5),
    27: ("manufacturer", 5),  # 2nd copy
    # Row 3 partial: Mfr VI, VII, VIII, VIII(copy2)
    28: ("manufacturer", 6),
    29: ("manufacturer", 7),
    30: ("manufacturer", 8),
    # pos 31 onwards = lower half
}

# Lower half: pos 31-62 (same layout, different player)
LOWER_HALF = {
    # Row 3 continued: Cotton I-IV, Iron I-IV, Brewery I
    31: ("cotton", 1),
    32: ("cotton", 2),
    33: ("cotton", 3),
    34: ("cotton", 4),
    35: ("iron", 1),
    36: ("iron", 2),
    37: ("iron", 3),
    38: ("iron", 4),
    39: ("brewery", 1),
    # Row 4+: Brewery II-IV, Coal I-IV, Pottery I(no-dev), Pottery II
    40: ("brewery", 2),
    41: ("brewery", 3),
    42: ("brewery", 4),
    43: ("coal", 1),
    44: ("coal", 2),
    45: ("coal", 3),
    46: ("coal", 4),
    47: ("pottery", 1),     # no-develop
    48: ("pottery", 2),
    # Pottery III(no-dev), IV, V, Mfr I, Mfr II, Mfr II(copy2), Mfr III, Mfr IV, Mfr V
    49: ("pottery", 3),     # no-develop
    50: ("pottery", 4),
    51: ("pottery", 5),
    52: ("manufacturer", 1),
    53: ("manufacturer", 2),
    54: ("manufacturer", 2),  # 2nd copy
    55: ("manufacturer", 3),
    56: ("manufacturer", 4),
    57: ("manufacturer", 5),
    58: ("manufacturer", 5),  # 2nd copy
    # Mfr VI, VII, VIII
    59: ("manufacturer", 6),
    60: ("manufacturer", 7),
    61: ("manufacturer", 8),
    # 62: EMPTY
}

# Combined: all positions
ALL_POSITIONS = {}
ALL_POSITIONS.update(UPPER_HALF)
ALL_POSITIONS.update(LOWER_HALF)

# Build cost per tile type (money only — coal/iron costs are separate market transactions)
TILE_MONEY_COST = {
    ("cotton", 1): 12, ("cotton", 2): 14, ("cotton", 3): 16, ("cotton", 4): 18,
    ("iron", 1): 5, ("iron", 2): 7, ("iron", 3): 9, ("iron", 4): 12,
    ("coal", 1): 5, ("coal", 2): 7, ("coal", 3): 8, ("coal", 4): 10,
    ("brewery", 1): 5, ("brewery", 2): 7, ("brewery", 3): 9, ("brewery", 4): 9,
    ("manufacturer", 1): 8, ("manufacturer", 2): 10, ("manufacturer", 3): 12,
    ("manufacturer", 4): 8, ("manufacturer", 5): 16, ("manufacturer", 6): 20,
    ("manufacturer", 7): 16, ("manufacturer", 8): 20,
    ("pottery", 1): 17, ("pottery", 2): 0, ("pottery", 3): 22,
    ("pottery", 4): 0, ("pottery", 5): 24,
}

# Full cost including resource requirements
TILE_FULL_COST = {
    ("cotton", 1): {"money": 12, "coal": 0, "iron": 0},
    ("cotton", 2): {"money": 14, "coal": 1, "iron": 0},
    ("cotton", 3): {"money": 16, "coal": 1, "iron": 1},
    ("cotton", 4): {"money": 18, "coal": 1, "iron": 1},
    ("iron", 1): {"money": 5, "coal": 1, "iron": 0},
    ("iron", 2): {"money": 7, "coal": 1, "iron": 0},
    ("iron", 3): {"money": 9, "coal": 1, "iron": 0},
    ("iron", 4): {"money": 12, "coal": 1, "iron": 0},
    ("coal", 1): {"money": 5, "coal": 0, "iron": 0},
    ("coal", 2): {"money": 7, "coal": 0, "iron": 0},
    ("coal", 3): {"money": 8, "coal": 0, "iron": 1},
    ("coal", 4): {"money": 10, "coal": 0, "iron": 1},
    ("brewery", 1): {"money": 5, "coal": 0, "iron": 1},
    ("brewery", 2): {"money": 7, "coal": 0, "iron": 1},
    ("brewery", 3): {"money": 9, "coal": 0, "iron": 1},
    ("brewery", 4): {"money": 9, "coal": 0, "iron": 1},
    ("manufacturer", 1): {"money": 8, "coal": 1, "iron": 0},
    ("manufacturer", 2): {"money": 10, "coal": 0, "iron": 1},
    ("manufacturer", 3): {"money": 12, "coal": 2, "iron": 0},
    ("manufacturer", 4): {"money": 8, "coal": 0, "iron": 1},
    ("manufacturer", 5): {"money": 16, "coal": 1, "iron": 0},
    ("manufacturer", 6): {"money": 20, "coal": 0, "iron": 0},
    ("manufacturer", 7): {"money": 16, "coal": 1, "iron": 1},
    ("manufacturer", 8): {"money": 20, "coal": 0, "iron": 2},
    ("pottery", 1): {"money": 17, "coal": 0, "iron": 1},
    ("pottery", 2): {"money": 0, "coal": 1, "iron": 0},
    ("pottery", 3): {"money": 22, "coal": 2, "iron": 0},
    ("pottery", 4): {"money": 0, "coal": 1, "iron": 0},
    ("pottery", 5): {"money": 24, "coal": 2, "iron": 0},
}
