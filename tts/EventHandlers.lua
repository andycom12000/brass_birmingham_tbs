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
    if not state then return end
    if not isCurrentPlayer(playerColor) then return end

    local objType = EventHandlers.identifyObject(droppedObject)

    if objType == "card" then
        EventHandlers.handleCardDrop(playerColor, droppedObject)
    elseif objType == "building_tile" then
        EventHandlers.handleBuildingDrop(playerColor, droppedObject)
    elseif objType == "link_tile" then
        EventHandlers.handleLinkDrop(playerColor, droppedObject)
    end
end

--- Called from Global.lua onObjectPickUp TTS callback.
-- Currently used to detect if a pending action should remain active.
-- @param playerColor  TTS seat color string
-- @param obj  The TTS object that was picked up
function EventHandlers.onObjectPickUp(playerColor, obj)
    if not state then return end
    if not (state._pendingCard and state._pendingPlayer == playerColor) then return end

    local objType = EventHandlers.identifyObject(obj)
    if objType ~= "card" then
        -- Player picked up a tile — they are preparing to place it.
        -- Keep the pending card alive; do not cancel.
    end
end

------------------------------------------------------
-- OBJECT IDENTIFICATION
------------------------------------------------------

--- Determine what kind of game object this TTS object represents.
-- Checks object tags first (most reliable), then falls back to name patterns.
-- @param obj  TTS object
-- @return "card" | "building_tile" | "link_tile" | "resource" | "money" | nil
function EventHandlers.identifyObject(obj)
    if not obj or obj.isDestroyed() then return nil end

    local name = obj.getName() or ""
    local tags  = obj.getTags and obj.getTags() or {}

    -- Tags are set up in TTS and are the authoritative source
    for _, tag in ipairs(tags) do
        if tag == "Card" or tag == "card" then return "card" end
        if tag == "BuildingTile"           then return "building_tile" end
        if tag == "LinkTile"               then return "link_tile" end
        if tag == "Resource"               then return "resource" end
        if tag == "Money"                  then return "money" end
    end

    -- Fallback: infer from naming conventions used in CardManager.parseCard
    if name:find("^Location:") or name:find("^Industry:") or name:find("^Wild") then
        return "card"
    end

    -- Building tile names: e.g. "Cotton Tile", "Iron Tile Lv2", "Brewery Tile"
    if name:find("Tile$") then
        if name:find("Cotton") or name:find("Coal") or name:find("Iron")
            or name:find("Brewery") or name:find("Manufacturer") or name:find("Pottery") then
            return "building_tile"
        end
    end

    -- Link tile names: e.g. "Canal", "Rail"
    if name:find("^Canal") or name:find("^Rail") then
        return "link_tile"
    end

    return nil
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
-- BUILDING TILE DROP
------------------------------------------------------

--- Handle a building tile being dropped on the board.
-- Requires a pending card (play a card first).
-- Snaps to the nearest valid slot and executes the Build action.
-- @param playerColor  TTS seat color string
-- @param tileObj  TTS object representing a building tile
function EventHandlers.handleBuildingDrop(playerColor, tileObj)
    if not state._pendingCard then
        printToColor("Play a card first.", playerColor, {1, 0.5, 0})
        returnToPlayerArea(tileObj, playerColor)
        return
    end

    local pos      = tileObj.getPosition()
    local snapInfo = SnapMap.findNearestPosition(pos, 2.0)

    if snapInfo and snapInfo.type == "slot" then
        local cityName = GameState.getCityForSlot(state, snapInfo.id)
        local tileType = tileObj.getVar("industryType")
                      or EventHandlers.parseTileType(tileObj)
        local tileLevel = tileObj.getVar("level")
                       or EventHandlers.parseTileLevel(tileObj)

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

------------------------------------------------------
-- LINK TILE DROP
------------------------------------------------------

--- Handle a link (canal/rail) tile being dropped on the board.
-- Requires a pending card (play a card first).
-- Snaps to the nearest valid link point and executes the Network action.
-- @param playerColor  TTS seat color string
-- @param linkObj  TTS object representing a canal or rail tile
function EventHandlers.handleLinkDrop(playerColor, linkObj)
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

            local linkData = require("src/BoardData").links[snapInfo.id]
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
-- Used when the tile object does not have the "industryType" script variable set.
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
