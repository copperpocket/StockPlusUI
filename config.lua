-- config.lua : parent options panel, shared widget builders, nav plumbing
local SPU = _G["StockPlusUI"]

-- ---- defaults --------------------------------------------------------------

local defaults = {
    action_bar_fader = {
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
        bars = {
            main         = { enabled = false },
            bottom_left  = { enabled = false },
            bottom_right = { enabled = false },
            right_1      = { enabled = false },
            right_2      = { enabled = false },
        },
    },
    gryphon_toggle = {
        hidden = false,
    },
    player_frame_fader = {
        enabled     = false,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    chat_enhance = {
        bg_alpha          = 0.30,
        buttons_alpha     = 1.00,
        hide_buttons      = false,
        faster_text_fade  = false,
        text_visible_time = 10,
        fade_tabs         = false,
        tabs_faded_alpha  = 0.20,
        tabs_shown_alpha  = 1.00,
        fade_time         = 0.25,
        editbox_on_top    = false,
    },
    minimap_fader = {
        enabled     = false,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    buff_fader = {
        enabled     = false,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    party_fader = {
        enabled     = false,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    objective_tracker_fader = {
        enabled     = false,
        faded_alpha = 0.2,
        shown_alpha = 1.0,
        fade_time   = 0.25,
    },
    nameplates = {
        enabled       = false,
        bar_width     = 110,
        bar_height    = 10,
        name_size     = 10,
        level_size    = 10,
        cast_enabled  = true,
        cast_icon     = true,
        cast_name     = true,
        cast_height   = 8,
    },
    conditions = {
        combat       = true,
        target       = true,
        group        = false,
        hp_threshold = 100,
        mp_threshold = 100,
    },
}

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

-- ---- shared widget builders ------------------------------------------------

function SPU:make_header(panel, text, anchor, gap)
    local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    if anchor then
        h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -20)
    else
        h:SetPoint("TOPLEFT", 16, -8)
    end
    h:SetWidth(220)
    h:SetJustifyH("LEFT")
    h:SetText(text)
    h:SetTextColor(0.2, 1.0, 0.6)
    return h
end

function SPU:make_subtitle(panel, text, anchor, gap)
    local s = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -6)
    s:SetWidth(220)
    s:SetJustifyH("LEFT")
    s:SetText(text)
    return s
end

function SPU:make_checkbox(panel, name, label, anchor, gap, get, set)
    local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -6)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnShow",  function(self) self:SetChecked(get()) end)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    return cb
end

function SPU:make_alpha_slider(panel, name, label, anchor, gap, get, set)
    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, gap or -24)
    s:SetMinMaxValues(0, 1)
    s:SetValueStep(0.05)
    s:SetWidth(180)
    _G[s:GetName() .. "Low"]:SetText("0.0")
    _G[s:GetName() .. "High"]:SetText("1.0")
    s:SetScript("OnShow", function(self)
        local v = get() or 0
        self:SetValue(v)
        _G[self:GetName() .. "Text"]:SetText(string.format("%s: %.2f", label, v))
    end)
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        set(value)
        _G[self:GetName() .. "Text"]:SetText(string.format("%s: %.2f", label, value))
    end)
    return s
end

function SPU:make_slider(panel, name, label, anchor, gap, min, max, step, fmt, get, set)
    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, gap or -24)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetWidth(180)
    _G[s:GetName() .. "Low"]:SetText(tostring(min))
    _G[s:GetName() .. "High"]:SetText(tostring(max))
    s:SetScript("OnShow", function(self)
        local v = get() or min
        self:SetValue(v)
        _G[self:GetName() .. "Text"]:SetText(string.format(fmt, v))
    end)
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        set(value)
        _G[self:GetName() .. "Text"]:SetText(string.format(fmt, value))
    end)
    return s
end

function SPU:make_scroll(panel, anchor_below)
    local scroll = CreateFrame("ScrollFrame", (panel:GetName() or "SPUPanel") .. "Scroll", panel, "UIPanelScrollFrameTemplate")
    if anchor_below then
        scroll:SetPoint("TOPLEFT", anchor_below, "BOTTOMLEFT", 0, -12)
    else
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -48)
    end
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(200, 10)
    scroll:SetScrollChild(content)

    local top = CreateFrame("Frame", nil, content)
    top:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    top:SetSize(1, 1)

    return content, scroll, top
end

-- ---- single-panel config with internal nav list ---------------------------

local parent_panel
local pages = {}           -- name -> { button, frame }
local nav_offset
local first_page

local function select_page(name)
    for n, entry in pairs(pages) do
        if n == name then
            entry.frame:Show()
            entry.button:LockHighlight()
        else
            entry.frame:Hide()
            entry.button:UnlockHighlight()
        end
    end
end

local function build_page(page)
    local btn = CreateFrame("Button", nil, parent_panel)
    btn:SetSize(130, 22)
    btn:SetPoint("TOPLEFT", parent_panel, "TOPLEFT", 16, nav_offset)
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("LEFT", 4, 0)
    txt:SetText(page.name)
    btn:SetFontString(txt)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    btn:SetScript("OnClick", function() select_page(page.name) end)
    nav_offset = nav_offset - 24

    local frame = CreateFrame("Frame", "StockPlusUIPage_" .. page.name:gsub("%s", ""), parent_panel)
    frame:SetPoint("TOPLEFT", parent_panel, "TOPLEFT", 160, -16)
    frame:SetPoint("BOTTOMRIGHT", parent_panel, "BOTTOMRIGHT", -16, 16)
    frame:Hide()
    page.build(frame)

    pages[page.name] = { button = btn, frame = frame }
    if not first_page then
        first_page = page.name
        select_page(first_page)
    end
end

-- Build all queued pages, sorted: "Conditions" first, then alphabetical.
function SPU:build_config_pages()
    if not parent_panel then return end
    table.sort(self.config_pages, function(a, b)
        if a.name == "Conditions" then return true end
        if b.name == "Conditions" then return false end
        return a.name < b.name
    end)
    nav_offset = -50
    for i = 1, #self.config_pages do
        build_page(self.config_pages[i])
    end
end

-- register_config now only queues; pages are built (sorted) on PLAYER_LOGIN.
function SPU:register_config(name, build_fn)
    table.insert(self.config_pages, { name = name, build = build_fn })
end

local function build_parent()
    parent_panel = CreateFrame("Frame", "StockPlusUIOptionsPanel", InterfaceOptionsFramePanelContainer)
    parent_panel.name = "StockPlusUI"

    local title = parent_panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("StockPlusUI")
    title:SetTextColor(0.2, 1.0, 0.6)

    local divider = parent_panel:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(1, 1, 1, 0.15)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", parent_panel, "TOPLEFT", 150, -12)
    divider:SetPoint("BOTTOMLEFT", parent_panel, "BOTTOMLEFT", 150, 12)

    InterfaceOptions_AddCategory(parent_panel)
    SPU.options_panel = parent_panel
end

build_parent()
