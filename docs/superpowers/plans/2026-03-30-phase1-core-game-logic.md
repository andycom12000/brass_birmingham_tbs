# Phase 1: Core Game Logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Brass: Birmingham game logic as standalone Lua modules, testable outside TTS with `busted` test framework.

**Architecture:** All game logic lives in pure Lua modules under `src/`. Each module depends only on `GameState` and other `src/` modules — no TTS API calls. A separate `tts/` layer (Phase 2) will wrap these modules with TTS bindings. This separation allows unit testing with `busted` and keeps logic portable.

**Tech Stack:** Lua 5.3, busted (Lua test framework), LuaRocks (package manager)

**Spec:** `docs/superpowers/specs/2026-03-30-brass-birmingham-tts-mod-design.md`

---

## File Structure

```
brass_birmingham_tbs/
├── src/
│   ├── GameState.lua        — Central game state, initialization, player data
│   ├── BoardData.lua        — Static board topology (cities, slots, links, merchants)
│   ├── Market.lua           — Coal/iron market pricing, resource consumption
│   ├── IncomeTrack.lua      — Income level ↔ space conversion, advance/decrease
│   ├── TurnManager.lua      — Turn order, round flow, spending tracker, income phase
│   ├── Validation.lua       — Legal move checking for all 6 actions
│   ├── Actions.lua          — Execute actions (Build/Network/Develop/Sell/Loan/Scout)
│   ├── Scoring.lua          — End-of-era scoring (building VP + link VP + income VP)
│   ├── EraTransition.lua    — Canal→Rail transition logic
│   ├── Lang.lua             — i18n string table (en / zh-TW)
│   └── helpers.lua          — Shared utilities (deep copy, table find, etc.)
├── spec/
│   ├── GameState_spec.lua
│   ├── BoardData_spec.lua
│   ├── Market_spec.lua
│   ├── IncomeTrack_spec.lua
│   ├── TurnManager_spec.lua
│   ├── Validation_spec.lua
│   ├── Actions_spec.lua
│   ├── Scoring_spec.lua
│   └── EraTransition_spec.lua
├── .busted                  — busted config
└── docs/
```

---

### Task 1: Project Setup & Test Framework

**Files:**
- Create: `.busted`
- Create: `src/helpers.lua`
- Create: `spec/helpers_spec.lua`

- [ ] **Step 1: Initialize project and install busted**

```bash
cd C:/Users/andyc/Projects/brass_birmingham_tbs
# Install busted globally (assumes LuaRocks installed)
luarocks install busted
```

- [ ] **Step 2: Create busted config**

Create `.busted`:
```lua
return {
    default = {
        ROOT = {"spec/"},
        pattern = "_spec",
        lua = "lua",
    }
}
```

- [ ] **Step 3: Write helpers test**

Create `spec/helpers_spec.lua`:
```lua
package.path = package.path .. ";src/?.lua"
local helpers = require("helpers")

describe("helpers", function()
    describe("deepCopy", function()
        it("copies a nested table without reference sharing", function()
            local original = { a = 1, b = { c = 2 } }
            local copy = helpers.deepCopy(original)
            copy.b.c = 99
            assert.are.equal(2, original.b.c)
            assert.are.equal(99, copy.b.c)
        end)
    end)

    describe("tableFind", function()
        it("finds element matching predicate", function()
            local t = { { id = "a" }, { id = "b" }, { id = "c" } }
            local found = helpers.tableFind(t, function(el) return el.id == "b" end)
            assert.are.equal("b", found.id)
        end)

        it("returns nil when not found", function()
            local t = { { id = "a" } }
            local found = helpers.tableFind(t, function(el) return el.id == "z" end)
            assert.is_nil(found)
        end)
    end)

    describe("tableFilter", function()
        it("returns elements matching predicate", function()
            local t = { 1, 2, 3, 4, 5 }
            local result = helpers.tableFilter(t, function(v) return v > 3 end)
            assert.are.same({ 4, 5 }, result)
        end)
    end)
end)
```

- [ ] **Step 4: Run test to verify it fails**

Run: `busted spec/helpers_spec.lua`
Expected: FAIL — `helpers` module not found

- [ ] **Step 5: Implement helpers**

Create `src/helpers.lua`:
```lua
local helpers = {}

function helpers.deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[helpers.deepCopy(k)] = helpers.deepCopy(v)
    end
    return setmetatable(copy, getmetatable(orig))
end

function helpers.tableFind(t, predicate)
    for _, v in ipairs(t) do
        if predicate(v) then return v end
    end
    return nil
end

function helpers.tableFilter(t, predicate)
    local result = {}
    for _, v in ipairs(t) do
        if predicate(v) then result[#result + 1] = v end
    end
    return result
end

function helpers.tableMap(t, fn)
    local result = {}
    for i, v in ipairs(t) do
        result[i] = fn(v, i)
    end
    return result
end

function helpers.shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

return helpers
```

- [ ] **Step 6: Run test to verify it passes**

Run: `busted spec/helpers_spec.lua`
Expected: 4 successes, 0 failures

- [ ] **Step 7: Commit**

```bash
git add .busted src/helpers.lua spec/helpers_spec.lua
git commit -m "feat: project setup with busted test framework and helpers module"
```

---

### Task 2: BoardData — Static Board Topology

**Files:**
- Create: `src/BoardData.lua`
- Create: `spec/BoardData_spec.lua`

- [ ] **Step 1: Write BoardData tests**

