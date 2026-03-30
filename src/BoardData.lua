local Constants = require("src/Constants")

local I = Constants.Industry
local E = Constants.Era

local BoardData = {}

-- ============================================================
-- 1. CITIES
-- ============================================================
-- Each city has an array of industry slots.
-- Merchant-only cities (no industry slots) are included for
-- completeness; their slots array is empty.

BoardData.cities = {
    Birmingham = {
        slots = {
            { id = "Birmingham_cotton_1",      type = I.COTTON },
            { id = "Birmingham_manufacturer_1", type = I.MANUFACTURER },
            { id = "Birmingham_iron_1",         type = I.IRON },
            { id = "Birmingham_manufacturer_2", type = I.MANUFACTURER },
        }
    },
    Coventry = {
        slots = {
            { id = "Coventry_pottery_1",      type = I.POTTERY },
            { id = "Coventry_manufacturer_1", type = I.MANUFACTURER },
        }
    },
    Dudley = {
        slots = {
            { id = "Dudley_coal_1", type = I.COAL },
            { id = "Dudley_iron_1", type = I.IRON },
        }
    },
    Kidderminster = {
        slots = {
            { id = "Kidderminster_cotton_1", type = I.COTTON },
            { id = "Kidderminster_cotton_2", type = I.COTTON },
        }
    },
    Wolverhampton = {
        slots = {
            { id = "Wolverhampton_manufacturer_1", type = I.MANUFACTURER },
            { id = "Wolverhampton_manufacturer_2", type = I.MANUFACTURER },
        }
    },
    Coalbrookdale = {
        slots = {
            { id = "Coalbrookdale_iron_1",    type = I.IRON },
            { id = "Coalbrookdale_iron_2",    type = I.IRON },
            { id = "Coalbrookdale_brewery_1", type = I.BREWERY },
        }
    },
    Nuneaton = {
        slots = {
            { id = "Nuneaton_manufacturer_1", type = I.MANUFACTURER },
            { id = "Nuneaton_cotton_1",       type = I.COTTON },
        }
    },
    Worcester = {
        slots = {
            { id = "Worcester_cotton_1", type = I.COTTON },
            { id = "Worcester_cotton_2", type = I.COTTON },
        }
    },
    Tamworth = {
        slots = {
            { id = "Tamworth_cotton_1", type = I.COTTON },
            { id = "Tamworth_coal_1",   type = I.COAL },
        }
    },
    Walsall = {
        slots = {
            { id = "Walsall_manufacturer_1", type = I.MANUFACTURER },
            { id = "Walsall_brewery_1",      type = I.BREWERY },
        }
    },
    Cannock = {
        slots = {
            { id = "Cannock_coal_1",         type = I.COAL },
            { id = "Cannock_manufacturer_1", type = I.MANUFACTURER },
        }
    },
    ["Burton-on-Trent"] = {
        slots = {
            { id = "Burton-on-Trent_brewery_1", type = I.BREWERY },
            { id = "Burton-on-Trent_brewery_2", type = I.BREWERY },
            { id = "Burton-on-Trent_coal_1",    type = I.COAL },
        }
    },
    Stafford = {
        slots = {
            { id = "Stafford_manufacturer_1", type = I.MANUFACTURER },
            { id = "Stafford_pottery_1",      type = I.POTTERY },
        }
    },
    ["Stoke-on-Trent"] = {
        slots = {
            { id = "Stoke-on-Trent_cotton_1",       type = I.COTTON },
            { id = "Stoke-on-Trent_manufacturer_1",  type = I.MANUFACTURER },
            { id = "Stoke-on-Trent_pottery_1",       type = I.POTTERY },
        }
    },
    Leek = {
        slots = {
            { id = "Leek_cotton_1",       type = I.COTTON },
            { id = "Leek_manufacturer_1", type = I.MANUFACTURER },
        }
    },
    Stone = {
        slots = {
            { id = "Stone_cotton_1",       type = I.COTTON },
            { id = "Stone_manufacturer_1", type = I.MANUFACTURER },
        }
    },
    Uttoxeter = {
        slots = {
            { id = "Uttoxeter_manufacturer_1", type = I.MANUFACTURER },
            { id = "Uttoxeter_brewery_1",      type = I.BREWERY },
        }
    },
    Belper = {
        slots = {
            { id = "Belper_cotton_1",       type = I.COTTON },
            { id = "Belper_manufacturer_1", type = I.MANUFACTURER },
            { id = "Belper_pottery_1",      type = I.POTTERY },
        }
    },
    Derby = {
        slots = {
            { id = "Derby_cotton_1",       type = I.COTTON },
            { id = "Derby_brewery_1",      type = I.BREWERY },
            { id = "Derby_manufacturer_1", type = I.MANUFACTURER },
        }
    },
    Redditch = {
        slots = {
            { id = "Redditch_coal_1", type = I.COAL },
            { id = "Redditch_iron_1", type = I.IRON },
        }
    },
    -- Merchant-only cities (no industry slots)
    Shrewsbury   = { slots = {} },
    Gloucester   = { slots = {} },
    Oxford       = { slots = {} },
    Warrington   = { slots = {} },
    Nottingham   = { slots = {} },
}

