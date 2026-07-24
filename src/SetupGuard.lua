local Constants = require("src/Constants")

local SetupGuard = {}

--- Validate seated players against the chosen player count before starting
--- the game (called after the host completes the physical crown setup).
---
--- Pure function: takes the chosen player count and the seat colors reported
--- by TTS, and decides whether the game may start.
---
--- @param expectedCount number  chosen player count (2, 3, or 4)
--- @param seatedColors table  list of TTS seat colors currently occupied by a
---     connected player (as returned by getSeatedPlayers())
--- @param supportedColors table|nil  colors this mod supports as player
---     seats; defaults to Constants.ALL_COLORS. Any seated color outside this
---     set is treated as a non-player seat (e.g. a spectator/observer using a
---     TTS color the mod has no player board for) and is ignored unless it is
---     the reason the supported-seat count doesn't match expectedCount.
--- @return table  { ok = bool, reason = string, ... }
---     reason == ""                on success (ok == true)
---     reason == "unsupported_seat"  seats = { offending colors } — at least
---         one seated color isn't supported and the supported-seat count
---         doesn't match expectedCount
---     reason == "count_mismatch"  expected = expectedCount, actual = <n>
function SetupGuard.validate(expectedCount, seatedColors, supportedColors)
    supportedColors = supportedColors or Constants.ALL_COLORS

    local supportedSet = {}
    for _, color in ipairs(supportedColors) do
        supportedSet[color] = true
    end

    local playerSeats = {}
    local unsupportedSeats = {}
    for _, color in ipairs(seatedColors or {}) do
        if supportedSet[color] then
            playerSeats[#playerSeats + 1] = color
        else
            unsupportedSeats[#unsupportedSeats + 1] = color
        end
    end

    if #playerSeats == expectedCount then
        return { ok = true, reason = "" }
    end

    if #unsupportedSeats > 0 then
        return {
            ok = false,
            reason = "unsupported_seat",
            seats = unsupportedSeats,
        }
    end

    return {
        ok = false,
        reason = "count_mismatch",
        expected = expectedCount,
        actual = #playerSeats,
    }
end

return SetupGuard
