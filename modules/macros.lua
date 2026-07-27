-- modules/macros.lua : personal macro helpers (toggle external addon frames).
-- Safe if an addon isn't installed: it silently skips what's missing.

local function toggle_details()
    if not SlashCmdList["DETAILS"] then return false end
    DetailsToggleState = not DetailsToggleState
    SlashCmdList["DETAILS"](DetailsToggleState and "show" or "hide")
    return true
end

local function toggle_zygor()
    local handler = SlashCmdList["ACECONSOLE_ZYGOR"]
    if handler then
        handler("show")   -- /zygor show is itself a toggle
        return true
    end
    return false
end

-- plain = both, Shift = Details only, Ctrl = Zygor only
function ToggleAddons()
    local both = not IsShiftKeyDown() and not IsControlKeyDown()
    local did_any = false

    if IsShiftKeyDown() or both then
        if toggle_details() then did_any = true end
    end
    if IsControlKeyDown() or both then
        if toggle_zygor() then did_any = true end
    end

    if not did_any then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99StockPlusUI|r no matching addon found to toggle")
    end
end
