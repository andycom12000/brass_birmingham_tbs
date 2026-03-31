--- CardManager.lua
-- Handles all TTS card/deck operations including dealing, discarding, and supply management

local CardManager = {}

--- Find the card deck on the board (placed by crown setup button).
--- Searches for a Deck or Card object near the known deck snap point position.
--- @return TTS object|nil  the deck object
function CardManager.findDeckOnBoard()
    local deckPos = Vector(-12.67, 0.96, 11.71)
    local bestObj = nil
    local bestDist = 5

    for _, obj in ipairs(getAllObjects()) do
        if obj.type == "Deck" or obj.type == "Card" then
            local pos = obj.getPosition()
            local dist = math.sqrt(
                (pos.x - deckPos.x)^2 + (pos.z - deckPos.z)^2
            )
            if dist < bestDist then
                bestDist = dist
                bestObj = obj
            end
        end
    end

    return bestObj
end

--- Deal cards from a deck to all players.
--- @param state table  game state
--- @param deckObj TTS object  the deck to deal from
function CardManager.dealFromDeck(state, deckObj)
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

--- Deal cards to all players (up to hand size 8)
-- @param state Game state object
function CardManager.dealToAll(state)
    local deckObj = CardManager.findDeckOnBoard()
    if deckObj then
        CardManager.dealFromDeck(state, deckObj)
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
    local deckObj = CardManager.findDeckOnBoard()
    if not deckObj then return true end
    if deckObj.type == "Deck" then return deckObj.getQuantity() <= 0 end
    if deckObj.type == "Card" then return false end  -- single card left
    return true
end

--- Refill a player's hand to 8 cards
-- @param state Game state object
-- @param color Player color string
function CardManager.refillHand(state, color)
    local deckObj = CardManager.findDeckOnBoard()
    if not deckObj then return end
    local p = GameState.getPlayer(state, color)
    local toDeal = Constants.INITIAL_HAND_SIZE - (p.handSize or 0)
    if toDeal > 0 and deckObj.getQuantity() >= toDeal then
        deckObj.deal(toDeal, color)
        p.handSize = Constants.INITIAL_HAND_SIZE
    end
end

return CardManager
