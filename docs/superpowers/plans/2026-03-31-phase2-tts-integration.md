# Phase 2: TTS Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Phase 1's pure Lua game logic to Tabletop Simulator's object system — Snap Points, physical objects, XML UI, card management, and visual feedback.

**Architecture:** New files live in `tts/` and bridge `src/` modules to TTS API calls. `tts/Global.lua` (already exists) is the entry point. New modules handle object mapping, UI rendering, card operations, and visual highlighting. No game logic changes — only TTS bindings.

**Tech Stack:** TTS Lua (MoonSharp), TTS XML UI, TTS Object API (Snap Points, highlightOn, createButton, etc.)

**Spec:** `docs/superpowers/specs/2026-03-30-brass-birmingham-tts-mod-design.md`

**Depends on:** Phase 1 complete (all `src/` modules)

---

## File Structure (Phase 2 additions)

```
brass_birmingham_tbs/
├── src/          — (Phase 1, unchanged)
├── tts/
│   ├── Global.lua           — (exists, will be updated)
│   ├── SnapMap.lua          — Snap Point GUID ↔ game position mapping
│   ├── ObjectManager.lua    — TTS object references, GUID registry, object spawning
│   ├── CardManager.lua      — Deck/card operations: shuffle, deal, discard, wild supply
│   ├── Highlights.lua       — Visual highlighting for legal moves (highlightOn/Off)
│   ├── UIManager.lua        — XML UI rendering: counters, setup panel, turn indicator
│   └── EventHandlers.lua    — TTS event callbacks: onObjectDrop, onObjectPickUp, etc.
├── xml/
│   └── UI.xml               — TTS XML UI definition (counters, buttons, panels)
└── docs/
```

---

### Task 1: SnapMap — Snap Point Mapping System

**Files:**
- Create: `tts/SnapMap.lua`

**Description:**
Maps TTS Snap Point GUIDs to game-logical positions and vice versa. On setup, scans the main board object for all Snap Points and builds the mapping from their tags.

**API:**
```lua
local SnapMap = {}

-- Scan a TTS object (main board) for all snap points and build mappings
-- Tags follow format: "city_Birmingham_cotton_1", "link_Birmingham-Coventry", "market_coal_3"
function SnapMap.buildFromObject(boardObject)
    -- Iterates boardObject.getSnapPoints()
    -- Parses each snap point's tags[1]
    -- Builds:
    --   SnapMap.byTag[tag] = { position, rotation, snapIndex }
    --   SnapMap.bySlotId[slotId] = snapPoint data
    --   SnapMap.byLinkId[linkId] = snapPoint data
end

-- Get the world position for a game slot
function SnapMap.getPositionForSlot(slotId)
    return SnapMap.bySlotId[slotId] and SnapMap.bySlotId[slotId].position
end

-- Get the world position for a link
function SnapMap.getPositionForLink(linkId)
    return SnapMap.byLinkId[linkId] and SnapMap.byLinkId[linkId].position
end

-- Find which game position a world position corresponds to (for drop events)
-- Returns { type = "slot"|"link"|"market", id = "..." } or nil
function SnapMap.findNearestPosition(worldPos, threshold)
end

return SnapMap
```

**Key details:**
- Snap Points are defined on the main board Custom Tile
- Each Snap Point has a tag string identifying its game-logical position
- Tag format: `city_CityName_industryType_N` for building slots, `link_CityA-CityB` for routes
- This module has NO game logic — only coordinate mapping
- ~80-100 lines

- [ ] Create `tts/SnapMap.lua`
- [ ] Commit

---

### Task 2: ObjectManager — TTS Object Registry

**Files:**
- Create: `tts/ObjectManager.lua`

**Description:**
Manages references to all TTS objects by GUID. Provides functions to find, spawn, move, and destroy game objects. Acts as the bridge between GameState (which tracks logical state) and TTS (which tracks physical objects).