Create `spec/BoardData_spec.lua`:
```lua
package.path = package.path .. ";src/?.lua"
local BoardData = require("BoardData")

describe("BoardData", function()
    describe("cities", function()
        it("contains Birmingham with correct slots", function()
            local city = BoardData.cities["Birmingham"]
            assert.is_not_nil(city)
            assert.is_true(#city.slots > 0)
        end)

        it("each slot has type and id", function()
            for name, city in pairs(BoardData.cities) do
                for i, slot in ipairs(city.slots) do
                    assert.is_not_nil(slot.type, name .. " slot " .. i .. " missing type")
                    assert.is_not_nil(slot.id, name .. " slot " .. i .. " missing id")
                end
            end
        end)
    end)

    describe("links", function()
        it("Birmingham-Coventry exists", function()
            local link = BoardData.links["Birmingham-Coventry"]
            assert.is_not_nil(link)
            assert.are.same({ "Birmingham", "Coventry" }, link.cities)
        end)

        it("each link has two cities and types", function()
            for id, link in pairs(BoardData.links) do
                assert.are.equal(2, #link.cities, id .. " should connect 2 cities")
                assert.is_not_nil(link.types, id .. " missing types")
            end
        end)
    end)

    describe("merchants", function()
        it("has 5 merchant locations", function()
            assert.are.equal(5, #BoardData.merchants)
        end)

        it("Shrewsbury has 1 slot and correct bonus", function()
            local shrewsbury = nil
            for _, m in ipairs(BoardData.merchants) do
                if m.name == "Shrewsbury" then shrewsbury = m; break end
            end
            assert.is_not_nil(shrewsbury)
            assert.are.equal(1, shrewsbury.slots)
            assert.are.equal("vp", shrewsbury.bonus.type)
            assert.are.equal(4, shrewsbury.bonus.value)
        end)
    end)

    describe("player count adjustments", function()
        it("returns removed cities for 2 players", function()
            local removed = BoardData.getRemovedCities(2)
            assert.is_true(#removed > 0)
            -- Teal + Blue cities
            local hasbelper = false
            local hasleek = false
            for _, c in ipairs(removed) do
                if c == "Belper" then hasbelper = true end
                if c == "Leek" then hasleek = true end
            end
            assert.is_true(hasbelper)
            assert.is_true(hasleek)
        end)

        it("returns removed cities for 3 players (teal only)", function()
            local removed = BoardData.getRemovedCities(3)
            local hasbelper = false
            local hasleek = false
            for _, c in ipairs(removed) do
                if c == "Belper" then hasbelper = true end
                if c == "Leek" then hasleek = true end
            end
            assert.is_true(hasbelper)
            assert.is_false(hasleek) -- Leek is blue, not removed for 3p
        end)

        it("returns empty for 4 players", function()
            local removed = BoardData.getRemovedCities(4)
            assert.are.equal(0, #removed)
        end)
    end)

    describe("building costs", function()
        it("Cotton Lv1 costs £12, 0 coal, 0 iron", function()
            local cost = BoardData.buildingCosts["cotton"][1]
            assert.are.equal(12, cost.money)
            assert.are.equal(0, cost.coal)
            assert.are.equal(0, cost.iron)
        end)

        it("Iron Lv1 produces 4 iron", function()
            local cost = BoardData.buildingCosts["iron"][1]
            assert.are.equal(4, cost.produces)
        end)

        it("Brewery Lv4 is rail-only", function()
            local cost = BoardData.buildingCosts["brewery"][4]
            assert.is_true(cost.railOnly)
        end)

        it("Pottery Lv1 cannot be developed", function()
            local cost = BoardData.buildingCosts["pottery"][1]
            assert.is_true(cost.noDevelop)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/BoardData_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement BoardData**

Create `src/BoardData.lua` — contains all static board data:
- `cities` table: all cities with their industry slots (type + id)
- `links` table: all routes with connected cities and allowed types (canal/rail/both)
- `merchants` table: 5 merchants with name, slots count, min players, bonus
- `buildingCosts` table: full cost/output/VP data per industry per level
- `tileCount` table: how many tiles per industry per level per player
- `getRemovedCities(playerCount)`: returns list of cities removed for that player count
- `getActiveMerchants(playerCount)`: returns active merchants for that player count
- `coalMarketTrack`: `{1,1,2,2,3,3,4,4,5,5,6,7,8,8}` — 14 spaces
- `ironMarketTrack`: `{1,1,2,2,3,3,4,5,6,6}` — 10 spaces

This file is large (~300 lines) but is pure static data with no logic beyond filtering. Complete city/slot/link data should be transcribed from the official board.

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/BoardData_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/BoardData.lua spec/BoardData_spec.lua
git commit -m "feat: add BoardData with complete board topology, costs, and player count rules"
```

---

### Task 3: IncomeTrack — Income Level/Space System

**Files:**
- Create: `src/IncomeTrack.lua`
- Create: `spec/IncomeTrack_spec.lua`

- [ ] **Step 1: Write IncomeTrack tests**

