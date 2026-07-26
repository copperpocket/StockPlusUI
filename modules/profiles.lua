-- modules/profiles.lua : save/switch/copy/delete/reset config profiles.
-- Switching a profile reloads the UI to apply it cleanly.
local SPU = _G["StockPlusUI"]

-- ---- popups ----------------------------------------------------------------

StaticPopupDialogs["STOCKPLUSUI_NEW_PROFILE"] = {
    text = "New profile name:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local name = self.editBox:GetText()
        if SPU:create_profile(name) then
            SPU:set_active_profile(name)
        else
            print("|cff33ff99StockPlusUI|r profile name invalid or already exists")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["STOCKPLUSUI_COPY_PROFILE"] = {
    text = "Copy current profile to new name:",
    button1 = "Copy",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local name = self.editBox:GetText()
        if SPU:copy_profile(SPU:get_active_profile(), name) then
            SPU:set_active_profile(name)
        else
            print("|cff33ff99StockPlusUI|r copy failed (name invalid or exists)")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["STOCKPLUSUI_SWITCH_PROFILE"] = {
    text = "Switch to profile '%s'? The UI will reload.",
    button1 = "Switch",
    button2 = "Cancel",
    OnAccept = function(self, name)
        SPU:set_active_profile(name)   -- reloads
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["STOCKPLUSUI_DELETE_PROFILE"] = {
    text = "Delete profile '%s'? This cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, name)
        if SPU:delete_profile(name) then
            print("|cff33ff99StockPlusUI|r deleted profile: " .. name)
            if SPU.refresh_profiles then SPU:refresh_profiles() end
        else
            print("|cff33ff99StockPlusUI|r cannot delete that profile")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["STOCKPLUSUI_RESET_PROFILE"] = {
    text = "Reset the current profile to addon defaults? This cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        local active = SPU:get_active_profile()
        StockPlusUIDB.profiles[active] = {}
        ReloadUI()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- ---- config page -----------------------------------------------------------

SPU:register_config("Profiles", function(panel)
    local header = SPU:make_header(panel, "Profiles", nil)
    local sub    = SPU:make_subtitle(panel,
        "Save and switch between configuration profiles. Switching reloads the UI.", header)

    local current = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    current:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
    current:SetText("Active: " .. (SPU:get_active_profile() or "?"))

    local content, scroll, top = SPU:make_scroll(panel, current)

    local newb, copyb, resetb

    local function refresh_list()
        if content._buttons then
            for _, b in ipairs(content._buttons) do b:Hide() end
        end
        content._buttons = {}

        local names = SPU:get_profile_names()
        local anchor = top
        for i, name in ipairs(names) do
            local active = (name == SPU:get_active_profile())

            local row = CreateFrame("Button", nil, content)
            row:SetSize(180, 22)
            row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", 2, 0)
            txt:SetText((active and "|cff33ff99> " or "   ") .. name .. (active and "|r" or ""))
            row:SetFontString(txt)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row:GetHighlightTexture():SetBlendMode("ADD")

            row:SetScript("OnClick", function()
                if name ~= SPU:get_active_profile() then
                    StaticPopup_Show("STOCKPLUSUI_SWITCH_PROFILE", name, nil, name)
                end
            end)

            if name ~= "Main" and not active then
                local del = CreateFrame("Button", nil, row)
                del:SetSize(18, 18)
                del:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                local dtxt = del:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                dtxt:SetPoint("CENTER")
                dtxt:SetText("|cffff5555x|r")
                del:SetFontString(dtxt)
                del:SetScript("OnClick", function()
                    StaticPopup_Show("STOCKPLUSUI_DELETE_PROFILE", name, nil, name)
                end)
            end

            content._buttons[#content._buttons + 1] = row
            anchor = row
        end
        return anchor
    end

    local last = refresh_list()

    newb = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    newb:SetSize(85, 24)
    newb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -16)
    newb:SetText("New")
    newb:SetScript("OnClick", function() StaticPopup_Show("STOCKPLUSUI_NEW_PROFILE") end)

    copyb = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    copyb:SetSize(85, 24)
    copyb:SetPoint("LEFT", newb, "RIGHT", 6, 0)
    copyb:SetText("Copy")
    copyb:SetScript("OnClick", function() StaticPopup_Show("STOCKPLUSUI_COPY_PROFILE") end)

    resetb = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetb:SetSize(176, 24)
    resetb:SetPoint("TOPLEFT", newb, "BOTTOMLEFT", 0, -8)
    resetb:SetText("Reset to Defaults")
    resetb:SetScript("OnClick", function() StaticPopup_Show("STOCKPLUSUI_RESET_PROFILE") end)

    content:SetHeight(420)

    SPU.refresh_profiles = function()
        current:SetText("Active: " .. (SPU:get_active_profile() or "?"))
        local a = refresh_list()
        newb:ClearAllPoints()
        newb:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -16)
        resetb:ClearAllPoints()
        resetb:SetPoint("TOPLEFT", newb, "BOTTOMLEFT", 0, -8)
    end
end)
