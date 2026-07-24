--- ScoreTracker: moves the physical VP score markers to match each
--- player's confirmed VP total (issue #10).
--
-- Deliberately thin: all the "what is the correct total / correct marker
-- position" logic lives in the pure, unit-tested Scoring.confirmedTotals
-- (src/Scoring.lua). This module only does the TTS object call, so the
-- untestable part (physical placement) is as small as possible.
--
-- Physical placement uses ScoreTrackLayout's ESTIMATED track geometry — see
-- that module's header. Marker movement is functionally correct (always
-- targets the position for the right VP count) but the exact on-screen
-- placement is pending manual verification in TTS.

local ScoreTracker = {}

--- Move every player's physical score marker to the position matching
--- their current confirmed VP total. Called by the single post-commit hook
--- aggregator after every committed action and every undo, and manually
--- after era-end scoring (which is not itself wrapped by
--- ActionEngine.commit — see tts/Global.lua).
--- @param state table  Game state
function ScoreTracker.syncMarkers(state)
    if not state then return end
    local totals = Scoring.confirmedTotals(state)
    for _, color in ipairs(state.turnOrder) do
        local guid = ScoreTrackLayout.COLOR_TO_GUID[color]
        local obj  = guid and getObjectFromGUID(guid)
        if obj and not obj.isDestroyed() then
            local pos = ScoreTrackLayout.getPosition(totals[color] or 0)
            if pos then obj.setPositionSmooth(pos) end
        end
    end
end

return ScoreTracker
