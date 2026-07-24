--- Regression tests for Actions.build — the full Build execution path.
--- Locks down money/spentThisRound deltas, tile placement, resource
--- consumption, coal/iron auto-sell to market, brewery auto-flip, and
--- overbuild removal. Part of issue #5 (safety net before the ActionEngine
--- refactor). No test framework beyond the repo's describe/it/expect runner.

local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Actions   = require("src/Actions")
local Tile      = require("src/Tile")

local function newState()
    return GameState.new(2)
end

--- Count resource tokens on a slot's tile.
local function resCount(state, slotId)
    local slot = GameState.getSlot(state, slotId)
    return slot and slot.tile and #slot.tile.resources or 0
end

-- ============================================================
-- Cotton — basic cost, placement, bookkeeping
-- ============================================================

describe("Actions.build - cotton basic cost and placement", function()
    it("deducts money and records spentThisRound", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local result = Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
        expect(result.success).toBeTrue()
        -- Cotton L1 costs £12, no coal/iron
        expect(player.money).toBe(Constants.INITIAL_MONEY - 12)
        expect(player.spentThisRound).toBe(12)
    end)

    it("places an unflipped tile and sets the occupant", function()
        local state = newState()
        Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
        local slot = GameState.getSlot(state, "Birmingham_2")
        expect(slot.occupant).toBe("White")
        expect(slot.tile.type).toBe(Constants.Industry.COTTON)
        expect(slot.tile.level).toBe(1)
        expect(slot.tile.flipped).toBeFalse()
    end)

    it("removes exactly one tile from the player's unbuilt stack", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local before = #player.unbuiltTiles[Constants.Industry.COTTON]
        Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
        expect(#player.unbuiltTiles[Constants.Industry.COTTON]).toBe(before - 1)
    end)

    it("does not change handSize (card deduction is a TTS-layer concern)", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        player.handSize = 8
        Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
        expect(player.handSize).toBe(8)
    end)

    it("returns a failure and does not mutate money on an invalid build", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        player.money = 3  -- cotton L1 needs £12
        local result = Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
        expect(result.success).toBeFalse()
        expect(player.money).toBe(3)
        expect(GameState.getSlot(state, "Birmingham_2").occupant).toBeNil()
    end)
end)

-- ============================================================
-- Brewery — auto-flip and immediate income on build
-- ============================================================

describe("Actions.build - brewery auto-flip and income", function()
    it("flips the brewery, advances income, and consumes 1 iron from the board", function()
        local state = newState()
        -- Provide a board iron source (findIronSources scans the whole board,
        -- no network needed). Owned by the opponent — irrelevant to sourcing.
        local ironSlot = GameState.getSlot(state, "Coalbrookdale_1")
        ironSlot.occupant = "Purple"
        ironSlot.tile = Tile.newWithResources(Constants.Industry.IRON, 1)  -- 4 iron
        expect(#ironSlot.tile.resources).toBe(4)

        local player = GameState.getPlayer(state, "White")
        local result = Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Walsall",
            industryType = Constants.Industry.BREWERY,
            level = 1,
            slotId = "Walsall_2",
        })
        expect(result.success).toBeTrue()

        local brewSlot = GameState.getSlot(state, "Walsall_2")
        expect(brewSlot.tile.flipped).toBeTrue()               -- breweries flip on build
        expect(#brewSlot.tile.resources).toBe(1)               -- canal era = 1 beer produced
        -- Brewery L1: £5 build, 1 iron consumed from board (free)
        expect(player.money).toBe(Constants.INITIAL_MONEY - 5)
        -- incomeSpaces=4 from income level 10 -> level 11
        expect(player.incomeLevel).toBe(11)
        -- 1 iron consumed, returned to market (8 -> 9); 3 iron left on the source
        expect(state.ironMarket.supply).toBe(9)
        expect(#ironSlot.tile.resources).toBe(3)
    end)
end)

-- ============================================================
-- Coal mine — mandatory auto-sell to the coal market
-- ============================================================

describe("Actions.build - coal mine auto-sell", function()
    it("keeps produced coal when the city is not connected to a merchant", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local result = Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 1,
            slotId = "Dudley_1",
        })
        expect(result.success).toBeTrue()
        local slot = GameState.getSlot(state, "Dudley_1")
        -- No merchant connection: coal cannot be sold, stays on the tile
        expect(#slot.tile.resources).toBe(2)
        expect(slot.tile.flipped).toBeFalse()
        expect(player.money).toBe(Constants.INITIAL_MONEY - 5)   -- coal L1 = £5
        expect(state.coalMarket.supply).toBe(Constants.INITIAL_COAL_SUPPLY)
    end)

    it("sells to market, earns £1 per cube, flips when emptied, and awards income", function()
        local state = newState()
        -- Connect Dudley -> Wolverhampton -> Shrewsbury (merchant) via any links.
        state.board.links["Dudley-Wolverhampton"].owner = "White"
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"
        -- Leave exactly 2 empty coal market spaces so both cubes sell.
        state.coalMarket.supply = 12  -- track has 14 spaces

        local player = GameState.getPlayer(state, "White")
        local result = Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 1,
            slotId = "Dudley_1",
        })
        expect(result.success).toBeTrue()
        local slot = GameState.getSlot(state, "Dudley_1")
        expect(#slot.tile.resources).toBe(0)          -- both cubes sold
        expect(slot.tile.flipped).toBeTrue()          -- auto-flip on empty
        expect(state.coalMarket.supply).toBe(14)      -- 12 + 2, capped at track max
        -- £5 build cost, +£2 from selling 2 cubes
        expect(player.money).toBe(Constants.INITIAL_MONEY - 5 + 2)
        -- coal L1 incomeSpaces=4 awarded on flip: level 10 -> 11
        expect(player.incomeLevel).toBe(11)
    end)
end)

-- ============================================================
-- Iron works — sells to the global market (no connection needed)
-- ============================================================

describe("Actions.build - iron works auto-sell to global market", function()
    it("sells iron to market without a connection and earns £1 per cube", function()
        local state = newState()
        state.era = Constants.Era.RAIL  -- avoid the canal one-per-city rule
        -- A coal mine in the same city satisfies the iron build's 1-coal cost
        -- (findNearestCoal reaches distance-0 without any links).
        local coalSlot = GameState.getSlot(state, "Coalbrookdale_3")
        coalSlot.occupant = "White"
        coalSlot.tile = Tile.newWithResources(Constants.Industry.COAL, 1)  -- 2 coal

        local player = GameState.getPlayer(state, "White")
        local result = Actions.build(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Coalbrookdale",
            industryType = Constants.Industry.IRON,
            level = 1,
            slotId = "Coalbrookdale_1",
        })
        expect(result.success).toBeTrue()
        local slot = GameState.getSlot(state, "Coalbrookdale_1")
        -- Iron L1 produces 4; iron market has 2 empty spaces (supply 8 / track 10)
        expect(resCount(state, "Coalbrookdale_1")).toBe(2)   -- 4 produced - 2 sold
        expect(slot.tile.flipped).toBeFalse()
        expect(state.ironMarket.supply).toBe(10)             -- 8 + 2
        -- £5 build, 1 coal from board (free), +£2 from selling 2 iron cubes
        expect(player.money).toBe(Constants.INITIAL_MONEY - 5 + 2)
        -- Coal consumed from the board mine returns to the coal market (13 -> 14)
        expect(state.coalMarket.supply).toBe(14)
    end)
end)
