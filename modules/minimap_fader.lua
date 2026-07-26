-- modules/minimap_fader.lua : fade the minimap chrome (and optionally the map
-- itself) on shared UI conditions. The map can stay always-visible or fade too.
local SPU = _G["StockPlusUI"]

local module = { name = "minimap_fader" }
SPU:register_module(module)

local db
local mouse_over = false
local fader
local current

-- Chrome = everything around the minimap except the map itself.
local chrome_frames = {
    "MinimapZoomIn",
    "MinimapZoomOut",
    "TimeManagerClockButton",
    "MiniMapTrackingFrame",
    "MiniMapTrackingButton",
    "MiniMapTrackingButtonBorder",
    "MiniMapTrackingIcon",
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

-- ---- map fade driver (separate, so it can hide the map to kill blips) ------

local map_driver = CreateFrame("Frame")
map_driver:Hide()
local m_from, m_to, m_elapsed, m_dur = 1, 1, 0, 0

local function set_map_alpha(a)
    if Minimap then Minimap:SetAlpha(a) end
end

map_driver:SetScript("OnUpdate", function(self, dt)
    m_elapsed = m_elapsed + dt
    local t = (m_dur > 0) and (m_elapsed / m_dur) or 1
    if t >= 1 then
        set_map_alpha(m_to)
        self:Hide()
        -- fully faded: hide the map so engine blips vanish too
        if m_to <= 0.001 and not should_show() then
            if Minimap then Minimap:Hide() end
        end
    else
        set_map_alpha(m_from + (m_to - m_from) * t)
    end
end)

local function fade_map_to(target)
    m_from    = Minimap and Minimap:GetAlpha() or target
    m_to      = target
    m_elapsed = 0
    m_dur     = db.fade_time or 0.25
    if m_dur <= 0 or m_from == m_to then
        set_map_alpha(target)
        map_driver:Hide()
        if target <= 0.001 and not should_show() then
            if Minimap then Minimap:Hide() end
        end
    else
        map_driver:Show()
    end
end

-- ---- apply -----------------------------------------------------------------

local current_map
local function apply()
    if not db or not db.enabled then return end
    local show = should_show()

    -- chrome fades to faded_alpha (or 0)
    local target = show and db.shown_alpha or db.faded_alpha
    if current ~= target then
        current = target
        fader:fade_to(target)
    end

    -- map: fade too only if fade_map is on; otherwise always full/visible
    if db.fade_map then
        local map_target = show and 1.0 or 0.0
        if current_map ~= map_target then
            current_map = map_target
            if show and Minimap then Minimap:Show() end
            fade_map_to(map_target)
        end
    else
        if current_map ~= 1.0 then
            current_map = 1.0
            map_driver:Hide()
            if Minimap then Minimap:Show(); Minimap:SetAlpha(1.0) end
        end
    end
end

SPU.apply_minimap = apply
function SPU:refresh_minimap()
    if db and db.enabled then
        current = nil
        current_map = nil
        apply()
    else
        if fader then fader:set(1.0) end
        current = 1.0
        current_map = 1.0
        map_driver:Hide()
        if Minimap then Minimap:Show(); Minimap:SetAlpha(1.0) end
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
    local sub    = SPU:make_subtitle(panel, "Fade the minimap chrome, and optionally the map itself, with UI state.", header)

    local toggle = SPU:make_checkbox(panel, "StockPlusUIMinimapFade", "Fade minimap chrome", sub, -16,
        function() return m().enabled end,
        function(v) m().enabled = v; if SPU.refresh_minimap then SPU:refresh_minimap() end end)

    local fademap = SPU:make_checkbox(panel, "StockPlusUIMinimapFadeMap", "Also fade the minimap itself", toggle, -8,
        function() return m().fade_map end,
        function(v) m().fade_map = v; if SPU.refresh_minimap then SPU:refresh_minimap() end end)

    SPU:make_alpha_slider(panel, "StockPlusUIMinimapAlpha", "Faded chrome opacity", fademap, -24,
        function() return m().faded_alpha end,
        function(v) m().faded_alpha = v; if SPU.refresh_minimap then SPU:refresh_minimap() end end)
end)
