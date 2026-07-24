--- Regression tests for Actions.develop and Actions.loan — full post-action
--- state (money, spentThisRound, income, iron consumption, tile removal).
--- Part of issue #5.

local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Actions   = require("src/Actions")

local function newState()
    return GameState.new(2)
end

--- Total tiles across every unbuilt industry stack.
local function totalUnbuilt(player)
    local n = 0
    for _, stack in pairs(player.unbuiltTiles) do
        n = n + #stack
    end
    return n
end

-- ============================================================
-- Loan
-- ============================================================

describe("Actions.loan - full post-action state", function()
    it("adds £30 and drops income by 3 levels to the top space of the new level", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        -- income level 10, space 0 by default
        local result = Actions.loan(state, "White")
        expect(result.success).toBeTrue()
        expect(player.money).toBe(Constants.INITIAL_MONEY + Constants.LOAN_AMOUNT)  -- 17 + 30
        expect(player.incomeLevel).toBe(7)   -- 10 - 3
        expect(player.incomeSpace).toBe(1)   -- top space of level 7 (2 spaces -> index 1)
    end)

    it("does not spend money (loan is a gain, not a spend)", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        Actions.loan(state, "White")
        expect(player.spentThisRound).toBe(0)
    end)
end)

-- ============================================================
-- Develop
-- ============================================================

describe("Actions.develop - full post-action state", function()
    it("consumes 1 iron from market and removes exactly one developable tile", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        -- No board iron -> iron is bought from the market.
        state.ironMarket.supply = 5
        local before = totalUnbuilt(player)

        local result = Actions.develop(state, "White", { count = 1 })
        expect(result.success).toBeTrue()
        -- Iron price at supply 5 is £3 (iron track position 6).
        expect(player.money).toBe(Constants.INITIAL_MONEY - 3)
        expect(player.spentThisRound).toBe(3)     -- market purchase records spending
        expect(state.ironMarket.supply).toBe(4)   -- one cube taken
        expect(totalUnbuilt(player)).toBe(before - 1)
    end)

    it("removes the lowest-level developable tile (brewery L1, alphabetical tiebreak)", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        state.ironMarket.supply = 5
        local breweryBefore = #player.unbuiltTiles[Constants.Industry.BREWERY]

        Actions.develop(state, "White", { count = 1 })
        -- brewery, coal, cotton, iron, manufacturer all have a level-1 tile;
        -- alphabetical tiebreak removes the brewery first.
        expect(#player.unbuiltTiles[Constants.Industry.BREWERY]).toBe(breweryBefore - 1)
    end)

    it("develops two tiles when count = 2", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        state.ironMarket.supply = 8
        local before = totalUnbuilt(player)
        local result = Actions.develop(state, "White", { count = 2 })
        expect(result.success).toBeTrue()
        expect(totalUnbuilt(player)).toBe(before - 2)
    end)
end)
