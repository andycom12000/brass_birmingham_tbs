--- EventHandlers.lua
-- Handles all TTS object events and routes them to game logic.
-- The interaction flow:
--   1. Player drops a card in the discard zone  -> card parsed, valid spots highlighted
--   2. Player drops a building/link tile on a highlighted spot -> action executed
--      - Resource consumption flow: iron phase -> coal phase -> market buys -> animations -> auto-sell -> finish
--   3. Non-physical actions (Sell, Develop, Loan, Scout) use button clicks / UIManager

local EventHandlers = {}

------------------------------------------------------
-- MODULE-LEVEL HELPERS
------------------------------------------------------

local function updatePhysicalCounters(playerColor, spentAmount)
    PLAYER_SPEND[playerColor] = (PLAYER_SPEND[playerColor] or 0) + spentAmount
    local spendGUID = COLOR_TO_SPEND_GUID[playerColor]
    if spendGUID then
        local spendObj = getObjectFromGUID(spendGUID)
        if spendObj and spendObj.Counter then
            spendObj.Counter.setValue(PLAYER_SPEND[playerColor])
        end
    end
    local moneyGUID = COLOR_TO_MONEY_GUID[playerColor]
    if moneyGUID then
        local moneyObj = getObjectFromGUID(moneyGUID)
        if moneyObj then
            pcall(function()
                local player = GameState.getPlayer(state, playerColor)
                moneyObj.setDescription(tostring(player.money))
                moneyObj.call('customSet')
            end)
        end
    end
end

local INDUSTRY_LABELS = {
    cotton       = "Cotton Mill",
    coal         = "Coal Mine",
    iron         = "Iron Works",
    brewery      = "Brewery",
    manufacturer = "Manufacturer",
    pottery      = "Pottery",
}

-- Track tiles that were just rejected to prevent re-triggering on manual return
local _recentlyRejected = {}
-- Track pickup positions so rejected tiles return to their original spot
local _pickupPositions = {}

------------------------------------------------------
-- PUBLIC API
------------------------------------------------------

--- Main entry point: called from Global.lua onObjectDrop TTS callback
-- @param playerColor  TTS seat color string ("Red", "Blue", etc.)
-- @param droppedObject  The TTS object that was just released
function EventHandlers.onObjectDrop(playerColor, droppedObject)
    if not state then return end
    if state._animating then return end
    if isRecentlyRejected(droppedObject) then return end

    local objType, meta = EventHandlers.identifyObject(droppedObject)
    if not objType then return end

    if objType == "building_tile" then
        EventHandlers.handleTilePlaced(playerColor, droppedObject, meta)
    elseif objType == "link_tile" then
        EventHandlers.handleLinkDrop(playerColor, droppedObject)
    elseif objType == "card" then
        if isCurrentPlayer(playerColor) then
            EventHandlers.handleCardDrop(playerColor, droppedObject)
        end
    end
end

--- Called from Global.lua onObjectPickUp TTS callback.
-- Cancels pending resource selection if the player picks something up.
-- @param playerColor  TTS seat color string
-- @param obj  The TTS object that was picked up
function EventHandlers.onObjectPickUp(playerColor, obj)
    -- Save pickup position for all objects (used by rejectTile to return to original spot)
    if obj and not obj.isDestroyed() then
        _pickupPositions[obj.getGUID()] = obj.getPosition()
    end

    if not state then return end

    -- Cancel pending resource selection if active
    if state._pendingResource and state._pendingResource.playerColor == playerColor then
        EventHandlers.cancelPendingResource()
    end

    if not (state._pendingCard and state._pendingPlayer == playerColor) then return end

    local objType, _ = EventHandlers.identifyObject(obj)
    if objType ~= "card" then
        -- Player picked up a tile -- they are preparing to place it.
        -- Keep the pending card alive; do not cancel.
    end
end

--- Cancel any active resource selection flow and clean up state.
function EventHandlers.cancelPendingResource()
    if not state or not state._pendingResource then return end
    Highlights.clearResourceCandidates()
    state._pendingResource = nil
end

------------------------------------------------------
-- OBJECT IDENTIFICATION
------------------------------------------------------

