local Constants = {}

Constants.Era = { CANAL = "canal", RAIL = "rail" }

-- TTS seat colors in the reference mod (not the default Red/Blue/Green/Yellow)
Constants.Color = { WHITE = "White", PURPLE = "Purple", ORANGE = "Orange", YELLOW = "Yellow" }
Constants.ALL_COLORS = { "White", "Purple", "Orange", "Yellow" }

Constants.Industry = {
    COTTON = "cotton",
    COAL = "coal",
    IRON = "iron",
    BREWERY = "brewery",
    MANUFACTURER = "manufacturer",
    POTTERY = "pottery",
}

Constants.Resource = { COAL = "coal", IRON = "iron", BEER = "beer" }

Constants.CardType = { LOCATION = "location", INDUSTRY = "industry", WILD_LOCATION = "wild_location", WILD_INDUSTRY = "wild_industry" }

-- Industries that can be sold via Sell action
Constants.SELLABLE_INDUSTRIES = { "cotton", "manufacturer", "pottery" }

-- Industries that auto-flip (no sell needed)
Constants.AUTO_FLIP_INDUSTRIES = { "coal", "iron", "brewery" }

Constants.LinkCost = {
    CANAL = 3,
    SINGLE_RAIL = 5,
    DOUBLE_RAIL = 15,
}

Constants.LOAN_AMOUNT = 30
Constants.LOAN_INCOME_PENALTY = 3

Constants.INITIAL_MONEY = 17
Constants.INITIAL_INCOME = 10
Constants.INITIAL_LINKS = 14
Constants.INITIAL_HAND_SIZE = 8
Constants.INITIAL_COAL_SUPPLY = 13
Constants.INITIAL_IRON_SUPPLY = 8
Constants.WILD_SUPPLY_COUNT = 4

Constants.ObjectName = {
    -- Resource bags (infinite bags on table)
    COAL_BAG  = "Coal Bag",
    IRON_BAG  = "Iron Bag",
    BEER_BAG  = "Beer Bag",
    -- Resource cubes/tokens (Nickname on individual objects)
    COAL_CUBE = "Coal",
    IRON_CUBE = "Iron",
    BEER      = "Beer",
    -- Link tiles (prefix — matched with string.find)
    CANAL     = "Canal",
    RAIL      = "Rail",
    -- Other identifiable objects
    MAIN_BOARD           = "Main Board",
    DRAW_DECK            = "Draw Deck",
    DISCARD_ZONE         = "Discard Zone",
    WILD_LOCATION_SUPPLY = "Wild Location Supply",
    WILD_INDUSTRY_SUPPLY = "Wild Industry Supply",
    LANGUAGE_TOGGLE      = "Language Toggle",
}

return Constants
