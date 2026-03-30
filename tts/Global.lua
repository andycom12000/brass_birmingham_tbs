------------------------------------------------------
-- Brass: Birmingham — Tabletop Simulator Mod
-- Global Script
------------------------------------------------------

-- Module includes (TTS will inline these)
#include src/helpers
#include src/Constants
#include src/BoardData
#include src/Tile
#include src/IncomeTrack
#include src/GameState
#include src/Network
#include src/Market
#include src/TurnManager
#include src/Validation
#include src/Actions
#include src/Scoring
#include src/EraTransition
#include src/Lang

------------------------------------------------------
-- GAME STATE
------------------------------------------------------
local state = nil  -- initialized in onLoad or setupGame

------------------------------------------------------
-- TTS CALLBACKS
------------------------------------------------------

function onLoad(save_state)
    -- Restore or initialize game state from save data
    if save_state and save_state ~= "" then
        state = GameState.deserialize(save_state)
        printToAll(Lang.get("game_loaded", state.lang))
    end
end

function onSave()
    if state then
        return GameState.serialize(state)
    end
    return ""
end

------------------------------------------------------
-- SETUP
------------------------------------------------------

-- Called when host clicks "Setup Game" button
-- playerCount: 2, 3, or 4
function setupGame(playerCount)
    state = GameState.new(playerCount)
    printToAll(Lang.format("game_started", state.lang, { count = playerCount }))
    printToAll(Lang.get("canal_era", state.lang))
    broadcastCurrentPlayer()
end

------------------------------------------------------
-- ACTION HANDLERS
-- These are called from TTS UI/object interactions
------------------------------------------------------

function onBuild(color, params)
    if not isCurrentPlayer(color) then return end
    local result = Actions.build(state, color, params)
    if result.success then
        printToAll(Lang.format("player_built", state.lang, {
            player = color,
            industry = params.industryType,
            level = params.level,
            city = params.location,
        }))
        afterAction(color)
    else
        printToColor(result.error, color, {1, 0, 0})
    end
end

function onNetwork(color, params)
    if not isCurrentPlayer(color) then return end
    local result = Actions.network(state, color, params)
    if result.success then
        printToAll(Lang.format("player_linked", state.lang, {
            player = color,
            city1 = params.city1 or "",
            city2 = params.city2 or "",
        }))
        afterAction(color)
    else
        printToColor(result.error, color, {1, 0, 0})
    end
end

function onSell(color, params)
    if not isCurrentPlayer(color) then return end
    local result = Actions.sell(state, color, params)
    if result.success then
        printToAll(Lang.format("player_sold", state.lang, {
            player = color,
            industry = params.industryType or "",
            city = params.location or "",
        }))
        afterAction(color)
    else
        printToColor(result.error, color, {1, 0, 0})
    end
end

function onDevelop(color, params)
    if not isCurrentPlayer(color) then return end
    local result = Actions.develop(state, color, params)
    if result.success then
        printToAll(Lang.format("player_developed", state.lang, {
            player = color,
            count = params.count,
        }))
        afterAction(color)
    else
        printToColor(result.error, color, {1, 0, 0})
    end
end

function onLoan(color)
    if not isCurrentPlayer(color) then return end
    local result = Actions.loan(state, color)
    if result.success then
        printToAll(Lang.format("player_loaned", state.lang, { player = color }))
        afterAction(color)
    else
        printToColor(result.error, color, {1, 0, 0})
    end
end

function onScout(color)
    if not isCurrentPlayer(color) then return end
    local result = Actions.scout(state, color)
    if result.success then
        printToAll(Lang.format("player_scouted", state.lang, { player = color }))
        afterAction(color)
    else
        printToColor(result.error, color, {1, 0, 0})
    end
end

------------------------------------------------------
-- HELPERS
------------------------------------------------------

function isCurrentPlayer(color)
    return GameState.getCurrentPlayerColor(state) == color
end

function afterAction(color)
    -- Update spend counter display
    local p = GameState.getPlayer(state, color)
    updateSpendCounter(color, p.spentThisRound)

    -- Check era end BEFORE advancing turn
    if EraTransition.isEraOver(state) then
        if state.era == Constants.Era.CANAL then
            printToAll(Lang.get("era_transition", state.lang))
            EraTransition.transition(state)
            broadcastCurrentPlayer()
            return
        else
            -- Game over — final scoring
            Scoring.scoreEndOfEra(state, true)
            local ranking = Scoring.determineWinner(state)
            announceResults(ranking)
            return
        end
    end

    -- Normal turn advancement
    TurnManager.endAction(state)
    broadcastCurrentPlayer()
end

function broadcastCurrentPlayer()
    local color = GameState.getCurrentPlayerColor(state)
    printToAll(Lang.format("your_turn", state.lang, { player = color }))
    printToAll(Lang.format("actions_remaining", state.lang, { count = state.actionsRemaining }))
end

function updateSpendCounter(color, amount)
    -- Phase 2: update XML UI counter for this player
    -- For now, just print
    printToColor("Spent this round: \xC2\xA3" .. amount, color)
end

function announceResults(ranking)
    printToAll("=== GAME OVER ===")
    for i, entry in ipairs(ranking) do
        printToAll(i .. ". " .. entry.color .. " \xe2\x80\x94 " .. entry.vp .. " VP")
    end
    if ranking[1] then
        printToAll(Lang.format("winner", state.lang, { player = ranking[1].color }))
    end
end

-- Language toggle (bound to a TTS UI button in Phase 2)
function toggleLanguage()
    if state then
        state.lang = (state.lang == "en") and "zh-TW" or "en"
        printToAll("Language: " .. state.lang)
    end
end
