# Market Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate coal/iron resource consumption, market purchases, and build validation when players place building tiles in the Brass: Birmingham TTS mod.

**Architecture:** Crown setup buttons retain their physical setup logic; a callback at the end triggers our `onPhysicalSetupComplete` which initializes game state, spawns locked market cubes, and deals cards. When a building tile is placed, the system validates affordability (including dynamic market pricing for shortfalls), lets the player choose resource sources via highlights when ambiguous, and plays smooth movement animations for all cube transfers.

**Tech Stack:** Lua 5.2 (MoonSharp) in Tabletop Simulator, Python 3 for `inject_scripts.py` build step.

**Spec:** `docs/superpowers/specs/2026-03-31-market-automation-design.md`

---

## Parallelization Strategy

Tasks are grouped into 3 phases. **All tasks within Phase 1 can run in parallel** because they only depend on the shared interface contracts defined in Task 0.

```
Phase 0: Interface Contracts (must complete first)
  └─ Task 0

Phase 1: Independent Modules (all parallel)
  ├─ Task 1: Market.estimateCost          (pure logic)
  ├─ Task 2: MarketLayout module          (new file, coordinates)
  ├─ Task 3: ResourceAnimation module     (new file, animation)
  ├─ Task 4: Highlights.showResourceCandidates (extend existing)
  ├─ Task 5: Actions.build auto-sell      (pure logic)
  ├─ Task 6: inject_scripts.py changes    (Python, crown callback)
  └─ Task 7: CardManager adaptation       (adapt to crown decks)

Phase 2: Integration (depends on all Phase 1)
  ├─ Task 8: EventHandlers rewrite        (uses Tasks 1-5)
  ├─ Task 9: Global.lua rewrite           (uses Tasks 6-8)
  └─ Task 10: Bundle, inject, TTS test
```

---

## Task 0: Interface Contracts

**Files:**
- Create: `docs/superpowers/plans/interfaces.md` (reference only, not shipped)

This task defines every shared function signature, data structure, and constant that Phase 1 tasks code against. **All subagents must read this before starting their task.**

- [ ] **Step 1: Define shared interfaces**

```markdown
## Shared Constants

MOVE_INTERVAL = 0.4   -- seconds between each cube animation start
MOVE_DURATION = 0.6   -- seconds for setPositionSmooth travel
ARRIVE_BUFFER = 0.1   -- seconds after last cube arrives

## Data Structures

### state._pendingResource
Set when a build requires player choice for resource sources.
Cleared when all resources are consumed or build is cancelled.

{
    playerColor = "White",       -- who is building
    buildSlotId = "Birmingham_1",-- where they are building
    buildPos    = Vector,        -- TTS world position of the build site
    meta        = {},            -- GMNotes metadata of the placed tile
    ironNeeded  = 1,             -- remaining iron to consume from board
    coalNeeded  = 2,             -- remaining coal to consume from board
    ironFromMarket = 0,          -- iron to buy from market (pre-calculated)
    coalFromMarket = 0,          -- coal to buy from market (pre-calculated)
    phase       = "iron",        -- "iron" | "coal" | "animate" | "autosell" | "done"
    candidates  = {              -- currently highlighted source slots
        { slotId = string, cityName = string, cubesAvailable = number },
    },
    moves       = {              -- accumulated animation instructions
        { guid = string, targetPos = Vector, destroyAfter = bool },
    },
}

### state.coalMarket (extended)
Existing fields: { supply = number }
New field:       { supply = number, cubeGUIDs = { string, ... } }
cubeGUIDs[1] = cheapest slot (index 1), cubeGUIDs[N] = most expensive filled slot.

### state.ironMarket (extended)
Same as coalMarket: add cubeGUIDs array.

### slot (extended)
Existing fields: { id, type, occupant, tile }
New field:       { ..., resourceGUIDs = { string, ... } }
resourceGUIDs tracks the TTS object GUIDs of coal/iron cubes on this slot's tile.
Parallel to slot.tile.resources (same length, same order).

## Function Signatures

### MarketLayout (new module: tts/MarketLayout.lua)
MarketLayout.getPosition(resourceType, index) -> Vector
  -- resourceType: "coal" | "iron"
  -- index: 1-based position on track (1 = cheapest, N = most expensive filled)
  -- Returns TTS world position for that market track slot.

MarketLayout.getTrackMax(resourceType) -> number
  -- Returns max capacity: coal=13, iron=8

### ResourceAnimation (new module: tts/ResourceAnimation.lua)
ResourceAnimation.play(moves, onComplete)
  -- moves: array of { guid=string, targetPos=Vector, destroyAfter=bool }
  -- onComplete: function() called after all animations finish
  -- Sets state._animating = true at start, false in onComplete.

ResourceAnimation.spawnCube(resourceType, position, onSpawned)
  -- Spawns a locked, non-interactable resource cube at position.
  -- resourceType: "coal" | "iron"
  -- onSpawned: function(obj) callback with the spawned TTS object
  -- Uses ObjectManager.spawnResource internally.
  -- Sets obj.setLock(true), obj.interactable = false, obj GMNotes.

ResourceAnimation.spawnAndMoveCube(resourceType, fromPos, toPos, onArrived)
  -- Spawn at fromPos, then smooth-move to toPos. Locked on arrival.
  -- onArrived: function(obj) callback.

### Market (extended: src/Market.lua)
Market.estimateCost(state, resourceType, count) -> number
  -- Simulates buying `count` units from market without modifying state.
  -- Returns total cost. Uses current market.supply to calculate prices.

### Highlights (extended: tts/Highlights.lua)
Highlights.showResourceCandidates(candidates, resourceType, onClickCallback)
  -- candidates: array of { slotId=string, cityName=string, cubesAvailable=number }
  -- resourceType: "coal" | "iron" (determines highlight color)
  -- onClickCallback: function(slotId) called when player clicks a candidate
  -- Highlights candidate slots with orange (coal) or grey (iron) glow.
  -- Registers click handlers on the highlighted objects.

Highlights.clearResourceCandidates()
  -- Clears only resource candidate highlights (not build/link highlights).

### CardManager (modified: tts/CardManager.lua)
CardManager.findDeckOnBoard() -> TTS object | nil
  -- Finds the card deck on the board (at the Deck snap point).
  -- Searches by position proximity to known deck snap point.

CardManager.dealFromDeck(state, deckObj)
  -- Deal INITIAL_HAND_SIZE cards to each player in state.turnOrder.
  -- Updates player.handSize.

### EventHandlers (modified: tts/EventHandlers.lua)
EventHandlers.handleTilePlaced(playerColor, tileObj, meta)
  -- Full resource consumption flow: validate -> deduct money -> iron phase -> coal phase -> animate -> auto-sell.

EventHandlers.onResourceCandidateClicked(playerColor, slotId)
  -- Called when player clicks a highlighted resource source.
  -- Consumes one cube from that source, updates _pendingResource, advances phase if done.

### Global.lua (modified)
onPhysicalSetupComplete(params)
  -- params: { playerCount = number }
  -- Called by crown button callback after physical setup.
  -- Initializes state, deals cards, spawns market cubes, configures UI.
```

- [ ] **Step 2: Commit interface doc**

```bash
git add docs/superpowers/plans/interfaces.md
git commit -m "docs: add interface contracts for market automation"
```

---

## Task 1: Market.estimateCost

**Files:**
- Modify: `src/Market.lua`

**Interface:** `Market.estimateCost(state, resourceType, count) -> number`

- [ ] **Step 1: Add estimateCost to Market module**

In `src/Market.lua`, add before the final `return Market`:

