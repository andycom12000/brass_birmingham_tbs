------------------------------------------------------
-- Brass: Birmingham — Tabletop Simulator Mod
-- Global Script
------------------------------------------------------

-- Phase 1: Game Logic Modules
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

-- Phase 2: TTS Integration Modules
#include tts/SnapMap
#include tts/ObjectManager
#include tts/CardManager
#include tts/Highlights
#include tts/UIManager
#include tts/EventHandlers

------------------------------------------------------
-- GAME STATE (global)
------------------------------------------------------
state = nil

------------------------------------------------------
-- TTS LIFECYCLE CALLBACKS
------------------------------------------------------

function onLoad(save_state)
    if save_state and save_state ~= "" then
        local saved = JSON.decode(save_state)
        if saved then
            state = saved.gameState
            ObjectManager.loadGUIDs(saved.objectGUIDs)

            -- Rebuild snap map
            local board = ObjectManager.getObject("mainBoard")
            if board then SnapMap.buildFromObject(board) end

            UIManager.hideSetup()
            UIManager.configureForPlayerCount(state.playerCount)
            UIManager.updateLanguage(state.lang)
            broadcastCurrentPlayer()

            printToAll(Lang.get("game_loaded", state.lang))
        end
    else
        UIManager.showSetup()
    end
end

function onSave()
    if state then
        return JSON.encode({
            gameState = state,
            objectGUIDs = ObjectManager.saveGUIDs(),
        })
    end
    return ""
end

------------------------------------------------------
-- SETUP
------------------------------------------------------

function onSetup2P() startGame(2) end
function onSetup3P() startGame(3) end
function onSetup4P() startGame(4) end

function startGame(playerCount)
    UIManager.hideSetup()
    state = GameState.new(playerCount)

    -- Scan objects on table
    ObjectManager.scanTable()

    -- Build snap point mappings
    local board = ObjectManager.getObject("mainBoard")
    if board then SnapMap.buildFromObject(board) end

    -- Setup cards
    local deck = ObjectManager.getObject("drawDeck")
    if deck then
        CardManager.buildDeck(state, deck)
        CardManager.dealToAll(state)
    end

    -- Income phase for first round
    TurnManager.incomePhase(state)

    -- Configure UI
    UIManager.configureForPlayerCount(playerCount)
    UIManager.resetAllCounters(state.turnOrder)
    UIManager.updateLanguage(state.lang)
    broadcastCurrentPlayer()

    printToAll(Lang.format("game_started", state.lang, { count = playerCount }))
    printToAll(Lang.get("canal_era", state.lang))
end

------------------------------------------------------
-- TTS EVENT CALLBACKS
------------------------------------------------------

function onObjectDrop(playerColor, droppedObject)
    EventHandlers.onObjectDrop(playerColor, droppedObject)
end

function onObjectPickUp(playerColor, pickedUpObject)
    EventHandlers.onObjectPickUp(playerColor, pickedUpObject)
end

------------------------------------------------------
-- ACTION HELPERS (called by EventHandlers)
------------------------------------------------------

function isCurrentPlayer(color)
    if not state then return false end
    return GameState.getCurrentPlayerColor(state) == color
end

function afterAction(color)
    -- Update spend counter
    local p = GameState.getPlayer(state, color)
    UIManager.updateSpendCounter(color, p.spentThisRound)

    -- Update deck empty flag
    state.deckEmpty = CardManager.isDeckEmpty()

    -- Check era end BEFORE advancing turn
    if EraTransition.isEraOver(state) then
        if state.era == Constants.Era.CANAL then
            printToAll(Lang.get("era_transition", state.lang))
            EraTransition.transition(state)
            CardManager.rebuildDeckForRailEra(state)
            CardManager.dealToAll(state)
            UIManager.resetAllCounters(state.turnOrder)
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

    -- Refill hand
    CardManager.refillHand(state, color)

    -- Advance turn
    TurnManager.endAction(state)
    broadcastCurrentPlayer()
end

function broadcastCurrentPlayer()
    if not state then return end
    local color = GameState.getCurrentPlayerColor(state)
    local turnText = Lang.format("your_turn", state.lang, { player = color })
    local actionsText = Lang.format("actions_remaining", state.lang, { count = state.actionsRemaining })
    UIManager.showTurnIndicator(turnText .. " — " .. actionsText)
    UIManager.showEndTurnButton()
    printToAll(turnText)
end

------------------------------------------------------
-- END TURN BUTTON
------------------------------------------------------

