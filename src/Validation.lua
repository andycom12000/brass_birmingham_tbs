local Constants    = require("src/Constants")
local BoardData    = require("src/BoardData")
local GameState    = require("src/GameState")
local Network      = require("src/Network")
local IncomeTrack  = require("src/IncomeTrack")
local helpers      = require("src/helpers")

local Validation = {}

-- ============================================================
-- Internal helpers
-- ============================================================

local function ok()
    return { valid = true, reason = "" }
end

local function fail(reason)
    return { valid = false, reason = reason }
end

--- Count total coal cubes on all unflipped coal-mine buildings on the board.
local function totalCoalOnBoard(state)
    local total = 0
    GameState.forEachSlot(state, function(_, slot)
        if slot.tile
            and slot.tile.type == Constants.Industry.COAL
            and not slot.tile.flipped
        then
            total = total + #slot.tile.resources
        end
    end)
    return total
end

--- Count total iron cubes on all unflipped iron-works buildings on the board.
local function totalIronOnBoard(state)
    local total = 0
    GameState.forEachSlot(state, function(_, slot)
        if slot.tile
            and slot.tile.type == Constants.Industry.IRON
            and not slot.tile.flipped
        then
            total = total + #slot.tile.resources
        end
    end)
    return total
end


--- Count how many coal cubes are reachable from cityName (via any placed links,
--- including coal at the city itself) plus market supply.
--- Market coal is only available if the city is connected to a merchant city.
--- Returns boardCoal, marketCoal.
local function countCoalAvailable(state, cityName)
    local boardCoal = 0
    local reachedMerchant = false
    local visited   = {}

    local function bfs(city)
        if visited[city] then return end
        visited[city] = true
        -- Check if this city is an active merchant
        if state.board.merchants[city] then
            reachedMerchant = true
        end
        local cityData = state.board.cities[city]
        if cityData and cityData.slots then
            for _, slot in ipairs(cityData.slots) do
                if slot.tile
                    and slot.tile.type == Constants.Industry.COAL
                    and not slot.tile.flipped
                then
                    boardCoal = boardCoal + #slot.tile.resources
                end
            end
        end
        local adjLinks = BoardData.adjacency[city] or {}
        for _, linkId in ipairs(adjLinks) do
            local link = state.board.links[linkId]
            if link and link.owner then
                local linkData = BoardData.links[linkId]
                for _, neighbor in ipairs(linkData.cities) do
                    if state.board.cities[neighbor] then
                        bfs(neighbor)
                    end
                end
            end
        end
    end

    bfs(cityName)

    local marketCoal = reachedMerchant and state.coalMarket.supply or 0
    return boardCoal, marketCoal
end

--- Count total iron available anywhere on the board (no connection needed)
--- plus market supply.
local function countIronAvailable(state)
    local boardIron = 0
    local sources = Network.findIronSources(state)
    for _, src in ipairs(sources) do
        boardIron = boardIron + #src.slot.tile.resources
    end
    local marketIron = state.ironMarket.supply
    return boardIron, marketIron
end

-- ============================================================
-- 1. canBuild
-- ============================================================

