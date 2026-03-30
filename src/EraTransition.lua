local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Scoring   = require("src/Scoring")

local EraTransition = {}

-- ============================================================
-- End-of-Era Detection
-- ============================================================

--- Check if the current era is over.
--- Condition: deck is empty AND all players have 0 cards in hand
---
--- @param state table  Game state
--- @return boolean  True if the era is over
function EraTransition.isEraOver(state)
    if not state.deckEmpty then return false end
    for _, color in ipairs(state.turnOrder) do
        local p = GameState.getPlayer(state, color)
        if p.handSize > 0 then return false end
    end
    return true
end

-- ============================================================
-- Canal-to-Rail Transition
-- ============================================================

--- Execute the full canal-to-rail transition.
--- Handles scoring, board cleanup, era switch, and player reset.
---
--- @param state table  Game state
function EraTransition.transition(state)
    -- 1. Score canal era (mid-game scoring: buildings + links, no income)
    Scoring.scoreEndOfEra(state, false)

    -- 2. Remove ALL canal links (set owner = nil, type = nil, tileGUID = nil)
    for linkId, link in pairs(state.board.links) do
        if link.type == Constants.Era.CANAL then
            link.owner = nil
            link.type = nil
            link.tileGUID = nil
        end
    end

    -- 3. Remove ALL Level 1 buildings from the board
    GameState.forEachSlot(state, function(cityName, slot)
        if slot.tile and slot.tile.level == 1 then
            slot.tile = nil
            slot.occupant = nil
        end
    end)

    -- 4. Switch era
    state.era = Constants.Era.RAIL

    -- 5. Reset round counter
    state.round = 1

    -- 6. Rebuild slot index (some slots may have changed)
    -- Actually slotIndex references are stable, no rebuild needed

    -- 7. Replenish merchant beer (each active merchant slot gets 1 beer)
    if state.board.merchants then
        for _, merchant in pairs(state.board.merchants) do
            if merchant.slots then
                for i = 1, #merchant.slots do
                    merchant.slots[i].filled = false
                    merchant.slots[i].tileGUID = nil
                end
            end
        end
    end

    -- 8. Reset market supplies to initial values
    state.coalMarket.supply = 13
    state.ironMarket.supply = 8

    -- 9. Reset wild supply
    state.wildSupply.location = 4
    state.wildSupply.industry = 4

    -- 10. Reset deck state (TTS layer will handle actual card shuffling)
    state.deckEmpty = false

    -- 11. Reset player states for new era
    for _, color in ipairs(state.turnOrder) do
        local p = GameState.getPlayer(state, color)
        p.handSize = 8  -- TTS will deal cards
        p.hasWilds = false
        p.spentThisRound = 0
        p.scoutUsedThisRound = false
    end

    -- 12. Set actions for first turn (rail era has NO first-round exception — always 2 actions)
    state.currentPlayerIdx = 1
    state.actionsRemaining = 2
end

return EraTransition