function onEndTurn(player, value, id)
    if not state then return end
    local color = player.color
    if not isCurrentPlayer(color) then
        printToColor("Not your turn.", color, {1, 0.5, 0})
        return
    end

    -- Clear any pending action
    if state._pendingCard then
        Highlights.clearAll()
        state._pendingCard = nil
    end

    -- Update deck empty flag
    state.deckEmpty = CardManager.isDeckEmpty()

    -- Check era end
    if EraTransition.isEraOver(state) then
        UIManager.hideEndTurnButton()
        if state.era == Constants.Era.CANAL then
            printToAll(Lang.get("era_transition", state.lang))
            EraTransition.transition(state)
            CardManager.rebuildDeckForRailEra(state)
            CardManager.dealToAll(state)
            UIManager.resetAllCounters(state.turnOrder)
            broadcastCurrentPlayer()
            return
        else
            Scoring.scoreEndOfEra(state, true)
            local ranking = Scoring.determineWinner(state)
            announceResults(ranking)
            return
        end
    end

    -- Advance turn
    TurnManager.endAction(state)
    broadcastCurrentPlayer()
end

------------------------------------------------------
-- RESULTS
------------------------------------------------------

function announceResults(ranking)
    UIManager.hideTurnIndicator()
    UIManager.hideEndTurnButton()
    printToAll("═══════════════════════════")
    printToAll(Lang.get("scoring_start", state.lang))
    for i, entry in ipairs(ranking) do
        printToAll(i .. ". " .. entry.color .. " — " .. entry.vp .. " VP (£" .. entry.money .. ")")
    end
    if ranking[1] then
        printToAll(Lang.format("winner", state.lang, { player = ranking[1].color }))
    end
    printToAll("═══════════════════════════")
end

------------------------------------------------------
-- SPEND COUNTER SYNC
------------------------------------------------------

-- Maps spend tracker GUIDs to money counter GUIDs
SPEND_TO_MONEY_MAP = {
    ["9f808b"] = "bfdaf2",  -- Orange board counter → Orange money counter
    ["b05299"] = "4a0fce",  -- Purple board counter → Purple money counter
    ["26e57c"] = "b56836",  -- Yellow board counter → Yellow money counter
    ["719019"] = "4d732a",  -- White board counter → White money counter
}

-- Starting money
STARTING_MONEY = 17

-- Called by spend tracker objects when their value changes
function onSpendChanged(params)
    local spendGUID = params.guid
    local spent = params.spent
    local moneyGUID = SPEND_TO_MONEY_MAP[spendGUID]

    if moneyGUID then
        local moneyObj = getObjectFromGUID(moneyGUID)
        if moneyObj then
            -- Calculate remaining money: starting - spent
            local remaining = STARTING_MONEY - spent
            if remaining < 0 then remaining = 0 end
            -- Set the money counter's description to trigger customSet
            moneyObj.setDescription(tostring(remaining))
            -- Call customSet on the money counter to update its display
            moneyObj.call('customSet')
        end
    end
end

------------------------------------------------------
-- LANGUAGE TOGGLE
------------------------------------------------------

function toggleLanguage()
    if not state then return end
    state.lang = (state.lang == "en") and "zh-TW" or "en"
    UIManager.updateLanguage(state.lang)
    printToAll("Language: " .. (state.lang == "en" and "English" or "繁體中文"))
end

------------------------------------------------------
-- SELL / DEVELOP / LOAN / SCOUT (button-triggered actions)
-- These are called from TTS context menu or buttons
------------------------------------------------------

function onSellAction(playerColor, slotIds, merchantName)
    if not state or not isCurrentPlayer(playerColor) then return end
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        return
    end
    local result = Actions.sell(state, playerColor, {
        slotIds = slotIds,
        merchantName = merchantName,
    })
    if result.success then
        Highlights.clearAll()
        state._pendingCard = nil
        printToAll(Lang.format("player_sold", state.lang, { player = playerColor, industry = "", city = "" }))
        afterAction(playerColor)
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onDevelopAction(playerColor, count)
    if not state or not isCurrentPlayer(playerColor) then return end
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        return
    end
    local result = Actions.develop(state, playerColor, { count = count or 1 })
    if result.success then
        Highlights.clearAll()
        state._pendingCard = nil
        printToAll(Lang.format("player_developed", state.lang, { player = playerColor, count = count or 1 }))
        afterAction(playerColor)
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onLoanAction(playerColor)
    if not state or not isCurrentPlayer(playerColor) then return end
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        return
    end
    local result = Actions.loan(state, playerColor)
    if result.success then
        Highlights.clearAll()
        state._pendingCard = nil
        -- Spawn £30 money at player area
        local board = ObjectManager.getPlayerBoard(playerColor)
        if board then
            local pos = board.getPosition() + Vector(5, 1, 0)
            ObjectManager.spawnMoney(15, pos)
            ObjectManager.spawnMoney(15, pos + Vector(1, 0, 0))
        end
        printToAll(Lang.format("player_loaned", state.lang, { player = playerColor }))
        afterAction(playerColor)
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onScoutAction(playerColor)
    if not state or not isCurrentPlayer(playerColor) then return end
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        return
    end
    local result = Actions.scout(state, playerColor)
    if result.success then
        Highlights.clearAll()
        state._pendingCard = nil
        CardManager.giveWilds(playerColor)
        printToAll(Lang.format("player_scouted", state.lang, { player = playerColor }))
        afterAction(playerColor)
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end
