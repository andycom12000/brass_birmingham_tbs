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

-- Tracks money spent by each player this round (color -> integer).
-- Reset on End Turn and on era transition.
-- Used by EventHandlers.deductTileCost to avoid reading button labels.
PLAYER_SPEND = {}

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
    printToAll("[DEBUG] startGame called with " .. tostring(playerCount) .. " players")
    UIManager.hideSetup()
    local ok, err = pcall(function()
        state = GameState.new(playerCount)
    end)
    if not ok then
        printToAll("[ERROR] GameState.new failed: " .. tostring(err))
        return
    end
    printToAll("[DEBUG] state created, era=" .. tostring(state and state.era))

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
    printToAll("[DEBUG] onObjectDrop fired by " .. tostring(playerColor) .. " obj=" .. tostring(droppedObject and droppedObject.getName()))
    printToAll("[DEBUG] state=" .. tostring(state ~= nil) .. " objType=" .. tostring(droppedObject and droppedObject.type))
    local notes = droppedObject and droppedObject.getGMNotes and droppedObject.getGMNotes() or ""
    printToAll("[DEBUG] GMNotes=" .. tostring(notes):sub(1, 80))
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
            PLAYER_SPEND = {}  -- reset spend tracking for new era
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

    -- Reset per-round spend tracking for this player
    PLAYER_SPEND[color] = 0

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
            PLAYER_SPEND = {}  -- reset spend tracking for new era
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
    ["9f808b"] = "bfdaf2",  -- Orange spend → Orange money
    ["b05299"] = "4a0fce",  -- Purple spend → Purple money
    ["26e57c"] = "b56836",  -- Yellow spend → Yellow money
    ["719019"] = "4d732a",  -- White spend → White money
}

-- Maps TTS seat color to spend tracker GUID
-- TTS seat colors in reference mod: White, Purple, Orange, Yellow
COLOR_TO_SPEND_GUID = {
    ["Orange"] = "9f808b",
    ["Purple"] = "b05299",
    ["Yellow"] = "26e57c",
    ["White"]  = "719019",
}

-- Maps TTS seat color to money counter GUID
COLOR_TO_MONEY_GUID = {
    ["Orange"] = "bfdaf2",
    ["Purple"] = "4a0fce",
    ["Yellow"] = "b56836",
    ["White"]  = "4d732a",
}

STARTING_MONEY = 17

-- Push a value to a MrStump counter object (set description + call customSet)
function setCounterValue(guid, value)
    local obj = getObjectFromGUID(guid)
    if obj then
        obj.setDescription(tostring(value))
        obj.call('customSet')
    end
end

-- Called by spend tracker objects when manually adjusted via buttons
function onSpendChanged(params)
    local spendGUID = params.guid
    local spent = params.spent
    local moneyGUID = SPEND_TO_MONEY_MAP[spendGUID]
    if moneyGUID then
        local remaining = STARTING_MONEY - spent
        if remaining < 0 then remaining = 0 end
        setCounterValue(moneyGUID, remaining)
    end
end

-- Called by game logic (afterAction) to update spend counter from GameState
function updateSpendCounterFromState(color)
    if not state then return end
    local p = GameState.getPlayer(state, color)
    if not p then return end

    local spent = p.spentThisRound or 0
    local spendGUID = COLOR_TO_SPEND_GUID[color]
    local moneyGUID = COLOR_TO_MONEY_GUID[color]

    -- Update spend tracker display
    if spendGUID then
        setCounterValue(spendGUID, spent)
    end

    -- Update money counter display (remaining = current money)
    if moneyGUID then
        setCounterValue(moneyGUID, p.money or 0)
    end
end

-- Reset all spend counters to 0 (new round)
function resetAllSpendCounters()
    for color, guid in pairs(COLOR_TO_SPEND_GUID) do
        setCounterValue(guid, 0)
    end
end

------------------------------------------------------
-- LANGUAGE TOGGLE
------------------------------------------------------

------------------------------------------------------
-- CHAT COMMANDS (for debugging / manual init)
------------------------------------------------------

function onChat(message, player)
    if message == "/init2" then
        startGame(2)
        return false
    elseif message == "/init3" then
        startGame(3)
        return false
    elseif message == "/init4" then
        startGame(4)
        return false
    elseif message == "/status" then
        printToAll("[STATUS] state=" .. tostring(state ~= nil))
        if state then
            printToAll("[STATUS] era=" .. tostring(state.era) .. " round=" .. tostring(state.round) .. " players=" .. tostring(state.playerCount))
        end
        return false
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
