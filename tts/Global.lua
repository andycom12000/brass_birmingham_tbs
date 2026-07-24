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
#include src/SetupGuard
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
#include tts/IncomeLayout
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
    -- Force-load XML UI from Lua (TTS does not parse XmlUI from saves)
    UIManager.initXmlUI()

    if save_state and save_state ~= "" then
        local saved = JSON.decode(save_state)
        if saved then
            state = saved.gameState
            ObjectManager.loadGUIDs(saved.objectGUIDs)

            -- Rebuild snap map
            SnapMap.buildFromGlobal()

            -- Wait for XML UI loading to complete before hiding elements
            Wait.condition(function()
                UIManager.hideSetup()
                UIManager.hideActionPanel()
                UIManager.hideSingleLinkButton()
                UIManager.hideAcceptVPLossButton()
                UIManager.configureForPlayerCount(state.playerCount)
                UIManager.updateLanguage(state.lang)
            end, function() return not UI.loading end)
            broadcastCurrentPlayer()

            printToAll(Lang.get("game_loaded", state.lang))
        end
    else
        -- Wait for XML UI loading, then show setup (hide others)
        Wait.condition(function()
            UIManager.hideActionPanel()
            UIManager.hideSingleLinkButton()
            UIManager.hideAcceptVPLossButton()
            UIManager.showEndTurnButton()
            UIManager.showSetup()
        end, function() return not UI.loading end)
    end

    -- Label the trash can object (works for both fresh and saved games)
    Wait.time(function() setupTrashCanLabels() end, 1)
end

function setupTrashCanLabels()
    if #ObjectManager.guids.trashCans == 0 then
        ObjectManager.scanTable()
    end

    for _, guid in ipairs(ObjectManager.guids.trashCans) do
        local obj = getObjectFromGUID(guid)
        if obj then
            obj.clearButtons()
            obj.createButton({
                click_function = "onTrashCanClick",
                function_owner = Global,
                label          = "Develop",
                position       = {0, 1.5, 0},
                rotation       = {0, 0, 0},
                width          = 0,
                height         = 0,
                font_size      = 200,
                font_color     = {1, 1, 1},
            })
        end
    end
end

function onTrashCanClick() end

