local UIManager = {}

-- updateSpendCounter: no-op — spend tracking now handled by on-board Counter objects
-- that sync to money counters via Global.onSpendChanged.
function UIManager.updateSpendCounter(color, amount)
    -- Physical spend trackers on the board handle display; nothing to do here.
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

-- resetAllCounters: no-op — physical spend counters reset manually or via game logic.
function UIManager.resetAllCounters(turnOrder)
    -- Physical counters on the board; nothing to reset via XML UI.
end

-- configureForPlayerCount: no-op — counter panels removed from XML UI.
function UIManager.configureForPlayerCount(playerCount)
    -- Counter panels removed; physical on-board counters are always visible.
end

function UIManager.updateLanguage(lang)
    local btnText = (lang == "zh-TW") and "End Turn" or "End Turn"
    UI.setAttribute("endTurnBtn", "text", btnText)
end

return UIManager
