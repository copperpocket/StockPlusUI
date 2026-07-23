-- modules/action_bar_fader.lua : auto-fade action bars by player state
local SPU = _G["StockPlusUI"]

local fader = { name = "action_bar_fader" }
SPU:register_module(fader)

-- The Blizzard bar frames we fade. These are the parent frames; fading the
-- parent fades all its buttons in one SetAlpha call (cheap).
local bars = {
    "MainMenuBarArtFrame",   -- main bar art + buttons container
    "BonusActionBarFrame",   -- stance/bonus bar overlay
    "MultiBarBottomLeft",    -- bottom-left
    "MultiBarBottomRight",   -- bottom-right
    "MultiBarRight",         -- right bar 1
    "MultiBarLeft",          -- right bar 2
}

local db                 -- module settings (set in on_init)
local current_alpha      -- last applied alpha, avoids redundant fades
local mouse_over = false -- tracked via hover hooks

-- ---- state evaluation ------------------------------------------------------

local function is_power_at_default()
    -- Rage (1) and RunicPower (6) default to 0; "active" means > 0.
    -- Mana/Energy/Focus default to max; "active" means current < max.
    local power_type = UnitPowerType("player")
    local cur        = UnitPower("player")
    local max        = UnitPowerMax("player")

    if power_type == 1 or power_type == 6 then   -- Rage / Runic Power
        return cur == 0
    else                                          -- Mana / Energy / Focus
        return cur >= max
    end
end

-- Returns true if bars should be fully shown.
local function should_show()
    if InCombatLockdown() then return true end                             -- 1. in combat
    if UnitExists("target") then return true end                           -- 2. has target
    if UnitHealth("player") < UnitHealthMax("player") then return true end  -- 3a. missing HP
    if not is_power_at_default() then return true end                      -- 3b. non-default power
    if mouse_over then return true end                                     -- 4. hovering a bar
    return false
end

-- ---- applying the fade -----------------------------------------------------

local function apply_fade()
    if not db or not db.enabled then return end

    local target = should_show() and db.shown_alpha or db.faded_alpha
    if current_alpha == target then return end  -- nothing to do
    current_alpha = target

    for i = 1, #bars do
        local f = _G[bars[i]]
        if f then
            UIFrameFadeRemoveFrame(f)  -- cancel any in-flight fade first
            local fade_info = {
                mode         = target > f:GetAlpha() and "IN" or "OUT",
                timeToFade   = db.fade_time,
                startAlpha   = f:GetAlpha(),
                endAlpha     = target,
                finishedFunc = nil,
            }
            UIFrameFade(f, fade_info)
        end
    end
end

SPU.apply_fade = apply_fade  -- expose for refresh_fader

-- Called by config when settings change.
function SPU:refresh_fader()
    if db and db.enabled then
        current_alpha = nil   -- force reapply
        apply_fade()
    else
        -- disabled: restore full opacity immediately
        for i = 1, #bars do
            local f = _G[bars[i]]
            if f then UIFrameFadeRemoveFrame(f); f:SetAlpha(1.0) end
        end
        current_alpha = 1.0
    end
end

-- ---- mouse hover tracking --------------------------------------------------

local function hook_hover()
    -- Hook enter/leave on each bar so hovering forces show.
    for i = 1, #bars do
        local f = _G[bars[i]]
        if f then
            f:HookScript("OnEnter", function() mouse_over = true;  apply_fade() end)
            f:HookScript("OnLeave", function() mouse_over = false; apply_fade() end)
        end
    end
end

-- ---- init & events ---------------------------------------------------------

function fader:on_init(settings)
    db = settings
    hook_hover()

    -- Register the events that change our state. All route to apply_fade.
    SPU:register_event("PLAYER_REGEN_DISABLED",  apply_fade)  -- entering combat
    SPU:register_event("PLAYER_REGEN_ENABLED",   apply_fade)  -- leaving combat
    SPU:register_event("PLAYER_TARGET_CHANGED",  apply_fade)
    SPU:register_event("PLAYER_ENTERING_WORLD",  apply_fade)
    SPU:register_event("ACTIONBAR_UPDATE_STATE", apply_fade)

    -- Health / power: filter to the player unit to avoid needless work.
    -- NOTE: WotLK 3.3.5a has no UNIT_POWER; use the per-power-type events.
    SPU:register_event("UNIT_HEALTH",       function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_MANA",         function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_RAGE",         function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_ENERGY",       function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_RUNIC_POWER",  function(_, unit) if unit == "player" then apply_fade() end end)
    SPU:register_event("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" then apply_fade() end end)

    -- Initial state after everything loads.
    apply_fade()
end
