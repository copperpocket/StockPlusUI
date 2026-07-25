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
        h:SetPoint("TOPLEFT", 16, -8)
    end
    h:SetWidth(220)                 -- constrain to content column
    h:SetJustifyH("LEFT")
    h:SetText(text)
    h:SetTextColor(0.2, 1.0, 0.6)
    return h
end


-- Small descriptive subtitle line.
function SPU:make_subtitle(panel, text, anchor, gap)
    local s = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -6)
    s:SetWidth(220)                 -- wrap long subtitles
    s:SetJustifyH("LEFT")
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
    s:SetWidth(160)
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

-- Generic numeric slider bound to get()/set(value), with custom range + label fmt.
function SPU:make_slider(panel, name, label, anchor, gap, min, max, step, fmt, get, set)
    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, gap or -24)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetWidth(160)
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

-- Wrap a config panel in a scroll frame. Returns a "content" frame to anchor
-- widgets to. Content grows; scrollbar appears on overflow.
function SPU:make_scroll(panel, anchor_below)
    local scroll = CreateFrame("ScrollFrame", (panel:GetName() or "SPUPanel") .. "Scroll", panel, "UIPanelScrollFrameTemplate")
    if anchor_below then
        scroll:SetPoint("TOPLEFT", anchor_below, "BOTTOMLEFT", 0, -12)
    else
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -48)
    end
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 8)

    if scroll.SetClipsChildren then
        scroll:SetClipsChildren(true)
    end

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
local nav_offset = -50     -- y for stacking nav buttons
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
    -- left-column nav button
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

    -- right-column content frame (build_fn populates this)
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

function SPU:register_config(name, build_fn)
    local page = { name = name, build = build_fn }
    table.insert(self.config_pages, page)
    if parent_panel then
        build_page(page)
    end
end

local function build_parent()
    parent_panel = CreateFrame("Frame", "StockPlusUIOptionsPanel", InterfaceOptionsFramePanelContainer)
    parent_panel.name = "StockPlusUI"

    local title = parent_panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("StockPlusUI")
    title:SetTextColor(0.2, 1.0, 0.6)

    -- vertical divider between nav and content
    local divider = parent_panel:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(1, 1, 1, 0.15)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", parent_panel, "TOPLEFT", 150, -12)
    divider:SetPoint("BOTTOMLEFT", parent_panel, "BOTTOMLEFT", 150, 12)

    InterfaceOptions_AddCategory(parent_panel)
    SPU.options_panel = parent_panel

    for i = 1, #SPU.config_pages do
        build_page(SPU.config_pages[i])
    end
end

build_parent()
