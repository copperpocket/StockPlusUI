-- modules/nameplates.lua : combo points on the target's nameplate.
-- Detects nameplates via WorldFrame scan, identifies the target plate by alpha,
-- and draws combo points (dull until max, gold at 5) for rogues / feral druids.
local SPU = _G["StockPlusUI"]

local module = { name = "nameplates" }
SPU:register_module(module)

local MAX_CP = 5

local db
local plates = {}
local target_plate

-- ---- detection -------------------------------------------------------------

local function get_healthbar(frame)
    for _, c in ipairs({ frame:GetChildren() }) do
        if c.GetObjectType and c:GetObjectType() == "StatusBar" then return c end
    end
end

local function get_nametext(frame)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then return r end
    end
end

local function is_nameplate(frame)
    if plates[frame] then return false end
    return get_healthbar(frame) ~= nil and get_nametext(frame) ~= nil
end

-- ---- combo dots ------------------------------------------------------------

local function build_combo_dots(frame, healthbar)
    local dots = {}
    local size, border, spacing = 8, 1, 3
    local total = MAX_CP * size + (MAX_CP - 1) * spacing
    for i = 1, MAX_CP do
        local x = -(total / 2) + (i - 1) * (size + spacing) + size / 2

        local bg = frame:CreateTexture(nil, "ARTWORK")
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0, 0, 0, 0.9)
        bg:SetWidth(size + border * 2); bg:SetHeight(size + border * 2)
        bg:SetPoint("TOP", healthbar, "BOTTOM", x, -3)
        bg:Hide()

        local dot = frame:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        dot:SetWidth(size); dot:SetHeight(size)
        dot:SetPoint("CENTER", bg, "CENTER", 0, 0)
        dot:Hide()

        dots[i] = { dot = dot, bg = bg }
    end
    return dots
end

local function register_plate(frame)
    if frame._spu_registered then return end
    frame._spu_registered = true
    local hb = get_healthbar(frame)
    plates[frame] = { healthbar = hb, cp = build_combo_dots(frame, hb) }
end

-- ---- target identification -------------------------------------------------

local function is_target_plate(frame)
    if not UnitExists("target") then return false end
    return frame:GetAlpha() > 0.9
end

-- ---- combo rendering -------------------------------------------------------

local function update_combo_display()
    local cp = target_plate and GetComboPoints("player", "target") or 0
    for frame, data in pairs(plates) do
        local show_here = (frame == target_plate) and db.show_combo and UnitExists("target")
        local full = (cp >= MAX_CP)
        for i = 1, MAX_CP do
            local e = data.cp[i]
            if show_here and cp > 0 then
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
end

-- ---- scan ------------------------------------------------------------------

local function scan()
    for _, f in ipairs({ WorldFrame:GetChildren() }) do
        if f and not plates[f] and is_nameplate(f) then
            register_plate(f)
        end
    end
    target_plate = nil
    for frame in pairs(plates) do
        if frame:IsShown() and is_target_plate(frame) then
            target_plate = frame
            break
        end
    end
    update_combo_display()
end

function module:on_init(settings)
    db = settings

    SPU:register_event("UNIT_COMBO_POINTS",     function() update_combo_display() end)
    SPU:register_event("PLAYER_TARGET_CHANGED", function() update_combo_display() end)

    local poller, acc = CreateFrame("Frame"), 0
    poller:SetScript("OnUpdate", function(_, dt)
        if not db or not db.show_combo then return end
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        scan()
    end)
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Nameplates", function(panel)
    local n = function() return SPU.db.nameplates end

    local header = SPU:make_header(panel, "Nameplates", nil)
    local sub    = SPU:make_subtitle(panel, "Enhance the default nameplates.", header)

    SPU:make_checkbox(panel, "StockPlusUINameplateCombo", "Show combo points on target", sub, -16,
        function() return n().show_combo end,
        function(v) n().show_combo = v end)
end)
