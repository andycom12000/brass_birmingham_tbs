--- Test card deduction: Action functions should NOT decrement handSize.
--- The TTS layer (handleCardDrop) is solely responsible for the -1 deduction.

local Constants   = require("src/Constants")
local GameState   = require("src/GameState")
local Actions     = require("src/Actions")
local Validation  = require("src/Validation")
local TestHelpers = require("tests/test_helpers")

describe("Card Deduction — Loan", function()
    it("should NOT decrement handSize", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50, handSize = 8 })
        local before = player.handSize
        local result = Actions.loan(state, color)
        expect(result.success).toBeTrue()
        expect(player.handSize).toBe(before)
    end)
end)

describe("Card Deduction — Develop", function()
    it("should NOT decrement handSize", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50, handSize = 8 })
        -- Ensure iron is available in market for develop
        state.ironMarket.supply = 5
        local result = Actions.develop(state, color, { count = 1 })
        expect(result.success).toBeTrue()
        expect(player.handSize).toBe(8)
    end)
end)

describe("Card Deduction — Scout", function()
    it("should NOT decrement handSize (net 0 from scout exchange)", function()
        local state, player, color = TestHelpers.createStateWithPlayer({
            money = 50,
            handSize = 8,
            hasWilds = false,
            scoutUsedThisRound = false,
        })
        state.wildSupply = { location = 4, industry = 4 }
        local before = player.handSize
        local result = Actions.scout(state, color)
        expect(result.success).toBeTrue()
        -- Scout discards 2 and gains 2 wilds = net 0
        -- The played card deduction is handled by TTS layer, not here
        expect(player.handSize).toBe(before)
    end)

    it("should set hasWilds to true", function()
        local state, player, color = TestHelpers.createStateWithPlayer({
            money = 50,
            handSize = 8,
            hasWilds = false,
            scoutUsedThisRound = false,
        })
        state.wildSupply = { location = 4, industry = 4 }
        Actions.scout(state, color)
        expect(player.hasWilds).toBeTrue()
    end)

    it("should decrement wild supply", function()
        local state, player, color = TestHelpers.createStateWithPlayer({
            money = 50,
            handSize = 8,
            hasWilds = false,
            scoutUsedThisRound = false,
        })
        state.wildSupply = { location = 4, industry = 4 }
        Actions.scout(state, color)
        expect(state.wildSupply.location).toBe(3)
        expect(state.wildSupply.industry).toBe(3)
    end)
end)

describe("Card Deduction — Sell", function()
    it("should NOT decrement handSize", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ money = 50, handSize = 8 })
        -- Place a sellable cotton tile connected to a merchant
        -- Find a slot in a city that has a merchant connection
        -- Use Birmingham which connects to merchants via links
        local slotId = "Birmingham_1"
        local slot = GameState.getSlot(state, slotId)
        if slot then
            -- Place an unflipped cotton tile
            slot.occupant = color
            slot.tile = {
                type = Constants.Industry.COTTON,
                level = 1,
                flipped = false,
                resources = {},
                beerToSell = 0,
                incomeSpaces = 1,
            }
            -- Need a merchant connection — place a link to a merchant city
            -- Connect Birmingham to a merchant via network
            -- For simplicity, add a direct merchant connection test
            -- by placing the tile in a city already connected
            -- We need to make the Network module see a connection to a merchant
            -- Place a link between Birmingham and a merchant-connected city
            for linkId, link in pairs(state.board.links) do
                local linkData = require("src/BoardData").links[linkId]
                if linkData then
                    local touchesBirmingham = false
                    for _, c in ipairs(linkData.cities) do
                        if c == "Birmingham" then touchesBirmingham = true end
                    end
                    if touchesBirmingham then
                        link.owner = color
                        break
                    end
                end
            end

            -- Also check if any merchant city is connected
            -- We may need to connect through multiple links, so let's try
            -- a simpler approach: use Wolverhampton which connects to Shrewsbury merchant
            -- Actually, let's just test with a city that IS a merchant-adjacent city
        end

        -- Alternative approach: find a city adjacent to a merchant
        -- and place a tile there
        local BoardData = require("src/BoardData")
        local foundSlot = false
        for cityName, cityData in pairs(state.board.cities) do
            if cityData.slots and #cityData.slots > 0 then
                -- Check if any link connects this city to a merchant
                local adjLinks = BoardData.adjacency[cityName] or {}
                for _, linkId in ipairs(adjLinks) do
                    local linkData = BoardData.links[linkId]
                    if linkData then
                        for _, neighbor in ipairs(linkData.cities) do
                            if state.board.merchants[neighbor] then
                                -- Found a city adjacent to a merchant!
                                local testSlot = cityData.slots[1]
                                testSlot.occupant = color
                                testSlot.tile = {
                                    type = Constants.Industry.COTTON,
                                    level = 1,
                                    flipped = false,
                                    resources = {},
                                    beerToSell = 0,
                                    incomeSpaces = 1,
                                }
                                -- Place the link so there's a connection
                                state.board.links[linkId].owner = color
                                local result = Actions.sell(state, color, { slotIds = { testSlot.id } })
                                if result.success then
                                    expect(player.handSize).toBe(8)
                                    foundSlot = true
                                end
                                break
                            end
                        end
                    end
                    if foundSlot then break end
                end
            end
            if foundSlot then break end
        end
        if not foundSlot then
            -- Fallback: just verify loan doesn't decrement (sell setup too complex)
            -- This shouldn't happen but is a safety net
            error("Could not set up sell test scenario")
        end
    end)
end)

describe("Validation.canPass", function()
    it("should always return valid", function()
        local state, player, color = TestHelpers.createStateWithPlayer({})
        local result = Validation.canPass(state, color)
        expect(result.valid).toBeTrue()
    end)

    it("should return valid even with 0 handSize", function()
        local state, player, color = TestHelpers.createStateWithPlayer({ handSize = 0 })
        local result = Validation.canPass(state, color)
        expect(result.valid).toBeTrue()
    end)
end)
