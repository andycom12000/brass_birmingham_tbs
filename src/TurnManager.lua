local GameState  = require("src/GameState")
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
-- Negative income = pay the bank; shortfall = lose 1 VP per £ owed
function TurnManager.incomePhase(state)
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
                p.vp = p.vp - shortfall  -- lose 1 VP per £ short
            end
        end
    end
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
