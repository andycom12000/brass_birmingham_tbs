--- Regression tests for previously-uncovered validation edge cases:
--- overbuild variants, rail-only restriction in the canal era, and beer
--- sourcing priority (own brewery before merchant beer). Part of issue #5.

local Constants  = require("src/Constants")
local GameState  = require("src/GameState")
local Actions    = require("src/Actions")
local Validation = require("src/Validation")
local Tile       = require("src/Tile")

local function newState()
    return GameState.new(2)
end

--- Force a player's unbuilt stack so a specific level is the lowest available
--- (overbuild also requires building the lowest level you still hold).
local function setLowest(player, industry, level)
    player.unbuiltTiles[industry] = { Tile.new(industry, level) }
end

-- ============================================================
-- Overbuild — own tile
-- ============================================================

describe("Validation.canBuild - overbuild own tile", function()
    it("allows overbuilding an unflipped own tile with a higher level", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local slot = GameState.getSlot(state, "Dudley_1")
        slot.occupant = "White"
        slot.tile = Tile.new(Constants.Industry.COAL, 1)  -- unflipped L1
        setLowest(player, Constants.Industry.COAL, 2)     -- coal L2 = £7, no resources

        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 2,
            slotId = "Dudley_1",
        })
        expect(v.valid).toBeTrue()
    end)

    it("rejects overbuilding an already-flipped own tile", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local slot = GameState.getSlot(state, "Dudley_1")
        slot.occupant = "White"
        slot.tile = Tile.new(Constants.Industry.COAL, 1)
        slot.tile.flipped = true
        setLowest(player, Constants.Industry.COAL, 2)

        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 2,
            slotId = "Dudley_1",
        })
        expect(v.valid).toBeFalse()
    end)

    it("rejects overbuilding own tile with an equal or lower level", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local slot = GameState.getSlot(state, "Dudley_1")
        slot.occupant = "White"
        slot.tile = Tile.new(Constants.Industry.COAL, 2)  -- existing L2
        setLowest(player, Constants.Industry.COAL, 2)     -- can only build L2

        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 2,
            slotId = "Dudley_1",
        })
        expect(v.valid).toBeFalse()
    end)
end)

-- ============================================================
-- Overbuild — opponent tile
-- ============================================================

describe("Validation.canBuild - overbuild opponent tile", function()
    it("rejects overbuilding an opponent coal mine while coal is still available", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local slot = GameState.getSlot(state, "Dudley_1")
        slot.occupant = "Purple"
        slot.tile = Tile.newWithResources(Constants.Industry.COAL, 1)  -- 2 coal on board
        setLowest(player, Constants.Industry.COAL, 2)

        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 2,
            slotId = "Dudley_1",
        })
        expect(v.valid).toBeFalse()
    end)

    it("allows overbuilding an opponent coal mine when no coal remains anywhere", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local slot = GameState.getSlot(state, "Dudley_1")
        slot.occupant = "Purple"
        slot.tile = Tile.new(Constants.Industry.COAL, 1)  -- unflipped, 0 resources
        state.coalMarket.supply = 0                       -- and none in the market
        setLowest(player, Constants.Industry.COAL, 2)

        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Dudley",
            industryType = Constants.Industry.COAL,
            level = 2,
            slotId = "Dudley_1",
        })
        expect(v.valid).toBeTrue()
    end)

    it("rejects overbuilding an opponent non-coal/iron tile", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local slot = GameState.getSlot(state, "Birmingham_2")
        slot.occupant = "Purple"
        slot.tile = Tile.new(Constants.Industry.COTTON, 1)
        setLowest(player, Constants.Industry.COTTON, 2)

        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 2,
            slotId = "Birmingham_2",
        })
        expect(v.valid).toBeFalse()
    end)
end)

-- ============================================================
-- Rail-only industry in the canal era
-- ============================================================

describe("Validation.canBuild - rail-only restriction", function()
    it("rejects a rail-only brewery (L4) in the canal era", function()
        local state = newState()  -- canal era by default
        local v = Validation.canBuild(state, "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Walsall",
            industryType = Constants.Industry.BREWERY,
            level = 4,
            slotId = "Walsall_2",
        })
        expect(v.valid).toBeFalse()
    end)
end)

-- ============================================================
-- Beer sourcing priority — own brewery before merchant beer
-- ============================================================

describe("Actions.sell - beer sourcing priority", function()
    it("consumes the player's own brewery beer before the merchant's beer", function()
        local state = newState()
        -- Sellable cotton at Worcester, connected to the Gloucester merchant.
        local sellSlot = GameState.getSlot(state, "Worcester_1")
        sellSlot.occupant = "White"
        sellSlot.tile = {
            type = Constants.Industry.COTTON, level = 1, flipped = false,
            resources = {}, beerToSell = 1, incomeSpaces = 0,
        }
        state.board.links["Gloucester-Worcester"].owner = "White"

        -- Own brewery with 1 beer (a valid source without any connection).
        local brewery = GameState.getSlot(state, "Stafford_1")
        brewery.occupant = "White"
        brewery.tile = {
            type = Constants.Industry.BREWERY, level = 1, flipped = true,
            resources = { Constants.Resource.BEER }, incomeSpaces = 0,
        }

        -- Merchant beer also available at Gloucester.
        state.board.merchants["Gloucester"].beer = 2

        local result = Actions.sell(state, "White",
            { slotIds = { "Worcester_1" }, merchantName = "Gloucester" })
        expect(result.success).toBeTrue()
        -- Own brewery beer is spent first; merchant beer is left untouched.
        expect(#brewery.tile.resources).toBe(0)
        expect(state.board.merchants["Gloucester"].beer).toBe(2)
    end)
end)
