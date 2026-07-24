#!/usr/bin/env python3
"""
inject_scripts.py

Reads the reference Brass: Birmingham TTS mod JSON, injects our bundled Lua
Global Script and XML UI into it, and writes a new save file ready to load
in Tabletop Simulator.

Strategy
--------
Each src/ and tts/ module uses `local X = {}` … `return X`.  To inline them
all into a single TTS Global script we:

  1. Strip every `local <name> = require(…)` line (the dependency is already a
     global from a previous section in the bundle).
  2. Change the leading `local <ModuleName> = {}` declaration to a bare
     `<ModuleName> = {}` so the table becomes a global that later modules can
     reference.
  3. Strip the trailing `return <ModuleName>` line (no caller to receive it).

For tts/Global.lua we:
  - Remove every `#include …` line (already inlined above).
  - Keep everything else verbatim.

The result is one large Lua chunk that TTS executes as its Global script.
"""

import json
import re
import shutil
import sys
from pathlib import Path

# Make src/ importable from the scripts/ directory
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
from tile_grid_map import ALL_POSITIONS, TILE_FULL_COST  # noqa: E402

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SRC_MOD_PATH = Path(
    r"C:\Users\andyc\OneDrive\ドキュメント\My Games\Tabletop Simulator"
    r"\Mods\Workshop\3073008847.json"
)

TTS_SAVES_PATH = Path(
    r"C:\Users\andyc\OneDrive\ドキュメント\My Games\Tabletop Simulator"
    r"\Saves\TS_Save_99.json"
)

OUTPUT_PATH = PROJECT_ROOT / "brass_birmingham_scripted.json"

# Module order mirrors Global.lua's #include directives
SRC_MODULES = [
    ("helpers",       PROJECT_ROOT / "src" / "helpers.lua"),
    ("Constants",     PROJECT_ROOT / "src" / "Constants.lua"),
    ("BoardData",     PROJECT_ROOT / "src" / "BoardData.lua"),
    ("Tile",          PROJECT_ROOT / "src" / "Tile.lua"),
    ("IncomeTrack",   PROJECT_ROOT / "src" / "IncomeTrack.lua"),
    ("GameState",     PROJECT_ROOT / "src" / "GameState.lua"),
    ("Network",       PROJECT_ROOT / "src" / "Network.lua"),
    ("Market",        PROJECT_ROOT / "src" / "Market.lua"),
    ("TurnManager",   PROJECT_ROOT / "src" / "TurnManager.lua"),
    ("Validation",    PROJECT_ROOT / "src" / "Validation.lua"),
    ("Actions",       PROJECT_ROOT / "src" / "Actions.lua"),
    ("ActionEngine",  PROJECT_ROOT / "src" / "ActionEngine.lua"),
    ("Scoring",       PROJECT_ROOT / "src" / "Scoring.lua"),
    ("EraTransition", PROJECT_ROOT / "src" / "EraTransition.lua"),
    ("Lang",          PROJECT_ROOT / "src" / "Lang.lua"),
    ("SnapMap",       PROJECT_ROOT / "tts" / "SnapMap.lua"),
    ("ObjectManager", PROJECT_ROOT / "tts" / "ObjectManager.lua"),
    ("CardManager",   PROJECT_ROOT / "tts" / "CardManager.lua"),
    ("Highlights",    PROJECT_ROOT / "tts" / "Highlights.lua"),
    ("UIManager",     PROJECT_ROOT / "tts" / "UIManager.lua"),
    ("EventHandlers",     PROJECT_ROOT / "tts" / "EventHandlers.lua"),
    ("MarketLayout",       PROJECT_ROOT / "tts" / "MarketLayout.lua"),
    ("IncomeLayout",       PROJECT_ROOT / "tts" / "IncomeLayout.lua"),
    ("ResourceAnimation",  PROJECT_ROOT / "tts" / "ResourceAnimation.lua"),
]

GLOBAL_LUA = PROJECT_ROOT / "tts" / "Global.lua"
XML_UI     = PROJECT_ROOT / "xml" / "UI.xml"

# ---------------------------------------------------------------------------
# Spend tracker configuration
# ---------------------------------------------------------------------------

# GUIDs of the board Counter objects to replace with spend trackers
SPEND_TRACKER_GUIDS = {"9f808b", "b05299", "26e57c", "719019"}

SPEND_TRACKER_SCRIPT = r"""-- Spend Tracker (modified MrStump counter)
-- Syncs with money counter via Global script

function onSave()
    return JSON.encode({saved_count = count})
end

function onload(saved_data)
    generateButtonParamiters()
    if saved_data ~= '' then
        count = JSON.decode(saved_data).saved_count
    else
        count = 0
    end
    b_display.label = tostring(count)
    if count >= 100 then b_display.font_size = 360 else b_display.font_size = 500 end
    self.createButton(b_display)
    self.createButton(b_plus)
    self.createButton(b_minus)
    self.createButton(b_plus5)
    self.createButton(b_minus5)
end

function increase()
    count = count + 1
    updateDisplay()
    syncMoney()
end

function decrease()
    if count > 0 then count = count - 1 end
    updateDisplay()
    syncMoney()
end

function increase5()
    count = count + 5
    updateDisplay()
    syncMoney()
end

function decrease5()
    if count > 4 then count = count - 5 else count = 0 end
    updateDisplay()
    syncMoney()
end

function customSet()
    local desc = self.getDescription()
    if desc ~= '' and type(tonumber(desc)) == 'number' then
        self.setDescription('')
        count = tonumber(desc)
        updateDisplay()
        syncMoney()
    end
end

function syncMoney()
    -- Call Global function to sync money counter
    if Global and Global.call then
        Global.call('onSpendChanged', {guid = self.getGUID(), spent = count})
    end
end

function updateDisplay()
    if count >= 100 then b_display.font_size = 360 else b_display.font_size = 500 end
    b_display.label = tostring(count)
    self.editButton(b_display)
end

function getCount()
    return count
end

function generateButtonParamiters()
    b_display = {
        index = 0, click_function = 'customSet', function_owner = self, label = '',
        position = {0,0.1,0}, width = 800, height = 600, font_size = 500
    }
    b_plus = {
        click_function = 'increase', function_owner = self, label = '+1',
        position = {1.45,-0.1,0.6}, width = 600, height = 500, font_size = 500
    }
    b_minus = {
        click_function = 'decrease', function_owner = self, label = '-1',
        position = {-1.45,-0.1,0.6}, width = 600, height = 500, font_size = 500
    }
    b_plus5 = {
        click_function = 'increase5', function_owner = self, label = '+5',
        position = {1.45,-0.1,-0.6}, width = 600, height = 500, font_size = 500
    }
    b_minus5 = {
        click_function = 'decrease5', function_owner = self, label = '-5',
        position = {-1.45,-0.1,-0.6}, width = 600, height = 500, font_size = 500
    }
end
"""

