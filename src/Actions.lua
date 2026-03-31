local Constants   = require("src/Constants")
local BoardData   = require("src/BoardData")
local GameState   = require("src/GameState")
local Network     = require("src/Network")
local Market      = require("src/Market")
local IncomeTrack = require("src/IncomeTrack")
local Validation  = require("src/Validation")

local Actions = {}

-- ============================================================
-- Internal helpers
-- ============================================================

local function ok()
    return { success = true, error = "" }
end

local function fail(reason)
    return { success = false, error = reason }
end

--- Advance a player's income track by N spaces and update state.
local function advanceIncome(state, color, spaces)
    if spaces <= 0 then return end
    local player = GameState.getPlayer(state, color)
    local newLevel, newSpace = IncomeTrack.advanceSpaces(
        player.incomeLevel, player.incomeSpace, spaces)
    player.incomeLevel = newLevel
    player.incomeSpace = newSpace
end

--- Auto-flip a tile (coal/iron) when its resources are exhausted.
--- Awards income advancement to the tile's owner.
local function autoFlipIfEmpty(state, slot)
    local tile = slot.tile
    if not tile then return end
    if tile.flipped then return end
    -- Only auto-flip coal mines and iron works
    if tile.type ~= Constants.Industry.COAL and tile.type ~= Constants.Industry.IRON then
        return
    end
    if #tile.resources == 0 then
        tile.flipped = true
        -- Award income to the owner
        if slot.occupant then
            advanceIncome(state, slot.occupant, tile.incomeSpaces)
        end
    end
end

