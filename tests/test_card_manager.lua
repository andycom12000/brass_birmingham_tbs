--- Tests for CardManager.parseCard — the runtime half of issue #3
--- ("Reject unrecognized cards loudly").
---
--- Card recognition is a build-time invariant: scripts/inject_scripts.py's
--- tag_all_cards() stamps every real card's GMNotes with {type="card",
--- cardType=...} before the save ships. parseCard() reads that metadata
--- (falling back to name-pattern matching for legacy/wild objects). This
--- suite exercises every shape tag_all_cards() actually produces — location,
--- single-industry, dual-industry, wild_location, wild_industry — plus the
--- name-based fallback path, and confirms parseCard() returns nil (not a
--- guessed/partial result) for anything else, so EventHandlers can reject
--- loudly instead of silently continuing.
---
--- CardManager.lua is written to run inside TTS, where `JSON` and `Constants`
--- are ambient globals (promoted by inject_scripts.py's bundling step). This
--- file provides minimal standins for both so the module can be required
--- as-is in the plain `lua` test runner.

local Constants = require("src/Constants")
_G.Constants = Constants

--- Minimal recursive-descent JSON decoder, just enough to round-trip the
--- flat {type=..., cardType=..., location=..., industryTypes=[...]} shapes
--- tag_all_cards() emits. Errors (via Lua `error`) on malformed input, same
--- as TTS's real JSON.decode, so `pcall(JSON.decode, str)` behaves the same
--- way it does at runtime.
local function jsonDecode(str)
    local pos = 1
    local len = #str

    local function skipWhitespace()
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        pos = pos + 1 -- opening quote
        local buf = {}
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(buf)
            elseif c == '\\' then
                pos = pos + 1
                local esc = str:sub(pos, pos)
                local map = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                buf[#buf + 1] = map[esc] or esc
                pos = pos + 1
            else
                buf[#buf + 1] = c
                pos = pos + 1
            end
        end
        error("Unterminated string in JSON at pos " .. pos)
    end

    local function parseNumber()
        local startPos = pos
        while pos <= len and str:sub(pos, pos):match("[%d%.%-%+eE]") do
            pos = pos + 1
        end
        local numStr = str:sub(startPos, pos - 1)
        local n = tonumber(numStr)
        if not n then error("Invalid number in JSON: " .. numStr) end
        return n
    end

    local function parseObject()
        pos = pos + 1 -- {
        local obj = {}
        skipWhitespace()
        if str:sub(pos, pos) == "}" then
            pos = pos + 1
            return obj
        end
        while true do
            skipWhitespace()
            if str:sub(pos, pos) ~= '"' then error("Expected string key in JSON object") end
            local key = parseString()
            skipWhitespace()
            if str:sub(pos, pos) ~= ":" then error("Expected ':' in JSON object") end
            pos = pos + 1
            skipWhitespace()
            obj[key] = parseValue()
            skipWhitespace()
            local c = str:sub(pos, pos)
            if c == "," then
                pos = pos + 1
            elseif c == "}" then
                pos = pos + 1
                break
            else
                error("Malformed JSON object at pos " .. pos)
            end
        end
        return obj
    end

    local function parseArray()
        pos = pos + 1 -- [
        local arr = {}
        skipWhitespace()
        if str:sub(pos, pos) == "]" then
            pos = pos + 1
            return arr
        end
        while true do
            skipWhitespace()
            arr[#arr + 1] = parseValue()
            skipWhitespace()
            local c = str:sub(pos, pos)
            if c == "," then
                pos = pos + 1
            elseif c == "]" then
                pos = pos + 1
                break
            else
                error("Malformed JSON array at pos " .. pos)
            end
        end
        return arr
    end

    parseValue = function()
        skipWhitespace()
        local c = str:sub(pos, pos)
        if c == "{" then
            return parseObject()
        elseif c == "[" then
            return parseArray()
        elseif c == '"' then
            return parseString()
        elseif str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        elseif c == "" then
            error("Unexpected end of JSON input")
        else
            return parseNumber()
        end
    end

    if str == nil or str == "" then
        error("Cannot decode empty JSON string")
    end
    local result = parseValue()
    return result
end

_G.JSON = { decode = jsonDecode }

-- CardManager.DISCARD_POSITIONS builds Vector(...) values at module-load
-- time (a top-level table constructor, not inside a function), so a stub
-- must exist before require() runs the module body. parseCard() itself
-- never touches Vector.
_G.Vector = function(x, y, z) return { x = x, y = y, z = z } end

local CardManager = require("tts/CardManager")

--- Build a fake TTS card object exposing only the methods parseCard() uses.
local function fakeCard(opts)
    opts = opts or {}
    return {
        getGMNotes     = function() return opts.gmNotes end,
        getName        = function() return opts.name or "" end,
        getDescription = function() return opts.description or "" end,
        getGUID        = function() return opts.guid or "test-guid" end,
        getMemo        = function() return opts.memo or "" end,
    }
end

describe("CardManager.parseCard — GMNotes metadata (primary path)", function()

    it("parses a location card", function()
        local card = fakeCard({ gmNotes = '{"type":"card","cardType":"location","location":"Birmingham"}' })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.LOCATION)
        expect(info.location).toBe("Birmingham")
    end)

    it("parses a single-industry card", function()
        local card = fakeCard({ gmNotes = '{"type":"card","cardType":"industry","industryTypes":["coal"]}' })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.INDUSTRY)
        expect(info.industryType).toBe("coal")
        expect(#info.industryTypes).toBe(1)
    end)

    it("parses a dual-industry card and sets industryType to the first entry", function()
        local card = fakeCard({ gmNotes = '{"type":"card","cardType":"industry","industryTypes":["cotton","manufacturer"]}' })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.INDUSTRY)
        expect(info.industryType).toBe("cotton")
        expect(#info.industryTypes).toBe(2)
    end)

    it("parses a wild location card", function()
        local card = fakeCard({ gmNotes = '{"type":"card","cardType":"wild_location"}' })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.WILD_LOCATION)
    end)

    it("parses a wild industry card", function()
        local card = fakeCard({ gmNotes = '{"type":"card","cardType":"wild_industry"}' })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.WILD_INDUSTRY)
    end)

end)

describe("CardManager.parseCard — name-based fallback (legacy path)", function()

    it("parses 'Wild Location' by name when GMNotes is absent", function()
        local card = fakeCard({ gmNotes = "", name = "Wild Location" })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.WILD_LOCATION)
    end)

    it("parses 'Wild Industry' by name when GMNotes is absent", function()
        local card = fakeCard({ gmNotes = "", name = "Wild Industry" })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.WILD_INDUSTRY)
    end)

    it("parses 'Location: X' by name when GMNotes is absent", function()
        local card = fakeCard({ gmNotes = "", name = "Location: Derby" })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.LOCATION)
        expect(info.location).toBe("Derby")
    end)

    it("parses 'Industry: X' by name when GMNotes is absent", function()
        local card = fakeCard({ gmNotes = "", name = "Industry: Coal" })
        local info = CardManager.parseCard(card)
        if info == nil then error("expected non-nil parse result") end
        expect(info.cardType).toBe(Constants.CardType.INDUSTRY)
        expect(info.industryType).toBe("coal")
    end)

end)

describe("CardManager.parseCard — unrecognized cards return nil (issue #3)", function()

    it("returns nil when GMNotes is absent and the name matches nothing", function()
        local card = fakeCard({ gmNotes = "", name = "Some Random Object" })
        local info = CardManager.parseCard(card)
        expect(info).toBeNil()
    end)

    it("returns nil when GMNotes is malformed JSON and the name matches nothing", function()
        local card = fakeCard({ gmNotes = "{not valid json", name = "Corrupted Card" })
        local info = CardManager.parseCard(card)
        expect(info).toBeNil()
    end)

    it("returns nil when GMNotes decodes but has no cardType and the name matches nothing", function()
        -- This is exactly what tag_all_cards() writes for an object it recognizes
        -- as a card sheet image but has no CARD_GRID_MAP entry for: {"type":"card"}
        local card = fakeCard({ gmNotes = '{"type":"card"}', name = "Untagged Card" })
        local info = CardManager.parseCard(card)
        expect(info).toBeNil()
    end)

    it("returns nil for a completely blank object (no GMNotes, no name)", function()
        local card = fakeCard({ gmNotes = "", name = "" })
        local info = CardManager.parseCard(card)
        expect(info).toBeNil()
    end)

end)
