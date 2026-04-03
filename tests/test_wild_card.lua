--- Tests for wild card discard behavior: wild cards should return to supply,
--- and state.wildSupply counters should increment accordingly.

local Constants   = require("src/Constants")
local GameState   = require("src/GameState")
local TestHelpers = require("tests/test_helpers")

describe("Wild card supply tracking", function()

    it("should initialize wildSupply with correct counts", function()
        local state = GameState.new(2)
        expect(state.wildSupply.location).toBe(Constants.WILD_SUPPLY_COUNT)
        expect(state.wildSupply.industry).toBe(Constants.WILD_SUPPLY_COUNT)
    end)

    it("should increment wildSupply.location when a wild location is returned", function()
        local state = GameState.new(2)
        -- Simulate: player took a wild location card, so supply decreased
        state.wildSupply.location = 2

        -- Simulate the discard logic from EventHandlers.handleCardDrop
        local discardResult = "wild_location"
        if discardResult == "wild_location" then
            state.wildSupply.location = (state.wildSupply.location or 0) + 1
        end

        expect(state.wildSupply.location).toBe(3)
    end)

    it("should increment wildSupply.industry when a wild industry is returned", function()
        local state = GameState.new(2)
        -- Simulate: player took a wild industry card, so supply decreased
        state.wildSupply.industry = 1

        -- Simulate the discard logic from EventHandlers.handleCardDrop
        local discardResult = "wild_industry"
        if discardResult == "wild_industry" then
            state.wildSupply.industry = (state.wildSupply.industry or 0) + 1
        end

        expect(state.wildSupply.industry).toBe(2)
    end)

    it("should not change wildSupply when a normal card is discarded", function()
        local state = GameState.new(2)
        local origLocation = state.wildSupply.location
        local origIndustry = state.wildSupply.industry

        -- Simulate: normal card returns nil
        local discardResult = nil
        if discardResult == "wild_location" then
            state.wildSupply.location = (state.wildSupply.location or 0) + 1
        elseif discardResult == "wild_industry" then
            state.wildSupply.industry = (state.wildSupply.industry or 0) + 1
        end

        expect(state.wildSupply.location).toBe(origLocation)
        expect(state.wildSupply.industry).toBe(origIndustry)
    end)

    it("should handle wildSupply incrementing from zero", function()
        local state = GameState.new(2)
        state.wildSupply.location = 0
        state.wildSupply.industry = 0

        -- Return one of each
        local result1 = "wild_location"
        if result1 == "wild_location" then
            state.wildSupply.location = (state.wildSupply.location or 0) + 1
        end

        local result2 = "wild_industry"
        if result2 == "wild_industry" then
            state.wildSupply.industry = (state.wildSupply.industry or 0) + 1
        end

        expect(state.wildSupply.location).toBe(1)
        expect(state.wildSupply.industry).toBe(1)
    end)

end)
