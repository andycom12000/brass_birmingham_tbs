# Brass: Birmingham — Tabletop Simulator Mod 設計文件

## 1. 專案概述

### 目標
為 Tabletop Simulator (TTS) 設計一個 Brass: Birmingham（工業革命：伯明翰）Workshop Mod，忠實還原實體桌遊體驗，同時加入中度自動化功能提升線上遊戲流暢度。

### 設計原則
- **忠實還原**：視覺風格、元件設計盡量貼近原版桌遊
- **中度自動化**：合法行動提示、資源自動扣除、花費追蹤與回合順序自動排序
- **物件互動為主**：核心操作透過拿取、放置、翻轉桌上物件完成
- **多語言支援**：英文 / 繁體中文切換

### 範圍
- 支援 2-4 人標準遊戲
- 不含 Solo 模式（Automa）
- 不含重度自動化（無全自動行動執行引擎）

---

## 2. 桌面佈局（Table Layout）

### 整體配置

```
  [🟡 玩家 3] [計數器]              [計數器] [🟢 玩家 4]

                 ┌──────────────────┐  ┌────┐
                 │                  │  │ 🍺 │
                 │   主地圖板       │  │啤酒│
                 │  (Main Board)    │  ├────┤
                 │                  │  │ ⚫ │
                 │  含：地圖網路    │  │煤炭│
                 │      煤炭市場    │  ├────┤
                 │      鐵礦市場    │  │ 🟠 │
                 │      商人區      │  │鐵礦│
                 │      抽牌區      │  └────┘
                 │      計分軌      │  公共資源區
                 └──────────────────┘

  [🔴 玩家 1] [計數器]              [計數器] [🔵 玩家 2]
```

### 主地圖板
- 單一大型 Custom Tile，固定鎖定於桌面中央
- 高解析度貼圖，整合所有公共元素：地圖網路、煤炭/鐵礦市場、商人區、抽牌區/棄牌堆、計分軌/回合軌/收入軌
- 使用 Snap Points 定義所有放置位置

### 公共資源區
- 位於主地圖板**右側**（緊貼，非桌面最右邊）
- 三個供應堆上下並列：啤酒（Wild Beer）、煤炭（Coal Supply）、鐵礦（Iron Supply）
- 主地圖 + 公共資源區作為整體群組置中於桌面

### 玩家區域（四角）
每位玩家的區域包含：
- **玩家板**（Player Board）：各產業建築槽位
- **建築 Tile 堆**：依產業類型分疊
- **手牌區**
- **金錢區**
- **幫助卡**（Reference Card）
- **計數器**（花費顯示面板）

### 計數器
- 純顯示面板，**無按鈕**
- 顯示內容：本回合金錢花費總數（£）
- 腳本自動追蹤玩家行動花費並即時更新
- 每回合開始時自動歸零
- 邊框顏色對應玩家色

---

## 3. 元件系統（Components）

### 元件總覽

| 元件 | TTS 類型 | 數量 | 說明 |
|------|----------|------|------|
| 主地圖板 | Custom Tile (2D) | 1 | 含市場、商人區、計分軌、Snap Points |
| 工業建築 Tiles | Custom Tile (2D) | 每人 ~20 | 6 種產業，可翻面 |
| 連結 Tiles | Custom Tile (2D) | 每人 14 | 運河(藍) / 鐵路(灰) |
| 資源 Token | Custom Model (3D) | 煤炭 24 / 鐵礦 16 / 啤酒 20 | 煤炭球 / 鐵礦方塊 / 啤酒桶 |
| 卡牌 | Deck / Card | 地點卡 36 + 產業卡 20 + 萬用卡 4 = 60 | 依人數移除特定卡（見下方） |
| 金錢 | Custom Model (3D) | £1×30 / £5×24 / £15×16 | £1 銅幣 / £5 銀幣 / £15 金幣 |
| 商人 Tiles | Custom Tile (2D) | 12（2人用5/3人用7/4人用8） | 依人數隨機設置 |
| 玩家板 | Custom Tile (2D) | 4 | 各產業建築槽位 + Snap Points |
| 計數器 | XML UI | 4 | 本回合花費 £（純顯示） |
| 幫助卡 | Custom Tile (2D) | 4 | 正面英文 / 背面中文，翻面切換 |
| 規則說明書 | Custom PDF | 2 本 | 英文版 + 繁體中文版 |

