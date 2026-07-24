local GameState = require("src/GameState")
local Network   = require("src/Network")
local BoardData = require("src/BoardData")
local Constants = require("src/Constants")

local Scoring = {}

-- ============================================================
-- Building VP Scoring
-- ============================================================

--- Score VP for all flipped buildings owned by a player.
--- A building scores its VP value only if:
---   - The player occupies the slot
---   - The tile is placed and flipped
---
--- @param state table  Game state
--- @param color string  Player color
--- @return number  Total VP from flipped buildings
function Scoring.scoreBuildingVP(state, color)
    local total = 0
    GameState.forEachSlot(state, function(cityName, slot)
        if slot.occupant == color and slot.tile and slot.tile.flipped then
            total = total + (slot.tile.vp or 0)
        end
    end)
    return total
end

-- ============================================================
-- Link VP Scoring
-- ============================================================

--- Score VP for all links owned by a player.
--- For each link owned by the player, count the sum of link icons
--- on flipped buildings in both adjacent cities.
---
--- @param state table  Game state
--- @param color string  Player color
--- @return number  Total VP from links (based on link icons in adjacent cities)
function Scoring.scoreLinkVP(state, color)
    local total = 0
    for linkId, link in pairs(state.board.links) do
        if link.owner == color then
            local linkData = BoardData.links[linkId]
            local cityList = linkData and linkData.cities or {}

            for _, cityName in ipairs(cityList) do
                local city = state.board.cities[cityName]
                if city and city.slots then
                    for _, slot in ipairs(city.slots) do
                        if slot.tile and slot.tile.flipped then
                            total = total + (slot.tile.linkIcons or 0)
                        end
                    end
                end
            end
        end
    end
    return total
end

-- ============================================================
-- Income VP Scoring
-- ============================================================

--- Score income VP (only at end of game / end of rail era).
--- The player's current income level directly equals VP (can be negative).
---
--- @param state table  Game state
--- @param color string  Player color
--- @return number  Income level (which equals VP at end of game)
function Scoring.scoreIncomeVP(state, color)
    return GameState.getPlayer(state, color).incomeLevel
end

-- ============================================================
-- End-of-Era Scoring
-- ============================================================

--- Execute end-of-era scoring for all players.
--- Calculates building VP, link VP, and optionally income VP.
--- Updates each player's total VP and returns a detailed breakdown.
---
--- @param state table  Game state
--- @param isFinal boolean  If true, includes income VP (end of rail era)
--- @return table  Scoring results for each player color
function Scoring.scoreEndOfEra(state, isFinal)
    local results = {}
    for _, color in ipairs(state.turnOrder) do
        local buildingVP = Scoring.scoreBuildingVP(state, color)
        local linkVP = Scoring.scoreLinkVP(state, color)
        local incomeVP = isFinal and Scoring.scoreIncomeVP(state, color) or 0
        local totalEraVP = buildingVP + linkVP + incomeVP

        local p = GameState.getPlayer(state, color)
        p.vp = p.vp + totalEraVP

        results[color] = {
            buildingVP = buildingVP,
            linkVP = linkVP,
            incomeVP = incomeVP,
            totalEraVP = totalEraVP,
            totalVP = p.vp,
        }
    end
    return results
end

-- ============================================================
-- Live VP Tracking (issue #10) / Projected VP (issue #11)
-- ============================================================

--- Confirmed VP totals for every player — the value physical score markers
--- must always match (issue #10). This is a thin pure wrapper so "what
--- marker position is correct" is unit-testable on its own, independent of
--- the TTS object calls that actually move the markers (tts/ScoreTracker).
---
--- @param state table  Game state
--- @return table  { [color] = confirmedVP }
function Scoring.confirmedTotals(state)
    local totals = {}
    for _, color in ipairs(state.turnOrder) do
        totals[color] = GameState.getPlayer(state, color).vp or 0
    end
    return totals
end

--- Project each player's final VP total if scoring were run right now,
--- broken down by source, WITHOUT mutating state (issue #11).
---
--- Income VP is only projected once the game has reached the final era
--- (Rail) — that mirrors exactly what Scoring.scoreEndOfEra(state, isFinal)
--- would compute for the *next* scoring event: a Canal-era-end transition
--- never includes income, only the Rail-era game-end does. This is what
--- makes the projection equivalent to actually running era-end scoring
--- (see tests/test_projected_vp.lua).
---
--- @param state table  Game state
--- @return table  { [color] = { confirmed, buildings, links, income, total } }
function Scoring.projectedTotals(state)
    local isFinal = (state.era == Constants.Era.RAIL)
    local results = {}
    for _, color in ipairs(state.turnOrder) do
        local confirmed = GameState.getPlayer(state, color).vp or 0
        local buildingVP = Scoring.scoreBuildingVP(state, color)
        local linkVP = Scoring.scoreLinkVP(state, color)
        local incomeVP = isFinal and Scoring.scoreIncomeVP(state, color) or 0

        results[color] = {
            confirmed = confirmed,
            buildings = buildingVP,
            links = linkVP,
            income = incomeVP,
            total = confirmed + buildingVP + linkVP + incomeVP,
        }
    end
    return results
end

-- ============================================================
-- Final Ranking / Winner Determination
-- ============================================================

--- Determine final ranking of all players.
--- Tiebreaker order:
---   1. VP (higher is better)
---   2. Income level (higher is better)
---   3. Remaining money (higher is better)
---   4. Shared victory (indicated by equal ranking)
---
--- @param state table  Game state
--- @return table  List of ranking entries { color, vp, incomeLevel, money }
function Scoring.determineWinner(state)
    local ranking = {}
    for _, color in ipairs(state.turnOrder) do
        local p = GameState.getPlayer(state, color)
        ranking[#ranking + 1] = {
            color = color,
            vp = p.vp,
            incomeLevel = p.incomeLevel,
            money = p.money,
        }
    end
    table.sort(ranking, function(a, b)
        if a.vp ~= b.vp then return a.vp > b.vp end
        if a.incomeLevel ~= b.incomeLevel then return a.incomeLevel > b.incomeLevel end
        return a.money > b.money
    end)
    return ranking
end

return Scoring
