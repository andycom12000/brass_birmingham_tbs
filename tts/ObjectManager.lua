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
    resourceBags = {},     -- { coal = GUID, iron = GUID, beer = GUID }
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
        elseif name == "Coal Bag" then
            ObjectManager.guids.resourceBags.coal = obj.getGUID()
        elseif name == "Iron Bag" then
            ObjectManager.guids.resourceBags.iron = obj.getGUID()
        elseif name == "Beer Bag" then
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

--- Spawn a resource from its bag at the given position
function ObjectManager.spawnResource(resourceType, position)
    local bagGUID = ObjectManager.guids.resourceBags[resourceType]
    if not bagGUID then return nil end
    local bag = getObjectFromGUID(bagGUID)
    if not bag then return nil end
    return bag.takeObject({ position = position })
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