Create `spec/IncomeTrack_spec.lua`:
```lua
package.path = package.path .. ";src/?.lua"
local IncomeTrack = require("IncomeTrack")

describe("IncomeTrack", function()
    describe("levelToIncome", function()
        it("level 10 = £10 income", function()
            assert.are.equal(10, IncomeTrack.levelToIncome(10))
        end)

        it("level -3 = -£3 income", function()
            assert.are.equal(-3, IncomeTrack.levelToIncome(-3))
        end)
    end)

    describe("advanceSpaces", function()
        it("advancing 5 spaces from level 10 space 0 reaches correct position", function()
            local newLevel, newSpace = IncomeTrack.advanceSpaces(10, 0, 5)
            -- Level 10 has 2 spaces per level. 5 spaces = 2 levels + 1 space
            -- 10 -> (space 0 +5) = level 12, space 1
            assert.are.equal(12, newLevel)
            assert.are.equal(1, newSpace)
        end)

        it("caps at level 30", function()
            local newLevel, _ = IncomeTrack.advanceSpaces(29, 3, 20)
            assert.are.equal(30, newLevel)
        end)
    end)

    describe("decreaseLevels", function()
        it("decreasing 3 levels from level 10 lands on level 7 highest space", function()
            local newLevel, newSpace = IncomeTrack.decreaseLevels(10, 0, 3)
            assert.are.equal(7, newLevel)
            -- Level 7 has 2 spaces (levels 1-10 have 2 spaces each), highest = 1
            assert.are.equal(1, newSpace)
        end)

        it("cannot go below -10", function()
            local newLevel, newSpace = IncomeTrack.decreaseLevels(-8, 0, 5)
            assert.are.equal(-10, newLevel)
            assert.are.equal(0, newSpace)
        end)
    end)

    describe("canLoan", function()
        it("can loan at level 10", function()
            assert.is_true(IncomeTrack.canLoan(10))
        end)

        it("cannot loan if would go below -10", function()
            assert.is_false(IncomeTrack.canLoan(-8))
        end)

        it("can loan at exactly -7 (would land on -10)", function()
            assert.is_true(IncomeTrack.canLoan(-7))
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/IncomeTrack_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement IncomeTrack**

Create `src/IncomeTrack.lua`:
- `levelToIncome(level)` — returns £ amount (level = income)
- `spacesPerLevel(level)` — returns spaces count: 1 (lv -10~0), 2 (lv 1~10), 3 (lv 11~20), 4 (lv 21~30)
- `advanceSpaces(currentLevel, currentSpace, spaces)` — move forward N spaces, returns new level+space
- `decreaseLevels(currentLevel, currentSpace, levels)` — drop N levels, land on highest space in new level
- `canLoan(currentLevel)` — returns true if level - 3 >= -10

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/IncomeTrack_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/IncomeTrack.lua spec/IncomeTrack_spec.lua
git commit -m "feat: add IncomeTrack with space/level conversion and loan validation"
```

---

### Task 4: GameState — Central State Management

**Files:**
- Create: `src/GameState.lua`
- Create: `spec/GameState_spec.lua`

- [ ] **Step 1: Write GameState tests**

Create `spec/GameState_spec.lua`:
```lua
package.path = package.path .. ";src/?.lua"
local GameState = require("GameState")

describe("GameState", function()
    local state

    before_each(function()
        state = GameState.new(4) -- 4 players
    end)

    describe("new", function()
        it("initializes with canal era", function()
            assert.are.equal("canal", state.era)
        end)

        it("gives each player £17", function()
            for _, player in pairs(state.players) do
                assert.are.equal(17, player.money)
            end
        end)

        it("sets income level to 10", function()
            for _, player in pairs(state.players) do
                assert.are.equal(10, player.incomeLevel)
            end
        end)

        it("creates 4 players for 4p game", function()
            local count = 0
            for _ in pairs(state.players) do count = count + 1 end
            assert.are.equal(4, count)
        end)

        it("sets first round flag", function()
            assert.is_true(state.isFirstRound)
        end)

        it("initializes coal market at 13", function()
            assert.are.equal(13, state.coalMarket.supply)
        end)

        it("initializes iron market at 8", function()
            assert.are.equal(8, state.ironMarket.supply)
        end)

        it("initializes wild card supply at 4+4", function()
            assert.are.equal(4, state.wildSupply.location)
            assert.are.equal(4, state.wildSupply.industry)
        end)
    end)

    describe("2-player setup", function()
        it("creates 2 players", function()
            local state2 = GameState.new(2)
            local count = 0
            for _ in pairs(state2.players) do count = count + 1 end
            assert.are.equal(2, count)
        end)
    end)

    describe("getPlayer", function()
        it("returns player by color", function()
            local p = GameState.getPlayer(state, "Red")
            assert.is_not_nil(p)
            assert.are.equal(17, p.money)
        end)
    end)

    describe("spendMoney", function()
        it("deducts money and tracks spending", function()
            GameState.spendMoney(state, "Red", 5)
            local p = GameState.getPlayer(state, "Red")
            assert.are.equal(12, p.money)
            assert.are.equal(5, p.spentThisRound)
        end)

        it("accumulates spending across actions", function()
            GameState.spendMoney(state, "Red", 5)
            GameState.spendMoney(state, "Red", 3)
            local p = GameState.getPlayer(state, "Red")
            assert.are.equal(8, p.spentThisRound)
        end)
    end)

    describe("serialize / deserialize", function()
        it("round-trips state correctly", function()
            GameState.spendMoney(state, "Red", 10)
            local json = GameState.serialize(state)
            local restored = GameState.deserialize(json)
            local p = GameState.getPlayer(restored, "Red")
            assert.are.equal(7, p.money)
            assert.are.equal(10, p.spentThisRound)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/GameState_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement GameState**

Create `src/GameState.lua`:
- `GameState.new(playerCount)` — creates initial state with all fields from spec
- `GameState.getPlayer(state, color)` — returns player table
- `GameState.spendMoney(state, color, amount)` — deducts money, adds to spentThisRound
- `GameState.gainMoney(state, color, amount)` — adds money
- `GameState.resetRoundSpending(state)` — zeros all spentThisRound
- `GameState.serialize(state)` — converts to JSON string (using simple Lua JSON encoder)
- `GameState.deserialize(json)` — restores from JSON string
- Initializes board from `BoardData` based on playerCount

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/GameState_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/GameState.lua spec/GameState_spec.lua
git commit -m "feat: add GameState with initialization, money tracking, and serialization"
```