-- ============================================================
-- 2. LINKS
-- ============================================================
-- Keys are always in alphabetical order: "CityA-CityB" where A < B.
-- types lists which era(s) the route is available in.
--
-- Source: official Brass: Birmingham board (Roxley Games edition).

BoardData.links = {
    -- Birmingham connections
    ["Birmingham-Coventry"]        = { cities = { "Birmingham", "Coventry" },        types = { E.CANAL, E.RAIL } },
    ["Birmingham-Dudley"]          = { cities = { "Birmingham", "Dudley" },           types = { E.CANAL, E.RAIL } },
    ["Birmingham-Redditch"]        = { cities = { "Birmingham", "Redditch" },         types = { E.CANAL, E.RAIL } },
    ["Birmingham-Tamworth"]        = { cities = { "Birmingham", "Tamworth" },         types = { E.CANAL, E.RAIL } },
    ["Birmingham-Walsall"]         = { cities = { "Birmingham", "Walsall" },          types = { E.CANAL, E.RAIL } },
    ["Birmingham-Wolverhampton"]   = { cities = { "Birmingham", "Wolverhampton" },    types = { E.CANAL, E.RAIL } },
    ["Birmingham-Worcester"]       = { cities = { "Birmingham", "Worcester" },        types = { E.CANAL, E.RAIL } },

    -- Coventry connections
    ["Coventry-Nuneaton"]          = { cities = { "Coventry", "Nuneaton" },           types = { E.CANAL, E.RAIL } },
    ["Coventry-Oxford"]            = { cities = { "Coventry", "Oxford" },             types = { E.CANAL, E.RAIL } },

    -- Dudley connections
    ["Dudley-Kidderminster"]       = { cities = { "Dudley", "Kidderminster" },        types = { E.CANAL, E.RAIL } },
    ["Dudley-Wolverhampton"]       = { cities = { "Dudley", "Wolverhampton" },        types = { E.CANAL, E.RAIL } },
    ["Dudley-Walsall"]             = { cities = { "Dudley", "Walsall" },              types = { E.RAIL } },

    -- Kidderminster connections
    ["Kidderminster-Worcester"]    = { cities = { "Kidderminster", "Worcester" },     types = { E.CANAL, E.RAIL } },
    ["Coalbrookdale-Kidderminster"] = { cities = { "Coalbrookdale", "Kidderminster" }, types = { E.CANAL, E.RAIL } },

    -- Wolverhampton connections
    ["Cannock-Wolverhampton"]      = { cities = { "Cannock", "Wolverhampton" },       types = { E.CANAL, E.RAIL } },
    ["Shrewsbury-Wolverhampton"]   = { cities = { "Shrewsbury", "Wolverhampton" },    types = { E.CANAL, E.RAIL } },
    ["Coalbrookdale-Wolverhampton"] = { cities = { "Coalbrookdale", "Wolverhampton" }, types = { E.CANAL, E.RAIL } },

    -- Coalbrookdale connections
    ["Coalbrookdale-Shrewsbury"]   = { cities = { "Coalbrookdale", "Shrewsbury" },    types = { E.CANAL, E.RAIL } },

    -- Cannock connections
    ["Cannock-Walsall"]            = { cities = { "Cannock", "Walsall" },             types = { E.CANAL, E.RAIL } },
    ["Cannock-Stafford"]           = { cities = { "Cannock", "Stafford" },            types = { E.CANAL, E.RAIL } },
    ["Birmingham-Cannock"]         = { cities = { "Birmingham", "Cannock" },          types = { E.RAIL } },

    -- Burton-on-Trent connections
    ["Burton-on-Trent-Tamworth"]   = { cities = { "Burton-on-Trent", "Tamworth" },   types = { E.CANAL, E.RAIL } },
    ["Burton-on-Trent-Cannock"]    = { cities = { "Burton-on-Trent", "Cannock" },    types = { E.RAIL } },
    ["Burton-on-Trent-Uttoxeter"]  = { cities = { "Burton-on-Trent", "Uttoxeter" },  types = { E.CANAL, E.RAIL } },

    -- Tamworth connections
    ["Nuneaton-Tamworth"]          = { cities = { "Nuneaton", "Tamworth" },           types = { E.CANAL, E.RAIL } },

    -- Nuneaton connections
    ["Nottingham-Nuneaton"]        = { cities = { "Nottingham", "Nuneaton" },         types = { E.RAIL } },

    -- Stafford connections
    ["Stafford-Stone"]             = { cities = { "Stafford", "Stone" },              types = { E.CANAL, E.RAIL } },
    ["Stafford-Uttoxeter"]         = { cities = { "Stafford", "Uttoxeter" },          types = { E.RAIL } },

    -- Stoke-on-Trent connections
    ["Leek-Stoke-on-Trent"]        = { cities = { "Leek", "Stoke-on-Trent" },         types = { E.CANAL, E.RAIL } },
    ["Stoke-on-Trent-Stone"]       = { cities = { "Stone", "Stoke-on-Trent" },        types = { E.CANAL, E.RAIL } },
    ["Stoke-on-Trent-Warrington"]  = { cities = { "Stoke-on-Trent", "Warrington" },   types = { E.CANAL, E.RAIL } },
    ["Shrewsbury-Warrington"]      = { cities = { "Shrewsbury", "Warrington" },       types = { E.CANAL, E.RAIL } },

    -- Leek connections
    ["Leek-Uttoxeter"]             = { cities = { "Leek", "Uttoxeter" },              types = { E.RAIL } },

    -- Stone connections
    ["Stone-Uttoxeter"]            = { cities = { "Stone", "Uttoxeter" },             types = { E.CANAL, E.RAIL } },

    -- Uttoxeter connections
    ["Derby-Uttoxeter"]            = { cities = { "Derby", "Uttoxeter" },             types = { E.CANAL, E.RAIL } },

    -- Belper connections
    ["Belper-Derby"]               = { cities = { "Belper", "Derby" },                types = { E.CANAL, E.RAIL } },
    ["Belper-Leek"]                = { cities = { "Belper", "Leek" },                 types = { E.RAIL } },

    -- Derby connections
    ["Derby-Nottingham"]           = { cities = { "Derby", "Nottingham" },            types = { E.CANAL, E.RAIL } },
    ["Burton-on-Trent-Derby"]      = { cities = { "Burton-on-Trent", "Derby" },       types = { E.RAIL } },

    -- Redditch connections
    ["Gloucester-Redditch"]        = { cities = { "Gloucester", "Redditch" },         types = { E.CANAL, E.RAIL } },
    ["Oxford-Redditch"]            = { cities = { "Oxford", "Redditch" },             types = { E.CANAL, E.RAIL } },
    ["Redditch-Worcester"]         = { cities = { "Redditch", "Worcester" },          types = { E.CANAL, E.RAIL } },

    -- Worcester connections
    ["Gloucester-Worcester"]       = { cities = { "Gloucester", "Worcester" },        types = { E.CANAL, E.RAIL } },

    -- Walsall connections
    ["Walsall-Wolverhampton"]      = { cities = { "Walsall", "Wolverhampton" },       types = { E.RAIL } },
}

