local ADDON_NAME = "PPLoot"
local PICK_POCKET_SPELL_ID = 921
local LOOT_WINDOW_TIMEOUT = 1.0 -- seconds after Pick Pocket cast to catch the loot window

local INDICATOR_BASE_Y = 140
local INDICATOR_DRIFT_Y = 42
local INDICATOR_HOLD_TIME = 0.6
local INDICATOR_FADE_TIME = 1.2
local INDICATOR_TOTAL_TIME = INDICATOR_HOLD_TIME + INDICATOR_FADE_TIME

local db = {
    enabled = true,
    showText = true,
}

local pickpocketExpireTime = 0
local isPickpocketing = false
local lootAnnounced = false
local wasMovingOnCast = false
local pendingTimer = nil

local function IsMoving()
    local speed = GetUnitSpeed("player")
    return speed and speed > 0
end

-- Floating indicator frame
local indicatorFrame = CreateFrame("Frame", "PPLootIndicatorFrame", UIParent)
indicatorFrame:SetSize(450, 32)
indicatorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, INDICATOR_BASE_Y)
indicatorFrame:SetFrameStrata("HIGH")
indicatorFrame:Hide()

local indicatorText = indicatorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
indicatorText:SetPoint("CENTER")
local fontPath, fontSize = indicatorText:GetFont()
if fontPath then
    indicatorText:SetFont(fontPath, fontSize, "OUTLINE")
end

local animElapsed = 0

local function OnIndicatorUpdate(self, elapsed)
    animElapsed = animElapsed + elapsed
    if animElapsed >= INDICATOR_TOTAL_TIME then
        self:Hide()
        self:SetScript("OnUpdate", nil)
        return
    end

    local progress = animElapsed / INDICATOR_TOTAL_TIME
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, INDICATOR_BASE_Y + (INDICATOR_DRIFT_Y * progress))

    if animElapsed <= INDICATOR_HOLD_TIME then
        self:SetAlpha(1)
    else
        local fadeProgress = (animElapsed - INDICATOR_HOLD_TIME) / INDICATOR_FADE_TIME
        self:SetAlpha(1 - fadeProgress)
    end
end

local function ShowIndicator(msg, r, g, b)
    if not db.showText then
        return
    end

    animElapsed = 0
    indicatorText:SetText(msg)
    indicatorText:SetTextColor(r or 1, g or 0.96, b or 0.41)
    indicatorFrame:ClearAllPoints()
    indicatorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, INDICATOR_BASE_Y)
    indicatorFrame:SetAlpha(1)
    indicatorFrame:Show()
    indicatorFrame:SetScript("OnUpdate", OnIndicatorUpdate)
end

local function CancelPendingTimer()
    if pendingTimer then
        pendingTimer:Cancel()
        pendingTimer = nil
    end
end

