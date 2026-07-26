-- modules/minimap_fader.lua : keep the minimap map always visible while its
-- chrome (buttons, clock, zone text, etc.) fades on shared UI conditions.
local SPU = _G["StockPlusUI"]

local module = { name = "minimap_fader" }
SPU:register_module(module)

local db
local mouse_over = false
local fader
local current

-- Chrome = everything around the minimap except the map itself. These fade as
-- a group on conditions; the Minimap frame stays fully visible.
local chrome_frames = {
    "MinimapZoomIn",
    "MinimapZoomOut",
    "TimeManagerClockButton",
    "MiniMapTrackingFrame",          -- container (background)
    "MiniMapTrackingButton",         -- the button
    "MiniMapTrackingButtonBorder",   -- border ring
    "MiniMapTrackingIcon",           -- the tracking icon itself
    "MiniMapTrackingBackground",
    "GameTimeFrame",
    "MiniMapWorldMapButton",
    "MinimapZoneTextButton",
    "MinimapBorderTop",
    "MinimapToggleButton",
}

local function get_chrome()
    local out = {}
    for i = 1, #chrome_frames do
        local f = _G[chrome_frames[i]]
        if f then out[#out + 1] = f end
    end
    return out
end

local function should_show()
    return SPU:should_ui_show() or mouse_over
end

local function apply()
    if not db or not db.enabled then return end
    local target = should_show() and db.shown_alpha or db.faded_alpha
    if current == target then return end
    current = target
    fader:fade_to(target)
end

SPU.apply_minimap = apply
function SPU:refresh_minimap()
    if db and db.enabled then
        current = nil
        apply()
    else
        if fader then fader:set(1.0) end
        current = 1.0
    end
end

-- ---- init ------------------------------------------------------------------

function module:on_init(settings)
    db = settings
    fader = SPU:create_fader(get_chrome, db.fade_time)

    SPU:register_event("PLAYER_REGEN_DISABLED",  apply)
    SPU:register_event("PLAYER_REGEN_ENABLED",   apply)
    SPU:register_event("PLAYER_TARGET_CHANGED",  apply)
    SPU:register_event("PLAYER_ENTERING_WORLD",  apply)
    SPU:register_event("UNIT_HEALTH",       function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_MANA",         function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_RAGE",         function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_ENERGY",       function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_RUNIC_POWER",  function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_DISPLAYPOWER", function(_, u) if u == "player" then apply() end end)

    -- hover over the whole minimap area keeps chrome shown
    local poller, acc = CreateFrame("Frame"), 0
    poller:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        local over = MinimapCluster and MinimapCluster:IsVisible() and MouseIsOver(MinimapCluster) or false
        if over ~= mouse_over then mouse_over = over; apply() end
    end)

    apply()
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Minimap", function(panel)
    local m = function() return SPU.db.minimap_fader end

    local header = SPU:make_header(panel, "Minimap", nil)
    local sub    = SPU:make_subtitle(panel, "Keep the minimap visible while its buttons, clock, and zone text fade with UI state.", header)

    local toggle = SPU:make_checkbox(panel, "StockPlusUIMinimapFade", "Fade minimap chrome (keep map visible)", sub, -16,
        function() return m().enabled end,
        function(v) m().enabled = v; if SPU.refresh_minimap then SPU:refresh_minimap() end end)

    SPU:make_alpha_slider(panel, "StockPlusUIMinimapAlpha", "Faded chrome opacity", toggle, -24,
        function() return m().faded_alpha end,
        function(v) m().faded_alpha = v; if SPU.refresh_minimap then SPU:refresh_minimap() end end)
end)
