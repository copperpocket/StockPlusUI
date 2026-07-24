-- modules/minimap_fader.lua : fade the minimap cluster by player state.
-- Engine-drawn blips (party/raid dots, POI/quest "!") ignore SetAlpha, so we
-- hard-hide the Minimap surface at the end of the fade-out to remove them,
-- and show it again when fading back in. Faded = fully hidden (alpha 0).
local SPU = _G["StockPlusUI"]

local module = { name = "minimap_fader" }
SPU:register_module(module)

local FADED_ALPHA = 0   -- minimap fades fully out (engine blips can't be alpha'd)

local db
local mouse_over = false
local current

local function should_show()
    return SPU:should_ui_show() or mouse_over
end

-- ---- fade driver with completion (hides Minimap surface when fully out) -----

local driver = CreateFrame("Frame")
driver:Hide()
local from, to, elapsed, dur = 1, 1, 0, 0

local function set_alpha(a)
    if MinimapCluster then MinimapCluster:SetAlpha(a) end
end

driver:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    local t = (dur > 0) and (elapsed / dur) or 1
    if t >= 1 then
        set_alpha(to)
        self:Hide()
        -- fade finished: if we faded OUT, hide the map surface to kill blips
        if to <= 0.001 and not should_show() then
            if Minimap then Minimap:Hide() end
        end
    else
        set_alpha(from + (to - from) * t)
    end
end)

local function start_fade(target)
    from    = MinimapCluster and MinimapCluster:GetAlpha() or target
    to      = target
    elapsed = 0
    dur     = db.fade_time or 0.25
    if dur <= 0 or from == to then
        set_alpha(target)
        driver:Hide()
        if target <= 0.001 and not should_show() then
            if Minimap then Minimap:Hide() end
        end
    else
        driver:Show()
    end
end

-- ---- apply -----------------------------------------------------------------

local function apply()
    if not db or not db.enabled then return end
    local show = should_show()
    local target = show and db.shown_alpha or FADED_ALPHA
    if current == target then return end
    current = target

    if show then
        -- fading IN: reveal the map surface first so blips return, then fade up
        if Minimap then Minimap:Show() end
    end
    start_fade(target)
end

SPU.apply_minimap = apply
function SPU:refresh_minimap()
    if db and db.enabled then
        current = nil
        apply()
    else
        driver:Hide()
        if Minimap then Minimap:Show() end
        if MinimapCluster then MinimapCluster:SetAlpha(1.0) end
        current = 1.0
    end
end

-- ---- init ------------------------------------------------------------------

function module:on_init(settings)
    db = settings

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
    local sub    = SPU:make_subtitle(panel, "Fade the minimap and all its elements based on player state.", header)

    SPU:make_checkbox(panel, "StockPlusUIMinimapFade", "Fade minimap", sub, -16,
        function() return m().enabled end,
        function(v) m().enabled = v; if SPU.refresh_minimap then SPU:refresh_minimap() end end)
end)
