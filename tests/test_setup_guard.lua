--- Unit tests for SetupGuard: verify seated players before game start (issue #2).

local SetupGuard = require("src/SetupGuard")
local Constants  = require("src/Constants")

describe("SetupGuard.validate — too few seated players", function()
    it("blocks when fewer players are seated than chosen", function()
        -- Chose 3 players, only 2 seated in supported colors.
        local result = SetupGuard.validate(3, { "White", "Purple" }, Constants.ALL_COLORS)
        expect(result.ok).toBeFalse()
        expect(result.reason).toBe("count_mismatch")
        expect(result.expected).toBe(3)
        expect(result.actual).toBe(2)
    end)
end)

describe("SetupGuard.validate — too many seated players", function()
    it("blocks when more players are seated than chosen", function()
        -- Chose 2 players, but 3 are seated in supported colors.
        local result = SetupGuard.validate(2, { "White", "Purple", "Orange" }, Constants.ALL_COLORS)
        expect(result.ok).toBeFalse()
        expect(result.reason).toBe("count_mismatch")
        expect(result.expected).toBe(2)
        expect(result.actual).toBe(3)
    end)
end)

describe("SetupGuard.validate — unsupported seat color", function()
    it("blocks and names the offending seat when a player sits in an unsupported color", function()
        -- Chose 2 players; one sits in White (supported), the other in Red
        -- (not one of the mod's 4 supported colors) — the supported-seat
        -- count (1) doesn't match the chosen count (2).
        local result = SetupGuard.validate(2, { "White", "Red" }, Constants.ALL_COLORS)
        expect(result.ok).toBeFalse()
        expect(result.reason).toBe("unsupported_seat")
        expect(#result.seats).toBe(1)
        expect(result.seats[1]).toBe("Red")
    end)

    it("names every offending seat when multiple unsupported colors are seated", function()
        local result = SetupGuard.validate(2, { "White", "Red", "Blue" }, Constants.ALL_COLORS)
        expect(result.ok).toBeFalse()
        expect(result.reason).toBe("unsupported_seat")
        expect(#result.seats).toBe(2)
    end)
end)

describe("SetupGuard.validate — correct seating", function()
    it("allows the game to start when exactly N players sit in supported colors (2P)", function()
        local result = SetupGuard.validate(2, { "White", "Purple" }, Constants.ALL_COLORS)
        expect(result.ok).toBeTrue()
        expect(result.reason).toBe("")
    end)

    it("allows the game to start when exactly N players sit in supported colors (4P)", function()
        local result = SetupGuard.validate(4, { "White", "Purple", "Orange", "Yellow" }, Constants.ALL_COLORS)
        expect(result.ok).toBeTrue()
    end)
end)

describe("SetupGuard.validate — non-player seat ignored", function()
    it("does not block when a fifth connected account sits in a non-player seat", function()
        -- All 4 supported colors correctly seated; a fifth account occupies
        -- an unsupported TTS color (spectator-like, no player board for it).
        local result = SetupGuard.validate(
            4,
            { "White", "Purple", "Orange", "Yellow", "Grey" },
            Constants.ALL_COLORS
        )
        expect(result.ok).toBeTrue()
        expect(result.reason).toBe("")
    end)

    it("does not block a correctly-seated smaller game with a spare account seated elsewhere", function()
        local result = SetupGuard.validate(2, { "White", "Purple", "Brown" }, Constants.ALL_COLORS)
        expect(result.ok).toBeTrue()
    end)
end)
