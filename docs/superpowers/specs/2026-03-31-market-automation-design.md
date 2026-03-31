# Market Automation Design

## Overview

Automate coal/iron resource consumption during building placement in the Brass: Birmingham TTS mod. The system manages all coal/iron cube objects (locked, non-interactable), handles board-to-market flow with smooth movement animations, and validates build affordability including dynamic market pricing.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Multiple equidistant coal/iron sources | Player chooses via highlight | Preserves strategic agency |
| Market purchase when board insufficient | Auto-buy, no confirmation | Streamlines flow; cost shown in announcement |
| Iron source selection (multiple) | Player chooses via highlight | Consistent with coal behavior |
| Coal/iron mine auto-sell on build | Fully automatic | Rule mandates: empty market slots **must** be filled |
| Resource selection UI | Highlight candidates on board | Reuses existing Highlights module |
| Implementation approach | Phased interactive flow | Matches physical board game rhythm |
| Game initialization | Deprecate crown buttons, unified startGame | All automation requires `state`; no partial/lite mode |

## 1. System-Managed Coal/Iron Cubes

All coal/iron cube TTS objects are exclusively controlled by the system.

**Object properties:**
- `setLock(true)` — cannot be dragged
- `interactable = false` — cannot be selected/hovered
- GMNotes: `{"type":"resource","resource":"coal"}` or `"iron"`

**GUID tracking:**

```lua
-- On building tiles
slot.resourceGUIDs = { "abc123", "def456" }

-- Market tracks (index 1 = cheapest slot, index N = most expensive)
state.coalMarket.cubeGUIDs = { "g1", "g2", ..., "g13" }  -- max 13
state.ironMarket.cubeGUIDs = { "g1", "g2", ..., "g8" }   -- max 8
```

**Movement protocol:** `setLock(false)` -> `setPositionSmooth` -> on arrival `setLock(true)`. For consumed cubes: move to build site -> `destruct()`.

## 2. Build Resource Consumption Flow

When a player drops a building tile:

### Step 1: Pre-validation

Check all conditions before committing any state changes:

1. **Money:** `player.money >= baseMoney + coalMarketCost + ironMarketCost`
   - `coalMarketCost` and `ironMarketCost` are only for the **shortfall** (board sources insufficient), not the full requirement
2. **Coal availability:** connected board coal + market supply >= coal needed
3. **Iron availability:** all board iron + market supply >= iron needed
4. **Coal market access:** if coal must be bought from market, player must have a path to a merchant city (`Network.hasMarketConnection`)
5. **Any failure:** return tile to player area + display reason. Flow ends.

### Step 2: Deduct money

Immediately update game state and physical counters:
- `totalCost = baseMoney + coalMarketCost + ironMarketCost`
- Update money counter + spend tracker
- State updates are instant; animations are purely visual.

### Step 3: Consume iron (before coal — simpler, no connectivity)

- Board iron sources == 0: all from market, skip to market purchase
- Board iron sources == 1: auto-consume, no player interaction
- Board iron sources >= 2: highlight all iron works with available cubes, enter `_pendingResource` wait state
  - Player clicks a highlighted iron works -> consume from that source
  - If more iron still needed, re-highlight remaining candidates
  - Repeat until iron satisfied
- Shortfall after board consumption: auto-purchase from market

### Step 4: Consume coal (requires BFS connectivity)

Same flow as iron, but candidates limited to BFS-connected coal mines from the build city.

- Board coal sources == 0: all from market (requires merchant connection)
- Board coal sources == 1: auto-consume
- Board coal sources >= 2: highlight connected coal mines, player clicks to choose
- Shortfall: auto-purchase from market

### Step 5: Animate

Queue all resource movements and play sequentially (0.4s intervals):

| Scenario | Origin | Destination | Destroy after? |
|----------|--------|-------------|---------------|
| Board consume -> market return | tile on coal/iron mine | market track empty slot | No |
| Market purchase -> consumed | market track | build site above | Yes |
| Auto-sell on build | spawn at build site | market track empty slot | No |

### Step 6: Post-animation

- Announce cost breakdown
- Unlock next player action

### Pending state structure

