-- modules/action_bar_fader.lua : auto-fade each action bar independently by state
local SPU = _G["StockPlusUI"]

local fader = { name = "action_bar_fader" }
SPU:register_module(fader)

-- Register this module's config page under the parent category.
SPU:register_config("Action Bars", function(panel)
    local abf = function() return SPU.db.action_bar_fader end

    local header = SPU:make_header(panel, "Action Bars", nil)
    local sub    = SPU:make_subtitle(panel, "Fade each bar independently based on player state.", header)

    local bar_rows = {
        { key = "main",         label = "Fade main bar" },
        { key = "bottom_left",  label = "Fade bottom-left bar" },
        { key = "bottom_right", label = "Fade bottom-right bar" },
        { key = "right_1",      label = "Fade right bar 1" },
        { key = "right_2",      label = "Fade right bar 2" },
    }

    local anchor = sub
    for i, row in ipairs(bar_rows) do
        anchor = SPU:make_checkbox(panel, "StockPlusUIBar_" .. row.key, row.label, anchor,
            i == 1 and -16 or -6,
            function() return abf().bars[row.key].enabled end,
            function(v)
                abf().bars[row.key].enabled = v
                if SPU.refresh_fader then SPU:refresh_fader() end
            end)
    end

    local slider = SPU:make_alpha_slider(panel, "StockPlusUIBarsAlpha", "Faded opacity", anchor, -24,
        function() return abf().faded_alpha end,
        function(v)
            abf().faded_alpha = v
            if SPU.refresh_fader then SPU:refresh_fader() end
        end)

    SPU:make_checkbox(panel, "StockPlusUIHideGryphons", "Hide action bar gryphons", slider, -24,
        function() return SPU.db.gryphon_toggle.hidden end,
        function(v)
            SPU.db.gryphon_toggle.hidden = v
            if SPU.refresh_gryphons then SPU:refresh_gryphons() end
        end)
end)

-- Per-bar definitions. Each key gets its own enabled setting, config checkbox,
-- and fade driver, so any bar can fade while others stay put.
local bar_defs = {
    { key = "main",         label = "Fade main bar",         frames = { "MainMenuBarArtFrame", "BonusActionBarFrame", "MainMenuExpBar", "ReputationWatchBar" } },
    { key = "bottom_left",  label = "Fade bottom-left bar",  frames = { "MultiBarBottomLeft" } },
    { key = "bottom_right", label = "Fade bottom-right bar", frames = { "MultiBarBottomRight" } },
    { key = "right_1",      label = "Fade right bar 1",      frames = { "MultiBarRight" } },
    { key = "right_2",      label = "Fade right bar 2",      frames = { "MultiBarLeft" } },
}

local db
local mouse_over = false
local drivers   = {}   -- key -> fade controller
local current   = {}   -- key -> last applied alpha (avoid redundant fades)

-- ---- state evaluation (shared across all bars) -----------------------------

local function is_power_at_default()
    local pt  = UnitPowerType("player")
    local cur = UnitPower("player")
    if pt == 1 or pt == 6 then return cur == 0            -- Rage / Runic Power
    else return cur >= UnitPowerMax("player") end          -- Mana / Energy / Focus
end

local function should_show()
    if InCombatLockdown() then return true end
    if UnitExists("target") then return true end
    if UnitHealth("player") < UnitHealthMax("player") then return true end
    if not is_power_at_default() then return true end
    if mouse_over then return true end
    return false
end

-- ---- resolve a bar's frame globals to actual frame objects -----------------

local function make_get_frames(def)
    return function()
        local out = {}
        for i = 1, #def.frames do
            local f = _G[def.frames[i]]
            if f then out[#out + 1] = f end
        end
        return out
    end
end

-- ---- applying the fade ------------------------------------------------------

local function apply_bar(def)
    local settings = db.bars[def.key]
    local ctrl = drivers[def.key]
    if not ctrl then return end

    if not settings.enabled then
        -- bar opted out: keep it fully visible
        if current[def.key] ~= 1.0 then
            ctrl:set(1.0)
            current[def.key] = 1.0
        end
        return
    end

    local target = should_show() and db.shown_alpha or db.faded_alpha
    if current[def.key] == target then return end
    current[def.key] = target
    ctrl:fade_to(target)
end

local function apply_fade()
    if not db then return end
    for i = 1, #bar_defs do
        apply_bar(bar_defs[i])
    end
end

SPU.apply_fade = apply_fade

-- Called by config when a bar toggle changes. Reset that bar's cached alpha so
-- it re-evaluates on the next apply.
function SPU:refresh_fader()
    for i = 1, #bar_defs do
        current[bar_defs[i].key] = nil
    end
    apply_fade()
end

-- ---- taint-safe hover polling (any enabled bar) ----------------------------

local function is_mouse_over_bars()
    for i = 1, #bar_defs do
        if db.bars[bar_defs[i].key].enabled then
            local frames = drivers[bar_defs[i].key] and make_get_frames(bar_defs[i])()
            if frames then
                for j = 1, #frames do
                    local f = frames[j]
                    if f:IsVisible() and MouseIsOver(f) then return true end
                end
            end
        end
    end
    return false
end

local poller, acc = CreateFrame("Frame"), 0
poller:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    local over = is_mouse_over_bars()
    if over ~= mouse_over then
        mouse_over = over
        apply_fade()
    end
end)

-- ---- init & events ----------------------------------------------------------

function fader:on_init(settings)
    db = settings

    -- one independent fade driver per bar
    for i = 1, #bar_defs do
        drivers[bar_defs[i].key] = SPU:create_fader(make_get_frames(bar_defs[i]), db.fade_time)
    end

    SPU:register_event("PLAYER_REGEN_DISABLED",  apply_fade)
    SPU:register_event("PLAYER_REGEN_ENABLED",   apply_fade)
    SPU:register_event("PLAYER_TARGET_CHANGED",  apply_fade)
    SPU:register_event("PLAYER_ENTERING_WORLD",  apply_fade)
    SPU:register_event("ACTIONBAR_UPDATE_STATE", apply_fade)

    SPU:register_event("UNIT_HEALTH",       function(_, u) if u == "player" then apply_fade() end end)
    SPU:register_event("UNIT_MANA",         function(_, u) if u == "player" then apply_fade() end end)
    SPU:register_event("UNIT_RAGE",         function(_, u) if u == "player" then apply_fade() end end)
    SPU:register_event("UNIT_ENERGY",       function(_, u) if u == "player" then apply_fade() end end)
    SPU:register_event("UNIT_RUNIC_POWER",  function(_, u) if u == "player" then apply_fade() end end)
    SPU:register_event("UNIT_DISPLAYPOWER", function(_, u) if u == "player" then apply_fade() end end)

    apply_fade()
end
