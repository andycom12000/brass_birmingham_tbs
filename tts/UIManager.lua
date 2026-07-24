local UIManager = {}

-- Per-player UI elements: action buttons visible only to the current player.
-- The action buttons live inside actionPanel, so restricting the panel's
-- visibility restricts the whole group. Turn indicator and language toggle
-- are intentionally excluded (they stay visible to every seat).
UIManager.ACTION_OWNED_IDS = { "actionPanel", "endTurnBtn", "singleLinkBtn", "acceptVPLossBtn" }

--- Force-load the XML UI from Lua with current language.
function UIManager.initXmlUI()
    local lang = UIManager._currentLang or (state and state.lang) or "en"
    local L = function(key) return Lang.get(key, lang) end

    -- Bake the current action owner's per-player visibility into the markup so
    -- it survives a full XML rebuild (e.g. a language toggle). An empty owner
    -- leaves the elements global until the first turn is broadcast.
    local owner = UIManager._actionOwner
    local vis = owner and (' visibility="' .. owner .. '"') or ''

    local xml = '<Defaults>'
        .. '<Button fontSize="14" fontStyle="Bold" textColor="#FFFFFF"/>'
        .. '</Defaults>'

        .. '<Panel id="turnPanel" rectAlignment="UpperCenter" offsetXY="0 -50"'
        .. ' width="400" height="36" color="#1A1A2EE0">'
        .. '<Text id="turnText" text="" fontSize="15" color="#FFFFFF"'
        .. ' rectAlignment="MiddleCenter"/>'
        .. '</Panel>'

        .. '<Button id="endTurnBtn" onClick="onEndTurn"' .. vis
        .. ' rectAlignment="UpperCenter" offsetXY="0 -90"'
        .. ' width="160" height="42" fontSize="17"'
        .. ' color="#8B2500" textColor="#FFD700" text="' .. L("btn_end_turn") .. '"/>'

        .. '<Panel id="actionPanel"' .. vis .. ' rectAlignment="UpperCenter" offsetXY="0 -138"'
        .. ' width="520" height="48" color="#1A1A2EE0">'
        .. '<HorizontalLayout spacing="6" padding="4 4 4 4"'
        .. ' rectAlignment="MiddleCenter">'
        .. '<Button id="sellBtn" onClick="onSellBtn"'
        .. ' preferredWidth="90" preferredHeight="38"'
        .. ' color="#4A7C59" textColor="#FFFFFF" fontSize="14" text="' .. L("btn_sell") .. '"/>'
        .. '<Button id="develop1Btn" onClick="onDevelop1Btn"'
        .. ' preferredWidth="105" preferredHeight="38"'
        .. ' color="#5B6A8A" textColor="#FFFFFF" fontSize="13" text="' .. L("btn_develop1") .. '"/>'
        .. '<Button id="develop2Btn" onClick="onDevelop2Btn"'
        .. ' preferredWidth="105" preferredHeight="38"'
        .. ' color="#5B6A8A" textColor="#FFFFFF" fontSize="13" text="' .. L("btn_develop2") .. '"/>'
        .. '<Button id="loanBtn" onClick="onLoanBtn"'
        .. ' preferredWidth="90" preferredHeight="38"'
        .. ' color="#8B6914" textColor="#FFFFFF" fontSize="14" text="' .. L("btn_loan") .. '"/>'
        .. '<Button id="scoutBtn" onClick="onScoutBtn"'
        .. ' preferredWidth="90" preferredHeight="38"'
        .. ' color="#6B4C8A" textColor="#FFFFFF" fontSize="14" text="' .. L("btn_scout") .. '"/>'
        .. '</HorizontalLayout>'
        .. '</Panel>'

        .. '<Button id="singleLinkBtn" onClick="onSingleLinkOnly"' .. vis
        .. ' rectAlignment="UpperCenter" offsetXY="0 -190"'
        .. ' width="200" height="38" fontSize="14"'
        .. ' color="#2E5090" textColor="#FFFFFF" text="' .. L("btn_single_link") .. '"/>'

        .. '<Button id="acceptVPLossBtn" onClick="onAcceptVPLossBtn"' .. vis
        .. ' rectAlignment="UpperCenter" offsetXY="0 -190"'
        .. ' width="220" height="38" fontSize="14"'
        .. ' color="#8B2500" textColor="#FFFFFF" text="' .. L("btn_accept_vp_loss") .. '"/>'

        .. '<Button id="langToggle" onClick="toggleLanguage"'
        .. ' rectAlignment="LowerLeft" offsetXY="15 15"'
        .. ' width="80" height="28" fontSize="11"'
        .. ' color="#8B7355" textColor="#D4C5A0" text="EN / ZH"/>'

    UI.setXml(xml)
end

-- updateSpendCounter: no-op — spend tracking now handled by on-board Counter objects
-- that sync to money counters via Global.onSpendChanged.
function UIManager.updateSpendCounter(color, amount)
    -- Physical spend trackers on the board handle display; nothing to do here.
end

function UIManager.showTurnIndicator(text)
    UI.show("turnPanel")
    UI.setAttribute("turnText", "text", text)
end

function UIManager.hideTurnIndicator()
    UI.hide("turnPanel")
end

function UIManager.showEndTurnButton()
    UI.show("endTurnBtn")
end

function UIManager.hideEndTurnButton()
    UI.hide("endTurnBtn")
end

function UIManager.showSetup()
    -- No-op: setup handled by physical crown buttons on the table
end

function UIManager.hideSetup()
    -- No-op: setup handled by physical crown buttons on the table
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
    -- Rebuild XML with translated text (UI.setAttribute unreliable after setXml).
    -- initXmlUI re-bakes the current action owner's visibility, so per-player
    -- restrictions survive the language toggle for every seat.
    UIManager._currentLang = lang
    UIManager.initXmlUI()
end

--- Restrict all per-player action controls to a single seat color, live
--- (no XML reload). Called on every turn change so buttons follow the current
--- player. The owner is also remembered so a later XML rebuild re-bakes it.
function UIManager.setActionOwner(color)
    UIManager._actionOwner = color
    if not color then return end
    for _, id in ipairs(UIManager.ACTION_OWNED_IDS) do
        UI.setAttribute(id, "visibility", color)
    end
end

--- Show the action button panel (after a card is played).
function UIManager.showActionPanel()
    UI.show("actionPanel")
end

--- Hide the action button panel.
function UIManager.hideActionPanel()
    UI.hide("actionPanel")
end

--- Show the "Single Link" button during double rail flow.
function UIManager.showSingleLinkButton()
    UI.show("singleLinkBtn")
end

--- Hide the "Single Link" button.
function UIManager.hideSingleLinkButton()
    UI.hide("singleLinkBtn")
end

--- Show the "Accept VP Loss" button during shortfall resolution.
function UIManager.showAcceptVPLossButton()
    UI.show("acceptVPLossBtn")
end

--- Hide the "Accept VP Loss" button.
function UIManager.hideAcceptVPLossButton()
    UI.hide("acceptVPLossBtn")
end

return UIManager
