--- Tests for income shortfall tile removal mechanics.

local Constants   = require("src/Constants")
local GameState   = require("src/GameState")
local BoardData   = require("src/BoardData")
local TurnManager = require("src/TurnManager")
local IncomeTrack = require("src/IncomeTrack")
local TestHelpers = require("tests/test_helpers")

local I = Constants.Industry

describe("TurnManager.calculateTileRefund", function()
    it("should return half the money cost rounded down for cotton Lv1", function()
        -- Cotton Lv1: money=12, so refund = floor(12/2) = 6
        expect(TurnManager.calculateTileRefund(I.COTTON, 1)).toBe(6)
    end)

    it("should return half the money cost rounded down for cotton Lv3", function()
        -- Cotton Lv3: money=16, so refund = floor(16/2) = 8
        expect(TurnManager.calculateTileRefund(I.COTTON, 3)).toBe(8)
    end)

    it("should return half the money cost rounded down for coal Lv1", function()
        -- Coal Lv1: money=5, so refund = floor(5/2) = 2
        expect(TurnManager.calculateTileRefund(I.COAL, 1)).toBe(2)
    end)

    it("should return half the money cost rounded down for iron Lv2", function()
        -- Iron Lv2: money=7, so refund = floor(7/2) = 3
        expect(TurnManager.calculateTileRefund(I.IRON, 2)).toBe(3)
    end)

    it("should return half the money cost rounded down for manufacturer Lv5", function()
        -- Manufacturer Lv5: money=16, so refund = floor(16/2) = 8
        expect(TurnManager.calculateTileRefund(I.MANUFACTURER, 5)).toBe(8)
    end)

    it("should return half the money cost rounded down for pottery Lv2", function()
        -- Pottery Lv2: money=0, so refund = floor(0/2) = 0
        expect(TurnManager.calculateTileRefund(I.POTTERY, 2)).toBe(0)
    end)

    it("should return half the money cost for brewery Lv1", function()
        -- Brewery Lv1: money=5, so refund = floor(5/2) = 2
        expect(TurnManager.calculateTileRefund(I.BREWERY, 1)).toBe(2)
    end)

    it("should return 0 for invalid industry/level", function()
        expect(TurnManager.calculateTileRefund("nonexistent", 1)).toBe(0)
        expect(TurnManager.calculateTileRefund(I.COTTON, 99)).toBe(0)
    end)
end)

describe("TurnManager.getRemovableTiles", function()
    it("should return tiles owned by the player on the board", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)

        -- Place a cotton Lv1 tile on Birmingham_1
        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.COTTON, level = 1 })

        local tiles = TurnManager.getRemovableTiles(state, color)
        expect(#tiles).toBe(1)
        expect(tiles[1].slotId).toBe("Birmingham_1")
        expect(tiles[1].cityName).toBe("Birmingham")
        expect(tiles[1].industryType).toBe(I.COTTON)
        expect(tiles[1].level).toBe(1)
        expect(tiles[1].refund).toBe(6) -- floor(12/2)
    end)

    it("should include both flipped and unflipped tiles", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)

        -- Place an unflipped tile
        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.COTTON, level = 1, flipped = false })
        -- Place a flipped tile
        TestHelpers.placeTile(state, "Birmingham_2", color, { type = I.COTTON, level = 2, flipped = true })

        local tiles = TurnManager.getRemovableTiles(state, color)
        expect(#tiles).toBe(2)
    end)

    it("should not return tiles owned by other players", function()
        local state = GameState.new(4)
        local color1 = TestHelpers.firstColor(state)
        local color2 = TestHelpers.secondColor(state)

        TestHelpers.placeTile(state, "Birmingham_1", color1, { type = I.COTTON, level = 1 })
        TestHelpers.placeTile(state, "Birmingham_2", color2, { type = I.IRON, level = 1 })

        local tiles = TurnManager.getRemovableTiles(state, color1)
        expect(#tiles).toBe(1)
        expect(tiles[1].slotId).toBe("Birmingham_1")
    end)

    it("should return empty list when player has no tiles on board", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)

        local tiles = TurnManager.getRemovableTiles(state, color)
        expect(#tiles).toBe(0)
    end)

    it("should return multiple tiles across different cities", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)

        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.COTTON, level = 1 })
        TestHelpers.placeTile(state, "Coventry_1", color, { type = I.MANUFACTURER, level = 1 })
        TestHelpers.placeTile(state, "Dudley_1", color, { type = I.COAL, level = 2 })

        local tiles = TurnManager.getRemovableTiles(state, color)
        expect(#tiles).toBe(3)
    end)
