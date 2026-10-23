--[[
-- **************************************************************************
-- * TitanGearScore.lua
-- *
-- * Titan Panel plugin: displays your GearScore and average item level.
-- * Ported to World of Warcraft: Forever (1.60.1) / Interface 16001.
-- *
-- * GearScore formula based on GearScoreLite by Mirrikat45 & TacoTip by kebabstorm.
-- * Titan Panel integration modelled after TitanGold by the Titan Dev Team.
-- *
-- * Author: Karuzo
-- **************************************************************************
--]]

local ADDON_NAME = ...

-- ******************************** Constants *******************************
local TITAN_GS_ID = "TitanGearScore"
local TITAN_BUTTON = "TitanPanel" .. TITAN_GS_ID .. "Button"
local _GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local TITAN_GS_VERSION = (_GetAddOnMetadata and _GetAddOnMetadata(ADDON_NAME, "Version")) or "2.1.0"

local floor = math.floor
local format = string.format

-- ******************************** GearScore Engine ************************
-- Self-contained GearScore calculator. No external libraries required.
-- Reads the player's equipped item IDs through C_Item.

-- Forever has Vanilla gear, so it uses the Classic GearScore brackets.
local BRACKET_SIZE = 200

local MAX_SCORE = BRACKET_SIZE * 6 - 1

local GS_ItemTypes = {
    ["INVTYPE_RELIC"]           = { SlotMOD = 0.3164 },
    ["INVTYPE_TRINKET"]         = { SlotMOD = 0.5625 },
    ["INVTYPE_2HWEAPON"]        = { SlotMOD = 2.0000 },
    ["INVTYPE_WEAPONMAINHAND"]  = { SlotMOD = 1.0000 },
    ["INVTYPE_WEAPONOFFHAND"]   = { SlotMOD = 1.0000 },
    ["INVTYPE_RANGED"]          = { SlotMOD = 0.3164 },
    ["INVTYPE_THROWN"]          = { SlotMOD = 0.3164 },
    ["INVTYPE_RANGEDRIGHT"]     = { SlotMOD = 0.3164 },
    ["INVTYPE_SHIELD"]          = { SlotMOD = 1.0000 },
    ["INVTYPE_WEAPON"]          = { SlotMOD = 1.0000 },
    ["INVTYPE_HOLDABLE"]        = { SlotMOD = 1.0000 },
    ["INVTYPE_HEAD"]            = { SlotMOD = 1.0000 },
    ["INVTYPE_NECK"]            = { SlotMOD = 0.5625 },
    ["INVTYPE_SHOULDER"]        = { SlotMOD = 0.7500 },
    ["INVTYPE_CHEST"]           = { SlotMOD = 1.0000 },
    ["INVTYPE_ROBE"]            = { SlotMOD = 1.0000 },
    ["INVTYPE_WAIST"]           = { SlotMOD = 0.7500 },
    ["INVTYPE_LEGS"]            = { SlotMOD = 1.0000 },
    ["INVTYPE_FEET"]            = { SlotMOD = 0.7500 },
    ["INVTYPE_WRIST"]           = { SlotMOD = 0.5625 },
    ["INVTYPE_HAND"]            = { SlotMOD = 0.7500 },
    ["INVTYPE_FINGER"]          = { SlotMOD = 0.5625 },
    ["INVTYPE_CLOAK"]           = { SlotMOD = 0.5625 },
    ["INVTYPE_BODY"]            = { SlotMOD = 0 },
}

local GS_Formula = {
    A = {
        [4] = { A = 91.4500, B = 0.6500 },
        [3] = { A = 81.3750, B = 0.8125 },
        [2] = { A = 73.0000, B = 1.0000 },
    },
    B = {
        [4] = { A = 26.0000, B = 1.2000 },
        [3] = { A = 0.7500,  B = 1.8000 },
        [2] = { A = 8.0000,  B = 2.0000 },
        [1] = { A = 0.0000,  B = 2.2500 },
    },
    C = {
        [4] = { A = 0.2500, B = 1.6275 },
    },
}