---

### Task 5: Market — Resource Pricing & Consumption

**Files:**
- Create: `src/Market.lua`
- Create: `spec/Market_spec.lua`

- [ ] **Step 1: Write Market tests**

Create `spec/Market_spec.lua`:
```lua
package.path = package.path .. ";src/?.lua"
local Market = require("Market")
local GameState = require("GameState")

describe("Market", function()
    local state

    before_each(function()
        state = GameState.new(4)
    end)

    describe("getCoalPrice", function()
        it("returns £1 at full supply (13)", function()
            assert.are.equal(1, Market.getCoalPrice(state))
        end)

        it("returns £8 when market is empty", function()
            state.coalMarket.supply = 0
            assert.are.equal(8, Market.getCoalPrice(state))
        end)
    end)

    describe("getIronPrice", function()
        it("returns £2 at supply 8", function()
            -- Track: 1,1,2,2,3,3,4,5,6,6 — 8 cubes fills spaces 3-10, cheapest visible = £2
            assert.are.equal(2, Market.getIronPrice(state))
        end)

        it("returns £6 when market is empty", function()
            state.ironMarket.supply = 0
            assert.are.equal(6, Market.getIronPrice(state))
        end)
    end)

    describe("buyCoalFromMarket", function()
        it("reduces supply and charges player", function()
            local cost = Market.buyCoalFromMarket(state, "Red", 1)
            assert.are.equal(12, state.coalMarket.supply)
            assert.is_true(cost > 0)
        end)
    end)

    describe("buyIronFromMarket", function()
        it("reduces supply and charges player", function()
            local cost = Market.buyIronFromMarket(state, "Red", 1)
            assert.are.equal(7, state.ironMarket.supply)
            assert.is_true(cost > 0)
        end)
    end)

    describe("returnResourceToMarket", function()
        it("coal returns to market if space available", function()
            state.coalMarket.supply = 10
            Market.returnCoalToMarket(state, 1)
            assert.are.equal(11, state.coalMarket.supply)
        end)

        it("coal overflows when market full (14)", function()
            state.coalMarket.supply = 14
            Market.returnCoalToMarket(state, 1)
            assert.are.equal(14, state.coalMarket.supply) -- capped
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/Market_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement Market**

Create `src/Market.lua`:
- `getCoalPrice(state)` — looks up price from track based on supply
- `getIronPrice(state)` — looks up price from track based on supply
- `buyCoalFromMarket(state, color, count)` — buy N coal, deduct money, return total cost
- `buyIronFromMarket(state, color, count)` — buy N iron, deduct money, return total cost
- `returnCoalToMarket(state, count)` — return consumed coal to market (fills lowest empty space)
- `returnIronToMarket(state, count)` — return consumed iron to market
- Uses `BoardData.coalMarketTrack` and `BoardData.ironMarketTrack` for price lookup

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/Market_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/Market.lua spec/Market_spec.lua
git commit -m "feat: add Market with price lookup, buying, and resource return"
```

---

### Task 6: TurnManager — Round Flow & Turn Order

**Files:**
- Create: `src/TurnManager.lua`
- Create: `spec/TurnManager_spec.lua`

- [ ] **Step 1: Write TurnManager tests**

```lua
package.path = package.path .. ";src/?.lua"
local TurnManager = require("TurnManager")
local GameState = require("GameState")

describe("TurnManager", function()
    local state

    before_each(function()
        state = GameState.new(4)
    end)

    describe("getActionsThisTurn", function()
        it("returns 1 for canal era first round", function()
            assert.are.equal(1, TurnManager.getActionsThisTurn(state))
        end)

        it("returns 2 for non-first rounds", function()
            state.isFirstRound = false
            assert.are.equal(2, TurnManager.getActionsThisTurn(state))
        end)

        it("returns 2 for rail era first round (no exception)", function()
            state.era = "rail"
            state.isFirstRound = true
            assert.are.equal(2, TurnManager.getActionsThisTurn(state))
        end)
    end)

    describe("incomePhase", function()
        it("gives each player income equal to their level", function()
            state.players["Red"].incomeLevel = 15
            state.players["Red"].money = 0
            TurnManager.incomePhase(state)
            assert.are.equal(15, state.players["Red"].money)
        end)

        it("deducts money for negative income", function()
            state.players["Red"].incomeLevel = -3
            state.players["Red"].money = 10
            TurnManager.incomePhase(state)
            assert.are.equal(7, state.players["Red"].money)
        end)

        it("deducts VP when cannot pay negative income", function()
            state.players["Red"].incomeLevel = -5
            state.players["Red"].money = 2
            state.players["Red"].vp = 10
            TurnManager.incomePhase(state)
            assert.are.equal(0, state.players["Red"].money)
            assert.are.equal(7, state.players["Red"].vp) -- lost 3 VP
        end)
    end)

    describe("reorderTurnOrder", function()
        it("sorts by spending ascending (stable)", function()
            state.players["Red"].spentThisRound = 20
            state.players["Blue"].spentThisRound = 5
            state.players["Yellow"].spentThisRound = 15
            state.players["Green"].spentThisRound = 5

            state.turnOrder = { "Red", "Blue", "Yellow", "Green" }
            TurnManager.reorderTurnOrder(state)

            -- Blue(5) and Green(5) tied, Blue was before Green, stays before
            assert.are.equal("Blue", state.turnOrder[1])
            assert.are.equal("Green", state.turnOrder[2])
            assert.are.equal("Yellow", state.turnOrder[3])
            assert.are.equal("Red", state.turnOrder[4])
        end)
    end)

    describe("nextPlayer", function()
        it("advances to next player in turn order", function()
            state.currentPlayerIdx = 1
            TurnManager.nextPlayer(state)
            assert.are.equal(2, state.currentPlayerIdx)
        end)

        it("wraps around after last player", function()
            state.currentPlayerIdx = 4
            TurnManager.nextPlayer(state)
            assert.are.equal(1, state.currentPlayerIdx)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/TurnManager_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement TurnManager**

Create `src/TurnManager.lua`:
- `getActionsThisTurn(state)` — 1 if canal era first round, else 2
- `incomePhase(state)` — distribute income to all players
- `reorderTurnOrder(state)` — stable sort by spentThisRound ascending
- `nextPlayer(state)` — advance currentPlayerIdx with wrap
- `startNewRound(state)` — reset spending, increment round, clear first round flag
- `getCurrentPlayer(state)` — returns current player color

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/TurnManager_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/TurnManager.lua spec/TurnManager_spec.lua
git commit -m "feat: add TurnManager with income phase, turn order, and round management"
```

