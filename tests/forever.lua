-- Run from the repository root with: lua tests/forever.lua
-- Offline smoke test for the Forever item-loading and Titan menu paths.
local frames, timers, requests = {}, {}, {}
local equipped = { [1] = 1001 }
local cached = {}
local items = {
    [1001] = { quality = 4, level = 60, loc = "INVTYPE_HEAD" },
    [1002] = { quality = 4, level = 60, loc = "INVTYPE_HEAD" },
    [1003] = { quality = 6, level = 60, loc = "INVTYPE_HEAD" },
}

UIParent = {}
FONT_COLOR_CODE_CLOSE = "|r"
RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 0, b = 0 } }
SlashCmdList = {}
issecretvalue = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitName = function() return "Tester" end
GetInventoryItemID = function(_, slot) return equipped[slot] end
GetAverageItemLevel = function() return 60, 60 end
IsShiftKeyDown = function() return false end
C_AddOns = { GetAddOnMetadata = function() return "2.1.1" end }
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_Item = {
    IsItemDataCachedByID = function(id) return cached[id] == true end,
    RequestLoadItemDataByID = function(id) requests[#requests + 1] = id end,
    GetItemInfo = function(id)
        local it = items[id]
        return nil, nil, it.quality, it.level
    end,
    GetItemInfoInstant = function(id)
        return id, nil, nil, items[id].loc
    end,
}

CreateFrame = function(_, name)
    local f = { events = {}, name = name }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterEvent(event) self.events[event] = nil end
    function f:SetScript(event, fn) self[event] = fn end
    function f:SetFrameStrata() end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

TitanGetVar = function() return true end
TitanToggleVar = function() end
TitanPanelButton_UpdateButton = function() end
TitanPanelButton_OnShow = function() end
TitanPanelButton_OnClick = function() end
TitanUtils_GetHighlightText = tostring
TitanUtils_GetNormalText = tostring
TitanUtils_GetRedText = tostring
TitanUtils_GetGreenText = tostring
TitanPanelRightClickMenu_GetDropdownLevel = function() return 1 end
TitanPanelRightClickMenu_AddTitle = function() end
TitanPanelRightClickMenu_AddSpacer = function() end
TitanPanelRightClickMenu_AddToggleIcon = function() end
TitanPanelRightClickMenu_AddToggleLabelText = function() end
local menuButton, hideID
TitanPanelRightClickMenu_AddButton = function(info) menuButton = info end
TitanPanelRightClickMenu_AddHide = function(id) hideID = id end

local function flushTimers()
    local todo = timers
    timers = {}
    for _, fn in ipairs(todo) do fn() end
end

assert(loadfile("TitanGearScore.lua"))("TitanGearScore")
local button = _G.TitanPanelTitanGearScoreButton
assert(button and button.registry)
button.OnShow(button)
local _, text = TitanPanelGearScore_GetButtonText()
assert(text:find("?", 1, true), text)
assert(#requests == 1 and requests[1] == 1001)
assert(TitanPanelGearScore_GetTooltipText():find("Loading", 1, true))

-- An unrelated item load must not change the score; the equipped item's load must.
frames[1].OnEvent(frames[1], "ITEM_DATA_LOAD_RESULT", 9999, true)
_, text = TitanPanelGearScore_GetButtonText()
assert(text:find("?", 1, true), text)
cached[1001] = true
frames[1].OnEvent(frames[1], "ITEM_DATA_LOAD_RESULT", 1001, true)
_, text = TitanPanelGearScore_GetButtonText()
assert(text:find("68", 1, true) and not text:find("?", 1, true), text)
assert(TitanPanelGearScore_GetTooltipText():find("Items Scored: 1", 1, true))

-- A known score with another item pending carries a visible uncertainty mark.
equipped[2] = 1002
button.OnEvent(button, "PLAYER_EQUIPMENT_CHANGED", 2)
flushTimers()
_, text = TitanPanelGearScore_GetButtonText()
assert(text:find("68", 1, true) and text:find("?", 1, true), text)
equipped[2] = nil

-- A failed load remains unknown rather than making a complete zero score.
equipped[1] = 1002
button.OnEvent(button, "PLAYER_EQUIPMENT_CHANGED", 1)
flushTimers()
frames[1].OnEvent(frames[1], "GET_ITEM_INFO_RECEIVED", 1002, false)
_, text = TitanPanelGearScore_GetButtonText()
assert(text:find("?", 1, true), text)
assert(TitanPanelGearScore_GetTooltipText():find("Unreadable", 1, true))

-- Unsupported item quality is called out instead of counting as scored.
equipped[1], cached[1003] = 1003, true
button.OnEvent(button, "PLAYER_EQUIPMENT_CHANGED", 1)
flushTimers()
local tooltip = TitanPanelGearScore_GetTooltipText()
assert(tooltip:find("Items Scored: 0", 1, true), tooltip)
assert(tooltip:find("Unscored", 1, true), tooltip)

-- Combat-secret equipment is excluded without touching the secret ID.
local secretID = {}
issecretvalue = function(v) return v == secretID end
equipped[1] = secretID
button.OnEvent(button, "PLAYER_EQUIPMENT_CHANGED", 1)
flushTimers()
assert(TitanPanelGearScore_GetTooltipText():find("Unreadable", 1, true))

-- A failed scan must clear the previous result rather than show stale gear.
GetInventoryItemID = function() error("inventory unavailable") end
button.OnEvent(button, "PLAYER_REGEN_ENABLED")
flushTimers()
_, text = TitanPanelGearScore_GetButtonText()
assert(text:find("?", 1, true), text)
assert(TitanPanelGearScore_GetTooltipText():find("inventory unavailable", 1, true))

button.registry.menuTextFunction("TitanGearScore")
assert(menuButton and menuButton.text == "Show Average Item Level")
assert(hideID == "TitanGearScore")
print("Forever smoke test passed")
