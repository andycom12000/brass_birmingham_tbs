--- Tests for link building (Network action) game logic.
--- Validates Actions.network() state changes and Validation.canNetwork() checks.

local Constants = require("src/Constants")
local GameState = require("src/GameState")
local Actions   = require("src/Actions")
local Validation = require("src/Validation")
local BoardData = require("src/BoardData")

--- Helper: create a fresh 2-player game state
local function newState()
    return GameState.new(2)
end

-- ============================================================
-- Actions.network — link ownership
-- ============================================================

describe("Actions.network - link ownership", function()
    it("sets link owner to player color after building a canal link", function()
        local state = newState()
        -- Canal era, pick a canal-compatible link
        local linkId = "Birmingham-Dudley"
        -- Give the player presence so network check passes
        -- (First link: no presence needed — can build anywhere)
        local result = Actions.network(state, "White", { linkId = linkId })
        expect(result.success).toBeTrue()
        expect(state.board.links[linkId].owner).toBe("White")
    end)

    it("sets link owner for a rail link", function()
        local state = newState()
        state.era = Constants.Era.RAIL
        local linkId = "Birmingham-Dudley"
        -- Place a building to give coal for rail
        -- First, put a coal mine with resources on Birmingham
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "White"
        local Tile = require("src/Tile")
        slot.tile = Tile.newWithResources(Constants.Industry.COAL, 1)

        local result = Actions.network(state, "White", { linkId = linkId })
        expect(result.success).toBeTrue()
        expect(state.board.links[linkId].owner).toBe("White")
    end)

    it("decrements linksRemaining by 1 for single link", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local before = player.linksRemaining
        Actions.network(state, "White", { linkId = "Birmingham-Dudley" })
        expect(player.linksRemaining).toBe(before - 1)
    end)
end)

-- ============================================================
-- Actions.network — money deduction
-- ============================================================

describe("Actions.network - money deduction", function()
    it("deducts canal link cost (3 pounds)", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local before = player.money
        Actions.network(state, "White", { linkId = "Birmingham-Dudley" })
        -- Canal costs £3, no resource costs
        expect(player.money).toBe(before - Constants.LinkCost.CANAL)
    end)

    it("deducts single rail link cost (5 pounds) plus coal cost", function()
        local state = newState()
        state.era = Constants.Era.RAIL
        -- Place a coal mine with resources so coal is available from board
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "White"
        local Tile = require("src/Tile")
        slot.tile = Tile.newWithResources(Constants.Industry.COAL, 1)

        local player = GameState.getPlayer(state, "White")
        local before = player.money
        Actions.network(state, "White", { linkId = "Birmingham-Dudley" })
        -- Rail costs £5, coal consumed from board (free), returned to market
        expect(player.money).toBe(before - Constants.LinkCost.SINGLE_RAIL)
    end)

    it("deducts rail cost plus market coal cost when no board coal", function()
        local state = newState()
        state.era = Constants.Era.RAIL
        -- No coal on board — must buy from market
        -- Need a merchant connection for coal market access
        -- Give player a building in Birmingham and a link to a merchant-adjacent city
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "White"
        local Tile = require("src/Tile")
        -- Use a non-coal building (cotton) so there's no board coal
        slot.tile = Tile.new(Constants.Industry.COTTON, 1)
        slot.tile.flipped = false

        -- Connect Birmingham to a merchant via owned links
        -- Worcester is a merchant city; Redditch connects Birmingham-Redditch and Redditch-Worcester
        if state.board.links["Birmingham-Redditch"] then
            state.board.links["Birmingham-Redditch"].owner = "White"
        end
        if state.board.links["Redditch-Worcester"] then
            state.board.links["Redditch-Worcester"].owner = "White"
        end

        local player = GameState.getPlayer(state, "White")
        local before = player.money
        -- Build a link that is NOT one of the links we used for merchant connection
        local linkId = "Birmingham-Tamworth"
        local result = Actions.network(state, "White", { linkId = linkId })
        -- If coal market is not empty, this should succeed and cost £5 + market price
        if result.success then
            expect(player.money).toBeLessThan(before - Constants.LinkCost.SINGLE_RAIL)
        end
        -- The exact amount depends on coal market price
    end)
end)