```lua
state._pendingResource = {
    playerColor = "White",
    buildSlotId = "Birmingham_1",
    ironNeeded = 1,           -- remaining iron to consume
    coalNeeded = 2,           -- remaining coal to consume
    phase = "iron",           -- "iron" -> "coal" -> "done"
    candidates = {            -- currently highlighted candidate slots
        { slotId = "Coalbrookdale_1", cityName = "Coalbrookdale", cubesAvailable = 2 },
        { slotId = "Dudley_2",        cityName = "Dudley",        cubesAvailable = 1 },
    },
    moves = { },              -- accumulated animation instructions
}
```

**Candidate click behavior:** When a player clicks a highlighted source, one cube is consumed from that source. If the source still has cubes AND more resources are needed, it remains highlighted alongside other candidates. The player may take multiple cubes from the same source.

### Auto-flip on board consumption

When consuming a cube causes a coal mine or iron works to reach 0 resources:
- **State:** auto-flip immediately (set `tile.flipped = true`, advance income)
- **Visual:** flip animation is queued into `moves` and plays during the animation phase (Step 5), not immediately on click

## 3. Coal/Iron Mine Auto-Sell on Build

Triggered after all resource consumption completes for a coal mine or iron works build.

**Rules:** When building a coal mine or iron works, produced resource cubes **must** fill empty market slots. This is mandatory, not optional.

**Flow:**

1. Calculate: `sellCount = min(tile.produces, marketMax - market.supply)`
2. Calculate: `keepCount = tile.produces - sellCount`
3. **Sold cubes (mandatory):**
   - Spawn directly to market track positions (lowest empty slot first)
   - Add GUIDs to `market.cubeGUIDs`
   - `market.supply += sellCount`
   - Builder gains `$1 x sellCount`
4. **Remaining cubes:**
   - Spawn on tile, locked + non-interactable
   - Add GUIDs to `slot.resourceGUIDs`
5. **If keepCount == 0** (all sold):
   - Tile resources empty -> auto-flip
   - Flip animation (`obj.flip()`)
   - Advance income track

**Animation order:** resource consumption animations -> auto-sell animations -> flip animation. Player sees the complete narrative: "spend resources to build -> cubes fly to market -> tile flips for income."

## 4. Money Validation: Market.estimateCost

Simulates sequential market purchases without modifying state. Each purchase reduces simulated supply, increasing the next unit's price.

```lua
function Market.estimateCost(state, resourceType, count)
    if count <= 0 then return 0 end
    local market = Market.getMarketSupply(state, resourceType)
    local track = Market.getTrack(resourceType)
    local trackLen = #track
    local simSupply = market.supply  -- read-only simulation
    local total = 0

    for i = 1, count do
        if simSupply <= 0 then
            total = total + Market.getMaxPrice(resourceType)
        else
            local pos = trackLen - simSupply + 1
            total = total + track[pos]
            simSupply = simSupply - 1
        end
    end
    return total
end
```

## 5. Animation System

```lua
local MOVE_INTERVAL = 0.4
local MOVE_DURATION = 0.6
local ARRIVE_BUFFER = 0.1

function animateResourceFlow(moves, onComplete)
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
            end, MOVE_DURATION)
        end, (i - 1) * MOVE_INTERVAL)
    end

    if onComplete then
        local totalTime = (#moves - 1) * MOVE_INTERVAL + MOVE_DURATION + ARRIVE_BUFFER
        Wait.time(onComplete, math.max(totalTime, 0.1))
    end
end
```

**Operation lock:** Set `state._animating = true` during animation playback. `onObjectDrop` ignores player input while animating. Reset to false in `onComplete`.

## 6. Game Initialization: Crown Button Callback

Reuse the original mod's crown setup buttons. They keep their existing physical setup logic; we append a callback at the end to initialize game state.

### 6.1 Crown Buttons (Retained)

| GUID | Label | Purpose |
|------|-------|---------|
| `5f8b97` | 2-player setup | Physical setup for 2P |
| `9c5d5e` | 3-player setup | Physical setup for 3P |
| `3ba14f` | 4-player setup | Physical setup for 4P |
| `f714a5` | AI/Mautoma | Disable (out of scope) |

Crown buttons retain their existing LuaScript which handles:
1. Mutual exclusion (lock other buttons)
2. Shuffle market tile deck (from zone `319330`, deck GUID `880aa5`)
3. Select and shuffle the correct pre-built card deck (2P=`b6ff44`, 3P=`3895fe`, 4P=`bc3ba4`)
4. Move card deck to board snap point (tagged `["Deck"]`)
5. Place merchant tiles on snap points (tag-filtered by player count: M2/M3/M4)
6. Place beer barrels from infinite bag `4be839` (tag-filtered: B2/B3/B4)