```lua
--- Simulate buying `count` units from market without modifying state.
--- Returns total cost using current supply level for price calculation.
--- Each simulated purchase decreases simulated supply, increasing next price.
--- @param state table
--- @param resourceType string  "coal" or "iron"
--- @param count number  how many units to buy
--- @return number  total cost
function Market.estimateCost(state, resourceType, count)
    if count <= 0 then return 0 end
    local market = Market.getMarketSupply(state, resourceType)
    if not market then return 0 end
    local track = Market.getTrack(resourceType)
    local trackLen = #track
    local simSupply = market.supply
    local total = 0

    for i = 1, count do
        if simSupply <= 0 then
            total = total + Market.getMaxPrice(resourceType)
        else
            local pos = trackLen - simSupply + 1
            if pos < 1 then pos = 1 end
            total = total + track[pos]
            simSupply = simSupply - 1
        end
    end
    return total
end
```

- [ ] **Step 2: Commit**

```bash
git add src/Market.lua
git commit -m "feat(Market): add estimateCost for simulating market purchases"
```

---

## Task 2: MarketLayout Module

**Files:**
- Create: `tts/MarketLayout.lua`

**Interface:** `MarketLayout.getPosition(resourceType, index) -> Vector`, `MarketLayout.getTrackMax(resourceType) -> number`

**Context:** The reference mod (3073008847.json) has a board with printed market tracks. We need to extract the physical positions of each market slot from the save file or measure them in TTS.

- [ ] **Step 1: Extract market track positions from reference mod**

Run a Python script to find snap points or object positions near the market area on the board. The board object in the reference mod likely has snap points for market track slots. Search the save JSON for snap points in the market region.

```bash
cd C:\Users\andyc\Projects\brass_birmingham_tbs
python -c "
import json
with open('brass_birmingham_scripted.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
# Find the main board and its snap points
for obj in data['ObjectStates']:
    name = obj.get('Nickname', '') or obj.get('Name', '')
    # Look for snap points on objects in the market area
    snaps = obj.get('AttachedSnapPoints', []) or []
    if len(snaps) > 5:
        print(f'Object: {name} (GUID: {obj.get(\"GUID\",\"?\")}) has {len(snaps)} snap points')
        # Print snap points that might be market-related
        for i, sp in enumerate(snaps):
            pos = sp.get('Position', {})
            tags = sp.get('Tags', [])
            if tags:
                print(f'  Snap {i}: pos=({pos.get(\"x\",0):.2f}, {pos.get(\"y\",0):.2f}, {pos.get(\"z\",0):.2f}) tags={tags}')
"
```

Use the output to identify market track snap points. If no snap points exist for the market track, look for existing coal/iron cube objects and record their positions.

Alternatively, read positions in TTS using the scripting console:
```lua
-- Run in TTS scripting console to find market area objects
for _, obj in ipairs(getAllObjects()) do
    local p = obj.getPosition()
    local n = obj.getName()
    -- Filter objects in the market region of the board
    if n:find("[Cc]oal") or n:find("[Ii]ron") or n:find("[Cc]ube") then
        print(n .. " GUID=" .. obj.getGUID() .. " pos=" .. tostring(p))
    end
end
```

- [ ] **Step 2: Create MarketLayout module with measured positions**

Create `tts/MarketLayout.lua`. Replace the `Vector(...)` placeholders below with actual measured positions from Step 1:

```lua
--- MarketLayout.lua
-- Maps market track slot indices to TTS world positions.
-- Index 1 = cheapest slot ($1), higher indices = more expensive.
-- Coal track: 13 slots, prices $1,$1,$2,$2,$3,$3,$4,$4,$5,$5,$6,$7,$8
-- Iron track: 8 slots, prices $1,$1,$2,$2,$3,$3,$4,$5 (PLACEHOLDER - verify from BoardData)

local MarketLayout = {}

-- IMPORTANT: These positions must be measured from the reference mod.
-- The format is Vector(x, y, z) in TTS world coordinates.
-- Positions are ordered from cheapest (index 1) to most expensive.
MarketLayout.positions = {
    coal = {
        -- 13 slots: $1, $1, $2, $2, $3, $3, $4, $4, $5, $5, $6, $7, $8
        [1]  = Vector(0, 0, 0),  -- TODO: measure from reference mod
        [2]  = Vector(0, 0, 0),
        [3]  = Vector(0, 0, 0),
        [4]  = Vector(0, 0, 0),
        [5]  = Vector(0, 0, 0),
        [6]  = Vector(0, 0, 0),
        [7]  = Vector(0, 0, 0),
        [8]  = Vector(0, 0, 0),
        [9]  = Vector(0, 0, 0),
        [10] = Vector(0, 0, 0),
        [11] = Vector(0, 0, 0),
        [12] = Vector(0, 0, 0),
        [13] = Vector(0, 0, 0),
    },
    iron = {
        -- 8 slots: $1, $1, $2, $2, $3, $3, $4, $5 (PLACEHOLDER - verify)
        [1] = Vector(0, 0, 0),  -- TODO: measure from reference mod
        [2] = Vector(0, 0, 0),
        [3] = Vector(0, 0, 0),
        [4] = Vector(0, 0, 0),
        [5] = Vector(0, 0, 0),
        [6] = Vector(0, 0, 0),
        [7] = Vector(0, 0, 0),
        [8] = Vector(0, 0, 0),
    },
}

MarketLayout.trackMax = {
    coal = 13,
    iron = 8,
}

--- Get the TTS world position for a market track slot.
--- @param resourceType string  "coal" or "iron"
--- @param index number  1-based slot index (1 = cheapest)
--- @return Vector  TTS world position
function MarketLayout.getPosition(resourceType, index)
    local track = MarketLayout.positions[resourceType]
    if not track then return Vector(0, 0, 0) end
    return track[index] or Vector(0, 0, 0)
end

--- Get the maximum capacity of a market track.
--- @param resourceType string  "coal" or "iron"
--- @return number
function MarketLayout.getTrackMax(resourceType)
    return MarketLayout.trackMax[resourceType] or 0
end

return MarketLayout
```

**Note to implementer:** The `Vector(0, 0, 0)` values are placeholders. You **must** measure real positions from the reference mod before this module is usable. The measurement step (Step 1) produces the actual coordinates. Fill them in before committing.

- [ ] **Step 3: Commit**

```bash
git add tts/MarketLayout.lua
git commit -m "feat(MarketLayout): add market track position mapping module"
```

---

## Task 3: ResourceAnimation Module

**Files:**
- Create: `tts/ResourceAnimation.lua`

**Interface:** `ResourceAnimation.play(moves, onComplete)`, `ResourceAnimation.spawnCube(resourceType, position, onSpawned)`, `ResourceAnimation.spawnAndMoveCube(resourceType, fromPos, toPos, onArrived)`

**Dependencies:** Uses `ObjectManager.spawnResource` (existing), references `state._animating` global.

- [ ] **Step 1: Create ResourceAnimation module**

Create `tts/ResourceAnimation.lua`:

