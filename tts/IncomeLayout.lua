--- IncomeLayout: maps income track (level, space) to TTS world positions.
--
-- Positions are taken directly from the reference mod's left-edge snap points.
-- The income track shares the left edge (X=-17.032) with the VP track.
--
-- Income markers start at snap index 12 (Z=-2.370) = income level 10.
-- Levels 0-12: 1 snap point each (single space)
-- Levels 13-18: 2 snap points each (paired, space 0 and 1)
-- Levels below 0 clamp to level 0 position.
-- Levels above 18 clamp to level 18 position.

local IncomeLayout = {}

-- Left-edge snap positions sorted bottom (Z low) to top (Z high).
-- Index 0 is unused (corner point); indices 1-26 are track positions.
-- Income level 0 = index 2, income level 10 = index 12.
local SNAP = {
    -- Levels 0-12: single space per level (indices 2-14)
    [2]  = Vector(-17.032, 0.961, -14.550),  -- level 0
    [3]  = Vector(-17.032, 0.961, -13.332),  -- level 1
    [4]  = Vector(-17.032, 0.961, -12.114),  -- level 2
    [5]  = Vector(-17.032, 0.961, -10.896),  -- level 3
    [6]  = Vector(-17.032, 0.961,  -9.678),  -- level 4
    [7]  = Vector(-17.032, 0.961,  -8.460),  -- level 5
    [8]  = Vector(-17.032, 0.961,  -7.242),  -- level 6
    [9]  = Vector(-17.032, 0.961,  -6.024),  -- level 7
    [10] = Vector(-17.032, 0.961,  -4.806),  -- level 8
    [11] = Vector(-17.032, 0.961,  -3.588),  -- level 9
    [12] = Vector(-17.032, 0.961,  -2.370),  -- level 10  (INITIAL)
    [13] = Vector(-17.032, 0.961,  -0.952),  -- level 11
    [14] = Vector(-17.032, 0.961,   0.009),  -- level 12
    -- Levels 13-18: paired, 2 spaces per level (indices 15-26)
    [15] = Vector(-17.032, 0.961,   1.452),  -- level 13 space 0
    [16] = Vector(-17.032, 0.961,   2.423),  -- level 13 space 1
    [17] = Vector(-17.032, 0.961,   3.909),  -- level 14 space 0
    [18] = Vector(-17.032, 0.961,   4.848),  -- level 14 space 1
    [19] = Vector(-17.032, 0.961,   6.312),  -- level 15 space 0
    [20] = Vector(-17.032, 0.961,   7.250),  -- level 15 space 1
    [21] = Vector(-17.032, 0.961,   8.718),  -- level 16 space 0
    [22] = Vector(-17.032, 0.961,   9.668),  -- level 16 space 1
    [23] = Vector(-17.032, 0.961,  11.127),  -- level 17 space 0
    [24] = Vector(-17.032, 0.961,  12.100),  -- level 17 space 1
    [25] = Vector(-17.032, 0.961,  13.516),  -- level 18 space 0
    [26] = Vector(-17.032, 0.961,  14.509),  -- level 18 space 1
}

--- Convert (incomeLevel, incomeSpace) to a snap index.
-- @param level  integer income level (0-18 on the board; clamped)
-- @param space  0-indexed space within the level
-- @return integer snap index into SNAP table
function IncomeLayout.levelToIndex(level, space)
    -- Clamp level to board range
    if level < 0 then level = 0 end
    if level > 18 then level = 18 end

    if level <= 12 then
        -- Levels 0-12: one snap point per level, starting at index 2
        return level + 2
    else
        -- Levels 13-18: two snap points per level, starting at index 15
        local base = 15 + (level - 13) * 2
        local s = math.min(space or 0, 1)
        return base + s
    end
end

--- Return the world position for a given income level and space.
-- @param level  integer income level
-- @param space  0-indexed space within the level
-- @return Vector  world position
function IncomeLayout.getPosition(level, space)
    local idx = IncomeLayout.levelToIndex(level, space or 0)
    return SNAP[idx]
end

return IncomeLayout