---

### Task 7: Validation — Legal Move Checking

**Files:**
- Create: `src/Validation.lua`
- Create: `spec/Validation_spec.lua`

- [ ] **Step 1: Write Validation tests**

Create `spec/Validation_spec.lua` — test key validation scenarios:

```lua
package.path = package.path .. ";src/?.lua"
local Validation = require("Validation")
local GameState = require("GameState")

describe("Validation", function()
    local state

    before_each(function()
        state = GameState.new(4)
    end)

    describe("canBuild", function()
        it("allows build with location card in matching city", function()
            local result = Validation.canBuild(state, "Red", {
                cardType = "location",
                location = "Birmingham",
                industryType = "cotton",
                level = 1,
            })
            assert.is_true(result.valid)
        end)

        it("rejects build when not enough money", function()
            state.players["Red"].money = 0
            local result = Validation.canBuild(state, "Red", {
                cardType = "location",
                location = "Birmingham",
                industryType = "cotton",
                level = 1,
            })
            assert.is_false(result.valid)
        end)

        it("rejects canal era double building in same city", function()
            -- Place a building in Birmingham first
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "cotton", level = 1, flipped = false }

            local result = Validation.canBuild(state, "Blue", {
                cardType = "location",
                location = "Birmingham",
                industryType = "iron",
                level = 1,
            })
            -- Canal era: max 1 per city (Blue trying to add second)
            assert.is_false(result.valid)
        end)
    end)

    describe("canNetwork", function()
        it("allows canal link for £3 in canal era", function()
            -- Place a building so player has network
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "cotton", level = 1, flipped = false }

            local result = Validation.canNetwork(state, "Red", {
                linkId = "Birmingham-Coventry",
                era = "canal",
            })
            assert.is_true(result.valid)
        end)
    end)

    describe("canDevelop", function()
        it("allows develop with enough iron", function()
            -- Ensure there's iron available (on a building or in market)
            local result = Validation.canDevelop(state, "Red", {
                count = 1,
            })
            assert.is_true(result.valid)
        end)

        it("rejects develop of pottery Lv1 (no-develop)", function()
            -- Set player's lowest tile to pottery Lv1
            -- (implementation checks the actual tile stack)
            local result = Validation.canDevelop(state, "Red", {
                count = 1,
                targetType = "pottery",
                targetLevel = 1,
            })
            assert.is_false(result.valid)
        end)
    end)

    describe("canLoan", function()
        it("allows loan at income level 10", function()
            assert.is_true(Validation.canLoan(state, "Red").valid)
        end)

        it("rejects loan at income level -8", function()
            state.players["Red"].incomeLevel = -8
            assert.is_false(Validation.canLoan(state, "Red").valid)
        end)
    end)

    describe("canScout", function()
        it("allows scout with no wilds in hand", function()
            state.players["Red"].handSize = 8
            state.players["Red"].hasWilds = false
            assert.is_true(Validation.canScout(state, "Red").valid)
        end)

        it("rejects scout when holding wild cards", function()
            state.players["Red"].hasWilds = true
            assert.is_false(Validation.canScout(state, "Red").valid)
        end)

        it("rejects scout with fewer than 3 cards in hand", function()
            state.players["Red"].handSize = 2
            state.players["Red"].hasWilds = false
            assert.is_false(Validation.canScout(state, "Red").valid)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/Validation_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement Validation**

Create `src/Validation.lua`:
- `canBuild(state, color, params)` — checks: slot available, correct industry type, in network (or location card), enough money/resources, canal era max 1 per city, overbuilding rules
- `canNetwork(state, color, params)` — checks: link unoccupied, adjacent to network, enough money/coal/beer, correct era
- `canSell(state, color, params)` — checks: building is sellable type (cotton/mfr/pottery), connected to merchant, enough beer
- `canDevelop(state, color, params)` — checks: lowest tile not no-develop, enough iron
- `canLoan(state, color)` — checks: income level - 3 >= -10
- `canScout(state, color)` — checks: no wilds in hand, hand size >= 3, wild supply > 0

Each returns `{ valid = bool, reason = string }`.

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/Validation_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/Validation.lua spec/Validation_spec.lua
git commit -m "feat: add Validation with legal move checking for all 6 actions"
```