SPEND_TRACKER_STATE = '{"saved_count":0}'


# ---------------------------------------------------------------------------
# Module processing helpers
# ---------------------------------------------------------------------------

# Matches:  local Foo = require("src/Bar")
#           local Foo = require("tts/Bar")
REQUIRE_RE = re.compile(r'^\s*local\s+\w+\s*=\s*require\s*\(.*\)\s*$')

# Matches:  local Foo = {}   (first token after 'local' is the module name)
LOCAL_TABLE_RE = re.compile(r'^(local\s+)(\w+)(\s*=\s*\{\})(.*)$')

# Matches:  return Foo   (bare return at end of module)
RETURN_RE = re.compile(r'^\s*return\s+\w+\s*$')


def process_module(name: str, path: Path) -> str:
    """
    Read a Lua module file and transform it for inline bundling:
      - Drop all require() lines
      - Promote the first `local Name = {}` to a global `Name = {}`
      - Drop ONLY the final `return <Name>` line (not other return statements)
    Returns the processed Lua source as a string.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    out = []
    promoted = False  # have we done the local→global promotion yet?

    for line in lines:
        # 1. Drop require() lines
        if REQUIRE_RE.match(line):
            continue

        # 2. Promote first `local <Name> = {}` to `<Name> = {}`
        if not promoted:
            m = LOCAL_TABLE_RE.match(line)
            if m and m.group(2) == name:
                # Remove the leading 'local ' keyword
                line = m.group(2) + m.group(3) + m.group(4)
                promoted = True

        out.append(line)

    # 3. Remove ONLY the last `return <ModuleName>` line (scan backwards)
    for i in range(len(out) - 1, -1, -1):
        stripped = out[i].strip()
        if stripped == "return " + name or stripped == "return  " + name:
            out.pop(i)
            break
        # Stop scanning backwards once we hit actual code (not blank/comment)
        if stripped and not stripped.startswith("--"):
            break

    return "\n".join(out)


def process_global(path: Path) -> str:
    """
    Read tts/Global.lua and strip all #include lines.
    Everything else is kept verbatim.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    out = [line for line in lines if not line.strip().startswith("#include")]
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Bundle builder
# ---------------------------------------------------------------------------

def build_lua_bundle() -> str:
    """Concatenate all modules + Global.lua into one Lua script."""
    parts = [
        "------------------------------------------------------",
        "-- Brass: Birmingham — Bundled Global Script",
        "-- Auto-generated by scripts/inject_scripts.py",
        "-- Do not edit directly — edit the source modules.",
        "------------------------------------------------------",
        "",
    ]

    for name, path in SRC_MODULES:
        if not path.exists():
            print(f"  WARNING: {path} not found — skipping.", file=sys.stderr)
            continue
        parts.append(f"-- ===== Module: {name} =====")
        parts.append(process_module(name, path))
        parts.append("")  # blank line between modules

    parts.append("-- ===== Global Script =====")
    parts.append(process_global(GLOBAL_LUA))

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Spend tracker patcher
# ---------------------------------------------------------------------------

SPEND_TRACKER_POSITIONS = {
    "26e57c": {"posX": -35.4, "posY": 0.9, "posZ": -27.5},  # Yellow -> below board 2
    "719019": {"posX":  35.3, "posY": 0.9, "posZ": -27.5},  # White  -> below board 82
    "9f808b": {"posX":  35.5, "posY": 0.9, "posZ":  27.5},  # Orange -> below board 81
    "b05299": {"posX": -35.4, "posY": 0.9, "posZ":  27.5},  # Purple -> below board 80
}

SPEND_TRACKER_SCALE = {"scaleX": 0.80, "scaleY": 1.0, "scaleZ": 0.80}


def patch_spend_trackers(mod_data: dict) -> int:
    """
    Walk ObjectStates and replace the 4 board Counter objects (by GUID) with
    spend tracker versions: inject the spend tracker LuaScript, set
    LuaScriptState, Nickname, and reposition below player boards.

    Returns the number of objects patched.
    """
    patched = 0
    for obj in mod_data.get("ObjectStates", []):
        guid = obj.get("GUID")
        if guid in SPEND_TRACKER_GUIDS:
            # Clear any script — use TTS built-in Counter UI only
            # (updated via Counter.setValue from Global script)
            obj["LuaScript"] = ""
            obj["LuaScriptState"] = ""
            obj["Nickname"] = "Spend Tracker"
            # Reset counter value to 0
            if "Counter" in obj:
                obj["Counter"]["value"] = 0
            # Reposition below player board, centered
            if guid in SPEND_TRACKER_POSITIONS:
                t = obj.get("Transform", {})
                t.update(SPEND_TRACKER_POSITIONS[guid])
                t.update(SPEND_TRACKER_SCALE)
                obj["Transform"] = t
            patched += 1
    return patched


# ---------------------------------------------------------------------------
# GMNotes tagging
# ---------------------------------------------------------------------------

# FaceURL substrings that identify each sprite sheet type
TILE_SHEET_IDS  = {"CA13E07E", "59EF30BD"}   # building tile sprite sheets
CARD_SHEET_IDS  = {"0E058782"}               # location / industry card sheet
BACK_SHEET_IDS  = {"525F74C1"}               # card-back sheet (skip)
WILD_SHEET_IDS  = {"2CF61FBB"}               # wild industry tiles (skip)
PLAYER_AID_IDS  = {"BB0D630F"}               # player aid (skip)

