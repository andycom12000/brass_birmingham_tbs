--- CardManager.lua
-- Handles all TTS card/deck operations including dealing, discarding, and supply management

local CardManager = {}

--- Build the initial draw deck for player count
-- Removes location cards for cities not in the game
-- @param state Game state object
-- @param deckObj TTS deck object
function CardManager.buildDeck(state, deckObj)
    local removedCities = require("src/BoardData").getRemovedCities(state.playerCount)
    if #removedCities > 0 then
        local cards = deckObj.getObjects()  -- get list of cards in deck
        for i = #cards, 1, -1 do
            local card = cards[i]
            for _, city in ipairs(removedCities) do
                if card.name and card.name:find(city) then
                    deckObj.takeObject({
                        index = card.index,
                        position = {0, -5, 0},  -- off-table
                        callback_function = function(obj) obj.destruct() end,
                    })
                    break
                end
            end
        end
    end
    Wait.time(function() deckObj.shuffle() end, 0.5)
end

--- Deal cards to all players (up to hand size 8)
-- @param state Game state object
function CardManager.dealToAll(state)
    local deckObj = ObjectManager.getObject("drawDeck")
    if not deckObj then return end
    for _, color in ipairs(state.turnOrder) do
        local p = GameState.getPlayer(state, color)
        local toDeal = Constants.INITIAL_HAND_SIZE - (p.handSize or 0)
        if toDeal > 0 then
            deckObj.deal(toDeal, color)
            p.handSize = Constants.INITIAL_HAND_SIZE
        end
    end
end

--- Parse a played card to determine its type
-- Card naming convention: "Location: Birmingham", "Industry: Cotton", "Wild Location", "Wild Industry"
-- @param cardObj TTS card object
-- @return Table with cardType and relevant data (location or industryType), or nil if unrecognized
function CardManager.parseCard(cardObj)
    local name = cardObj.getName()
    if name:find("^Wild Location") then
        return { cardType = Constants.CardType.WILD_LOCATION }
    elseif name:find("^Wild Industry") then
        return { cardType = Constants.CardType.WILD_INDUSTRY }
    elseif name:find("^Location: ") then
        local city = name:match("^Location: (.+)")
        return { cardType = Constants.CardType.LOCATION, location = city }
    elseif name:find("^Industry: ") then
        local industry = name:match("^Industry: (.+)")
        return { cardType = Constants.CardType.INDUSTRY, industryType = industry:lower() }
    end
    return nil
end

--- Move a card to the discard pile
-- @param cardObj TTS card object
function CardManager.discard(cardObj)
    local discardZone = ObjectManager.getObject("discardZone")
    if discardZone then
        cardObj.setPositionSmooth(discardZone.getPosition() + Vector(0, 1, 0))
    end
end

--- Return a wild card to its supply pile
-- @param cardObj TTS card object
-- @param wildType Card type (Constants.CardType.WILD_LOCATION or WILD_INDUSTRY)
function CardManager.returnWildToSupply(cardObj, wildType)
    local supplyKey = (wildType == Constants.CardType.WILD_LOCATION)
        and "wildLocationSupply" or "wildIndustrySupply"
    local supply = ObjectManager.getObject(supplyKey)
    if supply then
        cardObj.setPositionSmooth(supply.getPosition() + Vector(0, 0.5, 0))
    end
end

--- Give wild cards to a player (for Scout action)
-- @param playerColor Player color string
function CardManager.giveWilds(playerColor)
    local locSupply = ObjectManager.getObject("wildLocationSupply")
    local indSupply = ObjectManager.getObject("wildIndustrySupply")

    if locSupply and locSupply.getQuantity() > 0 then
        locSupply.deal(1, playerColor)
    end
    if indSupply and indSupply.getQuantity() > 0 then
        indSupply.deal(1, playerColor)
    end
end

--- Check if the draw deck is empty
-- @return Boolean true if deck is empty
function CardManager.isDeckEmpty()
    local deckObj = ObjectManager.getObject("drawDeck")
    if not deckObj then return true end
    if deckObj.type == "Deck" then return deckObj.getQuantity() <= 0 end
    if deckObj.type == "Card" then return false end  -- single card left
    return true
end

--- Rebuild deck for rail era transition
-- Collects all cards from discard zone and prepares for rail era
-- @param state Game state object
function CardManager.rebuildDeckForRailEra(state)
    -- Collect all cards from discard zone
    local discardZone = ObjectManager.getObject("discardZone")
    if not discardZone then return end

    -- Get objects in the zone
    local objects = discardZone.getObjects and discardZone.getObjects() or {}
    -- Group them into a deck, then build and shuffle
    -- Note: actual implementation depends on how TTS zones work
    -- This is a simplified version
    Wait.time(function()
        local deckObj = ObjectManager.getObject("drawDeck")
        if deckObj then
            CardManager.buildDeck(state, deckObj)
        end
    end, 1.0)
end

--- Refill a player's hand to 8 cards
-- @param state Game state object
-- @param color Player color string
function CardManager.refillHand(state, color)
    local deckObj = ObjectManager.getObject("drawDeck")
    if not deckObj then return end
    local p = GameState.getPlayer(state, color)
    local toDeal = Constants.INITIAL_HAND_SIZE - (p.handSize or 0)
    if toDeal > 0 and deckObj.getQuantity() >= toDeal then
        deckObj.deal(toDeal, color)
        p.handSize = Constants.INITIAL_HAND_SIZE
    end
end

return CardManager