--- Determine what kind of game object this TTS object represents.
-- Uses GMNotes JSON metadata (set by inject_scripts.py tag_all_cards) as the
-- primary source.  Falls back to name-pattern heuristics for link tiles and
-- objects that pre-date the tagging pass.
-- @param obj  TTS object
-- @return ("card"|"building_tile"|"link_tile"|nil), (meta table|nil)
function EventHandlers.identifyObject(obj)
    if not obj or obj.isDestroyed() then return nil, nil end

    -- Primary: GMNotes JSON metadata
    local notes = obj.getGMNotes()
    if notes and notes ~= "" then
        local ok, meta = pcall(JSON.decode, notes)
        if ok and meta then
            if meta.type == "tile" then return "building_tile", meta end
            if meta.type == "card" then return "card", meta end
        end
    end

    -- Fallback for link tiles (no GMNotes tagging -- they use Custom_Token)
    local name = obj.getName() or ""
    if name:find("^Canal") or name:find("^Rail") then
        return "link_tile", nil
    end

    return nil, nil
end

------------------------------------------------------
-- CARD DROP
------------------------------------------------------

--- Handle a card being dropped anywhere on the table.
-- Ignores the drop if the card is not near the discard zone.
-- On success: stores pending card state and shows highlighted valid spots.
-- @param playerColor  TTS seat color string
-- @param cardObj  TTS card object
function EventHandlers.handleCardDrop(playerColor, cardObj)
    -- Must land near the discard zone
    local discardZone = ObjectManager.getObject("discardZone")
    if not discardZone then return end

    local cardPos  = cardObj.getPosition()
    local zonePos  = discardZone.getPosition()
    local dist = math.sqrt(
        (cardPos.x - zonePos.x)^2 + (cardPos.z - zonePos.z)^2
    )

    if dist > 5 then return end  -- not near discard zone -- ignore

    -- Parse card name into structured info
    local cardInfo = CardManager.parseCard(cardObj)
    if not cardInfo then return end

    -- Record pending action state
    state._pendingCard   = cardInfo
    state._pendingPlayer = playerColor

    -- Deduct card from hand tracking
    GameState.playCard(state, playerColor)

    -- Move card to discard pile
    CardManager.discard(cardObj)

    -- Highlight valid build and/or link spots based on the card played
    Highlights.showValidBuildSpots(state, playerColor, cardInfo)

    printToColor(
        "Card played. Drop a building or link tile on a highlighted spot, or use the action buttons.",
        playerColor
    )
end

------------------------------------------------------
-- BUILDING TILE PLACED -- Full resource consumption flow
------------------------------------------------------