INDUSTRY_NAMES = {
    "cotton":       "Cotton Mill",
    "coal":         "Coal Mine",
    "iron":         "Iron Works",
    "brewery":      "Brewery",
    "manufacturer": "Manufacturer",
    "pottery":      "Pottery",
}

# Card sheet grid position -> (cardType, value)
# cardType: "location", "industry", "wild_location", "wild_industry"
# value:
#   location  -> city name string
#   industry  -> list of industry name(s), e.g. ["cotton"] or ["cotton", "manufacturer"]
#   wild_*    -> None
# Grid is 7x5; position = row * 7 + col.  Only used positions listed.
# Uncertain positions marked with TODO — update after running card_labeler.html
CARD_GRID_MAP = {
     0: ("location",      "Derby"),
     1: ("wild_location",  None),
     2: ("wild_industry",  None),
     3: ("industry",      ["cotton", "manufacturer"]),
     4: ("location",      "Birmingham"),
     5: ("industry",      ["cotton", "manufacturer"]),
     6: ("industry",      ["pottery"]),
     7: ("location",      "Stone"),
     8: ("location",      "Walsall"),
     9: ("location",      "Burton-on-Trent"),
    10: ("location",      "Wolverhampton"),
    11: ("industry",      ["iron"]),
    12: ("industry",      ["brewery"]),
    13: ("location",      "Stafford"),
    14: ("location",      "Cannock"),
    15: ("location",      "Tamworth"),
    16: ("location",      "Stoke-on-Trent"),
    17: ("location",      "Coventry"),
    18: ("industry",      ["coal"]),
    19: ("location",      "Dudley"),
    20: ("industry",      ["cotton", "manufacturer"]),
    23: ("location",      "Uttoxeter"),
    24: ("location",      "Coalbrookdale"),
    25: ("location",      "Kidderminster"),
    26: ("location",      "Worcester"),
    27: ("location",      "Leek"),
    28: ("location",      "Belper"),
    30: ("industry",      ["coal"]),
    31: ("location",      "Redditch"),
    32: ("location",      "Nuneaton"),
}


def _get_face_url(obj: dict) -> str:
    """Return the FaceURL string from a card/deck object, or ''."""
    # Cards store image data in CustomDeck (keyed by deck ID)
    custom_deck = obj.get("CustomDeck", {})
    for deck_entry in custom_deck.values():
        url = deck_entry.get("FaceURL", "")
        if url:
            return url
    return ""


def _face_url_matches(face_url: str, id_set: set) -> bool:
    return any(sheet_id in face_url for sheet_id in id_set)


def _tag_single_card(obj: dict) -> None:
    """
    Compute and set GMNotes JSON for a single Card object in-place.
    Skips objects that are not building tiles or game cards.
    """
    face_url = _get_face_url(obj)
    if not face_url:
        return

    # ---- building tile ----
    if _face_url_matches(face_url, TILE_SHEET_IDS):
        card_id = obj.get("CardID", -1)
        grid_pos = card_id % 100
        tile_info = ALL_POSITIONS.get(grid_pos)
        if tile_info is None:
            return  # unknown grid position — leave GMNotes untouched
        industry, level = tile_info
        cost = TILE_FULL_COST.get((industry, level), {"money": 0, "coal": 0, "iron": 0})
        notes = {
            "type":     "tile",
            "industry": industry,
            "level":    level,
            "money":    cost["money"],
            "coal":     cost["coal"],
            "iron":     cost["iron"],
        }
        obj["GMNotes"] = json.dumps(notes, separators=(",", ":"))
        # Set readable Nickname
        obj["Nickname"] = f"{INDUSTRY_NAMES.get(industry, industry)} Lv.{level}"
        return

    # ---- game card ----
    if _face_url_matches(face_url, CARD_SHEET_IDS):
        card_id = obj.get("CardID", -1)
        grid_pos = card_id % 100
        mapping = CARD_GRID_MAP.get(grid_pos)
        if mapping:
            card_type, value = mapping
            notes: dict = {"type": "card", "cardType": card_type}
            if card_type == "location" and value:
                notes["location"] = value
            elif card_type == "industry" and value:
                notes["industryTypes"] = value  # list of 1-2 industry names
            obj["GMNotes"] = json.dumps(notes, separators=(",", ":"))
        else:
            obj["GMNotes"] = json.dumps({"type": "card"}, separators=(",", ":"))
        return

    # Everything else (back sheet, wild tiles, player aid, etc.) — skip


def tag_all_cards(mod_data: dict) -> int:
    """
    Walk every object in ObjectStates (and ContainedObjects recursively),
    tagging Cards with GMNotes metadata.
    Returns the number of objects tagged.
    """
    tagged = 0

    def _walk(obj: dict) -> None:
        nonlocal tagged
        obj_type = obj.get("Name", "")

        if obj_type in ("Card", "DeckCustom", "Deck"):
            before = obj.get("GMNotes", "")
            # Tag the container itself (Deck objects also have CustomDeck)
            _tag_single_card(obj)
            if obj.get("GMNotes", "") != before:
                tagged += 1

        # Recurse into contained objects (cards inside decks, etc.)
        for contained in obj.get("ContainedObjects", []):
            _walk(contained)

    for obj in mod_data.get("ObjectStates", []):
        _walk(obj)

    return tagged


# ---------------------------------------------------------------------------
# Card recognition invariant check (issue #3)
# ---------------------------------------------------------------------------
#
# tts/CardManager.parseCard() treats a card as recognized only if its GMNotes
# decodes to a table with a `cardType` field (or, failing that, its name
# matches a legacy naming pattern). Card recognition is meant to be a
# build-time invariant: every real, dealable Card object should come out of
# tag_all_cards() with a cardType already stamped on it. If one doesn't, the
# CARD_GRID_MAP is missing an entry (or a sheet ID changed) and the shipped
# save would silently contain a card EventHandlers can't recognize.
#
# This check walks the same object tree as tag_all_cards(), but only
# individual "Card" objects (never "Deck"/"DeckCustom" containers, which are
# never themselves dropped/played — TTS always deals out individual Cards).
# For every Card whose GMNotes claims {"type": "card"}, cardType must be
# present. Anything else fails the build loudly instead of shipping a card
# CardManager.parseCard() would silently reject at runtime.


