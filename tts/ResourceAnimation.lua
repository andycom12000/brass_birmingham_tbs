--- ResourceAnimation.lua
-- Handles smooth movement animations for coal/iron cubes.
-- All spawned cubes are locked and non-interactable.

local ResourceAnimation = {}

ResourceAnimation.MOVE_INTERVAL = 0.4
ResourceAnimation.MOVE_DURATION = 0.6
ResourceAnimation.ARRIVE_BUFFER = 0.1

--- Play a sequence of cube movement animations.
--- Each move is staggered by MOVE_INTERVAL seconds.
--- Sets state._animating = true at start, false when all complete.
--- @param moves table  array of { guid=string, targetPos=Vector, destroyAfter=bool }
--- @param onComplete function  called after all animations finish (may be nil)
function ResourceAnimation.play(moves, onComplete)
    if #moves == 0 then
        if onComplete then onComplete() end
        return
    end

    if state then state._animating = true end

    for i, move in ipairs(moves) do
        Wait.time(function()
            local obj = getObjectFromGUID(move.guid)
            if not obj then return end

            obj.setLock(false)
            obj.setPositionSmooth(move.targetPos, false, false)

            Wait.time(function()
                local o = getObjectFromGUID(move.guid)
                if not o then return end
                if move.destroyAfter then
                    o.destruct()
                else
                    o.setLock(true)
                end
            end, ResourceAnimation.MOVE_DURATION)
        end, (i - 1) * ResourceAnimation.MOVE_INTERVAL)
    end

    local totalTime = (#moves - 1) * ResourceAnimation.MOVE_INTERVAL
                    + ResourceAnimation.MOVE_DURATION
                    + ResourceAnimation.ARRIVE_BUFFER
    Wait.time(function()
        if state then state._animating = false end
        if onComplete then onComplete() end
    end, math.max(totalTime, 0.1))
end

--- Spawn a locked, non-interactable resource cube at a position.
--- @param resourceType string  Constants.Resource.COAL or Constants.Resource.IRON
--- @param position Vector  TTS world position
--- @param onSpawned function(obj)  callback with the spawned object (may be nil)
function ResourceAnimation.spawnCube(resourceType, position, onSpawned)
    ObjectManager.spawnResource(resourceType, position, function(obj)
        if obj then
            obj.setLock(true)
            obj.interactable = false
            obj.setGMNotes(JSON.encode({
                type = "resource",
                resource = resourceType,
            }))
            if onSpawned then
                onSpawned(obj)
            end
        end
    end)
end

--- Spawn a cube at fromPos, then smooth-move it to toPos. Locked on arrival.
--- @param resourceType string  Constants.Resource.COAL or Constants.Resource.IRON
--- @param fromPos Vector  spawn position
--- @param toPos Vector  destination position
--- @param onArrived function(obj)  callback when cube reaches destination (may be nil)
function ResourceAnimation.spawnAndMoveCube(resourceType, fromPos, toPos, onArrived)
    ResourceAnimation.spawnCube(resourceType, fromPos, function(obj)
        if not obj then return end
        obj.setLock(false)
        obj.setPositionSmooth(toPos, false, false)
        Wait.time(function()
            if obj and not obj.isDestroyed() then
                obj.setLock(true)
            end
            if onArrived then onArrived(obj) end
        end, ResourceAnimation.MOVE_DURATION)
    end)
end

return ResourceAnimation