**API:**
```lua
local ObjectManager = {}

-- Object GUID registry (populated during setup or onLoad)
ObjectManager.guids = {
    mainBoard = nil,       -- Main board tile GUID
    drawDeck = nil,        -- Draw pile deck GUID
    discardZone = nil,     -- Discard scripting zone GUID
    playerBoards = {},     -- { ["Red"] = GUID, ... }
    playerHandZones = {},  -- { ["Red"] = GUID, ... }
    wildLocationSupply = nil,
    wildIndustrySupply = nil,
    languageToggle = nil,
}

-- Find and register all known objects by name/description/tag
function ObjectManager.scanTable()
    -- Scans all objects on the table
    -- Identifies objects by their Name or Description field
    -- Populates guids registry
end

-- Get a TTS object by its role
function ObjectManager.getObject(role)
    local guid = ObjectManager.guids[role]
    return guid and getObjectFromGUID(guid)
end

-- Spawn a resource token (coal/iron/beer) at a position
function ObjectManager.spawnResource(resourceType, position, rotation)
    -- Spawns from an infinite bag or clones from a template object
end

-- Spawn a money token at a player's area
function ObjectManager.spawnMoney(denomination, playerColor, count)
end

-- Move an object smoothly to a position
function ObjectManager.moveTo(obj, position, rotation)
    obj.setPositionSmooth(position)
    if rotation then obj.setRotationSmooth(rotation) end
end

-- Destroy an object (remove from table)
function ObjectManager.destroy(obj)
    obj.destruct()
end

-- Lock/unlock an object
function ObjectManager.lock(obj)
    obj.setLock(true)
end

return ObjectManager
```

**Key details:**
- Uses TTS API: `getObjectFromGUID`, `getAllObjects`, `spawnObject`, `object.destruct`
- GUIDs are saved/restored via `onSave`/`onLoad` so they persist across sessions
- Template objects (infinite bags for resources/money) are expected to exist on the table
- ~120-150 lines

- [ ] Create `tts/ObjectManager.lua`
- [ ] Commit

---

### Task 3: CardManager — Deck & Card Operations

**Files:**
- Create: `tts/CardManager.lua`

**Description:**
Handles all card-related TTS operations: deck building, shuffling, dealing, discarding, wild card supply management.

**API:**
```lua
local CardManager = {}

-- Build the draw deck for the current player count
-- Removes location cards for cities not in play
function CardManager.buildDeck(state, drawDeckObj)
    -- Based on state.playerCount, remove cards matching removed cities
    -- Shuffle the deck
end

-- Deal cards to all players (fill to hand size 8)
function CardManager.dealToAll(state)
    local deckObj = ObjectManager.getObject("drawDeck")
    for _, color in ipairs(state.turnOrder) do
        local handZone = ObjectManager.getObject("playerHandZones")[color]
        -- Deal cards from deck to hand zone
        deckObj.deal(Constants.INITIAL_HAND_SIZE, color)
    end
end

-- Handle a card being played (dropped into discard zone)
-- Returns card info: { cardType, location/industryType }
function CardManager.onCardPlayed(cardObj)
    -- Read card's Name or Description to determine type
    -- Parse: "Location: Birmingham" or "Industry: Cotton" or "Wild Location"
    -- Return structured data
end

-- Handle discarding (for Scout action)
function CardManager.discardCards(playerColor, count)
    -- Move N cards from player's hand to discard pile
end

-- Return a wild card to its supply
function CardManager.returnWildToSupply(cardObj, wildType)
    -- Move card to wild supply area
end

-- Give wild cards to a player (Scout result)
function CardManager.giveWilds(playerColor)
    -- Move 1 wild location + 1 wild industry from supply to player's hand
end

-- Check if draw deck is empty
function CardManager.isDeckEmpty()
    local deckObj = ObjectManager.getObject("drawDeck")
    return deckObj == nil or deckObj.getQuantity() == 0
end

-- Rebuild deck for rail era (collect all discards, shuffle)
function CardManager.rebuildDeckForRailEra(state)
    -- Collect all cards from discard zone
    -- Remove cards for cities not in play
    -- Shuffle into new draw deck
    -- Deal to all players
end

return CardManager
```