---

### Task 8: Actions — Execute Game Actions

**Files:**
- Create: `src/Actions.lua`
- Create: `spec/Actions_spec.lua`

- [ ] **Step 1: Write Actions tests**

Create `spec/Actions_spec.lua` — test each of the 6 actions:

```lua
package.path = package.path .. ";src/?.lua"
local Actions = require("Actions")
local GameState = require("GameState")

describe("Actions", function()
    local state

    before_each(function()
        state = GameState.new(4)
    end)

    describe("build", function()
        it("places tile on board and deducts cost", function()
            local result = Actions.build(state, "Red", {
                location = "Birmingham",
                slotId = "Birmingham_cotton_1",
                industryType = "cotton",
                level = 1,
            })
            assert.is_true(result.success)
            local slot = nil
            for _, s in ipairs(state.board.cities["Birmingham"].slots) do
                if s.id == "Birmingham_cotton_1" then slot = s; break end
            end
            assert.are.equal("Red", slot.occupant)
            assert.are.equal(5, state.players["Red"].money) -- 17 - 12
        end)

        it("brewery flips immediately and produces beer", function()
            state.players["Red"].money = 50
            local result = Actions.build(state, "Red", {
                location = "Burton-on-Trent",
                slotId = "BurtonOnTrent_brewery_1",
                industryType = "brewery",
                level = 1,
            })
            assert.is_true(result.success)
            -- Find the placed tile
            local slot = nil
            for _, s in ipairs(state.board.cities["Burton-on-Trent"].slots) do
                if s.id == "BurtonOnTrent_brewery_1" then slot = s; break end
            end
            assert.is_true(slot.tile.flipped)
            assert.are.equal(1, #slot.tile.resources) -- 1 beer
        end)
    end)

    describe("network", function()
        it("places canal link and deducts £3", function()
            -- Give Red a building in Birmingham for network
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "cotton", level = 1, flipped = false }

            local result = Actions.network(state, "Red", {
                linkId = "Birmingham-Coventry",
            })
            assert.is_true(result.success)
            assert.are.equal("Red", state.board.links["Birmingham-Coventry"].owner)
            assert.are.equal(14, state.players["Red"].money) -- 17 - 3
        end)
    end)

    describe("loan", function()
        it("gives £30 and decreases income 3 levels", function()
            local result = Actions.loan(state, "Red")
            assert.is_true(result.success)
            assert.are.equal(47, state.players["Red"].money) -- 17 + 30
            assert.are.equal(7, state.players["Red"].incomeLevel) -- 10 - 3
        end)
    end)

    describe("scout", function()
        it("gives 1 wild location + 1 wild industry, reduces supply", function()
            state.players["Red"].hasWilds = false
            state.players["Red"].handSize = 8
            local result = Actions.scout(state, "Red")
            assert.is_true(result.success)
            assert.are.equal(3, state.wildSupply.location)
            assert.are.equal(3, state.wildSupply.industry)
            -- Hand: -3 (1 played + 2 discarded) + 2 wilds gained = net -1
            assert.are.equal(7, state.players["Red"].handSize)
        end)
    end)

    describe("develop", function()
        it("removes 1 tile from player board and consumes 1 iron", function()
            local initialTileCount = #state.players["Red"].unbuiltTiles
            local result = Actions.develop(state, "Red", { count = 1 })
            assert.is_true(result.success)
            assert.are.equal(initialTileCount - 1, #state.players["Red"].unbuiltTiles)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/Actions_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement Actions**

Create `src/Actions.lua`:
- `Actions.build(state, color, params)` — validates via Validation, places tile, deducts cost, consumes resources, places output tokens, auto-flips brewery
- `Actions.network(state, color, params)` — validates, places link, deducts cost + resources
- `Actions.sell(state, color, params)` — validates, consumes beer, flips tile, advances income, processes merchant bonus
- `Actions.develop(state, color, params)` — validates, removes 1-2 lowest tiles, consumes iron
- `Actions.loan(state, color)` — validates, gives £30, decreases income 3 levels
- `Actions.scout(state, color)` — validates, removes 3 cards from hand, adds 2 wilds
- Each calls `Validation` first, then `Market` for resources, then updates `GameState`
- Each returns `{ success = bool, error = string }`

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/Actions_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/Actions.lua spec/Actions_spec.lua
git commit -m "feat: add Actions with all 6 game actions (Build/Network/Sell/Develop/Loan/Scout)"
```

---

### Task 9: Scoring — End-of-Era Scoring

**Files:**
- Create: `src/Scoring.lua`
- Create: `spec/Scoring_spec.lua`

- [ ] **Step 1: Write Scoring tests**

