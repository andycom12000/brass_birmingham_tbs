local UIManager = {}

function UIManager.updateSpendCounter(color, amount)
    UI.setAttribute("counterValue_" .. color, "text", "£" .. amount)
end

function UIManager.showTurnIndicator(text)
    UI.setAttribute("turnPanel", "active", "true")
    UI.setAttribute("turnText", "text", text)
end

function UIManager.hideTurnIndicator()
    UI.setAttribute("turnPanel", "active", "false")
end

function UIManager.showEndTurnButton()
    UI.setAttribute("endTurnBtn", "active", "true")
end

function UIManager.hideEndTurnButton()
    UI.setAttribute("endTurnBtn", "active", "false")
end

function UIManager.showSetup()
    UI.setAttribute("setupPanel", "active", "true")
end

function UIManager.hideSetup()
    UI.setAttribute("setupPanel", "active", "false")
end

function UIManager.resetAllCounters(turnOrder)
    for _, color in ipairs(turnOrder) do
        UIManager.updateSpendCounter(color, 0)
    end
end

function UIManager.configureForPlayerCount(playerCount)
    local allColors = { "Red", "Blue", "Yellow", "Green" }
    for i, color in ipairs(allColors) do
        UI.setAttribute("counterPanel_" .. color, "active", tostring(i <= playerCount))
    end
end

function UIManager.updateLanguage(lang)
    local label = (lang == "zh-TW") and "本回合花費" or "Spent"
    local btnText = (lang == "zh-TW") and "回合結束" or "End Turn"
    for _, color in ipairs({"Red", "Blue", "Yellow", "Green"}) do
        UI.setAttribute("counterLabel_" .. color, "text", label)
    end
    UI.setAttribute("endTurnBtn", "text", btnText)
end

return UIManager