### 工業建築 Tiles
6 種產業類型：
- **棉花廠（Cotton Mill）** — Lv 1-4
- **鐵工廠（Iron Works）** — Lv 1-4
- **煤礦（Coal Mine）** — Lv 1-4
- **釀酒廠（Brewery）** — Lv 1-4
- **製造廠（Manufacturer）** — Lv 1-8
- **陶瓷廠（Pottery）** — Lv 1-5

呈現方式：
- 2D Custom Tile，正面為建築圖片，背面為已翻面狀態
- 翻面代表建築已售出/已消耗完資源
- Tile 上的資源方塊（煤炭/鐵礦/啤酒）用 3D 小物件放在 Tile 上方
- 腳本追蹤每個 Tile 的等級、產業類型、擁有者、是否已翻面

### 連結 Tiles
- 運河（Canal）：藍色，僅用於運河時代
- 鐵路（Rail）：灰色，僅用於鐵路時代
- 每位玩家各 14 個，對應玩家顏色
- 時代轉換時腳本自動移除所有運河 Tile

### 資源 Token（3D）
- **煤炭**：黑色 3D 球體
- **鐵礦**：橘色 3D 方塊
- **啤酒**：金色 3D 小酒桶

### 卡牌
- 地點卡（Location）36 張、產業卡（Industry）20 張、萬用卡（Wild）4 張，共 60 張
- 使用 TTS 內建 Deck / Card 物件
- 正面貼圖顯示卡牌內容，背面統一花紋
- 支援自動洗牌、自動發牌
- **依人數移除卡牌**：
  - 2 人：移除 Belper、Derby、Stafford、Stone 相關的地點卡和對應連結
  - 3 人：移除 Belper、Derby 相關的地點卡和對應連結
  - 4 人：使用完整牌組

### 金錢（金屬幣）
- **£1 銅幣** — 小型，銅色金屬質感，3D Custom Model
- **£5 銀幣** — 中型，銀色金屬質感，3D Custom Model
- **£15 金幣** — 大型，金色金屬質感，3D Custom Model
- 三種面額大小遞增，方便目視區分
- 可堆疊，放在各玩家區域

### 幫助卡（Reference Card）
- 每位玩家 1 張，共 4 張
- 內容：行動一覽（6 種行動）、建造需求、銷售流程、計分規則、回合結構
- 正面英文 / 背面繁體中文，翻面即可切換語言
- 鎖定在玩家板旁邊

### 規則說明書（Rulebook）
- 使用 TTS Custom PDF 物件，呈現為可翻閱的實體書本
- 準備 2 本：英文版 + 繁體中文版
- 內容依照原版結構：
  1. 遊戲概述 Overview
  2. 元件說明 Components
  3. 遊戲設置 Setup
  4. 遊戲流程 Gameplay
  5. 行動詳解 Actions（Build / Network / Develop / Sell / Loan / Scout）
  6. 時代轉換 Era Transition
  7. 計分 Scoring
  8. 產業詳解 Industries
  9. 人數調整 Player Count
- 放置於桌面邊緣，玩家可拿起翻頁閱讀

---

## 4. Lua 腳本架構

### 架構：集中式 Global Script + require 模組化

```
Global.lua（進入點）
├── GameState.lua     — 遊戲狀態管理（玩家資料、回合、時代、分數）
├── Setup.lua         — 自動設置（依人數配置地圖、洗牌、發錢）
├── TurnManager.lua   — 回合流程、行動順序、花費追蹤、順序排序
├── Actions.lua       — 6 種行動邏輯（Build/Network/Develop/Sell/Loan/Scout）
├── Validation.lua    — 合法行動判斷、高亮提示可用位置
├── Market.lua        — 煤炭/鐵礦市場價格管理、資源購買
├── Scoring.lua       — 中期計分（運河時代結束）、終局計分
├── EraTransition.lua — 時代轉換（清除運河/Lv1 建築、重新洗牌）
├── SaveLoad.lua      — 序列化/反序列化遊戲狀態
├── Lang.lua          — 多語言文字管理（英文/繁體中文）
└── SnapMap.lua       — Snap Point GUID ↔ 遊戲邏輯位置映射
```

