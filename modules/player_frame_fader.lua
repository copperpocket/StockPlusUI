-- modules/player_frame_fader.lua : fade the player unit frame by state
local SPU = _G["StockPlusUI"]

local module = { name = "player_frame_fader" }
SPU:register_module(module)

SPU:register_config("Player Frame", function(panel)
    local pff = function() return SPU.db.player_frame_fader end

    local header = SPU:make_header(panel, "Player Frame", nil)
    local sub    = SPU:make_subtitle(panel, "Fade the player unit frame based on player state.", header)

    local toggle = SPU:make_checkbox(panel, "StockPlusUIPlayerFade", "Fade player frame", sub, -16,
        function() return pff().enabled end,
        function(v)
            pff().enabled = v
            if SPU.refresh_player_frame then SPU:refresh_player_frame() end
        end)

    SPU:make_alpha_slider(panel, "StockPlusUIPlayerAlpha", "Faded opacity", toggle, -24,
        function() return pff().faded_alpha end,
        function(v)
            pff().faded_alpha = v
            if SPU.refresh_player_frame then SPU:refresh_player_frame() end
        end)
end)

local db
local mouse_over = false
local fader

local function get_frames()
    return { PlayerFrame }
end

local function should_show()
    return SPU:should_ui_show() or mouse_over
end

local current
local function apply()
    if not db or not db.enabled then return end
    local target = should_show() and db.shown_alpha or db.faded_alpha
    if current == target then return end
    current = target
    fader:fade_to(target)
end

SPU.apply_player_frame = apply
function SPU:refresh_player_frame()
    if db and db.enabled then current = nil; apply()
    else fader:set(1.0); current = 1.0 end
end

-- taint-safe hover poll (PlayerFrame IS mouse-enabled, but poll anyway to
-- stay consistent and avoid hooking its secure scripts)
local poller, acc = CreateFrame("Frame"), 0
poller:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    local over = PlayerFrame and PlayerFrame:IsVisible() and MouseIsOver(PlayerFrame)
    if over ~= mouse_over then mouse_over = over; apply() end
end)

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
    apply()
end
