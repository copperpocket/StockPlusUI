-- config.lua : parent options panel, shared widget builders, child-page plumbing
local SPU = _G["StockPlusUI"]

-- ---- defaults --------------------------------------------------------------

local defaults = {
    action_bar_fader = {
        faded_alpha = 0.2,   -- opacity when hidden (set 0.0 for fully invisible)
        shown_alpha = 1.0,
        fade_time   = 0.25,  -- seconds for the alpha transition
        bars = {
            main         = { enabled = true },
            bottom_left  = { enabled = true },
            bottom_right = { enabled = true },
            right_1      = { enabled = true },
            right_2      = { enabled = true },
        },
    },
    gryphon_toggle = {
        hidden = false,   -- default: gryphons SHOWN (faithful to stock UI)
    },
    player_frame_fader = {
        enabled     = true,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    chat_enhance = {
        bg_alpha          = 0.30,
        buttons_alpha     = 1.00,
        hide_buttons      = false,
        faster_text_fade  = false,   -- OFF = native text fade timing
        text_visible_time = 10,
        fade_tabs         = false,   -- OFF = native chat fade behavior
        tabs_faded_alpha  = 0.20,
        tabs_shown_alpha  = 1.00,
        fade_time         = 0.25,
        editbox_on_top = false,
    },
    minimap_fader = {
        enabled     = true,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    buff_fader = {
        enabled     = true,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    party_fader = {
        enabled     = true,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    objective_tracker_fader = {
        enabled     = true,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
}

-- Recursively merge defaults into db, descending into nested tables.
local function deep_merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            deep_merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function SPU:apply_defaults(db)
    deep_merge(db, defaults)
end

-- ---- shared widget builders (exposed on SPU so modules can use them) --------

-- Section header inside a page.
function SPU:make_header(panel, text, anchor, gap)
    local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    if anchor then
        h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -20)
    else
        h:SetPoint("TOPLEFT", 16, -16)
    end
    h:SetText(text)
    h:SetTextColor(0.2, 1.0, 0.6)
    return h
end

-- Small descriptive subtitle line.
function SPU:make_subtitle(panel, text, anchor, gap)
    local s = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -8)
    s:SetText(text)
    return s
end

-- Checkbox bound to get()/set(bool).
function SPU:make_checkbox(panel, name, label, anchor, gap, get, set)
    local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -6)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnShow",  function(self) self:SetChecked(get()) end)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    return cb
end

-- 0.0-1.0 opacity slider bound to get()/set(value).
function SPU:make_alpha_slider(panel, name, label, anchor, gap, get, set)
    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, gap or -24)
    s:SetMinMaxValues(0, 1)
    s:SetValueStep(0.05)
    s:SetWidth(240)
    _G[s:GetName() .. "Low"]:SetText("0.0")
    _G[s:GetName() .. "High"]:SetText("1.0")
    s:SetScript("OnShow", function(self)
        self:SetValue(get())
        _G[self:GetName() .. "Text"]:SetText(string.format("%s: %.2f", label, get()))
    end)
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        set(value)
        _G[self:GetName() .. "Text"]:SetText(string.format("%s: %.2f", label, value))
    end)
    return s
end

-- Generic numeric slider bound to get()/set(value), with custom range + label fmt.
function SPU:make_slider(panel, name, label, anchor, gap, min, max, step, fmt, get, set)
    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, gap or -24)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetWidth(240)
    _G[s:GetName() .. "Low"]:SetText(tostring(min))
    _G[s:GetName() .. "High"]:SetText(tostring(max))
    s:SetScript("OnShow", function(self)
        self:SetValue(get())
        _G[self:GetName() .. "Text"]:SetText(string.format(fmt, get()))
    end)
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        set(value)
        _G[self:GetName() .. "Text"]:SetText(string.format(fmt, value))
    end)
    return s
end


-- ---- parent + child page plumbing ------------------------------------------

local parent_panel

-- Build a child page under the parent category and hand it to build_fn.
local function build_child(page)
    local child = CreateFrame("Frame", "StockPlusUIConfig_" .. page.name:gsub("%s", ""), InterfaceOptionsFramePanelContainer)
    child.name   = page.name
    child.parent = parent_panel.name   -- nests under "StockPlusUI" in the tree
    page.build(child)
    InterfaceOptions_AddCategory(child)
end

-- register_config: if the parent already exists, build immediately; otherwise
-- it stays queued in SPU.config_pages and gets built when the parent is created.
function SPU:register_config(name, build_fn)
    local page = { name = name, build = build_fn }
    table.insert(self.config_pages, page)
    if parent_panel then
        build_child(page)
    end
end

local function build_parent()
    parent_panel = CreateFrame("Frame", "StockPlusUIOptionsPanel", InterfaceOptionsFramePanelContainer)
    parent_panel.name = "StockPlusUI"

    SPU:make_header(parent_panel, "StockPlusUI", nil)
    local sub = SPU:make_subtitle(parent_panel,
        "A faithful overhaul of the default UI. Select a section on the left.",
        parent_panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"))
    -- (the throwaway fontstring above just gives make_subtitle an anchor; simpler:)
    sub:ClearAllPoints()
    sub:SetPoint("TOPLEFT", 16, -44)

    InterfaceOptions_AddCategory(parent_panel)
    SPU.options_panel = parent_panel

    -- Build any pages modules queued before us.
    for i = 1, #SPU.config_pages do
        build_child(SPU.config_pages[i])
    end
end

build_parent()
