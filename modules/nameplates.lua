-- modules/nameplates.lua : hide default plates + draw a faithful custom plate.
local SPU = _G["StockPlusUI"]

local module = { name = "nameplates" }
SPU:register_module(module)

local BAR_TEX = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
local FONT    = "Fonts\\FRIZQT__.TTF"
local DAMAGE_FLASH_TIME = 3.0
local MAX_CP  = 5

local db
local plates = {}
local damaged_names = {}
local hidden_holder = CreateFrame("Frame")
hidden_holder:Hide()

-- ---- detection helpers -----------------------------------------------------

local function get_healthbar(frame)
    for _, c in ipairs({ frame:GetChildren() }) do
        if c.GetObjectType and c:GetObjectType() == "StatusBar" then return c end
    end
end

local function get_fontstrings(frame)
    local fs = {}
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            fs[#fs + 1] = r
        end
    end
    return fs
end

local function is_nameplate(frame)
    if plates[frame] then return false end
    return get_healthbar(frame) ~= nil and #get_fontstrings(frame) > 0
end

-- ---- build our custom overlay ----------------------------------------------

local function build_overlay(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    overlay:SetAllPoints(frame)
    overlay:Hide()

    local bar = CreateFrame("StatusBar", nil, overlay)
    bar:SetStatusBarTexture(BAR_TEX)
    bar:SetStatusBarColor(1, 1, 0)
    bar:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    bar:SetWidth(110)
    bar:SetHeight(10)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, 0.6)
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)

    local glow = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetVertexColor(1, 0, 0, 0.55)
    glow:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
    glow:Hide()

    local border = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 0.9)
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)

    local name = overlay:CreateFontString(nil, "OVERLAY")
    name:SetFont(FONT, 10, "OUTLINE")
    name:SetPoint("BOTTOM", bar, "TOP", 0, 5)
    name:SetTextColor(1, 1, 1)

    local level = overlay:CreateFontString(nil, "OVERLAY")
    level:SetFont(FONT, 10, "OUTLINE")
    level:SetPoint("LEFT", bar, "RIGHT", 4, 0)
    level:SetTextColor(1, 0.82, 0)

    local skull = overlay:CreateTexture(nil, "OVERLAY")
    skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    skull:SetWidth(16)
    skull:SetHeight(16)
    skull:SetPoint("LEFT", bar, "RIGHT", 2, 0)
    skull:Hide()

    -- combo point dots, centered below our bar
    local cp = {}
    local size, gap, brd = 8, 3, 1
    local total = MAX_CP * size + (MAX_CP - 1) * gap
    for i = 1, MAX_CP do
        local x = -(total / 2) + (i - 1) * (size + gap) + size / 2
        local dbg = overlay:CreateTexture(nil, "ARTWORK")
        dbg:SetTexture("Interface\\Buttons\\WHITE8X8")
        dbg:SetVertexColor(0, 0, 0, 0.9)
        dbg:SetWidth(size + brd * 2); dbg:SetHeight(size + brd * 2)
        dbg:SetPoint("TOP", bar, "BOTTOM", x, -3)
        dbg:Hide()
        local dot = overlay:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        dot:SetWidth(size); dot:SetHeight(size)
        dot:SetPoint("CENTER", dbg, "CENTER", 0, 0)
        dot:Hide()
        cp[i] = { dot = dot, bg = dbg }
    end

    return { overlay = overlay, bar = bar, name = name, level = level,
             glow = glow, skull = skull, cp = cp }
end

-- ---- register --------------------------------------------------------------

local function register_plate(frame)
    if frame._spu_registered then return end
    frame._spu_registered = true

    local orig_hb = get_healthbar(frame)
    local orig_fs = get_fontstrings(frame)

    local orig_textures = {}
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then
            orig_textures[r] = r:GetTexture()
        end
    end

    -- find the skull texture (shown on ??-level mobs, no target needed)
    local skull_region
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetTexture then
            local tex = tostring(r:GetTexture() or "")
            if tex:find("UI%-TargetingFrame%-Skull") then
                skull_region = r
                break
            end
        end
    end

    local hb_tex, hb_r, hb_g, hb_b, hb_a
    if orig_hb then
        local t = orig_hb:GetStatusBarTexture()
        hb_tex = t and t.GetTexture and t:GetTexture() or BAR_TEX
        hb_r, hb_g, hb_b, hb_a = orig_hb:GetStatusBarColor()
    end

    local castbar
    for _, c in ipairs({ frame:GetChildren() }) do
        if c:GetObjectType() == "StatusBar" and c ~= orig_hb then
            castbar = c
        end
    end

    local data = {
        orig_hb        = orig_hb,
        orig_fs        = orig_fs,
        orig_textures  = orig_textures,
        hb_tex         = hb_tex,
        hb_color       = { hb_r or 1, hb_g or 1, hb_b or 0, hb_a or 1 },
        castbar        = castbar,
        castbar_parent = castbar and castbar:GetParent() or nil,
        ui             = build_overlay(frame),
        hidden         = false,
        _name          = "",
        _level         = "",
        skull_region   = skull_region,
    }
    plates[frame] = data

    frame:HookScript("OnShow", function(self)
        local d = plates[self]
        if db and db.enabled and type(d) == "table" then
            for r in pairs(d.orig_textures) do r:SetTexture(nil) end
        end
    end)
end

-- ---- enable/disable a single plate -----------------------------------------

