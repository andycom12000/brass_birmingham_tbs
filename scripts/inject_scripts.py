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

CROWN_LABELS = {
    "5f8b97": "2 Players",
    "9c5d5e": "3 Players",
    "3ba14f": "4 Players",
}


def patch_crown_buttons(mod_data: dict) -> int:
    patched = 0
    for obj in mod_data.get("ObjectStates", []):
        guid = obj.get("GUID")

        if guid in CROWN_BUTTON_GUIDS:
            player_count = CROWN_BUTTON_GUIDS[guid]

            # Replace the entire crown script with just our callback.
            # The original script runs its own setup (dealing cards, etc.)
            # which conflicts with our game state initialization.
            # Use a transparent button so the original object appearance is preserved.
            obj["LuaScript"] = f"""
function onLoad()
    self.createButton({{
        click_function = "onClick",
        function_owner = self,
        label          = "",
        position       = {{0, 0.5, 0}},
        width          = 800,
        height         = 800,
        color          = {{1, 1, 1, 0}},
        font_color     = {{0, 0, 0, 0}},
    }})
end

function onClick(obj, playerColor)
    Global.call('onPhysicalSetupComplete', {{playerCount = {player_count}}})
    self.clearButtons()
    self.setLock(true)
end
"""
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

    # NOTE: Snap point city mapping is hardcoded in SnapMap.lua, NOT via TTS Tags.
    # TTS Tags restrict snapping to tagged objects only, breaking free snap behavior.

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