--- Handle a building tile being dropped on the board.
-- Validates placement, checks affordability (base cost + market shortfall),
-- then enters the resource consumption flow: iron phase -> coal phase ->
-- market purchases -> animations -> auto-sell -> finish.
-- @param playerColor  TTS seat color string
-- @param tileObj      TTS object representing a building tile
-- @param meta         GMNotes table: {type,industry,level,money,coal,iron}
function EventHandlers.handleTilePlaced(playerColor, tileObj, meta)
    if not state then return end

    local cost = meta.money or 0
    local coalNeeded = meta.coal or 0
    local ironNeeded = meta.iron or 0

    local buildPos = tileObj.getPosition()
    local snapInfo = SnapMap.findNearestPosition(buildPos, 2.0)
    if not snapInfo or snapInfo.type ~= "slot" then
        printToColor("Invalid placement: no valid board slot found.", playerColor, {1, 0, 0})
        rejectTile(tileObj, playerColor)
        return
    end

    local buildSlotId = snapInfo.id
    local cityName = GameState.getCityForSlot(state, buildSlotId)

    -- Full game-rule validation via Validation.canBuild
    if state._pendingCard then
        local v = Validation.canBuild(state, playerColor, {
            cardType     = state._pendingCard.cardType,
            location     = state._pendingCard.location or cityName,
            industryType = meta.industry,
            level        = meta.level,
            slotId       = buildSlotId,
        })
        if not v.valid then
            printToColor(v.reason, playerColor, {1, 0, 0})
            rejectTile(tileObj, playerColor)
            return
        end
    end

    -- Count board resources and calculate market shortfall
    local cachedIronSources = {}
    local boardIron = 0
    if ironNeeded > 0 then
        cachedIronSources = Network.findIronSources(state)
        for _, src in ipairs(cachedIronSources) do
            boardIron = boardIron + #src.slot.tile.resources
        end
    end

    -- Coal requires knowing the city for BFS connectivity
    local cachedCoalSources = {}
    local boardCoal = 0
    if coalNeeded > 0 then
        if not cityName then
            printToColor("Cannot determine city for coal connection (SnapMap not available)", playerColor, {1, 0, 0})
            rejectTile(tileObj, playerColor)
            return
        end
        cachedCoalSources = Network.findNearestCoal(state, cityName) or {}
        for _, src in ipairs(cachedCoalSources) do
            boardCoal = boardCoal + #src.slot.tile.resources
        end
    end

    local ironFromMarket = math.max(0, ironNeeded - boardIron)
    local coalFromMarket = math.max(0, coalNeeded - boardCoal)

    -- Coal market access check
    if coalFromMarket > 0 then
        if not Network.hasMarketConnection(state, playerColor, cityName) then
            printToColor("Cannot buy coal: no connection to merchant", playerColor, {1, 0, 0})
            rejectTile(tileObj, playerColor)
            return
        end
    end

    -- Affordability check (baseMoney + market shortfall costs)
    local coalMarketCost = Market.estimateCost(state, Constants.Resource.COAL, coalFromMarket)
    local ironMarketCost = Market.estimateCost(state, Constants.Resource.IRON, ironFromMarket)
    local totalCost = cost + coalMarketCost + ironMarketCost

    local player = GameState.getPlayer(state, playerColor)
    if player.money < totalCost then
        printToColor("Not enough money: need $" .. totalCost .. ", have $" .. player.money, playerColor, {1, 0, 0})
        rejectTile(tileObj, playerColor)
        return
    end

    -- === All checks passed -- commit state changes ===

    -- Deduct ONLY base building cost (market costs deducted by buyFromMarket later)
    if cost > 0 then
        GameState.spendMoney(state, playerColor, cost)
        updatePhysicalCounters(playerColor, cost)
    end

    -- Place tile on slot
    local slot = GameState.getSlot(state, buildSlotId)
    local industryType = meta.industry
    local level = meta.level

    -- Handle overbuilding
    if slot.occupant then
        slot.occupant = nil
        slot.tile = nil
    end

    -- Remove tile from unbuilt stack
    Actions.removeTileFromUnbuilt(player, industryType, level)

    -- Create tile and place on slot
    local tile = Tile.newWithResources(industryType, level)
    slot.occupant = playerColor
    slot.tile = tile

    -- Snap to position
    local snapPos = SnapMap.getPositionForSlot(buildSlotId)
    if snapPos then
        ObjectManager.moveTo(tileObj, snapPos)
    end

    -- Lock after a short delay to let smooth movement finish
    Wait.time(function()
        if tileObj and not tileObj.isDestroyed() then
            tileObj.setLock(true)
        end
    end, 0.3)

    -- Brewery income on placement (breweries auto-flip and give income immediately)
    if industryType == Constants.Industry.BREWERY and tile then
        Actions.advanceIncome(state, playerColor, tile.incomeSpaces or 0)
    end

    -- If no resources needed, skip directly to auto-sell / finish
    local boardIronNeeded = math.min(ironNeeded, boardIron)
    local boardCoalNeeded = math.min(coalNeeded, boardCoal)

    if ironNeeded == 0 and coalNeeded == 0 then
        -- No resources needed at all
        EventHandlers._handleAutoSellAndFinish(playerColor, buildSlotId, buildPos, meta, cost)
        return
    end

    -- Set up pending resource state
    state._pendingResource = {
        playerColor    = playerColor,
        buildSlotId    = buildSlotId,
        buildPos       = buildPos,
        meta           = meta,
        ironNeeded     = boardIronNeeded,
        coalNeeded     = boardCoalNeeded,
        ironFromMarket = ironFromMarket,
        coalFromMarket = coalFromMarket,
        totalSpent     = cost,  -- will accumulate market costs
        phase          = Constants.Resource.IRON,
        candidates     = {},
        moves          = {},
        cachedIronSources = cachedIronSources,
        cachedCoalSources = cachedCoalSources,
    }

    -- Start iron phase
    EventHandlers._startResourcePhase(state._pendingResource)