--- Can player build at a specific location?
--- params: { cardType, location, industryType, level, slotId }
function Validation.canBuild(state, color, params)
    local cardType     = params.cardType
    local location     = params.location     -- city name from card
    local industryType = params.industryType
    local level        = params.level
    local slotId       = params.slotId

    local player = GameState.getPlayer(state, color)

    -- ---- 1. Resolve slot ----
    local slot = GameState.getSlot(state, slotId)
    if not slot then
        return fail("Slot '" .. tostring(slotId) .. "' does not exist")
    end

    local cityName = GameState.getCityForSlot(state, slotId)
    if not cityName then
        return fail("Cannot determine city for slot '" .. tostring(slotId) .. "'")
    end

    -- Confirm the city exists in this game state
    if not state.board.cities[cityName] then
        return fail("City '" .. cityName .. "' is not in play")
    end

    -- ---- 2. Rail-only check (canal era) ----
    local costData = BoardData.buildingCosts[industryType]
                     and BoardData.buildingCosts[industryType][level]
    if not costData then
        return fail("No data for " .. tostring(industryType) .. " level " .. tostring(level))
    end

    if costData.railOnly and state.era == Constants.Era.CANAL then
        return fail(industryType .. " level " .. level .. " cannot be built in the canal era")
    end

    -- ---- 3. Canal era: max 1 building per city ----
    if state.era == Constants.Era.CANAL then
        local count = GameState.countBuildingsInCity(state, cityName)
        -- The slot must be empty for this check; we will allow overbuilding below
        -- but not placing a second building in a different empty slot in the same city.
        if slot.occupant == nil and count >= 1 then
            return fail("Cannot build in " .. cityName .. ": already has a building (canal era)")
        end
    end

    -- ---- 4. Slot occupancy / overbuilding ----
    if slot.occupant then
        -- Slot is occupied — check overbuilding rules
        if slot.occupant == color then
            -- Own tile: can overbuild any unflipped tile with a higher level of ANY industry
            if slot.tile and slot.tile.flipped then
                return fail("Cannot overbuild your own flipped tile")
            end
            if slot.tile and level <= slot.tile.level then
                return fail("Overbuilding own tile requires a higher level tile")
            end
        else
            -- Opponent's tile: only coal or iron, resources must be 0 everywhere
            if slot.tile then
                local tileType = slot.tile.type
                if tileType ~= Constants.Industry.COAL and tileType ~= Constants.Industry.IRON then
                    return fail("Cannot overbuild opponent's " .. tostring(tileType) .. " tile")
                end
                -- Check that 0 of that resource type exist on all buildings AND market
                if tileType == Constants.Industry.COAL then
                    if totalCoalOnBoard(state) > 0 then
                        return fail("Cannot overbuild opponent's coal mine: coal still available on board")
                    end
                    if state.coalMarket.supply > 0 then
                        return fail("Cannot overbuild opponent's coal mine: coal still available in market")
                    end
                elseif tileType == Constants.Industry.IRON then
                    if totalIronOnBoard(state) > 0 then
                        return fail("Cannot overbuild opponent's iron works: iron still available on board")
                    end
                    if state.ironMarket.supply > 0 then
                        return fail("Cannot overbuild opponent's iron works: iron still available in market")
                    end
                end
            end
        end
    end

    -- ---- 5. Slot industry type matches what player wants to build ----
    if slot.types then
        local typeMatch = false
        for _, t in ipairs(slot.types) do
            if t == industryType then typeMatch = true; break end
        end
        if not typeMatch then
            return fail("Slot accepts {" .. table.concat(slot.types, ", ") .. "} but you want to build " .. tostring(industryType))
        end
    end

    -- ---- 6. Player has the tile available ----
    local stack = player.unbuiltTiles[industryType]
    if not stack or #stack == 0 then
        return fail("No " .. industryType .. " tiles remaining on your player board")
    end
    -- Must build the lowest-level tile first
    if stack[1].level ~= level then
        return fail("Must build lowest available " .. industryType
                    .. " level (" .. stack[1].level .. "), not level " .. level)
    end

    -- ---- 7. Network / card type check ----
    local hasPresence = GameState.hasPresenceOnBoard(state, color)

    if cardType == Constants.CardType.LOCATION or cardType == Constants.CardType.WILD_LOCATION then
        -- Location card: build at matching city regardless of network
        if location ~= cityName then
            return fail("Location card for '" .. tostring(location)
                        .. "' cannot be used to build in '" .. cityName .. "'")
        end
        -- No network check needed for location cards

    elseif cardType == Constants.CardType.INDUSTRY or cardType == Constants.CardType.WILD_INDUSTRY then
        -- Industry card: city must be in player's network
        -- Exception: if player has NO presence on board, can build anywhere
        if hasPresence then
            if not Network.isInNetwork(state, color, cityName) then
                return fail("'" .. cityName .. "' is not in your network (industry card requires network connection)")
            end
        end
        -- No location restriction — just industry type match (already done via slot.types)
    else
        return fail("Unknown card type: " .. tostring(cardType))
    end

    -- ---- 8. Money check ----
    if player.money < costData.money then
        return fail("Not enough money: need £" .. costData.money .. ", have £" .. player.money)
    end

    -- ---- 9. Coal resource check ----
    local coalNeeded = costData.coal or 0
    if coalNeeded > 0 then
        local boardCoal, marketCoal = countCoalAvailable(state, cityName)
        local totalCoal = boardCoal + marketCoal
        if totalCoal < coalNeeded then
            return fail("Not enough coal: need " .. coalNeeded .. ", only " .. totalCoal .. " available")
        end
    end

    -- ---- 10. Iron resource check ----
    local ironNeeded = costData.iron or 0
    if ironNeeded > 0 then
        local boardIron, marketIron = countIronAvailable(state)
        local totalIron = boardIron + marketIron
        if totalIron < ironNeeded then
            return fail("Not enough iron: need " .. ironNeeded .. ", only " .. totalIron .. " available")
        end
    end

    return ok()
end

-- ============================================================
-- 2. canNetwork
-- ============================================================