def validate_card_metadata(mod_data: dict) -> list:
    """
    Verify the build-time invariant that every individual Card object tagged
    as a game card has a parseable cardType in its GMNotes.
    Returns a list of (guid, card_id, nickname) tuples for any violations
    (empty list means the invariant holds).
    """
    violations = []

    def _walk(obj: dict) -> None:
        if obj.get("Name") == "Card":
            notes_str = obj.get("GMNotes", "")
            if notes_str:
                try:
                    notes = json.loads(notes_str)
                except (ValueError, TypeError):
                    notes = None
                if isinstance(notes, dict) and notes.get("type") == "card":
                    if not notes.get("cardType"):
                        violations.append(
                            (obj.get("GUID"), obj.get("CardID"), obj.get("Nickname", ""))
                        )
        for contained in obj.get("ContainedObjects", []):
            _walk(contained)

    for obj in mod_data.get("ObjectStates", []):
        _walk(obj)

    return violations


# ---------------------------------------------------------------------------
# Money counter patcher — inject getCount() into existing MrStump scripts
# ---------------------------------------------------------------------------

MONEY_COUNTER_GUIDS = {"b56836", "4d732a", "bfdaf2", "4a0fce"}

GET_COUNT_SNIPPET = "\nfunction getCount()\n    return count\nend\n"


def patch_money_counters(mod_data: dict) -> int:
    """
    Append a getCount() function to the LuaScript of the 4 money counter objects
    so EventHandlers can read their current value via obj.call('getCount').
    Returns the number of objects patched.
    """
    patched = 0
    for obj in mod_data.get("ObjectStates", []):
        guid = obj.get("GUID")
        if guid in MONEY_COUNTER_GUIDS:
            script = obj.get("LuaScript", "")
            # Only append once (idempotent)
            if "function getCount()" not in script:
                obj["LuaScript"] = script + GET_COUNT_SNIPPET
                patched += 1
    return patched


# ---------------------------------------------------------------------------
# Crown button callback injection
# ---------------------------------------------------------------------------

CROWN_BUTTON_GUIDS = {
    "5f8b97": 2,  # 2-player crown
    "9c5d5e": 3,  # 3-player crown
    "3ba14f": 4,  # 4-player crown
}

AI_BUTTON_GUID = "f714a5"

CROWN_CALLBACK_SNIPPET = """
    -- Injected by inject_scripts.py: trigger game state initialization
    Global.call('onPhysicalSetupComplete', {{playerCount = {player_count}}})
"""

# Complete replacement script for crown buttons.
# Preserves the original physical setup (deck placement, market tokens,
# beer barrels) and appends our game state initialization callback.
CROWN_FULL_SCRIPT = """
function onload()
    isButtonLocked = false
    times = 1

    fourP_Button  = getObjectFromGUID("3ba14f")
    threeP_Button = getObjectFromGUID("9c5d5e")
    towP_Button   = getObjectFromGUID("5f8b97")

    deck        = getObjectFromGUID("{deck_guid}")
    market_zone = getObjectFromGUID("319330")
    barrel      = getObjectFromGUID("4be839")
    point_pool  = Global.getSnapPoints()

    local button = {{}}
    button.tooltip = "{tooltip}"
    button.height = 800
    button.width = 800
    button.font_size = 50
    button.position = {{0, 0.1, 0}}
    button.rotation = {{0, 0, 0}}
    button.click_function = "on_Button_pressed"
    button.function_owner = self
    button.color = {{1, 1, 1, 0}}
    self.createButton(button)
end

function on_Button_pressed()
    if isButtonLocked == false then
        startLuaCoroutine(self, "prepareGame")
        isButtonLocked = true
        self.editButton({{index=0, tooltip = "Please wait..."}})
        broadcastToAll("Setting up {player_count}-player game", "Yellow")
        {lock_others}
    end
end

function prepareGame()
    if times == 1 then
        local m = getCardInZone(market_zone)
        if m then m.shuffle() end
    end
    if deck then deck.shuffle() end
    delay(20)
    for _,point in pairs(point_pool) do
        if point.tags[1] == "Deck" then
            if deck then
                deck.setPositionSmooth(point.position)
                delay(5)
                deck.setRotationSmooth(point.rotation)
                delay(5)
            end
        elseif {market_tag_check} and times == 1 then
            putMarketToken(point)
        elseif {barrel_tag_check} then
            putBarrelToken(point)
        end
    end

    broadcastToAll("Setup complete!", "Green")

    if times == 1 then
        -- First click: canal era — trigger our game state initialization
        Global.call('onPhysicalSetupComplete', {{playerCount = {player_count}}})
        times = 2
        isButtonLocked = false
        self.editButton({{index=0, tooltip = "Prepare Rail Era"}})
    else
        self.editButton({{index=0, tooltip = "Start a new game"}})
    end

    return 1
end

function putMarketToken(point)
    local m = getCardInZone(market_zone)
    if not m then return end
    local params = {{}}
    params.position = point.position
    params.rotation = point.rotation
    params.smooth = true
    if m.type == "Deck" then
        m.takeObject(params)
        delay(10)
    elseif m.type == "Card" then
        m.setPositionSmooth(point.position)
        delay(5)
        m.setRotationSmooth(point.rotation)
        delay(5)
    end
end

function putBarrelToken(point)
    if not barrel then return end
    local params = {{}}
    params.position = point.position
    params.smooth = true
    barrel.takeObject(params)
    delay(10)
end

function getCardInZone(zone)
    if not zone then return nil end
    for _,obj in ipairs(zone.getObjects()) do
        if obj.type == "Card" or obj.type == "Deck" then
            return obj
        end
    end
    return nil
end

function LockButton()
    isButtonLocked = true
    return 1
end

function delay(frame)
    for i = 1, frame do
        coroutine.yield(0)
    end
end
"""