end

------------------------------------------------------
-- RESOURCE PHASE FUNCTIONS
------------------------------------------------------

--- Begin consuming resources for the current phase (iron or coal).
-- If only one source exists, auto-consume. If multiple, show choice UI.
-- @param pending table  The _pendingResource state table
function EventHandlers._startResourcePhase(pending)
    local resourceType = pending.phase
    local needed = (resourceType == Constants.Resource.IRON) and pending.ironNeeded or pending.coalNeeded

    if needed <= 0 then
        EventHandlers._advanceResourcePhase(pending)
        return
    end

    -- Use cached sources
    local sources = (resourceType == Constants.Resource.IRON)
        and pending.cachedIronSources
        or pending.cachedCoalSources

    -- Build candidates
    local candidates = {}
    for _, src in ipairs(sources or {}) do
        if src.slot and src.slot.tile and #src.slot.tile.resources > 0 then
            candidates[#candidates + 1] = {
                slotId = src.slotId,
                cityName = src.cityName,
                cubesAvailable = #src.slot.tile.resources,
            }
        end
    end
    pending.candidates = candidates

    if #candidates == 0 then
        EventHandlers._advanceResourcePhase(pending)
    elseif #candidates == 1 then
        -- Auto-consume from only source
        local avail = math.min(needed, candidates[1].cubesAvailable)
        for _ = 1, avail do
            EventHandlers._consumeOneFromSource(pending, candidates[1].slotId)
        end
        -- Source exhausted or need met -- advance
        EventHandlers._advanceResourcePhase(pending)
    else
        -- Multiple sources: highlight for player choice
        Highlights.showResourceCandidates(candidates, resourceType, function(slotId)
            EventHandlers.onResourceCandidateClicked(pending.playerColor, slotId)
        end)
    end
end

--- Advance from the current resource phase to the next.
-- Iron -> buy market iron -> Coal -> buy market coal -> animate -> finish.
-- @param pending table  The _pendingResource state table
function EventHandlers._advanceResourcePhase(pending)
    if pending.phase == Constants.Resource.IRON then
        -- Buy market iron
        EventHandlers._buyMarketResources(pending, Constants.Resource.IRON)
        -- Move to coal
        pending.phase = Constants.Resource.COAL
        EventHandlers._startResourcePhase(pending)
    elseif pending.phase == Constants.Resource.COAL then
        -- Buy market coal
        EventHandlers._buyMarketResources(pending, Constants.Resource.COAL)
        -- Move to animation
        pending.phase = "animate"
        EventHandlers._playAnimationsAndFinish(pending)
    end
end

