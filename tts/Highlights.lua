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

--- Spawn a temporary marker token at a world position
-- @param position Vector or table {x, y, z}
-- @param color TTS color string or RGB table (default green)
-- @return Spawned object or nil
function Highlights._spawnMarker(position, color)
    local colorTable = color or {0, 1, 0}  -- default green
    if type(color) == "string" then
        colorTable = Highlights._colorStringToRGB(color)
    end

    -- Spawn a small custom token as a visual marker
    local marker = spawnObject({
        type = "Custom_Token",
        position = position,
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},
    })

    if marker then
        marker.setColorTint(colorTable)
        marker.setLock(true)  -- prevent accidental movement
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

    -- Iterate through all slots and check if build is valid
    GameState.forEachSlot(state, function(slotId, slot)
        local buildParams = {
            cardType = cardInfo.cardType,
            location = cardInfo.location,
            industryType = cardInfo.industryType,
            level = cardInfo.level,
            slotId = slotId,
        }

        local result = Validation.canBuild(state, color, buildParams)
        if result.valid then
            validSlots[#validSlots + 1] = slotId

            -- Get snap point position for this slot from SnapMap
            local snapPos = SnapMap.getPositionForSlot(slotId)
            if snapPos then
                Highlights._spawnMarker(snapPos, "Green")
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

    local color = (resourceType == "coal") and {1, 0.5, 0} or {0.6, 0.6, 0.6}  -- orange / grey

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

    local resName = (resourceType == "coal") and "Coal" or "Iron"
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
