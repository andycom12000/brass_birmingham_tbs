local Constants = require("src/Constants")
local BoardData  = require("src/BoardData")
local Tile       = require("src/Tile")
local helpers    = require("src/helpers")

local GameState = {}

-- ============================================================
-- Internal helpers
-- ============================================================

--- Build the unbuiltTiles table for a single player.
--- Each industry type has an ordered stack (lowest level first).
--- We create `count` copies of Tile.new(type, level) per level entry.
local function buildUnbuiltTiles()
    local tiles = {}
    for industryType, levels in pairs(BoardData.buildingCosts) do
        tiles[industryType] = {}
        -- Collect all levels first so we can sort them
        local sortedLevels = {}
        for level, _ in pairs(levels) do
            sortedLevels[#sortedLevels + 1] = level
        end
        table.sort(sortedLevels)

        for _, level in ipairs(sortedLevels) do
            local costData = levels[level]
            local count = costData.count or 1
            for _ = 1, count do
                tiles[industryType][#tiles[industryType] + 1] = Tile.new(industryType, level)
            end
        end
    end
    return tiles
end

--- Build the board.cities table: deep copy + add occupant/tile fields,
--- and remove cities that are excluded for this player count.
local function buildBoardCities(playerCount)
    local removedSet = {}
    for _, name in ipairs(BoardData.getRemovedCities(playerCount)) do
        removedSet[name] = true
    end

    local cities = {}
    for cityName, cityData in pairs(BoardData.cities) do
        if not removedSet[cityName] then
            local city = helpers.deepCopy(cityData)
            -- Add occupant/tile fields to every slot
            if city.slots then
                for _, slot in ipairs(city.slots) do
                    slot.occupant = nil
                    slot.tile     = nil
                end
            end
            cities[cityName] = city
        end
    end
    return cities, removedSet
end

--- Build the board.links table: deep copy + add owner/tileGUID fields,
--- removing any link that connects to a removed city.
local function buildBoardLinks(removedSet)
    local links = {}
    for linkId, linkData in pairs(BoardData.links) do
        local skip = false
        for _, city in ipairs(linkData.cities) do
            if removedSet[city] then
                skip = true
                break
            end
        end
        if not skip then
            local link = helpers.deepCopy(linkData)
            link.owner    = nil
            link.tileGUID = nil
            links[linkId] = link
        end
    end
    return links
end

--- Build the flat slot index: slotId -> slot object reference.
local function buildSlotIndex(cities)
    local index = {}
    for _, city in pairs(cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.id then
                    index[slot.id] = slot
                end
            end
        end
    end
    return index
end

--- Build city index: slotId -> cityName for O(1) lookup.
local function buildCityIndex(cities)
    local index = {}
    for cityName, city in pairs(cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.id then
                    index[slot.id] = cityName
                end
            end
        end
    end
    return index
end

--- Build initial merchant state for active merchants.
--- Each active merchant city gets a `merchantBonus` field and `merchantSlots` table.
local function buildMerchants(playerCount, cities)
    local activeMerchants = BoardData.getActiveMerchants(playerCount)
    local merchantState = {}
    for _, m in ipairs(activeMerchants) do
        local slots = {}
        for i = 1, m.slots do
            slots[i] = { filled = false, tileGUID = nil }
        end
        merchantState[m.name] = {
            bonus  = helpers.deepCopy(m.bonus),
            slots  = slots,
        }
    end
    return merchantState
end

-- ============================================================
-- Public API
-- ============================================================

--- Create a new game state for N players.
--- @param playerCount number  2, 3, or 4
--- @return table  full state object
function GameState.new(playerCount)
    assert(playerCount >= 2 and playerCount <= 4,
        "playerCount must be 2, 3, or 4, got: " .. tostring(playerCount))

    -- Turn order: first playerCount colors
    local turnOrder = {}
    for i = 1, playerCount do
        turnOrder[i] = Constants.ALL_COLORS[i]
    end

    -- Players
    local players = {}
    for i = 1, playerCount do
        local color = Constants.ALL_COLORS[i]
        players[color] = {
            color              = color,
            money              = Constants.INITIAL_MONEY,
            incomeLevel        = Constants.INITIAL_INCOME,
            incomeSpace        = 0,
            vp                 = 0,
            spentThisRound     = 0,
            linksRemaining     = Constants.INITIAL_LINKS,
            hasWilds           = false,
            handSize           = Constants.INITIAL_HAND_SIZE,
            scoutUsedThisRound = false,
            unbuiltTiles       = buildUnbuiltTiles(),
        }
    end

    -- Board
    local cities, removedSet = buildBoardCities(playerCount)
    local links              = buildBoardLinks(removedSet)
    local slotIndex          = buildSlotIndex(cities)
    local cityIndex          = buildCityIndex(cities)
    local merchants          = buildMerchants(playerCount, cities)

    return {
        era              = Constants.Era.CANAL,
        round            = 1,
        playerCount      = playerCount,
        currentPlayerIdx = 1,
        actionsRemaining = 1,   -- first round of canal era = 1 action

        players   = players,
        turnOrder = turnOrder,

        board = {
            cities    = cities,
            links     = links,
            merchants = merchants,
        },

        slotIndex  = slotIndex,
        cityIndex  = cityIndex,

        coalMarket = { supply = Constants.INITIAL_COAL_SUPPLY },
        ironMarket = { supply = Constants.INITIAL_IRON_SUPPLY },

        wildSupply = { location = Constants.WILD_SUPPLY_COUNT, industry = Constants.WILD_SUPPLY_COUNT },

        deckEmpty = false,

        lang = "en",
    }
end

--- Get player data by color.
--- Raises an error if the color is not in the game.
function GameState.getPlayer(state, color)
    local p = state.players[color]
    if not p then error("Invalid player color: " .. tostring(color)) end
    return p
end

--- Get a slot by its ID string.  O(1) via slotIndex.
function GameState.getSlot(state, slotId)
    return state.slotIndex[slotId]
end

--- Get the city name for a given slot ID.  O(1) via cityIndex.
function GameState.getCityForSlot(state, slotId)
    return state.cityIndex[slotId]
end

--- Deduct one card from a player's hand (playing a card).
function GameState.playCard(state, color)
    local p = GameState.getPlayer(state, color)
    p.handSize = math.max(0, (p.handSize or 0) - 1)
end

--- Deduct money from a player and record spending for turn-order purposes.
function GameState.spendMoney(state, color, amount)
    local p = GameState.getPlayer(state, color)
    p.money          = p.money - amount
    p.spentThisRound = p.spentThisRound + amount
end

--- Give money to a player.
function GameState.gainMoney(state, color, amount)
    local p = GameState.getPlayer(state, color)
    p.money = p.money + amount
end

--- Reset per-round tracking fields for all players at the start of a new round.
function GameState.resetRoundSpending(state)
    for _, p in pairs(state.players) do
        p.spentThisRound     = 0
        p.scoutUsedThisRound = false
    end
end

--- Return the color of the player whose turn it currently is.
function GameState.getCurrentPlayerColor(state)
    return state.turnOrder[state.currentPlayerIdx]
end

--- Return true when we are in round 1 of the canal era (only 1 action per player).
function GameState.isFirstRound(state)
    return state.era == Constants.Era.CANAL and state.round == 1
end

--- Call fn(cityName, slot, slotIndex) for every industry slot on the board.
function GameState.forEachSlot(state, fn)
    for cityName, city in pairs(state.board.cities) do
        if city.slots then
            for i, slot in ipairs(city.slots) do
                fn(cityName, slot, i)
            end
        end
    end
end

--- Count how many slots in a city are currently occupied.
--- Used for the canal-era "max one building per city" rule.
function GameState.countBuildingsInCity(state, cityName)
    local count = 0
    local city = state.board.cities[cityName]
    if city and city.slots then
        for _, slot in ipairs(city.slots) do
            if slot.occupant then count = count + 1 end
        end
    end
    return count
end

--- Return true if the player has at least one building or link on the board.
function GameState.hasPresenceOnBoard(state, color)
    -- Check buildings (direct loop for early exit)
    for _, city in pairs(state.board.cities) do
        if city.slots then
            for _, slot in ipairs(city.slots) do
                if slot.occupant == color then return true end
            end
        end
    end
    -- Check links
    for _, link in pairs(state.board.links) do
        if link.owner == color then return true end
    end
    return false
end

--- Serialize the entire state to a JSON string.
--- Uses the TTS global JSON object when available; returns "" otherwise.
function GameState.serialize(state)
    if JSON then
        return JSON.encode(state)
    end
    return ""
end

--- Deserialize a JSON string back to a state table.
--- Uses the TTS global JSON object when available; returns nil otherwise.
function GameState.deserialize(jsonStr)
    if JSON then
        return JSON.decode(jsonStr)
    end
    return nil
end

return GameState