```lua
--- ResourceAnimation.lua
-- Handles smooth movement animations for coal/iron cubes.
-- All spawned cubes are locked and non-interactable.

local ResourceAnimation = {}

ResourceAnimation.MOVE_INTERVAL = 0.4
ResourceAnimation.MOVE_DURATION = 0.6
ResourceAnimation.ARRIVE_BUFFER = 0.1

--- Play a sequence of cube movement animations.
--- Each move is played with a staggered delay (MOVE_INTERVAL between starts).
--- Sets state._animating = true at start, false when all complete.
--- @param moves table  array of { guid=string, targetPos=Vector, destroyAfter=bool }
--- @param onComplete function  called after all animations finish (may be nil)
function ResourceAnimation.play(moves, onComplete)
    if #moves == 0 then
        if onComplete then onComplete() end
        return
    end

    -- Lock player interaction during animation
    if state then state._animating = true end

    for i, move in ipairs(moves) do
        Wait.time(function()
            local obj = getObjectFromGUID(move.guid)
            if not obj then return end

            obj.setLock(false)
            obj.setPositionSmooth(move.targetPos, false, false)

            Wait.time(function()
                local o = getObjectFromGUID(move.guid)
                if not o then return end
                if move.destroyAfter then
                    o.destruct()
                else
                    o.setLock(true)
                end
            end, ResourceAnimation.MOVE_DURATION)
        end, (i - 1) * ResourceAnimation.MOVE_INTERVAL)
    end

    local totalTime = (#moves - 1) * ResourceAnimation.MOVE_INTERVAL
                    + ResourceAnimation.MOVE_DURATION
                    + ResourceAnimation.ARRIVE_BUFFER
    Wait.time(function()
        if state then state._animating = false end
        if onComplete then onComplete() end
    end, math.max(totalTime, 0.1))
end

--- Spawn a locked, non-interactable resource cube at a position.
--- @param resourceType string  "coal" or "iron"
--- @param position Vector  TTS world position
--- @param onSpawned function(obj)  callback with the spawned object (may be nil)
function ResourceAnimation.spawnCube(resourceType, position, onSpawned)
    local obj = ObjectManager.spawnResource(resourceType, position)
    if obj then
        obj.setLock(true)
        obj.interactable = false
        obj.setGMNotes(JSON.encode({
            type = "resource",
            resource = resourceType,
        }))
        if onSpawned then
            -- spawnResource may return before physics settle; short delay
            Wait.time(function() onSpawned(obj) end, 0.1)
        end
    end
    return obj
end

--- Spawn a cube at fromPos, then smooth-move it to toPos. Locked on arrival.
--- @param resourceType string  "coal" or "iron"
--- @param fromPos Vector  spawn position
--- @param toPos Vector  destination position
--- @param onArrived function(obj)  callback when cube reaches destination (may be nil)
function ResourceAnimation.spawnAndMoveCube(resourceType, fromPos, toPos, onArrived)
    ResourceAnimation.spawnCube(resourceType, fromPos, function(obj)
        if not obj then return end
        obj.setLock(false)
        obj.setPositionSmooth(toPos, false, false)
        Wait.time(function()
            if obj and not obj.isDestroyed() then
                obj.setLock(true)
            end
            if onArrived then onArrived(obj) end
        end, ResourceAnimation.MOVE_DURATION)
    end)
end

return ResourceAnimation
```

- [ ] **Step 2: Commit**

```bash
git add tts/ResourceAnimation.lua
git commit -m "feat(ResourceAnimation): add cube movement animation module"
```

---

## Task 4: Highlights.showResourceCandidates

**Files:**
- Modify: `tts/Highlights.lua`

**Interface:** `Highlights.showResourceCandidates(candidates, resourceType, onClickCallback)`, `Highlights.clearResourceCandidates()`

- [ ] **Step 1: Add resource candidate highlighting**

In `tts/Highlights.lua`, add a tracking table and two new functions before `return Highlights`:

```lua
-- Separate tracking for resource candidate highlights (independent of build/link highlights)
Highlights._resourceCandidateState = {
    markers = {},
    clickCallbackId = nil,
}

--- Show resource source candidates with highlights and click handlers.
--- @param candidates table  array of { slotId=string, cityName=string, cubesAvailable=number }
--- @param resourceType string  "coal" or "iron"
--- @param onClickCallback function(slotId)  called when player clicks a candidate
function Highlights.showResourceCandidates(candidates, resourceType, onClickCallback)
    Highlights.clearResourceCandidates()

    local color = (resourceType == "coal") and {1, 0.5, 0} or {0.6, 0.6, 0.6}  -- orange / grey

    for _, cand in ipairs(candidates) do
        local snapPos = SnapMap.getPositionForSlot(cand.slotId)
        if snapPos then
            local marker = Highlights._spawnMarker(snapPos + Vector(0, 0.5, 0), color)
            if marker then
                -- Store slotId on the marker for click detection
                marker.setGMNotes(JSON.encode({
                    type = "resource_candidate",
                    slotId = cand.slotId,
                }))
                marker.interactable = true  -- must be interactable to receive clicks
                -- Create an invisible click button on the marker
                marker.createButton({
                    click_function = "onResourceMarkerClicked",
                    function_owner = Global,
                    label          = "",
                    position       = {0, 0.2, 0},
                    width          = 1200,
                    height         = 1200,
                    color          = {0, 0, 0, 0},  -- invisible
                })
                table.insert(Highlights._resourceCandidateState.markers, marker)
            end
        end
    end

    -- Store callback for Global to invoke
    Highlights._resourceClickCallback = onClickCallback

    -- Announce
    local resName = (resourceType == "coal") and "Coal" or "Iron"
    local msg = "Choose " .. resName .. " source: click a highlighted building"
    if state and state._pendingResource then
        printToColor(msg, state._pendingResource.playerColor, color)
    end
end

--- Clear only resource candidate highlights.
function Highlights.clearResourceCandidates()
    for _, marker in ipairs(Highlights._resourceCandidateState.markers) do
        if marker and not marker.isDestroyed() then
            marker.destruct()
        end
    end
    Highlights._resourceCandidateState.markers = {}
    Highlights._resourceClickCallback = nil
end
```

- [ ] **Step 2: Commit**

```bash
git add tts/Highlights.lua
git commit -m "feat(Highlights): add resource candidate highlighting with click handlers"
```

---

## Task 5: Actions.build Auto-Sell

**Files:**
- Modify: `src/Actions.lua`

