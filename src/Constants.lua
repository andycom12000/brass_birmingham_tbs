local Constants = {}

Constants.Era = { CANAL = "canal", RAIL = "rail" }

Constants.Color = { RED = "Red", BLUE = "Blue", YELLOW = "Yellow", GREEN = "Green" }
Constants.ALL_COLORS = { "Red", "Blue", "Yellow", "Green" }

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

return Constants