### GameState 核心資料結構

```lua
GameState = {
    era = "canal",              -- "canal" | "rail"
    round = 1,
    isFirstRound = true,        -- 首回合只有 1 個行動
    currentPlayerIdx = 1,
    actionsRemaining = 1,       -- 首回合 1，之後 2

    players = {
        ["Red"] = {
            money = 30,
            income = 10,         -- 收入等級（對應收入軌）
            vp = 0,
            spentThisRound = 0,
            linksRemaining = 14,
            -- 玩家板上尚未建造的建築 Tile
            unbuiltTiles = {
                { type = "cotton", level = 1, guid = "abc123" },
                { type = "cotton", level = 2, guid = "abc124" },
                -- ...
            },
        },
        -- Blue, Yellow, Green ...
    },

    turnOrder = { "Red", "Blue", "Yellow", "Green" },

    -- 地圖上已放置的建築
    board = {
        cities = {
            ["Birmingham"] = {
                slots = {
                    { id = "Birmingham_cotton_1", type = "cotton",
                      occupant = nil,       -- nil | "Red" | "Blue" ...
                      tile = nil,           -- nil | { type, level, flipped, guid, resources = {} }
                      snapGUID = "sp001",   -- 對應的 Snap Point GUID
                    },
                    { id = "Birmingham_iron_1", type = "iron",
                      occupant = nil, tile = nil, snapGUID = "sp002",
                    },
                    -- ...
                },
            },
            -- Coventry, Dudley, Walsall, ...
        },
        -- 地圖上已放置的連結
        links = {
            ["Birmingham-Coventry"] = {
                id = "Birmingham-Coventry",
                type = nil,         -- nil | "canal" | "rail"
                owner = nil,        -- nil | "Red" | "Blue" ...
                snapGUID = "sp100", -- 對應的 Snap Point GUID
                tileGUID = nil,     -- 放置的連結 Tile GUID
            },
            -- ...
        },
    },

    coalMarket = { supply = 13 },  -- 目前市場上的煤炭數量
    ironMarket = { supply = 8 },   -- 目前市場上的鐵礦數量

    -- 牌庫管理
    deck = {
        drawPileGUID = "deck001",
        discardPileGUID = "disc001",
    },

    lang = "en",  -- "en" | "zh-TW"
}
```

### Snap Point 與位置映射

所有遊戲位置透過 **Snap Point GUID** 與 GameState 雙向映射：

```lua
-- SnapMap.lua — Snap Point GUID ↔ 遊戲邏輯位置 對照表
-- 在 Setup 時掃描主地圖板上所有 Snap Points，依 tag 建立映射
SnapMap = {
    -- tag 格式: "city_Birmingham_cotton_1", "link_Birmingham-Coventry"
    byTag = {},    -- tag → Snap Point reference
    byGUID = {},   -- GUID → { locationType, locationId }
}
```

- 主地圖板上每個 Snap Point 設定 **tag**（如 `city_Birmingham_cotton_1`、`link_Birmingham-Coventry`）
- Setup 時掃描所有 Snap Points 並建立 `SnapMap`
- 腳本透過 tag 識別玩家放置物件的目標位置
- `onObjectDropped` 事件中比對 Snap Point → 查詢 GameState 對應格位 → 執行驗證

### 自動化功能

#### 自動設置（Setup）
- 依玩家人數調整地圖（移除城市/連結）
- 隨機抽取商人 Tiles 並放置
- 洗牌並發牌（8 張/人）
- 發放起始金額 £30
- 放置煤炭/鐵礦至市場
- 隨機決定起始玩家順序