### 6.2 Callback Injection

In `inject_scripts.py`, append one line to each crown button's LuaScript coroutine, after the physical setup completes:

```lua
Global.call('onPhysicalSetupComplete', {playerCount = 2})  -- (or 3, or 4)
```

Also in `inject_scripts.py`:
- Rename crown button labels to bilingual text (e.g. "2 Players / 2人遊戲")
- Disable the AI/Mautoma button (`f714a5`): clear LuaScript, set `Locked = true`

### 6.3 onPhysicalSetupComplete (Global.lua)

Called by crown button after physical setup is done. Handles everything the crowns don't:

```lua
function onPhysicalSetupComplete(params)
    local playerCount = params.playerCount

    -- 1. Initialize game state
    state = GameState.new(playerCount)

    -- 2. Adapt CardManager to use the pre-built deck already on the board
    --    (crown already shuffled and placed it; we just deal from it)
    local deck = CardManager.findDeckOnBoard()
    CardManager.dealFromDeck(state, deck)  -- deal 8 cards to each player

    -- 3. Hide unused pre-built decks (the 2 not selected by crown)
    hideUnusedDecks(playerCount)

    -- 4. Set money counters to $17, reset spend trackers to 0
    for _, color in ipairs(state.turnOrder) do
        setMoneyCounter(color, Constants.INITIAL_MONEY)
        setSpendCounter(color, 0)
    end

    -- 5. Spawn market coal/iron cubes (locked, non-interactable)
    spawnMarketCubes(state)

    -- 6. Income phase for first round
    TurnManager.incomePhase(state)

    -- 7. Configure UI
    UIManager.hideSetup()
    UIManager.configureForPlayerCount(playerCount)
    UIManager.showEndTurnButton()
    broadcastCurrentPlayer()

    printToAll(Lang.format("game_started", state.lang, { count = playerCount }))
end
```

### 6.4 CardManager Adaptation

Current `CardManager.buildDeck` dynamically removes city cards from one master deck. This conflicts with the crown approach (3 pre-built decks with correct cards already removed).

**Change:** Remove `CardManager.buildDeck` and `CardManager.rebuildDeckForRailEra`. Replace with:
- `CardManager.findDeckOnBoard()` — find the deck at the board snap point (placed by crown)
- `CardManager.dealFromDeck(state, deck)` — deal 8 cards to each seated player
- `CardManager.refillHand(state, color)` — draw cards to refill hand (existing, keep)

### 6.5 No State = No Game

Without `state`, `onObjectDrop` ignores all tile placements. No fallback, no partial functionality.

```lua
function EventHandlers.onObjectDrop(playerColor, droppedObject)
    if not state then return end  -- hard gate
    ...
end
```

## 7. Market Track Position Mapping

Physical TTS coordinates for each market track slot, stored in a `MarketLayout` module or within `SnapMap`.

```lua
MarketLayout = {
    coal = {
        [1]  = Vector(...),  -- $1 slot
        ...
        [13] = Vector(...),  -- $8 slot (most expensive)
    },
    iron = {
        [1]  = Vector(...),  -- $1 slot
        ...
        [8]  = Vector(...),  -- $6 slot
    },
}
```

Exact coordinates to be measured from the reference mod's save JSON or via TTS scripting console during implementation.

## Files Affected

| File | Changes |
|------|---------|
| `src/Market.lua` | Add `estimateCost()` |
| `tts/EventHandlers.lua` | Rewrite `handleTilePlaced` + `deductTileCost` for full resource flow; hard gate on `state` |
| `tts/Global.lua` | Replace `startGame` with `onPhysicalSetupComplete` callback; add `_pendingResource` handling; animation lock; remove DEBUG prints |
| `tts/Highlights.lua` | Add `showResourceCandidates()` for coal/iron source highlighting |
| `tts/ResourceAnimation.lua` | New module: `animateResourceFlow()`, market sync helpers |
| `tts/MarketLayout.lua` | New module: market track position mapping |
| `src/Actions.lua` | Add auto-sell step to `Actions.build` for coal/iron mines |
| `tts/CardManager.lua` | Replace `buildDeck`/`rebuildDeckForRailEra` with `findDeckOnBoard`/`dealFromDeck` to work with crown's pre-built decks |
| `scripts/inject_scripts.py` | Append callback to crown button scripts; disable AI button; lock/tag coal/iron cube objects; rename crown labels; add `#include` for new modules |
