local SnapMap = {}

SnapMap.byTag = {}      -- tag string → { position, rotation, snapIndex }
SnapMap.bySlotId = {}   -- "Birmingham_cotton_1" → snap data
SnapMap.byLinkId = {}   -- "Birmingham-Coventry" → snap data

--- Scan a board object's snap points and build all mappings
-- Snap point tags follow format:
--   "city_Birmingham_1" for building slots
--   "link_Birmingham-Coventry" for route links
function SnapMap.buildFromObject(boardObject)
    SnapMap.byTag = {}
    SnapMap.bySlotId = {}
    SnapMap.byLinkId = {}

    local snaps = boardObject.getSnapPoints()
    for i, snap in ipairs(snaps) do
        local tag = snap.tags and snap.tags[1] or nil
        if tag then
            local data = {
                position = boardObject.positionToWorld(snap.position),
                rotation = snap.rotation,
                snapIndex = i,
                tag = tag,
            }
            SnapMap.byTag[tag] = data

            if tag:sub(1, 5) == "city_" then
                local slotId = tag:sub(6)
                SnapMap.bySlotId[slotId] = data
            elseif tag:sub(1, 5) == "link_" then
                local linkId = tag:sub(6)
                SnapMap.byLinkId[linkId] = data
            end
        end
    end
end

--- Scan save-level (Global) snap points and build mappings.
-- Used when snap points are at the save root level, not attached to a board object.
-- Positions are already in world coordinates.
function SnapMap.buildFromGlobal()
    SnapMap.byTag = {}
    SnapMap.bySlotId = {}
    SnapMap.byLinkId = {}

    local snaps = Global.getSnapPoints()
    if not snaps then return end

    for i, snap in ipairs(snaps) do
        local tags = snap.tags or {}
        for _, tag in ipairs(tags) do
            local data = {
                position = snap.position,
                rotation = snap.rotation,
                snapIndex = i,
                tag = tag,
            }
            SnapMap.byTag[tag] = data

            if tag:sub(1, 5) == "city_" then
                local slotId = tag:sub(6)
                SnapMap.bySlotId[slotId] = data
            elseif tag:sub(1, 5) == "link_" then
                local linkId = tag:sub(6)
                SnapMap.byLinkId[linkId] = data
            end
        end
    end
end

--- Get world position for a building slot
function SnapMap.getPositionForSlot(slotId)
    local data = SnapMap.bySlotId[slotId]
    return data and data.position or nil
end

--- Get world position for a route link
function SnapMap.getPositionForLink(linkId)
    local data = SnapMap.byLinkId[linkId]
    return data and data.position or nil
end

--- Find the nearest game position to a world coordinate
-- Returns { type = "slot"|"link", id = "..." } or nil
function SnapMap.findNearestPosition(worldPos, threshold)
    local nearest = nil
    local nearestDist = threshold or 2.0

    for slotId, data in pairs(SnapMap.bySlotId) do
        local dist = SnapMap._distance(worldPos, data.position)
        if dist < nearestDist then
            nearestDist = dist
            nearest = { type = "slot", id = slotId }
        end
    end

    for linkId, data in pairs(SnapMap.byLinkId) do
        local dist = SnapMap._distance(worldPos, data.position)
        if dist < nearestDist then
            nearestDist = dist
            nearest = { type = "link", id = linkId }
        end
    end

    return nearest
end

--- Euclidean distance between two positions (tables with x,y,z or [1],[2],[3])
function SnapMap._distance(a, b)
    local dx = (a.x or a[1]) - (b.x or b[1])
    local dy = (a.y or a[2]) - (b.y or b[2])
    local dz = (a.z or a[3]) - (b.z or b[3])
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

return SnapMap