end)

describe("TurnManager.removeTileForDebt", function()
    it("should clear the slot and return the correct refund", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)

        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.COTTON, level = 1 })

        local slot = GameState.getSlot(state, "Birmingham_1")
        expect(slot.occupant).toBe(color)
        expect(slot.tile ~= nil).toBeTrue()

        local refund = TurnManager.removeTileForDebt(state, color, "Birmingham_1")
        expect(refund).toBe(6) -- floor(12/2)

        -- Slot should be cleared
        expect(slot.occupant == nil).toBeTrue()
        expect(slot.tile == nil).toBeTrue()
    end)

    it("should return 0 for a slot not owned by the player", function()
        local state = GameState.new(4)
        local color1 = TestHelpers.firstColor(state)
        local color2 = TestHelpers.secondColor(state)

        TestHelpers.placeTile(state, "Birmingham_1", color2, { type = I.COTTON, level = 1 })

        local refund = TurnManager.removeTileForDebt(state, color1, "Birmingham_1")
        expect(refund).toBe(0)

        -- Slot should not be modified
        local slot = GameState.getSlot(state, "Birmingham_1")
        expect(slot.occupant).toBe(color2)
    end)

    it("should return 0 for an empty slot", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)

        local refund = TurnManager.removeTileForDebt(state, color, "Birmingham_1")
        expect(refund).toBe(0)
    end)
end)

describe("TurnManager.resolveShortfallAsVP", function()
    it("should deduct VP equal to the remaining shortfall", function()
        local state = GameState.new(2)
        local color = TestHelpers.firstColor(state)
        local p = GameState.getPlayer(state, color)
        p.vp = 20

        TurnManager.resolveShortfallAsVP(state, color, 5)
        expect(p.vp).toBe(15)
    end)

    it("should allow VP to go negative", function()
        local state = GameState.new(2)
        local color = TestHelpers.firstColor(state)
        local p = GameState.getPlayer(state, color)
        p.vp = 2

        TurnManager.resolveShortfallAsVP(state, color, 5)
        expect(p.vp).toBe(-3)
    end)

    it("should not change VP when shortfall is 0 or negative", function()
        local state = GameState.new(2)
        local color = TestHelpers.firstColor(state)
        local p = GameState.getPlayer(state, color)
        p.vp = 20

        TurnManager.resolveShortfallAsVP(state, color, 0)
        expect(p.vp).toBe(20)

        TurnManager.resolveShortfallAsVP(state, color, -5)
        expect(p.vp).toBe(20)
    end)
end)