--- Can player build a network link?
--- params: { linkId, double (bool, for double rail) }
function Validation.canNetwork(state, color, params)
    local linkId   = params.linkId
    local isDouble = params.double or false

    local player = GameState.getPlayer(state, color)
    local era    = state.era

    -- ---- 1. Link exists ----
    local link     = state.board.links[linkId]
    local linkData = BoardData.links[linkId]
    if not link or not linkData then
        return fail("Link '" .. tostring(linkId) .. "' does not exist")
    end

    -- ---- 2. Link has no owner ----
    if link.owner then
        return fail("Link '" .. linkId .. "' is already owned by " .. tostring(link.owner))
    end

    -- ---- 3. Era type match ----
    local linkTypes = linkData.types
    local eraType   = era  -- Constants.Era.CANAL or Constants.Era.RAIL
    local eraOk     = false
    for _, t in ipairs(linkTypes) do
        if t == eraType then eraOk = true; break end
    end
    if not eraOk then
        return fail("Link '" .. linkId .. "' is not available in the " .. era .. " era")
    end

    -- ---- 4. Link must touch player's network ----
    -- Exception: if player has no presence at all, first link can go anywhere
    local hasPresence = GameState.hasPresenceOnBoard(state, color)
    if hasPresence then
        local cityA, cityB = linkData.cities[1], linkData.cities[2]
        local network      = Network.getPlayerNetwork(state, color)
        if not network[cityA] and not network[cityB] then
            return fail("Link '" .. linkId .. "' does not connect to your network")
        end
    end

    -- ---- 5. Cost and resource checks ----
    if era == Constants.Era.CANAL then
        -- Canal: £CANAL cost, no resources
        if player.money < Constants.LinkCost.CANAL then
            return fail("Not enough money for canal link: need £" .. Constants.LinkCost.CANAL .. ", have £" .. player.money)
        end

    elseif era == Constants.Era.RAIL then
        if isDouble then
            -- Double rail: £DOUBLE_RAIL + 2 coal + 1 beer (covers 2 links)
            if player.money < Constants.LinkCost.DOUBLE_RAIL then
                return fail("Not enough money for double rail: need £" .. Constants.LinkCost.DOUBLE_RAIL .. ", have £" .. player.money)
            end
            -- Need 2 coal
            local cityA = linkData.cities[1]
            local boardCoal, marketCoal = countCoalAvailable(state, cityA)
            local totalCoal = boardCoal + marketCoal
            if totalCoal < 2 then
                return fail("Not enough coal for double rail: need 2, only " .. totalCoal .. " available")
            end
            -- Need 1 beer
            local beerSources = Network.findBeerSources(state, color, cityA, nil)
            local totalBeer = #beerSources
            if totalBeer < 1 then
                return fail("Not enough beer for double rail: need 1, none available")
            end
        else
            -- Single rail: £SINGLE_RAIL + 1 coal
            if player.money < Constants.LinkCost.SINGLE_RAIL then
                return fail("Not enough money for rail link: need £" .. Constants.LinkCost.SINGLE_RAIL .. ", have £" .. player.money)
            end
            local cityA = linkData.cities[1]
            local boardCoal, marketCoal = countCoalAvailable(state, cityA)
            local totalCoal = boardCoal + marketCoal
            if totalCoal < 1 then
                return fail("Not enough coal for rail link: need 1, only " .. totalCoal .. " available")
            end
        end
    end

    return ok()
end

-- ============================================================
-- 3. canSell
-- ============================================================