CROWN_LABELS = {
    "5f8b97": "2 Players",
    "9c5d5e": "3 Players",
    "3ba14f": "4 Players",
}


CROWN_CONFIGS = {
    "5f8b97": {
        "player_count": 2,
        "deck_guid": "b6ff44",
        "tooltip": "2 Players",
        "market_tag_check": 'point.tags[3] == "M2"',
        "barrel_tag_check": 'point.tags[3] == "B2"',
        "lock_others": 'startLuaCoroutine(threeP_Button, "LockButton")\n        startLuaCoroutine(fourP_Button, "LockButton")',
    },
    "9c5d5e": {
        "player_count": 3,
        "deck_guid": "3895fe",
        "tooltip": "3 Players",
        "market_tag_check": 'point.tags[2] == "M3"',
        "barrel_tag_check": 'point.tags[2] == "B3"',
        "lock_others": 'startLuaCoroutine(fourP_Button, "LockButton")\n        startLuaCoroutine(towP_Button, "LockButton")',
    },
    "3ba14f": {
        "player_count": 4,
        "deck_guid": "bc3ba4",
        "tooltip": "4 Players",
        "market_tag_check": 'point.tags[1] == "M4"',
        "barrel_tag_check": 'point.tags[1] == "B4"',
        "lock_others": 'startLuaCoroutine(threeP_Button, "LockButton")\n        startLuaCoroutine(towP_Button, "LockButton")',
    },
}


def patch_crown_buttons(mod_data: dict) -> int:
    patched = 0
    for obj in mod_data.get("ObjectStates", []):
        guid = obj.get("GUID")

        if guid in CROWN_BUTTON_GUIDS:
            config = CROWN_CONFIGS[guid]

            # Replace with our combined script: original physical setup +
            # our game state initialization callback.
            obj["LuaScript"] = CROWN_FULL_SCRIPT.format(**config)
            obj["LuaScriptState"] = ""

            if guid in CROWN_LABELS:
                obj["Nickname"] = CROWN_LABELS[guid]
            patched += 1

        elif guid == AI_BUTTON_GUID:
            obj["LuaScript"] = ""
            obj["LuaScriptState"] = ""
            obj["Locked"] = True
            obj["Nickname"] = "(Disabled)"

    return patched


# ---------------------------------------------------------------------------
# Rename Chinese nicknames to English
# ---------------------------------------------------------------------------

NICKNAME_RENAME_MAP = {
    "\u8fd0\u8239":          "Canal",
    "\u8fd0\u8239-\u8fd0\u6cb3\u65f6\u4ee3": "Canal - Canal Era",
    "\u706b\u8f66":          "Rail",
    "\u706b\u8f66-\u94c1\u8def\u65f6\u4ee3": "Rail - Rail Era",
    "\u7164\u70ad":          "Coal",
    "\u94a2\u94c1":          "Iron",
    "\u9152\u6876":          "Beer",
    "\u7164\u77ff":          "Coal Bag",
    "\u6536\u5165\u6307\u793a\u7269":  "Income Marker",
    "\u5206\u6570\u6307\u793a\u7269":  "Score Marker",
    "\u4e07\u80fd\u5730\u70b9\u724c":  "Wild Location",
    "\u4e07\u80fd\u4ea7\u4e1a\u724c":  "Wild Industry",
    "AI\u62bd\u724c\u6309\u94ae":      "AI Draw Button",
    "\u8bbe\u7f6e -\u7b80\u5355AI-":   "Setup - Easy AI",
    "\u8bbe\u7f6e -\u4e2d\u7b49AI-":   "Setup - Medium AI",
    "\u8bbe\u7f6e -\u56f0\u96beAI-":   "Setup - Hard AI",
}


def rename_chinese_nicknames(mod_data: dict) -> int:
    """Rename Chinese Nicknames in all ObjectStates to English equivalents."""
    renamed = 0

    def _walk(obj: dict) -> None:
        nonlocal renamed
        nickname = obj.get("Nickname", "")
        if nickname in NICKNAME_RENAME_MAP:
            obj["Nickname"] = NICKNAME_RENAME_MAP[nickname]
            renamed += 1
        for child in obj.get("ContainedObjects", []):
            _walk(child)

    for obj in mod_data.get("ObjectStates", []):
        _walk(obj)

    return renamed


# ---------------------------------------------------------------------------
# Lock coal/iron resource cubes
# ---------------------------------------------------------------------------

def lock_resource_cubes(mod_data: dict) -> int:
    """
    Lock coal/iron cube objects on the market track.
    Object type is BlockSquare, not Custom_Token.
    """
    locked = 0

    # Match patterns for coal/iron cubes
    COAL_NAMES = {"coal", "Coal", "Coal Bag"}
    IRON_NAMES = {"iron", "Iron", "Iron Bag"}
    # Object types that are cubes (not bags or boards)
    CUBE_TYPES = {"BlockSquare", "Custom_Token", "Custom_Model"}

    def _walk(obj: dict) -> None:
        nonlocal locked
        nickname = obj.get("Nickname", "") or ""
        obj_type = obj.get("Name", "")

        if obj_type not in CUBE_TYPES:
            # Recurse into containers but don't lock them
            for contained in obj.get("ContainedObjects", []):
                _walk(contained)
            return

        resource_type = None
        if nickname in COAL_NAMES or nickname.lower() in COAL_NAMES:
            resource_type = "coal"
        elif nickname in IRON_NAMES or nickname.lower() in IRON_NAMES:
            resource_type = "iron"

        if resource_type:
            obj["Locked"] = True
            obj["GMNotes"] = json.dumps(
                {"type": "resource", "resource": resource_type},
                separators=(",", ":"),
            )
            locked += 1

        for contained in obj.get("ContainedObjects", []):
            _walk(contained)

    for obj in mod_data.get("ObjectStates", []):
        _walk(obj)

    return locked