function onSave()
    if state then
        -- Temporarily remove non-serializable fields (Vectors, TTS objects)
        local pendingBackup = state._pendingResource
        local animBackup = state._animating
        local shortfallBackup = state._pendingShortfalls
        local shortfallIdxBackup = state._shortfallIndex
        local currentShortfallBackup = state._currentShortfall
        local pendingFirstLinkBackup = state._pendingFirstLink
        local pendingScoutBackup = state._pendingScout
        local pendingDevelopBackup = state._pendingDevelop
        local buildSnapshotBackup = state._buildSnapshot
        local buildSlotIdBackup = state._buildCommitSlotId
        local undoPlayedCardBackup = state._undoPlayedCard
        local undoRefillOwedBackup = state._undoRefillOwed
        state._pendingResource = nil
        state._animating = nil
        state._pendingShortfalls = nil
        state._shortfallIndex = nil
        state._currentShortfall = nil
        state._pendingFirstLink = nil
        state._pendingScout = nil
        state._pendingDevelop = nil
        -- Undo/build transient fields (issue #9): the pre-execution snapshot is
        -- large and the undo window does not survive a reload.
        state._buildSnapshot = nil
        state._buildCommitSlotId = nil
        state._undoPlayedCard = nil
        state._undoRefillOwed = nil

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
        state._pendingScout = pendingScoutBackup
        state._pendingDevelop = pendingDevelopBackup
        state._buildSnapshot = buildSnapshotBackup
        state._buildCommitSlotId = buildSlotIdBackup
        state._undoPlayedCard = undoPlayedCardBackup
        state._undoRefillOwed = undoRefillOwedBackup

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
    local lang = (state and state.lang) or "en"

    local seatedColors = getSeatedPlayers()
    local guard = SetupGuard.validate(playerCount, seatedColors, Constants.ALL_COLORS)
    if not guard.ok then
        local message
        if guard.reason == "unsupported_seat" then
            message = Lang.format("setup_unsupported_seat", lang, { seats = table.concat(guard.seats, ", ") })
        else
            message = Lang.format("setup_count_mismatch", lang, { expected = guard.expected, actual = guard.actual })
        end
        broadcastToAll(message, {1, 0, 0})
        return
    end

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

    -- Configure UI (wait for XML UI loading to finish)
    Wait.condition(function()
        UIManager.hideSetup()
        UIManager.hideActionPanel()
        UIManager.hideSingleLinkButton()
        UIManager.hideAcceptVPLossButton()
        UIManager.configureForPlayerCount(playerCount)
        UIManager.showEndTurnButton()
    end, function() return not UI.loading end)
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

-- Detect building tiles dropped into the trash can (Bag) during Develop
function onObjectEnterContainer(container, obj)
    if not state or not state._pendingDevelop then return end
    if not obj or obj.isDestroyed() then return end
    if not ObjectManager.isTrashCan(container.getGUID()) then return end

    local meta = ObjectManager.parseMeta(obj)
    if meta and meta.type == "tile" then
        _onDevelopTileDropped(state._pendingDevelop.playerColor, obj, meta, true)
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
            closeUndoWindow()  -- cards dealt: lock undo (issue #9)
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

    -- Defer the hand refill until the undo window closes (issue #9): drawing a
    -- new card immediately would let a player peek then undo. The owed draw is
    -- performed by closeUndoWindow() when the window locks.
    state._undoRefillOwed = color

    -- Advance turn
    local prevCurrent = GameState.getCurrentPlayerColor(state)
    local oldRound = state.round
    TurnManager.endAction(state)
    if GameState.getCurrentPlayerColor(state) ~= prevCurrent then
        -- The next player is about to act: lock the previous player's undo and
        -- perform their deferred draw.
        closeUndoWindow()
    end
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
    -- Restrict the action buttons to the current player (per-player visibility).
    UIManager.setActionOwner(color)
    local turnText = Lang.format("your_turn", state.lang, { player = color })
    local actionsText = Lang.format("actions_remaining", state.lang, { count = state.actionsRemaining })
    UIManager.showTurnIndicator(turnText .. " — " .. actionsText)
    UIManager.showEndTurnButton()
    -- Offer undo only when the current player has an undoable committed action.
    local last = ActionEngine.getLastCommit()
    if last and last.color == color then
        UIManager.showUndoButton()
    else
        UIManager.hideUndoButton()
    end
    printToAll(turnText)
end

------------------------------------------------------
-- UNDO (issue #9)
------------------------------------------------------

-- Find the locked board tile object nearest a world position (within ~1 unit).
local function _findLockedTileNear(pos)
    if not pos then return nil end
    local best, bestD = nil, 1.0
    for _, obj in ipairs(getAllObjects()) do
        if not obj.isDestroyed() and obj.getLock and obj.getLock() then
            local p = obj.getPosition()
            local dx, dz = p.x - pos.x, p.z - pos.z
            local d = math.sqrt(dx * dx + dz * dz)
            if d < bestD then bestD, best = d, obj end
        end
    end
    return best
end

-- Return a placed tile to the acting player: unlock, turn face-up, lift it off
-- the board so they can retrieve it.
local function _returnTileToPlayer(obj)
    if not obj or obj.isDestroyed() then return end
    obj.setLock(false)
    if obj.is_face_down then obj.flip() end
    local p = obj.getPosition()
    obj.setPositionSmooth({ p.x, p.y + 3, p.z })
end

-- Re-sync money / spend / income displays for all players from restored state.
local function _resyncDerivedUI()
    for _, c in ipairs(state.turnOrder) do
        updateSpendCounterFromState(c)
        moveIncomeMarker(c)
    end
end

-- Restore the played card from the discard pile to the player's hand, and add
-- it back to the (restored, post-play) hand count.
local function _returnPlayedCardToHand(color)
    local pc = state._undoPlayedCard
    if pc and pc.color == color and pc.guid then
        local card = getObjectFromGUID(pc.guid)
        if card and not card.isDestroyed() then
            local zoneGUID = ObjectManager.guids.playerHandZones[color]
            local zone = zoneGUID and getObjectFromGUID(zoneGUID)
            if zone then card.setPositionSmooth(zone.getPosition()) end
        end
        local p = GameState.getPlayer(state, color)
        p.handSize = (p.handSize or 0) + 1
    end
end

-- Physically reverse the just-undone action's discrete board objects.
-- Resource-cube *counts* are already correct in the engine (proven by the undo
-- symmetry tests); reconciling the physical cubes on the table is a follow-up
-- item to tune against TTS.
local function _resyncPhysicalAfterUndo(record)
    _resyncDerivedUI()
    local action = record.action
    if action == "build" and record.slotId then
        _returnTileToPlayer(_findLockedTileNear(SnapMap.getPositionForSlot(record.slotId)))
    elseif action == "network" and record.params then
        for _, lid in ipairs({ record.params.linkId, record.params.secondLinkId }) do
            if lid then
                _returnTileToPlayer(_findLockedTileNear(SnapMap.getPositionForLink(lid)))
            end
        end
    elseif action == "sell" and record.params and record.params.slotIds then
        for _, sid in ipairs(record.params.slotIds) do
            local obj = _findLockedTileNear(SnapMap.getPositionForSlot(sid))
            if obj and not obj.isDestroyed() and obj.is_face_down then obj.flip() end
        end
    end
end

--- Close the undo window: perform any deferred hand refill, drop the played-card
--- reference, lock undo, and hide the button. Called when the next player acts,
--- when the same player starts their next action, or when cards are dealt.
function closeUndoWindow()
    if not state then return end
    if state._undoRefillOwed then
        CardManager.refillHand(state, state._undoRefillOwed)
        state._undoRefillOwed = nil
    end
    state._undoPlayedCard = nil
    ActionEngine.clearLastCommit()
    UIManager.hideUndoButton()
end

--- TTS UI callback for the Undo button.
function onUndoBtn(player, value, id)
    if player then onUndoAction(player.color) end
end

--- Undo the current player's last committed action and re-sync the table.
function onUndoAction(color)
    if not state then return end
    if not isCurrentPlayer(color) then
        printToColor("Not your turn.", color, {1, 0.5, 0})
        return
    end
    local record = ActionEngine.getLastCommit()
    if not record or record.color ~= color then
        printToColor("Nothing to undo — the window has closed.", color, {1, 0.5, 0})
        return
    end

    -- Logical restore: money, board, resources, income, VP, and bookkeeping.
    ActionEngine.undo(state)

    -- Physical table re-sync + return the played card to hand.
    _resyncPhysicalAfterUndo(record)
    _returnPlayedCardToHand(color)

    -- The undone action is reverted: no deferred draw, clear the window and
    -- return the player to a fresh action (card back in hand, actions restored).
    state._undoRefillOwed = nil
    state._undoPlayedCard = nil
    state._pendingCard    = nil
    Highlights.clearAll()
    UIManager.hideActionPanel()

    printToAll(color .. " undid their last action (" .. tostring(record.action) .. ").")
    broadcastCurrentPlayer()
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
    UIManager.showAcceptVPLossButton()
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
        UIManager.hideAcceptVPLossButton()
        state._currentShortfall = nil
        state._shortfallIndex = state._shortfallIndex + 1
        _startShortfallResolution()
    else
        -- Update highlights (remove destroyed tile from candidates)
        local newRemovable = TurnManager.getRemovableTiles(state, playerColor)
        if #newRemovable == 0 then
            -- No more tiles — take remaining VP loss
            Highlights.clearResourceCandidates()
            UIManager.hideAcceptVPLossButton()
            TurnManager.resolveShortfallAsVP(state, playerColor, cs.remaining)
            printToAll(Lang.format("shortfall_no_tiles", state.lang, { player = playerColor, vp = cs.remaining }))
            state._currentShortfall = nil
            state._shortfallIndex = state._shortfallIndex + 1
            _startShortfallResolution()
        end
    end
end

function onAcceptVPLoss(player, value, id)
    if not state or not state._currentShortfall then return end
    local cs = state._currentShortfall
    if cs.color ~= player.color then return end

    Highlights.clearResourceCandidates()
    UIManager.hideAcceptVPLossButton()
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

-- Maps TTS seat color to income marker GUID
-- Income markers are backgammon_piece_white objects identified by ColorDiffuse
COLOR_TO_INCOME_GUID = {
    ["Yellow"] = "8ef975",
    ["Orange"] = "c13f31",
    ["White"]  = "8f36d3",
    ["Purple"] = "c5d022",
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

    -- Update money counter (MrStump script with customSet)
    local moneyGUID = COLOR_TO_MONEY_GUID[color]
    if moneyGUID then
        setCounterValue(moneyGUID, p.money or 0)
    end

    -- Update spend tracker (no Lua script — use TTS Counter API)
    local spendGUID = COLOR_TO_SPEND_GUID[color]
    if spendGUID then
        local spendObj = getObjectFromGUID(spendGUID)
        if spendObj and spendObj.Counter then
            spendObj.Counter.setValue(p.spentThisRound or 0)
        end
    end
end

-- Reset all spend counters to 0 (new round)
function resetAllSpendCounters()
    for color, guid in pairs(COLOR_TO_SPEND_GUID) do
        local obj = getObjectFromGUID(guid)
        if obj and obj.Counter then
            obj.Counter.setValue(0)
        end
    end
end

-- Move a player's income marker to the correct board position
function moveIncomeMarker(color)
    if not state then return end
    local player = GameState.getPlayer(state, color)
    if not player then return end
    local guid = COLOR_TO_INCOME_GUID[color]
    if not guid then return end
    local obj = getObjectFromGUID(guid)
    if not obj then return end
    local pos = IncomeLayout.getPosition(player.incomeLevel, player.incomeSpace)
    if pos then
        obj.setPositionSmooth(pos)
    end
end

------------------------------------------------------
-- LANGUAGE TOGGLE
------------------------------------------------------

------------------------------------------------------
-- SETUP BUTTONS (wired from UI.xml)
------------------------------------------------------

function onSetup2P() onPhysicalSetupComplete({playerCount = 2}) end
function onSetup3P() onPhysicalSetupComplete({playerCount = 3}) end
function onSetup4P() onPhysicalSetupComplete({playerCount = 4}) end

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

--- Physically remove cubes from the market track after a state change.
--- Shared by Build (_buyMarketResources) and Develop flows.
--- Call AFTER Market.buyFromMarket has already decreased supply in state.
--- @param resourceType string  "coal" or "iron"
--- @param count number  how many cubes to remove
function _removeMarketCubesPhysical(resourceType, count)
    local marketData = (resourceType == Constants.Resource.IRON)
        and state.ironMarket or state.coalMarket
    if not marketData then return end
    if not marketData.cubeGUIDs then marketData.cubeGUIDs = {} end

    local cubeName = (resourceType == Constants.Resource.COAL)
        and Constants.ObjectName.COAL_CUBE or Constants.ObjectName.IRON_CUBE

    for i = 1, count do
        local slotIdx = marketData.supply + i
        local cubeGUID = marketData.cubeGUIDs[slotIdx]

        if cubeGUID then
            local cubeObj = getObjectFromGUID(cubeGUID)
            if cubeObj and not cubeObj.isDestroyed() then cubeObj.destruct() end
            marketData.cubeGUIDs[slotIdx] = nil
        else
            -- Fallback: find cube nearest to the now-empty track position
            local trackPos = MarketLayout.getPosition(resourceType, slotIdx)
            if trackPos then
                for _, obj in ipairs(getAllObjects()) do
                    if not obj.isDestroyed() and obj.getName() == cubeName then
                        local opos = obj.getPosition()
                        local dx = opos.x - trackPos.x
                        local dz = opos.z - trackPos.z
                        if math.sqrt(dx * dx + dz * dz) < 1.0 then
                            obj.destruct()
                            break
                        end
                    end
                end
            end
        end
    end
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
    UIManager.hideActionPanel()
    state._pendingCard = nil
    printToAll(message)
    afterAction(playerColor)
end

function onSellAction(playerColor, slotIds, merchantName)
    if not requirePendingCard(playerColor) then return end
    local result = ActionEngine.execute(state, "sell", playerColor, { slotIds = slotIds, merchantName = merchantName })
    if result.success then
        finishButtonAction(playerColor, Lang.format("player_sold", state.lang, { player = playerColor, industry = "", city = "" }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onDevelopAction(playerColor, count)
    if not requirePendingCard(playerColor) then return end
    count = count or 1

    -- Validate: check iron availability (board + market w/ money)
    local v = Validation.canDevelop(state, playerColor, { count = count })
    if not v.valid then
        printToColor(v.reason, playerColor, {1, 0, 0})
        return
    end

    -- Enter pending develop flow — player must drag tiles to trash can
    state._pendingDevelop = {
        playerColor = playerColor,
        count = count,
        tilesReceived = 0,
    }

    for _, guid in ipairs(ObjectManager.guids.trashCans) do
        local obj = getObjectFromGUID(guid)
        if obj then Highlights.highlightObject(obj, "Green") end
    end

    UIManager.hideActionPanel()
    printToColor(
        Lang.format("develop_trash_prompt", state.lang, { count = count }),
        playerColor, {0.4, 0.6, 0.8}
    )
end

--- Called when a building tile is dropped near/into the trash can during Develop.
--- @param playerColor string
--- @param tileObj TTS object
--- @param meta table|nil  pre-parsed GMNotes (avoids re-decode if caller already has it)
--- @param inBag boolean  true if tile entered the bag (onObjectEnterContainer path)
function _onDevelopTileDropped(playerColor, tileObj, meta, inBag)
    local pending = state._pendingDevelop
    if not pending then return end
    if pending.playerColor ~= playerColor then
        printToColor("Not your develop action.", playerColor, {1, 0.5, 0})
        return
    end

    -- Guard against double-fire (onObjectDrop + onObjectEnterContainer)
    local guid = tileObj and not tileObj.isDestroyed() and tileObj.getGUID()
    if not guid then return end
    if pending._processedGUIDs and pending._processedGUIDs[guid] then return end
    pending._processedGUIDs = pending._processedGUIDs or {}
    pending._processedGUIDs[guid] = true

    -- Parse metadata if caller didn't provide it
    meta = meta or ObjectManager.parseMeta(tileObj)

    -- Helper: reject tile back to original position
    local function rejectDevelopTile(reason)
        printToColor(reason, playerColor, {1, 0.3, 0.3})
        pending._processedGUIDs[guid] = nil
        if inBag then
            -- Find the trash can that contains this tile
            for _, g in ipairs(ObjectManager.guids.trashCans) do
                local bag = getObjectFromGUID(g)
                if bag then
                    local ok, extracted = pcall(bag.takeObject, {
                        guid = guid,
                        callback_function = function(obj) rejectTile(obj, playerColor) end,
                    })
                    if ok and extracted then return end
                end
            end
        else
            rejectTile(tileObj, playerColor)
        end
    end

    if meta and meta.industry and meta.level then
        -- Reject noDevelop tiles (e.g. Pottery Lv.1, Lv.3)
        local costData = BoardData.buildingCosts[meta.industry]
            and BoardData.buildingCosts[meta.industry][meta.level]
        if costData and costData.noDevelop then
            rejectDevelopTile(meta.industry .. " Lv." .. meta.level .. " cannot be developed.")
            return
        end

        -- Reject tiles that aren't the lowest developable level for their industry
        local player = GameState.getPlayer(state, playerColor)
        if player and player.unbuiltTiles and player.unbuiltTiles[meta.industry] then
            local lowestLevel = nil
            for _, tile in ipairs(player.unbuiltTiles[meta.industry]) do
                if not tile.noDevelop then
                    lowestLevel = tile.level
                    break
                end
            end
            if lowestLevel and meta.level ~= lowestLevel then
                rejectDevelopTile("Must develop lowest level first ("
                    .. meta.industry .. " Lv." .. lowestLevel .. ").")
                return
            end
        end
    end

    -- Destroy the tile (it may or may not have entered the bag)
    if tileObj and not tileObj.isDestroyed() then
        tileObj.destruct()
    end

    pending.tilesReceived = pending.tilesReceived + 1
    printToColor(
        Lang.format("develop_trash_progress", state.lang, { current = pending.tilesReceived, total = pending.count }),
        playerColor, {0.4, 0.6, 0.8}
    )

    if pending.tilesReceived >= pending.count then
        local count = pending.count
        state._pendingDevelop = nil
        Highlights.clearAll()

        -- Pre-calculate how much iron will come from the market
        -- (iron from buildings is consumed first by Actions.develop)
        local boardIron = 0
        local ironSources = Network.findIronSources(state)
        for _, src in ipairs(ironSources) do
            boardIron = boardIron + #src.slot.tile.resources
        end
        local ironFromMarket = math.max(0, count - boardIron)

        local result = ActionEngine.execute(state, "develop", playerColor, { count = count })
        if result.success then
            -- Physically remove iron cubes from the market track
            if ironFromMarket > 0 then
                _removeMarketCubesPhysical(Constants.Resource.IRON, ironFromMarket)
            end
            updateSpendCounterFromState(playerColor)
            finishButtonAction(playerColor, Lang.format("player_developed", state.lang, { player = playerColor, count = count }))
        else
            printToColor(result.error, playerColor, {1, 0, 0})
        end
    end
end

function onLoanAction(playerColor)
    if not requirePendingCard(playerColor) then return end
    local result = ActionEngine.execute(state, "loan", playerColor, {})
    if result.success then
        updateSpendCounterFromState(playerColor)
        moveIncomeMarker(playerColor)
        finishButtonAction(playerColor, Lang.format("player_loaned", state.lang, { player = playerColor }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

function onScoutAction(playerColor)
    if not requirePendingCard(playerColor) then return end

    -- Validate scout prerequisites (wilds, hand size, supply, etc.)
    local v = Validation.canScout(state, playerColor)
    if not v.valid then
        printToColor(v.reason, playerColor, {1, 0, 0})
        return
    end

    -- Enter pending discard flow — player must discard 2 cards first
    state._pendingScout = {
        playerColor = playerColor,
        cardsDiscarded = 0,
        required = 2,
    }
    UIManager.hideActionPanel()
    printToColor(Lang.get("scout_discard_prompt", state.lang), playerColor, {0.6, 0.4, 0.8})
end

--- Called from EventHandlers when a card is dropped during pending scout.
function _onScoutCardDiscarded(playerColor, cardObj)
    local pending = state._pendingScout
    if not pending then return end
    if pending.playerColor ~= playerColor then
        printToColor("Not your scout action.", playerColor, {1, 0.5, 0})
        return
    end

    -- Discard the card (moves to discard pile or returns wild to supply)
    local ok, discardResult = pcall(CardManager.discard, cardObj, playerColor)
    if discardResult == "wild_location" then
        state.wildSupply.location = (state.wildSupply.location or 0) + 1
    elseif discardResult == "wild_industry" then
        state.wildSupply.industry = (state.wildSupply.industry or 0) + 1
    end

    -- Decrement hand size
    local player = GameState.getPlayer(state, playerColor)
    player.handSize = math.max(0, (player.handSize or 0) - 1)

    pending.cardsDiscarded = pending.cardsDiscarded + 1
    printToColor(
        Lang.format("scout_discard_progress", state.lang, { current = pending.cardsDiscarded, total = pending.required }),
        playerColor, {0.6, 0.4, 0.8}
    )

    if pending.cardsDiscarded >= pending.required then
        -- All discards done — execute scout action
        state._pendingScout = nil
        local result = ActionEngine.execute(state, "scout", playerColor, {})
        if result.success then
            local dealt = CardManager.giveWilds(playerColor)
            -- Restore handSize: discards decremented it by 2, wilds add back
            local player = GameState.getPlayer(state, playerColor)
            player.handSize = (player.handSize or 0) + dealt
            finishButtonAction(playerColor, Lang.format("player_scouted", state.lang, { player = playerColor }))
        else
            printToColor(result.error, playerColor, {1, 0, 0})
        end
    end
end

function onPassAction(playerColor)
    if not requirePendingCard(playerColor) then return end
    finishButtonAction(playerColor, playerColor .. " passed")
end

------------------------------------------------------
-- UI BUTTON CALLBACKS (TTS buttons pass player, value, id)
------------------------------------------------------

function onLoanBtn(player) onLoanAction(player.color) end
function onScoutBtn(player) onScoutAction(player.color) end
function onDevelop1Btn(player) onDevelopAction(player.color, 1) end
function onDevelop2Btn(player) onDevelopAction(player.color, 2) end

function onSellBtn(player)
    local color = player.color
    if not requirePendingCard(color) then return end
    -- Show sellable buildings as clickable markers
    _startSellFlow(color)
end

function onAcceptVPLossBtn(player)
    onAcceptVPLoss(player)
end

------------------------------------------------------
-- SELL FLOW (select buildings to sell)
------------------------------------------------------

function _startSellFlow(playerColor)
    local sellable = {}
    GameState.forEachSlot(state, function(cityName, slot)
        if slot.occupant == playerColor and slot.tile
           and not slot.tile.flipped
           and helpers.tableContains(Constants.SELLABLE_INDUSTRIES, slot.tile.type) then
            -- Check merchant connectivity
            if Network.isConnectedToMerchant(state, playerColor, cityName) then
                sellable[#sellable + 1] = {
                    slotId = slot.id,
                    cityName = cityName,
                }
            end
        end
    end)

    if #sellable == 0 then
        printToColor("No sellable buildings connected to a merchant.", playerColor, {1, 0.5, 0})
        return
    end

    -- Store sell state
    state._pendingSell = {
        playerColor = playerColor,
        selectedSlots = {},
    }

    -- Show sellable buildings as clickable markers
    local candidates = {}
    for _, s in ipairs(sellable) do
        local pos = SnapMap.getPositionForSlot(s.slotId)
        if pos then
            candidates[#candidates + 1] = {
                slotId = s.slotId,
                cityName = s.cityName,
                cubesAvailable = 0,
            }
        end
    end

    Highlights.showResourceCandidates(candidates, "sell", function(slotId)
        _onSellBuildingClicked(playerColor, slotId)
    end)
    printToColor("Click a building to sell it.", playerColor, {0.2, 0.8, 0.2})
end

function _onSellBuildingClicked(playerColor, slotId)
    if not state or not state._pendingSell then return end
    if state._pendingSell.playerColor ~= playerColor then return end

    local cityName = GameState.getCityForSlot(state, slotId)
    local merchantName = Network.findConnectedMerchant(state, cityName)

    local result = ActionEngine.execute(state, "sell", playerColor, {
        slotIds = { slotId },
        merchantName = merchantName,
    })

    if result.success then
        -- Flip the physical tile on the board
        local slot = GameState.getSlot(state, slotId)
        if slot and slot.tile then
            local snapPos = SnapMap.getPositionForSlot(slotId)
            if snapPos then
                for _, obj in ipairs(getAllObjects()) do
                    if not obj.isDestroyed() and obj.getLock and obj.getLock() then
                        local opos = obj.getPosition()
                        local dx = opos.x - snapPos.x
                        local dz = opos.z - snapPos.z
                        if math.sqrt(dx*dx + dz*dz) < 1.0 then
                            obj.flip()
                            break
                        end
                    end
                end
            end
        end

        Highlights.clearResourceCandidates()
        state._pendingSell = nil
        finishButtonAction(playerColor, Lang.format("player_sold", state.lang, {
            player = playerColor, industry = "", city = cityName or "",
        }))
    else
        printToColor(result.error, playerColor, {1, 0, 0})
    end
end

------------------------------------------------------
-- SINGLE LINK BUTTON (double rail flow)
------------------------------------------------------

--- Called when the player clicks "Single Link" during a double rail flow.
function onSingleLinkOnly(player, value, id)
    if not state or not state._pendingFirstLink then return end
    local color = player.color
    if not isCurrentPlayer(color) then return end

    EventHandlers.executeSingleLink(color)
end
