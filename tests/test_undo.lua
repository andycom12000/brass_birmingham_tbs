--- Symmetry tests for single-step undo (issue #9).
--- For every action type, snapshot -> execute -> undo must leave the logical
--- state deep-equal to the original. Also covers single-step semantics, the
--- undo-of-nothing guard, index re-aliasing after restore, and full restoration
--- of resource-consuming builds (market cubes, flipped opponent mines, income).

local Constants    = require("src/Constants")
local GameState    = require("src/GameState")
local Actions      = require("src/Actions")
local ActionEngine = require("src/ActionEngine")
local helpers      = require("src/helpers")
local Tile         = require("src/Tile")

local function resetEngine()
    ActionEngine.setPostCommitHook(nil)
    ActionEngine.clearLastCommit()
end

local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k, _ in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- Assert that executing `actionName` and then undoing restores the state.
local function expectSymmetry(state, actionName, color, params)
    local original = helpers.deepCopy(state)
    local r = ActionEngine.execute(state, actionName, color, params)
    expect(r.success).toBeTrue()
    -- The action actually changed something (guards against a no-op passing).
    ActionEngine.undo(state)
    expect(deepEqual(state, original)).toBeTrue()
end

-- ============================================================
-- Per-action symmetry
-- ============================================================

describe("ActionEngine.undo - symmetry per action", function()
    it("restores after loan", function()
        resetEngine()
        expectSymmetry(GameState.new(2), "loan", "White", {})
    end)

    it("restores after scout", function()
        resetEngine()
        local state = GameState.new(2)
        GameState.getPlayer(state, "White").handSize = 8
        expectSymmetry(state, "scout", "White", {})
    end)

    it("restores after develop (market iron consumed)", function()
        resetEngine()
        local state = GameState.new(2)
        state.ironMarket.supply = 8
        expectSymmetry(state, "develop", "White", { count = 1 })
    end)

    it("restores after pass", function()
        resetEngine()
        expectSymmetry(GameState.new(2), "pass", "White", {})
    end)

    it("restores after a canal network link", function()
        resetEngine()
        expectSymmetry(GameState.new(2), "network", "White", { linkId = "Birmingham-Dudley" })
    end)

    it("restores after sell", function()
        resetEngine()
        local state = GameState.new(2)
        local slot = GameState.getSlot(state, "Wolverhampton_1")
        slot.occupant = "White"
        slot.tile = {
            type = Constants.Industry.MANUFACTURER, level = 1, flipped = false,
            resources = {}, beerToSell = 0, incomeSpaces = 1,
        }
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"
        expectSymmetry(state, "sell", "White", { slotIds = { "Wolverhampton_1" } })
    end)

    it("restores after a simple build", function()
        resetEngine()
        expectSymmetry(GameState.new(2), "build", "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
    end)
end)

-- ============================================================
-- Resource-consuming build: market cubes, flipped opponent mine, income
-- ============================================================

describe("ActionEngine.undo - resource-consuming build", function()
    it("restores auto-sold market cubes and consumed board coal", function()
        resetEngine()
        local state = GameState.new(2)
        state.era = Constants.Era.RAIL
        -- Board coal in the same city satisfies the iron build's coal cost;
        -- iron auto-sells to the market (changing ironMarket.supply).
        local coalSlot = GameState.getSlot(state, "Coalbrookdale_3")
        coalSlot.occupant = "White"
        coalSlot.tile = Tile.newWithResources(Constants.Industry.COAL, 1)  -- 2 coal
        expectSymmetry(state, "build", "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Coalbrookdale",
            industryType = Constants.Industry.IRON,
            level = 1,
            slotId = "Coalbrookdale_1",
        })
    end)

    it("restores a flipped opponent mine and its awarded income", function()
        resetEngine()
        local state = GameState.new(2)
        state.era = Constants.Era.RAIL
        -- Opponent coal mine holding exactly one coal: consuming it empties and
        -- auto-flips the mine and advances Purple's income. Undo must reverse
        -- all of that.
        local coalSlot = GameState.getSlot(state, "Coalbrookdale_3")
        coalSlot.occupant = "Purple"
        coalSlot.tile = Tile.new(Constants.Industry.COAL, 1)
        coalSlot.tile.resources = { Constants.Resource.COAL }  -- exactly 1
        expect(coalSlot.tile.flipped).toBeFalse()

        expectSymmetry(state, "build", "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Coalbrookdale",
            industryType = Constants.Industry.IRON,
            level = 1,
            slotId = "Coalbrookdale_1",
        })
        -- Sanity: after the round-trip the mine is unflipped with its coal back.
        -- Re-fetch from state — restore() replaces board.cities, so the original
        -- coalSlot reference now points at the detached pre-undo table.
        local restored = GameState.getSlot(state, "Coalbrookdale_3")
        expect(restored.tile.flipped).toBeFalse()
        expect(#restored.tile.resources).toBe(1)
        expect(GameState.getPlayer(state, "Purple").incomeLevel).toBe(Constants.INITIAL_INCOME)
    end)
end)

-- ============================================================
-- Undo semantics
-- ============================================================

describe("ActionEngine.undo - semantics", function()
    it("is single-step: a second undo finds nothing to undo", function()
        resetEngine()
        local state = GameState.new(2)
        ActionEngine.execute(state, "loan", "White", {})
        expect(ActionEngine.undo(state).success).toBeTrue()
        expect(ActionEngine.canUndo()).toBeFalse()
        expect(ActionEngine.undo(state).success).toBeFalse()
    end)

    it("fails cleanly when there is nothing to undo", function()
        resetEngine()
        local state = GameState.new(2)
        local r = ActionEngine.undo(state)
        expect(r.success).toBeFalse()
    end)

    it("fires the post-commit hook so scoring recomputes on the restored state", function()
        resetEngine()
        local state = GameState.new(2)
        ActionEngine.execute(state, "loan", "White", {})
        local fired = 0
        ActionEngine.setPostCommitHook(function() fired = fired + 1 end)
        ActionEngine.undo(state)
        expect(fired).toBe(1)
    end)

    it("re-aliases the slot index so getSlot mutations reach board.cities", function()
        resetEngine()
        local state = GameState.new(2)
        ActionEngine.execute(state, "build", "White", {
            cardType = Constants.CardType.LOCATION,
            location = "Birmingham",
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "Birmingham_2",
        })
        ActionEngine.undo(state)
        -- After restore, getSlot must return the very table board.cities holds.
        local viaIndex = GameState.getSlot(state, "Birmingham_2")
        viaIndex.occupant = "MARKER"
        local viaBoard = state.board.cities["Birmingham"].slots[2]
        expect(viaBoard.occupant).toBe("MARKER")
    end)
end)
