local Constants = require("src/Constants")
local BoardData = require("src/BoardData")
local GameState = require("src/GameState")

local Market = {}

-- ============================================================
-- Price Lookup Logic
-- ============================================================

--- Get current price for a resource type from market.
--- resourceType: Constants.Resource.COAL or Constants.Resource.IRON
--- The price is determined by the NEXT cube position (the cheapest empty space).
--- When supply = 0, return max price (coal=8, iron=6).
function Market.getPrice(state, resourceType)
    local marketSupply = Market.getMarketSupply(state, resourceType)
    if not marketSupply then return 0 end

    local supply = marketSupply.supply
    local track = Market.getTrack(resourceType)
    local trackLength = (#track)

    -- When supply is 0, return max price (virtual unlimited supply)
    if supply == 0 then
        return Market.getMaxPrice(resourceType)
    end

    -- Price is determined by the position of the leftmost (next) cube
    -- Position = trackLength - supply + 1
    local position = trackLength - supply + 1
    if position < 1 then position = 1 end

    return track[position]
end

-- ============================================================
-- Market Transactions
-- ============================================================

--- Buy N resources from market, deducting money from player.
--- For each unit: get current price, deduct from player, decrease market supply.
--- Returns total cost paid.
function Market.buyFromMarket(state, color, resourceType, count)
    local totalCost = 0

    for i = 1, count do
        local price = Market.getPrice(state, resourceType)
        totalCost = totalCost + price

        -- Deduct money from player
        GameState.spendMoney(state, color, price)

        -- Decrease market supply by 1
        local marketSupply = Market.getMarketSupply(state, resourceType)
        if marketSupply then
            marketSupply.supply = marketSupply.supply - 1
        end
    end

    return totalCost
end

--- Return a resource to the market (when consumed from a building).
--- In Brass: Birmingham, when coal/iron is consumed, the cube goes back to market.
--- Fills lowest empty space on the track.
--- If track is full, resource overflows to general supply (lost).
function Market.returnToMarket(state, resourceType, count)
    local marketSupply = Market.getMarketSupply(state, resourceType)
    if not marketSupply then return end

    local track = Market.getTrack(resourceType)
    local trackMax = (#track)

    -- Increase supply, capped at track max
    marketSupply.supply = marketSupply.supply + count
    if marketSupply.supply > trackMax then
        marketSupply.supply = trackMax
    end
end

-- ============================================================
-- Market State Accessors
-- ============================================================

--- Get the market supply table for a resource type.
function Market.getMarketSupply(state, resourceType)
    if resourceType == Constants.Resource.COAL then
        return state.coalMarket
    elseif resourceType == Constants.Resource.IRON then
        return state.ironMarket
    end
    return nil
end

--- Get the track data for a resource type.
function Market.getTrack(resourceType)
    if resourceType == Constants.Resource.COAL then
        return BoardData.coalMarketTrack
    elseif resourceType == Constants.Resource.IRON then
        return BoardData.ironMarketTrack
    end
    return nil
end

--- Get max price for a resource (when market is empty, virtual unlimited supply).
function Market.getMaxPrice(resourceType)
    if resourceType == Constants.Resource.COAL then return 8 end
    if resourceType == Constants.Resource.IRON then return 6 end
    return 0
end

--- Simulate buying count units from the market WITHOUT modifying state.
--- Returns the total cost using current supply levels for dynamic price calculation.
--- Each simulated purchase decreases a local simulated supply, increasing the next unit's price.
function Market.estimateCost(state, resourceType, count)
    if count <= 0 then return 0 end
    local market = Market.getMarketSupply(state, resourceType)
    if not market then return 0 end
    local track = Market.getTrack(resourceType)
    local trackLen = #track
    local simSupply = market.supply
    local total = 0

    for i = 1, count do
        if simSupply <= 0 then
            total = total + Market.getMaxPrice(resourceType)
        else
            local pos = trackLen - simSupply + 1
            if pos < 1 then pos = 1 end
            total = total + track[pos]
            simSupply = simSupply - 1
        end
    end
    return total
end

return Market
