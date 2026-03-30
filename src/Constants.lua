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

return Constants