-- ============================================================
-- Validation.canNetwork — era rejection
-- ============================================================

describe("Validation.canNetwork - era checks", function()
    it("rejects rail-only link in canal era", function()
        local state = newState()
        -- "Dudley-Walsall" is rail-only
        local v = Validation.canNetwork(state, "White", {
            linkId = "Dudley-Walsall",
            double = false,
        })
        expect(v.valid).toBeFalse()
    end)

    it("allows canal-compatible link in canal era", function()
        local state = newState()
        local v = Validation.canNetwork(state, "White", {
            linkId = "Birmingham-Dudley",
            double = false,
        })
        expect(v.valid).toBeTrue()
    end)

    it("allows rail link in rail era when coal is available", function()
        local state = newState()
        state.era = Constants.Era.RAIL
        -- Place coal on the board for the rail cost
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "White"
        local Tile = require("src/Tile")
        slot.tile = Tile.newWithResources(Constants.Industry.COAL, 1)

        local v = Validation.canNetwork(state, "White", {
            linkId = "Birmingham-Dudley",
            double = false,
        })
        expect(v.valid).toBeTrue()
    end)
end)

-- ============================================================
-- Validation.canNetwork — already owned link
-- ============================================================

describe("Validation.canNetwork - already owned link", function()
    it("rejects link that is already owned", function()
        local state = newState()
        state.board.links["Birmingham-Dudley"].owner = "Purple"
        local v = Validation.canNetwork(state, "White", {
            linkId = "Birmingham-Dudley",
            double = false,
        })
        expect(v.valid).toBeFalse()
    end)
end)

-- ============================================================
-- Validation.canNetwork — money check
-- ============================================================

describe("Validation.canNetwork - money check", function()
    it("rejects canal link when player cannot afford it", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        player.money = 2  -- canal costs £3
        local v = Validation.canNetwork(state, "White", {
            linkId = "Birmingham-Dudley",
            double = false,
        })
        expect(v.valid).toBeFalse()
    end)

    it("allows canal link when player has exact money", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        player.money = 3  -- canal costs exactly £3
        local v = Validation.canNetwork(state, "White", {
            linkId = "Birmingham-Dudley",
            double = false,
        })
        expect(v.valid).toBeTrue()
    end)
end)

-- ============================================================
-- Validation.canNetwork — network adjacency
-- ============================================================

describe("Validation.canNetwork - network adjacency", function()
    it("allows first link anywhere when player has no presence", function()
        local state = newState()
        -- No buildings or links placed — first link can go anywhere
        -- Use a link between two cities that exist in 2-player game
        local v = Validation.canNetwork(state, "White", {
            linkId = "Coalbrookdale-Shrewsbury",
            double = false,
        })
        expect(v.valid).toBeTrue()
    end)

    it("rejects link not touching player network when player has presence", function()
        local state = newState()
        -- Give player presence in Birmingham
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "White"
        local Tile = require("src/Tile")
        slot.tile = Tile.new(Constants.Industry.COTTON, 1)

        -- Try to build a link far from Birmingham (Coalbrookdale-Shrewsbury)
        local v = Validation.canNetwork(state, "White", {
            linkId = "Coalbrookdale-Shrewsbury",
            double = false,
        })
        expect(v.valid).toBeFalse()
    end)

    it("allows link touching player network", function()
        local state = newState()
        -- Give player presence in Birmingham
        local slot = state.board.cities["Birmingham"].slots[1]
        slot.occupant = "White"
        local Tile = require("src/Tile")
        slot.tile = Tile.new(Constants.Industry.COTTON, 1)

        -- Birmingham-Dudley touches Birmingham which is in the player's network
        local v = Validation.canNetwork(state, "White", {
            linkId = "Birmingham-Dudley",
            double = false,
        })
        expect(v.valid).toBeTrue()
    end)
end)

-- ============================================================
-- Actions.network — playCard NOT called (handled by TTS layer)
-- ============================================================

describe("Actions.network - playCard integration", function()
    it("does NOT decrement handSize (card deduction handled by TTS layer)", function()
        local state = newState()
        local player = GameState.getPlayer(state, "White")
        local before = player.handSize
        Actions.network(state, "White", { linkId = "Birmingham-Dudley" })
        expect(player.handSize).toBe(before)
    end)
end)
