--- MarketLayout: maps market track slot indices to TTS world positions.
--
-- Positions were measured from actual cube placements in the reference mod
-- save file (brass_birmingham_scripted.json).
--
-- Each resource track is laid out as rows of two columns (left / right).
--   Odd-numbered slots  -> left column
--   Even-numbered slots -> right column
-- Rows go from cheapest (highest Z, top of board) to most expensive
-- (lowest Z, bottom of board).
--
-- Coal track: 14 slots across 7 rows
--   Prices: $1,$1,$2,$2,$3,$3,$4,$4,$5,$5,$6,$7,$8,$8
-- Iron track: 10 slots across 5 rows
--   Prices: $1,$1,$2,$2,$3,$3,$4,$5,$6,$6
--
-- Slot 1 is the cheapest; cubes fill from slot 1 upward.
-- Iron row 5 (slots 9-10) is estimated by extrapolation; all others are
-- directly measured from placed cubes.

local MarketLayout = {}

MarketLayout.positions = {
    coal = {
        -- Row 1: price $1
        [1]  = Vector(12.15, 1.20, 5.46),
        [2]  = Vector(12.91, 1.20, 5.46),
        -- Row 2: price $2
        [3]  = Vector(12.15, 1.20, 4.42),
        [4]  = Vector(12.91, 1.20, 4.42),
        -- Row 3: price $3
        [5]  = Vector(12.15, 1.20, 3.40),
        [6]  = Vector(12.91, 1.20, 3.40),
        -- Row 4: price $4
        [7]  = Vector(12.15, 1.20, 2.40),
        [8]  = Vector(12.91, 1.20, 2.40),
        -- Row 5: price $5
        [9]  = Vector(12.15, 1.20, 1.39),
        [10] = Vector(12.91, 1.20, 1.39),
        -- Row 6: price $6, $7
        [11] = Vector(12.15, 1.20, 0.37),
        [12] = Vector(12.91, 1.20, 0.37),
        -- Row 7: price $8
        [13] = Vector(12.15, 1.20, -0.65),
        [14] = Vector(12.91, 1.20, -0.65),
    },
    iron = {
        -- Row 1: price $1
        [1]  = Vector(14.08, 1.20, 3.40),
        [2]  = Vector(14.83, 1.20, 3.40),
        -- Row 2: price $2
        [3]  = Vector(14.08, 1.20, 2.40),
        [4]  = Vector(14.83, 1.20, 2.40),
        -- Row 3: price $3
        [5]  = Vector(14.08, 1.20, 1.39),
        [6]  = Vector(14.83, 1.20, 1.39),
        -- Row 4: price $4, $5
        [7]  = Vector(14.08, 1.20, 0.38),
        [8]  = Vector(14.83, 1.20, 0.38),
        -- Row 5: price $6 (estimated by extrapolation)
        [9]  = Vector(14.08, 1.20, -0.62),
        [10] = Vector(14.83, 1.20, -0.62),
    },
}

--- Return the world position for a given resource track slot.
-- @param resourceType  "coal" or "iron"
-- @param index         1-based slot index (1 = cheapest)
-- @return Vector  world position, or Vector(0,0,0) if invalid
function MarketLayout.getPosition(resourceType, index)
    local track = MarketLayout.positions[resourceType]
    if not track then return Vector(0, 0, 0) end
    return track[index] or Vector(0, 0, 0)
end

--- Return the total number of slots on a resource track.
-- @param resourceType  "coal" or "iron"
-- @return number  slot count (14 for coal, 10 for iron, 0 if unknown)
function MarketLayout.getTrackMax(resourceType)
    local track = MarketLayout.positions[resourceType]
    if not track then return 0 end
    return #track
end

return MarketLayout
