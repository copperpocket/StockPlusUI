-- modules/objective_tracker_fader.lua : fade the quest/objective tracker by state
local SPU = _G["StockPlusUI"]

local module = { name = "objective_tracker_fader" }
SPU:register_module(module)

local db
local mouse_over = false
local fader
local current

-- WatchFrame is the quest/objective tracker in 3.3.5a (non-protected).
local function get_frames()
    return WatchFrame and { WatchFrame } or {}
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

SPU.apply_objectives = apply
function SPU:refresh_objectives()
    if db and db.enabled then current = nil; apply()
    else if fader then fader:set(1.0) end; current = 1.0 end
end

function module:on_init(settings)
    db = settings
    fader = SPU:create_fader(get_frames, db.fade_time)

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
        local over = WatchFrame and WatchFrame:IsVisible() and MouseIsOver(WatchFrame) or false
        if over ~= mouse_over then mouse_over = over; apply() end
    end)

    apply()
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Objectives", function(panel)
    local o = function() return SPU.db.objective_tracker_fader end

    local header = SPU:make_header(panel, "Objectives", nil)
    local sub    = SPU:make_subtitle(panel, "Fade the quest and objective tracker based on player state.", header)

    local toggle = SPU:make_checkbox(panel, "StockPlusUIObjFade", "Fade objective tracker", sub, -16,
        function() return o().enabled end,
        function(v) o().enabled = v; if SPU.refresh_objectives then SPU:refresh_objectives() end end)

    SPU:make_alpha_slider(panel, "StockPlusUIObjAlpha", "Faded opacity", toggle, -24,
        function() return o().faded_alpha end,
        function(v) o().faded_alpha = v; if SPU.refresh_objectives then SPU:refresh_objectives() end end)
end)
