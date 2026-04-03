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
    local btnText = (lang == "zh-TW") and "結束回合" or "End Turn"
    UI.setAttribute("endTurnBtn", "text", btnText)
end

--- Show the action button panel (after a card is played).
function UIManager.showActionPanel()
    UI.setAttribute("actionPanel", "active", "true")
end

--- Hide the action button panel.
function UIManager.hideActionPanel()
    UI.setAttribute("actionPanel", "active", "false")
end

--- Show the "Single Link" button during double rail flow.
function UIManager.showSingleLinkButton()
    UI.setAttribute("singleLinkBtn", "active", "true")
end

--- Hide the "Single Link" button.
function UIManager.hideSingleLinkButton()
    UI.setAttribute("singleLinkBtn", "active", "false")
end

--- Show the "Accept VP Loss" button during shortfall resolution.
function UIManager.showAcceptVPLossButton()
    UI.setAttribute("acceptVPLossBtn", "active", "true")
end

--- Hide the "Accept VP Loss" button.
function UIManager.hideAcceptVPLossButton()
    UI.setAttribute("acceptVPLossBtn", "active", "false")
end

return UIManager
