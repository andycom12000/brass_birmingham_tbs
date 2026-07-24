--- Highlights.lua
-- Provides visual highlighting on TTS objects for legal moves
-- Spawns temporary marker tokens and applies highlight glow to objects

local Highlights = {}

-- Active highlights tracking for cleanup
Highlights.activeHighlights = {
    markers = {},      -- list of spawned temporary marker objects
    objects = {},      -- list of highlighted game objects
}

--- Highlight a single object with a colored glow
-- @param obj TTS object to highlight
-- @param color TTS color string or RGB table (default green)
function Highlights.highlightObject(obj, color)
    if not obj or obj.isDestroyed() then return end

    local colorTable = color or {0, 1, 0}  -- default green
    -- Convert color string to RGB if needed
    if type(color) == "string" then
        colorTable = Highlights._colorStringToRGB(color)
    end

    obj.highlightOn(colorTable, -1)  -- -1 = permanent until cleared
    table.insert(Highlights.activeHighlights.objects, obj)
end

--- Spawn a temporary marker at a world position
-- Uses a BlockSquare (built-in, no import dialog) with transparency
-- @param position Vector or table {x, y, z}
-- @param color TTS color string or RGB table (default green)
-- @return Spawned object or nil
function Highlights._spawnMarker(position, color)
    local colorTable = color or {0, 1, 0}  -- default green
    if type(color) == "string" then
        colorTable = Highlights._colorStringToRGB(color)
    end

    -- Use BlockSquare (built-in object, no import needed)
    local marker = spawnObject({
        type = "BlockSquare",
        position = Vector(position.x, position.y + 0.5, position.z),
        rotation = {0, 0, 0},
        scale = {1.2, 0.1, 1.2},
    })

    if marker then
        -- Set color with transparency (alpha = 0.4)
        marker.setColorTint({colorTable[1], colorTable[2], colorTable[3], 0.4})
        marker.setLock(true)
        marker.interactable = false
        table.insert(Highlights.activeHighlights.markers, marker)
    end

    return marker
end

--- Convert color string to RGB table
-- @param colorStr TTS color name ("Red", "Green", "Blue", "Yellow", "White", "Black")
-- @return RGB table {r, g, b}
function Highlights._colorStringToRGB(colorStr)
    local colors = {
        Red = {1, 0, 0},
        Green = {0, 1, 0},
        Blue = {0, 0, 1},
        Yellow = {1, 1, 0},
        White = {1, 1, 1},
        Black = {0, 0, 0},
    }
    return colors[colorStr] or {0, 1, 0}  -- default to green
end

