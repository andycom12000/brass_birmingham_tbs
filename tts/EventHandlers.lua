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

--- Find and flip the physical TTS tile at a board slot, and announce income.
--- Called when a coal mine or iron works has its resources exhausted.
--- @param slotId string  The slot whose tile was auto-flipped in state
--- @param occupant string  The tile owner's color
--- @param incomeSpaces number  Income spaces awarded
local function flipPhysicalTile(slotId, occupant, incomeSpaces)
    local snapPos = SnapMap.getPositionForSlot(slotId)
    if not snapPos then return end

    -- Find locked tile object near the snap position
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

    -- Announce income advance
    if occupant and incomeSpaces and incomeSpaces > 0 then
        printToAll(occupant .. " tile flipped — income +" .. incomeSpaces)
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
        EventHandlers.handleLinkDrop(playerColor, droppedObject, meta)
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
--- Save a pickup/home position for an object (called from onObjectPickUp and onObjectLeaveContainer)
function EventHandlers.savePickupPosition(guid, position)
    _pickupPositions[guid] = position
end

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

    -- Cancel pending double rail if the player picks up the first rail tile
    if state._pendingFirstLink and state._pendingFirstLink.playerColor == playerColor then
        if obj and not obj.isDestroyed() and state._pendingFirstLink.tileObj == obj then
            -- Player picked up the pending first link tile — cancel double rail
            state._pendingFirstLink = nil
            Highlights.clearAll()
            UIManager.hideSingleLinkButton()
            printToColor("Double rail cancelled.", playerColor, {1, 1, 0})
            -- Don't reject — player is holding the tile
        end
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
    local ON = Constants.ObjectName
    if name:find("^" .. ON.CANAL) or name:find("^" .. ON.RAIL) then
        local linkType = nil
        if name:find("^" .. ON.CANAL) then
            linkType = Constants.Era.CANAL
        else
            linkType = Constants.Era.RAIL
        end
        return "link_tile", { linkType = linkType }
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

    -- Move card to discard pile (or back to wild supply)
    local discardResult = CardManager.discard(cardObj)
    if discardResult == "wild_location" then
        state.wildSupply.location = (state.wildSupply.location or 0) + 1
    elseif discardResult == "wild_industry" then
        state.wildSupply.industry = (state.wildSupply.industry or 0) + 1
    end

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

    -- Find nearest city (not individual slot)
    local cityName = SnapMap.findNearestCity(buildPos, 4.0)
    if not cityName then
        printToColor("No city found near drop position.", playerColor, {1, 0, 0})
        rejectTile(tileObj, playerColor)
        return
    end

    -- City must exist in current game state (some removed for 2/3 player)
    local city = state.board.cities[cityName]
    if not city then
        printToColor(cityName .. " is not in this game.", playerColor, {1, 0, 0})
        rejectTile(tileObj, playerColor)
        return
    end

    -- Find the nearest empty slot of matching type to where the user dropped the tile
    local buildSlotId = nil
    local bestSlotDist = math.huge
    if city.slots then
        for _, s in ipairs(city.slots) do
            if not s.occupant and s.types then
                local typeMatch = false
                for _, t in ipairs(s.types) do
                    if t == meta.industry then typeMatch = true; break end
                end
                if typeMatch then
                    local slotPos = SnapMap.getPositionForSlot(s.id)
                    if slotPos then
                        local dist = SnapMap._distance(buildPos, slotPos)
                        if dist < bestSlotDist then
                            bestSlotDist = dist
                            buildSlotId = s.id
                        end
                    elseif not buildSlotId then
                        -- Fallback if no snap position: take first match
                        buildSlotId = s.id
                    end
                end
            end
        end
    end

    if not buildSlotId then
        printToColor(cityName .. " has no empty slot for " .. (meta.industry or "?"), playerColor, {1, 0, 0})
        rejectTile(tileObj, playerColor)
        return
    end

    local slot = GameState.getSlot(state, buildSlotId)

    -- Full game-rule validation via Validation.canBuild (when card flow active)
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
    local boardCoal = 0
    if coalNeeded > 0 then
        if not cityName then
            printToColor("Cannot determine city for coal connection (SnapMap not available)", playerColor, {1, 0, 0})
            rejectTile(tileObj, playerColor)
            return
        end
        -- Count ALL connected coal (not just nearest) for accurate market shortfall
        boardCoal = Network.countConnectedCoal(state, cityName)
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
    local tile = Tile.newWithResources(industryType, level, state.era)
    slot.occupant = playerColor
    slot.tile = tile

    -- Move tile to the matched slot's snap position.
    -- Wait 2 frames for TTS snap to settle, then setPosition + lock.
    local snapPos = SnapMap.getPositionForSlot(buildSlotId)
    local targetPos = snapPos
        and Vector(snapPos.x, 1.05, snapPos.z)
        or  Vector(buildPos.x, 1.05, buildPos.z)
    Wait.frames(function()
        if tileObj and not tileObj.isDestroyed() then
            tileObj.setPosition(targetPos)
            tileObj.setLock(true)
        end
    end, 2)

    -- Brewery income on placement (breweries auto-flip and give income immediately)
    if industryType == Constants.Industry.BREWERY and tile then
        Actions.advanceIncome(state, playerColor, tile.incomeSpaces or 0)
    end

    -- If no resources needed, skip directly to auto-sell / finish
    local boardIronNeeded = math.min(ironNeeded, boardIron)
    local boardCoalNeeded = math.min(coalNeeded, boardCoal)

    if ironNeeded == 0 and coalNeeded == 0 then
        EventHandlers._handleAutoSellAndFinish(playerColor, buildSlotId, buildPos, meta, cost, tileObj)
        return
    end

    -- Set up pending resource state
    state._pendingResource = {
        playerColor    = playerColor,
        buildSlotId    = buildSlotId,
        buildPos       = buildPos,
        meta           = meta,
        tileObj        = tileObj,
        ironNeeded     = boardIronNeeded,
        coalNeeded     = boardCoalNeeded,
        ironFromMarket = ironFromMarket,
        coalFromMarket = coalFromMarket,
        totalSpent     = cost,
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

    -- Auto-flip if empty — record for physical flip after animations
    if Actions.autoFlipIfEmpty(state, slot) then
        if not pending.flippedSlots then pending.flippedSlots = {} end
        pending.flippedSlots[#pending.flippedSlots + 1] = {
            slotId = slotId,
            occupant = slot.occupant,
            incomeSpaces = slot.tile.incomeSpaces or 0,
        }
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
        local price = Market.getPrice(state, resourceType)
        totalPrice = totalPrice + price

        -- State: buy from market (deducts money, decreases supply)
        Market.buyFromMarket(state, pending.playerColor, resourceType, 1)

        -- Visual: directly remove the most expensive market cube
        local cubeGUID = nil
        if #marketData.cubeGUIDs > 0 then
            cubeGUID = table.remove(marketData.cubeGUIDs, #marketData.cubeGUIDs)
        end
        if cubeGUID then
            local cubeObj = getObjectFromGUID(cubeGUID)
            if cubeObj then cubeObj.destruct() end
        else
            -- Fallback: find cube near the now-empty track position
            local emptyIdx = marketData.supply + 1
            local trackPos = MarketLayout.getPosition(resourceType, emptyIdx)
            if trackPos then
                for _, obj in ipairs(getAllObjects()) do
                    if not obj.isDestroyed() then
                        local name = obj.getName() or ""
                        local isMatch = (resourceType == Constants.Resource.COAL and name == Constants.ObjectName.COAL_CUBE)
                                     or (resourceType == Constants.Resource.IRON and name == Constants.ObjectName.IRON_CUBE)
                        if isMatch then
                            local opos = obj.getPosition()
                            local dx = opos.x - trackPos.x
                            local dz = opos.z - trackPos.z
                            if math.sqrt(dx*dx + dz*dz) < 1.0 then
                                obj.destruct()
                                break
                            end
                        end
                    end
                end
            end
        end
    end

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
        -- Physically flip any source tiles emptied during resource consumption
        if pending.flippedSlots then
            for _, info in ipairs(pending.flippedSlots) do
                flipPhysicalTile(info.slotId, info.occupant, info.incomeSpaces)
            end
        end
        EventHandlers._handleAutoSellAndFinish(
            pending.playerColor, pending.buildSlotId, pending.buildPos, pending.meta, pending.totalSpent, pending.tileObj)
    end)
end

--- After resource consumption, auto-sell produced resources to market if applicable.
-- Coal mines and iron works sell their produced cubes into empty market slots.
-- @param playerColor string  TTS seat color
-- @param buildSlotId string  The slot where the building was placed
-- @param buildPos Vector  TTS world position of the build
-- @param meta table  GMNotes metadata
-- @param totalSpent number  Total money spent so far
function EventHandlers._handleAutoSellAndFinish(playerColor, buildSlotId, buildPos, meta, totalSpent, tileObj)
    local slot = GameState.getSlot(state, buildSlotId)
    if not slot or not slot.tile then
        printToAll("[AutoSell] no slot or tile for " .. tostring(buildSlotId))
        EventHandlers._finishBuild(playerColor, meta, totalSpent)
        return
    end

    local tileType = slot.tile.type
    printToAll("[AutoSell] type=" .. tostring(tileType) .. " resources=" .. #slot.tile.resources)
    if tileType ~= Constants.Industry.COAL and tileType ~= Constants.Industry.IRON then
        EventHandlers._finishBuild(playerColor, meta, totalSpent)
        return
    end

    -- Tile position on the board
    local snapPos = SnapMap.getPositionForSlot(buildSlotId)
    local tilePos = snapPos and Vector(snapPos.x, 1.05, snapPos.z) or Vector(buildPos.x, 1.05, buildPos.z)
    local resourceType = (tileType == Constants.Industry.COAL) and Constants.Resource.COAL or Constants.Resource.IRON

    -- Calculate sell/keep counts BEFORE state mutation
    local market = Market.getMarketSupply(state, resourceType)
    local trackMax = #Market.getTrack(resourceType)
    local emptySlots = trackMax - market.supply
    local produced = #slot.tile.resources
    local sellCount = math.min(produced, emptySlots)
    local keepCount = produced - sellCount

    printToAll("[AutoSell] produced=" .. produced .. " emptySlots=" .. emptySlots .. " sell=" .. sellCount .. " keep=" .. keepCount)
    printToAll("[AutoSell] tilePos=" .. tostring(tilePos) .. " snapPos=" .. tostring(snapPos))

    if produced == 0 then
        EventHandlers._finishBuild(playerColor, meta, totalSpent)
        return
    end

    if not slot.resourceGUIDs then slot.resourceGUIDs = {} end
    if not market.cubeGUIDs then market.cubeGUIDs = {} end

    -- State mutation: auto-sell (removes resources, adds to market supply, gives money)
    local result = Actions.autoSellToMarket(state, playerColor, slot)

    -- Update money counter for sold income
    if result.sold > 0 then
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
        printToAll(playerColor .. " sold " .. result.sold .. " " .. resourceType .. " to market (+$" .. result.sold .. ")")
    end

    -- Spawn ALL produced tokens from infinite bag
    -- Sold ones go to market positions, kept ones stay on tile
    if state then state._animating = true end
    local spawnDelay = 0.25

    -- Spawn sold cubes → directly at market track positions
    for i = 1, result.sold do
        local marketIdx = market.supply - result.sold + i
        local targetPos = MarketLayout.getPosition(resourceType, marketIdx)
        Wait.time(function()
            ResourceAnimation.spawnCube(resourceType, targetPos, function(obj)
                if obj then
                    market.cubeGUIDs[marketIdx] = obj.getGUID()
                end
            end)
        end, (i - 1) * spawnDelay)
    end

    -- Spawn kept cubes → on the tile
    for i = 1, result.kept do
        local spawnPos = Vector(tilePos.x + (i - 1) * 0.5 - (result.kept - 1) * 0.25, 1.5, tilePos.z)
        Wait.time(function()
            ResourceAnimation.spawnCube(resourceType, spawnPos, function(obj)
                if obj then
                    slot.resourceGUIDs[#slot.resourceGUIDs + 1] = obj.getGUID()
                end
            end)
        end, (result.sold + i - 1) * spawnDelay)
    end

    -- After all spawns complete, flip tile if all sold, then finish
    local totalSpawns = result.sold + result.kept
    local finishDelay = totalSpawns * spawnDelay + 0.5
    Wait.time(function()
        if result.kept == 0 and tileObj and not tileObj.isDestroyed() then
            tileObj.flip()
        end
        if state then state._animating = false end
        EventHandlers._finishBuild(playerColor, meta, totalSpent)
    end, finishDelay)
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

--- Resolve a linkId from a drop position using SnapMap.
-- Handles reverse ordering fallback for BoardData consistency.
-- @param dropPos Vector  TTS world position where tile was dropped
-- @return string|nil  linkId or nil if no link found
local function resolveLinkId(dropPos)
    local snapInfo = SnapMap.findNearestPosition(dropPos, 4.0)
    local linkId = nil
    if snapInfo and snapInfo.type == "link" then
        linkId = snapInfo.id
    end

    -- Fallback: if snap didn't match a valid link in game state, try reverse ordering
    if linkId and not state.board.links[linkId] then
        local linkData = BoardData.links[linkId]
        if linkData and linkData.cities then
            local rev = linkData.cities[2] .. "-" .. linkData.cities[1]
            if state.board.links[rev] then
                linkId = rev
            end
        end
    end

    return linkId
end

--- Position and lock a link tile at its drop position.
-- @param linkObj TTS object
-- @param dropPos Vector  TTS world position
local function positionAndLockLink(linkObj, dropPos)
    linkObj.setPositionSmooth(Vector(dropPos.x, 1.05, dropPos.z), false, true)
    Wait.time(function()
        if linkObj and not linkObj.isDestroyed() then
            linkObj.setLock(true)
        end
    end, 0.5)
end

--- Execute a single rail/canal link action and finish the turn.
-- Used for canal links, single rail when double is not affordable,
-- and the executeSingleLink public function.
-- @param playerColor string  TTS seat color
-- @param linkId string  The link to build
-- @param linkObj TTS object  The link tile
-- @param dropPos Vector  TTS world position
-- @param linkType string  Constants.Era.CANAL or Constants.Era.RAIL
local function executeSingleLinkAction(playerColor, linkId, linkObj, dropPos, linkType)
    -- Snapshot money before action for calculating total spent
    local playerData = GameState.getPlayer(state, playerColor)
    local moneyBefore = playerData.money

    -- Execute action (state changes: money, coal, beer, link ownership, linksRemaining)
    local result = Actions.network(state, playerColor, { linkId = linkId })
    if not result.success then
        printToColor(result.error, playerColor, {1, 0, 0})
        rejectTile(linkObj, playerColor)
        return
    end

    -- Calculate how much money was actually spent (base cost + any market purchases)
    local totalSpent = moneyBefore - playerData.money

    -- Physical: position and lock tile
    positionAndLockLink(linkObj, dropPos)

    -- Update physical counters with total money spent
    updatePhysicalCounters(playerColor, totalSpent)

    -- Announce
    local linkData = BoardData.links[linkId]
    local isCanal = (linkType == Constants.Era.CANAL)
    local linkLabel = isCanal and "Canal" or "Rail"
    local cityInfo = ""
    if linkData and linkData.cities then
        cityInfo = " (" .. linkData.cities[1] .. " - " .. linkData.cities[2] .. ")"
    end
    printToAll(playerColor .. " built " .. linkLabel .. " link" .. cityInfo)

    -- Clear pending card and advance
    Highlights.clearAll()
    state._pendingCard = nil
    afterAction(playerColor)
end

--- Handle a link (canal/rail) tile being dropped on the board.
-- Uses centralized Validation.canNetwork() and Actions.network() for game logic.
-- Requires a pending card (play a card first).
-- Snaps to the nearest valid link point and executes the Network action.
--
-- Double rail support: In Rail era, if the player can afford double rail
-- (£15 + 2 coal + 1 beer), the first link is stored as pending and valid
-- second link positions are highlighted. The player can then place a second
-- rail tile or click "Single Link" to build only one.
--
-- @param playerColor  TTS seat color string
-- @param linkObj  TTS object representing a canal or rail tile
-- @param meta  table with linkType field (Constants.Era.CANAL or Constants.Era.RAIL)
function EventHandlers.handleLinkDrop(playerColor, linkObj, meta)
    if not state then return end
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        rejectTile(linkObj, playerColor)
        return
    end

    local linkType = meta and meta.linkType or Constants.Era.CANAL
    local dropPos = linkObj.getPosition()

    -- ================================================================
    -- Case B: Pending first link exists — this is the second rail tile
    -- ================================================================
    if state._pendingFirstLink then
        local secondLinkId = resolveLinkId(dropPos)
        if not secondLinkId then
            printToColor("No link found near drop position.", playerColor, {1, 0, 0})
            rejectTile(linkObj, playerColor)
            return
        end

        local firstLink = state._pendingFirstLink
        state._pendingFirstLink = nil

        -- Snapshot money before action
        local playerData = GameState.getPlayer(state, playerColor)
        local moneyBefore = playerData.money

        -- Execute double rail action
        local result = Actions.network(state, playerColor, {
            linkId = firstLink.linkId,
            secondLinkId = secondLinkId,
        })

        if not result.success then
            printToColor(result.error, playerColor, {1, 0, 0})
            -- Unlock and reject first tile too
            if firstLink.tileObj and not firstLink.tileObj.isDestroyed() then
                firstLink.tileObj.setLock(false)
                rejectTile(firstLink.tileObj, playerColor)
            end
            rejectTile(linkObj, playerColor)
            Highlights.clearAll()
            return
        end

        local totalSpent = moneyBefore - playerData.money

        -- Physical: position and lock both tiles
        positionAndLockLink(linkObj, dropPos)
        -- First tile already positioned; ensure it stays locked
        if firstLink.tileObj and not firstLink.tileObj.isDestroyed() then
            firstLink.tileObj.setLock(true)
        end

        -- Update physical counters
        updatePhysicalCounters(playerColor, totalSpent)

        -- Announce double rail
        local firstLinkData = BoardData.links[firstLink.linkId]
        local secondLinkData = BoardData.links[secondLinkId]
        local cityInfo1 = ""
        if firstLinkData and firstLinkData.cities then
            cityInfo1 = firstLinkData.cities[1] .. " - " .. firstLinkData.cities[2]
        end
        local cityInfo2 = ""
        if secondLinkData and secondLinkData.cities then
            cityInfo2 = secondLinkData.cities[1] .. " - " .. secondLinkData.cities[2]
        end
        printToAll(playerColor .. " built Double Rail (" .. cityInfo1 .. " + " .. cityInfo2 .. ")")

        -- Clear pending card and advance
        Highlights.clearAll()
        state._pendingCard = nil
        afterAction(playerColor)
        return
    end

    -- ================================================================
    -- Case A: No pending first link — this is the first (or only) link
    -- ================================================================
    local linkId = resolveLinkId(dropPos)
    if not linkId then
        printToColor("No link found near drop position.", playerColor, {1, 0, 0})
        rejectTile(linkObj, playerColor)
        return
    end

    -- For Rail era links, check if double rail is possible
    if state.era == Constants.Era.RAIL and linkType == Constants.Era.RAIL then
        local vDouble = Validation.canNetwork(state, playerColor, {
            linkId = linkId,
            double = true,
        })

        if vDouble.valid then
            -- Player CAN afford double rail — enter pending state
            -- First validate single too (to make sure the link itself is valid)
            local vSingle = Validation.canNetwork(state, playerColor, {
                linkId = linkId,
                double = false,
            })
            if not vSingle.valid then
                printToColor(vSingle.reason, playerColor, {1, 0, 0})
                rejectTile(linkObj, playerColor)
                return
            end

            -- Store pending first link
            state._pendingFirstLink = {
                linkId = linkId,
                tileObj = linkObj,
                dropPos = dropPos,
                playerColor = playerColor,
            }

            -- Position and lock the first tile (don't execute action yet)
            positionAndLockLink(linkObj, dropPos)

            -- Show valid second link positions
            Highlights.showValidSecondLinks(state, playerColor, linkId)

            -- Show Single Link button
            UIManager.showSingleLinkButton(playerColor)

            -- Message
            printToColor(
                "Place a second rail tile for double rail (£" .. Constants.LinkCost.DOUBLE_RAIL
                .. " + 2 coal + 1 beer), or click 'Single Link' for single rail (£"
                .. Constants.LinkCost.SINGLE_RAIL .. " + 1 coal)",
                playerColor, {0.2, 0.8, 1}
            )
            return
        end

        -- Cannot afford double rail — fall through to single rail
    end

    -- Single link (canal or rail when double is not affordable)
    -- Validate single link
    local v = Validation.canNetwork(state, playerColor, {
        linkId = linkId,
        double = false,
    })
    if not v.valid then
        printToColor(v.reason, playerColor, {1, 0, 0})
        rejectTile(linkObj, playerColor)
        return
    end

    executeSingleLinkAction(playerColor, linkId, linkObj, dropPos, linkType)
end

------------------------------------------------------
-- DOUBLE RAIL: Execute single link from pending state
------------------------------------------------------

--- Execute the pending first link as a single rail action.
-- Called when the player clicks "Single Link" or the flow is cancelled.
-- @param playerColor string  TTS seat color
function EventHandlers.executeSingleLink(playerColor)
    if not state or not state._pendingFirstLink then return end
    local firstLink = state._pendingFirstLink
    state._pendingFirstLink = nil
    Highlights.clearAll()
    UIManager.hideSingleLinkButton()

    executeSingleLinkAction(
        playerColor,
        firstLink.linkId,
        firstLink.tileObj,
        firstLink.dropPos,
        Constants.Era.RAIL
    )
end

--- Cancel the pending double rail flow.
-- Unlocks and returns the first tile, clears highlights.
-- @param playerColor string  TTS seat color
function EventHandlers.cancelPendingDoubleRail(playerColor)
    if not state or not state._pendingFirstLink then return end
    local firstLink = state._pendingFirstLink
    state._pendingFirstLink = nil
    Highlights.clearAll()
    UIManager.hideSingleLinkButton()

    -- Unlock and reject the first tile
    if firstLink.tileObj and not firstLink.tileObj.isDestroyed() then
        firstLink.tileObj.setLock(false)
        rejectTile(firstLink.tileObj, playerColor)
    end

    printToColor("Double rail cancelled.", playerColor, {1, 1, 0})
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