```lua
package.path = package.path .. ";src/?.lua"
local Scoring = require("Scoring")
local GameState = require("GameState")

describe("Scoring", function()
    local state

    before_each(function()
        state = GameState.new(4)
    end)

    describe("scoreBuildingVP", function()
        it("scores VP for flipped buildings", function()
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "cotton", level = 1, flipped = true, vp = 5 }

            local vp = Scoring.scoreBuildingVP(state, "Red")
            assert.are.equal(5, vp)
        end)

        it("scores 0 for unflipped buildings", function()
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "cotton", level = 1, flipped = false, vp = 5 }

            local vp = Scoring.scoreBuildingVP(state, "Red")
            assert.are.equal(0, vp)
        end)
    end)

    describe("scoreLinkVP", function()
        it("scores link icons from adjacent flipped buildings", function()
            -- Place a link
            state.board.links["Birmingham-Coventry"].owner = "Red"
            state.board.links["Birmingham-Coventry"].type = "canal"

            -- Place flipped building in Birmingham with 2 link icons
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "coal", level = 1, flipped = true, linkIcons = 2 }

            -- Place flipped building in Coventry with 1 link icon
            local slot2 = state.board.cities["Coventry"].slots[1]
            slot2.occupant = "Blue"
            slot2.tile = { type = "cotton", level = 1, flipped = true, linkIcons = 1 }

            local vp = Scoring.scoreLinkVP(state, "Red")
            assert.are.equal(3, vp) -- 2 + 1
        end)
    end)

    describe("scoreIncomeVP", function()
        it("returns income level as VP", function()
            state.players["Red"].incomeLevel = 15
            assert.are.equal(15, Scoring.scoreIncomeVP(state, "Red"))
        end)

        it("returns negative VP for negative income", function()
            state.players["Red"].incomeLevel = -3
            assert.are.equal(-3, Scoring.scoreIncomeVP(state, "Red"))
        end)
    end)

    describe("scoreEndOfEra", function()
        it("calculates total and updates VP", function()
            local slot = state.board.cities["Birmingham"].slots[1]
            slot.occupant = "Red"
            slot.tile = { type = "cotton", level = 1, flipped = true, vp = 5, linkIcons = 1 }

            Scoring.scoreEndOfEra(state, false) -- not final
            assert.is_true(state.players["Red"].vp >= 5)
        end)

        it("includes income VP only in final scoring", function()
            state.players["Red"].incomeLevel = 20
            Scoring.scoreEndOfEra(state, false) -- mid-game: no income VP
            local vpMid = state.players["Red"].vp

            state.players["Red"].vp = 0
            Scoring.scoreEndOfEra(state, true) -- final: includes income VP
            local vpFinal = state.players["Red"].vp

            assert.is_true(vpFinal > vpMid)
        end)
    end)

    describe("determineWinner", function()
        it("ranks by VP then income then money", function()
            state.players["Red"].vp = 100
            state.players["Blue"].vp = 100
            state.players["Red"].incomeLevel = 15
            state.players["Blue"].incomeLevel = 20

            local ranking = Scoring.determineWinner(state)
            assert.are.equal("Blue", ranking[1].color) -- higher income
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/Scoring_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement Scoring**

Create `src/Scoring.lua`:
- `scoreBuildingVP(state, color)` — sum VP of all flipped buildings owned by color
- `scoreLinkVP(state, color)` — for each owned link, sum link icons on adjacent flipped buildings
- `scoreIncomeVP(state, color)` — returns income level as VP
- `scoreEndOfEra(state, isFinal)` — scores all players: buildings + links + (income if final)
- `determineWinner(state)` — returns sorted ranking with tiebreakers (VP → income → money)

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/Scoring_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/Scoring.lua spec/Scoring_spec.lua
git commit -m "feat: add Scoring with building VP, link VP, income VP, and winner ranking"
```

---

### Task 10: EraTransition — Canal to Rail

**Files:**
- Create: `src/EraTransition.lua`
- Create: `spec/EraTransition_spec.lua`

- [ ] **Step 1: Write EraTransition tests**

```lua
package.path = package.path .. ";src/?.lua"
local EraTransition = require("EraTransition")
local GameState = require("GameState")

describe("EraTransition", function()
    local state

    before_each(function()
        state = GameState.new(4)
        state.era = "canal"
        -- Place some canal links and level 1 buildings
        state.board.links["Birmingham-Coventry"].owner = "Red"
        state.board.links["Birmingham-Coventry"].type = "canal"

        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "Red"
        slot.tile = { type = "cotton", level = 1, flipped = true, vp = 5, linkIcons = 1 }

        local slot2 = state.board.cities["Coventry"].slots[1]
        slot2.occupant = "Blue"
        slot2.tile = { type = "iron", level = 2, flipped = false, resources = { "iron", "iron" } }
    end)

    describe("isEraOver", function()
        it("returns false when deck has cards", function()
            state.deckEmpty = false
            assert.is_false(EraTransition.isEraOver(state))
        end)

        it("returns true when deck empty and all hands empty", function()
            state.deckEmpty = true
            for _, p in pairs(state.players) do
                p.handSize = 0
            end
            assert.is_true(EraTransition.isEraOver(state))
        end)

        it("returns false when deck empty but someone has cards", function()
            state.deckEmpty = true
            state.players["Red"].handSize = 2
            assert.is_false(EraTransition.isEraOver(state))
        end)
    end)

    describe("transition", function()
        it("changes era to rail", function()
            EraTransition.transition(state)
            assert.are.equal("rail", state.era)
        end)

        it("removes all canal links", function()
            EraTransition.transition(state)
            assert.is_nil(state.board.links["Birmingham-Coventry"].owner)
            assert.is_nil(state.board.links["Birmingham-Coventry"].type)
        end)

        it("removes level 1 buildings from board", function()
            EraTransition.transition(state)
            local slot = state.board.cities["Birmingham"].slots[1]
            assert.is_nil(slot.tile) -- Level 1 cotton removed
        end)

        it("keeps level 2+ buildings", function()
            EraTransition.transition(state)
            local slot2 = state.board.cities["Coventry"].slots[1]
            assert.is_not_nil(slot2.tile) -- Level 2 iron stays
        end)

        it("does not set isFirstRound for rail era", function()
            EraTransition.transition(state)
            assert.is_false(state.isFirstRound)
        end)

        it("resets market supplies", function()
            state.coalMarket.supply = 3
            EraTransition.transition(state)
            assert.are.equal(13, state.coalMarket.supply)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/EraTransition_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement EraTransition**

Create `src/EraTransition.lua`:
- `isEraOver(state)` — true if deck empty AND all players hand size = 0
- `transition(state)` — executes full era transition:
  1. Call `Scoring.scoreEndOfEra(state, false)` for mid-game scoring
  2. Remove all canal links (set owner/type to nil)
  3. Remove all Level 1 buildings from board
  4. Set era to "rail"
  5. Reset markets to initial supply
  6. Set `isFirstRound = false` (rail era has no first-round exception)
  7. Reset round counter

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/EraTransition_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/EraTransition.lua spec/EraTransition_spec.lua
git commit -m "feat: add EraTransition with canal-to-rail transition logic"
```