--- Consume up to `needed` coal from buildings connected to `cityName`.
--- Returns the number still needed after taking from buildings.
--- Consumed coal is returned to market.
local function consumeCoalFromBuildings(state, cityName, needed)
    local remaining = needed
    local sources = Network.findNearestCoal(state, cityName)
    while remaining > 0 do
        if not sources or #sources == 0 then break end
        -- Take one coal from the first source (nearest)
        local src = sources[1]
        local resources = src.slot.tile.resources
        if #resources > 0 then
            table.remove(resources, #resources)  -- remove last token
            Market.returnToMarket(state, Constants.Resource.COAL, 1)
            autoFlipIfEmpty(state, src.slot)
            remaining = remaining - 1
            -- If this source is exhausted, remove it from the list
            if #resources == 0 then
                table.remove(sources, 1)
            end
        else
            -- Source exhausted, remove and continue
            table.remove(sources, 1)
        end
        -- If all sources at this distance are exhausted, re-search for next nearest
        if #sources == 0 and remaining > 0 then
            sources = Network.findNearestCoal(state, cityName)
        end
    end
    return remaining
end

--- Consume up to `needed` iron from any iron works on the board.
--- Returns the number still needed after taking from buildings.
--- Consumed iron is returned to market.
local function consumeIronFromBuildings(state, needed)
    local remaining = needed
    local sources = Network.findIronSources(state)
    local srcIdx = 1
    while remaining > 0 do
        if srcIdx > #sources then break end
        local src = sources[srcIdx]
        local resources = src.slot.tile.resources
        if #resources > 0 then
            table.remove(resources, #resources)
            Market.returnToMarket(state, Constants.Resource.IRON, 1)
            autoFlipIfEmpty(state, src.slot)
            remaining = remaining - 1
            -- If this source is exhausted, move to the next
            if #resources == 0 then
                srcIdx = srcIdx + 1
            end
        else
            srcIdx = srcIdx + 1
        end
    end
    return remaining
end

--- Consume `needed` coal: buildings first, then market.
local function consumeCoal(state, color, cityName, needed)
    if needed <= 0 then return end
    local fromMarket = consumeCoalFromBuildings(state, cityName, needed)
    if fromMarket > 0 then
        Market.buyFromMarket(state, color, Constants.Resource.COAL, fromMarket)
    end
end

--- Consume `needed` iron: buildings first, then market.
local function consumeIron(state, color, needed)
    if needed <= 0 then return end
    local fromMarket = consumeIronFromBuildings(state, needed)
    if fromMarket > 0 then
        Market.buyFromMarket(state, color, Constants.Resource.IRON, fromMarket)
    end
end

--- Consume `needed` beer from available sources for an action at `cityName`.
--- Own breweries are used first, then connected others, then merchant beer.
--- Beer is not returned to market — it is simply removed.
--- `merchantName` is the merchant city being sold to (nil if not selling).
local function consumeBeer(state, color, cityName, needed, merchantName)
    if needed <= 0 then return end
    local remaining = needed
    local sources = Network.findBeerSources(state, color, cityName, merchantName)
    for _, src in ipairs(sources) do
        if remaining <= 0 then break end
        if src.isMerchantBeer then
            local merchant = state.board.merchants[src.cityName]
            if merchant and merchant.beer and merchant.beer > 0 then
                merchant.beer = merchant.beer - 1
                remaining = remaining - 1
            end
        elseif src.slot and src.slot.tile then
            local resources = src.slot.tile.resources
            while remaining > 0 and #resources > 0 do
                table.remove(resources, #resources)
                remaining = remaining - 1
            end
            -- Breweries do not auto-flip based on resource depletion the same way;
            -- they are already flipped on build. No income award on beer consumption.
        end
    end
end


--- Remove the first tile matching `industryType` and `level` from
--- the player's unbuiltTiles stack.
local function removeTileFromUnbuilt(player, industryType, level)
    local stack = player.unbuiltTiles[industryType]
    if not stack then return nil end
    for i, tile in ipairs(stack) do
        if tile.level == level then
            table.remove(stack, i)
            return tile
        end
    end
    return nil
end

--- Remove the first developable (non-noDevelop) tile across all industry
--- stacks, ordered by lowest level. Returns the removed tile and its type.
local function removeLowestDevelopable(player)
    -- Collect candidates: first developable tile from each industry type
    local candidates = {}
    for industryType, stack in pairs(player.unbuiltTiles) do
        for i, tile in ipairs(stack) do
            if not tile.noDevelop then
                candidates[#candidates + 1] = {
                    industryType = industryType,
                    level        = tile.level,
                    index        = i,
                }
                break
            end
        end
    end

    if #candidates == 0 then return nil, nil end

    -- Sort by level ascending; stable by industryType as tiebreaker
    table.sort(candidates, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.industryType < b.industryType
    end)

    local best = candidates[1]
    local removed = table.remove(player.unbuiltTiles[best.industryType], best.index)
    return removed, best.industryType
end

-- ============================================================
-- 1. Build
-- ============================================================

--- Auto-sell produced resources to market when building a coal mine or iron works.
--- Mandatory rule: if market has empty slots, cubes must fill them.
--- Returns { sold=number, kept=number } for the caller to animate.
function Actions.autoSellToMarket(state, color, slot)
    local tile = slot.tile
    if not tile then return { sold = 0, kept = 0 } end

    local resourceType = nil
    if tile.type == Constants.Industry.COAL then
        resourceType = Constants.Resource.COAL
    elseif tile.type == Constants.Industry.IRON then
        resourceType = Constants.Resource.IRON
    else
        return { sold = 0, kept = 0 }
    end

    local track = Market.getTrack(resourceType)
    local trackMax = #track
    local market = Market.getMarketSupply(state, resourceType)
    if not market then return { sold = 0, kept = 0 } end

    local emptySlots = trackMax - market.supply
    local produced = #tile.resources
    local sellCount = math.min(produced, emptySlots)

    -- Sell cubes to market using existing Market.returnToMarket
    if sellCount > 0 then
        Market.returnToMarket(state, resourceType, sellCount)
        -- Remove sold cubes from tile
        for i = 1, sellCount do
            table.remove(tile.resources, #tile.resources)
        end
        -- Builder gains $1 per cube sold
        GameState.gainMoney(state, color, sellCount)
    end

    -- Auto-flip if all cubes sold
    autoFlipIfEmpty(state, slot)

    return { sold = sellCount, kept = produced - sellCount }
end

--- Execute the Build action.
--- params: { cardType, location, industryType, level, slotId }
function Actions.build(state, color, params)
    -- Step 1: Validate
    local v = Validation.canBuild(state, color, params)
    if not v.valid then
        return fail(v.reason)
    end

    local player      = GameState.getPlayer(state, color)
    local industryType = params.industryType
    local level        = params.level
    local slotId       = params.slotId

    local slot     = GameState.getSlot(state, slotId)
    local cityName = GameState.getCityForSlot(state, slotId)

    local costData = BoardData.buildingCosts[industryType][level]

    -- Step 9: For overbuilding — remove old tile from slot first.
    -- The old tile simply leaves play (no income refund etc.)
    if slot.occupant then
        slot.occupant = nil
        slot.tile     = nil
    end

    -- Step 2: Remove tile from player's unbuiltTiles
    local tile = removeTileFromUnbuilt(player, industryType, level)
    if not tile then
        return fail("Could not find tile " .. industryType .. " level " .. level
                    .. " in unbuiltTiles (internal error)")
    end

    -- Initialise the tile with its resources (mirrors Tile.newWithResources logic):
    -- fill resource tokens and auto-flip breweries.
    if tile.produces and tile.produces > 0 and tile.producesType then
        for _ = 1, tile.produces do
            tile.resources[#tile.resources + 1] = tile.producesType
        end
    end
    -- Breweries auto-flip immediately on placement
    if industryType == Constants.Industry.BREWERY then
        tile.flipped = true
    end

    -- Step 3: Place tile on board slot
    slot.occupant = color
    slot.tile     = tile

    -- Step 4: Deduct money cost
    GameState.spendMoney(state, color, costData.money)

    -- Step 5: Consume coal (nearest connected source first, then market)
    local coalNeeded = costData.coal or 0
    consumeCoal(state, color, cityName, coalNeeded)

    -- Step 6: Consume iron (any source first, then market)
    local ironNeeded = costData.iron or 0
    consumeIron(state, color, ironNeeded)

    -- Step 8: For breweries — income advance on placement (flipped = already done above)
    -- Breweries award income when they are sold/flipped; since they flip on build,
    -- we advance income now.
    if industryType == Constants.Industry.BREWERY then
        advanceIncome(state, color, tile.incomeSpaces)
    end

    -- Auto-sell for coal mines and iron works (mandatory rule)
    local autoSellResult = Actions.autoSellToMarket(state, color, slot)

    -- Step 10: Update handSize (player played a card)
    GameState.playCard(state, color)

    return ok()
end

-- ============================================================
-- 2. Network
-- ============================================================

--- Execute the Network (build link) action.
--- params: { linkId, secondLinkId (optional, for double rail) }
function Actions.network(state, color, params)
    -- Step 1: Validate primary link
    local isDouble = (params.secondLinkId ~= nil)
    local v = Validation.canNetwork(state, color, {
        linkId = params.linkId,
        double = isDouble,
    })
    if not v.valid then
        return fail(v.reason)
    end

    -- If double rail, also validate the second link
    if isDouble then
        local v2 = Validation.canNetwork(state, color, {
            linkId = params.secondLinkId,
            double = false,  -- check it as a standalone single (availability)
        })
        if not v2.valid then
            return fail("Second link invalid: " .. v2.reason)
        end
    end

    local player = GameState.getPlayer(state, color)
    local era    = state.era

    -- Determine costs
    local moneyCost, coalNeeded, beerNeeded
    if era == Constants.Era.CANAL then
        moneyCost  = Constants.LinkCost.CANAL
        coalNeeded = 0
        beerNeeded = 0
    elseif isDouble then
        moneyCost  = Constants.LinkCost.DOUBLE_RAIL
        coalNeeded = 2
        beerNeeded = 1
    else
        moneyCost  = Constants.LinkCost.SINGLE_RAIL
        coalNeeded = 1
        beerNeeded = 0
    end

    -- Find a reference city for coal/beer source searching
    local linkData = BoardData.links[params.linkId]
    local refCity  = linkData.cities[1]

    -- Step 3: Deduct money
    GameState.spendMoney(state, color, moneyCost)

    -- Step 4: Consume coal
    consumeCoal(state, color, refCity, coalNeeded)

    -- Step 5: Consume beer (double rail only)
    if beerNeeded > 0 then
        consumeBeer(state, color, refCity, beerNeeded, nil)
    end

    -- Step 2: Place link(s) — set owner on board
    state.board.links[params.linkId].owner = color

    if isDouble then
        state.board.links[params.secondLinkId].owner = color
    end

    -- Step 6: Decrease linksRemaining (1 for single/canal, 2 for double)
    local linksPlaced = isDouble and 2 or 1
    player.linksRemaining = (player.linksRemaining or 0) - linksPlaced

    -- Step 7: Update handSize
    GameState.playCard(state, color)

    return ok()
end

-- ============================================================
-- 3. Sell
-- ============================================================

--- Execute the Sell action.
--- params: { slotIds = { "slotId1", ... }, merchantName = "Shrewsbury" }
function Actions.sell(state, color, params)
    -- Step 1: Validate
    local v = Validation.canSell(state, color, params)
    if not v.valid then
        return fail(v.reason)
    end

    local slotIds     = params.slotIds or { params.slotId }
    local merchantName = params.merchantName  -- may be nil

    -- Step 2: For each building, consume beer, flip tile, advance income
    for _, slotId in ipairs(slotIds) do
        local slot = GameState.getSlot(state, slotId)
        local tile = slot.tile
        local cityName = GameState.getCityForSlot(state, slotId)

        -- 2a. Consume required beer
        local beerNeeded = tile.beerToSell or 0
        if beerNeeded > 0 then
            consumeBeer(state, color, cityName, beerNeeded, merchantName)
        end

        -- 2b. Flip the tile
        tile.flipped = true

        -- 2c. Advance income track
        advanceIncome(state, color, tile.incomeSpaces)
    end

    -- Step 3: Process merchant bonus if a merchant city was involved
    if merchantName then
        local merchant = state.board.merchants[merchantName]
        if merchant and merchant.bonus then
            local bonus = merchant.bonus
            local player = GameState.getPlayer(state, color)
            if bonus.type == "vp" then
                player.vp = (player.vp or 0) + (bonus.value or 0)
            elseif bonus.type == "money" then
                GameState.gainMoney(state, color, bonus.value or 0)
            elseif bonus.type == "income_advance" then
                advanceIncome(state, color, bonus.value or 0)
            elseif bonus.type == "develop_free" then
                -- Grant a free develop: flag for the caller to handle, or
                -- remove one developable tile from unbuiltTiles without iron cost.
                local count = bonus.value or 1
                for _ = 1, count do
                    removeLowestDevelopable(player)
                end
            end
        end
    end

    -- Step 4: Update handSize
    GameState.playCard(state, color)

    return ok()
end

-- ============================================================
-- 4. Develop
-- ============================================================

--- Execute the Develop action.
--- params: { count = 1 or 2 }
function Actions.develop(state, color, params)
    -- Step 1: Validate
    local v = Validation.canDevelop(state, color, params)
    if not v.valid then
        return fail(v.reason)
    end

    local count  = params.count or 1
    local player = GameState.getPlayer(state, color)

    -- Steps 2 & 3: For each tile to develop, consume 1 iron then remove tile.
    for _ = 1, count do
        -- Consume 1 iron (buildings first, then market)
        consumeIron(state, color, 1)
        -- Remove lowest-level non-noDevelop tile from unbuiltTiles
        removeLowestDevelopable(player)
    end

    -- Step 4: Update handSize
    GameState.playCard(state, color)

    return ok()
end

-- ============================================================
-- 5. Loan
-- ============================================================

--- Execute the Loan action.
function Actions.loan(state, color)
    -- Step 1: Validate
    local v = Validation.canLoan(state, color)
    if not v.valid then
        return fail(v.reason)
    end

    local player = GameState.getPlayer(state, color)

    -- Step 2: Gain £LOAN_AMOUNT
    GameState.gainMoney(state, color, Constants.LOAN_AMOUNT)

    -- Step 3: Decrease income by LOAN_INCOME_PENALTY levels
    local newLevel, newSpace = IncomeTrack.decreaseLevels(
        player.incomeLevel, player.incomeSpace, Constants.LOAN_INCOME_PENALTY)
    player.incomeLevel = newLevel
    player.incomeSpace = newSpace

    -- Step 4: Update handSize (player played a card)
    GameState.playCard(state, color)

    return ok()
end

-- ============================================================
-- 6. Scout
-- ============================================================

--- Execute the Scout action.
function Actions.scout(state, color)
    -- Step 1: Validate
    local v = Validation.canScout(state, color)
    if not v.valid then
        return fail(v.reason)
    end

    local player = GameState.getPlayer(state, color)

    -- Steps 2 & 3: Net handSize change is -1 (lost 3 cards, gained 2 wilds).
    -- The card played counts as -1, the 2 discarded are -2, gaining 2 wilds = +2.
    GameState.playCard(state, color)       -- lose 1 (played card)
    player.handSize = player.handSize - 2  -- lose 2 (discarded)
    player.handSize = player.handSize + 2  -- gain 2 wild cards
    player.hasWilds = true

    -- Step 4: Decrease wildSupply
    state.wildSupply.location = state.wildSupply.location - 1
    state.wildSupply.industry = state.wildSupply.industry - 1

    -- Step 5: Mark scout used this round
    player.scoutUsedThisRound = true

    return ok()
end

return Actions
