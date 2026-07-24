--- Regression tests for Actions.sell — the full Sell execution path.
--- Covers tile flip, income advance, beer consumption, multi-slot sell, and
--- each merchant bonus type (vp / income_advance / money). Part of issue #5.

local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Actions   = require("src/Actions")

local function newStateSell()
    return GameState.new(2)
end

--- Place a sellable industry tile the test controls precisely.
local function placeSellable(state, slotId, color, fields)
    local slot = GameState.getSlot(state, slotId)
    slot.occupant = color
    local tile = {
        type = Constants.Industry.MANUFACTURER,
        level = 1,
        flipped = false,
        resources = {},
        beerToSell = 0,
        incomeSpaces = 0,
        vp = 0,
    }
    for k, v in pairs(fields or {}) do tile[k] = v end
    slot.tile = tile
    return slot
end

--- Place a flipped brewery holding `beer` beer tokens for the given owner.
local function placeBrewery(state, slotId, color, beer)
    local slot = GameState.getSlot(state, slotId)
    slot.occupant = color
    local resources = {}
    for i = 1, (beer or 0) do resources[i] = Constants.Resource.BEER end
    slot.tile = {
        type = Constants.Industry.BREWERY,
        level = 1,
        flipped = true,          -- breweries are active once built
        resources = resources,
        incomeSpaces = 0,
        beerToSell = 0,
    }
    return slot
end

-- ============================================================
-- Single sell — no beer required
-- ============================================================

describe("Actions.sell - single sell without beer", function()
    it("flips the tile and advances income by the tile's incomeSpaces", function()
        local state = newStateSell()
        -- Wolverhampton is adjacent to the Shrewsbury merchant.
        placeSellable(state, "Wolverhampton_1", "White",
            { beerToSell = 0, incomeSpaces = 5 })
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"

        local player = GameState.getPlayer(state, "White")
        local result = Actions.sell(state, "White", { slotIds = { "Wolverhampton_1" } })
        expect(result.success).toBeTrue()
        expect(GameState.getSlot(state, "Wolverhampton_1").tile.flipped).toBeTrue()
        -- incomeSpaces 5 from level 10 -> level 12
        expect(player.incomeLevel).toBe(12)
    end)
end)

-- ============================================================
-- Sell requiring beer — consumes from the player's own brewery
-- ============================================================

describe("Actions.sell - beer consumption", function()
    it("consumes one beer from the player's own brewery", function()
        local state = newStateSell()
        -- Worcester is adjacent to the Gloucester merchant.
        placeSellable(state, "Worcester_1", "White",
            { type = Constants.Industry.COTTON, beerToSell = 1, incomeSpaces = 5 })
        state.board.links["Gloucester-Worcester"].owner = "White"
        -- Own brewery is a valid beer source regardless of connection.
        local brewery = placeBrewery(state, "Stafford_1", "White", 1)

        local player = GameState.getPlayer(state, "White")
        local result = Actions.sell(state, "White", { slotIds = { "Worcester_1" } })
        expect(result.success).toBeTrue()
        expect(GameState.getSlot(state, "Worcester_1").tile.flipped).toBeTrue()
        expect(#brewery.tile.resources).toBe(0)   -- the one beer was consumed
        expect(player.incomeLevel).toBe(12)
    end)
end)

-- ============================================================
-- Multi-slot sell — several buildings in one action
-- ============================================================

describe("Actions.sell - multi-slot", function()
    it("flips every listed tile and advances income for each", function()
        local state = newStateSell()
        placeSellable(state, "Wolverhampton_1", "White", { incomeSpaces = 1 })
        placeSellable(state, "Wolverhampton_2", "White", { incomeSpaces = 1 })
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"

        local player = GameState.getPlayer(state, "White")
        local result = Actions.sell(state, "White",
            { slotIds = { "Wolverhampton_1", "Wolverhampton_2" } })
        expect(result.success).toBeTrue()
        expect(GameState.getSlot(state, "Wolverhampton_1").tile.flipped).toBeTrue()
        expect(GameState.getSlot(state, "Wolverhampton_2").tile.flipped).toBeTrue()
        -- Two incomeSpaces total from level 10 -> level 11
        expect(player.incomeLevel).toBe(11)
    end)
end)

-- ============================================================
-- Merchant bonuses
-- ============================================================

describe("Actions.sell - merchant VP bonus", function()
    it("awards Shrewsbury's +4 VP when sold to that merchant", function()
        local state = newStateSell()
        placeSellable(state, "Wolverhampton_1", "White", { incomeSpaces = 0 })
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"

        local player = GameState.getPlayer(state, "White")
        local result = Actions.sell(state, "White",
            { slotIds = { "Wolverhampton_1" }, merchantName = "Shrewsbury" })
        expect(result.success).toBeTrue()
        expect(player.vp).toBe(4)   -- Shrewsbury bonus = vp 4
    end)
end)

describe("Actions.sell - merchant income-advance bonus", function()
    it("advances income by Oxford's +2 bonus", function()
        local state = newStateSell()
        -- Coventry is adjacent to the Oxford merchant.
        placeSellable(state, "Coventry_1", "White", { incomeSpaces = 0 })
        state.board.links["Coventry-Oxford"].owner = "White"

        local player = GameState.getPlayer(state, "White")
        local result = Actions.sell(state, "White",
            { slotIds = { "Coventry_1" }, merchantName = "Oxford" })
        expect(result.success).toBeTrue()
        -- Only the +2 income_advance applies (tile incomeSpaces = 0): 10 -> 11
        expect(player.incomeLevel).toBe(11)
    end)
end)

describe("Actions.sell - merchant money bonus", function()
    it("awards Warrington's +£5 in a 3-player game", function()
        -- Warrington activates at 3 players; Stoke-on-Trent is in play at 3p.
        local state = GameState.new(3)
        placeSellable(state, "Stoke-on-Trent_2", "White", { incomeSpaces = 0 })
        state.board.links["Stoke-on-Trent-Warrington"].owner = "White"

        local player = GameState.getPlayer(state, "White")
        local before = player.money
        local result = Actions.sell(state, "White",
            { slotIds = { "Stoke-on-Trent_2" }, merchantName = "Warrington" })
        expect(result.success).toBeTrue()
        expect(player.money).toBe(before + 5)   -- Warrington bonus = money 5
    end)
end)