local GS_Quality = {
    [BRACKET_SIZE * 6] = {
        Red   = { A = 0.94, B = BRACKET_SIZE * 5, C = 0.00006, D =  1 },
        Green = { A = 0,    B = 0,                 C = 0,       D =  0 },
        Blue  = { A = 0.47, B = BRACKET_SIZE * 5, C = 0.00047, D = -1 },
        Description = "Legendary",
    },
    [BRACKET_SIZE * 5] = {
        Red   = { A = 0.69, B = BRACKET_SIZE * 4, C = 0.00025, D =  1 },
        Green = { A = 0.97, B = BRACKET_SIZE * 4, C = 0.00096, D = -1 },
        Blue  = { A = 0.28, B = BRACKET_SIZE * 4, C = 0.00019, D =  1 },
        Description = "Epic",
    },
    [BRACKET_SIZE * 4] = {
        Red   = { A = 0.00, B = BRACKET_SIZE * 3, C = 0.00069, D =  1 },
        Green = { A = 1.00, B = BRACKET_SIZE * 3, C = 0.00003, D = -1 },
        Blue  = { A = 0.50, B = BRACKET_SIZE * 3, C = 0.00022, D = -1 },
        Description = "Superior",
    },
    [BRACKET_SIZE * 3] = {
        Red   = { A = 0.12, B = BRACKET_SIZE * 2, C = 0.00012, D = -1 },
        Green = { A = 0.00, B = BRACKET_SIZE * 2, C = 0.00100, D =  1 },
        Blue  = { A = 1.00, B = BRACKET_SIZE * 2, C = 0.00050, D = -1 },
        Description = "Uncommon",
    },
    [BRACKET_SIZE * 2] = {
        Red   = { A = 1.00, B = BRACKET_SIZE,     C = 0.00088, D = -1 },
        Green = { A = 1.00, B = BRACKET_SIZE,     C = 0.00100, D = -1 },
        Blue  = { A = 1.00, B = 0,                C = 0,       D =  0 },
        Description = "Common",
    },
    [BRACKET_SIZE] = {
        Red   = { A = 0.55, B = 0, C = 0.00045, D = 1 },
        Green = { A = 0.55, B = 0, C = 0.00045, D = 1 },
        Blue  = { A = 0.55, B = 0, C = 0.00045, D = 1 },
        Description = "Trash",
    },
}

--- Compute the GS-quality color for a given score.
---@param score number
---@return number r, number g, number b, string description
local function GetScoreColor(score)
    score = tonumber(score)
    if not score then return 0, 0, 0, "Trash" end
    if score > MAX_SCORE then score = MAX_SCORE end
    for i = 0, 5 do
        if score > i * BRACKET_SIZE and score <= (i + 1) * BRACKET_SIZE then
            local q = GS_Quality[(i + 1) * BRACKET_SIZE]
            local r = q.Red.A   + ((score - q.Red.B)   * q.Red.C)   * q.Red.D
            local g = q.Green.A + ((score - q.Green.B) * q.Green.C) * q.Green.D
            local b = q.Blue.A  + ((score - q.Blue.B)  * q.Blue.C)  * q.Blue.D
            return r, g, b, q.Description
        end
    end
    return 0.1, 0.1, 0.1, "Trash"
end

--- Score loaded item data.
---@param itemRarity number
---@param itemLevel number
---@param itemEquipLoc string
---@return number gearScore, number itemLevel, number r, number g, number b, string|nil equipLoc
local function ScoreItem(ItemRarity, ItemLevel, ItemEquipLoc)
    if not (ItemRarity and ItemLevel and ItemEquipLoc and GS_ItemTypes[ItemEquipLoc]) then
        return 0, 0, 0.1, 0.1, 0.1, nil
    end

    local QualityScale = 1
    local Scale = 1.8618

    if ItemRarity == 5 then       -- Legendary
        QualityScale = 1.3;  ItemRarity = 4
    elseif ItemRarity <= 1 then   -- Poor / Common
        QualityScale = 0.005; ItemRarity = 2
    elseif ItemRarity == 7 then   -- Heirloom
        ItemRarity = 3; ItemLevel = 187.05
    end

    -- Pick formula table based on TacoTip's improved thresholds
    local Table
    if ItemLevel < 100 and ItemRarity == 4 then
        Table = GS_Formula.C
    elseif ItemLevel < 168 and ItemRarity == 4 then
        Table = GS_Formula.B
    elseif ItemLevel < 148 and ItemRarity == 3 then
        Table = GS_Formula.B
    elseif ItemLevel < 138 and ItemRarity == 2 then
        Table = GS_Formula.B
    elseif ItemLevel <= 120 then
        Table = GS_Formula.B
    else
        Table = GS_Formula.A
    end

    if ItemRarity >= 2 and ItemRarity <= 4 and Table[ItemRarity] then
        local gs = floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * GS_ItemTypes[ItemEquipLoc].SlotMOD * Scale * QualityScale)
        local origLevel = ItemLevel
        if ItemLevel == 187.05 then origLevel = 0 end -- Heirloom marker
        if gs < 0 then gs = 0 end
        local r, g, b = GetScoreColor(floor(((ItemLevel - Table[ItemRarity].A) / Table[ItemRarity].B) * Scale) * 11.25)
        return gs, floor(origLevel), r, g, b, ItemEquipLoc
    end

    return 0, 0, 0.1, 0.1, 0.1, nil
