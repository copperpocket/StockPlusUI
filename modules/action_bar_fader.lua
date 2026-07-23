-- modules/action_bar_fader.lua : auto-fade action bars by player state
local SPU = _G["StockPlusUI"]

local fader = { name = "action_bar_fader" }
SPU:register_module(fader)

local bars = {
    "MainMenuBarArtFrame",   -- main bar art + buttons container
    "BonusActionBarFrame",   -- stance/bonus bar overlay
    "MultiBarBottomLeft",    -- bottom-left
    "MultiBarBottomRight",   -- bottom-right
    "MultiBarRight",         -- right bar 1
    "MultiBarLeft",          -- right bar 2
    "MainMenuExpBar",        -- experience bar
    "ReputationWatchBar",    -- reputation watch bar
}


local db
local mouse_over = false

-- ---- state evaluation ------------------------------------------------------

local function is_power_at_default()
    local power_type = UnitPowerType("player")
    local cur        = UnitPower("player")
    local max        = UnitPowerMax("player")
    if power_type == 1 or power_type == 6 then   -- Rage / Runic Power
        return cur == 0
    else                                          -- Mana / Energy / Focus
        return cur >= max
    end
end

local function should_show()
    if InCombatLockdown() then return true end
    if UnitExists("target") then return true end
    if UnitHealth("player") < UnitHealthMax("player") then return true end
    if not is_power_at_default() then return true end
    if mouse_over then return true end
    return false
end

-- ---- fade driver (taint-safe: only SetAlpha, never writes fields) ----------
-- IMPORTANT: do NOT use UIFrameFade on these secure frames. It writes
-- frame.fadeInfo onto them, which taints the bars and breaks keybinds.

local fade_driver = CreateFrame("Frame")
fade_driver:Hide()

local fade_from, fade_to, fade_elapsed, fade_duration = 1, 1, 0, 0

local function set_bars_alpha(a)
    for i = 1, #bars do
        local f = _G[bars[i]]
        if f then f:SetAlpha(a) end   -- method call, non-protected, safe
    end
end

fade_driver:SetScript("OnUpdate", function(self, elapsed)
    fade_elapsed = fade_elapsed + elapsed
    local t = (fade_duration > 0) and (fade_elapsed / fade_duration) or 1
    if t >= 1 then
        set_bars_alpha(fade_to)
        self:Hide()
    else
        set_bars_alpha(fade_from + (fade_to - fade_from) * t)
    end
end)

local function start_fade(target)
    local first = _G[bars[1]]
    fade_from     = first and first:GetAlpha() or target
    fade_to       = target
    fade_elapsed  = 0
    fade_duration = db.fade_time or 0.25
    if fade_duration <= 0 or fade_from == fade_to then
        set_bars_alpha(target)
        fade_driver:Hide()
    else
        fade_driver:Show()
    end
end

-- ---- applying the fade -----------------------------------------------------

local current_target

local function apply_fade()
    if not db or not db.enabled then return end
    local target = should_show() and db.shown_alpha or db.faded_alpha
    if current_target == target then return end
    current_target = target
    start_fade(target)
end

SPU.apply_fade = apply_fade

function SPU:refresh_fader()
    if db and db.enabled then
        current_target = nil
        apply_fade()
    else
        fade_driver:Hide()
        set_bars_alpha(1.0)
        current_target = 1.0
    end
end

-- ---- mouse hover tracking (taint-safe polling, no HookScript) --------------

local hover_poller    = CreateFrame("Frame")
local POLL_INTERVAL   = 0.1
local since_last_poll = 0

local function is_mouse_over_bars()
    for i = 1, #bars do
        local f = _G[bars[i]]
        if f and f:IsVisible() and MouseIsOver(f) then
            return true
        end
    end
    return false
end

hover_poller:SetScript("OnUpdate", function(_, elapsed)
    since_last_poll = since_last_poll + elapsed
    if since_last_poll < POLL_INTERVAL then return end
    since_last_poll = 0
    local now_over = is_mouse_over_bars()
    if now_over ~= mouse_over then
        mouse_over = now_over
        apply_fade()
    end
end)

-- ---- init & events ---------------------------------------------------------

function fader:on_init(settings)
    db = settings

    SPU:register_event("PLAYER_REGEN_DISABLED",  apply_fade)
    SPU:register_event("PLAYER_REGEN_ENABLED",   apply_fade)
    SPU:register_event("PLAYER_TARGET_CHANGED",  apply_fade)
    SPU:register_event("PLAYER_ENTERING_WORLD",  apply_fade)
    SPU:register_event("ACTIONBAR_UPDATE_STATE", apply_fade)

    SPU:register_event("UNIT_HEALTH",       function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_MANA",         function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_RAGE",         function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_ENERGY",       function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_RUNIC_POWER",  function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" then apply_fade() end end)

    apply_fade()
end
