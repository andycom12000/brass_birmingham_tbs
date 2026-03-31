--- EventHandlers.lua
-- Handles all TTS object events and routes them to game logic.
-- The interaction flow:
--   1. Player drops a card in the discard zone  → card parsed, valid spots highlighted
--   2. Player drops a building/link tile on a highlighted spot → action executed
--   3. Non-physical actions (Sell, Develop, Loan, Scout) use button clicks / UIManager

local EventHandlers = {}

------------------------------------------------------
-- PUBLIC API
------------------------------------------------------

--- Main entry point: called from Global.lua onObjectDrop TTS callback
-- @param playerColor  TTS seat color string ("Red", "Blue", etc.)
-- @param droppedObject  The TTS object that was just released
function EventHandlers.onObjectDrop(playerColor, droppedObject)
    local objType, meta = EventHandlers.identifyObject(droppedObject)
    if not objType then return end

    if objType == "building_tile" then
        EventHandlers.handleTilePlaced(playerColor, droppedObject, meta)
    elseif objType == "link_tile" then
        if state then
            EventHandlers.handleLinkDrop(playerColor, droppedObject)
        end
    elseif objType == "card" then
        if state and isCurrentPlayer(playerColor) then
            EventHandlers.handleCardDrop(playerColor, droppedObject)
        end
    end
end

--- Called from Global.lua onObjectPickUp TTS callback.
-- Currently used to detect if a pending action should remain active.
-- @param playerColor  TTS seat color string
-- @param obj  The TTS object that was picked up
function EventHandlers.onObjectPickUp(playerColor, obj)
    if not state then return end
    if not (state._pendingCard and state._pendingPlayer == playerColor) then return end

    local objType, _ = EventHandlers.identifyObject(obj)
    if objType ~= "card" then
        -- Player picked up a tile — they are preparing to place it.
        -- Keep the pending card alive; do not cancel.
    end
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

    -- Fallback for link tiles (no GMNotes tagging — they use Custom_Token)
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

    if dist > 5 then return end  -- not near discard zone — ignore

    -- Parse card name into structured info
    local cardInfo = CardManager.parseCard(cardObj)
    if not cardInfo then return end

    -- Wild cards are handled the same way as regular cards for action selection;
    -- a comment here flags that the wild-use count could be tracked here if needed.
    -- (cardInfo.cardType == Constants.CardType.WILD_LOCATION / WILD_INDUSTRY)

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
-- BUILDING TILE PLACED (GMNotes-aware)
------------------------------------------------------

--- Handle a building tile being dropped on the board.
-- Reads cost metadata from GMNotes and auto-deducts money from the player's
-- money counter, adding the same amount to the spend tracker.
-- Also runs the full Build action validation / state update.
-- @param playerColor  TTS seat color string
-- @param tileObj      TTS object representing a building tile
-- @param meta         GMNotes table: {type,industry,level,money,coal,iron}
function EventHandlers.handleTilePlaced(playerColor, tileObj, meta)
    -- Auto-deduct money cost whenever a building tile is dropped anywhere
    local cost = meta.money or 0
    if cost > 0 then
        EventHandlers.deductTileCost(playerColor, cost, meta)
    end

    -- If full game state is active, also run the game logic
    if state and state._pendingCard then
        local pos      = tileObj.getPosition()
        local snapInfo = SnapMap.findNearestPosition(pos, 2.0)

        if snapInfo and snapInfo.type == "slot" then
            local cityName  = GameState.getCityForSlot(state, snapInfo.id)
            local tileType  = meta.industry or EventHandlers.parseTileType(tileObj)
            local tileLevel = meta.level    or EventHandlers.parseTileLevel(tileObj)

            local result = Actions.build(state, playerColor, {
                cardType     = state._pendingCard.cardType,
                location     = cityName,
                industryType = tileType,
                level        = tileLevel,
                slotId       = snapInfo.id,
            })

            if result.success then
                Highlights.clearAll()
                state._pendingCard = nil
                ObjectManager.moveTo(tileObj, SnapMap.getPositionForSlot(snapInfo.id))
                ObjectManager.lock(tileObj)
                spawnTileResources(state, snapInfo.id)
                printToAll(Lang.format("player_built", state.lang, {
                    player   = playerColor,
                    industry = tileType,
                    level    = tileLevel,
                    city     = cityName,
                }))
                afterAction(playerColor)
            else
                printToColor(result.error, playerColor, {1, 0, 0})
                returnToPlayerArea(tileObj, playerColor)
            end
        else
            printToColor("Invalid placement.", playerColor, {1, 0, 0})
            returnToPlayerArea(tileObj, playerColor)
        end
    end
