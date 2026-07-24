local Lang = {}

-- English string table
Lang.strings = {
    en = {
        -- Game lifecycle
        game_loaded = "Game loaded",
        game_started = "Game started ({count} players)",

        -- Turn/Round management
        your_turn = "Your turn",
        round_N = "Round {round}",
        canal_era = "Canal Era",
        rail_era = "Rail Era",
        actions_remaining = "{count} action(s) remaining",

        -- Actions
        action_build = "Build",
        action_network = "Network",
        action_develop = "Develop",
        action_sell = "Sell",
        action_loan = "Loan",
        action_scout = "Scout",
        -- UI buttons
        btn_end_turn = "End Turn",
        btn_sell = "Sell",
        btn_develop1 = "Develop 1",
        btn_develop2 = "Develop 2",
        btn_loan = "Loan",
        btn_scout = "Scout",
        btn_single_link = "Single Link Only",
        btn_accept_vp_loss = "Accept VP Loss",
        btn_undo = "Undo",

        -- Game events
        player_spent = "{player} spent £{amount}",
        player_built = "{player} built {industry} Lv{level} in {city}",
        player_linked = "{player} linked {city1} — {city2}",
        player_sold = "{player} sold {industry} in {city}",
        player_loaned = "{player} took a loan (£30, income -3)",
        player_scouted = "{player} scouted",
        player_developed = "{player} developed {count} tile(s)",
        scout_discard_prompt = "Scout: discard 2 cards from your hand.",
        scout_discard_progress = "Discarded {current}/{total} cards.",
        develop_trash_prompt = "Drop {count} tile(s) onto the trash marker to develop.",
        develop_trash_progress = "Tiles received: {current}/{total}.",

        -- Income
        income_collected = "{player} collected £{amount} income",
        income_paid = "{player} paid £{amount} (negative income)",
        income_shortfall = "{player} lost {vp} VP from income shortfall",

        -- Shortfall tile removal
        shortfall_owe = "{player} owes £{amount} — remove tiles or accept VP loss",
        shortfall_removed = "{player} removed a tile (refund £{refund}, remaining debt: £{remaining})",
        shortfall_vp_loss = "{player} accepted {vp} VP loss",
        shortfall_no_tiles = "{player} lost {vp} VP (no tiles to remove)",

        -- Scoring
        scoring_start = "Scoring...",
        building_vp = "Building VP: {vp}",
        link_vp = "Link VP: {vp}",
        income_vp = "Income VP: {vp}",
        total_vp = "Total: {vp} VP",
        winner = "{player} wins!",
        tie = "Shared victory!",

        -- Era transition
        era_transition = "Era transition: Canal → Rail",
        removing_canals = "Removing canal links...",
        removing_lv1 = "Removing Level 1 buildings...",

        -- Errors/Validation
        invalid_action = "Invalid action",
        not_enough_money = "Not enough money",
        not_in_network = "Not in your network",
        slot_occupied = "Slot already occupied",
        no_beer = "Not enough beer",
        cannot_develop = "Cannot develop this tile",
        cannot_loan = "Income too low for loan",
        cannot_scout = "Cannot scout (already holding wild cards)",
        card_unrecognized = "Unrecognized card — the build pipeline did not tag this card. Returned to your hand; no action taken.",

        -- Industry names (for display)
        industry_cotton = "Cotton Mill",
        industry_coal = "Coal Mine",
        industry_iron = "Iron Works",
        industry_brewery = "Brewery",
        industry_manufacturer = "Manufacturer",
        industry_pottery = "Pottery",
    },

    -- Traditional Chinese Taiwan
    ["zh-TW"] = {
        -- Game lifecycle
        game_loaded = "遊戲已載入",
        game_started = "遊戲開始（{count} 位玩家）",

        -- Turn/Round management
        your_turn = "輪到你的回合",
        round_N = "第 {round} 回合",
        canal_era = "運河時代",
        rail_era = "鐵路時代",
        actions_remaining = "剩餘 {count} 個行動",

        -- Actions
        action_build = "建造",
        action_network = "建立連結",
        action_develop = "升級科技",
        action_sell = "銷售",
        action_loan = "貸款",
        action_scout = "偵查",
        -- UI buttons
        btn_end_turn = "結束回合",
        btn_sell = "賣貨",
        btn_develop1 = "研發 1",
        btn_develop2 = "研發 2",
        btn_loan = "貸款",
        btn_scout = "偵察",
        btn_single_link = "僅建單條路線",
        btn_accept_vp_loss = "接受扣分",
        btn_undo = "復原",

        -- Game events
        player_spent = "{player} 花費了 £{amount}",
        player_built = "{player} 在 {city} 建造了 {industry} Lv{level}",
        player_linked = "{player} 連結了 {city1} — {city2}",
        player_sold = "{player} 在 {city} 銷售了 {industry}",
        player_loaned = "{player} 進行了貸款（£30，收入 -3）",
        player_scouted = "{player} 進行了偵查",
        player_developed = "{player} 升級了 {count} 張科技",
        scout_discard_prompt = "偵查：請從手中棄掉 2 張牌。",
        scout_discard_progress = "已棄 {current}/{total} 張牌。",
        develop_trash_prompt = "請將 {count} 張板塊拖到垃圾桶來進行升級。",
        develop_trash_progress = "已接收板塊：{current}/{total}。",

        -- Income
        income_collected = "{player} 收取了 £{amount} 收入",
        income_paid = "{player} 支付了 £{amount}（負收入）",
        income_shortfall = "{player} 因收入不足損失了 {vp} VP",

        -- Shortfall tile removal
        shortfall_owe = "{player} 欠 £{amount} — 移除磚塊或接受 VP 損失",
        shortfall_removed = "{player} 移除了磚塊（退款 £{refund}，剩餘債務：£{remaining}）",
        shortfall_vp_loss = "{player} 接受了 {vp} VP 損失",
        shortfall_no_tiles = "{player} 損失了 {vp} VP（沒有可移除的磚塊）",

        -- Scoring
        scoring_start = "計分中...",
        building_vp = "建築分數：{vp}",
        link_vp = "連結分數：{vp}",
        income_vp = "收入分數：{vp}",
        total_vp = "總分：{vp} 分",
        winner = "{player} 獲勝！",
        tie = "共同勝利！",

        -- Era transition
        era_transition = "時代轉換：運河 → 鐵路",
        removing_canals = "移除運河連結...",
        removing_lv1 = "移除等級 1 建築...",

        -- Errors/Validation
        invalid_action = "無效行動",
        not_enough_money = "金錢不足",
        not_in_network = "不在你的網路中",
        slot_occupied = "格位已被佔用",
        no_beer = "啤酒不足",
        cannot_develop = "無法升級此科技",
        cannot_loan = "收入太低無法貸款",
        cannot_scout = "無法偵查（已持有萬用卡）",
        card_unrecognized = "無法辨識的卡牌 — 建置流程未標記此卡。已退回你的手牌，未執行任何行動。",

        -- Industry names (for display)
        industry_cotton = "棉花廠",
        industry_coal = "煤礦",
        industry_iron = "鐵工廠",
        industry_brewery = "釀酒廠",
        industry_manufacturer = "製造廠",
        industry_pottery = "陶瓷廠",
    },
}

-- Get a localized string
-- locale: "en" or "zh-TW"
function Lang.get(key, locale)
    local strings = Lang.strings[locale] or Lang.strings["en"]
    return strings[key] or Lang.strings["en"][key] or ("?" .. key .. "?")
end

-- Format a localized string with parameter substitution
-- params: { player = "Red", amount = 15 }
-- Template uses {key} syntax: "Player {player} spent £{amount}"
function Lang.format(key, locale, params)
    local str = Lang.get(key, locale)
    if params then
        for k, v in pairs(params) do
            str = str:gsub("{" .. k .. "}", tostring(v))
        end
    end
    return str
end

return Lang
