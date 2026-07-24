--- Regression tests for end-of-era scoring — pins current VP totals for a
--- representative board so the ActionEngine refactor (and later live-scoring
--- work) cannot silently change scoring output. Part of issue #5.

local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Scoring   = require("src/Scoring")
local Tile      = require("src/Tile")

--- Build a fixed 2-player board:
---   White: cotton L1 (flipped) at Worcester_1     -> vp 5, linkIcons 1
---          manufacturer L1 (flipped) at Birmingham_2 -> vp 3, linkIcons 2
---          cotton L2 (UNFLIPPED) at Kidderminster_2  -> not scored
---          link Birmingham-Worcester (adjacent to both flipped buildings)
---   White income level = 10 (default)
local function scoredState()
    local state = GameState.new(2)

    local function placeFlipped(slotId, industry, level)
        local slot = GameState.getSlot(state, slotId)
        slot.occupant = "White"
        slot.tile = Tile.new(industry, level)
        slot.tile.flipped = true
    end

    placeFlipped("Worcester_1", Constants.Industry.COTTON, 1)          -- vp5, icons1
    placeFlipped("Birmingham_2", Constants.Industry.MANUFACTURER, 1)   -- vp3, icons2

    -- An unflipped building must not score.
    local kg = GameState.getSlot(state, "Kidderminster_2")
    kg.occupant = "White"
    kg.tile = Tile.new(Constants.Industry.COTTON, 2)  -- unflipped

    state.board.links["Birmingham-Worcester"].owner = "White"
    return state
end

-- ============================================================
-- Building / link / income component scoring
-- ============================================================

describe("Scoring - building VP", function()
    it("sums VP of the player's flipped buildings only", function()
        local state = scoredState()
        -- 5 (cotton L1) + 3 (manufacturer L1); unflipped cotton L2 excluded
        expect(Scoring.scoreBuildingVP(state, "White")).toBe(8)
    end)

    it("scores 0 for a player with no buildings", function()
        local state = scoredState()
        expect(Scoring.scoreBuildingVP(state, "Purple")).toBe(0)
    end)
end)

describe("Scoring - link VP", function()
    it("sums link icons of flipped buildings adjacent to the player's links", function()
        local state = scoredState()
        -- Birmingham-Worcester touches Birmingham (manufacturer icons 2)
        -- and Worcester (cotton icons 1) = 3
        expect(Scoring.scoreLinkVP(state, "White")).toBe(3)
    end)

    it("scores 0 for a player with no links", function()
        local state = scoredState()
        expect(Scoring.scoreLinkVP(state, "Purple")).toBe(0)
    end)
end)

describe("Scoring - income VP", function()
    it("equals the player's income level", function()
        local state = scoredState()
        expect(Scoring.scoreIncomeVP(state, "White")).toBe(10)
    end)
end)

-- ============================================================
-- End-of-era scoring
-- ============================================================

describe("Scoring - end of era (non-final: no income)", function()
    it("pins building + link totals and adds them to player VP", function()
        local state = scoredState()
        local results = Scoring.scoreEndOfEra(state, false)
        expect(results["White"].buildingVP).toBe(8)
        expect(results["White"].linkVP).toBe(3)
        expect(results["White"].incomeVP).toBe(0)
        expect(results["White"].totalEraVP).toBe(11)
        -- p.vp started at 0 and gains the era total
        expect(results["White"].totalVP).toBe(11)
    end)
end)

describe("Scoring - end of era (final: includes income)", function()
    it("adds income level as VP for the final scoring", function()
        local state = scoredState()
        local results = Scoring.scoreEndOfEra(state, true)
        expect(results["White"].incomeVP).toBe(10)
        expect(results["White"].totalEraVP).toBe(21)  -- 8 + 3 + 10
    end)
end)