-- ============================================================
-- 3. MERCHANTS
-- ============================================================

BoardData.merchants = {
    { name = "Shrewsbury", slots = 1, minPlayers = 2, bonus = { type = "vp",             value = 4 } },
    { name = "Gloucester", slots = 2, minPlayers = 2, bonus = { type = "develop_free",   value = 1 } },
    { name = "Oxford",     slots = 2, minPlayers = 2, bonus = { type = "income_advance", value = 2 } },
    { name = "Warrington", slots = 2, minPlayers = 3, bonus = { type = "money",          value = 5 } },
    { name = "Nottingham", slots = 2, minPlayers = 4, bonus = { type = "vp",             value = 3 } },
}

-- O(1) lookup: merchantsByName["Shrewsbury"] => merchant entry
BoardData.merchantsByName = {}
for _, m in ipairs(BoardData.merchants) do
    BoardData.merchantsByName[m.name] = m
end

-- ============================================================
-- 4. ADJACENCY  (auto-built from links)
-- ============================================================
-- adjacency[cityName] = { linkId1, linkId2, ... }

BoardData.adjacency = {}
for linkId, link in pairs(BoardData.links) do
    for _, city in ipairs(link.cities) do
        if not BoardData.adjacency[city] then
            BoardData.adjacency[city] = {}
        end
        local adj = BoardData.adjacency[city]
        adj[#adj + 1] = linkId
    end
end

-- ============================================================
-- 5. MARKET TRACKS
-- ============================================================

BoardData.coalMarketTrack = { 1,1,2,2,3,3,4,4,5,5,6,7,8,8 }  -- 14 spaces
BoardData.ironMarketTrack = { 1,1,2,2,3,3,4,5,6,6 }           -- 10 spaces

-- ============================================================
-- 6. BUILDING COSTS
-- ============================================================
-- buildingCosts[industryType][level] = cost data
-- Fields present depend on industry type:
--   money, coal, iron, vp, incomeSpaces, linkIcons
--   beerToSell  (for sellable industries: cotton, manufacturer, pottery)
--   produces    (for auto-flip industries:  coal, iron, brewery)
--   railOnly    (optional flag)
--   noDevelop   (optional flag — pottery levels that cannot be developed past)
--   count       (tile count in the supply)

BoardData.buildingCosts = {

    [I.COTTON] = {
        [1] = { money=12, coal=0, iron=0, beerToSell=1, vp=5,  incomeSpaces=5, linkIcons=1, count=3 },
        [2] = { money=14, coal=1, iron=0, beerToSell=1, vp=5,  incomeSpaces=4, linkIcons=2, count=2 },
        [3] = { money=16, coal=1, iron=1, beerToSell=1, vp=9,  incomeSpaces=3, linkIcons=1, count=3 },
        [4] = { money=18, coal=1, iron=1, beerToSell=1, vp=12, incomeSpaces=2, linkIcons=1, count=3 },
    },

    [I.COAL] = {
        [1] = { money=5,  coal=0, iron=0, produces=2, vp=1, incomeSpaces=4, linkIcons=2, count=1 },
        [2] = { money=7,  coal=0, iron=0, produces=3, vp=2, incomeSpaces=7, linkIcons=1, count=2 },
        [3] = { money=8,  coal=0, iron=1, produces=4, vp=3, incomeSpaces=6, linkIcons=1, count=2 },
        [4] = { money=10, coal=0, iron=1, produces=5, vp=4, incomeSpaces=5, linkIcons=1, count=2 },
    },

    [I.IRON] = {
        [1] = { money=5,  coal=1, iron=0, produces=4, vp=3, incomeSpaces=3, linkIcons=1, count=1 },
        [2] = { money=7,  coal=1, iron=0, produces=4, vp=5, incomeSpaces=3, linkIcons=1, count=1 },
        [3] = { money=9,  coal=1, iron=0, produces=5, vp=7, incomeSpaces=2, linkIcons=1, count=1 },
        [4] = { money=12, coal=1, iron=0, produces=6, vp=9, incomeSpaces=1, linkIcons=1, count=1 },
    },

    [I.BREWERY] = {
        [1] = { money=5, coal=0, iron=1, produces=1, vp=4,  incomeSpaces=4, linkIcons=2, count=2 },
        [2] = { money=7, coal=0, iron=1, produces=1, vp=5,  incomeSpaces=5, linkIcons=2, count=2 },
        [3] = { money=9, coal=0, iron=1, produces=1, vp=7,  incomeSpaces=5, linkIcons=2, count=2 },
        [4] = { money=9, coal=0, iron=1, produces=2, vp=10, incomeSpaces=5, linkIcons=2, count=1, railOnly=true },
    },

    [I.MANUFACTURER] = {
        [1] = { money=8,  coal=1, iron=0, beerToSell=1, vp=3,  incomeSpaces=5, linkIcons=2, count=1 },
        [2] = { money=10, coal=0, iron=1, beerToSell=1, vp=5,  incomeSpaces=1, linkIcons=1, count=2 },
        [3] = { money=12, coal=2, iron=0, beerToSell=0, vp=4,  incomeSpaces=4, linkIcons=0, count=1 },
        [4] = { money=8,  coal=0, iron=1, beerToSell=1, vp=3,  incomeSpaces=6, linkIcons=1, count=1 },
        [5] = { money=16, coal=1, iron=0, beerToSell=2, vp=8,  incomeSpaces=2, linkIcons=2, count=2 },
        [6] = { money=20, coal=0, iron=0, beerToSell=1, vp=7,  incomeSpaces=6, linkIcons=1, count=1 },
        [7] = { money=16, coal=1, iron=1, beerToSell=0, vp=9,  incomeSpaces=4, linkIcons=0, count=1 },
        [8] = { money=20, coal=0, iron=2, beerToSell=1, vp=11, incomeSpaces=1, linkIcons=1, count=2 },
    },

    [I.POTTERY] = {
        -- noDevelop = cannot be developed past (must be built/overbuilt, not developed forward)
        [1] = { money=17, coal=0, iron=1, beerToSell=1, vp=10, incomeSpaces=5, linkIcons=1, count=1, noDevelop=true },
        [2] = { money=0,  coal=1, iron=0, beerToSell=1, vp=1,  incomeSpaces=1, linkIcons=1, count=1 },
        [3] = { money=22, coal=2, iron=0, beerToSell=2, vp=11, incomeSpaces=5, linkIcons=1, count=1, noDevelop=true },
        [4] = { money=0,  coal=1, iron=0, beerToSell=1, vp=1,  incomeSpaces=1, linkIcons=1, count=1 },
        [5] = { money=24, coal=2, iron=0, beerToSell=2, vp=20, incomeSpaces=5, linkIcons=1, count=1, railOnly=true },
    },
}

-- ============================================================
-- 7. PLAYER-COUNT CITY EXCLUSIONS
-- ============================================================

-- Teal cities: removed from play for 2-player AND 3-player games
BoardData.tealCities = { "Belper", "Derby" }

-- Blue cities: removed from play for 2-player games only
BoardData.blueCities = { "Leek", "Stoke-on-Trent", "Stone", "Uttoxeter" }

-- ============================================================
-- 8. FUNCTIONS
-- ============================================================

--- Returns the list of city names whose location cards are removed
--- for the given player count.
--- @param playerCount number  2, 3, or 4
--- @return table  array of city name strings
function BoardData.getRemovedCities(playerCount)
    local removed = {}
    if playerCount <= 3 then
        for _, c in ipairs(BoardData.tealCities) do
            removed[#removed + 1] = c
        end
    end
    if playerCount <= 2 then
        for _, c in ipairs(BoardData.blueCities) do
            removed[#removed + 1] = c
        end
    end
    return removed
end

--- Returns the list of active merchant entries for the given player count.
--- A merchant is active when playerCount >= merchant.minPlayers.
--- @param playerCount number  2, 3, or 4
--- @return table  array of merchant entry tables
function BoardData.getActiveMerchants(playerCount)
    local active = {}
    for _, m in ipairs(BoardData.merchants) do
        if playerCount >= m.minPlayers then
            active[#active + 1] = m
        end
    end
    return active
end

return BoardData