end

-- Slot scan order: head(1), neck(2), shoulder(3), chest(5), waist(6), legs(7),
-- feet(8), wrist(9), hands(10), ring1(11), ring2(12), trinket1(13),
-- trinket2(14), cloak(15), mainhand(16), offhand(17), ranged(18).
-- Skipping shirt(4) as it has no stats.
local SCAN_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local SLOT_NAMES = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Cloak",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged/Relic",
}

-- ******************************** Bar Gradient ****************************
-- Smooth gradient following WoW's item quality color ramp:
-- Gray (Poor) → White (Common) → Green (Uncommon) → Blue (Rare) → Purple (Epic) → Orange (Legendary)
-- Mapped to Classic GearScore brackets (0-200-400-600-800-1000-1200).

local GRADIENT_STOPS = {
    --  score threshold,          R,    G,    B
    { 0,                        0.62, 0.62, 0.62 },  -- #9d9d9d  Poor (gray)
    { BRACKET_SIZE,             1.00, 1.00, 1.00 },  -- #ffffff  Common (white)
    { BRACKET_SIZE * 2,         0.12, 1.00, 0.00 },  -- #1eff00  Uncommon (green)
    { BRACKET_SIZE * 3,         0.00, 0.44, 0.87 },  -- #0070dd  Rare (blue)
    { BRACKET_SIZE * 4,         0.64, 0.21, 0.93 },  -- #a335ee  Epic (purple)
    { BRACKET_SIZE * 5,         1.00, 0.50, 0.00 },  -- #ff8000  Legendary (orange)
}