# ---------------------------------------------------------------------------
# Tag link tiles with GMNotes
# ---------------------------------------------------------------------------

LINK_BAG_NICKNAMES = {"Canal - Canal Era", "Rail - Rail Era"}


def tag_link_tiles(mod_data: dict) -> int:
    """
    Walk Custom_Model_Bag objects whose Nickname matches link tile bags,
    and tag their contained Custom_Token objects with GMNotes JSON.
    """
    tagged = 0
    for obj in mod_data.get("ObjectStates", []):
        nickname = obj.get("Nickname", "")
        if nickname not in LINK_BAG_NICKNAMES:
            continue
        if obj.get("Name") != "Custom_Model_Bag":
            continue
        link_type = "canal" if "Canal" in nickname else "rail"
        for contained in obj.get("ContainedObjects", []):
            if contained.get("Name") != "Custom_Token":
                continue
            notes = {"type": "link", "linkType": link_type}
            contained["GMNotes"] = json.dumps(notes, separators=(",", ":"))
            tagged += 1
    return tagged


HAND_TRIGGER_GUIDS = {"8913e3", "38c677", "5c56af", "83dff2"}


def enable_hand_zones(mod_data: dict) -> int:
    """Enable Hands property on HandTrigger objects so TTS deals cards to them."""
    enabled = 0
    for obj in mod_data.get("ObjectStates", []):
        if obj.get("GUID") in HAND_TRIGGER_GUIDS and obj.get("Name") == "HandTrigger":
            obj["Hands"] = True
            enabled += 1
    return enabled


# ---------------------------------------------------------------------------
# Snap point tagging — map save-level snap points to city slot IDs
# ---------------------------------------------------------------------------

# Generated by scripts/build_snap_tags.py — snap point index -> tag
# Snap point index -> tag using BoardData slot IDs
# Ordering within each city: left-to-right (X asc), top-to-bottom (Z desc)
# Maps to BoardData slot order (first slot in city.slots array = _1, etc.)
SNAP_TAGS = {
    # Belper (3 slots)
    186: "city_Belper_1",
    187: "city_Belper_2",
    188: "city_Belper_3",
    # Birmingham (4 slots)
    216: "city_Birmingham_1",
    218: "city_Birmingham_2",
    217: "city_Birmingham_3",
    219: "city_Birmingham_4",
    # Burton-on-Trent (2 slots — 3rd snap point 222 skipped, not a game slot)
    221: "city_Burton-on-Trent_1",
    220: "city_Burton-on-Trent_2",
    # Cannock (2 slots)
    201: "city_Cannock_1",
    202: "city_Cannock_2",
    # Coalbrookdale (3 slots)
    206: "city_Coalbrookdale_1",
    207: "city_Coalbrookdale_2",
    205: "city_Coalbrookdale_3",
    # Coventry (3 slots — 3rd snap point has no TTS snap; handled via SnapMap estimate)
    223: "city_Coventry_1",
    224: "city_Coventry_2",
    # Derby (3 slots)
    192: "city_Derby_1",
    191: "city_Derby_2",
    193: "city_Derby_3",
    # Dudley (2 slots)
    225: "city_Dudley_1",
    226: "city_Dudley_2",
    # Kidderminster (2 slots)
    214: "city_Kidderminster_1",
    215: "city_Kidderminster_2",
    # Leek (2 slots)
    194: "city_Leek_1",
    195: "city_Leek_2",
    # Nuneaton (2 slots) — swapped with Uttoxeter per board verification
    212: "city_Nuneaton_1",
    213: "city_Nuneaton_2",
    # Redditch (2 slots)
    227: "city_Redditch_1",
    228: "city_Redditch_2",
    # Stafford (2 slots)
    184: "city_Stafford_1",
    185: "city_Stafford_2",
    # Stoke-on-Trent (3 slots)
    181: "city_Stoke-on-Trent_1",
    182: "city_Stoke-on-Trent_2",
    183: "city_Stoke-on-Trent_3",
    # Stone (2 slots)
    196: "city_Stone_1",
    197: "city_Stone_2",
    # Tamworth (2 slots)
    189: "city_Tamworth_1",
    190: "city_Tamworth_2",
    # Uttoxeter (2 slots) — swapped with Nuneaton per board verification
    198: "city_Uttoxeter_1",
    199: "city_Uttoxeter_2",
    # Walsall (2 slots)
    208: "city_Walsall_1",
    209: "city_Walsall_2",
    # Wolverhampton (2 slots)
    203: "city_Wolverhampton_1",
    204: "city_Wolverhampton_2",
    # Worcester (2 slots)
    210: "city_Worcester_1",
    211: "city_Worcester_2",
}


def tag_snap_points(mod_data: dict) -> int:
    """Tag save-level snap points with city slot IDs."""
    snap_points = mod_data.get("SnapPoints", [])
    tagged = 0

    for idx, tag in SNAP_TAGS.items():
        if idx >= len(snap_points):
            continue
        sp = snap_points[idx]
        if "Tags" not in sp:
            sp["Tags"] = []
        if tag not in sp["Tags"]:
            sp["Tags"].append(tag)
            tagged += 1

    return tagged


# ---------------------------------------------------------------------------
# Snap point position corrections
# ---------------------------------------------------------------------------
# Generated from snap_editor.html CURRENT_SLOTS + CURRENT_LINKS.
# These are the manually-corrected world positions that align with the board art.
# The reference mod's original snap points are slightly off; this table patches them.
# Key = snap point index in top-level SnapPoints array.
# Value = corrected (x, z) world position.  Y is kept from the original.

