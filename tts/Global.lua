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
#include tts/MarketLayout
#include tts/ResourceAnimation

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
            SnapMap.buildFromGlobal()

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
        -- Temporarily remove non-serializable fields (Vectors, TTS objects)
        local pendingBackup = state._pendingResource
        local animBackup = state._animating
        local shortfallBackup = state._pendingShortfalls
        local shortfallIdxBackup = state._shortfallIndex
        local currentShortfallBackup = state._currentShortfall
        local pendingFirstLinkBackup = state._pendingFirstLink
        state._pendingResource = nil
        state._animating = nil
        state._pendingShortfalls = nil
        state._shortfallIndex = nil
        state._currentShortfall = nil
        state._pendingFirstLink = nil

        -- cubeGUIDs are fine (string arrays), but remove any Vector refs
        -- that might have leaked into market data
        local ok, encoded = pcall(JSON.encode, {
            gameState = state,
            objectGUIDs = ObjectManager.saveGUIDs(),
        })

        -- Restore transient fields
        state._pendingResource = pendingBackup
        state._animating = animBackup
        state._pendingShortfalls = shortfallBackup
        state._shortfallIndex = shortfallIdxBackup
        state._currentShortfall = currentShortfallBackup
        state._pendingFirstLink = pendingFirstLinkBackup

        if ok then
            return encoded
        else
            printToAll("[WARN] Save failed: " .. tostring(encoded))
            return ""
        end
    end
    return ""
end

------------------------------------------------------
-- SETUP (called by crown button callback)
------------------------------------------------------

PREBUILT_DECK_GUIDS = {
    [2] = "b6ff44",
    [3] = "3895fe",
    [4] = "bc3ba4",
}

