--- Tests for the ActionEngine commit seam (issue #8).
--- Verifies the single validate/snapshot/execute/commit path: a pre-execution
--- snapshot is captured, the post-commit hook fires exactly once per committed
--- action with the post-action state, failed actions commit nothing, and
--- routing an action through the engine is behaviourally identical to calling
--- the Actions module directly.

local Constants    = require("src/Constants")
local GameState    = require("src/GameState")
local Actions      = require("src/Actions")
local ActionEngine = require("src/ActionEngine")

local function newState()
    return GameState.new(2)
end

--- Reset the engine's module-level state between tests.
local function resetEngine()
    ActionEngine.setPostCommitHook(nil)
    ActionEngine.clearLastCommit()
end

--- Recursive deep equality for plain data tables.
local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k, _ in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-- ============================================================
-- Basic dispatch
-- ============================================================

describe("ActionEngine.execute - dispatch", function()
    it("runs a registered action and reports success", function()
        resetEngine()
        local state = newState()
        local result = ActionEngine.execute(state, "network", "White",
            { linkId = "Birmingham-Dudley" })
        expect(result.success).toBeTrue()
        expect(state.board.links["Birmingham-Dudley"].owner).toBe("White")
    end)

    it("rejects an unknown action without firing the hook", function()
        resetEngine()
        local fired = 0
        ActionEngine.setPostCommitHook(function() fired = fired + 1 end)
        local state = newState()
        local result = ActionEngine.execute(state, "teleport", "White", {})
        expect(result.success).toBeFalse()
        expect(fired).toBe(0)
    end)

    it("routes every atomic action type", function()
        resetEngine()
        -- loan
        local s1 = newState()
        expect(ActionEngine.execute(s1, "loan", "White", {}).success).toBeTrue()
        -- scout
        local s2 = newState()
        GameState.getPlayer(s2, "White").handSize = 8
        expect(ActionEngine.execute(s2, "scout", "White", {}).success).toBeTrue()
        -- develop
        local s3 = newState()
        s3.ironMarket.supply = 8
        expect(ActionEngine.execute(s3, "develop", "White", { count = 1 }).success).toBeTrue()
        -- pass
        local s4 = newState()
        expect(ActionEngine.execute(s4, "pass", "White", {}).success).toBeTrue()
    end)
end)

-- ============================================================
-- Snapshot
-- ============================================================

describe("ActionEngine - pre-execution snapshot", function()
    it("captures state as it was BEFORE the action executed", function()
        resetEngine()
        local captured
        ActionEngine.setPostCommitHook(function(_state, record) captured = record end)

        local state = newState()  -- White money 17
        ActionEngine.execute(state, "loan", "White", {})

        -- Post-action state reflects the loan (+£30)
        expect(GameState.getPlayer(state, "White").money).toBe(47)
        -- The snapshot preserves the pre-action money
        expect(captured.snapshot.players["White"].money).toBe(17)
    end)

    it("snapshot is independent of later state mutation", function()
        resetEngine()
        local state = newState()
        local snap = ActionEngine.beginAction(state)
        GameState.getPlayer(state, "White").money = 999
        expect(snap.players["White"].money).toBe(Constants.INITIAL_MONEY)
    end)
end)

-- ============================================================
-- Post-commit hook
-- ============================================================

describe("ActionEngine - post-commit hook", function()
    it("fires exactly once per committed action", function()
        resetEngine()
        local fired = 0
        ActionEngine.setPostCommitHook(function() fired = fired + 1 end)
        local state = newState()
        ActionEngine.execute(state, "loan", "White", {})
        expect(fired).toBe(1)
    end)

    it("does not fire when the action fails validation", function()
        resetEngine()
        local fired = 0
        ActionEngine.setPostCommitHook(function() fired = fired + 1 end)
        local state = newState()
        -- Scout needs >= 3 cards; default handSize 0 -> fails
        local result = ActionEngine.execute(state, "scout", "White", {})
        expect(result.success).toBeFalse()
        expect(fired).toBe(0)
    end)

    it("receives the post-action state", function()
        resetEngine()
        local seenMoney
        ActionEngine.setPostCommitHook(function(state)
            seenMoney = GameState.getPlayer(state, "White").money
        end)
        local state = newState()
        ActionEngine.execute(state, "loan", "White", {})
        expect(seenMoney).toBe(47)  -- hook sees the money AFTER the loan
    end)
end)

-- ============================================================
-- Last-commit record (undo basis)
-- ============================================================

describe("ActionEngine - last commit record", function()
    it("stores the committed action and clears on demand", function()
        resetEngine()
        local state = newState()
        ActionEngine.execute(state, "loan", "White", {})
        local record = ActionEngine.getLastCommit()
        expect(record.action).toBe("loan")
        expect(record.color).toBe("White")
        expect(record.snapshot.players["White"].money).toBe(17)
        ActionEngine.clearLastCommit()
        expect(ActionEngine.getLastCommit()).toBeNil()
    end)

    it("commit() finalises an externally-executed action and fires the hook once", function()
        resetEngine()
        local fired = 0
        ActionEngine.setPostCommitHook(function() fired = fired + 1 end)
        local state = newState()
        -- Simulate the interactive build path: snapshot, mutate, then commit.
        local snap = ActionEngine.beginAction(state)
        GameState.spendMoney(state, "White", 5)
        ActionEngine.commit(state, { action = "build", color = "White", snapshot = snap })
        expect(fired).toBe(1)
        expect(ActionEngine.getLastCommit().action).toBe("build")
    end)
end)

-- ============================================================
-- Behavioural equivalence
-- ============================================================

describe("ActionEngine - behavioural equivalence", function()
    it("routing network through the engine equals calling Actions directly", function()
        resetEngine()
        local direct = newState()
        Actions.network(direct, "White", { linkId = "Birmingham-Dudley" })

        local viaEngine = newState()
        ActionEngine.execute(viaEngine, "network", "White", { linkId = "Birmingham-Dudley" })

        expect(deepEqual(direct, viaEngine)).toBeTrue()
    end)

    it("routing sell through the engine equals calling Actions directly", function()
        resetEngine()
        local function setup()
            local state = newState()
            local slot = GameState.getSlot(state, "Wolverhampton_1")
            slot.occupant = "White"
            slot.tile = {
                type = Constants.Industry.MANUFACTURER, level = 1, flipped = false,
                resources = {}, beerToSell = 0, incomeSpaces = 1,
            }
            state.board.links["Shrewsbury-Wolverhampton"].owner = "White"
            return state
        end
        local direct = setup()
        Actions.sell(direct, "White", { slotIds = { "Wolverhampton_1" } })

        local viaEngine = setup()
        ActionEngine.execute(viaEngine, "sell", "White", { slotIds = { "Wolverhampton_1" } })

        expect(deepEqual(direct, viaEngine)).toBeTrue()
    end)
end)