**Key details:**
- Card identification via Name field (set during asset creation in Phase 3)
- Uses TTS API: `deck.deal()`, `deck.shuffle()`, `object.getQuantity()`
- Wild cards are separate objects, not in the deck
- ~100-130 lines

- [ ] Create `tts/CardManager.lua`
- [ ] Commit

---

### Task 4: Highlights — Visual Move Feedback

**Files:**
- Create: `tts/Highlights.lua`

**Description:**
Provides visual highlighting on TTS objects to indicate legal moves. Uses TTS's `highlightOn()` API with color-coded highlighting.

**API:**
```lua
local Highlights = {}

local HIGHLIGHT_COLOR = {0.2, 1, 0.2}  -- Green for valid
local HIGHLIGHT_DURATION = -1            -- Persistent until cleared

-- Highlight all valid build locations for a player
function Highlights.showValidBuildSpots(state, color, cardInfo)
    Highlights.clearAll()
    -- Use Validation to get valid spots
    -- For each valid slot, find the TTS snap point via SnapMap
    -- Create a highlight indicator (colored circle or glow on the board position)
    -- TTS doesn't highlight snap points directly, so we use:
    --   1. createButton on the board at snap point positions, or
    --   2. Spawn temporary highlight tokens at valid positions
end

-- Highlight all valid network link positions
function Highlights.showValidLinkSpots(state, color)
    Highlights.clearAll()
    -- Similar: iterate all links, check Validation.canNetwork for each
    -- Highlight valid link positions
end

-- Highlight all sellable buildings
function Highlights.showSellableBuildings(state, color)
    Highlights.clearAll()
    -- Find all buildings owned by color that can be sold
    -- highlightOn() those TTS objects
end

-- Highlight a specific object (e.g., a building tile being targeted)
function Highlights.highlightObject(obj, color)
    obj.highlightOn(color or HIGHLIGHT_COLOR, HIGHLIGHT_DURATION)
end

-- Clear all active highlights
function Highlights.clearAll()
    -- Remove all temporary highlight tokens
    -- highlightOff() on all previously highlighted objects
    for _, obj in ipairs(Highlights.activeHighlights) do
        if obj and not obj.isDestroyed() then
            obj.highlightOff()
        end
    end
    Highlights.activeHighlights = {}
end

Highlights.activeHighlights = {}

return Highlights
```

**Key details:**
- TTS `highlightOn(color, duration)` adds a colored glow to objects
- For snap point positions (empty spots on the board), we may need temporary marker tokens
- `clearAll()` must be called before showing new highlights and after an action completes
- ~80-120 lines

- [ ] Create `tts/Highlights.lua`
- [ ] Commit

---

### Task 5: XML UI — Player Counters & Setup Panel

**Files:**
- Create: `xml/UI.xml`
- Create: `tts/UIManager.lua`

**Description:**
TTS XML UI for player spend counters, turn indicator, setup panel, and language toggle.