#### 回合管理（TurnManager）
- 追蹤當前行動玩家
- 每回合 2 個行動，每個行動打 1 張牌
- **首回合例外**：每個時代的第一回合，每位玩家只執行 1 個行動（運河時代第一回合 + 鐵路時代第一回合皆適用）
- 自動累計花費金額至計數器
- 回合結束自動補牌
- 全部玩家完成後依花費**由低到高排序**決定下回合順序
- 花費相同維持原本相對順序（穩定排序）
- 計數器歸零，進入下回合

#### 行動詳解（Actions）

##### Build（建造）
- 打出 1 張地點卡或產業卡
- 地點卡：建在該城市的對應產業格位
- 產業卡：建在任何你有網路連結到的城市的對應格位（運河時代第一次建造無需網路）
- **Overbuilding（覆蓋建造）**：可以用更高級的 Tile 替換自己已有的同產業 Tile（不可替換他人的）。煤礦和鐵工廠必須在其資源 Token 全部被消耗後才可被覆蓋建造
- 支付金錢 + 煤炭/鐵礦需求（見下方費用表）
- 建造完成後，若該建築產出資源（煤炭/鐵礦/啤酒），放置對應 Token

##### Network（建立連結）
- 打出任意 1 張牌
- **運河時代**：花費 £3 放置 1 條運河連結，不需煤炭
- **鐵路時代**：花費 £5 + 1 煤炭放置 1 條鐵路連結；或花費 £15 + 1 煤炭 + 1 啤酒放置 2 條
- 連結必須連接到你已有建築或已有連結的城市
- 每條路線最多 1 條連結（不同玩家不可重疊）

##### Develop（升級科技）
- 打出任意 1 張牌
- 從玩家板上移除 1 或 2 個最低等級的建築 Tile（回到遊戲盒外）
- 每次 Develop 移除的 Tile 需花費 1 鐵礦/個
- **限制**：不可跳過等級；製造廠（Manufacturer）不可透過 Develop 升級

##### Sell（銷售）
- 打出任意 1 張牌
- 可銷售的建築類型：棉花廠、製造廠、陶瓷廠（有銷售圖示的產業）
- **銷售條件**：該建築必須透過網路連結到至少一個商人 Tile，且消耗所需的啤酒
- 銷售成功：翻面建築 Tile，獲得收入等級提升和/或 VP
- 可在同一行動中銷售多個建築（只要各自滿足條件）

##### Loan（貸款）
- 打出任意 1 張牌
- 獲得 £30
- 收入等級降低 3 級（最低降至 0，不會變負數）
- 無借貸次數限制

##### Scout（偵查）
- 打出任意 1 張牌，並額外棄掉 2 張手牌（共消耗 3 張手牌）
- 從供應區獲得 1 張萬用地點卡（Wild Location）和 1 張萬用產業卡（Wild Industry）
- **限制**：每回合只能執行 1 次 Scout（不可作為同回合的兩個行動都執行 Scout）

#### 建造費用表