--- Interpolate the bar gradient color for a given GearScore.
---@param score number
---@return number r, number g, number b
local function GetBarGradient(score)
    score = score or 0
    if score <= GRADIENT_STOPS[1][1] then
        return GRADIENT_STOPS[1][2], GRADIENT_STOPS[1][3], GRADIENT_STOPS[1][4]
    end
    for i = 2, #GRADIENT_STOPS do
        if score <= GRADIENT_STOPS[i][1] then
            local prev = GRADIENT_STOPS[i - 1]
            local curr = GRADIENT_STOPS[i]
            local t = (score - prev[1]) / (curr[1] - prev[1])
            local r = prev[2] + (curr[2] - prev[2]) * t
            local g = prev[3] + (curr[3] - prev[3]) * t
            local b = prev[4] + (curr[4] - prev[4]) * t
            return r, g, b
        end
    end
    -- Above max stop
    local last = GRADIENT_STOPS[#GRADIENT_STOPS]
    return last[2], last[3], last[4]
end

-- Cached results, refreshed on gear change
local cachedGearScore = 0
local cachedAvgILevel = nil
local cachedSlotScores = {}
local cachedBarR, cachedBarG, cachedBarB = 1, 1, 1 -- smooth gradient color (bar)
local cachedDesc = ""
local cachedScoredCount, cachedLoading, cachedUnreadable, cachedUnscored = 0, 0, 0, 0
local cacheReady = false

-- Forever may return secret item values in combat. Check before comparing or
-- formatting any client value.
local function Plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local pending, failed = {}, {}
local loader = CreateFrame("Frame")
local listening = false
local LOAD_EVENTS = { "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }

local function ListenForItems(on)
    if listening == on then return end
    listening = on
    for _, event in ipairs(LOAD_EVENTS) do
        if on then loader:RegisterEvent(event) else loader:UnregisterEvent(event) end
    end
end

local function RequestItem(id)
    if pending[id] then return end
    pending[id] = true
    ListenForItems(true)
    C_Item.RequestLoadItemDataByID(id)
end

local function ReadSlot(slot)
    local rawID = GetInventoryItemID("player", slot)
    local id = Plain(rawID)
    if not id then
        if issecretvalue and issecretvalue(rawID) then return "unreadable" end
        return "empty"
    end
    if failed[id] then return "unreadable" end
    if pending[id] or Plain(C_Item.IsItemDataCachedByID(id)) ~= true then
        RequestItem(id)
        return "loading"
    end

    local _, _, rawQuality, rawLevel = C_Item.GetItemInfo(id)
    local quality, level = Plain(rawQuality), Plain(rawLevel)
    if type(quality) ~= "number" or type(level) ~= "number" then
        if (issecretvalue and (issecretvalue(rawQuality) or issecretvalue(rawLevel))) then
            return "unreadable"
        end
        RequestItem(id) -- cache entry was evicted between the two calls
        return "loading"
    end
    local _, _, _, rawEquipLoc = C_Item.GetItemInfoInstant(id)
    local equipLoc = Plain(rawEquipLoc)
    if type(equipLoc) ~= "string" then return "unreadable" end
    return quality, level, equipLoc
end

local function RecalcScore()
    local _, rawClass = UnitClass("player")
    local enClass = Plain(rawClass)
    local totalGS, itemCount = 0, 0
    local loading, unreadable, unscored = 0, 0, 0
    local slotData = {}

    for _, slot in ipairs(SCAN_SLOTS) do
        local quality, level, equipLoc = ReadSlot(slot)
        if quality == "loading" then
            loading = loading + 1
            slotData[slot] = "loading"
        elseif quality == "unreadable" then
            unreadable = unreadable + 1
            slotData[slot] = "unreadable"
        elseif type(quality) == "number" then
            local gs, il, r, g, b, scoredLoc = ScoreItem(quality, level, equipLoc)
            if scoredLoc then
                if enClass == "HUNTER" then
                    if slot == 16 or slot == 17 then gs = floor(gs * 0.3164)
                    elseif slot == 18 then gs = floor(gs * 5.3224) end
                end
                totalGS = totalGS + gs
                itemCount = itemCount + 1
                slotData[slot] = { score = gs, ilvl = il, r = r, g = g, b = b }
            else
                unscored = unscored + 1
                slotData[slot] = "unscored"
            end
        end
    end

    -- This is Blizzard's equipped average, independent of GearScore's slot
    -- weights and still meaningful while some item data is loading.
    local ok, _, equipped = pcall(GetAverageItemLevel)
    equipped = ok and Plain(equipped) or nil
    cachedAvgILevel = type(equipped) == "number" and floor(equipped + 0.5) or nil
    cachedGearScore = totalGS
    cachedScoredCount, cachedLoading, cachedUnreadable, cachedUnscored = itemCount, loading, unreadable, unscored
    _, _, _, cachedDesc = GetScoreColor(totalGS)
    cachedBarR, cachedBarG, cachedBarB = GetBarGradient(totalGS)
    cachedSlotScores = slotData
    cacheReady = true
end

local scanError = nil
local function RefreshScore()
    local ok, err = pcall(RecalcScore)
    if ok then
        scanError = nil
    else
        cacheReady = false
        cachedAvgILevel = nil
        local message = Plain(err)
        scanError = type(message) == "string" and message or "Gear data unavailable"
    end
end

loader:SetScript("OnEvent", function(_, _, rawID, rawSuccess)
    local id = Plain(rawID)
    if id and pending[id] then
        pending[id] = nil
        if Plain(rawSuccess) == false then failed[id] = true end
        -- The item can finish loading while the Titan button is hidden.
        RefreshScore()
        TitanPanelButton_UpdateButton(TITAN_GS_ID)
    end
    if not next(pending) then ListenForItems(false) end
end)

local refreshQueued = false
local function ScheduleRecalc()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function()
        refreshQueued = false
        RefreshScore()
        TitanPanelButton_UpdateButton(TITAN_GS_ID)
    end)
end

local function ResetItemLoads()
    pending, failed = {}, {}
    ListenForItems(false)
end

-- ******************************** Titan Panel Integration *****************
-- Follows the same Create_Frames / OnLoad / OnShow / OnEvent pattern as TitanGold.

local function ScoreText()
    local incomplete = cachedLoading + cachedUnreadable > 0
    if not cacheReady or (cachedScoredCount == 0 and incomplete) then return "|cff888888?|r" end
    local text = format("|cff%02x%02x%02x%d|r", cachedBarR * 255, cachedBarG * 255, cachedBarB * 255, cachedGearScore)
    return incomplete and text .. "|cff888888?|r" or text
end

local function ColoredPlayerName()
    local name = Plain(UnitName("player")) or "Player"
    local class = Plain(select(2, UnitClass("player")))
    local color = class and RAID_CLASS_COLORS[class]
    if color then
        return format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
    end
    return name
end

---Build the button text shown on the Titan bar.
local function GetButtonText(id)
    local gsText = ScoreText()

    if TitanGetVar(TITAN_GS_ID, "ShowAvgILevel") then
        return "GearScore" .. ": " .. FONT_COLOR_CODE_CLOSE, gsText .. "  " .. TitanUtils_GetNormalText("iLvl: ") .. TitanUtils_GetHighlightText(cachedAvgILevel or "?")
    end

    return "GearScore" .. ": " .. FONT_COLOR_CODE_CLOSE, gsText
end

---Build the rich tooltip.
local function GetTooltipText()
    local lines = ""

    if not cacheReady then
        return scanError and ("Unable to read gear: " .. scanError) or "Calculating score...\nEquip or swap an item to trigger an update."
    end

    -- Player info
    lines = lines .. ColoredPlayerName() .. "\n"
    lines = lines .. TitanUtils_GetNormalText("GearScore: ") .. ScoreText()
    if cachedScoredCount > 0 then lines = lines .. "  (" .. cachedDesc .. ")" end
    lines = lines .. "\n"
    lines = lines .. TitanUtils_GetNormalText("Avg Item Level: ") .. TitanUtils_GetHighlightText(cachedAvgILevel or "?") .. "\n"
    lines = lines .. TitanUtils_GetNormalText("Items Scored: ") .. TitanUtils_GetHighlightText(cachedScoredCount) .. "\n"
    if cachedLoading > 0 then lines = lines .. TitanUtils_GetNormalText(cachedLoading .. " item(s) still loading; excluded from score.") .. "\n" end
    if cachedUnreadable > 0 then lines = lines .. TitanUtils_GetNormalText(cachedUnreadable .. " item(s) unreadable; excluded from score.") .. "\n" end
    if cachedUnscored > 0 then lines = lines .. TitanUtils_GetNormalText(cachedUnscored .. " item(s) have no GearScore.") .. "\n" end

    -- Separator
    lines = lines .. " \n"
    lines = lines .. TitanUtils_GetNormalText("--- Equipped Gear ---") .. "\n"

    -- Per-slot breakdown, ordered by scan order
    for _, slot in ipairs(SCAN_SLOTS) do
        local name = SLOT_NAMES[slot] or ("Slot " .. slot)
        local data = cachedSlotScores[slot]
        if type(data) == "table" then
            local scoreStr = format("|cff%02x%02x%02x%d|r", data.r * 255, data.g * 255, data.b * 255, data.score)
            lines = lines .. TitanUtils_GetNormalText(name .. ": ") .. scoreStr .. "  (iLvl " .. data.ilvl .. ")\n"
        else
            local status = data == "loading" and "Loading" or data == "unreadable" and "Unreadable" or data == "unscored" and "Unscored" or "Empty"
            lines = lines .. TitanUtils_GetNormalText(name .. ": ") .. TitanUtils_GetRedText(status) .. "\n"
        end
    end

    -- Hint
    lines = lines .. " \n"
    lines = lines .. TitanUtils_GetGreenText("Shift+Left-click to print to chat.")

    return lines
end

---Build the right-click menu.
local function CreateMenu(id)
    -- Level 1
    if TitanPanelRightClickMenu_GetDropdownLevel() == 1 then
        TitanPanelRightClickMenu_AddTitle("GearScore")
        TitanPanelRightClickMenu_AddSpacer()

        local info = {}
        info.text = "Show Average Item Level"
        info.func = function()
            TitanToggleVar(TITAN_GS_ID, "ShowAvgILevel")
            TitanPanelButton_UpdateButton(TITAN_GS_ID)
        end
        info.checked = TitanGetVar(TITAN_GS_ID, "ShowAvgILevel")
        info.keepShownOnClick = 1
        TitanPanelRightClickMenu_AddButton(info)

        TitanPanelRightClickMenu_AddSpacer()
        TitanPanelRightClickMenu_AddToggleIcon(id)
        TitanPanelRightClickMenu_AddToggleLabelText(id)

        TitanPanelRightClickMenu_AddSpacer()
        TitanPanelRightClickMenu_AddHide(id)
    end
end

---Build the .registry and register events (called once when button is created).
---@param self Button
local function OnLoad(self)
    self.registry = {
        id = TITAN_GS_ID,
        category = "Interface",
        version = TITAN_GS_VERSION,
        menuText = "GearScore",
        menuTextFunction = CreateMenu,
        buttonTextFunction = "TitanPanelGearScore_GetButtonText",
        tooltipTitle = "Titan Panel |cffeda55fGearScore|r",
        tooltipTextFunction = "TitanPanelGearScore_GetTooltipText",
        icon = "Interface\\Icons\\trade_engineering",
        iconWidth = 16,
        notes = "Displays your GearScore and average item level.\n"
             .. "Score updates automatically when you equip or swap gear.",
        controlVariables = {
            ShowIcon = true,
            ShowLabelText = true,
            ShowRegularText = false,
            ShowColoredText = false,
            DisplayOnRightSide = false,
        },
        savedVariables = {
            ShowIcon = true,
            ShowLabelText = true,
            ShowAvgILevel = true,
        },
    }

    self:RegisterEvent("ADDON_LOADED")
end

---@param self Button
local function OnShow(self)
    -- Keep the button current while it is displayed on a Titan bar.
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Initial calculation
    RefreshScore()
    TitanPanelButton_UpdateButton(TITAN_GS_ID)
end

---@param self Button
local function OnHide(self)
    self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

---@param self Button
---@param event string
---@param a1 any
local function OnEvent(self, event, a1, ...)
    if event == "ADDON_LOADED" then
        if a1 == ADDON_NAME then
            self:UnregisterEvent("ADDON_LOADED")

            ScheduleRecalc()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD"
        or (event == "UNIT_INVENTORY_CHANGED" and Plain(a1) == "player") then
        ResetItemLoads()
        ScheduleRecalc()
    elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        ScheduleRecalc()
    end
end

---@param self Button
---@param button string
local function OnClick(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
        print(ColoredPlayerName() .. " - GearScore: " .. ScoreText() .. " (Avg iLvl: " .. (cachedAvgILevel or "?") .. ")")
    end
end

-- ******************************** Global function hooks *******************
-- Titan Panel expects these as globals with specific naming conventions.

function TitanPanelGearScore_GetButtonText(id)
    return GetButtonText(id)
end

function TitanPanelGearScore_GetTooltipText()
    return GetTooltipText()
end

-- Titan Panel looks for this global to build the right-click menu.
function TitanPanelRightClickMenu_PrepareTitanGearScoreMenu()
    CreateMenu(TITAN_GS_ID)
end

-- ******************************** Frame Creation **************************
-- Following TitanGold's pattern: create frames in Lua, no XML needed.

local function Create_Frames()
    if _G[TITAN_BUTTON] then
        return -- already created
    end

    local f = CreateFrame("Frame", nil, UIParent)

    local window = CreateFrame("Button", TITAN_BUTTON, f, "TitanPanelComboTemplate")
    window:SetFrameStrata("FULLSCREEN")

    OnLoad(window)

    window:SetScript("OnShow", function(self)
        OnShow(self)
        TitanPanelButton_OnShow(self)
    end)
    window:SetScript("OnHide", function(self)
        OnHide(self)
    end)
    window:SetScript("OnEvent", function(self, event, ...)
        OnEvent(self, event, ...)
    end)
    window:SetScript("OnClick", function(self, button)
        OnClick(self, button)
        TitanPanelButton_OnClick(self, button)
    end)
end

Create_Frames()

-- ******************************** Slash Command ***************************
SLASH_TITANGEARSCORE1 = "/tgs"
SLASH_TITANGEARSCORE2 = "/titangs"
SlashCmdList["TITANGEARSCORE"] = function(msg)
    if not cacheReady then
        RefreshScore()
    end
    local bracket = cachedScoredCount > 0 and (" (" .. cachedDesc .. ")") or ""
    print(ColoredPlayerName() .. " - GearScore: " .. ScoreText() .. bracket .. " - Avg iLvl: " .. (cachedAvgILevel or "?"))
end
