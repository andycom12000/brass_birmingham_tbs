--- Tests for income phase integration with round progression.

local Constants   = require("src/Constants")
local GameState   = require("src/GameState")
local TurnManager = require("src/TurnManager")
local IncomeTrack = require("src/IncomeTrack")
local TestHelpers = require("tests/test_helpers")

--- Helper: exhaust all actions in the current round to trigger startNewRound.
--- For a 2-player game, round 1 (canal era) = 1 action each = 2 total actions.
--- Subsequent rounds = 2 actions each = 4 total actions.
local function exhaustRound(state)
    local totalActions = 0
    for _, color in ipairs(state.turnOrder) do
        totalActions = totalActions + TurnManager.getActionsThisTurn(state)
    end
    for _ = 1, totalActions do
        TurnManager.endAction(state)
    end
end

describe("Income Phase - Round Progression Integration", function()
    it("should collect income when a new round starts", function()
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local color2 = state.turnOrder[2]
        local p1 = GameState.getPlayer(state, color1)
        local p2 = GameState.getPlayer(state, color2)

        -- Both start at income level 10, money 17
        expect(p1.incomeLevel).toBe(10)
        expect(p1.money).toBe(17)
        expect(p2.money).toBe(17)

        local moneyBefore1 = p1.money
        local moneyBefore2 = p2.money
        local income1 = IncomeTrack.levelToIncome(p1.incomeLevel)
        local income2 = IncomeTrack.levelToIncome(p2.incomeLevel)

        -- Round 1 (canal era): 1 action per player = 2 endAction calls
        expect(state.round).toBe(1)
        exhaustRound(state)
        expect(state.round).toBe(2)

        -- Both players should have gained income
        expect(p1.money).toBe(moneyBefore1 + income1)
        expect(p2.money).toBe(moneyBefore2 + income2)
    end)

    it("should run income phase BEFORE turn reordering", function()
        -- Set up so player 1 spent more than player 2 (should swap after reorder)
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local color2 = state.turnOrder[2]
        local p1 = GameState.getPlayer(state, color1)
        local p2 = GameState.getPlayer(state, color2)

        -- Give player 1 higher income and make them spend more
        p1.incomeLevel = 15
        p1.spentThisRound = 100
        p2.incomeLevel = 5
        p2.spentThisRound = 10

        local moneyBefore1 = p1.money
        local moneyBefore2 = p2.money

        -- Call startNewRound directly to check ordering
        TurnManager.startNewRound(state)

        -- Income should be based on pre-reorder income levels
        -- (incomePhase runs first, before reorderTurnOrder)
        expect(p1.money).toBe(moneyBefore1 + 15)
        expect(p2.money).toBe(moneyBefore2 + 5)

        -- After reorder, lower spender (player 2) should be first
        expect(state.turnOrder[1]).toBe(color2)
        expect(state.turnOrder[2]).toBe(color1)
    end)

    it("should handle negative income correctly during round transition", function()
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local p1 = GameState.getPlayer(state, color1)

        p1.incomeLevel = -3
        p1.money = 10

        exhaustRound(state)

        -- Should have paid 3 from negative income
        expect(p1.money).toBe(10 - 3)
    end)

    it("should lose VP on income shortfall during round transition", function()
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local p1 = GameState.getPlayer(state, color1)

        p1.incomeLevel = -5
        p1.money = 2
        p1.vp = 20

        exhaustRound(state)

        -- Owed 5, had 2, shortfall = 3 VP lost
        expect(p1.money).toBe(0)
        expect(p1.vp).toBe(17)
    end)

    it("should handle zero income without changing money", function()
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local p1 = GameState.getPlayer(state, color1)

        p1.incomeLevel = 0
        p1.money = 10

        exhaustRound(state)

        expect(p1.money).toBe(10)
    end)

    it("should collect income for all players in a multi-round game", function()
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local color2 = state.turnOrder[2]
        local p1 = GameState.getPlayer(state, color1)
        local p2 = GameState.getPlayer(state, color2)

        p1.incomeLevel = 5
        p2.incomeLevel = 8

        local m1 = p1.money
        local m2 = p2.money

        -- Complete round 1
        exhaustRound(state)
        expect(state.round).toBe(2)
        expect(p1.money).toBe(m1 + 5)
        expect(p2.money).toBe(m2 + 8)

        m1 = p1.money
        m2 = p2.money

        -- Complete round 2 (2 actions per player now)
        exhaustRound(state)
        expect(state.round).toBe(3)
        expect(p1.money).toBe(m1 + 5)
        expect(p2.money).toBe(m2 + 8)
    end)

    it("should handle income correctly with various income levels", function()
        local state = GameState.new(2)
        local color1 = state.turnOrder[1]
        local p1 = GameState.getPlayer(state, color1)

        -- Test income at level 10 (default)
        expect(IncomeTrack.levelToIncome(10)).toBe(10)
        expect(IncomeTrack.levelToIncome(0)).toBe(0)
        expect(IncomeTrack.levelToIncome(-10)).toBe(-10)
        expect(IncomeTrack.levelToIncome(30)).toBe(30)
        expect(IncomeTrack.levelToIncome(1)).toBe(1)
    end)
end)