**xml/UI.xml:**
```xml
<!-- Player Spend Counters (one per player, positioned at corners) -->
<Panel id="counterPanel_Red" position="0 0 0" rotation="0 0 0"
       width="120" height="80" color="#111111E0">
    <Text id="counterLabel_Red" text="本回合花費" fontSize="12"
          color="#E74C3C" alignment="UpperCenter"/>
    <Text id="counterValue_Red" text="£0" fontSize="28"
          color="#FFFFFF" alignment="MiddleCenter" fontStyle="Bold"/>
    <Text id="counterAuto_Red" text="自動追蹤" fontSize="10"
          color="#888888" alignment="LowerCenter"/>
</Panel>
<!-- Repeat for Blue, Yellow, Green with their colors -->

<!-- Turn Indicator -->
<Panel id="turnPanel" position="0 200 0" width="300" height="50"
       color="#1A1A2EE0" active="false">
    <Text id="turnText" text="" fontSize="18" color="#FFFFFF"
          alignment="MiddleCenter"/>
</Panel>

<!-- Setup Panel (shown before game starts) -->
<Panel id="setupPanel" position="0 0 0" width="400" height="250"
       color="#2A1A0AE0" active="true">
    <Text text="BRASS: BIRMINGHAM" fontSize="24" color="#D4C5A0"
          alignment="UpperCenter" offsetXY="0 -20"/>
    <Text text="Select Players" fontSize="16" color="#A89870"
          alignment="MiddleCenter" offsetXY="0 -10"/>
    <HorizontalLayout spacing="20" offsetXY="0 30">
        <Button id="setup2p" text="2 Players" onClick="onSetup2P"
                width="100" height="40" fontSize="14" color="#D4C5A0"/>
        <Button id="setup3p" text="3 Players" onClick="onSetup3P"
                width="100" height="40" fontSize="14" color="#D4C5A0"/>
        <Button id="setup4p" text="4 Players" onClick="onSetup4P"
                width="100" height="40" fontSize="14" color="#D4C5A0"/>
    </HorizontalLayout>
</Panel>

<!-- Language Toggle Button -->
<Button id="langToggle" text="EN / 中文" onClick="toggleLanguage"
        position="-600 -350 0" width="80" height="30" fontSize="12"
        color="#8B7355" textColor="#D4C5A0"/>
```

**tts/UIManager.lua:**
```lua
local UIManager = {}

-- Update a player's spend counter display
function UIManager.updateSpendCounter(color, amount)
    UI.setAttribute("counterValue_" .. color, "text", "£" .. amount)
end

-- Show/hide the turn indicator
function UIManager.showTurnIndicator(text)
    UI.setAttribute("turnPanel", "active", "true")
    UI.setAttribute("turnText", "text", text)
end

function UIManager.hideTurnIndicator()
    UI.setAttribute("turnPanel", "active", "false")
end

-- Show/hide setup panel
function UIManager.showSetup()
    UI.setAttribute("setupPanel", "active", "true")
end

function UIManager.hideSetup()
    UI.setAttribute("setupPanel", "active", "false")
end

-- Update all counters to zero (new round)
function UIManager.resetAllCounters(turnOrder)
    for _, color in ipairs(turnOrder) do
        UIManager.updateSpendCounter(color, 0)
    end
end

-- Update counter positions based on player count
-- Hide unused player counters
function UIManager.configureForPlayerCount(playerCount)
    local allColors = { "Red", "Blue", "Yellow", "Green" }
    for i, color in ipairs(allColors) do
        local active = i <= playerCount
        UI.setAttribute("counterPanel_" .. color, "active", tostring(active))
    end
end

-- Update language on all UI elements
function UIManager.updateLanguage(lang)
    -- Update counter labels
    local label = (lang == "zh-TW") and "本回合花費" or "Spent this round"
    local auto = (lang == "zh-TW") and "自動追蹤" or "Auto-tracked"
    for _, color in ipairs(Constants.ALL_COLORS) do
        UI.setAttribute("counterLabel_" .. color, "text", label)
        UI.setAttribute("counterAuto_" .. color, "text", auto)
    end
end

return UIManager
```

**Key details:**
- TTS XML UI is defined in a separate XML string/file, loaded via `UI.setXml()` or embedded in save
- `UI.setAttribute()` updates UI elements at runtime
- Counters positioned at the four corners near player areas
- Setup panel shown on load, hidden after game starts
- ~150 lines total (XML + Lua)

- [ ] Create `xml/UI.xml`
- [ ] Create `tts/UIManager.lua`
- [ ] Commit

---

### Task 6: EventHandlers — TTS Event Callbacks

**Files:**
- Create: `tts/EventHandlers.lua`

**Description:**
Handles all TTS object events and routes them to the appropriate game logic. This is the core bridge between physical TTS interactions and the game engine.

