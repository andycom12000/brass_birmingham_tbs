--- Tests for Farm Brewery locations (#6).

local Constants   = require("src/Constants")
local BoardData   = require("src/BoardData")
local GameState   = require("src/GameState")
local Validation  = require("src/Validation")
local TestHelpers = require("tests/test_helpers")

-- ============================================================
-- BoardData: farm brewery cities exist
-- ============================================================

describe("BoardData - Farm Brewery cities", function()
    it("should have Farm Brewery 1 with isFarmBrewery flag", function()
        local fb1 = BoardData.cities["Farm Brewery 1"]
        expect(fb1 ~= nil).toBeTrue()
        expect(fb1.isFarmBrewery).toBeTrue()
    end)

    it("should have Farm Brewery 2 with isFarmBrewery flag", function()
        local fb2 = BoardData.cities["Farm Brewery 2"]
        expect(fb2 ~= nil).toBeTrue()
        expect(fb2.isFarmBrewery).toBeTrue()
    end)

    it("Farm Brewery 1 should have exactly 1 BREWERY slot", function()
        local fb1 = BoardData.cities["Farm Brewery 1"]
        expect(#fb1.slots).toBe(1)
        expect(fb1.slots[1].id).toBe("FarmBrewery1_1")
        expect(fb1.slots[1].types[1]).toBe(Constants.Industry.BREWERY)
    end)

    it("Farm Brewery 2 should have exactly 1 BREWERY slot", function()
        local fb2 = BoardData.cities["Farm Brewery 2"]
        expect(#fb2.slots).toBe(1)
        expect(fb2.slots[1].id).toBe("FarmBrewery2_1")
        expect(fb2.slots[1].types[1]).toBe(Constants.Industry.BREWERY)
    end)
end)

-- ============================================================
-- BoardData: farm brewery links
-- ============================================================

describe("BoardData - Farm Brewery links", function()
    it("Farm Brewery 1 should connect to Kidderminster", function()
        local link = BoardData.links["Farm Brewery 1-Kidderminster"]
        expect(link ~= nil).toBeTrue()
        expect(link.cities[1]).toBe("Farm Brewery 1")
        expect(link.cities[2]).toBe("Kidderminster")
    end)

    it("Farm Brewery 1 should connect to Worcester", function()
        local link = BoardData.links["Farm Brewery 1-Worcester"]
        expect(link ~= nil).toBeTrue()
        expect(link.cities[1]).toBe("Farm Brewery 1")
        expect(link.cities[2]).toBe("Worcester")
    end)

    it("Farm Brewery 2 should connect to Cannock", function()
        local link = BoardData.links["Cannock-Farm Brewery 2"]
        expect(link ~= nil).toBeTrue()
        expect(link.cities[1]).toBe("Cannock")
        expect(link.cities[2]).toBe("Farm Brewery 2")
    end)

    it("Farm Brewery 2 should connect to Walsall", function()
        local link = BoardData.links["Farm Brewery 2-Walsall"]
        expect(link ~= nil).toBeTrue()
        expect(link.cities[1]).toBe("Farm Brewery 2")
        expect(link.cities[2]).toBe("Walsall")
    end)

    it("existing Kidderminster-Worcester link should still exist", function()
        local link = BoardData.links["Kidderminster-Worcester"]
        expect(link ~= nil).toBeTrue()
    end)

    it("existing Cannock-Walsall link should still exist", function()
        local link = BoardData.links["Cannock-Walsall"]
        expect(link ~= nil).toBeTrue()
    end)
end)

-- ============================================================
-- BoardData: adjacency auto-built for farm breweries
-- ============================================================

describe("BoardData - Farm Brewery adjacency", function()
    it("Farm Brewery 1 should have 2 adjacent links", function()
        local adj = BoardData.adjacency["Farm Brewery 1"]
        expect(adj ~= nil).toBeTrue()
        expect(#adj).toBe(2)
    end)

    it("Farm Brewery 2 should have 2 adjacent links", function()
        local adj = BoardData.adjacency["Farm Brewery 2"]
        expect(adj ~= nil).toBeTrue()
        expect(#adj).toBe(2)
    end)
end)

-- ============================================================
-- Farm breweries not removed for any player count
-- ============================================================

describe("BoardData - Farm Brewery player count removal", function()
    it("should not remove farm breweries for 2-player game", function()
        local removed = BoardData.getRemovedCities(2)
        for _, name in ipairs(removed) do
            expect(name ~= "Farm Brewery 1").toBeTrue()
            expect(name ~= "Farm Brewery 2").toBeTrue()
        end
    end)

    it("should not remove farm breweries for 3-player game", function()
        local removed = BoardData.getRemovedCities(3)
        for _, name in ipairs(removed) do
            expect(name ~= "Farm Brewery 1").toBeTrue()
            expect(name ~= "Farm Brewery 2").toBeTrue()
        end
    end)

    it("farm breweries should exist in 2-player game state", function()
        local state = GameState.new(2)
        expect(state.board.cities["Farm Brewery 1"] ~= nil).toBeTrue()
        expect(state.board.cities["Farm Brewery 2"] ~= nil).toBeTrue()
    end)
end)

-- ============================================================
-- Validation: farm brewery build restrictions
-- ============================================================

describe("Validation - Farm Brewery build with INDUSTRY card", function()
    it("should allow building brewery at farm brewery with INDUSTRY card", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50 })
        -- Give the player presence so network check applies
        TestHelpers.placeTile(state, "Birmingham_1", color, {
            type = Constants.Industry.IRON, level = 1, resources = {}
        })
        -- Place a link connecting Birmingham to Walsall, then Walsall to Farm Brewery 2
        state.board.links["Birmingham-Walsall"].owner = color
        state.board.links["Farm Brewery 2-Walsall"].owner = color

        local result = Validation.canBuild(state, color, {
            cardType = Constants.CardType.INDUSTRY,
            location = nil,
            industryType = Constants.Industry.BREWERY,
            level = 1,
            slotId = "FarmBrewery2_1",
        })
        expect(result.valid).toBeTrue()
    end)
end)

describe("Validation - Farm Brewery build with WILD_INDUSTRY card", function()
    it("should allow building brewery at farm brewery with WILD_INDUSTRY card", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50 })
        TestHelpers.placeTile(state, "Birmingham_1", color, {
            type = Constants.Industry.IRON, level = 1, resources = {}
        })
        state.board.links["Birmingham-Walsall"].owner = color
        state.board.links["Farm Brewery 2-Walsall"].owner = color

        local result = Validation.canBuild(state, color, {
            cardType = Constants.CardType.WILD_INDUSTRY,
            location = nil,
            industryType = Constants.Industry.BREWERY,
            level = 1,
            slotId = "FarmBrewery2_1",
        })
        expect(result.valid).toBeTrue()
    end)
end)

describe("Validation - Farm Brewery rejects LOCATION card", function()
    it("should reject building at farm brewery with LOCATION card", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50 })

        local result = Validation.canBuild(state, color, {
            cardType = Constants.CardType.LOCATION,
            location = "Farm Brewery 2",
            industryType = Constants.Industry.BREWERY,
            level = 1,
            slotId = "FarmBrewery2_1",
        })
        expect(result.valid).toBeFalse()
    end)
end)

describe("Validation - Farm Brewery rejects WILD_LOCATION card", function()
    it("should reject building at farm brewery with WILD_LOCATION card", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50 })

        local result = Validation.canBuild(state, color, {
            cardType = Constants.CardType.WILD_LOCATION,
            location = "Farm Brewery 2",
            industryType = Constants.Industry.BREWERY,
            level = 1,
            slotId = "FarmBrewery2_1",
        })
        expect(result.valid).toBeFalse()
    end)
end)

describe("Validation - Farm Brewery rejects non-brewery industry", function()
    it("should reject building non-brewery at farm brewery (slot type mismatch)", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50 })

        local result = Validation.canBuild(state, color, {
            cardType = Constants.CardType.INDUSTRY,
            location = nil,
            industryType = Constants.Industry.COTTON,
            level = 1,
            slotId = "FarmBrewery1_1",
        })
        expect(result.valid).toBeFalse()
    end)
end)