local function hide_default(data)
    if data.hidden then return end
    data.hidden = true
    if data.castbar then data.castbar:SetParent(hidden_holder) end
    for r in pairs(data.orig_textures) do r:SetTexture(nil) end
    if data.orig_hb then data.orig_hb:SetAlpha(0) end
    data.ui.overlay:Show()
end

local function restore_default(data)
    if not data.hidden then return end
    data.hidden = false
    if data.castbar and data.castbar_parent then
        data.castbar:SetParent(data.castbar_parent)
    end
    for r, tex in pairs(data.orig_textures) do r:SetTexture(tex) end
    if data.orig_hb then
        data.orig_hb:SetAlpha(1)
    end
    for _, fs in ipairs(data.orig_fs) do
        if fs._spu_last then fs:SetText(fs._spu_last) end
    end
    data.ui.overlay:Hide()
end

-- ---- combo point display ---------------------------------------------------

local function update_combo(data, is_target)
    local cp = (is_target and UnitExists("target")) and GetComboPoints("player", "target") or 0
    local full = (cp >= MAX_CP)
    for i = 1, MAX_CP do
        local e = data.ui.cp[i]
        if is_target and cp > 0 then
            e.bg:Show(); e.dot:Show()
            if i <= cp then
                if full then e.dot:SetVertexColor(1.0, 0.85, 0.10, 1.0)
                else         e.dot:SetVertexColor(0.75, 0.75, 0.75, 1.0) end
            else
                e.dot:SetVertexColor(0.25, 0.25, 0.25, 0.9)
            end
        else
            e.bg:Hide(); e.dot:Hide()
        end
    end
end

-- ---- per-plate update ------------------------------------------------------

local function update_plate(frame, data)
    if not db.enabled then
        restore_default(data)
        return
    end
    hide_default(data)

    for _, fs in ipairs(data.orig_fs) do
        local txt = fs:GetText()
        if txt and txt ~= "" then
            fs._spu_last = txt
            if tonumber(txt) then data._level = txt else data._name = txt end
            fs:SetText("")
        end
    end

    data.ui.name:SetText(data._name or "")

    -- Level / skull display.
    local is_skull = data.skull_region and data.skull_region:IsShown()
    if is_skull then
        data.ui.level:SetText("")
        data.ui.skull:Show()
    else
        data.ui.skull:Hide()
        local lvl = tonumber(data._level)
        if lvl and lvl > 0 then
            data.ui.level:SetText(data._level)
            local c = GetQuestDifficultyColor(lvl)
            data.ui.level:SetTextColor(c.r, c.g, c.b)
        else
            data.ui.level:SetText("")
        end
    end

    -- Name red = recently damaged (any source, matched by name via combat log)
    local last_hit = data._name and damaged_names[data._name]
    if last_hit and (GetTime() - last_hit) <= DAMAGE_FLASH_TIME then
        data.ui.name:SetTextColor(1, 0, 0)
    else
        data.ui.name:SetTextColor(1, 1, 1)
    end

    local is_target = frame:GetAlpha() > 0.9 and UnitExists("target")

    -- Glow = aggro on us (target plate only)
    if is_target and UnitIsUnit("targettarget", "player") then
        data.ui.glow:Show()
    else
        data.ui.glow:Hide()
    end

    -- Combo points (target plate only, rogues / feral druids)
    update_combo(data, is_target)

    -- mirror health value + reaction color every pass (handles recycling)
    local hb = data.orig_hb
    if hb then
        local mn, mx = hb:GetMinMaxValues()
        data.ui.bar:SetMinMaxValues(mn, mx)
        data.ui.bar:SetValue(hb:GetValue())
        local cr, cg, cb = hb:GetStatusBarColor()
        if cr then data.ui.bar:SetStatusBarColor(cr, cg, cb) end
    end

    for r in pairs(data.orig_textures) do r:SetTexture(nil) end
end

-- ---- scan ------------------------------------------------------------------

local function scan()
    for _, f in ipairs({ WorldFrame:GetChildren() }) do
        if type(f) == "table" and not plates[f] and is_nameplate(f) then
            register_plate(f)
        end
    end
    for frame, data in pairs(plates) do
        if type(data) == "table" and frame:IsShown() then
            update_plate(frame, data)
        end
    end
end

-- ---- combat log: record which mob names took damage ------------------------

local cl = CreateFrame("Frame")
cl:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
cl:SetScript("OnEvent", function(_, event, timestamp, subevent, srcGUID, srcName,
                                 srcFlags, dstGUID, dstName, dstFlags, ...)
    if not dstName then return end
    if subevent == "SWING_DAMAGE"
       or subevent == "SPELL_DAMAGE"
       or subevent == "SPELL_PERIODIC_DAMAGE"
       or subevent == "RANGE_DAMAGE" then
        damaged_names[dstName] = GetTime()
    end
end)

function module:on_init(settings)
    db = settings
    local poller, acc = CreateFrame("Frame"), 0
    poller:SetScript("OnUpdate", function(_, dt)
        if not db then return end
        acc = acc + dt
        if acc < 0.02 then return end
        acc = 0
        scan()
    end)
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Nameplates", function(panel)
    local n = function() return SPU.db.nameplates end
    local header = SPU:make_header(panel, "Nameplates", nil)
    local sub    = SPU:make_subtitle(panel, "Custom nameplates faithful to the default.", header)

    SPU:make_checkbox(panel, "StockPlusUINameplateEnable", "Enable custom nameplates", sub, -16,
        function() return n().enabled end,
        function(v) n().enabled = v end)
end)
