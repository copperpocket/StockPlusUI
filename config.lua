-- config.lua : default settings + Interface Options panel
local SPU = _G["StockPlusUI"]

-- Central defaults. Modules read their own sub-table.
local defaults = {
    action_bar_fader = {
        enabled     = true,
        faded_alpha = 0.2,   -- opacity when hidden (set 0.0 for fully invisible)
        shown_alpha = 1.0,
        fade_time   = 0.25,  -- seconds for the alpha transition
    },
    gryphon_toggle = {
        hidden = false,   -- default: gryphons SHOWN (faithful to stock UI)
    },
}

-- Shallow-merge defaults into db without clobbering saved user values.
function SPU:apply_defaults(db)
    for section, opts in pairs(defaults) do
        db[section] = db[section] or {}
        for k, v in pairs(opts) do
            if db[section][k] == nil then
                db[section][k] = v
            end
        end
    end
end

-- Build the options panel shown under ESC > Interface > AddOns > StockPlusUI.
local function build_panel()
    local panel = CreateFrame("Frame", "StockPlusUIOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "StockPlusUI"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("StockPlusUI")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("A faithful overhaul of the default UI")

    -- Enable checkbox for the fader module.
    local enable = CreateFrame("CheckButton", "StockPlusUIEnableFader", panel, "InterfaceOptionsCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    _G[enable:GetName() .. "Text"]:SetText("Enable action bar fading")
    enable:SetScript("OnShow", function(self)
        self:SetChecked(SPU.db.action_bar_fader.enabled)
    end)
    enable:SetScript("OnClick", function(self)
        SPU.db.action_bar_fader.enabled = self:GetChecked() and true or false
        if SPU.refresh_fader then SPU:refresh_fader() end
    end)

    -- Faded-alpha slider (0.0 - 1.0).
    local slider = CreateFrame("Slider", "StockPlusUIFadedAlpha", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 4, -32)
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(0.05)
    slider:SetWidth(240)
    _G[slider:GetName() .. "Low"]:SetText("0.0")
    _G[slider:GetName() .. "High"]:SetText("1.0")
    _G[slider:GetName() .. "Text"]:SetText("Faded opacity")
    slider:SetScript("OnShow", function(self)
        self:SetValue(SPU.db.action_bar_fader.faded_alpha)
    end)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20  -- snap to step
        SPU.db.action_bar_fader.faded_alpha = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Faded opacity: %.2f", value))
        if SPU.refresh_fader then SPU:refresh_fader() end
    end)

    -- Hide gryphons checkbox.
    local gryphons = CreateFrame("CheckButton", "StockPlusUIHideGryphons", panel, "InterfaceOptionsCheckButtonTemplate")
    gryphons:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, -24)
    _G[gryphons:GetName() .. "Text"]:SetText("Hide action bar gryphons")
    gryphons:SetScript("OnShow", function(self)
        self:SetChecked(SPU.db.gryphon_toggle.hidden)
    end)
    gryphons:SetScript("OnClick", function(self)
        SPU.db.gryphon_toggle.hidden = self:GetChecked() and true or false
        if SPU.refresh_gryphons then SPU:refresh_gryphons() end
    end)

    InterfaceOptions_AddCategory(panel)
    SPU.options_panel = panel
end

build_panel()
