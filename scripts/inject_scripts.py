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
    ("EventHandlers", PROJECT_ROOT / "tts" / "EventHandlers.lua"),
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
      - Drop the final `return Name` line
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

        # 3. Drop `return <Name>` at module end
        if RETURN_RE.match(line):
            continue

        out.append(line)

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

def patch_spend_trackers(mod_data: dict) -> int:
    """
    Walk ObjectStates and replace the 4 board Counter objects (by GUID) with
    spend tracker versions: inject the spend tracker LuaScript, set
    LuaScriptState to the initial saved state, and set Nickname.

    Returns the number of objects patched.
    """
    patched = 0
    for obj in mod_data.get("ObjectStates", []):
        if obj.get("GUID") in SPEND_TRACKER_GUIDS:
            obj["LuaScript"] = SPEND_TRACKER_SCRIPT
            obj["LuaScriptState"] = SPEND_TRACKER_STATE
            obj["Nickname"] = "Spend Tracker"
            patched += 1
    return patched


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