function onPhysicalSetupComplete(params)
    local playerCount = params.playerCount
    printToAll("Initializing game state for " .. playerCount .. " players...")

    local ok, err = pcall(function()
        state = GameState.new(playerCount)
    end)
    if not ok then
        printToAll("[ERROR] GameState.new failed: " .. tostring(err))
        return
    end

    -- Deal cards from the deck the crown placed on the board
    local deck = CardManager.findDeckOnBoard()
    if deck then
        CardManager.dealFromDeck(state, deck)
    else
        printToAll("[WARNING] Could not find card deck on board")
    end

    -- Hide unused pre-built decks
    hideUnusedDecks(playerCount)

    -- Set money counters and reset spend trackers
    for _, color in ipairs(state.turnOrder) do
        local moneyGUID = COLOR_TO_MONEY_GUID[color]
        if moneyGUID then
            local moneyObj = getObjectFromGUID(moneyGUID)
            if moneyObj then
                moneyObj.setDescription(tostring(Constants.INITIAL_MONEY))
                pcall(function() moneyObj.call('customSet') end)
            end
        end
        local spendGUID = COLOR_TO_SPEND_GUID[color]
        if spendGUID then
            local spendObj = getObjectFromGUID(spendGUID)
            if spendObj and spendObj.Counter then
                spendObj.Counter.setValue(0)
            end
        end
    end

    PLAYER_SPEND = {}

    -- Spawn market coal/iron cubes
    -- Record existing market cube GUIDs (don't spawn — reference mod already has them)
    recordMarketCubes(state)

    -- No income phase at game start: income is collected at the END of each round.
    -- First round of canal era = 1 action per player, starting with $17.

    -- Scan objects on table
    ObjectManager.scanTable()

    -- Build snap point mappings (hardcoded positions, no board object needed)
    SnapMap.buildFromGlobal()

    -- Configure UI
    UIManager.hideSetup()
    UIManager.configureForPlayerCount(playerCount)
    UIManager.showEndTurnButton()
    broadcastCurrentPlayer()

    printToAll(Lang.format("game_started", state.lang, { count = playerCount }))
    printToAll(Lang.get("canal_era", state.lang))
end

function hideUnusedDecks(playerCount)
    for pc, guid in pairs(PREBUILT_DECK_GUIDS) do
        if pc ~= playerCount then
            local obj = getObjectFromGUID(guid)
            if obj then
                obj.setPosition(Vector(0, -5, 0))
                Wait.time(function()
                    local o = getObjectFromGUID(guid)
                    if o then o.destruct() end
                end, 1.0)
            end
        end
    end
end

--- Find existing coal/iron cubes on the market track and record their GUIDs.
--- The reference mod already has cubes placed; we don't spawn new ones.
function recordMarketCubes(gameState)
    gameState.coalMarket.cubeGUIDs = {}
    gameState.ironMarket.cubeGUIDs = {}

    -- Collect all resource cubes on the table
    local coalCubes = {}
    local ironCubes = {}

    for _, obj in ipairs(getAllObjects()) do
        local gm = obj.getGMNotes() or ""
        local pos = obj.getPosition()
        -- Check GMNotes (set by inject_scripts.py lock_resource_cubes)
        if gm:find('"resource":"coal"') or gm:find('"resource": "coal"') then
            coalCubes[#coalCubes + 1] = { guid = obj.getGUID(), x = pos.x, z = pos.z }
        elseif gm:find('"resource":"iron"') or gm:find('"resource": "iron"') then
            ironCubes[#ironCubes + 1] = { guid = obj.getGUID(), x = pos.x, z = pos.z }
        else
            -- Fallback: check by Nickname
            local name = obj.getName() or ""
            if name == Constants.ObjectName.COAL_CUBE then
                coalCubes[#coalCubes + 1] = { guid = obj.getGUID(), x = pos.x, z = pos.z }
            elseif name == Constants.ObjectName.IRON_CUBE then
                ironCubes[#ironCubes + 1] = { guid = obj.getGUID(), x = pos.x, z = pos.z }
            end
        end
    end

    -- Match cubes to market track positions (nearest to each slot)
    local function assignCubesToTrack(cubes, resourceType, market)
        local trackMax = #Market.getTrack(resourceType)
        local used = {}
        for idx = 1, math.min(market.supply, trackMax) do
            local trackPos = MarketLayout.getPosition(resourceType, idx)
            local bestCube = nil
            local bestDist = 2.0  -- max search radius
            for ci, cube in ipairs(cubes) do
                if not used[ci] then
                    local dx = cube.x - trackPos.x
                    local dz = cube.z - trackPos.z
                    local dist = math.sqrt(dx*dx + dz*dz)
                    if dist < bestDist then
                        bestDist = dist
                        bestCube = ci
                    end
                end
            end
            if bestCube then
                market.cubeGUIDs[idx] = cubes[bestCube].guid
                used[bestCube] = true
            end
        end
    end

    assignCubesToTrack(coalCubes, Constants.Resource.COAL, gameState.coalMarket)
    assignCubesToTrack(ironCubes, Constants.Resource.IRON, gameState.ironMarket)

    local coalCount = 0
    for _ in pairs(gameState.coalMarket.cubeGUIDs) do coalCount = coalCount + 1 end
    local ironCount = 0
    for _ in pairs(gameState.ironMarket.cubeGUIDs) do ironCount = ironCount + 1 end
    printToAll("[Market] Recorded " .. coalCount .. " coal + " .. ironCount .. " iron cube GUIDs")
end

------------------------------------------------------
-- RESOURCE MARKER CLICK ROUTING
------------------------------------------------------

function onResourceMarkerClicked(obj, playerColor)
    if not state then return end
    local notes = obj.getGMNotes()
    if notes and notes ~= "" then
        local ok, meta = pcall(JSON.decode, notes)
        if ok and meta and meta.slotId then
            -- Route to shortfall handler if a shortfall is active
            if state._currentShortfall then
                onShortfallTileClicked(playerColor, meta.slotId)
            elseif state._pendingResource then
                EventHandlers.onResourceCandidateClicked(playerColor, meta.slotId)
            end
        end
    end
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

-- Also track position when tile leaves a container (deck/stack on player board)
function onObjectLeaveContainer(container, obj)
    if obj and not obj.isDestroyed() then
        -- Save the container's position as the "home" for this object
        EventHandlers.savePickupPosition(obj.getGUID(), container.getPosition())
    end
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
    local oldRound = state.round
    TurnManager.endAction(state)
    if state.round > oldRound then
        -- New round started — announce income results
        for _, c in ipairs(state.turnOrder) do
            local p = GameState.getPlayer(state, c)
            local income = IncomeTrack.levelToIncome(p.incomeLevel)
            if income > 0 then
                printToAll(Lang.format("income_collected", state.lang, { player = c, amount = income }))
            elseif income < 0 then
                printToAll(Lang.format("income_paid", state.lang, { player = c, amount = math.abs(income) }))
            end
        end

        -- Handle income shortfalls (interactive tile removal)
        if state._pendingShortfalls and #state._pendingShortfalls > 0 then
            _startShortfallResolution()
            return  -- Don't broadcastCurrentPlayer yet
        end
    end
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
-- INCOME SHORTFALL RESOLUTION
------------------------------------------------------

function _startShortfallResolution()
    if not state._pendingShortfalls then
        broadcastCurrentPlayer()
        return
    end
    local sf = state._pendingShortfalls[state._shortfallIndex]
    if not sf then
        -- All shortfalls resolved
        state._pendingShortfalls = nil
        state._shortfallIndex = nil
        broadcastCurrentPlayer()
        return
    end

    local removable = TurnManager.getRemovableTiles(state, sf.color)
    if #removable == 0 then
        -- No tiles to remove — take VP loss
        TurnManager.resolveShortfallAsVP(state, sf.color, sf.amount)
        printToAll(Lang.format("shortfall_no_tiles", state.lang, { player = sf.color, vp = sf.amount }))
        state._shortfallIndex = state._shortfallIndex + 1
        _startShortfallResolution()
        return
    end

    -- Show shortfall UI
    printToAll(Lang.format("shortfall_owe", state.lang, { player = sf.color, amount = sf.amount }))

    -- Store current shortfall state for click handling
    state._currentShortfall = {
        color = sf.color,
        remaining = sf.amount,
    }

    -- Highlight removable tiles using the resource candidate system
    local candidates = {}
    for _, tile in ipairs(removable) do
        local pos = SnapMap.getPositionForSlot(tile.slotId)
        if pos then
            candidates[#candidates + 1] = {
                slotId = tile.slotId,
                cityName = tile.cityName,
                cubesAvailable = tile.refund,
            }
        end
    end

    Highlights.showResourceCandidates(candidates, "shortfall", function(slotId)
        onShortfallTileClicked(sf.color, slotId)
    end)
end

function onShortfallTileClicked(playerColor, slotId)
    if not state or not state._currentShortfall then return end
    local cs = state._currentShortfall
    if cs.color ~= playerColor then return end

    local refund = TurnManager.removeTileForDebt(state, playerColor, slotId)
    if refund == 0 then return end

    -- Apply refund: reduce remaining debt, give surplus as money
    local surplus = refund - cs.remaining
    if surplus > 0 then
        GameState.gainMoney(state, playerColor, surplus)
        cs.remaining = 0
    else
        cs.remaining = cs.remaining - refund
    end

    -- Remove the physical tile from the board
    local snapPos = SnapMap.getPositionForSlot(slotId)
    if snapPos then
        for _, obj in ipairs(getAllObjects()) do
            if not obj.isDestroyed() and obj.getLock and obj.getLock() then
                local opos = obj.getPosition()
                local dx = opos.x - snapPos.x
                local dz = opos.z - snapPos.z
                if math.sqrt(dx*dx + dz*dz) < 1.0 then
                    obj.destruct()
                    break
                end
            end
        end
    end

    printToAll(Lang.format("shortfall_removed", state.lang, {
        player = playerColor,
        refund = refund,
        remaining = math.max(0, cs.remaining),
    }))

    if cs.remaining <= 0 then
        -- Shortfall fully resolved
        Highlights.clearResourceCandidates()
        state._currentShortfall = nil
        state._shortfallIndex = state._shortfallIndex + 1
        _startShortfallResolution()
    else
        -- Update highlights (remove destroyed tile from candidates)
        local newRemovable = TurnManager.getRemovableTiles(state, playerColor)
        if #newRemovable == 0 then
            -- No more tiles — take remaining VP loss
            Highlights.clearResourceCandidates()
            TurnManager.resolveShortfallAsVP(state, playerColor, cs.remaining)
            printToAll(Lang.format("shortfall_no_tiles", state.lang, { player = playerColor, vp = cs.remaining }))
            state._currentShortfall = nil
            state._shortfallIndex = state._shortfallIndex + 1
            _startShortfallResolution()
        end
        -- Otherwise, keep highlights up for the player to click more tiles
    end
end

function onAcceptVPLoss(player, value, id)
    if not state or not state._currentShortfall then return end
    local cs = state._currentShortfall
    if cs.color ~= player.color then return end

    Highlights.clearResourceCandidates()
    TurnManager.resolveShortfallAsVP(state, cs.color, cs.remaining)
    printToAll(Lang.format("shortfall_vp_loss", state.lang, { player = cs.color, vp = cs.remaining }))
    state._currentShortfall = nil
    state._shortfallIndex = state._shortfallIndex + 1
    _startShortfallResolution()
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

    -- If a card is pending, treat End Turn as Pass
    if state._pendingCard then
        onPassAction(color)
        return
    end

    -- No card pending — tell them to play a card first
    printToColor("Play a card first, then choose an action or pass.", color, {1, 0.5, 0})
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

-- Maps TTS seat color to player board GUID
COLOR_TO_BOARD_GUID = {
    ["Orange"] = "57ef3a",
    ["Purple"] = "018be6",
    ["Yellow"] = "535035",
    ["White"]  = "fcfae7",
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

STARTING_MONEY = Constants.INITIAL_MONEY

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
        onPhysicalSetupComplete({playerCount = 2})
        return false
    elseif message == "/init3" then
        onPhysicalSetupComplete({playerCount = 3})
        return false
    elseif message == "/init4" then
        onPhysicalSetupComplete({playerCount = 4})
        return false
    elseif message == "/status" then
        printToAll("[STATUS] state=" .. tostring(state ~= nil))
        if state then
            printToAll("[STATUS] era=" .. tostring(state.era) .. " round=" .. tostring(state.round))
        end
        return false
    elseif message == "/slots" then
        debugShowSlots()
        return false
    elseif message == "/clearslots" then
        debugClearSlots()
        return false
    end
end

-- Debug: spawn labels at every slot showing accepted types
_debugSlotLabels = {}

function debugShowSlots()
    debugClearSlots()
    if not state then
        printToAll("No state — run /init2 first")
        return
    end

    local SHORT = {
        cotton = "Co", coal = "Cl", iron = "Fe",
        brewery = "Br", manufacturer = "Mf", pottery = "Po",
    }

    local count = 0
    for slotId, data in pairs(SnapMap.bySlotId) do
        local slot = GameState.getSlot(state, slotId)
        if slot and data.position then
            local types = slot.types or {}
            local labels = {}
            for _, t in ipairs(types) do
                labels[#labels + 1] = SHORT[t] or t
            end
            local text = slotId .. "\n" .. table.concat(labels, "/")

            local pos = data.position + Vector(0, 1.5, 0)
            local label = spawnObject({
                type = "3DText",
                position = pos,
                rotation = {90, 180, 0},
            })
            if label then
                label.setLock(true)
                label.setValue(text)
                label.setScale({0.4, 0.4, 0.4})
                _debugSlotLabels[#_debugSlotLabels + 1] = label
                count = count + 1
            end
        end
    end
    printToAll("Spawned " .. count .. " slot labels. Use /clearslots to remove.")
end

function debugClearSlots()
    for _, obj in ipairs(_debugSlotLabels) do
        if obj and not obj.isDestroyed() then
            obj.destruct()
        end
    end
    _debugSlotLabels = {}
end

------------------------------------------------------
-- LANGUAGE TOGGLE
------------------------------------------------------

function toggleLanguage()
    if not state then return end
    state.lang = (state.lang == "en") and "zh-TW" or "en"
    UIManager.updateLanguage(state.lang)
    printToAll("Language: " .. (state.lang == "en" and "English" or "Traditional Chinese"))
end

------------------------------------------------------
-- SELL / DEVELOP / LOAN / SCOUT / PASS (button-triggered actions)
------------------------------------------------------

--- Guard: check current player and pending card. Returns false if blocked.
local function requirePendingCard(playerColor)
    if not state or not isCurrentPlayer(playerColor) then return false end
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        return false
    end
    return true
end

--- Finish a button-triggered action: clear state, announce, advance turn.
local function finishButtonAction(playerColor, message)
    Highlights.clearAll()
    state._pendingCard = nil
    printToAll(message)
    afterAction(playerColor)
end

function onSellAction(playerColor, slotIds, merchantName)
    if not requirePendingCard(playerColor) then return end
    local result = Actions.sell(state, playerColor, { slotIds = slotIds, merchantName = merchantName })
    if result.success then
        finishButtonAction(playerColor, Lang.format("player_sold", state.lang, { player = playerColor, industry = "", city = "" }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onDevelopAction(playerColor, count)
    if not requirePendingCard(playerColor) then return end
    local result = Actions.develop(state, playerColor, { count = count or 1 })
    if result.success then
        finishButtonAction(playerColor, Lang.format("player_developed", state.lang, { player = playerColor, count = count or 1 }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onLoanAction(playerColor)
    if not requirePendingCard(playerColor) then return end
    local result = Actions.loan(state, playerColor)
    if result.success then
        local board = ObjectManager.getPlayerBoard(playerColor)
        if board then
            local pos = board.getPosition() + Vector(5, 1, 0)
            ObjectManager.spawnMoney(15, pos)
            ObjectManager.spawnMoney(15, pos + Vector(1, 0, 0))
        end
        finishButtonAction(playerColor, Lang.format("player_loaned", state.lang, { player = playerColor }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onScoutAction(playerColor)
    if not requirePendingCard(playerColor) then return end
    local result = Actions.scout(state, playerColor)
    if result.success then
        CardManager.giveWilds(playerColor)
        finishButtonAction(playerColor, Lang.format("player_scouted", state.lang, { player = playerColor }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onPassAction(playerColor)
    if not requirePendingCard(playerColor) then return end
    finishButtonAction(playerColor, playerColor .. " passed")
end

------------------------------------------------------
-- SINGLE LINK BUTTON (double rail flow)
------------------------------------------------------

--- Called when the player clicks "Single Link" during a double rail flow.
-- Executes the pending first link as a single rail action.
function onSingleLinkOnly(player, value, id)
    if not state or not state._pendingFirstLink then return end
    local color = player.color
    if not isCurrentPlayer(color) then return end

    EventHandlers.executeSingleLink(color)
end
