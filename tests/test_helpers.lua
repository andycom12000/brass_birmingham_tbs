--- Test helpers: factory functions for creating game state fixtures.

local GameState = require("src/GameState")
local Constants = require("src/Constants")

local TestHelpers = {}

--- Create a standard 2-player game state for testing.
--- @param overrides table  Optional overrides to apply after creation
--- @return table state
function TestHelpers.createTestState(overrides)
    local state = GameState.new(2)
    if overrides then
        for k, v in pairs(overrides) do
            state[k] = v
        end
    end
    return state
end

--- Create a state and set a specific player's attributes.
--- @param playerOverrides table  { money=50, incomeLevel=5, ... }
--- @param playerIndex number  1 or 2 (default 1)
--- @return table state, table player, string color
function TestHelpers.createStateWithPlayer(playerOverrides, playerIndex)
    local state = GameState.new(2)
    local idx = playerIndex or 1
    local color = state.turnOrder[idx]
    local player = GameState.getPlayer(state, color)
    if playerOverrides then
        for k, v in pairs(playerOverrides) do
            player[k] = v
        end
    end
    return state, player, color
end

--- Place a tile on a slot for testing.
--- @param state table  Game state
--- @param slotId string  Target slot
--- @param color string  Player color
--- @param tileOverrides table  { type, level, flipped, resources, ... }
function TestHelpers.placeTile(state, slotId, color, tileOverrides)
    local Tile = require("src/Tile")
    local slot = GameState.getSlot(state, slotId)
    if not slot then error("Slot not found: " .. tostring(slotId)) end
    slot.occupant = color
    local tile = Tile.new(tileOverrides.type or Constants.Industry.COTTON, tileOverrides.level or 1)
    for k, v in pairs(tileOverrides) do
        tile[k] = v
    end
    slot.tile = tile
end

--- Get the first player's color from a state.
function TestHelpers.firstColor(state)
    return state.turnOrder[1]
end

--- Get the second player's color from a state.
function TestHelpers.secondColor(state)
    return state.turnOrder[2]
end

return TestHelpers
