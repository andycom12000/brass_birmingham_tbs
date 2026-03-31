local UIManager = {}

--[[
    UIManager module for handling all UI updates and interactions.
    Manages spend counters, turn indicators, setup panels, and language settings.
]]

-- Updates the spend counter for a given player color
-- @param color string: Player color (Red, Blue, Yellow, Green)
-- @param amount number: Amount spent (in pounds)
function UIManager.updateSpendCounter(color, amount)
    UI.setAttribute("counterValue_" .. color, "text", "£" .. amount)
end

-- Shows the turn indicator with specified text
-- @param text string: Text to display in the turn indicator
function UIManager.showTurnIndicator(text)
    UI.setAttribute("turnPanel", "active", "true")
    UI.setAttribute("turnText", "text", text)
end

-- Hides the turn indicator
function UIManager.hideTurnIndicator()
    UI.setAttribute("turnPanel", "active", "false")
end

-- Shows the setup panel (player selection at game start)
function UIManager.showSetup()
    UI.setAttribute("setupPanel", "active", "true")
end

-- Hides the setup panel (after game configuration)
function UIManager.hideSetup()
    UI.setAttribute("setupPanel", "active", "false")
end

-- Resets all spend counters to zero
-- @param turnOrder table: Ordered list of player colors in game
function UIManager.resetAllCounters(turnOrder)
    for _, color in ipairs(turnOrder) do
        UIManager.updateSpendCounter(color, 0)
    end
end

-- Configures counter panel visibility based on player count
-- Activates only the panels for players in the game
-- @param playerCount number: Number of players (2, 3, or 4)
function UIManager.configureForPlayerCount(playerCount)
    local allColors = { "Red", "Blue", "Yellow", "Green" }
    for i, color in ipairs(allColors) do
        UI.setAttribute("counterPanel_" .. color, "active", tostring(i <= playerCount))
    end
end

-- Updates UI language for all labels
-- @param lang string: Language code ("en-US" for English, "zh-TW" for Traditional Chinese)
function UIManager.updateLanguage(lang)
    local label = (lang == "zh-TW") and "本回合花費" or "Spent this round"
    for _, color in ipairs({"Red", "Blue", "Yellow", "Green"}) do
        UI.setAttribute("counterLabel_" .. color, "text", label)
    end
end

return UIManager
