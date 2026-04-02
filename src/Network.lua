local Constants = require("src/Constants")
local BoardData  = require("src/BoardData")

local Network = {}

-- ============================================================
-- Internal helpers
-- ============================================================

-- Set of merchant city names for fast O(1) lookup (derived from BoardData)
local MERCHANT_CITIES = {}
for _, m in ipairs(BoardData.merchants) do
    MERCHANT_CITIES[m.name] = true
end

--- BFS over all placed links starting from `startCity`.
--- Calls `visitor(cityName, distance)` for every reachable city
--- (including the start, at distance 0).
--- `visitor` may return true to stop traversal early.
--- @param state table
--- @param startCity string
--- @param visitor function(cityName, distance) -> bool|nil
local function bfsAllLinks(state, startCity, visitor)
    if not state.board.cities[startCity] then return end

    local visited = { [startCity] = true }
    -- queue entries: { city = string, dist = number }
    local queue   = { { city = startCity, dist = 0 } }
    local head    = 1

    while head <= #queue do
        local entry = queue[head]
        head = head + 1

        if visitor(entry.city, entry.dist) then return end

        local adjLinks = BoardData.adjacency[entry.city] or {}
        for _, linkId in ipairs(adjLinks) do
            local link = state.board.links[linkId]
            -- Only traverse placed (owned) links
            if link and link.owner then
                local linkData = BoardData.links[linkId]
                for _, neighbor in ipairs(linkData.cities) do
                    if not visited[neighbor] then
                        -- Only visit cities that exist in the current game state
                        if state.board.cities[neighbor] then
                            visited[neighbor] = true
                            queue[#queue + 1] = { city = neighbor, dist = entry.dist + 1 }
                        end
                    end
                end
            end
        end
    end
end

--- BFS over only the given player's placed links, starting from `startCity`.
--- Calls `visitor(cityName)` for every reachable city (including start).
--- Also includes any city that has the player's building, even without links.
--- @param state table
--- @param color string
--- @param startCity string
--- @param visitor function(cityName)
local function bfsPlayerLinks(state, color, startCity, visitor)
    if not state.board.cities[startCity] then return end

    local visited = { [startCity] = true }
    local queue   = { startCity }
    local head    = 1

    while head <= #queue do
        local city = queue[head]
        head = head + 1

        visitor(city)

        local adjLinks = BoardData.adjacency[city] or {}
        for _, linkId in ipairs(adjLinks) do
            local link = state.board.links[linkId]
            if link and link.owner == color then
                local linkData = BoardData.links[linkId]
                for _, neighbor in ipairs(linkData.cities) do
                    if not visited[neighbor] then
                        if state.board.cities[neighbor] then
                            visited[neighbor] = true
                            queue[#queue + 1] = neighbor
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

--- Get the set of cities reachable by a player's network.
--- A city is "in network" if it has the player's building OR is adjacent to
--- a link owned by the player (and reachable via their link network).
---
--- Algorithm:
---   1. Seed with every city that already has the player's building.
---   2. BFS from each seed city, following only the player's links,
---      collecting all reachable cities.
---
--- @param state table
--- @param color string
--- @return table  { [cityName] = true, ... }
function Network.getPlayerNetwork(state, color)
    local network = {}

    -- Seed set: cities where the player has a building
    local seeds = {}
    for cityName, city in pairs(state.board.cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.occupant == color then
                    seeds[cityName] = true
                    break
                end
            end
        end
    end

    -- Also seed cities at either end of the player's links
    for linkId, link in pairs(state.board.links) do
        if link.owner == color then
            local linkData = BoardData.links[linkId]
            for _, cityName in ipairs(linkData.cities) do
                if state.board.cities[cityName] then
                    seeds[cityName] = true
                end
            end
        end
    end

    -- BFS from every seed city, following player's links
    for seedCity, _ in pairs(seeds) do
        if not network[seedCity] then
            bfsPlayerLinks(state, color, seedCity, function(cityName)
                network[cityName] = true
            end)
        end
    end

    return network
end

--- Check if a specific city is in a player's network.
--- @param state table
--- @param color string
--- @param cityName string
--- @return boolean
function Network.isInNetwork(state, color, cityName)
    return Network.getPlayerNetwork(state, color)[cityName] == true
end

--- Check if a city is connected to any active merchant via ANY player's links.
--- A merchant city is active when a merchant tile has been placed there.
--- @param state table
--- @param color string  (unused; kept for API symmetry — path uses any links)
--- @param cityName string
--- @return boolean
function Network.isConnectedToMerchant(state, color, cityName)
    local found = false
    bfsAllLinks(state, cityName, function(reachedCity, _distance)
        if MERCHANT_CITIES[reachedCity] then
            -- Check the merchant city is actually in play (has an entry in merchants)
            if state.board.merchants[reachedCity] then
                found = true
                return true  -- stop BFS
            end
        end
    end)
    return found
end

--- Find a connected merchant city reachable from cityName via ANY player's links.
--- Returns the merchant name, or nil if none found.
---
--- @param state table
--- @param cityName string
--- @return string|nil  merchant city name
function Network.findConnectedMerchant(state, cityName)
    local merchantName = nil
    bfsAllLinks(state, cityName, function(reachedCity, _distance)
        if MERCHANT_CITIES[reachedCity] then
            if state.board.merchants[reachedCity] then
                merchantName = reachedCity
                return true  -- stop BFS
            end
        end
    end)
    return merchantName
end

--- Find the nearest coal source connected to a city, following ANY player's links.
--- "Nearest" means fewest links traversed.
--- If multiple sources are at the same distance, all are returned.
---
--- @param state table
--- @param cityName string
--- @return table|nil  list of { cityName, slotId, slot } entries, or nil if none found
function Network.findNearestCoal(state, cityName)
    local results   = nil
    local bestDist  = math.huge

    bfsAllLinks(state, cityName, function(reachedCity, distance)
        -- Stop expanding once we've gone past the best distance found
        if distance > bestDist then
            return true  -- stop BFS early
        end

        local city = state.board.cities[reachedCity]
        if city and city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.tile
                    and slot.tile.type == Constants.Industry.COAL
                    and not slot.tile.flipped
                    and #slot.tile.resources > 0
                then
                    if distance < bestDist then
                        bestDist = distance
                        results  = {}
                    end
                    results[#results + 1] = {
                        cityName = reachedCity,
                        slotId   = slot.id,
                        slot     = slot,
                    }
                end
            end
        end
    end)

    return results
end

--- Count ALL coal cubes reachable from cityName via any placed links.
--- Unlike findNearestCoal (which returns only the nearest distance),
--- this counts coal at every reachable city.
---
--- @param state table
--- @param cityName string
--- @return number  total coal cubes reachable
function Network.countConnectedCoal(state, cityName)
    local total = 0
    bfsAllLinks(state, cityName, function(reachedCity, _)
        local city = state.board.cities[reachedCity]
        if city and city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.tile
                    and slot.tile.type == Constants.Industry.COAL
                    and not slot.tile.flipped
                    and #slot.tile.resources > 0
                then
                    total = total + #slot.tile.resources
                end
            end
        end
    end)
    return total
end

--- Find all iron sources on the board (no connection required).
--- Returns every unflipped iron works with at least one iron resource.
---
--- @param state table
--- @return table  list of { cityName, slotId, slot }
function Network.findIronSources(state)
    local results = {}
    for cityName, city in pairs(state.board.cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.tile
                    and slot.tile.type == Constants.Industry.IRON
                    and not slot.tile.flipped
                    and #slot.tile.resources > 0
                then
                    results[#results + 1] = {
                        cityName = cityName,
                        slotId   = slot.id,
                        slot     = slot,
                    }
                end
            end
        end
    end
    return results
end

--- Find all beer sources available for an action performed by `color` at `cityName`.
---
--- Rules:
---   1. Own breweries: available regardless of connection.
---   2. Other players' breweries: must be reachable from cityName via any placed link.
---   3. Merchant beer: if merchantName is provided, that merchant's beer (if any).
---
--- @param state table
--- @param color string
--- @param cityName string
--- @param merchantName string|nil  name of the merchant being sold to (optional)
--- @return table  list of { cityName, slotId, slot, owner, isMerchantBeer }
function Network.findBeerSources(state, color, cityName, merchantName)
    local results = {}

    -- Helper: add a brewery slot to results if it has beer
    local function addBrewery(bCityName, slot, owner, isMerchantBeer)
        if slot.tile
            and slot.tile.type == Constants.Industry.BREWERY
            and slot.tile.flipped   -- breweries flip on build; flipped = active
            and #slot.tile.resources > 0
        then
            results[#results + 1] = {
                cityName      = bCityName,
                slotId        = slot.id,
                slot          = slot,
                owner         = owner,
                isMerchantBeer = isMerchantBeer or false,
            }
        end
    end

    -- 1. Own breweries (no connection needed)
    for bCityName, city in pairs(state.board.cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.occupant == color then
                    addBrewery(bCityName, slot, color, false)
                end
            end
        end
    end

    -- 2. Other players' breweries reachable via any placed link from cityName
    local reachable = {}
    bfsAllLinks(state, cityName, function(reachedCity, _)
        reachable[reachedCity] = true
    end)

    for bCityName, city in pairs(state.board.cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.occupant and slot.occupant ~= color and reachable[bCityName] then
                    addBrewery(bCityName, slot, slot.occupant, false)
                end
            end
        end
    end

    -- 3. Merchant beer (only when selling to a specific merchant)
    if merchantName then
        local merchant = state.board.merchants[merchantName]
        if merchant and merchant.beer and merchant.beer > 0 then
            -- Represent merchant beer as a synthetic entry (no real slot)
            results[#results + 1] = {
                cityName       = merchantName,
                slotId         = nil,
                slot           = nil,
                owner          = merchantName,
                isMerchantBeer = true,
            }
        end
    end

    return results
end

--- Check if there is a path from cityName to any merchant city
--- via any placed links (for coal market access).
---
--- @param state table
--- @param color string  (unused; path uses any player's links)
--- @param cityName string
--- @return boolean
function Network.hasMarketConnection(state, color, cityName)
    return Network.isConnectedToMerchant(state, color, cityName)
end

--- Parse a link ID of the form "CityA-CityB" and return both city names.
--- Falls back to splitting on the first "-" that separates known city names.
---
--- @param linkId string
--- @return string, string  cityA, cityB
function Network.getLinkCities(linkId)
    -- First try BoardData directly (authoritative source)
    local linkData = BoardData.links[linkId]
    if linkData and linkData.cities then
        return linkData.cities[1], linkData.cities[2]
    end

    -- Fallback: brute-force split at every "-" position
    -- to find a split where both parts are known city names
    local len = #linkId
    for i = 2, len - 1 do
        if linkId:sub(i, i) == "-" then
            local a = linkId:sub(1, i - 1)
            local b = linkId:sub(i + 1)
            if BoardData.cities[a] and BoardData.cities[b] then
                return a, b
            end
        end
    end

    -- Last resort: return raw split on first "-"
    local first, second = linkId:match("^([^%-]+)%-(.+)$")
    return first or linkId, second or ""
end

return Network