SNAP_POSITION_PATCHES = {
    141: ( -5.660, -11.507),  142: ( -0.662, -10.045),  143: ( -5.175,  -7.144),
    144: ( -8.499,  -6.754),  145: (-11.754,  -1.317),  146: ( -7.388,  -1.276),
    147: ( -2.077, -14.461),  148: (  0.295, -12.101),  149: (  5.738, -11.260),
    150: ( -4.262,  -3.716),  151: ( -1.709,  -1.495),  152: (  0.718,  -5.985),
    153: (  1.976,  -4.400),  154: (  3.980,  -8.918),  155: (  7.655,  -9.164),
    156: (  7.749,  -7.477),  158: (  6.758,  -2.971),  159: ( 12.644,  -5.265),
    160: (  9.932,  -1.112),  161: (  4.294,  -1.743),  162: (  6.974,   1.952),
    163: (  3.035,   0.613),  164: (  1.324,  -0.099),  165: ( -3.743,   0.621),
    166: ( -4.264,   2.316),  167: ( -0.808,   3.685),  168: (  2.477,   3.545),
    169: ( -6.275,   5.707),  170: (  0.442,   6.879),  171: ( -1.969,   8.921),
    172: (  5.863,   8.483),  173: (  8.926,   5.836),  174: ( 11.245,   9.988),
    175: (  9.337,  11.751),  176: (  4.925,  14.416),  177: ( -1.007,  14.270),
    178: ( -4.821,  10.058),  179: ( -5.131,  13.742),
    181: ( -3.666,  11.933),  182: ( -2.933,  13.516),  183: ( -2.097,  11.823),
    184: (  1.068,  14.348),  185: (  2.593,  14.352),  186: (  7.045,  13.941),
    187: (  8.637,  13.921),  188: ( 10.193,  13.936),  189: (  1.520,   8.990),
    190: (  3.053,   8.972),  191: (  8.868,   9.703),  192: (  8.063,   8.131),
    193: (  9.633,   8.088),  194: ( -7.216,   8.338),  195: ( -5.659,   8.375),
    196: ( -4.010,   5.160),  197: ( -2.513,   5.176),  198: (  5.459,   4.249),
    199: (  6.998,   4.213),  201: ( -1.692,   1.758),  202: ( -0.032,   1.781),
    203: ( -5.098,  -1.390),  204: ( -3.626,  -1.381),  205: ( -8.201,  -2.866),
    206: ( -9.743,  -2.866),  207: ( -8.984,  -1.263),  208: (  0.314,  -2.130),
    209: (  1.924,  -2.145),  210: (  5.961,  -0.047),  211: (  7.476,  -0.049),
    212: (  8.989,  -3.449),  213: ( 10.570,  -3.473),  214: ( -3.594,  -5.524),
    215: ( -2.000,  -5.512),  216: (  3.663,  -6.824),  217: (  5.178,  -6.849),
    218: (  3.700,  -5.212),  219: (  5.141,  -5.239),  220: ( 10.493,  -6.234),
    221: (  9.786,  -7.869),  222: ( 11.284,  -7.889),  223: (  2.114, -10.818),
    224: (  3.629, -10.786),  225: ( -5.912,  -8.953),  226: ( -4.379,  -9.001),
    227: ( -5.424, -13.336),  228: ( -3.873, -13.366),
}


def patch_snap_positions(mod_data: dict) -> int:
    """Patch top-level SnapPoints to match SnapMap corrected positions."""
    snaps = mod_data.get("SnapPoints", [])
    patched = 0
    for idx, (x, z) in SNAP_POSITION_PATCHES.items():
        if idx < len(snaps):
            snaps[idx]["Position"]["x"] = x
            snaps[idx]["Position"]["z"] = z
            patched += 1
    return patched


TRASH_CAN_POSITIONS = {
    # (GUID, posX, posZ) — one per player corner, mirrored
    "tc_wht": ( 14.0, -22.0),   # White  (bottom-right)
    "tc_org": ( 14.0,  22.0),   # Orange (top-right)
    "tc_pur": (-14.0,  22.0),   # Purple (top-left)
    "tc_yel": (-14.0, -22.0),   # Yellow (bottom-left)
}


