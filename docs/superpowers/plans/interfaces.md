# Market Automation — Interface Contracts

All subagents must read this before starting their task.

## Shared Constants

```lua
-- Animation timing
MOVE_INTERVAL = 0.4   -- seconds between each cube animation start
MOVE_DURATION = 0.6   -- seconds for setPositionSmooth travel
ARRIVE_BUFFER = 0.1   -- seconds after last cube arrives

-- Track capacities (derived from BoardData, NOT hardcoded)
-- Coal: #BoardData.coalMarketTrack = 14 slots
-- Iron: #BoardData.ironMarketTrack = 10 slots
-- Use #Market.getTrack(resourceType) to get capacity at runtime

-- Initial supply (different from track capacity!)
-- Constants.INITIAL_COAL_SUPPLY = 13
-- Constants.INITIAL_IRON_SUPPLY = 8
```

## Resource Type Constants

Always use `Constants.Resource.COAL` / `Constants.Resource.IRON`, never raw strings `"coal"` / `"iron"`.

Phase constants (add to Constants.lua if needed):
```lua
Constants.ResourcePhase = {
    IRON    = "iron",
    COAL    = "coal",
    ANIMATE = "animate",
    DONE    = "done",
}
```

## Data Structures

### state._pendingResource

Set when a build requires player choice for resource sources. Cleared when all resources are consumed or build is cancelled.

```lua
{
    playerColor    = "White",
    buildSlotId    = "Birmingham_1",
    buildPos       = Vector,            -- TTS world position of build site
    meta           = {},                -- GMNotes metadata of placed tile
    ironNeeded     = 1,                 -- remaining iron to consume from BOARD
    coalNeeded     = 2,                 -- remaining coal to consume from BOARD
    ironFromMarket = 0,                 -- iron to buy from market (pre-calculated)
    coalFromMarket = 0,                 -- coal to buy from market (pre-calculated)
    totalSpent     = 0,                 -- actual money spent (for announcement)
    phase          = "iron",            -- "iron" | "coal" | "animate" | "done"
    candidates     = {                  -- currently highlighted source slots
        { slotId = string, cityName = string, cubesAvailable = number },
    },
    moves          = {                  -- accumulated animation instructions
        { guid = string, targetPos = Vector, destroyAfter = bool },
    },
    cachedCoalSources = {},             -- cached BFS results from pre-validation
    cachedIronSources = {},             -- cached findIronSources results
}
```

### state.coalMarket (extended)

```lua
{ supply = number, cubeGUIDs = { string, ... } }
-- cubeGUIDs[1] = cheapest filled slot, cubeGUIDs[N] = most expensive filled slot
-- Length = supply (only filled slots have GUIDs)
```

### state.ironMarket (extended)

Same structure as coalMarket.

### slot (extended)

```lua
{ id, type, occupant, tile, resourceGUIDs = { string, ... } }
-- resourceGUIDs parallel to slot.tile.resources (same length, same order)
-- Only present on slots with coal/iron mine tiles that have cubes
```

## Function Signatures

### MarketLayout (new: tts/MarketLayout.lua)

```lua
MarketLayout.getPosition(resourceType, index) -> Vector
  -- resourceType: Constants.Resource.COAL or Constants.Resource.IRON
  -- index: 1-based position (1 = cheapest slot)
  -- Returns TTS world position

MarketLayout.getTrackMax(resourceType) -> number
  -- Returns #Market.getTrack(resourceType)
  -- coal=14, iron=10
```

### ResourceAnimation (new: tts/ResourceAnimation.lua)

```lua
ResourceAnimation.play(moves, onComplete)
  -- moves: array of { guid=string, targetPos=Vector, destroyAfter=bool }
  -- onComplete: function() called after all done
  -- Sets state._animating = true at start, false in onComplete

ResourceAnimation.spawnCube(resourceType, position, onSpawned)
  -- Spawns locked, non-interactable cube with GMNotes
  -- onSpawned: function(obj) callback

ResourceAnimation.spawnAndMoveCube(resourceType, fromPos, toPos, onArrived)
  -- Spawn at fromPos, smooth-move to toPos, lock on arrival
  -- onArrived: function(obj) callback
```

### Market (extended: src/Market.lua)

```lua
Market.estimateCost(state, resourceType, count) -> number
  -- Simulates buying count units without modifying state
  -- Returns total cost using current supply for pricing
```

### Highlights (extended: tts/Highlights.lua)

```lua
Highlights.showResourceCandidates(candidates, resourceType, onClickCallback)
  -- candidates: array of { slotId, cityName, cubesAvailable }
  -- resourceType: Constants.Resource.COAL or IRON
  -- onClickCallback: function(slotId) on player click

Highlights.clearResourceCandidates()
  -- Clears resource highlights only

Highlights.clearAll()
  -- MUST also call clearResourceCandidates() (errata fix #7)
```

### CardManager (modified: tts/CardManager.lua)

```lua
CardManager.findDeckOnBoard() -> TTS object | nil
  -- Find card deck near known snap point position

CardManager.dealFromDeck(state, deckObj)
  -- Deal INITIAL_HAND_SIZE cards to each player
```

### Actions (extended: src/Actions.lua)

```lua
Actions.autoSellToMarket(state, color, slot) -> { sold=number, kept=number }
  -- Mandatory auto-sell for coal/iron mine builds
  -- MUST use Market.returnToMarket (not inline supply manipulation)
  -- MUST use autoFlipIfEmpty (not inline flip logic)
```

### EventHandlers (modified: tts/EventHandlers.lua)

```lua
EventHandlers.handleTilePlaced(playerColor, tileObj, meta)
  -- Full flow: Validation.canBuild -> affordability check -> resource phases -> animate -> auto-sell
  -- MUST call Validation.canBuild for full game-rule validation (errata fix #3)
  -- MUST deduct only baseMoney upfront; market costs via Market.buyFromMarket (errata fix #2)

EventHandlers.onResourceCandidateClicked(playerColor, slotId)
  -- Consume one cube from clicked source, advance phase

EventHandlers.cancelPendingResource()
  -- Cancel resource flow, clear highlights, return tile (errata fix #10)
```

### Global.lua (modified)

```lua
onPhysicalSetupComplete(params)
  -- params: { playerCount = number }
  -- Called by crown button after physical setup

onResourceMarkerClicked(obj, playerColor)
  -- Button callback routing to EventHandlers
```

## Critical Errata (must apply)

1. Track capacity: coal=14, iron=10 (NOT 13/8)
2. Money: only deduct baseMoney upfront; market costs deducted by Market.buyFromMarket
3. Must call Validation.canBuild before resource flow
4. _handleAutoSell must call Actions.autoSellToMarket, not duplicate logic
5. Store totalSpent during flow, don't re-estimate after
6. Cache BFS results in _pendingResource
7. clearAll must call clearResourceCandidates
8. Stagger auto-sell animations with MOVE_INTERVAL
9. Use Constants.Resource.* everywhere, not raw strings
10. Add cancelPendingResource() for cleanup