| 產業 | 等級 | 金錢 | 煤炭 | 鐵礦 | 產出 | 翻面獲得 |
|------|------|------|------|------|------|----------|
| 棉花廠 Cotton | Lv1 | £12 | 0 | 0 | — | 收入+5, VP 3 |
| 棉花廠 Cotton | Lv2 | £14 | 1 coal | 0 | — | 收入+4, VP 5 |
| 棉花廠 Cotton | Lv3 | £16 | 1 coal | 1 iron | — | 收入+3, VP 9 |
| 棉花廠 Cotton | Lv4 | £18 | 1 coal | 1 iron | — | 收入+2, VP 12 |
| 鐵工廠 Iron | Lv1 | £5 | 1 coal | 0 | 4 iron | 收入+3, VP 3 |
| 鐵工廠 Iron | Lv2 | £7 | 1 coal | 0 | 4 iron | 收入+3, VP 5 |
| 鐵工廠 Iron | Lv3 | £9 | 1 coal | 0 | 5 iron | 收入+2, VP 7 |
| 鐵工廠 Iron | Lv4 | £12 | 1 coal | 0 | 6 iron | 收入+1, VP 9 |
| 煤礦 Coal | Lv1 | £5 | 0 | 0 | 2 coal | 收入+4, VP 1 |
| 煤礦 Coal | Lv2 | £7 | 0 | 0 | 3 coal | 收入+7, VP 2 |
| 煤礦 Coal | Lv3 | £8 | 0 | 1 iron | 4 coal | 收入+6, VP 3 |
| 煤礦 Coal | Lv4 | £10 | 0 | 1 iron | 5 coal | 收入+5, VP 4 |
| 釀酒廠 Brewery | Lv1 | £5 | 0 | 1 iron | 1 beer | 收入+4, VP 2 |
| 釀酒廠 Brewery | Lv2 | £7 | 0 | 1 iron | 1 beer | 收入+5, VP 5 |
| 釀酒廠 Brewery | Lv3 | £9 | 0 | 1 iron | 1 beer | 收入+5, VP 7 |
| 釀酒廠 Brewery | Lv4 | £9 | 0 | 1 iron | 2 beer | 收入+5, VP 10 |
| 製造廠 Mfr | Lv1 | £8 | 0 | 0 | — | 收入+3, VP 3 |
| 製造廠 Mfr | Lv2 | £10 | 1 coal | 0 | — | 收入+5, VP 5 |
| 製造廠 Mfr | Lv3 | £12 | 1 coal | 1 iron | — | 收入+4, VP 4 |
| 製造廠 Mfr | Lv4 | £8 | 0 | 1 iron | — | 收入+3, VP 3 |
| 製造廠 Mfr | Lv5 | £16 | 1 coal | 0 | — | 收入+8, VP 8 |
| 製造廠 Mfr | Lv6 | £20 | 0 | 0 | — | 收入+7, VP 7 |
| 製造廠 Mfr | Lv7 | £16 | 1 coal | 1 iron | — | 收入+9, VP 9 |
| 製造廠 Mfr | Lv8 | £20 | 0 | 1 iron | — | 收入+8, VP 11 |
| 陶瓷廠 Pottery | Lv1 | £17 | 0 | 1 iron | — | 收入+5, VP 10 |
| 陶瓷廠 Pottery | Lv2 | £0 | 1 coal | 0 | — | 收入+1, VP 1 |
| 陶瓷廠 Pottery | Lv3 | £22 | 2 coal | 0 | — | 收入+5, VP 11 |
| 陶瓷廠 Pottery | Lv4 | £0 | 1 coal | 0 | — | 收入+1, VP 1 |
| 陶瓷廠 Pottery | Lv5 | £24 | 2 coal | 0 | — | 收入+5, VP 20 |

> 注：以上費用為原版參考值，實作時應以最終確認的遊戲數據為準。

#### 合法行動提示（Validation）
- Build：高亮可建造的城市格位（依打出的卡牌、網路連結、金錢/資源是否足夠）
- Network：高亮可連結的路線（依時代、金錢/煤炭是否足夠、網路連結）
- Sell：高亮可銷售的建築（依網路是否連到商人、啤酒是否足夠）
- Develop：高亮可升級的產業（依鐵礦是否足夠、產業是否允許 Develop）
- 使用 `highlightOn()` 物件發光提示
- 非法操作彈出提示訊息
- 玩家放置到錯誤位置時，物件自動彈回原位

#### 資源自動扣除（Market）
- 建造時自動計算煤炭/鐵礦需求
- **煤炭/鐵礦取得優先順序**：
  1. 自己相連建築上的資源（免費）
  2. 其他玩家相連建築上的資源（免費，但消耗他人資源使其建築翻面）
  3. 從市場購買（依市場價格扣錢 + 移除 Token）
  4. 多個來源可選時，由玩家手動選擇（高亮所有合法來源）