**Context:** After building a coal mine or iron works, produced resource cubes must fill empty market slots. This is a mandatory game rule. This task adds the pure logic only (no TTS animation — that's handled by EventHandlers in Task 8).

- [ ] **Step 1: Add autoSellResources function**

In `src/Actions.lua`, add a new function before `Actions.build`:

```lua
--- Auto-sell produced resources to market when building a coal mine or iron works.
--- Mandatory rule: if market has empty slots, cubes must fill them.
--- Returns { sold=number, kept=number } for the caller to animate.
--- @param state table
--- @param color string  builder's color
--- @param slot table  the board slot where tile was placed
--- @return table  { sold=number, kept=number }
function Actions.autoSellToMarket(state, color, slot)
    local tile = slot.tile
    if not tile then return { sold = 0, kept = 0 } end

    local resourceType = nil
    if tile.type == Constants.Industry.COAL then
        resourceType = Constants.Resource.COAL
    elseif tile.type == Constants.Industry.IRON then
        resourceType = Constants.Resource.IRON
    else
        return { sold = 0, kept = 0 }
    end

    local market = Market.getMarketSupply(state, resourceType)
    if not market then return { sold = 0, kept = 0 } end

    local track = Market.getTrack(resourceType)
    local trackMax = #track
    local emptySlots = trackMax - market.supply
    local produced = #tile.resources
    local sellCount = math.min(produced, emptySlots)
    local keepCount = produced - sellCount

    -- Sell cubes to market (remove from tile, add to market supply)
    for i = 1, sellCount do
        table.remove(tile.resources, #tile.resources)
        market.supply = market.supply + 1
    end

    -- Builder gains $1 per cube sold
    if sellCount > 0 then
        GameState.gainMoney(state, color, sellCount)
    end

    -- If all cubes sold, tile is empty -> auto-flip
    if #tile.resources == 0 and produced > 0 then
        tile.flipped = true
        if slot.occupant then
            advanceIncome(state, slot.occupant, tile.incomeSpaces)
        end
    end

    return { sold = sellCount, kept = keepCount }
end
```

- [ ] **Step 2: Call autoSellToMarket from Actions.build**

In `src/Actions.lua`, in `Actions.build`, add the auto-sell call after the resource placement block (after the brewery income advance block, before `GameState.playCard`). Find this section:

```lua
    -- Step 8: For breweries — income advance on placement (flipped = already done above)
    -- Breweries award income when they are sold/flipped; since they flip on build,
    -- we advance income now.
    if industryType == Constants.Industry.BREWERY then
        advanceIncome(state, color, tile.incomeSpaces)
    end
```

Add after it:

```lua
    -- Step 8b: Auto-sell for coal mines and iron works
    -- Produced cubes must fill empty market slots (mandatory rule).
    -- Returns sell/keep counts for TTS animation layer.
    local autoSellResult = Actions.autoSellToMarket(state, color, slot)
```

- [ ] **Step 3: Commit**

```bash
git add src/Actions.lua
git commit -m "feat(Actions): add auto-sell to market for coal/iron mine builds"
```

---

## Task 6: inject_scripts.py — Crown Callback & Cube Setup

**Files:**
- Modify: `scripts/inject_scripts.py`

- [ ] **Step 1: Add crown button callback injection**

In `scripts/inject_scripts.py`, add a new function after `patch_money_counters`:

```python
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
    -- Injected by inject_scripts.py: trigger our game state initialization
    Wait.time(function()
        Global.call('onPhysicalSetupComplete', {{playerCount = {player_count}}})
    end, 2.0)  -- delay to let physical setup animations finish
"""

CROWN_LABELS = {
    "5f8b97": "2 Players / 2\u4eba\u904a\u6232",  # 2人遊戲
    "9c5d5e": "3 Players / 3\u4eba\u904a\u6232",  # 3人遊戲
    "3ba14f": "4 Players / 4\u4eba\u904a\u6232",  # 4人遊戲
}


def patch_crown_buttons(mod_data: dict) -> int:
    """
    Append a Global.call callback to each crown button's LuaScript.
    Rename labels to bilingual text.
    Disable the AI/Mautoma button.
    Returns the number of crown buttons patched.
    """
    patched = 0

    for obj in mod_data.get("ObjectStates", []):
        guid = obj.get("GUID")

        # Crown setup buttons: append callback
        if guid in CROWN_BUTTON_GUIDS:
            player_count = CROWN_BUTTON_GUIDS[guid]
            script = obj.get("LuaScript", "")
            callback = CROWN_CALLBACK_SNIPPET.format(player_count=player_count)

            # Find the last 'end' in the script (end of the main coroutine)
            # and insert our callback just before it
            last_end_idx = script.rfind("\nend")
            if last_end_idx != -1:
                obj["LuaScript"] = (
                    script[:last_end_idx] + callback + script[last_end_idx:]
                )
            else:
                # Fallback: append at the end
                obj["LuaScript"] = script + "\n" + callback

            # Rename label
            if guid in CROWN_LABELS:
                obj["Nickname"] = CROWN_LABELS[guid]

            patched += 1

        # AI button: disable
        elif guid == AI_BUTTON_GUID:
            obj["LuaScript"] = ""
            obj["LuaScriptState"] = ""
            obj["Locked"] = True
            obj["Nickname"] = "(Disabled)"

    return patched
```

- [ ] **Step 2: Add coal/iron cube locking**

Add another function to lock existing coal/iron cube objects in the save file and tag them with GMNotes:

```python
# ---------------------------------------------------------------------------
# Lock coal/iron resource cubes
# ---------------------------------------------------------------------------

RESOURCE_CUBE_NAMES = {"Coal", "Iron", "coal", "iron"}


def lock_resource_cubes(mod_data: dict) -> int:
    """
    Find all coal/iron cube objects and set them to locked + non-interactable.
    Also tag them with GMNotes for identification.
    Returns the number of cubes locked.
    """
    locked = 0

    def _walk(obj: dict) -> None:
        nonlocal locked
        name = obj.get("Nickname", "") or obj.get("Name", "")
        # Match coal/iron cube objects (Custom_Token or similar)
        for res_name in RESOURCE_CUBE_NAMES:
            if res_name in name:
                resource_type = "coal" if "coal" in name.lower() else "iron"
                obj["Locked"] = True
                obj["GMNotes"] = json.dumps(
                    {"type": "resource", "resource": resource_type},
                    separators=(",", ":"),
                )
                locked += 1
                break

        for contained in obj.get("ContainedObjects", []):
            _walk(contained)

    for obj in mod_data.get("ObjectStates", []):
        _walk(obj)

    return locked
```

- [ ] **Step 3: Add new module to SRC_MODULES list**

In `inject_scripts.py`, add the new modules to the `SRC_MODULES` list, after the `EventHandlers` entry:

```python
    ("MarketLayout",       PROJECT_ROOT / "tts" / "MarketLayout.lua"),
    ("ResourceAnimation",  PROJECT_ROOT / "tts" / "ResourceAnimation.lua"),
```

- [ ] **Step 4: Call new functions from main()**

In the `main()` function, add calls after the existing patching steps (after `patch_money_counters`):

```python
    # 4e. Inject crown button callbacks
    print()
    print("Patching crown setup buttons...")
    n_crowns = patch_crown_buttons(mod_data)
    print(f"  Patched {n_crowns} crown button(s).")

    # 4f. Lock resource cubes
    print()
    print("Locking coal/iron resource cubes...")
    n_cubes = lock_resource_cubes(mod_data)
    print(f"  Locked {n_cubes} resource cube(s).")
```

- [ ] **Step 5: Commit**

```bash
git add scripts/inject_scripts.py
git commit -m "feat(inject): crown button callback, AI disable, cube locking"
```

---

## Task 7: CardManager Adaptation

**Files:**
- Modify: `tts/CardManager.lua`

**Context:** Crown buttons use 3 pre-built decks (2P/3P/4P). Our `CardManager.buildDeck` dynamically removes cards from one deck — this is no longer needed. Replace with functions that work with the crown's pre-built decks.

- [ ] **Step 1: Replace buildDeck and rebuildDeckForRailEra**

In `tts/CardManager.lua`, replace the `buildDeck` and `rebuildDeckForRailEra` functions, and add `findDeckOnBoard` and `dealFromDeck`:

Replace `CardManager.buildDeck`:

```lua
--- Find the card deck on the board (placed by crown setup button).
--- Searches for a Deck or Card object near the known deck snap point position.
--- @return TTS object|nil  the deck object
function CardManager.findDeckOnBoard()
    -- Known deck snap point position (from reference mod)
    local deckPos = Vector(-12.67, 0.96, 11.71)
    local bestObj = nil
    local bestDist = 5  -- max search radius

    for _, obj in ipairs(getAllObjects()) do
        if obj.type == "Deck" or obj.type == "Card" then
            local pos = obj.getPosition()
            local dist = math.sqrt(
                (pos.x - deckPos.x)^2 + (pos.z - deckPos.z)^2
            )
            if dist < bestDist then
                bestDist = dist
                bestObj = obj
            end
        end
    end

    return bestObj
end
```

Replace `CardManager.rebuildDeckForRailEra`:

```lua
--- Deal cards from a deck to all players.
--- @param state table  game state
--- @param deckObj TTS object  the deck to deal from
function CardManager.dealFromDeck(state, deckObj)
    if not deckObj then return end
    for _, color in ipairs(state.turnOrder) do
        local p = GameState.getPlayer(state, color)
        local toDeal = Constants.INITIAL_HAND_SIZE - (p.handSize or 0)
        if toDeal > 0 then
            deckObj.deal(toDeal, color)
            p.handSize = Constants.INITIAL_HAND_SIZE
        end
    end
end
```

Remove the old `buildDeck` function entirely. Remove the old `rebuildDeckForRailEra` function entirely. Keep `dealToAll` as a convenience wrapper:

```lua
--- Deal cards to all players from the deck on the board.
--- Convenience wrapper around findDeckOnBoard + dealFromDeck.
--- @param state table  game state
function CardManager.dealToAll(state)
    local deckObj = CardManager.findDeckOnBoard()
    if deckObj then
        CardManager.dealFromDeck(state, deckObj)
    end
end
```

- [ ] **Step 2: Update isDeckEmpty to use findDeckOnBoard**

Replace the existing `CardManager.isDeckEmpty`:

```lua
--- Check if the draw deck is empty.
--- @return boolean
function CardManager.isDeckEmpty()
    local deckObj = CardManager.findDeckOnBoard()
    if not deckObj then return true end
    if deckObj.type == "Deck" then return deckObj.getQuantity() <= 0 end
    if deckObj.type == "Card" then return false end  -- single card left
    return true
end
```

- [ ] **Step 3: Update refillHand to use findDeckOnBoard**

Replace the existing `CardManager.refillHand`:

```lua
--- Refill a player's hand to 8 cards.
--- @param state table  game state
--- @param color string  player color
function CardManager.refillHand(state, color)
    local deckObj = CardManager.findDeckOnBoard()
    if not deckObj then return end
    local p = GameState.getPlayer(state, color)
    local toDeal = Constants.INITIAL_HAND_SIZE - (p.handSize or 0)
    if toDeal > 0 and deckObj.getQuantity() >= toDeal then
        deckObj.deal(toDeal, color)
        p.handSize = Constants.INITIAL_HAND_SIZE
    end
end
```

- [ ] **Step 4: Commit**

```bash
git add tts/CardManager.lua
git commit -m "refactor(CardManager): adapt to crown pre-built decks"
```

---

## Task 8: EventHandlers Rewrite

**Files:**
- Modify: `tts/EventHandlers.lua`

**Dependencies:** Tasks 1 (Market.estimateCost), 2 (MarketLayout), 3 (ResourceAnimation), 4 (Highlights), 5 (Actions auto-sell)

This is the core integration task. Rewrite `handleTilePlaced` to implement the full resource consumption flow with validation, player choice, and animation.

- [ ] **Step 1: Add hard gate and resource click handler**

At the top of `EventHandlers.onObjectDrop`, add the hard gate. Also add the resource candidate click handler:

Replace the existing `EventHandlers.onObjectDrop`:

```lua
function EventHandlers.onObjectDrop(playerColor, droppedObject)
    if not state then return end  -- hard gate: no state, no automation
    if state._animating then return end  -- block during animation

    local objType, meta = EventHandlers.identifyObject(droppedObject)
    if not objType then return end

    if objType == "building_tile" then
        EventHandlers.handleTilePlaced(playerColor, droppedObject, meta)
    elseif objType == "link_tile" then
        EventHandlers.handleLinkDrop(playerColor, droppedObject)
    elseif objType == "card" then
        if isCurrentPlayer(playerColor) then
            EventHandlers.handleCardDrop(playerColor, droppedObject)
        end
    end
end
```

Add this new function for handling resource candidate clicks (called from Global via button callback):

```lua
--- Called when player clicks a highlighted resource candidate marker.
--- Consumes one cube from the selected source and advances the resource phase.
--- @param playerColor string  TTS seat color
--- @param slotId string  the clicked slot ID
function EventHandlers.onResourceCandidateClicked(playerColor, slotId)
    local pending = state._pendingResource
    if not pending then return end
    if pending.playerColor ~= playerColor then return end

    local slot = GameState.getSlot(state, slotId)
    if not slot or not slot.tile then return end

    local resourceType = (pending.phase == "iron") and Constants.Resource.IRON or Constants.Resource.COAL

    -- Consume one cube from this source
    if #slot.tile.resources > 0 then
        table.remove(slot.tile.resources, #slot.tile.resources)

        -- Track the cube GUID for animation
        local cubeGUID = nil
        if slot.resourceGUIDs and #slot.resourceGUIDs > 0 then
            cubeGUID = table.remove(slot.resourceGUIDs, #slot.resourceGUIDs)
        end

        -- Return cube to market (state update)
        Market.returnToMarket(state, resourceType, 1)

        -- Queue animation: cube flies from source to market track
        if cubeGUID then
            local marketSupply = Market.getMarketSupply(state, resourceType).supply
            local targetPos = MarketLayout.getPosition(resourceType, marketSupply)
            pending.moves[#pending.moves + 1] = {
                guid = cubeGUID,
                targetPos = targetPos,
                destroyAfter = false,
            }
            -- Record new market cube GUID
            local marketCubes = (resourceType == "coal")
                and state.coalMarket.cubeGUIDs
                or state.ironMarket.cubeGUIDs
            marketCubes[marketSupply] = cubeGUID
        end

        -- Auto-flip if source is now empty
        if #slot.tile.resources == 0 then
            autoFlipIfEmpty(state, slot)
        end

        -- Decrement remaining need
        if pending.phase == "iron" then
            pending.ironNeeded = pending.ironNeeded - 1
        else
            pending.coalNeeded = pending.coalNeeded - 1
        end
    end

    -- Check if current phase is satisfied
    local currentNeed = (pending.phase == "iron") and pending.ironNeeded or pending.coalNeeded
    if currentNeed <= 0 then
        Highlights.clearResourceCandidates()
        EventHandlers._advanceResourcePhase(pending)
    else
        -- Update candidates (remove exhausted sources)
        local newCandidates = {}
        for _, cand in ipairs(pending.candidates) do
            local s = GameState.getSlot(state, cand.slotId)
            if s and s.tile and #s.tile.resources > 0 then
                cand.cubesAvailable = #s.tile.resources
                newCandidates[#newCandidates + 1] = cand
            end
        end
        pending.candidates = newCandidates

        if #newCandidates <= 1 then
            -- Only one source left, auto-consume remaining
            Highlights.clearResourceCandidates()
            while currentNeed > 0 and #newCandidates > 0 do
                EventHandlers.onResourceCandidateClicked(playerColor, newCandidates[1].slotId)
                currentNeed = (pending.phase == "iron") and pending.ironNeeded or pending.coalNeeded
            end
        else
            -- Re-show highlights with updated candidates
            local resType = (pending.phase == "iron") and "iron" or "coal"
            Highlights.showResourceCandidates(newCandidates, resType, function(sid)
                EventHandlers.onResourceCandidateClicked(playerColor, sid)
            end)
        end
    end
end
```

- [ ] **Step 2: Add phase advancement logic**

Add helper functions for the resource consumption flow:

```lua
--- Advance the resource consumption phase.
--- Called when the current phase (iron or coal) is satisfied.
--- @param pending table  state._pendingResource
function EventHandlers._advanceResourcePhase(pending)
    if pending.phase == "iron" then
        -- Iron done. Buy any market iron.
        EventHandlers._buyMarketResources(pending, "iron")
        -- Move to coal phase
        pending.phase = "coal"
        EventHandlers._startResourcePhase(pending)

    elseif pending.phase == "coal" then
        -- Coal done. Buy any market coal.
        EventHandlers._buyMarketResources(pending, "coal")
        -- Move to animate phase
        pending.phase = "animate"
        EventHandlers._playAnimationsAndFinish(pending)
    end
end

--- Start a resource consumption phase (iron or coal).
--- If no board sources or only 1, auto-consume. If multiple, show highlights.
--- @param pending table  state._pendingResource
function EventHandlers._startResourcePhase(pending)
    local resourceType = pending.phase  -- "iron" or "coal"
    local needed = (resourceType == "iron") and pending.ironNeeded or pending.coalNeeded

    if needed <= 0 then
        EventHandlers._advanceResourcePhase(pending)
        return
    end

    -- Find board sources
    local sources
    if resourceType == "iron" then
        sources = Network.findIronSources(state)
    else
        local cityName = GameState.getCityForSlot(state, pending.buildSlotId)
        sources = Network.findNearestCoal(state, cityName) or {}
    end

    -- Build candidates list
    local candidates = {}
    for _, src in ipairs(sources) do
        candidates[#candidates + 1] = {
            slotId = src.slotId,
            cityName = src.cityName,
            cubesAvailable = #src.slot.tile.resources,
        }
    end
    pending.candidates = candidates

    if #candidates == 0 then
        -- All from market
        EventHandlers._advanceResourcePhase(pending)

    elseif #candidates == 1 then
        -- Auto-consume from the only source
        while needed > 0 and #candidates[1].cubesAvailable > 0 do
            EventHandlers.onResourceCandidateClicked(pending.playerColor, candidates[1].slotId)
            needed = (resourceType == "iron") and pending.ironNeeded or pending.coalNeeded
            candidates[1].cubesAvailable = #(GameState.getSlot(state, candidates[1].slotId).tile.resources)
        end
        -- If still need more, advance (will buy from market)
        if needed > 0 then
            EventHandlers._advanceResourcePhase(pending)
        end

    else
        -- Multiple sources: highlight and wait for player clicks
        Highlights.showResourceCandidates(candidates, resourceType, function(slotId)
            EventHandlers.onResourceCandidateClicked(pending.playerColor, slotId)
        end)
    end
end

--- Buy remaining resources from market, queueing animations.
--- @param pending table  state._pendingResource
--- @param resourceType string  "iron" or "coal"
function EventHandlers._buyMarketResources(pending, resourceType)
    local fromMarket = (resourceType == "iron") and pending.ironFromMarket or pending.coalFromMarket
    if fromMarket <= 0 then return end

    local marketCubes = (resourceType == "coal")
        and state.coalMarket.cubeGUIDs
        or state.ironMarket.cubeGUIDs

    for i = 1, fromMarket do
        -- Remove the most expensive cube (last in array) from market
        local cubeGUID = table.remove(marketCubes, #marketCubes)
        if cubeGUID then
            -- Queue animation: cube flies from market to build site, then destroyed
            pending.moves[#pending.moves + 1] = {
                guid = cubeGUID,
                targetPos = pending.buildPos + Vector(0, 1, 0),
                destroyAfter = true,
            }
        end
        -- Market state already updated by Market.buyFromMarket in pre-validation cost calc
        -- Actually we need to do the actual state update here
        Market.buyFromMarket(state, pending.playerColor, resourceType, 1)
    end
end

--- Play all queued animations, then handle auto-sell and finish.
--- @param pending table  state._pendingResource
function EventHandlers._playAnimationsAndFinish(pending)
    ResourceAnimation.play(pending.moves, function()
        -- After resource consumption animations: handle auto-sell for coal/iron mines
        local slot = GameState.getSlot(state, pending.buildSlotId)
        if slot and slot.tile then
            local tileType = slot.tile.type
            if tileType == Constants.Industry.COAL or tileType == Constants.Industry.IRON then
                EventHandlers._handleAutoSell(pending, slot)
                return  -- _handleAutoSell will call _finishBuild when done
            end
        end
        EventHandlers._finishBuild(pending)
    end)
end

--- Handle auto-sell animation for coal/iron mine builds.
--- @param pending table  state._pendingResource
--- @param slot table  the build slot
function EventHandlers._handleAutoSell(pending, slot)
    local tile = slot.tile
    local resourceType = (tile.type == Constants.Industry.COAL) and "coal" or "iron"
    local market = Market.getMarketSupply(state, resourceType)
    local trackMax = MarketLayout.getTrackMax(resourceType)
    local emptySlots = trackMax - market.supply
    local produced = #tile.resources
    local sellCount = math.min(produced, emptySlots)
    local keepCount = produced - sellCount

    local sellMoves = {}

    -- Sell cubes: spawn at build site and move to market
    for i = 1, sellCount do
        table.remove(tile.resources, #tile.resources)
        market.supply = market.supply + 1
        local targetPos = MarketLayout.getPosition(resourceType, market.supply)
        -- We need to spawn a cube and move it
        ResourceAnimation.spawnAndMoveCube(resourceType, pending.buildPos + Vector(0, 0.5, 0), targetPos, function(obj)
            if obj then
                local marketCubes = (resourceType == "coal")
                    and state.coalMarket.cubeGUIDs
                    or state.ironMarket.cubeGUIDs
                marketCubes[market.supply] = obj.getGUID()
            end
        end)
    end

    -- Keep cubes: spawn on tile
    for i = 1, keepCount do
        local spawnPos = pending.buildPos + Vector(0, 0.3 + (i - 1) * 0.4, 0)
        ResourceAnimation.spawnCube(resourceType, spawnPos, function(obj)
            if obj then
                if not slot.resourceGUIDs then slot.resourceGUIDs = {} end
                slot.resourceGUIDs[#slot.resourceGUIDs + 1] = obj.getGUID()
            end
        end)
    end

    -- Builder gains $1 per sold cube
    if sellCount > 0 then
        GameState.gainMoney(state, pending.playerColor, sellCount)
    end

    -- Auto-flip if all sold
    if keepCount == 0 and produced > 0 then
        tile.flipped = true
        if slot.occupant then
            advanceIncome(state, slot.occupant, tile.incomeSpaces)
        end
    end

    -- Wait for sell animations to complete, then finish
    local delay = sellCount * ResourceAnimation.MOVE_INTERVAL + ResourceAnimation.MOVE_DURATION + ResourceAnimation.ARRIVE_BUFFER
    Wait.time(function()
        EventHandlers._finishBuild(pending)
    end, math.max(delay, 0.1))
end

--- Finish the build action: announce, clean up pending state, advance turn.
--- @param pending table  state._pendingResource
function EventHandlers._finishBuild(pending)
    local meta = pending.meta

    -- Announce
    local INDUSTRY_LABELS = {
        cotton       = "Cotton Mill",
        coal         = "Coal Mine",
        iron         = "Iron Works",
        brewery      = "Brewery",
        manufacturer = "Manufacturer",
        pottery      = "Pottery",
    }
    local label = (INDUSTRY_LABELS[meta.industry] or meta.industry or "Building")
                  .. " Lv" .. (meta.level or "?")
    local totalSpent = (meta.money or 0)
        + Market.estimateCost(state, "coal", pending.coalFromMarket)
        + Market.estimateCost(state, "iron", pending.ironFromMarket)
    printToAll(pending.playerColor .. " built " .. label .. " ($" .. totalSpent .. " total)")

    -- Clean up
    state._pendingResource = nil

    -- Advance turn if game state is fully active
    if state._pendingCard then
        Highlights.clearAll()
        state._pendingCard = nil
        afterAction(pending.playerColor)
    end
end
```

- [ ] **Step 3: Rewrite handleTilePlaced**

Replace the existing `EventHandlers.handleTilePlaced` entirely:

```lua
function EventHandlers.handleTilePlaced(playerColor, tileObj, meta)
    -- Requires full game state
    if not state then return end

    local cost = meta.money or 0
    local coalNeeded = meta.coal or 0
    local ironNeeded = meta.iron or 0

    -- Determine build position
    local buildPos = tileObj.getPosition()
    local snapInfo = SnapMap.findNearestPosition(buildPos, 2.0)
    local buildSlotId = snapInfo and snapInfo.id or nil
    local cityName = buildSlotId and GameState.getCityForSlot(state, buildSlotId) or nil

    -- === Pre-validation ===
    local player = GameState.getPlayer(state, playerColor)

    -- Count board sources
    local boardCoal = 0
    if coalNeeded > 0 and cityName then
        local coalSources = Network.findNearestCoal(state, cityName) or {}
        for _, src in ipairs(coalSources) do
            boardCoal = boardCoal + #src.slot.tile.resources
        end
    end
    local boardIron = 0
    if ironNeeded > 0 then
        local ironSources = Network.findIronSources(state)
        for _, src in ipairs(ironSources) do
            boardIron = boardIron + #src.slot.tile.resources
        end
    end

    local coalFromMarket = math.max(0, coalNeeded - boardCoal)
    local ironFromMarket = math.max(0, ironNeeded - boardIron)

    -- Coal market access check
    if coalFromMarket > 0 and cityName then
        if not Network.hasMarketConnection(state, playerColor, cityName) then
            printToColor("Cannot buy coal: no connection to merchant", playerColor, {1, 0, 0})
            returnToPlayerArea(tileObj, playerColor)
            return
        end
    end

    -- Money check (base cost + market shortfall costs)
    local coalMarketCost = Market.estimateCost(state, "coal", coalFromMarket)
    local ironMarketCost = Market.estimateCost(state, "iron", ironFromMarket)
    local totalCost = cost + coalMarketCost + ironMarketCost

    if player.money < totalCost then
        printToColor("Not enough money: need $" .. totalCost .. " (build $" .. cost
            .. " + market coal $" .. coalMarketCost
            .. " + market iron $" .. ironMarketCost
            .. "), have $" .. player.money, playerColor, {1, 0, 0})
        returnToPlayerArea(tileObj, playerColor)
        return
    end

    -- Resource availability check
    if coalNeeded > boardCoal + (state.coalMarket.supply) then
        printToColor("Not enough coal available", playerColor, {1, 0, 0})
        returnToPlayerArea(tileObj, playerColor)
        return
    end
    if ironNeeded > boardIron + (state.ironMarket.supply) then
        printToColor("Not enough iron available", playerColor, {1, 0, 0})
        returnToPlayerArea(tileObj, playerColor)
        return
    end

    -- === All checks passed: commit ===

    -- Deduct money immediately
    GameState.spendMoney(state, playerColor, totalCost)
    PLAYER_SPEND[playerColor] = (PLAYER_SPEND[playerColor] or 0) + totalCost

    -- Update physical counters
    local spendGUID = COLOR_TO_SPEND_GUID[playerColor]
    if spendGUID then
        local spendObj = getObjectFromGUID(spendGUID)
        if spendObj and spendObj.Counter then
            spendObj.Counter.setValue(PLAYER_SPEND[playerColor])
        end
    end
    local moneyGUID = COLOR_TO_MONEY_GUID[playerColor]
    if moneyGUID then
        local moneyObj = getObjectFromGUID(moneyGUID)
        if moneyObj then
            local ok, _ = pcall(function()
                moneyObj.setDescription(tostring(player.money))
                moneyObj.call('customSet')
            end)
        end
    end

    -- Lock the placed tile
    if snapInfo then
        local snapPos = SnapMap.getPositionForSlot(snapInfo.id)
        if snapPos then
            ObjectManager.moveTo(tileObj, snapPos)
        end
        ObjectManager.lock(tileObj)
    end

    -- Set up pending resource consumption
    state._pendingResource = {
        playerColor    = playerColor,
        buildSlotId    = buildSlotId,
        buildPos       = buildPos,
        meta           = meta,
        ironNeeded     = math.min(ironNeeded, boardIron),  -- only board portion
        coalNeeded     = math.min(coalNeeded, boardCoal),  -- only board portion
        ironFromMarket = ironFromMarket,
        coalFromMarket = coalFromMarket,
        phase          = "iron",
        candidates     = {},
        moves          = {},
    }

    -- Start the iron consumption phase
    EventHandlers._startResourcePhase(state._pendingResource)
end
```

- [ ] **Step 4: Remove old deductTileCost**

Delete the entire `EventHandlers.deductTileCost` function — its logic is now inlined in `handleTilePlaced`.

- [ ] **Step 5: Commit**

```bash
git add tts/EventHandlers.lua
git commit -m "feat(EventHandlers): full resource consumption flow with validation and animation"
```

---

## Task 9: Global.lua Rewrite

**Files:**
- Modify: `tts/Global.lua`

**Dependencies:** Tasks 6 (inject crown callback), 7 (CardManager), 8 (EventHandlers)

- [ ] **Step 1: Add #include for new modules**

In `tts/Global.lua`, add the new module includes after the EventHandlers include:

```lua
#include tts/MarketLayout
#include tts/ResourceAnimation
```

- [ ] **Step 2: Replace startGame with onPhysicalSetupComplete**

Replace the entire `startGame` function and the `onSetup*` functions with:

```lua
------------------------------------------------------
-- SETUP (called by crown button callback)
------------------------------------------------------

-- Pre-built deck GUIDs (crown buttons select one of these)
PREBUILT_DECK_GUIDS = {
    [2] = "b6ff44",
    [3] = "3895fe",
    [4] = "bc3ba4",
}

function onPhysicalSetupComplete(params)
    local playerCount = params.playerCount
    printToAll("Initializing game state for " .. playerCount .. " players...")

    local ok, err = pcall(function()
        state = GameState.new(playerCount)
    end)
    if not ok then
        printToAll("[ERROR] GameState.new failed: " .. tostring(err))
        return
    end

    -- Deal cards from the deck the crown placed on the board
    local deck = CardManager.findDeckOnBoard()
    if deck then
        CardManager.dealFromDeck(state, deck)
    else
        printToAll("[WARNING] Could not find card deck on board")
    end

    -- Hide unused pre-built decks
    hideUnusedDecks(playerCount)

    -- Set money counters to starting value
    for _, color in ipairs(state.turnOrder) do
        local moneyGUID = COLOR_TO_MONEY_GUID[color]
        if moneyGUID then
            local moneyObj = getObjectFromGUID(moneyGUID)
            if moneyObj then
                moneyObj.setDescription(tostring(Constants.INITIAL_MONEY))
                pcall(function() moneyObj.call('customSet') end)
            end
        end
        -- Reset spend trackers
        local spendGUID = COLOR_TO_SPEND_GUID[color]
        if spendGUID then
            local spendObj = getObjectFromGUID(spendGUID)
            if spendObj and spendObj.Counter then
                spendObj.Counter.setValue(0)
            end
        end
    end

    PLAYER_SPEND = {}

    -- Spawn market coal/iron cubes
    spawnMarketCubes(state)

    -- Income phase for first round
    TurnManager.incomePhase(state)

    -- Scan objects
    ObjectManager.scanTable()

    -- Build snap point mappings
    local board = ObjectManager.getObject("mainBoard")
    if board then SnapMap.buildFromObject(board) end

    -- Configure UI
    UIManager.hideSetup()
    UIManager.configureForPlayerCount(playerCount)
    broadcastCurrentPlayer()

    printToAll(Lang.format("game_started", state.lang, { count = playerCount }))
    printToAll(Lang.get("canal_era", state.lang))
end

function hideUnusedDecks(playerCount)
    for pc, guid in pairs(PREBUILT_DECK_GUIDS) do
        if pc ~= playerCount then
            local obj = getObjectFromGUID(guid)
            if obj then
                obj.setPosition(Vector(0, -5, 0))  -- move off-table
                Wait.time(function()
                    local o = getObjectFromGUID(guid)
                    if o then o.destruct() end
                end, 1.0)
            end
        end
    end
end

function spawnMarketCubes(gameState)
    -- Spawn coal cubes on market track
    gameState.coalMarket.cubeGUIDs = {}
    for i = 1, gameState.coalMarket.supply do
        local pos = MarketLayout.getPosition("coal", i)
        ResourceAnimation.spawnCube("coal", pos, function(obj)
            if obj then
                gameState.coalMarket.cubeGUIDs[i] = obj.getGUID()
            end
        end)
    end

    -- Spawn iron cubes on market track
    gameState.ironMarket.cubeGUIDs = {}
    for i = 1, gameState.ironMarket.supply do
        local pos = MarketLayout.getPosition("iron", i)
        ResourceAnimation.spawnCube("iron", pos, function(obj)
            if obj then
                gameState.ironMarket.cubeGUIDs[i] = obj.getGUID()
            end
        end)
    end
end
```

- [ ] **Step 3: Remove old onSetup functions and DEBUG prints**

Delete these functions (no longer needed — crown buttons trigger directly):
```lua
function onSetup2P() startGame(2) end
function onSetup3P() startGame(3) end
function onSetup4P() startGame(4) end
```

Remove the DEBUG printToAll lines from `onObjectDrop`:

```lua
function onObjectDrop(playerColor, droppedObject)
    EventHandlers.onObjectDrop(playerColor, droppedObject)
end
```

- [ ] **Step 4: Add resource marker click handler**

Add the Global function that marker buttons call:

```lua
--- Called by resource candidate marker buttons (created by Highlights).
--- Routes to EventHandlers for processing.
function onResourceMarkerClicked(obj, playerColor)
    if not state or not state._pendingResource then return end
    local notes = obj.getGMNotes()
    if notes and notes ~= "" then
        local ok, meta = pcall(JSON.decode, notes)
        if ok and meta and meta.slotId then
            EventHandlers.onResourceCandidateClicked(playerColor, meta.slotId)
        end
    end
end
```

- [ ] **Step 5: Add animation lock to onObjectDrop**

The animation lock is already handled in the EventHandlers rewrite (Task 8, Step 1), where `state._animating` is checked. No additional changes needed in Global.lua.

- [ ] **Step 6: Commit**

```bash
git add tts/Global.lua
git commit -m "feat(Global): crown callback setup, market cube spawning, resource click routing"
```

---

## Task 10: Bundle, Inject, and TTS Test

**Files:**
- All files from Tasks 1-9

- [ ] **Step 1: Run inject_scripts.py**

```bash
cd C:\Users\andyc\Projects\brass_birmingham_tbs
python scripts/inject_scripts.py
```

Expected output should include:
- All existing patching messages
- "Patched 3 crown button(s)."
- "Locked N resource cube(s)."
- Output written to `brass_birmingham_scripted.json` and copied to `TS_Save_99.json`

- [ ] **Step 2: Load in TTS and verify**

Load `TS_Save_99` in Tabletop Simulator. Verify:

1. **Crown button click** → physical setup occurs (shuffle, merchants, barrels), then our `onPhysicalSetupComplete` triggers (cards dealt, counters set)
2. **AI button** → disabled, no interaction
3. **Market cubes** → appear on coal/iron tracks, locked, non-interactable
4. **Place a building tile** (e.g., Cotton Lv1, $12, 0 coal, 0 iron) → money deducted, spend tracker updated
5. **Place a building tile with coal** (e.g., Iron Works Lv1, $5, 1 coal) → if coal on board: highlight source, click to consume, cube animates to market; if no coal: auto-buy from market, cube animates from market to build site
6. **Place a coal mine** → cubes auto-sell to market track, money gained, tile flips if all sold
7. **Error case**: try to build without enough money → tile returned, error message shown

- [ ] **Step 3: Fix any issues and re-inject**

If issues are found, fix the relevant source files and re-run:

```bash
python scripts/inject_scripts.py
```

Reload `TS_Save_99` in TTS and re-verify.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: market automation - resource consumption, animation, crown callback integration"
```

---

---

## Errata: Post-Review Fixes

The following critical issues were found during /simplify review and must be applied during implementation:

### Fix 1: Track capacity is 14 (coal) / 10 (iron), not 13/8

`BoardData.coalMarketTrack` has 14 entries, `ironMarketTrack` has 10. `Constants.INITIAL_COAL_SUPPLY=13` / `INITIAL_IRON_SUPPLY=8` are starting fill levels, not max capacity. All tasks must use `#Market.getTrack(resourceType)` for max capacity. Remove `MarketLayout.trackMax` hardcoded table — derive from `#Market.getTrack()`. MarketLayout.positions must have 14 coal slots and 10 iron slots.

### Fix 2: Double money deduction

`handleTilePlaced` must only deduct `baseMoney` (the building cost). Market purchase costs are deducted by `Market.buyFromMarket` in `_buyMarketResources`. Do NOT pre-deduct market costs. The totalCost is only used for **validation** (checking affordability), not deduction.

### Fix 3: Restore Validation.canBuild

`handleTilePlaced` must call `Validation.canBuild` before the resource flow for full game-rule validation (era, card type, slot occupancy, overbuild, tile stack, network). The resource affordability check (with market costs) is an **additional** check on top of canBuild, not a replacement.

Additionally, after validation passes, `handleTilePlaced` must perform the state updates that `Actions.build` does (minus resource consumption, which our animated flow handles):
- Remove tile from `player.unbuiltTiles`
- Place tile on slot (`slot.occupant = color, slot.tile = tile`)
- Initialize tile resources and auto-flip breweries
- Call `GameState.playCard`

### Fix 4: _handleAutoSell must call Actions.autoSellToMarket

Task 8's `_handleAutoSell` must call `Actions.autoSellToMarket(state, color, slot)` for state mutation, then use the returned `{ sold, kept }` to drive animation only. No inline market manipulation.

### Fix 5: Store actual cost during purchase, don't re-estimate

In `_finishBuild`, store the actual total spent during the flow (in `_pendingResource.totalSpent`), don't call `Market.estimateCost` again after supply has changed.

### Fix 6: Cache BFS results

`handleTilePlaced` should store the found coal/iron sources in `_pendingResource.cachedCoalSources` / `cachedIronSources`. `_startResourcePhase` reads from cache instead of re-running BFS.

### Fix 7: clearAll must also clear resource candidates

In Task 4, add `Highlights.clearResourceCandidates()` at the end of `Highlights.clearAll()`.

### Fix 8: Stagger auto-sell animations

In `_handleAutoSell`, use `Wait.time((i-1) * MOVE_INTERVAL, ...)` to stagger each `spawnAndMoveCube` call, not fire them all in one frame.

### Fix 9: Use Constants.Resource.* consistently

Replace all raw `"coal"`/`"iron"` strings with `Constants.Resource.COAL`/`Constants.Resource.IRON`. Add `Constants.ResourcePhase = { IRON="iron", COAL="coal", ANIMATE="animate", DONE="done" }` for phase strings.

### Fix 10: Add cancellation path

Add `EventHandlers.cancelPendingResource()` that clears `state._pendingResource`, calls `Highlights.clearResourceCandidates()`, and returns the tile to player area. Call this from `onEndTurn` and `onObjectPickUp` if the placed tile is picked back up.
