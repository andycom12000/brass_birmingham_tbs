local Constants = require("src/Constants")
local BoardData = require("src/BoardData")

local Tile = {}

--- Create a new tile from BoardData.buildingCosts
--- @param industryType string  Constants.Industry value
--- @param level number  integer
--- @return table  A tile with all fields initialized
function Tile.new(industryType, level)
    local costData = BoardData.buildingCosts[industryType][level]
    if not costData then
        error(string.format("No building cost data for %s level %d", industryType, level))
    end

    -- Determine producesType based on industry
    local producesType = nil
    if industryType == Constants.Industry.COAL then
        producesType = Constants.Resource.COAL
    elseif industryType == Constants.Industry.IRON then
        producesType = Constants.Resource.IRON
    elseif industryType == Constants.Industry.BREWERY then
        producesType = Constants.Resource.BEER
    end

    -- Build the tile object with all fields
    local tile = {
        type = industryType,
        level = level,
        flipped = false,
        vp = costData.vp or 0,
        linkIcons = costData.linkIcons or 0,
        incomeSpaces = costData.incomeSpaces or 0,
        beerToSell = costData.beerToSell or 0,
        produces = costData.produces or 0,
        producesType = producesType,
        resources = {},
        noDevelop = costData.noDevelop or false,
        railOnly = costData.railOnly or false,
        cost = {
            money = costData.money or 0,
            coal = costData.coal or 0,
            iron = costData.iron or 0,
        },
    }

    return tile
end

--- Create a tile and immediately fill its resources
--- Coal mines get N coal tokens, Iron works get N iron tokens, Breweries get N beer tokens
--- Breweries auto-flip on build
--- For breweries, resource count is era-based: canal=1, rail=2 (overrides BoardData.produces)
--- @param industryType string  Constants.Industry value
--- @param level number  integer
--- @param era string|nil  Constants.Era value ("canal" or "rail"); defaults to "canal"
--- @return table  A tile with resources initialized and flipped state
function Tile.newWithResources(industryType, level, era)
    local tile = Tile.new(industryType, level)

    -- For breweries, override produces based on era (canal=1, rail=2)
    if industryType == Constants.Industry.BREWERY then
        tile.produces = (era == Constants.Era.RAIL) and 2 or 1
    end

    -- Fill resources if tile produces something
    if tile.produces > 0 and tile.producesType then
        for i = 1, tile.produces do
            tile.resources[i] = tile.producesType
        end
    end

    -- Breweries auto-flip on build
    if industryType == Constants.Industry.BREWERY then
        tile.flipped = true
    end

    return tile
end

return Tile