---

### Task 11: Lang — Internationalization

**Files:**
- Create: `src/Lang.lua`
- Create: `spec/Lang_spec.lua`

- [ ] **Step 1: Write Lang tests**

```lua
package.path = package.path .. ";src/?.lua"
local Lang = require("Lang")

describe("Lang", function()
    it("returns English string by default", function()
        assert.are.equal("Your turn", Lang.get("your_turn", "en"))
    end)

    it("returns Chinese string", function()
        assert.are.equal("輪到你的回合", Lang.get("your_turn", "zh-TW"))
    end)

    it("falls back to English for missing key", function()
        assert.are.equal("Unknown key", Lang.get("nonexistent", "zh-TW"))
    end)

    it("formats string with parameters", function()
        local result = Lang.format("player_spent", "en", { player = "Red", amount = 15 })
        assert.is_true(result:find("Red") ~= nil)
        assert.is_true(result:find("15") ~= nil)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `busted spec/Lang_spec.lua`
Expected: FAIL

- [ ] **Step 3: Implement Lang**

Create `src/Lang.lua`:
- String tables for `en` and `zh-TW` covering: turn prompts, action names, error messages, scoring labels, era transition messages
- `Lang.get(key, locale)` — returns localized string, fallback to "Unknown key"
- `Lang.format(key, locale, params)` — returns formatted string with parameter substitution

- [ ] **Step 4: Run test to verify it passes**

Run: `busted spec/Lang_spec.lua`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add src/Lang.lua spec/Lang_spec.lua
git commit -m "feat: add Lang with en/zh-TW string tables and parameter formatting"
```

---

### Task 12: Integration Test — Full Game Flow

**Files:**
- Create: `spec/integration_spec.lua`

- [ ] **Step 1: Write integration test simulating a mini game**

Create `spec/integration_spec.lua`:
```lua
package.path = package.path .. ";src/?.lua"
local GameState = require("GameState")
local TurnManager = require("TurnManager")
local Actions = require("Actions")
local Scoring = require("Scoring")
local EraTransition = require("EraTransition")

describe("Integration: mini game flow", function()
    local state

    before_each(function()
        state = GameState.new(2)
    end)

    it("can execute a full round: income -> actions -> reorder", function()
        -- Income phase
        TurnManager.incomePhase(state)
        assert.are.equal(27, state.players["Red"].money) -- 17 + 10

        -- Player 1 takes loan
        Actions.loan(state, "Red")
        assert.are.equal(57, state.players["Red"].money) -- 27 + 30
        assert.are.equal(7, state.players["Red"].incomeLevel)

        -- Reorder
        TurnManager.reorderTurnOrder(state)
        -- Red spent 0 on actions (loan gives money, doesn't "spend" in the tracking sense)
    end)

    it("serialize and deserialize preserves game mid-play", function()
        TurnManager.incomePhase(state)
        Actions.loan(state, "Red")

        local json = GameState.serialize(state)
        local restored = GameState.deserialize(json)

        assert.are.equal(state.players["Red"].money,
                         restored.players["Red"].money)
        assert.are.equal(state.players["Red"].incomeLevel,
                         restored.players["Red"].incomeLevel)
        assert.are.equal(state.era, restored.era)
    end)

    it("scoring returns deterministic results", function()
        -- Place a flipped building
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "Red"
        slot.tile = { type = "cotton", level = 1, flipped = true, vp = 5, linkIcons = 1 }

        Scoring.scoreEndOfEra(state, true)
        assert.is_true(state.players["Red"].vp >= 5)

        local ranking = Scoring.determineWinner(state)
        assert.is_not_nil(ranking)
        assert.is_true(#ranking >= 2)
    end)
end)
```

- [ ] **Step 2: Run all tests**

Run: `busted`
Expected: All pass across all spec files

- [ ] **Step 3: Commit**

```bash
git add spec/integration_spec.lua
git commit -m "feat: add integration test for full game flow"
```

---

## Next Phase

After Phase 1 is complete with all tests passing, proceed to:
- **Phase 2: TTS Integration** — wrap `src/` modules with TTS API bindings (`tts/Global.lua`, `tts/SnapMap.lua`, XML UI for counters, object event handlers)
- **Phase 3: Assets** — create all image/model/PDF assets and assemble the TTS save file
