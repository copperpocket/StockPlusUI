-- modules/buff_fader.lua : fade player buffs/debuffs by player state
local SPU = _G["StockPlusUI"]

local module = { name = "buff_fader" }
SPU:register_module(module)

local db
local mouse_over = false
local fader
local current

-- BuffFrame covers buffs AND self-debuffs; TemporaryEnchantFrame covers weapon
-- enchants. Both are non-protected, so SetAlpha is taint-safe.
local frame_names = { "BuffFrame", "TemporaryEnchantFrame" }

local function get_frames()
    local out = {}
    for i = 1, #frame_names do
        local f = _G[frame_names[i]]
        if f then out[#out + 1] = f end
    end
    return out
end

local function is_power_at_default()
    local pt  = UnitPowerType("player")
    local cur = UnitPower("player")
    if pt == 1 or pt == 6 then return cur == 0
    else return cur >= UnitPowerMax("player") end
end

local function should_show()
    if InCombatLockdown() then return true end
    if UnitExists("target") then return true end
    if UnitHealth("player") < UnitHealthMax("player") then return true end
    if not is_power_at_default() then return true end
    if mouse_over then return true end
    return false
end

local function apply()
    if not db or not db.enabled then return end
    local target = should_show() and db.shown_alpha or db.faded_alpha
    if current == target then return end
    current = target
    fader:fade_to(target)
end

SPU.apply_buffs = apply
function SPU:refresh_buffs()
    if db and db.enabled then current = nil; apply()
    else if fader then fader:set(1.0) end; current = 1.0 end
end

-- hover: check if the mouse is over the buff frame OR any visible buff button
local function mouse_over_buffs()
    local bf = _G["BuffFrame"]
    if bf and bf:IsVisible() and MouseIsOver(bf) then return true end
    -- buttons can extend beyond BuffFrame's rect; check them directly
    for i = 1, 40 do
        local b = _G["BuffButton" .. i]
        if b and b:IsVisible() and MouseIsOver(b) then return true end
    end
    return false
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
        local over = mouse_over_buffs()
        if over ~= mouse_over then mouse_over = over; apply() end
    end)

    apply()
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Buffs", function(panel)
    local b = function() return SPU.db.buff_fader end

    local header = SPU:make_header(panel, "Buffs", nil)
    local sub    = SPU:make_subtitle(panel, "Fade player buffs and debuffs based on player state.", header)

    local toggle = SPU:make_checkbox(panel, "StockPlusUIBuffFade", "Fade buffs", sub, -16,
        function() return b().enabled end,
        function(v) b().enabled = v; if SPU.refresh_buffs then SPU:refresh_buffs() end end)

    SPU:make_alpha_slider(panel, "StockPlusUIBuffAlpha", "Faded opacity", toggle, -24,
        function() return b().faded_alpha end,
        function(v) b().faded_alpha = v; if SPU.refresh_buffs then SPU:refresh_buffs() end end)
end)