**API:**
```lua
local EventHandlers = {}

-- Called when any object is dropped on the table
function EventHandlers.onObjectDrop(playerColor, droppedObject)
    if not state then return end

    -- Determine what was dropped
    local objType = EventHandlers.identifyObject(droppedObject)

    if objType == "card" then
        EventHandlers.handleCardDrop(playerColor, droppedObject)
    elseif objType == "building_tile" then
        EventHandlers.handleBuildingDrop(playerColor, droppedObject)
    elseif objType == "link_tile" then
        EventHandlers.handleLinkDrop(playerColor, droppedObject)
    end
end

-- Identify what type of game object this is
function EventHandlers.identifyObject(obj)
    local name = obj.getName()
    local desc = obj.getDescription()
    -- Parse object name/description/tags to determine type
    -- Returns: "card", "building_tile", "link_tile", "resource", "money", or nil
end

-- Handle card dropped into discard zone
function EventHandlers.handleCardDrop(playerColor, cardObj)
    -- Check if card landed in discard zone
    -- If so, parse card type and trigger action selection
    local cardInfo = CardManager.onCardPlayed(cardObj)
    if cardInfo then
        -- Store pending action context
        state._pendingCard = cardInfo
        state._pendingPlayer = playerColor

        -- Show valid actions based on card type
        -- For location card → highlight valid build spots
        -- For industry card → highlight valid build spots in network
        -- Player's next drop determines the action
        Highlights.showValidBuildSpots(state, playerColor, cardInfo)
    end
end

-- Handle building tile dropped on the board
function EventHandlers.handleBuildingDrop(playerColor, tileObj)
    if not state._pendingCard then return end

    -- Find which snap point the tile landed on
    local pos = tileObj.getPosition()
    local snapInfo = SnapMap.findNearestPosition(pos, 2.0)

    if snapInfo and snapInfo.type == "slot" then
        -- Attempt to build
        local result = Actions.build(state, playerColor, {
            cardType = state._pendingCard.cardType,
            location = GameState.getCityForSlot(state, snapInfo.id),
            industryType = state._pendingCard.industryType or tileObj.getVar("industryType"),
            level = tileObj.getVar("level"),
            slotId = snapInfo.id,
        })

        if result.success then
            Highlights.clearAll()
            state._pendingCard = nil
            -- Snap tile to exact position
            ObjectManager.moveTo(tileObj, SnapMap.getPositionForSlot(snapInfo.id))
            -- Spawn resources if needed
            spawnTileResources(state, snapInfo.id)
            afterAction(playerColor)
        else
            -- Invalid placement: bounce back
            printToColor(result.error, playerColor, {1, 0, 0})
            -- Return tile to player area
            returnToPlayerArea(tileObj, playerColor)
        end
    else
        returnToPlayerArea(tileObj, playerColor)
    end
end

-- Handle link tile dropped on the board
function EventHandlers.handleLinkDrop(playerColor, linkObj)
    if not state._pendingCard then return end

    local pos = linkObj.getPosition()
    local snapInfo = SnapMap.findNearestPosition(pos, 2.0)

    if snapInfo and snapInfo.type == "link" then
        local result = Actions.network(state, playerColor, {
            linkId = snapInfo.id,
        })

        if result.success then
            Highlights.clearAll()
            state._pendingCard = nil
            ObjectManager.moveTo(linkObj, SnapMap.getPositionForLink(snapInfo.id))
            afterAction(playerColor)
        else
            printToColor(result.error, playerColor, {1, 0, 0})
            returnToPlayerArea(linkObj, playerColor)
        end
    else
        returnToPlayerArea(linkObj, playerColor)
    end
end

-- Spawn resource tokens on a newly built tile
function spawnTileResources(state, slotId)
    local slot = GameState.getSlot(state, slotId)
    if slot and slot.tile and slot.tile.resources then
        local pos = SnapMap.getPositionForSlot(slotId)
        for i, resType in ipairs(slot.tile.resources) do
            local offset = {x = 0, y = 0.5 * i, z = 0}
            ObjectManager.spawnResource(resType, {
                x = pos.x + offset.x,
                y = pos.y + offset.y,
                z = pos.z + offset.z,
            })
        end
    end
end

-- Return an object to its owner's player area
function returnToPlayerArea(obj, playerColor)
    local boardGUID = ObjectManager.guids.playerBoards[playerColor]
    if boardGUID then
        local board = getObjectFromGUID(boardGUID)
        if board then
            obj.setPositionSmooth(board.getPosition() + Vector(0, 2, 0))
        end
    end
end

return EventHandlers
```