--- Consume one resource cube from a board source.
-- Removes a resource from the tile, returns it to market, queues animation,
-- and auto-flips tile if empty.
-- @param pending table  The _pendingResource state table
-- @param slotId string  The slot to consume from
function EventHandlers._consumeOneFromSource(pending, slotId)
    local slot = GameState.getSlot(state, slotId)
    if not slot or not slot.tile or #slot.tile.resources == 0 then return end

    local resourceType = pending.phase

    -- Remove one resource from tile
    table.remove(slot.tile.resources, #slot.tile.resources)

    -- Get cube GUID for animation
    local cubeGUID = nil
    if slot.resourceGUIDs and #slot.resourceGUIDs > 0 then
        cubeGUID = table.remove(slot.resourceGUIDs, #slot.resourceGUIDs)
    end

    -- Return to market (state update)
    Market.returnToMarket(state, resourceType, 1)

    -- Queue animation: cube flies to market track
    if cubeGUID then
        local marketSupply = Market.getMarketSupply(state, resourceType).supply
        local targetPos = MarketLayout.getPosition(resourceType, marketSupply)
        pending.moves[#pending.moves + 1] = {
            guid = cubeGUID,
            targetPos = targetPos,
            destroyAfter = false,
        }
        -- Track GUID in market
        local marketCubes = Market.getMarketSupply(state, resourceType)
        if not marketCubes.cubeGUIDs then marketCubes.cubeGUIDs = {} end
        marketCubes.cubeGUIDs[marketSupply] = cubeGUID
    end

    -- Auto-flip if empty
    if #slot.tile.resources == 0 then
        Actions.autoFlipIfEmpty(state, slot)
    end

    -- Decrement need
    if resourceType == Constants.Resource.IRON then
        pending.ironNeeded = pending.ironNeeded - 1
    else
        pending.coalNeeded = pending.coalNeeded - 1
    end
end

--- Handle player clicking a resource candidate marker.
-- Consumes one resource from the clicked source and updates the UI.
-- @param playerColor string  TTS seat color
-- @param slotId string  The slot that was clicked
function EventHandlers.onResourceCandidateClicked(playerColor, slotId)
    local pending = state._pendingResource
    if not pending then return end
    if pending.playerColor ~= playerColor then return end

    EventHandlers._consumeOneFromSource(pending, slotId)

    local resourceType = pending.phase
    local remaining = (resourceType == Constants.Resource.IRON) and pending.ironNeeded or pending.coalNeeded

    if remaining <= 0 then
        Highlights.clearResourceCandidates()
        EventHandlers._advanceResourcePhase(pending)
    else
        -- Update candidates (remove exhausted sources)
        local newCandidates = {}
        for _, cand in ipairs(pending.candidates) do
            local s = GameState.getSlot(state, cand.slotId)
            if s and s.tile and #s.tile.resources > 0 then
                cand.cubesAvailable = #s.tile.resources
                newCandidates[#newCandidates + 1] = cand
            end
        end
        pending.candidates = newCandidates

        if #newCandidates <= 1 then
            Highlights.clearResourceCandidates()
            if #newCandidates == 1 then
                local avail = math.min(remaining, newCandidates[1].cubesAvailable)
                for _ = 1, avail do
                    EventHandlers._consumeOneFromSource(pending, newCandidates[1].slotId)
                end
            end
            EventHandlers._advanceResourcePhase(pending)
        else
            Highlights.showResourceCandidates(newCandidates, resourceType, function(sid)
                EventHandlers.onResourceCandidateClicked(playerColor, sid)
            end)
        end
    end
end

------------------------------------------------------
-- MARKET PURCHASE HELPER
------------------------------------------------------

--- Buy resources from the market, deducting money and queuing animations.
-- @param pending table  The _pendingResource state table
-- @param resourceType string  Constants.Resource.COAL or Constants.Resource.IRON
function EventHandlers._buyMarketResources(pending, resourceType)
    local fromMarket = (resourceType == Constants.Resource.IRON) and pending.ironFromMarket or pending.coalFromMarket
    if fromMarket <= 0 then return end

    local marketData = Market.getMarketSupply(state, resourceType)
    if not marketData.cubeGUIDs then marketData.cubeGUIDs = {} end

    local totalPrice = 0
    for _ = 1, fromMarket do
        -- Get price before buying (for tracking)
        local price = Market.getPrice(state, resourceType)
        totalPrice = totalPrice + price

        -- Actually buy (deducts money, decreases supply)
        Market.buyFromMarket(state, pending.playerColor, resourceType, 1)

        -- Queue animation: cube from market to build site (destroyed on arrival)
        local cubeGUID = nil
        if marketData.cubeGUIDs and #marketData.cubeGUIDs > 0 then
            cubeGUID = table.remove(marketData.cubeGUIDs, #marketData.cubeGUIDs)
        end
        if cubeGUID then
            pending.moves[#pending.moves + 1] = {
                guid = cubeGUID,
                targetPos = pending.buildPos + Vector(0, 1, 0),
                destroyAfter = true,
            }
        end
    end

    -- Update counters once after all market purchases
    pending.totalSpent = pending.totalSpent + totalPrice
    updatePhysicalCounters(pending.playerColor, totalPrice)
end

------------------------------------------------------
-- ANIMATION + AUTO-SELL + FINISH
------------------------------------------------------

--- Play all queued cube animations, then proceed to auto-sell and finish.
-- @param pending table  The _pendingResource state table
function EventHandlers._playAnimationsAndFinish(pending)
    ResourceAnimation.play(pending.moves, function()
        EventHandlers._handleAutoSellAndFinish(
            pending.playerColor, pending.buildSlotId, pending.buildPos, pending.meta, pending.totalSpent)
    end)
end

--- After resource consumption, auto-sell produced resources to market if applicable.
-- Coal mines and iron works sell their produced cubes into empty market slots.
-- @param playerColor string  TTS seat color
-- @param buildSlotId string  The slot where the building was placed
-- @param buildPos Vector  TTS world position of the build
-- @param meta table  GMNotes metadata
-- @param totalSpent number  Total money spent so far
function EventHandlers._handleAutoSellAndFinish(playerColor, buildSlotId, buildPos, meta, totalSpent)
    local slot = GameState.getSlot(state, buildSlotId)
    if slot and slot.tile then
        local tileType = slot.tile.type
        if tileType == Constants.Industry.COAL or tileType == Constants.Industry.IRON then
            -- Use Actions.autoSellToMarket for state mutation
            local result = Actions.autoSellToMarket(state, playerColor, slot)

            if result.sold > 0 or result.kept > 0 then
                if state then state._animating = true end
                local resourceType = (tileType == Constants.Industry.COAL) and Constants.Resource.COAL or Constants.Resource.IRON

                -- Animate sold cubes: spawn at build site, move to market
                for i = 1, result.sold do
                    local marketSupply = Market.getMarketSupply(state, resourceType).supply - result.sold + i
                    local targetPos = MarketLayout.getPosition(resourceType, marketSupply)
                    Wait.time(function()
                        ResourceAnimation.spawnAndMoveCube(resourceType, buildPos + Vector(0, 0.5, 0), targetPos, function(obj)
                            if obj then
                                local marketData = Market.getMarketSupply(state, resourceType)
                                if not marketData.cubeGUIDs then marketData.cubeGUIDs = {} end
                                marketData.cubeGUIDs[marketSupply] = obj.getGUID()
                            end
                        end)
                    end, (i - 1) * ResourceAnimation.MOVE_INTERVAL)
                end

                -- Spawn kept cubes on tile
                for i = 1, result.kept do
                    local spawnPos = buildPos + Vector(0, 0.3 + (i - 1) * 0.4, 0)
                    ResourceAnimation.spawnCube(resourceType, spawnPos, function(obj)
                        if obj then
                            if not slot.resourceGUIDs then slot.resourceGUIDs = {} end
                            slot.resourceGUIDs[#slot.resourceGUIDs + 1] = obj.getGUID()
                        end
                    end)
                end

                -- Wait for sell animations then finish
                local delay = math.max(result.sold, 1) * ResourceAnimation.MOVE_INTERVAL
                            + ResourceAnimation.MOVE_DURATION
                            + ResourceAnimation.ARRIVE_BUFFER
                Wait.time(function()
                    if state then state._animating = false end
                    EventHandlers._finishBuild(playerColor, meta, totalSpent)
                end, delay)
                return
            end
        end
    end

    -- No auto-sell needed
    EventHandlers._finishBuild(playerColor, meta, totalSpent)
end

--- Final step: announce build, clean up state, and advance turn.
-- @param playerColor string  TTS seat color
-- @param meta table  GMNotes metadata
-- @param totalSpent number  Total money spent
function EventHandlers._finishBuild(playerColor, meta, totalSpent)
    local label = (INDUSTRY_LABELS[meta.industry] or meta.industry or "Building")
                  .. " Lv" .. (meta.level or "?")
    printToAll(playerColor .. " built " .. label .. " ($" .. totalSpent .. " total)")

    state._pendingResource = nil

    if state._pendingCard then
        Highlights.clearAll()
        state._pendingCard = nil
        afterAction(playerColor)
    end
end

------------------------------------------------------
-- LINK TILE DROP
------------------------------------------------------

--- Handle a link (canal/rail) tile being dropped on the board.
-- Requires a pending card (play a card first).
-- Snaps to the nearest valid link point and executes the Network action.
-- @param playerColor  TTS seat color string
-- @param linkObj  TTS object representing a canal or rail tile
function EventHandlers.handleLinkDrop(playerColor, linkObj)
    if not isCurrentPlayer(playerColor) then return end

    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        rejectTile(linkObj, playerColor)
        return
    end

    local pos      = linkObj.getPosition()
    local snapInfo = SnapMap.findNearestPosition(pos, 2.0)

    if snapInfo and snapInfo.type == "link" then
        local result = Actions.network(state, playerColor, {
            linkId = snapInfo.id,
        })

        if result.success then
            Highlights.clearAll()
            state._pendingCard = nil

            ObjectManager.moveTo(linkObj, SnapMap.getPositionForLink(snapInfo.id))
            ObjectManager.lock(linkObj)

            local linkData = BoardData.links[snapInfo.id]
            local cities   = linkData and linkData.cities or {"?", "?"}

            printToAll(Lang.format("player_linked", state.lang, {
                player = playerColor,
                city1  = cities[1],
                city2  = cities[2],
            }))

            afterAction(playerColor)
        else
            printToColor(result.error, playerColor, {1, 0, 0})
            rejectTile(linkObj, playerColor)
        end
    else
        printToColor("Invalid link placement.", playerColor, {1, 0, 0})
        rejectTile(linkObj, playerColor)
    end
end

------------------------------------------------------
-- TILE PARSING FALLBACKS
------------------------------------------------------

--- Infer industry type from a tile object's name.
-- Used when the tile object does not have GMNotes set.
-- @param tileObj  TTS object
-- @return Constants.Industry string or nil
function EventHandlers.parseTileType(tileObj)
    local name = (tileObj.getName() or ""):lower()
    for _, ind in pairs(Constants.Industry) do
        if name:find(ind) then return ind end
    end
    return nil
end

--- Infer building level from a tile object's description.
-- Description convention: "Lv2", "Lv3", etc.
-- Defaults to level 1 when not found.
-- @param tileObj  TTS object
-- @return integer level
function EventHandlers.parseTileLevel(tileObj)
    local desc  = tileObj.getDescription() or ""
    local level = desc:match("Lv(%d+)")
    return level and tonumber(level) or 1
end

------------------------------------------------------
-- MODULE-PRIVATE HELPERS
------------------------------------------------------

--- Spawn resource tokens on top of a freshly placed building.
-- Reads slot.tile.resources from game state and spawns each via ObjectManager.
-- @param gameState  Game state object
-- @param slotId  Building slot identifier string
function spawnTileResources(gameState, slotId)
    local slot = GameState.getSlot(gameState, slotId)
    if not slot or not slot.tile or not slot.tile.resources then return end

    local basePos = SnapMap.getPositionForSlot(slotId)
    if not basePos then return end

    for i, resType in ipairs(slot.tile.resources) do
        local offset = Vector(0, 0.3 + (i - 1) * 0.4, 0)
        ObjectManager.spawnResource(resType, basePos + offset)
    end
end

--- Smoothly return a tile to its owner's player board area.
-- Used when an action validation fails to keep the table tidy.
-- @param obj  TTS object to return
-- @param playerColor  TTS seat color string
function rejectTile(obj, playerColor)
    local guid = obj.getGUID()

    -- Mark as recently rejected (prevents re-processing for 2 seconds)
    _recentlyRejected[guid] = true
    Wait.time(function() _recentlyRejected[guid] = nil end, 2.0)

    -- Return to original pickup position (where the tile was before the player grabbed it)
    local originalPos = _pickupPositions[guid]
    _pickupPositions[guid] = nil
    if originalPos then
        obj.setPositionSmooth(originalPos)
        return
    end

    -- Fallback: center of player board
    local boardGUID = COLOR_TO_BOARD_GUID and COLOR_TO_BOARD_GUID[playerColor]
    if boardGUID then
        local board = getObjectFromGUID(boardGUID)
        if board then
            obj.setPositionSmooth(board.getPosition() + Vector(0, 2, 0))
            return
        end
    end

    -- Last resort: lift above drop point
    local pos = obj.getPosition()
    obj.setPositionSmooth(Vector(pos.x, pos.y + 3, pos.z))
end

function isRecentlyRejected(obj)
    return _recentlyRejected[obj.getGUID()] == true
end

return EventHandlers
