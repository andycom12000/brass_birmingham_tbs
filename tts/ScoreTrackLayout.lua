--- ScoreTrackLayout: maps a confirmed VP total (0-100) to a TTS world
--- position on the physical score track, and identifies each seat's
--- physical score marker object.
--
-- Physical markers
-- ----------------
-- The reference mod ships four "score indicator" discs (Custom_Model,
-- Nickname "分数指示物") sitting at the score track's start space. Their
-- GUIDs were found by inspecting the reference mod save and matched to our
-- four TTS seat colors the same way tts/Global.lua's COLOR_TO_INCOME_GUID
-- was built: by comparing each disc's ColorDiffuse against the already-
-- identified income markers ("收入指示物", backgammon_piece_white), which
-- sit at the exact same anchor point and use the same four physical colors.
--
--   Orange -> 2d162b   (red-ish,   matches income GUID c13f31)
--   Yellow -> 2a926b   (gold,      matches income GUID 8ef975)
--   Purple -> 18e2bd   (magenta,   matches income GUID c5d022)
--   White  -> 0a843a   (grey/white,matches income GUID 8f36d3)
--
-- Track geometry — ESTIMATED, PENDING TTS CALIBRATION
-- -----------------------------------------------------
-- All four score markers start at X=-17.032, Z=-14.550 — the exact same
-- world position as the income track's level-0 space (see IncomeLayout.lua
-- SNAP[2]), i.e. the shared bottom-left corner of the left-edge track strip.
-- No other point along the VP track has been measured in TTS (unlike
-- MarketLayout/IncomeLayout, which were built from real cube/marker
-- placements). Real Brass: Birmingham boards run VP 0-100 as a loop around
-- all four board edges starting from this corner, so this module estimates
-- that loop as a rectangle: the one measured edge (the income track) gives
-- a uniform world-units-per-space step, and the other three edges are
-- assumed symmetric.
--
-- TODO (follow-up, needs a human at the TTS table): open the mod, walk a
-- score marker around the printed VP track space by space, and replace the
-- formula below with a measured position table — the same way
-- MarketLayout.positions / IncomeLayout.SNAP were built. Until then, marker
-- movement is functionally correct (always reflects the right VP count) but
-- its on-screen placement has NOT been visually verified.

local ScoreTrackLayout = {}

--- Physical score-marker GUID per TTS seat color.
ScoreTrackLayout.COLOR_TO_GUID = {
    Orange = "2d162b",
    Yellow = "2a926b",
    Purple = "18e2bd",
    White  = "0a843a",
}

-- Shared anchor with the income track's level-0 space.
local ANCHOR_X, ANCHOR_Z = -17.032, -14.550
-- Estimated half-extents of the board's outer edge, mirrored from the one
-- measured edge (income track spans this same Z range on the left side).
local HALF_W, HALF_Z = 17.032, 14.550
local TRACK_Y = 0.98

local LEFT_LEN  = HALF_Z * 2   -- up the left edge
local TOP_LEN   = HALF_W * 2   -- across the top edge
local RIGHT_LEN = HALF_Z * 2   -- down the right edge
-- (the bottom edge implicitly closes the loop back to the anchor)

local STEPS = 101  -- VP 0..100
local PERIMETER = LEFT_LEN + TOP_LEN + RIGHT_LEN + TOP_LEN
local STEP = PERIMETER / STEPS

--- Estimated world position for a confirmed VP total (clamped to 0-100).
--- Walks the estimated rectangular loop counter-clockwise from the shared
--- anchor corner: up the left edge, across the top, down the right edge,
--- then along the bottom back toward the anchor.
--- @param vp number
--- @return Vector
function ScoreTrackLayout.getPosition(vp)
    vp = math.max(0, math.min(100, vp or 0))
    local dist = vp * STEP

    if dist <= LEFT_LEN then
        return Vector(ANCHOR_X, TRACK_Y, ANCHOR_Z + dist)
    end
    dist = dist - LEFT_LEN

    if dist <= TOP_LEN then
        return Vector(ANCHOR_X + dist, TRACK_Y, ANCHOR_Z + LEFT_LEN)
    end
    dist = dist - TOP_LEN

    if dist <= RIGHT_LEN then
        return Vector(ANCHOR_X + TOP_LEN, TRACK_Y, (ANCHOR_Z + LEFT_LEN) - dist)
    end
    dist = dist - RIGHT_LEN

    return Vector((ANCHOR_X + TOP_LEN) - dist, TRACK_Y, ANCHOR_Z)
end

return ScoreTrackLayout
