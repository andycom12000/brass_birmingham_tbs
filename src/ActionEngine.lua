local helpers    = require("src/helpers")
local GameState  = require("src/GameState")
local Actions    = require("src/Actions")

--- ActionEngine — the single commit seam for every player action.
---
--- Every action flows through one path: validate -> snapshot -> execute ->
--- commit -> post-commit hook. The snapshot is a pre-execution deep copy of
--- the logical game state (the basis for single-step undo, issue #9); the
--- post-commit hook is the single place live scoring (issues #10/#11) hangs
--- off. The TTS event layer is a thin translator that hands the engine an
--- action name plus params.
---
--- Two entry points exist because actions resolve differently:
---   * Atomic actions (network, sell, develop, loan, scout, pass) execute
---     synchronously via ActionEngine.execute().
---   * Build resolves interactively in the TTS layer (animated resource
---     consumption spread across drop events), so it snapshots up front with
---     beginAction() and finalises with commit() once fully resolved.
--- Both paths capture a pre-execution snapshot and fire the hook exactly once.
---
--- This module lives in the pure-logic tier and must stay free of TTS globals.

local ActionEngine = {}

-- Registry of synchronous executors. Each returns { success, error }.
-- Build is atomic in the pure tier, so it is registered here too; the TTS
-- layer still drives its interactive path via beginAction()/commit().
local EXECUTORS = {
    build   = function(state, color, params) return Actions.build(state, color, params) end,
    network = function(state, color, params) return Actions.network(state, color, params) end,
    sell    = function(state, color, params) return Actions.sell(state, color, params) end,
    develop = function(state, color, params) return Actions.develop(state, color, params) end,
    loan    = function(state, color, _params) return Actions.loan(state, color) end,
    scout   = function(state, color, _params) return Actions.scout(state, color) end,
    pass    = function(state, color, params) return Actions.pass(state, color, params) end,
}

-- Single post-commit hook and the last committed record (for single-step undo).
ActionEngine._postCommitHook = nil
ActionEngine._lastCommit     = nil

--- Register the (single) post-commit hook. Pass nil to clear it.
--- The hook is called as fn(state, record) after every committed action.
function ActionEngine.setPostCommitHook(fn)
    ActionEngine._postCommitHook = fn
end

--- Capture a pre-execution deep snapshot of the logical state.
function ActionEngine.beginAction(state)
    return helpers.deepCopy(state)
end

--- Return the last committed record ({ action, color, params, snapshot }),
--- or nil if nothing is committed / the commit has been cleared.
function ActionEngine.getLastCommit()
    return ActionEngine._lastCommit
end

--- Clear the last committed record — used to lock undo once the next player
--- begins acting or cards are dealt (issue #9).
function ActionEngine.clearLastCommit()
    ActionEngine._lastCommit = nil
end

--- Record a committed action and fire the post-commit hook exactly once.
--- `record` must carry at least { action, color, snapshot }; the snapshot is
--- the pre-execution state captured by beginAction() (or execute()).
--- Used directly by the interactive build path after it finishes resolving.
function ActionEngine.commit(state, record)
    ActionEngine._lastCommit = record
    if ActionEngine._postCommitHook then
        ActionEngine._postCommitHook(state, record)
    end
end

--- Execute a synchronous action end to end.
--- validate + execute happen inside the registered executor (each Actions.X
--- validates before mutating); the engine wraps them with a pre-execution
--- snapshot, and commits + fires the hook only on success. On failure nothing
--- is committed and the hook does not fire.
--- @return table result  { success, error }
function ActionEngine.execute(state, actionName, color, params)
    local executor = EXECUTORS[actionName]
    if not executor then
        return { success = false, error = "Unknown action: " .. tostring(actionName) }
    end

    local snapshot = ActionEngine.beginAction(state)
    local result   = executor(state, color, params or {})

    if not result or not result.success then
        -- Actions validate before mutating, so a failed action leaves the
        -- state untouched. No commit, no hook.
        return result or { success = false, error = "nil result from executor" }
    end

    ActionEngine.commit(state, {
        action   = actionName,
        color    = color,
        params   = params,
        snapshot = snapshot,
    })
    return result
end

--- Restore the live state, in place, from a pre-execution snapshot.
--- The state table identity is preserved (callers hold a reference to it):
--- every key is replaced with a deep copy of the snapshot's value, then the
--- flat slot/city indices are rebuilt so they alias the restored slot tables.
function ActionEngine.restore(state, snapshot)
    for k in pairs(state) do
        state[k] = nil
    end
    for k, v in pairs(snapshot) do
        state[k] = helpers.deepCopy(v)
    end
    GameState.rebuildIndices(state)
end

--- Undo the last committed action (single-step). Restores the logical state
--- from the commit's pre-execution snapshot, consumes the commit (so undo is
--- single-step and cannot be repeated), and fires the post-commit hook so live
--- scoring/projection recompute against the restored state.
--- @return table  { success, error, undone (action name), color }
function ActionEngine.undo(state)
    local record = ActionEngine._lastCommit
    if not record then
        return { success = false, error = "Nothing to undo" }
    end

    ActionEngine.restore(state, record.snapshot)
    ActionEngine._lastCommit = nil  -- single-step: the undo is consumed

    if ActionEngine._postCommitHook then
        ActionEngine._postCommitHook(state, {
            action = "undo",
            color  = record.color,
            undone = record.action,
        })
    end

    return { success = true, error = "", undone = record.action, color = record.color }
end

--- True when an undo is currently available (a commit is pending and unlocked).
function ActionEngine.canUndo()
    return ActionEngine._lastCommit ~= nil
end

return ActionEngine
