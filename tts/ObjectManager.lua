local ObjectManager = {}

ObjectManager.guids = {
    mainBoard = nil,
    drawDeck = nil,
    discardZone = nil,
    playerBoards = {},     -- { ["Red"] = GUID, ... }
    playerHandZones = {},  -- { ["Red"] = GUID, ... }
    wildLocationSupply = nil,
    wildIndustrySupply = nil,
    languageToggle = nil,
    -- Resource infinite bags (hardcoded from reference mod)
    resourceBags = {
        coal = "bc1987",  -- 煤矿
        iron = "4d261e",  -- 钢铁
        beer = "4be839",  -- 酒桶
    },
    moneyBags = {},        -- { ["1"] = GUID, ["5"] = GUID, ["15"] = GUID }
}

--- Scan all objects on the table and identify them by Name
-- Expected object names:
--   "Main Board", "Draw Deck", "Discard Zone"
--   "Player Board Red", "Player Board Blue", etc.
--   "Hand Zone Red", "Hand Zone Blue", etc.
--   "Wild Location Supply", "Wild Industry Supply"
--   "Language Toggle"
--   "Coal Bag", "Iron Bag", "Beer Bag"
--   "Money 1 Bag", "Money 5 Bag", "Money 15 Bag"
function ObjectManager.scanTable()
    for _, obj in ipairs(getAllObjects()) do
        local name = obj.getName()
        if name == "Main Board" then
            ObjectManager.guids.mainBoard = obj.getGUID()
        elseif name == "Draw Deck" then
            ObjectManager.guids.drawDeck = obj.getGUID()
        elseif name == "Discard Zone" then
            ObjectManager.guids.discardZone = obj.getGUID()
        elseif name == "Wild Location Supply" then
            ObjectManager.guids.wildLocationSupply = obj.getGUID()
        elseif name == "Wild Industry Supply" then
            ObjectManager.guids.wildIndustrySupply = obj.getGUID()
        elseif name == "Language Toggle" then
            ObjectManager.guids.languageToggle = obj.getGUID()
        elseif (name == "Coal Bag" or name == "煤矿") and (obj.type == "Infinite" or obj.type == "Bag") then
            ObjectManager.guids.resourceBags.coal = obj.getGUID()
        elseif (name == "Iron Bag" or name == "钢铁") and (obj.type == "Infinite" or obj.type == "Bag") then
            ObjectManager.guids.resourceBags.iron = obj.getGUID()
        elseif (name == "Beer Bag" or name == "酒桶") and (obj.type == "Infinite" or obj.type == "Bag") then
            ObjectManager.guids.resourceBags.beer = obj.getGUID()
        elseif name == "Money 1 Bag" then
            ObjectManager.guids.moneyBags["1"] = obj.getGUID()
        elseif name == "Money 5 Bag" then
            ObjectManager.guids.moneyBags["5"] = obj.getGUID()
        elseif name == "Money 15 Bag" then
            ObjectManager.guids.moneyBags["15"] = obj.getGUID()
        else
            -- Check for player-specific objects
            for _, color in ipairs({"Red", "Blue", "Yellow", "Green"}) do
                if name == "Player Board " .. color then
                    ObjectManager.guids.playerBoards[color] = obj.getGUID()
                elseif name == "Hand Zone " .. color then
                    ObjectManager.guids.playerHandZones[color] = obj.getGUID()
                end
            end
        end
    end
end

--- Get an object by role name
function ObjectManager.getObject(role)
    local guid = ObjectManager.guids[role]
    if type(guid) == "string" then
        return getObjectFromGUID(guid)
    end
    return nil
end

--- Get a player board by color
function ObjectManager.getPlayerBoard(color)
    local guid = ObjectManager.guids.playerBoards[color]
    return guid and getObjectFromGUID(guid)
end

--- Spawn a resource from its infinite bag at the given position.
--- @param resourceType string  "coal", "iron", or "beer"
--- @param position Vector  where to spawn
--- @param callback function(obj)  optional callback when object is ready
--- @return TTS object or nil
function ObjectManager.spawnResource(resourceType, position, callback)
    local bagGUID = ObjectManager.guids.resourceBags[resourceType]
    if not bagGUID then
        if printToAll then printToAll("[WARN] No bag GUID for " .. tostring(resourceType)) end
        return nil
    end
    local bag = getObjectFromGUID(bagGUID)
    if not bag then
        if printToAll then printToAll("[WARN] Bag not found: " .. bagGUID) end
        return nil
    end
    local params = {
        position = position,
        smooth = false,
    }
    if callback then
        params.callback_function = callback
    end
    return bag.takeObject(params)
end

--- Spawn money from the appropriate bag at the given position
function ObjectManager.spawnMoney(denomination, position)
    local key = tostring(denomination)
    local bagGUID = ObjectManager.guids.moneyBags[key]
    if not bagGUID then return nil end
    local bag = getObjectFromGUID(bagGUID)
    if not bag then return nil end
    return bag.takeObject({ position = position })
end

--- Move an object to a position with optional rotation
function ObjectManager.moveTo(obj, position, rotation)
    if not obj then return end
    obj.setPositionSmooth(position)
    if rotation then obj.setRotationSmooth(rotation) end
end

--- Destroy an object
function ObjectManager.destroy(obj)
    if obj and not obj.isDestroyed() then obj.destruct() end
end

--- Lock an object
function ObjectManager.lock(obj)
    if obj then obj.setLock(true) end
end

--- Unlock an object
function ObjectManager.unlock(obj)
    if obj then obj.setLock(false) end
end

--- Save GUIDs for persistence
function ObjectManager.saveGUIDs()
    return ObjectManager.guids
end

--- Load saved GUIDs
function ObjectManager.loadGUIDs(savedGuids)
    if savedGuids then
        ObjectManager.guids = savedGuids
    end
end

return ObjectManager