end

--- Deduct a tile's money cost from the player's money counter and update the
-- spend tracker, using the global PLAYER_SPEND accumulator so reads/writes
-- do not depend on querying button labels from counter objects.
-- @param playerColor  TTS seat color string
-- @param cost         integer money cost to deduct
-- @param meta         GMNotes table (used for announcement)
function EventHandlers.deductTileCost(playerColor, cost, meta)
    printToAll("[DEBUG] deductTileCost: color=" .. tostring(playerColor) .. " cost=" .. tostring(cost))

    -- Accumulate total spend this round
    PLAYER_SPEND[playerColor] = (PLAYER_SPEND[playerColor] or 0) + cost

    -- Update spend tracker display
    local spendGUID = COLOR_TO_SPEND_GUID[playerColor]
    printToAll("[DEBUG] spendGUID=" .. tostring(spendGUID))
    if spendGUID then
        local spendObj = getObjectFromGUID(spendGUID)
        printToAll("[DEBUG] spendObj=" .. tostring(spendObj))
        if spendObj then
            spendObj.setDescription(tostring(PLAYER_SPEND[playerColor]))
            spendObj.call('customSet')
            printToAll("[DEBUG] spend counter updated to " .. tostring(PLAYER_SPEND[playerColor]))
        end
    end

    -- Update money counter (read via getCount, then set via customSet)
    local moneyGUID = COLOR_TO_MONEY_GUID[playerColor]
    printToAll("[DEBUG] moneyGUID=" .. tostring(moneyGUID))
    if moneyGUID then
        local moneyObj = getObjectFromGUID(moneyGUID)
        printToAll("[DEBUG] moneyObj=" .. tostring(moneyObj))
        if moneyObj then
            local ok, current = pcall(function() return moneyObj.call('getCount') end)
            printToAll("[DEBUG] getCount ok=" .. tostring(ok) .. " current=" .. tostring(current))
            if ok and current then
                local remaining = current - cost
                if remaining < 0 then remaining = 0 end
                moneyObj.setDescription(tostring(remaining))
                moneyObj.call('customSet')
                printToAll("[DEBUG] money counter updated to " .. tostring(remaining))
            end
        end
    end

    -- Announce
    local INDUSTRY_LABELS = {
        cotton       = "Cotton Mill",
        coal         = "Coal Mine",
        iron         = "Iron Works",
        brewery      = "Brewery",
        manufacturer = "Manufacturer",
        pottery      = "Pottery",
    }
    local label = (INDUSTRY_LABELS[meta.industry] or meta.industry or "Building")
                  .. " Lv" .. (meta.level or "?")
    printToAll(playerColor .. " built " .. label .. " ($" .. cost .. ")")
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
        returnToPlayerArea(linkObj, playerColor)
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
            returnToPlayerArea(linkObj, playerColor)
        end
    else
        printToColor("Invalid link placement.", playerColor, {1, 0, 0})
        returnToPlayerArea(linkObj, playerColor)
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
function returnToPlayerArea(obj, playerColor)
    local board = ObjectManager.getPlayerBoard(playerColor)
    if board then
        obj.setPositionSmooth(board.getPosition() + Vector(0, 2, 0))
    end
end

return EventHandlers