--- Can player sell?
--- params: { slotId } or { slotIds } for multi-sell
function Validation.canSell(state, color, params)
    -- Normalise to a list of slotIds
    local slotIds
    if params.slotIds then
        slotIds = params.slotIds
    elseif params.slotId then
        slotIds = { params.slotId }
    else
        return fail("No slotId or slotIds provided")
    end

    if #slotIds == 0 then
        return fail("No slots specified")
    end

    for _, slotId in ipairs(slotIds) do
        local slot = GameState.getSlot(state, slotId)
        if not slot then
            return fail("Slot '" .. tostring(slotId) .. "' does not exist")
        end

        -- ---- 1. Must be occupied by this player ----
        if slot.occupant ~= color then
            return fail("Slot '" .. slotId .. "' is not owned by you")
        end

        local tile = slot.tile
        if not tile then
            return fail("Slot '" .. slotId .. "' has no tile")
        end

        -- ---- 2. Must be a sellable industry ----
        if not helpers.tableContains(Constants.SELLABLE_INDUSTRIES, tile.type) then
            return fail("'" .. tile.type .. "' is not a sellable industry")
        end

        -- ---- 3. Must not already be flipped ----
        if tile.flipped then
            return fail("Slot '" .. slotId .. "' is already sold (flipped)")
        end

        -- ---- 4. Must be connected to a merchant via network ----
        local cityName = GameState.getCityForSlot(state, slotId)
        if not cityName then
            return fail("Cannot determine city for slot '" .. slotId .. "'")
        end

        if not Network.isConnectedToMerchant(state, color, cityName) then
            return fail("'" .. cityName .. "' is not connected to any merchant city")
        end

        -- ---- 5. Beer check: enough beer for this tile ----
        local beerNeeded = tile.beerToSell or 0
        if beerNeeded > 0 then
            -- Find the merchant city this is connected to (first one found)
            local merchantName = Network.findConnectedMerchant(state, cityName)

            local beerSources = Network.findBeerSources(state, color, cityName, merchantName)
            -- Count total beer tokens across all sources
            local totalBeer = 0
            for _, src in ipairs(beerSources) do
                if src.isMerchantBeer then
                    -- Merchant beer: add merchant.beer count
                    local merchant = state.board.merchants[src.cityName]
                    if merchant and merchant.beer then
                        totalBeer = totalBeer + merchant.beer
                    else
                        totalBeer = totalBeer + 1  -- synthetic entry represents 1
                    end
                elseif src.slot and src.slot.tile then
                    totalBeer = totalBeer + #src.slot.tile.resources
                end
            end

            if totalBeer < beerNeeded then
                return fail("Not enough beer to sell '" .. tile.type
                            .. "': need " .. beerNeeded .. ", only " .. totalBeer .. " available")
            end
        end
    end

    return ok()
end

-- ============================================================
-- 4. canDevelop
-- ============================================================

--- Can player develop?
--- params: { count } (1 or 2 tiles to remove)
function Validation.canDevelop(state, color, params)
    local count = params.count or 1

    if count ~= 1 and count ~= 2 then
        return fail("Develop count must be 1 or 2, got " .. tostring(count))
    end

    local player = GameState.getPlayer(state, color)

    -- Find the N lowest-level developable tiles across all industry types.
    -- For each industry type: the first tile in the stack is lowest level.
    -- noDevelop tiles at the bottom of a stack must be skipped to the next one.

    -- Collect all candidate tiles: one (or two) per industry type,
    -- skipping noDevelop entries at the front of each stack.
    local candidates = {}

    for industryType, stack in pairs(player.unbuiltTiles) do
        -- Walk the stack from index 1 to find the first non-noDevelop tile
        for _, tile in ipairs(stack) do
            if not tile.noDevelop then
                candidates[#candidates + 1] = { industryType = industryType, tile = tile }
                break  -- only consider the lowest developable per industry type
            end
        end
    end

    if #candidates < count then
        return fail("Not enough developable tiles: need " .. count
                    .. " but only " .. #candidates .. " available")
    end

    -- ---- Iron check: need 1 iron per tile developed ----
    local boardIron, marketIron = countIronAvailable(state)
    local totalIron = boardIron + marketIron
    if totalIron < count then
        return fail("Not enough iron to develop: need " .. count .. ", only " .. totalIron .. " available")
    end

    return ok()
end

-- ============================================================
-- 5. canLoan
-- ============================================================

--- Can player take a loan?
function Validation.canLoan(state, color)
    local player = GameState.getPlayer(state, color)
    if not IncomeTrack.canLoan(player.incomeLevel) then
        return fail("Cannot take a loan: income level " .. player.incomeLevel
                    .. " would drop below -10")
    end
    return ok()
end

-- ============================================================
-- 6. canScout
-- ============================================================

--- Can player scout?
function Validation.canScout(state, color)
    local player = GameState.getPlayer(state, color)

    -- ---- 1. Must NOT already have wild cards ----
    if player.hasWilds then
        return fail("You already have wild cards in hand")
    end

    -- ---- 2. Must have at least 3 cards (1 to play + 2 to discard) ----
    -- handSize tracks how many cards the player currently holds
    if (player.handSize or 0) < 3 then
        return fail("Not enough cards to scout: need at least 3, have " .. (player.handSize or 0))
    end

    -- ---- 3. Wild supply must have at least 1 of each type ----
    if not state.wildSupply or (state.wildSupply.location or 0) < 1 then
        return fail("No wild location cards remaining in supply")
    end
    if (state.wildSupply.industry or 0) < 1 then
        return fail("No wild industry cards remaining in supply")
    end

    -- ---- 4. Player has not already scouted this round ----
    if player.scoutUsedThisRound then
        return fail("You have already used Scout this round")
    end

    return ok()
end

-- ============================================================
-- 7. canPass
-- ============================================================

--- Can the player pass (discard a card without taking an action)?
function Validation.canPass(state, color)
    -- Pass is always valid if a card has been played (checked by TTS layer)
    return ok()
end

return Validation
