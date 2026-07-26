-- modules/frame_mover.lua : unlock/move core frames (player, target, focus,
-- minimap, buffs) plus a custom tooltip anchor, with grid, snapping, and
-- floating lock/reset buttons.
local SPU = _G["StockPlusUI"]

local module = { name = "frame_mover" }
SPU:register_module(module)

local db
local GRID_STEP = 32

local movable = {
    { key = "player",  frame = "PlayerFrame",    label = "Player"  },
    { key = "target",  frame = "TargetFrame",    label = "Target"  },
    { key = "focus",   frame = "FocusFrame",     label = "Focus"   },
    { key = "minimap", frame = "MinimapCluster", label = "Minimap" },
    { key = "buffs",   frame = "BuffFrame",      label = "Buffs"   },
}

local movers = {}
local tooltip_anchor
local grid_frame
local lock_button, reset_button

-- grid geometry, computed once when the grid is built (first unlock)
local grid_ox, grid_oy       -- screen origin used for snapping (top-left)
local grid_step_x, grid_step_y

-- ---- reset confirmation popup ----------------------------------------------

StaticPopupDialogs["STOCKPLUSUI_RESET_FRAMES"] = {
    text = "Reset all frame positions to default?",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        db.positions = {}
        for _, entry in ipairs(movable) do
            local f = _G[entry.frame]
            if f and entry._orig and not InCombatLockdown() then
                f:ClearAllPoints()
                f:SetPoint(entry._orig.p, UIParent, entry._orig.rp, entry._orig.x, entry._orig.y)
            end
        end
        if tooltip_anchor then
            tooltip_anchor:ClearAllPoints()
            tooltip_anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 80)
        end
        print("|cff33ff99StockPlusUI|r frame positions reset to default")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- ---- position apply --------------------------------------------------------

local function apply_position(entry)
    if InCombatLockdown() then return end
    local f = _G[entry.frame]
    if not f then return end
    local pos = db.positions and db.positions[entry.key]
    if pos then
        f:ClearAllPoints()
        f:SetPoint(pos.point or "TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
    elseif entry._orig then
        -- no saved position in this profile: restore Blizzard's default
        f:ClearAllPoints()
        f:SetPoint(entry._orig.p, UIParent, entry._orig.rp, entry._orig.x, entry._orig.y)
    end
end

-- ---- mover overlays --------------------------------------------------------

local function make_mover(entry)
    local f = _G[entry.frame]
    if not f then return end

    if not entry._orig and f:GetPoint() then
        local p, _, rp, x, y = f:GetPoint()
        entry._orig = { p = p, rp = rp, x = x, y = y }
    end

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

        local scale  = f:GetEffectiveScale()
        local uscale = UIParent:GetEffectiveScale()
        -- frame's top-left in UIParent units
        local left = f:GetLeft() * scale / uscale
        local top  = f:GetTop()  * scale / uscale

        -- offset from UIParent top-left (grid origin)
        local uh = UIParent:GetHeight()
        local dx = left
        local dy = top - uh

        -- snap using the SAME steps the grid uses, then round to whole pixels
        -- (identical math to the grid lines, so they always align)
        local sx = grid_step_x or GRID_STEP
        local sy = grid_step_y or GRID_STEP
        dx = math.floor(math.floor(dx / sx + 0.5) * sx + 0.5)
        dy = math.floor(math.floor(dy / sy + 0.5) * sy + 0.5)

        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", dx, dy)
        db.positions = db.positions or {}
        db.positions[entry.key] = { point = "TOPLEFT", x = dx, y = dy }
    end)

    f:SetMovable(true)
    movers[entry.key] = mover
end

-- ---- grid frame (created empty at init) ------------------------------------

local function create_grid_frame()
    local grid = CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("MEDIUM")
    grid:Hide()
    grid_frame = grid
end

-- ---- tooltip anchor --------------------------------------------------------

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
        anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -110, 100)
    end

    anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.positions = db.positions or {}
        db.positions.tooltip = { point = point, x = x, y = y }
    end)

    tooltip_anchor = anchor

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if db and db.positions and db.positions.tooltip and tooltip_anchor then
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", tooltip_anchor, "BOTTOMRIGHT", 0, 0)
        end
    end)
end

-- ---- grid (populated lazily on first unlock, when dimensions are final) -----

local grid_built = false

local function make_grid()
    if grid_built then return end
    grid_built = true

    local grid = grid_frame
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()

    -- per-axis step that divides the screen evenly -> lines hit all edges
    local nx = math.floor(w / GRID_STEP + 0.5)
    local ny = math.floor(h / GRID_STEP + 0.5)
    grid_step_x = w / nx
    grid_step_y = h / ny
    grid_ox, grid_oy = 0, 0

    local function vline(x, r, g, b, a)
        local t = grid:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(r, g, b, a)
        t:SetWidth(1)
        t:SetPoint("TOPLEFT", grid, "TOPLEFT", x, 0)
        t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", x, 0)
    end
    local function hline(y, r, g, b, a)
        local t = grid:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(r, g, b, a)
        t:SetHeight(1)
        t:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -y)
        t:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, -y)
    end

    -- draw lines at ROUNDED pixel positions from index (no drift, no gap)
    for i = 0, nx do
        vline(math.floor(i * grid_step_x + 0.5), 1, 1, 1, 0.35)
    end
    for i = 0, ny do
        hline(math.floor(i * grid_step_y + 0.5), 1, 1, 1, 0.35)
    end

    -- true-center green cross (visual reference)
    vline(math.floor(w / 2 + 0.5), 0.2, 1.0, 0.6, 0.8)
    hline(math.floor(h / 2 + 0.5), 0.2, 1.0, 0.6, 0.8)
end

-- ---- floating lock / reset buttons -----------------------------------------

local function make_buttons()
    local btn = CreateFrame("Button", "StockPlusUILockButton", UIParent, "UIPanelButtonTemplate")
    btn:SetSize(120, 28)
    btn:SetPoint("TOP", UIParent, "TOP", -65, -120)
    btn:SetFrameStrata("DIALOG")
    btn:SetText("Lock Frames")
    btn:Hide()
    btn:SetScript("OnClick", function()
        db.unlocked = false
        if SPU.refresh_movers then SPU.refresh_movers() end
    end)
    lock_button = btn

    local reset = CreateFrame("Button", "StockPlusUIResetButton", UIParent, "UIPanelButtonTemplate")
    reset:SetSize(120, 28)
    reset:SetPoint("TOP", UIParent, "TOP", 65, -120)
    reset:SetFrameStrata("DIALOG")
    reset:SetText("Reset Positions")
    reset:Hide()
    reset:SetScript("OnClick", function()
        StaticPopup_Show("STOCKPLUSUI_RESET_FRAMES")
    end)
    reset_button = reset
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
    if lock_button then
        if unlocked then lock_button:Show() else lock_button:Hide() end
    end
    if reset_button then
        if unlocked then reset_button:Show() else reset_button:Hide() end
    end
    if grid_frame then
        if unlocked then
            make_grid()
            grid_frame:Show()
        else
            grid_frame:Hide()
        end
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
    create_grid_frame()
    make_buttons()

    SPU:register_event("PLAYER_ENTERING_WORLD", function()
        for _, entry in ipairs(movable) do apply_position(entry) end
    end)

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
            if v then
                if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
                    InterfaceOptionsFrame:Hide()
                end
                if GameMenuFrame and GameMenuFrame:IsShown() then
                    HideUIPanel(GameMenuFrame)
                end
                if CloseAllWindows then CloseAllWindows() end
            end
        end)
end)
