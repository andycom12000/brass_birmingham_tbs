local SnapMap = {}

SnapMap.byTag = {}      -- tag string → { position, rotation, snapIndex }
SnapMap.bySlotId = {}   -- "Birmingham_1" → snap data
SnapMap.byLinkId = {}   -- "Birmingham-Coventry" → snap data
SnapMap.byCityCenter = {} -- "Birmingham" → Vector (center of all slots)

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

--- Build slot mappings from hardcoded positions.
-- Positions measured from the reference mod's save-level snap points.
-- This avoids using TTS Tags (which restrict snap behavior).
function SnapMap.buildFromGlobal()
    SnapMap.byTag = {}
    SnapMap.bySlotId = {}
    SnapMap.byLinkId = {}

    -- Snap point world positions extracted from reference mod snap points.
    -- Each position matches the exact SnapPoint[idx].Position from the JSON.
    local SLOT_POSITIONS = {
        -- Belper (3 slots) — snaps 186, 187, 188
        { id = "Belper_1", pos = Vector(7.299325, 0.96, 13.939304) },
        { id = "Belper_2", pos = Vector(8.955435, 0.96, 13.939304) },
        { id = "Belper_3", pos = Vector(10.584352, 0.96, 13.939323) },
        -- Birmingham (4 slots) — snaps 216, 218, 217, 219
        { id = "Birmingham_1", pos = Vector(3.743216, 0.96, -6.823899) },
        { id = "Birmingham_2", pos = Vector(3.764189, 0.96, -5.243904) },
        { id = "Birmingham_3", pos = Vector(5.386132, 0.96, -6.816908) },
        { id = "Birmingham_4", pos = Vector(5.414096, 0.96, -5.222926) },
        -- Burton-on-Trent (2 slots) — snaps 198, 199
        { id = "Burton-on-Trent_1", pos = Vector(5.674157, 0.96, 4.248626) },
        { id = "Burton-on-Trent_2", pos = Vector(7.303093, 0.96, 4.248626) },
        -- Cannock (2 slots) — snaps 201, 202
        { id = "Cannock_1", pos = Vector(-1.691984, 0.96, 1.757875) },
        { id = "Cannock_2", pos = Vector(-0.032445, 0.96, 1.780506) },
        -- Coalbrookdale (3 slots) — snaps 206, 207, 205
        { id = "Coalbrookdale_1", pos = Vector(-10.200422, 0.96, -2.828633) },
        { id = "Coalbrookdale_2", pos = Vector(-9.368486, 0.96, -1.262620) },
        { id = "Coalbrookdale_3", pos = Vector(-8.529552, 0.96, -2.828633) },
        -- Coventry (3 slots) — snaps 221, 220, 222
        { id = "Coventry_1", pos = Vector(10.171118, 0.96, -7.885310) },
        { id = "Coventry_2", pos = Vector(10.990244, 0.96, -6.282060) },
        { id = "Coventry_3", pos = Vector(11.802370, 0.96, -7.864309) },
        -- Derby (3 slots) — snaps 192, 191, 193
        { id = "Derby_1", pos = Vector(8.428551, 0.96, 8.222458) },
        { id = "Derby_2", pos = Vector(9.233561, 0.96, 9.794345) },
        { id = "Derby_3", pos = Vector(10.043711, 0.96, 8.202714) },
        -- Dudley (2 slots) — snaps 214, 215
        { id = "Dudley_1", pos = Vector(-3.721978, 0.96, -5.508296) },
        { id = "Dudley_2", pos = Vector(-2.095748, 0.96, -5.495581) },
        -- Kidderminster (2 slots) — snaps 225, 226
        { id = "Kidderminster_1", pos = Vector(-6.168565, 0.96, -9.016786) },
        { id = "Kidderminster_2", pos = Vector(-4.555384, 0.96, -9.000574) },
        -- Leek (2 slots) — snaps 184, 185
        { id = "Leek_1", pos = Vector(1.097839, 0.96, 14.438809) },
        { id = "Leek_2", pos = Vector(2.731706, 0.96, 14.424453) },
        -- Nuneaton (2 slots) — snaps 212, 213
        { id = "Nuneaton_1", pos = Vector(9.378379, 0.96, -3.402273) },
        { id = "Nuneaton_2", pos = Vector(11.021295, 0.96, -3.395279) },
        -- Redditch (2 slots) — snaps 223, 224
        { id = "Redditch_1", pos = Vector(2.113574, 0.96, -10.817973) },
        { id = "Redditch_2", pos = Vector(3.772827, 0.96, -10.817973) },
        -- Stafford (2 slots) — snaps 196, 197
        { id = "Stafford_1", pos = Vector(-4.258573, 0.96, 5.207421) },
        { id = "Stafford_2", pos = Vector(-2.637125, 0.96, 5.222799) },
        -- Stoke-on-Trent (3 slots) — snaps 181, 182, 183
        { id = "Stoke-on-Trent_1", pos = Vector(-3.884848, 0.96, 11.988375) },
        { id = "Stoke-on-Trent_2", pos = Vector(-3.022102, 0.96, 13.528519) },
        { id = "Stoke-on-Trent_3", pos = Vector(-2.224559, 0.96, 11.988104) },
        -- Stone (2 slots) — snaps 194, 195
        { id = "Stone_1", pos = Vector(-7.520805, 0.96, 8.398808) },
        { id = "Stone_2", pos = Vector(-5.888338, 0.96, 8.389524) },
        -- Tamworth (2 slots) — snaps 210, 211
        { id = "Tamworth_1", pos = Vector(6.207975, 0.96, -0.015510) },
        { id = "Tamworth_2", pos = Vector(7.827428, 0.96, 0.012454) },
        -- Uttoxeter (2 slots) — snaps 189, 190
        { id = "Uttoxeter_1", pos = Vector(1.519803, 0.96, 8.990265) },
        { id = "Uttoxeter_2", pos = Vector(3.180723, 0.96, 8.972310) },
        -- Walsall (2 slots) — snaps 208, 209
        { id = "Walsall_1", pos = Vector(0.313989, 0.96, -2.129650) },
        { id = "Walsall_2", pos = Vector(1.954838, 0.96, -2.145350) },
        -- Wolverhampton (2 slots) — snaps 203, 204
        { id = "Wolverhampton_1", pos = Vector(-5.349645, 0.96, -1.339521) },
        { id = "Wolverhampton_2", pos = Vector(-3.743100, 0.96, -1.346513) },
        -- Worcester (2 slots) — snaps 227, 228
        { id = "Worcester_1", pos = Vector(-5.709967, 0.96, -13.405255) },
        { id = "Worcester_2", pos = Vector(-4.074101, 0.96, -13.389140) },
        -- Farm Brewery — snaps 229, 200
        { id = "FarmBrewery1_1", pos = Vector(-8.422162, 0.96, -11.546000) },
        { id = "FarmBrewery2_1", pos = Vector(-7.060468, 0.96, 2.172760) },
    }

    local count = 0
    local cityAccum = {}  -- cityName -> { sumX, sumZ, n }
    for _, entry in ipairs(SLOT_POSITIONS) do
        local data = {
            position = entry.pos,
            rotation = { x = 0, y = 180, z = 0 },
            tag = "city_" .. entry.id,
        }
        SnapMap.bySlotId[entry.id] = data
        SnapMap.byTag["city_" .. entry.id] = data
        count = count + 1

        -- Accumulate city center
        local cityName = entry.id:match("^(.+)_%d+$")
        if cityName then
            if not cityAccum[cityName] then
                cityAccum[cityName] = { sumX = 0, sumZ = 0, n = 0 }
            end
            local a = cityAccum[cityName]
            a.sumX = a.sumX + entry.pos.x
            a.sumZ = a.sumZ + entry.pos.z
            a.n = a.n + 1
        end
    end

    -- Compute city centers
    SnapMap.byCityCenter = {}
    for cityName, a in pairs(cityAccum) do
        SnapMap.byCityCenter[cityName] = Vector(a.sumX / a.n, 0.96, a.sumZ / a.n)
    end
    -- Remove auto-parsed farm brewery entries (slot IDs don't match BoardData keys)
    SnapMap.byCityCenter["FarmBrewery1"] = nil
    SnapMap.byCityCenter["FarmBrewery2"] = nil

    -- Add merchant city centers (no building slots, but needed for link matching)
    -- Positions from tagged merchant snap points in the save file
    SnapMap.byCityCenter["Shrewsbury"]  = Vector(-14.439, 0.96, -3.011)
    SnapMap.byCityCenter["Gloucester"]  = Vector(3.702, 0.96, -14.548)
    SnapMap.byCityCenter["Oxford"]      = Vector(11.523, 0.96, -11.985)
    SnapMap.byCityCenter["Warrington"]  = Vector(-7.762, 0.96, 12.550)
    SnapMap.byCityCenter["Nottingham"]  = Vector(14.237, 0.96, 10.424)

    -- Farm brewery city centers (estimated — may need TTS adjustment)
    -- Slot IDs use "FarmBrewery1_1" so the auto-parser maps to "FarmBrewery1";
    -- we override with the correct BoardData key here.
    SnapMap.byCityCenter["Farm Brewery 1"] = Vector(-5.660, 0.96, -11.170)
    SnapMap.byCityCenter["Farm Brewery 2"] = Vector(0.130, 0.96, -0.180)

    -- Link snap point positions extracted from reference mod snap points.
    local LINK_POSITIONS = {
        { id = "Kidderminster-Worcester",     pos = Vector(-5.660388, 0.96, -11.507246) },
        { id = "Birmingham-Worcester",        pos = Vector(-0.661587, 0.96, -10.045407) },
        { id = "Dudley-Kidderminster",        pos = Vector(-5.175323, 0.96, -7.144116) },
        { id = "Coalbrookdale-Kidderminster", pos = Vector(-8.499175, 0.96, -6.753577) },
        { id = "Coalbrookdale-Shrewsbury",    pos = Vector(-11.753687, 0.96, -1.316921) },
        { id = "Coalbrookdale-Wolverhampton", pos = Vector(-7.388280, 0.96, -1.275767) },
        { id = "Gloucester-Worcester",        pos = Vector(-2.076601, 0.96, -14.460986) },
        { id = "Redditch-Worcester",          pos = Vector(0.294656, 0.96, -12.101261) },
        { id = "Oxford-Redditch",             pos = Vector(5.737827, 0.96, -11.259514) },
        { id = "Dudley-Wolverhampton",        pos = Vector(-4.261658, 0.96, -3.715955) },
        { id = "Walsall-Wolverhampton",       pos = Vector(-1.709300, 0.96, -1.495031) },
        { id = "Birmingham-Dudley",           pos = Vector(0.718321, 0.96, -5.984568) },
        { id = "Birmingham-Walsall",          pos = Vector(1.975539, 0.96, -4.400317) },
        { id = "Birmingham-Redditch",         pos = Vector(3.980023, 0.96, -8.917946) },
        { id = "Coventry-Oxford",             pos = Vector(7.654861, 0.96, -9.164195) },
        { id = "Birmingham-Coventry",         pos = Vector(7.748926, 0.96, -7.477209) },
        -- NOTE: snap 157 at (7.479, -4.938) skipped — no matching BoardData link
        { id = "Birmingham-Tamworth",         pos = Vector(6.757850, 0.96, -2.970645) },
        { id = "Coventry-Nuneaton",           pos = Vector(12.644048, 0.96, -5.284865) },
        { id = "Nuneaton-Tamworth",           pos = Vector(9.932418, 0.96, -1.111601) },
        { id = "Birmingham-Cannock",          pos = Vector(4.274405, 0.96, -1.763060) },
        { id = "Burton-on-Trent-Tamworth",    pos = Vector(6.973626, 0.96, 1.952281) },
        { id = "Burton-on-Trent-Cannock",     pos = Vector(3.035019, 0.96, 0.612657) },
        { id = "Cannock-Walsall",             pos = Vector(1.324278, 0.96, -0.098752) },
        { id = "Cannock-Wolverhampton",       pos = Vector(-3.743125, 0.96, 0.620533) },
        { id = "Stone-Cannock",               pos = Vector(-4.264416, 0.96, 2.315660) },
        { id = "Cannock-Stafford",            pos = Vector(-0.808261, 0.96, 3.684514) },
        { id = "Burton-on-Trent-Uttoxeter",   pos = Vector(2.476622, 0.96, 3.544925) },
        { id = "Stafford-Stone",              pos = Vector(-6.274909, 0.96, 5.707407) },
        { id = "Stafford-Uttoxeter",          pos = Vector(0.442284, 0.96, 6.879314) },
        { id = "Stone-Uttoxeter",             pos = Vector(-1.969494, 0.96, 8.920661) },
        { id = "Derby-Uttoxeter",             pos = Vector(5.863106, 0.96, 8.482992) },
        { id = "Burton-on-Trent-Derby",       pos = Vector(8.925817, 0.96, 5.835839) },
        { id = "Derby-Nottingham",            pos = Vector(11.245152, 0.96, 9.988194) },
        { id = "Belper-Derby",                pos = Vector(9.337038, 0.96, 11.751387) },
        { id = "Belper-Leek",                 pos = Vector(4.924756, 0.96, 14.416066) },
        { id = "Leek-Stoke-on-Trent",         pos = Vector(-1.006876, 0.96, 14.269884) },
        { id = "Stoke-on-Trent-Stone",        pos = Vector(-4.821410, 0.96, 10.057897) },
        { id = "Shrewsbury-Warrington",       pos = Vector(-5.131299, 0.96, 13.742054) },
    }

    for _, entry in ipairs(LINK_POSITIONS) do
        local data = {
            position = entry.pos,
            tag = "link_" .. entry.id,
        }
        SnapMap.byLinkId[entry.id] = data
        SnapMap.byTag["link_" .. entry.id] = data
    end

    if printToAll then
        local cityCount = 0
        for _ in pairs(SnapMap.byCityCenter) do cityCount = cityCount + 1 end
        local linkCount = 0
        for _ in pairs(SnapMap.byLinkId) do linkCount = linkCount + 1 end
        printToAll("[SnapMap] loaded " .. count .. " slots in " .. cityCount .. " cities, " .. linkCount .. " links")
    end
end

--- Find the nearest city to a world position (2D, ignoring Y).
-- @param worldPos Vector or table
-- @param threshold number max 2D distance
-- @return string cityName or nil
function SnapMap.findNearestCity(worldPos, threshold)
    local best = nil
    local bestDist = threshold or 3.0

    for cityName, center in pairs(SnapMap.byCityCenter) do
        local dist = SnapMap._distance(worldPos, center)
        if dist < bestDist then
            bestDist = dist
            best = cityName
        end
    end
    return best
end

--- Find the N nearest cities to a world position (2D, ignoring Y).
-- @param worldPos Vector or table
-- @param count number how many cities to return
-- @return table array of city names sorted by distance
function SnapMap.findNearestCities(worldPos, count)
    local all = {}
    for cityName, center in pairs(SnapMap.byCityCenter) do
        local dist = SnapMap._distance(worldPos, center)
        all[#all + 1] = { name = cityName, dist = dist }
    end
    table.sort(all, function(a, b) return a.dist < b.dist end)
    local result = {}
    for i = 1, math.min(count or 2, #all) do
        result[i] = all[i].name
    end
    return result
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

--- 2D distance between two positions (X/Z only, ignoring Y height)
-- onObjectDrop fires while tile is still in the air, so Y distance is unreliable
function SnapMap._distance(a, b)
    local dx = (a.x or a[1]) - (b.x or b[1])
    local dz = (a.z or a[3]) - (b.z or b[3])
    return math.sqrt(dx*dx + dz*dz)
end

return SnapMap