local function FormatMoneyName(rawName)
    if not rawName then
        return ""
    end

    local gold = rawName:match("(%d+)%s*[Gg]old")
    local silver = rawName:match("(%d+)%s*[Ss]ilver")
    local copper = rawName:match("(%d+)%s*[Cc]opper")

    if gold or silver or copper then
        local parts = {}
        if gold then
            parts[#parts + 1] = "|cffffffff" .. gold .. "|r|cffffd700g|r"
        end
        if silver then
            parts[#parts + 1] = "|cffffffff" .. silver .. "|r|cffc7c7cfs|r"
        end
        if copper then
            parts[#parts + 1] = "|cffffffff" .. copper .. "|r|cffeda55fc|r"
        end
        return table.concat(parts, " ")
    end

    return rawName:gsub("\n", " ")
end

local function LootAllSlots()
    local numItems = GetNumLootItems()
    local entries = {}

    for i = numItems, 1, -1 do
        local icon, name, quantity = GetLootSlotInfo(i)
        if icon then
            if not lootAnnounced then
                local slotType = GetLootSlotType(i)
                if slotType == LOOT_SLOT_MONEY then
                    entries[#entries + 1] = FormatMoneyName(name)
                else
                    local link = GetLootSlotLink(i) or name
                    if link then
                        if quantity and quantity > 1 then
                            entries[#entries + 1] = link .. " x" .. quantity
                        else
                            entries[#entries + 1] = link
                        end
                    end
                end
            end
            LootSlot(i)
        end
    end

    if not lootAnnounced then
        if #entries > 0 then
            lootAnnounced = true
            -- Reverse so display matches original loot slot order
            local ordered = {}
            for i = #entries, 1, -1 do
                ordered[#ordered + 1] = entries[i]
            end
            ShowIndicator("Pickpocketed: " .. table.concat(ordered, ", "), 1, 0.96, 0.41)
        elseif numItems == 0 then
            lootAnnounced = true
            if wasMovingOnCast or IsMoving() then
                ShowIndicator("Stop moving to pickpocket", 1, 0.65, 0.2)
            else
                ShowIndicator("Nothing picked", 0.7, 0.7, 0.7)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("UI_ERROR_MESSAGE")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if type(PPLootDB) ~= "table" then
                PPLootDB = {}
            end
            if PPLootDB.enabled == nil then
                PPLootDB.enabled = true
            end
            if PPLootDB.showText == nil then
                PPLootDB.showText = true
            end
            db = PPLootDB
            frame:UnregisterEvent("ADDON_LOADED")
        end
        return
    end

    if not db.enabled then
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == PICK_POCKET_SPELL_ID then
            pickpocketExpireTime = GetTime() + LOOT_WINDOW_TIMEOUT
            lootAnnounced = false
            wasMovingOnCast = IsMoving()
            CancelPendingTimer()
            pendingTimer = C_Timer.NewTimer(LOOT_WINDOW_TIMEOUT, function()
                pendingTimer = nil
                if not isPickpocketing and not lootAnnounced and pickpocketExpireTime > 0 then
                    pickpocketExpireTime = 0
                    if wasMovingOnCast or IsMoving() then
                        ShowIndicator("Stop moving to pickpocket", 1, 0.65, 0.2)
                    else
                        ShowIndicator("Nothing picked", 0.7, 0.7, 0.7)
                    end
                    wasMovingOnCast = false
                end
            end)
        end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        if isPickpocketing or GetTime() <= pickpocketExpireTime then
            CancelPendingTimer()
            isPickpocketing = true
            LootAllSlots()
        end
    elseif event == "LOOT_CLOSED" then
        if (isPickpocketing or GetTime() <= pickpocketExpireTime) and not lootAnnounced then
            if wasMovingOnCast or IsMoving() then
                ShowIndicator("Stop moving to pickpocket", 1, 0.65, 0.2)
            else
                ShowIndicator("Nothing picked", 0.7, 0.7, 0.7)
            end
        end
        isPickpocketing = false
        pickpocketExpireTime = 0
        lootAnnounced = false
        wasMovingOnCast = false
        CancelPendingTimer()
    elseif event == "UI_ERROR_MESSAGE" then
        local _, message = ...
        if type(message) ~= "string" then
            return
        end

        local lower = message:lower()
        if (ERR_ALREADY_PICKPOCKETED and message == ERR_ALREADY_PICKPOCKETED) or lower:find("pockets picked") then
            CancelPendingTimer()
            pickpocketExpireTime = 0
            wasMovingOnCast = false
            ShowIndicator("Already pickpocketed", 1, 0.65, 0.2)
        elseif (SPELL_FAILED_TARGET_NO_POCKETS and message == SPELL_FAILED_TARGET_NO_POCKETS) or lower:find("no pockets") then
            CancelPendingTimer()
            pickpocketExpireTime = 0
            wasMovingOnCast = false
            ShowIndicator("No pockets to pick", 0.7, 0.7, 0.7)
        elseif (isPickpocketing or GetTime() <= pickpocketExpireTime) and ((ERR_LOOT_WHILE_MOVING and message == ERR_LOOT_WHILE_MOVING) or lower:find("while moving")) then
            CancelPendingTimer()
            pickpocketExpireTime = 0
            wasMovingOnCast = false
            lootAnnounced = true
            ShowIndicator("Stop moving to pickpocket", 1, 0.65, 0.2)
        elseif (isPickpocketing or GetTime() <= pickpocketExpireTime) and lower:find("no loot") then
            CancelPendingTimer()
            pickpocketExpireTime = 0
            wasMovingOnCast = false
            lootAnnounced = true
            ShowIndicator("Nothing picked", 0.7, 0.7, 0.7)
        end
    end
end)

local function PrintStatus()
    local lootState = db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
    local textState = db.showText and "|cff00ff00On|r" or "|cffff0000Off|r"
    print("|cffFFF468PPLoot:|r Autoloot " .. lootState .. " | Visual indicator " .. textState)
end

SLASH_PPLOOT1 = "/pploot"
SlashCmdList["PPLOOT"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")

    if cmd == "" or cmd == "toggle" then
        db.enabled = not db.enabled
        isPickpocketing = false
        pickpocketExpireTime = 0
        lootAnnounced = false
        wasMovingOnCast = false
        CancelPendingTimer()
        PrintStatus()
    elseif cmd == "text" or cmd == "visual" or cmd == "indicator" then
        db.showText = not db.showText
        PrintStatus()
    elseif cmd == "test" then
        if not db.showText then
            print("|cffFFF468PPLoot:|r Visual indicator is currently off. Use |cffffffff/pploot text|r to enable it.")
        else
            ShowIndicator("Pickpocketed: |cffffffff4|r|cffc7c7cfs|r |cffffffff12|r|cffeda55fc|r, |cff1eff00[Battered Junkbox]|r", 1, 0.96, 0.41)
        end
    else
        PrintStatus()
        print("  |cffffffff/pploot|r - Toggle Pick Pocket autoloot on/off")
        print("  |cffffffff/pploot text|r - Toggle floating visual indicator on/off")
        print("  |cffffffff/pploot test|r - Preview the floating indicator")
    end
end
