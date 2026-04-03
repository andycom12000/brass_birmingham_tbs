local GameState  = require("src/GameState")
local BoardData  = require("src/BoardData")
local IncomeTrack = require("src/IncomeTrack")
local helpers    = require("src/helpers")

local TurnManager = {}

-- Get number of actions for current turn
-- Canal era first round = 1 action; all other cases = 2 actions
function TurnManager.getActionsThisTurn(state)
    if GameState.isFirstRound(state) then return 1 end
    return 2
end

-- Execute income phase: each player receives money equal to their income level
-- Negative income = pay the bank; shortfall returned for interactive tile removal
-- Returns: array of { color, amount } shortfall entries (empty if no shortfalls)
function TurnManager.incomePhase(state)
    local shortfalls = {}
    for _, color in ipairs(state.turnOrder) do
        local p = GameState.getPlayer(state, color)
        local income = IncomeTrack.levelToIncome(p.incomeLevel)
        if income >= 0 then
            GameState.gainMoney(state, color, income)
        else
            local owed = math.abs(income)
            if p.money >= owed then
                p.money = p.money - owed
            else
                local shortfall = owed - p.money
                p.money = 0
                -- Don't immediately deduct VP -- return shortfall for interactive resolution
                shortfalls[#shortfalls + 1] = { color = color, amount = shortfall }
            end
        end
    end
    return shortfalls
end

--- Calculate the refund value for removing a tile from the board.
--- Per rules: half of the build cost (money only), rounded down.
function TurnManager.calculateTileRefund(industryType, level)
    local costData = BoardData.buildingCosts[industryType] and BoardData.buildingCosts[industryType][level]
    if not costData then return 0 end
    return math.floor(costData.money / 2)
end

--- Get all removable industry tiles owned by a player on the board, with their refund values.
--- Both flipped and unflipped tiles can be removed.
--- Returns a list of { slotId, cityName, industryType, level, refund }
function TurnManager.getRemovableTiles(state, color)
    local tiles = {}
    for cityName, city in pairs(state.board.cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.occupant == color and slot.tile then
                    local refund = TurnManager.calculateTileRefund(slot.tile.type, slot.tile.level)
                    tiles[#tiles + 1] = {
                        slotId = slot.id,
                        cityName = cityName,
                        industryType = slot.tile.type,
                        level = slot.tile.level,
                        refund = refund,
                    }
                end
            end
        end
    end
    return tiles
end

--- Remove a tile from the board to cover income shortfall.
--- Returns the refund amount. The tile is removed from the game (not returned to player mat).
function TurnManager.removeTileForDebt(state, color, slotId)
    local slot = GameState.getSlot(state, slotId)
    if not slot or slot.occupant ~= color or not slot.tile then return 0 end
    local refund = TurnManager.calculateTileRefund(slot.tile.type, slot.tile.level)
    -- Remove tile from board permanently
    slot.occupant = nil
    slot.tile = nil
    return refund
end

--- Resolve remaining shortfall as VP loss (1 VP per GBP short).
function TurnManager.resolveShortfallAsVP(state, color, remainingShortfall)
    if remainingShortfall <= 0 then return end
    local p = GameState.getPlayer(state, color)
    p.vp = p.vp - remainingShortfall
end

-- Reorder turn order by spending (ascending, stable sort)
-- Players who spent less go first; ties preserve previous order
function TurnManager.reorderTurnOrder(state)
    helpers.stableSort(state.turnOrder, function(a, b)
        return GameState.getPlayer(state, a).spentThisRound
             < GameState.getPlayer(state, b).spentThisRound
    end)
end

-- Advance to next player
function TurnManager.nextPlayer(state)
    state.currentPlayerIdx = state.currentPlayerIdx + 1
    if state.currentPlayerIdx > #state.turnOrder then
        state.currentPlayerIdx = 1
    end
end

-- Start a new round
function TurnManager.startNewRound(state)
    local shortfalls = TurnManager.incomePhase(state)

    -- If there are shortfalls, store them for interactive resolution by TTS layer
    if shortfalls and #shortfalls > 0 then
        state._pendingShortfalls = shortfalls
        state._shortfallIndex = 1
    end

    TurnManager.reorderTurnOrder(state)
    GameState.resetRoundSpending(state)
    state.round = state.round + 1
    state.currentPlayerIdx = 1
    state.actionsRemaining = TurnManager.getActionsThisTurn(state)
end

-- Called after a player completes one action
function TurnManager.endAction(state)
    state.actionsRemaining = state.actionsRemaining - 1
    if state.actionsRemaining <= 0 then
        -- Current player's turn is over
        -- Draw cards back to 8 (handled by TTS layer in Phase 2)
        local p = GameState.getPlayer(state, GameState.getCurrentPlayerColor(state))
        p.handSize = 8  -- reset hand size (card draw handled by TTS)

        TurnManager.nextPlayer(state)
        if state.currentPlayerIdx == 1 then
            -- All players completed their turns — start new round
            TurnManager.startNewRound(state)
        else
            state.actionsRemaining = TurnManager.getActionsThisTurn(state)
        end
    end
end

return TurnManager