**Key details:**
- `onObjectDrop` is the primary TTS callback for physical interactions
- Objects are identified by their Name/Description/Tags
- The flow: play card → show highlights → drop tile on highlighted spot → execute action
- Invalid placements bounce the object back to the player area
- `state._pendingCard` tracks the action context between card play and tile placement
- ~200-250 lines

- [ ] Create `tts/EventHandlers.lua`
- [ ] Commit

---

### Task 7: Update Global.lua — Wire Everything Together

**Files:**
- Modify: `tts/Global.lua`

**Description:**
Update the existing Global.lua to `#include` all Phase 2 modules and wire up TTS callbacks to EventHandlers.

**Changes:**
1. Add `#include` for all new tts/ modules
2. Replace the placeholder action handlers with EventHandlers delegation
3. Wire `onObjectDrop` TTS callback to `EventHandlers.onObjectDrop`
4. Wire setup buttons to `setupGame` with UIManager
5. Wire `onLoad` to scan objects and build SnapMap
6. Update `afterAction` to use UIManager for counter updates
7. Add `onObjectPickUp` callback (cancel pending action if player picks up their card)

```lua
-- Updated TTS callbacks
function onObjectDrop(playerColor, droppedObject)
    EventHandlers.onObjectDrop(playerColor, droppedObject)
end

function onObjectPickUp(playerColor, pickedUpObject)
    -- Cancel pending action if player picks up something
    if state and state._pendingCard then
        Highlights.clearAll()
        state._pendingCard = nil
    end
end

-- Setup button callbacks
function onSetup2P() startGame(2) end
function onSetup3P() startGame(3) end
function onSetup4P() startGame(4) end

function startGame(playerCount)
    UIManager.hideSetup()
    state = GameState.new(playerCount)

    -- Scan table objects
    ObjectManager.scanTable()

    -- Build snap point mappings
    local board = ObjectManager.getObject("mainBoard")
    if board then SnapMap.buildFromObject(board) end

    -- Setup cards
    local deck = ObjectManager.getObject("drawDeck")
    if deck then
        CardManager.buildDeck(state, deck)
        CardManager.dealToAll(state)
    end

    -- Configure UI
    UIManager.configureForPlayerCount(playerCount)
    UIManager.resetAllCounters(state.turnOrder)
    UIManager.showTurnIndicator(Lang.format("your_turn", state.lang, {
        player = GameState.getCurrentPlayerColor(state)
    }))

    printToAll(Lang.format("game_started", state.lang, { count = playerCount }))
end

-- Updated afterAction
function afterAction(color)
    local p = GameState.getPlayer(state, color)
    UIManager.updateSpendCounter(color, p.spentThisRound)

    if EraTransition.isEraOver(state) then
        if state.era == Constants.Era.CANAL then
            printToAll(Lang.get("era_transition", state.lang))
            EraTransition.transition(state)
            CardManager.rebuildDeckForRailEra(state)
            CardManager.dealToAll(state)
            UIManager.resetAllCounters(state.turnOrder)
        else
            Scoring.scoreEndOfEra(state, true)
            local ranking = Scoring.determineWinner(state)
            announceResults(ranking)
            return
        end
    end

    TurnManager.endAction(state)

    local nextColor = GameState.getCurrentPlayerColor(state)
    UIManager.showTurnIndicator(Lang.format("your_turn", state.lang, { player = nextColor }))
end
```

- [ ] Update `tts/Global.lua`
- [ ] Commit

---

## Next Phase

After Phase 2 is complete, proceed to:
- **Phase 3: Assets** — create image textures, 3D models, card images, PDF rulebooks, and assemble the final TTS save file (.json)