def add_trash_cans(mod_data: dict) -> int:
    """Add or update the 4 Trash Can objects (one per player) for the Develop action."""
    # Remove existing trash cans (idempotent)
    all_guids = set(TRASH_CAN_POSITIONS.keys())
    mod_data["ObjectStates"] = [
        o for o in mod_data["ObjectStates"]
        if o.get("GUID") not in all_guids
    ]

    for guid, (px, pz) in TRASH_CAN_POSITIONS.items():
        trash_can = {
            "GUID": guid,
            "Name": "Bag",
            "Transform": {
                "posX": px, "posY": 1.4, "posZ": pz,
                "rotX": 0.0, "rotY": 0.0, "rotZ": 0.0,
                "scaleX": 1.0, "scaleY": 1.0, "scaleZ": 1.0,
            },
            "Nickname": "Trash Can",
            "Description": "Drop building tiles here during Develop action.",
            "GMNotes": json.dumps({"type": "trash_can"}),
            "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0},
            "ColorDiffuse": {"r": 0.4, "g": 0.4, "b": 0.4},
            "LayoutGroupSortIndex": 0,
            "Value": 0,
            "Locked": False,
            "Grid": True,
            "Snap": True,
            "IgnoreFoW": False,
            "MeasureMovement": False,
            "DragSelectable": True,
            "Autoraise": True,
            "Sticky": True,
            "Tooltip": True,
            "GridProjection": False,
            "HideWhenFaceDown": False,
            "Hands": False,
            "Bag": {"Order": 0},
            "ContainedObjects": [],
            "LuaScript": "",
            "LuaScriptState": "",
            "XmlUI": "",
        }
        mod_data["ObjectStates"].append(trash_can)

    return len(TRASH_CAN_POSITIONS)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=== Brass: Birmingham — Script Injector ===")
    print()

    # 1. Read reference mod
    print(f"Reading reference mod: {SRC_MOD_PATH}")
    if not SRC_MOD_PATH.exists():
        print("ERROR: Reference mod not found.", file=sys.stderr)
        sys.exit(1)
    with open(SRC_MOD_PATH, "r", encoding="utf-8") as f:
        mod_data = json.load(f)
    print(f"  Loaded: {len(mod_data.get('ObjectStates', []))} objects")

    # 2. Build the bundled Lua script
    print()
    print("Building Lua bundle...")
    lua_bundle = build_lua_bundle()
    print(f"  Bundle size: {len(lua_bundle):,} characters")

    # 3. Read XML UI
    print()
    print(f"Reading XML UI: {XML_UI}")
    if not XML_UI.exists():
        print("ERROR: UI.xml not found.", file=sys.stderr)
        sys.exit(1)
    xml_content = XML_UI.read_text(encoding="utf-8")
    print(f"  XML size: {len(xml_content):,} characters")

    # 4. Inject into mod data
    print()
    print("Injecting scripts into mod data...")
    mod_data["LuaScript"] = lua_bundle
    mod_data["XmlUI"] = xml_content
    # Update save name so it's identifiable in TTS
    mod_data["SaveName"] = "Brass Birmingham (Scripted)"

    # 4b. Patch board Counter objects → spend trackers
    print()
    print("Patching spend tracker Counter objects...")
    n_patched = patch_spend_trackers(mod_data)
    print(f"  Patched {n_patched} of {len(SPEND_TRACKER_GUIDS)} expected spend tracker(s).")
    if n_patched != len(SPEND_TRACKER_GUIDS):
        print(
            f"  WARNING: Expected {len(SPEND_TRACKER_GUIDS)} objects but only found "
            f"{n_patched}. Check GUIDs in SPEND_TRACKER_GUIDS.",
            file=sys.stderr,
        )

    # 4c. Tag all card/tile objects with GMNotes metadata
    print()
    print("Tagging cards and tiles with GMNotes metadata...")
    n_tagged = tag_all_cards(mod_data)
    print(f"  Tagged {n_tagged} object(s).")

    # 4c2. Verify the card-recognition invariant (issue #3): every individual
    # Card object tagged as a game card must carry a parseable cardType, or
    # tts/CardManager.parseCard() will silently reject it at runtime.
    print()
    print("Verifying card recognition invariant (all cards parseable)...")
    violations = validate_card_metadata(mod_data)
    if violations:
        print(
            f"  ERROR: {len(violations)} card(s) tagged as type=card have no "
            "cardType — CardManager.parseCard() would reject them at runtime:",
            file=sys.stderr,
        )
        for guid, card_id, nickname in violations:
            print(
                f"    GUID={guid} CardID={card_id} Nickname={nickname!r}",
                file=sys.stderr,
            )
        print(
            "  Fix CARD_GRID_MAP (or the sheet ID it's keyed from) so every "
            "dealable card resolves to a cardType, then re-run this script.",
            file=sys.stderr,
        )
        sys.exit(1)
    print("  OK — every tagged card has a parseable cardType.")

    # 4d. Patch money counter objects to expose getCount()
    print()
    print("Patching money counter objects (adding getCount())...")
    n_money = patch_money_counters(mod_data)
    print(f"  Patched {n_money} of {len(MONEY_COUNTER_GUIDS)} money counter(s).")
    if n_money != len(MONEY_COUNTER_GUIDS):
        print(
            f"  WARNING: Expected {len(MONEY_COUNTER_GUIDS)} objects but only found "
            f"{n_money}. Some may already have getCount() or GUIDs have changed.",
            file=sys.stderr,
        )

    # 4e. Inject crown button callbacks
    print()
    print("Patching crown setup buttons...")
    n_crowns = patch_crown_buttons(mod_data)
    print(f"  Patched {n_crowns} crown button(s).")

    # 4f. Rename Chinese nicknames to English
    print()
    print("Renaming Chinese nicknames to English...")
    n_renamed = rename_chinese_nicknames(mod_data)
    print(f"  Renamed {n_renamed} object(s).")

    # 4g. Lock resource cubes
    print()
    print("Locking coal/iron resource cubes...")
    n_cubes = lock_resource_cubes(mod_data)
    print(f"  Locked {n_cubes} resource cube(s).")

    # 4g2. Tag link tiles with GMNotes
    print()
    print("Tagging link tiles with GMNotes metadata...")
    n_links = tag_link_tiles(mod_data)
    print(f"  Tagged {n_links} link tile(s).")

    print()
    print("Enabling hand zones...")
    n_hands = enable_hand_zones(mod_data)
    print(f"  Enabled {n_hands} hand zone(s).")

    # 4h. Patch top-level snap point positions to match SnapMap corrections
    print()
    print("Patching snap point positions (sync with SnapMap)...")
    n_snaps = patch_snap_positions(mod_data)
    print(f"  Patched {n_snaps} snap point(s).")

    # 4i. Add Trash Can object for Develop action
    print()
    print("Adding Trash Cans (Bag x4)...")
    n_cans = add_trash_cans(mod_data)
    print(f"  Added {n_cans} Trash Can(s).")

    # 5. Write output JSON
    print()
    print(f"Writing output: {OUTPUT_PATH}")
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(mod_data, f, ensure_ascii=False, indent=2)
    size_mb = OUTPUT_PATH.stat().st_size / (1024 * 1024)
    print(f"  Written: {size_mb:.1f} MB")

    # 6. Validate round-trip
    print()
    print("Validating output JSON...")
    with open(OUTPUT_PATH, "r", encoding="utf-8") as f:
        check = json.load(f)
    assert check["LuaScript"] == lua_bundle, "LuaScript mismatch after round-trip!"
    assert check["XmlUI"] == xml_content, "XmlUI mismatch after round-trip!"
    assert len(check.get("ObjectStates", [])) == len(
        mod_data.get("ObjectStates", [])
    ), "ObjectStates count mismatch!"
    print("  OK — JSON is valid and round-trips correctly.")

    # 7. Copy to TTS Saves
    print()
    print(f"Copying to TTS Saves: {TTS_SAVES_PATH}")
    TTS_SAVES_PATH.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(OUTPUT_PATH, TTS_SAVES_PATH)
    print("  Done.")

    print()
    print("=== Injection complete ===")
    print(f"  Output : {OUTPUT_PATH}")
    print(f"  TTS    : {TTS_SAVES_PATH}")
    print()
    print("Load 'TS_Save_99' from the TTS main menu to test.")


if __name__ == "__main__":
    main()
