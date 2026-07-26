-- modules/frame_mover.lua : unlock/move core frames (player, target, focus,
-- minimap, buffs) plus a custom tooltip anchor.
local SPU = _G["StockPlusUI"]

local module = { name = "frame_mover" }
SPU:register_module(module)

local db

-- Frames we allow moving. Add more here later if desired.
local movable = {
    { key = "player",  frame = "PlayerFrame",    label = "Player"  },
    { key = "target",  frame = "TargetFrame",    label = "Target"  },
    { key = "focus",   frame = "FocusFrame",     label = "Focus"   },
    { key = "minimap", frame = "MinimapCluster", label = "Minimap" },
    { key = "buffs",   frame = "BuffFrame",      label = "Buffs"   },
}

local movers = {}          -- key -> mover overlay frame
local tooltip_anchor       -- draggable placeholder marking where tooltips go

-- Apply a saved position to a frame (out of combat only, for secure frames).
local function apply_position(entry)
    if InCombatLockdown() then return end
    local pos = db.positions and db.positions[entry.key]
    local f = _G[entry.frame]
    if f and pos then
        f:ClearAllPoints()
        f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end
end

-- Create a drag overlay for a frame.
local function make_mover(entry)
    local f = _G[entry.frame]
    if not f then return end

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetAllPoints(f)
    mover:SetFrameStrata("HIGH")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    local tex = mover:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(mover)
    tex:SetTexture(0.2, 1.0, 0.6, 0.35)
    local lbl = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("CENTER")
    lbl:SetText(entry.label)

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        f:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        db.positions = db.positions or {}
        db.positions[entry.key] = { point = point, x = x, y = y }
    end)

    f:SetMovable(true)
    movers[entry.key] = mover
end

-- ---- tooltip anchor (special: hook its default anchor) ---------------------

local function make_tooltip_mover()
    local anchor = CreateFrame("Frame", "StockPlusUITooltipAnchor", UIParent)
    anchor:SetSize(130, 30)
    anchor:SetFrameStrata("TOOLTIP")
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetMovable(true)
    anchor:Hide()

    local tex = anchor:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(anchor)
    tex:SetTexture(0.2, 1.0, 0.6, 0.35)
    local lbl = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("CENTER")
    lbl:SetText("Tooltip")

    local pos = db.positions and db.positions.tooltip
    anchor:ClearAllPoints()
    if pos then
        anchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -220, 200)
    end

    anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.positions = db.positions or {}
        db.positions.tooltip = { point = point, x = x, y = y }
    end)

    tooltip_anchor = anchor

    -- Override where the tooltip anchors, only when custom position is enabled.
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if db and db.tooltip_custom and tooltip_anchor then
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", tooltip_anchor, "BOTTOMRIGHT", 0, 0)
        end
    end)
end

-- ---- lock/unlock -----------------------------------------------------------

local function set_unlocked(unlocked)
    for _, entry in ipairs(movable) do
        local mover = movers[entry.key]
        if mover then
            if unlocked then mover:Show() else mover:Hide() end
        end
    end
    if tooltip_anchor then
        if unlocked then tooltip_anchor:Show() else tooltip_anchor:Hide() end
    end
end

SPU.refresh_movers = function()
    set_unlocked(db and db.unlocked)
end

-- ---- init ------------------------------------------------------------------

function module:on_init(settings)
    db = settings

    for _, entry in ipairs(movable) do
        make_mover(entry)
    end
    make_tooltip_mover()

    -- apply saved positions on load and after entering world
    SPU:register_event("PLAYER_ENTERING_WORLD", function()
        for _, entry in ipairs(movable) do apply_position(entry) end
    end)

    -- safety: lock (hide movers) when entering combat so you can't taint
    SPU:register_event("PLAYER_REGEN_DISABLED", function()
        set_unlocked(false)
    end)
    SPU:register_event("PLAYER_REGEN_ENABLED", function()
        if db.unlocked then set_unlocked(true) end
    end)

    for _, entry in ipairs(movable) do apply_position(entry) end
    set_unlocked(db.unlocked)
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Frame Mover", function(panel)
    local m = function() return SPU.db.frame_mover end

    local header = SPU:make_header(panel, "Frame Mover", nil)
    local sub    = SPU:make_subtitle(panel, "Unlock to drag frames and the tooltip anchor. Lock to fix them in place.", header)

    local unlock = SPU:make_checkbox(panel, "StockPlusUIFrameUnlock", "Unlock frames (drag to move)", sub, -16,
        function() return m().unlocked end,
        function(v)
            m().unlocked = v
            if SPU.refresh_movers then SPU.refresh_movers() end
        end)

    local ttc = SPU:make_checkbox(panel, "StockPlusUITooltipCustom", "Custom tooltip position", unlock, -8,
        function() return m().tooltip_custom end,
        function(v) m().tooltip_custom = v end)

    SPU:make_checkbox(panel, "StockPlusUIFrameReset", "(check to reset positions)", ttc, -8,
        function() return false end,
        function(v)
            if v then
                m().positions = {}
                print("|cff33ff99StockPlusUI|r frame positions cleared - type /reload to apply")
            end
        end)
end)
