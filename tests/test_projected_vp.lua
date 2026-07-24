--- Tests for the live VP tracking / projected VP subsystem (issues #10/#11).
---
--- Scoring.confirmedTotals is the pure "what should the physical score
--- marker show" computation (issue #10) — tested here at the logic level,
--- including through a full ActionEngine commit + undo, since actual
--- marker movement (tts/ScoreTracker) needs manual TTS verification and
--- can't be exercised by these plain-Lua tests.
---
--- Scoring.projectedTotals is the pure per-source VP projection (issue
--- #11) — tested here for equivalence against actually running
--- Scoring.scoreEndOfEra on the same state, and for non-mutation.

local Constants    = require("src/Constants")
local GameState    = require("src/GameState")
local Actions      = require("src/Actions")
local ActionEngine = require("src/ActionEngine")
local Scoring      = require("src/Scoring")
local Tile         = require("src/Tile")
local helpers      = require("src/helpers")

local function resetEngine()
    ActionEngine.setPostCommitHook(nil)
    ActionEngine.clearLastCommit()
end

--- Same fixture shape as tests/test_scoring.lua's scoredState(): a 2-player
--- board with White holding two flipped buildings and one owned link.
---   Building VP: cotton L1 (5) + manufacturer L1 (3) = 8
---   Link VP: Birmingham-Worcester touches both flipped buildings = 3
local function scoredState(era)
    local state = GameState.new(2)
    state.era = era or Constants.Era.CANAL

    local function placeFlipped(slotId, industry, level)
        local slot = GameState.getSlot(state, slotId)
        slot.occupant = "White"
        slot.tile = Tile.new(industry, level)
        slot.tile.flipped = true
    end

    placeFlipped("Worcester_1", Constants.Industry.COTTON, 1)
    placeFlipped("Birmingham_2", Constants.Industry.MANUFACTURER, 1)
    state.board.links["Birmingham-Worcester"].owner = "White"

    -- Some VP already confirmed from an earlier era / merchant bonus.
    GameState.getPlayer(state, "White").vp = 6

    return state
end

-- ============================================================
-- Scoring.confirmedTotals (issue #10 — marker-position source of truth)
-- ============================================================

describe("Scoring.confirmedTotals", function()
    it("reflects each player's current vp", function()
        local state = GameState.new(2)
        GameState.getPlayer(state, "White").vp = 12
        local totals = Scoring.confirmedTotals(state)
        expect(totals["White"]).toBe(12)
        expect(totals["Purple"]).toBe(0)
    end)

    it("updates immediately when a merchant VP bonus is sold", function()
        resetEngine()
        local state = GameState.new(2)
        local slot = GameState.getSlot(state, "Wolverhampton_1")
        slot.occupant = "White"
        slot.tile = {
            type = Constants.Industry.MANUFACTURER, level = 1, flipped = false,
            resources = {}, beerToSell = 0, incomeSpaces = 0, vp = 0,
        }
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"

        expect(Scoring.confirmedTotals(state)["White"]).toBe(0)

        local r = ActionEngine.execute(state, "sell", "White",
            { slotIds = { "Wolverhampton_1" }, merchantName = "Shrewsbury" })
        expect(r.success).toBeTrue()
        -- Shrewsbury bonus = +4 VP (src/BoardData.lua)
        expect(Scoring.confirmedTotals(state)["White"]).toBe(4)
    end)

    it("reverts to the pre-action total after undo (marker must follow)", function()
        resetEngine()
        local state = GameState.new(2)
        local slot = GameState.getSlot(state, "Wolverhampton_1")
        slot.occupant = "White"
        slot.tile = {
            type = Constants.Industry.MANUFACTURER, level = 1, flipped = false,
            resources = {}, beerToSell = 0, incomeSpaces = 0, vp = 0,
        }
        state.board.links["Shrewsbury-Wolverhampton"].owner = "White"

        local r = ActionEngine.execute(state, "sell", "White",
            { slotIds = { "Wolverhampton_1" }, merchantName = "Shrewsbury" })
        expect(r.success).toBeTrue()
        expect(Scoring.confirmedTotals(state)["White"]).toBe(4)

        local u = ActionEngine.undo(state)
        expect(u.success).toBeTrue()
        expect(Scoring.confirmedTotals(state)["White"]).toBe(0)
    end)
end)

-- ============================================================
-- Scoring.projectedTotals (issue #11 — pure projection)
-- ============================================================

describe("Scoring.projectedTotals - equivalence with era-end scoring", function()
    it("matches scoreEndOfEra(state, false) during the Canal era (no income)", function()
        local state = scoredState(Constants.Era.CANAL)
        local projected = Scoring.projectedTotals(state)

        local copy = helpers.deepCopy(state)
        local results = Scoring.scoreEndOfEra(copy, false)

        for _, color in ipairs(state.turnOrder) do
            expect(projected[color].total).toBe(results[color].totalVP)
            expect(projected[color].buildings).toBe(results[color].buildingVP)
            expect(projected[color].links).toBe(results[color].linkVP)
            expect(projected[color].income).toBe(results[color].incomeVP)
        end
    end)

    it("matches scoreEndOfEra(state, true) during the Rail era (income included)", function()
        local state = scoredState(Constants.Era.RAIL)
        local projected = Scoring.projectedTotals(state)

        local copy = helpers.deepCopy(state)
        local results = Scoring.scoreEndOfEra(copy, true)

        for _, color in ipairs(state.turnOrder) do
            expect(projected[color].total).toBe(results[color].totalVP)
            expect(projected[color].income).toBe(results[color].incomeVP)
        end
    end)

    it("does not mutate the input state", function()
        local state = scoredState(Constants.Era.CANAL)
        local vpBefore = GameState.getPlayer(state, "White").vp

        Scoring.projectedTotals(state)

        expect(GameState.getPlayer(state, "White").vp).toBe(vpBefore)
    end)
end)

describe("Scoring.projectedTotals - per-source breakdown", function()
    it("splits confirmed / buildings / links / income for the Canal era", function()
        local state = scoredState(Constants.Era.CANAL)
        local p = Scoring.projectedTotals(state)["White"]

        expect(p.confirmed).toBe(6)
        expect(p.buildings).toBe(8)
        expect(p.links).toBe(3)
        expect(p.income).toBe(0)
        expect(p.total).toBe(17)
    end)

    it("includes income once in the Rail era", function()
        local state = scoredState(Constants.Era.RAIL)
        local p = Scoring.projectedTotals(state)["White"]

        expect(p.income).toBe(10)  -- default income level
        expect(p.total).toBe(6 + 8 + 3 + 10)
    end)

    it("scores 0 across the board for a player with nothing built", function()
        local state = scoredState(Constants.Era.CANAL)
        local p = Scoring.projectedTotals(state)["Purple"]

        expect(p.confirmed).toBe(0)
        expect(p.buildings).toBe(0)
        expect(p.links).toBe(0)
        expect(p.total).toBe(0)
    end)
end)