- 市場價格隨供給自動更新（煤炭 £1-£8，鐵礦 £1-£6）
- **啤酒取得規則**：
  1. 自己的啤酒（自己建築上的啤酒桶）優先
  2. 不足時可使用相連的其他玩家啤酒
  3. 多個來源可選時，由玩家手動選擇
  4. 啤酒不可從市場購買

#### 時代轉換（EraTransition）
- 時代結束條件：**牌庫耗盡，且所有玩家手牌皆已打出進入棄牌堆**（即所有玩家手牌為 0 時觸發）
- 自動執行中期計分（運河時代計分）
- 移除所有運河連結 Tile（歸還玩家）
- 移除所有 Level 1 建築 Tile（從地圖和玩家板上移除）
- **鐵路時代牌庫組成**：使用完整牌組，依人數移除對應城市卡（規則同設置），不含運河時代已棄的牌
- 洗牌、發牌（每人手牌補至 8 張）
- 重置市場供給至初始值
- 重置 `isFirstRound = true`（鐵路時代第一回合也只有 1 個行動）

#### 計分（Scoring）
- **已翻面建築 VP**：每個已翻面建築提供其印刷的 VP 值
- **連結 VP**：每條連結獲得其兩端城市中所有已翻面建築上印刷的「連結計分圖示」（link icon）數量總和。例如某建築印有 2 個連結圖示，則為相鄰連結貢獻 2 分
- **收入 VP**：終局時收入等級直接轉換為對應 VP
- 計分時機：運河時代結束（中期計分）+ 鐵路時代結束（終局計分）
- 中期計分後運河連結被移除，不再計分；鐵路時代的連結在終局計分
- **平手判定**：VP 相同時，比較剩餘金錢（£）；仍相同則比較收入等級
- 自動計算並更新計分軌
- 終局顯示最終排名與詳細得分明細

### 事件流程（以 Build 為例）

1. 玩家從手牌中打出一張卡到棄牌堆 → `onObjectEnterZone(棄牌區)`
2. 腳本辨識卡牌類型，高亮合法建造位置 → `Validation.getValidBuildSpots()`
3. 玩家將建築 Tile 放到高亮位置 → `onObjectDropped(Snap Point)`
4. 腳本自動扣除金錢 + 資源 → `Market.consumeResources()`
5. 放置資源 Token 到建築上（如煤礦產煤）→ `Actions.placeResources()`
6. 更新 GameState、計數器花費、剩餘行動 -1 → `TurnManager.endAction()`

### 存檔/讀檔（SaveLoad）
- `onSave()` — 將 GameState 序列化為 JSON 字串，TTS 自動保存
- `onLoad(save_state)` — 從 JSON 還原 GameState，重建所有 UI 狀態
- 物件位置由 TTS 自動保存，腳本只需保存邏輯狀態
- 載入後重新綁定所有物件參照（GUID mapping）

### 多語言系統（Lang）
- `Lang.lua` 管理所有 UI 文字的中英文對照表
- 腳本產生的提示訊息依語言設定顯示
- 桌面上放置語言切換按鈕（Custom Tile）全局切換
- 幫助卡翻面切換語言
- 規則書準備英文/中文各一本

---

## 5. 美術資源需求

### 需要製作的圖片資源
- 主地圖板貼圖（高解析度，含所有公共區域）
- 6 種產業建築 Tile 貼圖（每種每級正面 + 統一背面）
- 運河/鐵路連結 Tile 貼圖（4 色 × 2 類型）
- 卡牌正面貼圖（地點卡 + 產業卡 + 萬用卡）+ 統一背面
- 金錢（£1 銅幣 / £5 銀幣 / £15 金幣）3D 模型 + 貼圖
- 商人 Tile 貼圖
- 玩家板貼圖（4 色）
- 幫助卡正面（英文）/ 背面（中文）
- 規則說明書 PDF（英文版 + 中文版）
- 資源 Token 3D 模型（煤炭球、鐵礦方塊、啤酒桶）

### 視覺風格
- 還原原版 Brass: Birmingham 的工業革命時代美術風格
- 配色以暗金、深棕、暗紅為主調
- 字體使用古典襯線體