describe("TurnManager.incomePhase - shortfall return value", function()
    it("should return empty shortfalls when all players can pay", function()
        local state = GameState.new(2)
        local color1 = TestHelpers.firstColor(state)
        local color2 = TestHelpers.secondColor(state)
        local p1 = GameState.getPlayer(state, color1)
        local p2 = GameState.getPlayer(state, color2)

        p1.incomeLevel = -3
        p1.money = 10
        p2.incomeLevel = 5
        p2.money = 10

        local shortfalls = TurnManager.incomePhase(state)
        expect(#shortfalls).toBe(0)
        expect(p1.money).toBe(7)   -- 10 - 3
        expect(p2.money).toBe(15)  -- 10 + 5
    end)

    it("should return shortfall when player cannot pay full amount", function()
        local state = GameState.new(2)
        local color1 = TestHelpers.firstColor(state)
        local p1 = GameState.getPlayer(state, color1)

        p1.incomeLevel = -8
        p1.money = 3
        p1.vp = 20

        local shortfalls = TurnManager.incomePhase(state)
        expect(#shortfalls).toBe(1)
        expect(shortfalls[1].color).toBe(color1)
        expect(shortfalls[1].amount).toBe(5)   -- owed 8, had 3
        expect(p1.money).toBe(0)
        -- VP should NOT be deducted
        expect(p1.vp).toBe(20)
    end)

    it("should return shortfalls for multiple players", function()
        local state = GameState.new(2)
        local color1 = TestHelpers.firstColor(state)
        local color2 = TestHelpers.secondColor(state)
        local p1 = GameState.getPlayer(state, color1)
        local p2 = GameState.getPlayer(state, color2)

        p1.incomeLevel = -5
        p1.money = 1
        p2.incomeLevel = -10
        p2.money = 3

        local shortfalls = TurnManager.incomePhase(state)
        expect(#shortfalls).toBe(2)
        expect(shortfalls[1].amount).toBe(4)  -- 5 - 1
        expect(shortfalls[2].amount).toBe(7)  -- 10 - 3
    end)

    it("should return empty shortfalls for positive income", function()
        local state = GameState.new(2)
        local shortfalls = TurnManager.incomePhase(state)
        expect(#shortfalls).toBe(0)
    end)
end)

describe("Shortfall integration - tile removal then VP loss", function()
    it("should allow removing a tile to cover shortfall fully", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)
        local p = GameState.getPlayer(state, color)

        -- Place a cotton Lv1 tile (refund = 6)
        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.COTTON, level = 1 })

        -- Simulate a shortfall of 5
        p.money = 0
        p.vp = 20
        local remaining = 5

        -- Remove the tile
        local refund = TurnManager.removeTileForDebt(state, color, "Birmingham_1")
        expect(refund).toBe(6)

        remaining = remaining - refund
        -- Surplus of 1 should go to player as money
        if remaining < 0 then
            GameState.gainMoney(state, color, math.abs(remaining))
            remaining = 0
        end

        expect(remaining).toBe(0)
        expect(p.money).toBe(1)  -- surplus from refund
        expect(p.vp).toBe(20)    -- no VP lost
    end)

    it("should deduct VP for remaining shortfall after removing all tiles", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)
        local p = GameState.getPlayer(state, color)

        -- Place a pottery Lv2 tile (refund = 0, money cost is 0)
        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.POTTERY, level = 2 })

        p.money = 0
        p.vp = 20
        local remaining = 5

        -- Remove the tile (refund 0)
        local refund = TurnManager.removeTileForDebt(state, color, "Birmingham_1")
        expect(refund).toBe(0)

        remaining = remaining - refund
        expect(remaining).toBe(5)

        -- No more tiles to remove — resolve as VP loss
        local moreTiles = TurnManager.getRemovableTiles(state, color)
        expect(#moreTiles).toBe(0)

        TurnManager.resolveShortfallAsVP(state, color, remaining)
        expect(p.vp).toBe(15)
    end)

    it("should handle partial coverage: tile refund + VP loss", function()
        local state = GameState.new(4)
        local color = TestHelpers.firstColor(state)
        local p = GameState.getPlayer(state, color)

        -- Place a coal Lv1 tile (refund = 2)
        TestHelpers.placeTile(state, "Birmingham_1", color, { type = I.COAL, level = 1 })

        p.money = 0
        p.vp = 20
        local remaining = 5

        -- Remove the tile
        local refund = TurnManager.removeTileForDebt(state, color, "Birmingham_1")
        expect(refund).toBe(2)
        remaining = remaining - refund
        expect(remaining).toBe(3)

        -- No more tiles
        local moreTiles = TurnManager.getRemovableTiles(state, color)
        expect(#moreTiles).toBe(0)

        -- Remaining shortfall as VP loss
        TurnManager.resolveShortfallAsVP(state, color, remaining)
        expect(p.vp).toBe(17)
    end)

    it("should store pending shortfalls in startNewRound", function()
        local state = GameState.new(2)
        local color1 = TestHelpers.firstColor(state)
        local p1 = GameState.getPlayer(state, color1)

        p1.incomeLevel = -10
        p1.money = 2
        p1.vp = 30

        TurnManager.startNewRound(state)

        -- Shortfall should be stored, not resolved
        expect(state._pendingShortfalls ~= nil).toBeTrue()
        expect(#state._pendingShortfalls).toBe(1)
        expect(state._pendingShortfalls[1].color).toBe(color1)
        expect(state._pendingShortfalls[1].amount).toBe(8)
        expect(state._shortfallIndex).toBe(1)
        -- VP should not be deducted yet
        expect(p1.vp).toBe(30)
    end)

    it("should not set pending shortfalls when there are none", function()
        local state = GameState.new(2)
        -- Default income level 10 with 17 money, no shortfalls

        TurnManager.startNewRound(state)

        expect(state._pendingShortfalls == nil).toBeTrue()
        expect(state._shortfallIndex == nil).toBeTrue()
    end)
end)