--- Show valid build spots for a given card
-- Checks each slot via Validation.canBuild and highlights valid ones
-- @param state Game state object
-- @param color Player color string
-- @param cardInfo Table with cardType, location (for location cards), industryType, level
function Highlights.showValidBuildSpots(state, color, cardInfo)
    Highlights.clearAll()

    local validSlots = {}

    -- Build the list of industry types to try for this card.
    -- Industry cards: check only the card's allowed industries.
    -- Location/wild cards: try ALL industry types the player has tiles for.
    local industryList = cardInfo.industryTypes or {}
    if #industryList == 0 and cardInfo.industryType then
        industryList = { cardInfo.industryType }
    end

    -- For location/wild cards, try every industry type the player has unbuilt tiles for
    if #industryList == 0 then
        local player = GameState.getPlayer(state, color)
        if player and player.unbuiltTiles then
            for indType, stack in pairs(player.unbuiltTiles) do
                if #stack > 0 then
                    industryList[#industryList + 1] = indType
                end
            end
        end
    end

    local seen = {}  -- avoid duplicate markers for the same slot

    -- Iterate through all slots and check if build is valid
    GameState.forEachSlot(state, function(cityName, slot)
        if seen[slot.id] then return end

        for _, indType in ipairs(industryList) do
            -- Determine the lowest available tile level for this industry
            local player = GameState.getPlayer(state, color)
            local stack = player and player.unbuiltTiles and player.unbuiltTiles[indType]
            local level = (stack and #stack > 0) and stack[1].level or 1

            local buildParams = {
                cardType     = cardInfo.cardType,
                location     = cardInfo.location,
                industryType = indType,
                slotId       = slot.id,
                level        = level,
            }

            local result = Validation.canBuild(state, color, buildParams)
            if result.valid then
                validSlots[#validSlots + 1] = slot.id
                seen[slot.id] = true

                local snapPos = SnapMap.getPositionForSlot(slot.id)
                printToAll("[HIGHLIGHT] " .. slot.id .. " at ("
                    .. string.format("%.2f", snapPos and snapPos.x or 0) .. ", "
                    .. string.format("%.2f", snapPos and snapPos.z or 0) .. ")")
                if snapPos then
                    Highlights._spawnMarker(snapPos, "Green")
                end
                break  -- slot already marked, no need to try other industry types
            end
        end
    end)

    -- Brief feedback to player
    if #validSlots == 0 then
        printToColor("No valid build spots for this card.", color, {1, 1, 0})
    else
        printToColor("Found " .. #validSlots .. " valid build spot(s). (Green markers)", color, {0, 1, 0})
    end
end

--- Show valid link spots (network action)
-- Checks each link via Validation.canNetwork and highlights valid ones
-- @param state Game state object
-- @param color Player color string
function Highlights.showValidLinkSpots(state, color)
    Highlights.clearAll()

    local validLinks = {}

    -- Iterate through all links and check if network is valid
    for linkId, link in pairs(state.board.links) do
        -- Skip already-owned links
        if not link.owner then
            local linkParams = {
                linkId = linkId,
                double = false,  -- show single rail for now
            }

            local result = Validation.canNetwork(state, color, linkParams)
            if result.valid then
                validLinks[#validLinks + 1] = linkId

                -- Get snap point position for this link from SnapMap
                local snapPos = SnapMap.getPositionForLink(linkId)
                if snapPos then
                    Highlights._spawnMarker(snapPos, "Blue")
                end
            end
        end
    end

    -- Brief feedback to player
    if #validLinks == 0 then
        printToColor("No valid link spots available.", color, {1, 1, 0})
    else
        printToColor("Found " .. #validLinks .. " valid link spot(s). (Blue markers)", color, {0, 0, 1})
    end
end

--- Show all sellable buildings for current player
-- Finds all buildings that can be sold and highlights them
-- @param state Game state object
-- @param color Player color string
function Highlights.showSellableBuildings(state, color)
    Highlights.clearAll()

    local sellableCount = 0

    -- Iterate through all slots belonging to this player
    GameState.forEachSlot(state, function(slotId, slot)
        if slot.occupant == color and slot.tile then
            local sellParams = {
                slotId = slotId,
            }

            local result = Validation.canSell(state, color, sellParams)
            if result.valid then
                sellableCount = sellableCount + 1

                -- Try to get the actual TTS object for this building
                -- For now, we'll spawn a marker at the snap position
                local snapPos = SnapMap.getPositionForSlot(slotId)
                if snapPos then
                    Highlights._spawnMarker(snapPos, "Yellow")
                end
            end
        end
    end)

    -- Brief feedback to player
    if sellableCount == 0 then
        printToColor("No buildings available to sell.", color, {1, 1, 0})
    else
        printToColor("Found " .. sellableCount .. " sellable building(s). (Yellow markers)", color, {1, 1, 0})
    end
end

--- Show valid second link positions for double rail.
-- After the first rail link is placed, highlights links the player could build
-- as a second link in a double rail action.
-- @param state Game state object
-- @param color Player color string
-- @param firstLinkId string  The already-placed first link's ID
function Highlights.showValidSecondLinks(state, color, firstLinkId)
    Highlights.clearAll()

    local validLinks = {}

    -- The first link is not yet owned in state (it's pending), so we need to
    -- temporarily check as if it were owned to see network adjacency for 2nd link.
    -- However, for validation we just check each unowned link for availability.
    -- The second link must be: unowned, available in rail era, and touching the
    -- player's network (which includes the first link's cities since it's pending).

    -- Temporarily set the first link as owned for network adjacency checks
    local firstLink = state.board.links[firstLinkId]
    local originalOwner = firstLink and firstLink.owner
    if firstLink then
        firstLink.owner = color
    end

    for linkId, link in pairs(state.board.links) do
        -- Skip already-owned links and the first link itself
        if not link.owner and linkId ~= firstLinkId then
            local linkParams = {
                linkId = linkId,
                double = false,  -- validate as a single (availability + network check)
            }

            local result = Validation.canNetwork(state, color, linkParams)
            if result.valid then
                validLinks[#validLinks + 1] = linkId

                local snapPos = SnapMap.getPositionForLink(linkId)
                if snapPos then
                    Highlights._spawnMarker(snapPos, {0.2, 0.8, 1})  -- cyan/light blue
                end
            end
        end
    end

    -- Restore the first link's original owner
    if firstLink then
        firstLink.owner = originalOwner
    end

    -- Brief feedback
    if #validLinks == 0 then
        printToColor("No valid second link positions — click 'Single Link' to build one rail.", color, {1, 1, 0})
    else
        printToColor("Found " .. #validLinks .. " valid second link spot(s). (Cyan markers)", color, {0.2, 0.8, 1})
    end
end

--- Clear all active highlights and temporary markers
-- Removes all spawned markers and highlights from objects
function Highlights.clearAll()
    Highlights.clearResourceCandidates()

    -- Destroy all temporary markers
    for _, marker in ipairs(Highlights.activeHighlights.markers) do
        if marker and not marker.isDestroyed() then
            marker.destruct()
        end
    end
    Highlights.activeHighlights.markers = {}

    -- Remove highlights from all objects
    for _, obj in ipairs(Highlights.activeHighlights.objects) do
        if obj and not obj.isDestroyed() then
            obj.highlightOff()
        end
    end
    Highlights.activeHighlights.objects = {}
end

-- Separate tracking for resource candidate highlights
Highlights._resourceCandidateState = {
    markers = {},
}

--- Show resource source candidates with highlights and click handlers.
--- @param candidates table  array of { slotId=string, cityName=string, cubesAvailable=number }
--- @param resourceType string  "coal" or "iron"
--- @param onClickCallback function(slotId)  called when player clicks a candidate
function Highlights.showResourceCandidates(candidates, resourceType, onClickCallback)
    Highlights.clearResourceCandidates()

    local color = (resourceType == Constants.Resource.COAL) and {1, 0.5, 0} or {0.6, 0.6, 0.6}  -- orange / grey

    for _, cand in ipairs(candidates) do
        local snapPos = SnapMap.getPositionForSlot(cand.slotId)
        if snapPos then
            local marker = Highlights._spawnMarker(snapPos + Vector(0, 0.5, 0), color)
            if marker then
                marker.setGMNotes(JSON.encode({
                    type = "resource_candidate",
                    slotId = cand.slotId,
                }))
                marker.interactable = true
                marker.createButton({
                    click_function = "onResourceMarkerClicked",
                    function_owner = Global,
                    label          = "",
                    position       = {0, 0.2, 0},
                    width          = 1200,
                    height         = 1200,
                    color          = {0, 0, 0, 0},
                })
                table.insert(Highlights._resourceCandidateState.markers, marker)
            end
        end
    end

    Highlights._resourceClickCallback = onClickCallback

    local resName = (resourceType == Constants.Resource.COAL) and "Coal" or "Iron"
    local msg = "Choose " .. resName .. " source: click a highlighted building"
    if state and state._pendingResource then
        printToColor(msg, state._pendingResource.playerColor, color)
    end
end

--- Clear only resource candidate highlights.
function Highlights.clearResourceCandidates()
    for _, marker in ipairs(Highlights._resourceCandidateState.markers) do
        if marker and not marker.isDestroyed() then
            marker.destruct()
        end
    end
    Highlights._resourceCandidateState.markers = {}
    Highlights._resourceClickCallback = nil
end

return Highlights
