--- Regression tests for Market dynamic pricing — locks the price ladder and
--- buy/return/estimate behaviour that build/develop/network all depend on.
--- Part of issue #5.

local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Market    = require("src/Market")

local COAL = Constants.Resource.COAL
local IRON = Constants.Resource.IRON

local function newState()
    return GameState.new(2)
end

-- ============================================================
-- getPrice — the price ladder
-- ============================================================

describe("Market.getPrice - coal ladder", function()
    it("prices the next cube by track position at full supply", function()
        local state = newState()  -- coal supply 13, track has 14 spaces
        expect(Market.getPrice(state, COAL)).toBe(1)
    end)

    it("prices the last cube at the top of the track", function()
        local state = newState()
        state.coalMarket.supply = 1
        expect(Market.getPrice(state, COAL)).toBe(8)
    end)

    it("returns the max price when the market is empty", function()
        local state = newState()
        state.coalMarket.supply = 0
        expect(Market.getPrice(state, COAL)).toBe(8)
    end)
end)

describe("Market.getPrice - iron ladder", function()
    it("prices the next cube at default supply", function()
        local state = newState()  -- iron supply 8, track has 10 spaces
        expect(Market.getPrice(state, IRON)).toBe(2)
    end)

    it("returns the max price when the iron market is empty", function()
        local state = newState()
        state.ironMarket.supply = 0
        expect(Market.getPrice(state, IRON)).toBe(6)
    end)
end)

-- ============================================================
-- buyFromMarket — rising price per unit, supply decreases
-- ============================================================

describe("Market.buyFromMarket", function()
    it("charges a rising price per unit and lowers supply", function()
        local state = newState()  -- coal supply 13
        local player = GameState.getPlayer(state, "White")
        local total = Market.buyFromMarket(state, "White", COAL, 2)
        expect(total).toBe(3)                                   -- £1 then £2
        expect(state.coalMarket.supply).toBe(11)
        expect(player.money).toBe(Constants.INITIAL_MONEY - 3)
        expect(player.spentThisRound).toBe(3)
    end)
end)

-- ============================================================
-- returnToMarket — refills, capped at track max
-- ============================================================

describe("Market.returnToMarket", function()
    it("raises supply and caps at the track maximum", function()
        local state = newState()
        state.coalMarket.supply = 11
        Market.returnToMarket(state, COAL, 5)   -- 11 + 5 = 16, capped at 14
        expect(state.coalMarket.supply).toBe(14)
    end)
end)

-- ============================================================
-- estimateCost — matches buyFromMarket without mutating state
-- ============================================================

describe("Market.estimateCost", function()
    it("equals the real buy cost and does not mutate state", function()
        local state = newState()  -- coal supply 13
        local estimate = Market.estimateCost(state, COAL, 2)
        expect(estimate).toBe(3)
        expect(state.coalMarket.supply).toBe(Constants.INITIAL_COAL_SUPPLY)  -- unchanged
    end)
end)
