local Constants = require("src/Constants")

local IncomeTrack = {}

-- Returns the income £ amount for a given level (level = income)
function IncomeTrack.levelToIncome(level)
    return level  -- income equals level number
end

-- Returns how many spaces are in a given level
function IncomeTrack.spacesPerLevel(level)
    if level <= 0 then
        return 1
    elseif level <= 10 then
        return 2
    elseif level <= 20 then
        return 3
    else
        return 4
    end
end

-- Advance N spaces forward from current position
-- Returns newLevel, newSpace
-- currentSpace is 0-indexed within the level (0 = first space, spacesPerLevel-1 = last)
function IncomeTrack.advanceSpaces(currentLevel, currentSpace, spaces)
    local level = currentLevel
    local space = currentSpace

    for _ = 1, spaces do
        space = space + 1

        -- Check if we crossed a level boundary
        if space >= IncomeTrack.spacesPerLevel(level) then
            level = level + 1
            space = 0
        end

        -- Cap at level 30, highest space
        if level > 30 then
            level = 30
            space = IncomeTrack.spacesPerLevel(30) - 1
            break
        end
    end

    return level, space
end

-- Decrease N levels (for loans). Land on highest space of new level.
-- Returns newLevel, newSpace
-- Cannot go below -10
function IncomeTrack.decreaseLevels(currentLevel, currentSpace, levels)
    local newLevel = math.max(-10, currentLevel - levels)
    local newSpace = IncomeTrack.spacesPerLevel(newLevel) - 1
    return newLevel, newSpace
end

-- Can the player take a loan? (level - penalty >= -10)
function IncomeTrack.canLoan(currentLevel)
    return (currentLevel - Constants.LOAN_INCOME_PENALTY) >= -10
end

return IncomeTrack
