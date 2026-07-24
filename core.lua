-- core.lua : addon table, shared event system, saved vars, slash command
local addon_name = ...

local SPU = {}
_G["StockPlusUI"] = SPU

SPU.name    = "StockPlusUI"
SPU.modules = {}   -- registered feature modules
SPU.frame   = CreateFrame("Frame", "StockPlusUIEventFrame", UIParent)

-- Lightweight per-event listener registry so modules don't each create a frame.
-- listeners[event] = { fn1, fn2, ... }
local listeners = {}

function SPU:register_event(event, fn)
    if not listeners[event] then
        listeners[event] = {}
        self.frame:RegisterEvent(event)
    end
    table.insert(listeners[event], fn)
end

SPU.frame:SetScript("OnEvent", function(_, event, ...)
    local fns = listeners[event]
    if fns then
        for i = 1, #fns do
            fns[i](event, ...)
        end
    end
end)

-- Modules call SPU:register_module({ name = ..., on_init = function(self, db) end })
function SPU:register_module(module)
    table.insert(self.modules, module)
end

-- Config page registry. Modules call SPU:register_config("Label", build_fn).
-- Each becomes a child page under the parent "StockPlusUI" category. build_fn
-- receives the child panel frame and populates it. Pages are built after the
-- parent panel exists (see config.lua), so we queue them until then.
SPU.config_pages = {}   -- { { name = ..., build = ... }, ... }

function SPU:register_config(name, build_fn)
    table.insert(self.config_pages, { name = name, build = build_fn })
end

-- Bootstrap once saved variables are available.
SPU:register_event("ADDON_LOADED", function(_, loaded_name)
    if loaded_name ~= addon_name then return end

    StockPlusUIDB = StockPlusUIDB or {}
    SPU.db = StockPlusUIDB
    SPU:apply_defaults(SPU.db)   -- defined in config.lua

    for i = 1, #SPU.modules do
        local m = SPU.modules[i]
        SPU.db[m.name] = SPU.db[m.name] or {}
        if m.on_init then m:on_init(SPU.db[m.name]) end
    end
end)

-- Reusable taint-safe alpha fader. Returns a controller with :fade_to(alpha)
-- and :set(alpha). Uses SetAlpha only (never writes fields onto secure frames).
function SPU:create_fader(get_frames, fade_time)
    local driver = CreateFrame("Frame")
    driver:Hide()
    local from, to, elapsed, duration = 1, 1, 0, 0

    local function set(a)
        local frames = get_frames()
        for i = 1, #frames do
            local f = frames[i]
            if f then f:SetAlpha(a) end
        end
    end

    driver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = (duration > 0) and (elapsed / duration) or 1
        if t >= 1 then set(to); self:Hide()
        else set(from + (to - from) * t) end
    end)

    local ctrl = {}
    function ctrl:set(a) set(a); driver:Hide() end
    function ctrl:fade_to(target)
        local frames = get_frames()
        from     = (frames[1] and frames[1]:GetAlpha()) or target
        to       = target
        elapsed  = 0
        duration = fade_time or 0.25
        if duration <= 0 or from == to then set(target); driver:Hide()
        else driver:Show() end
    end
    return ctrl
end

-- Shared "should the UI be shown" state used by all fader modules. Modules with
-- extra conditions (e.g. party health, editbox focus) OR their own checks on top.
local function is_power_at_default()
    local pt  = UnitPowerType("player")
    local cur = UnitPower("player")
    if pt == 1 or pt == 6 then       -- Rage / Runic Power
        return cur == 0
    else                              -- Mana / Energy / Focus
        return cur >= UnitPowerMax("player")
    end
end
SPU.is_power_at_default = is_power_at_default

-- Base show condition: combat, target, missing health, non-default power.
-- NOTE: hover is intentionally NOT here — each module tracks its own frame's
-- hover separately.
function SPU:should_ui_show()
    if InCombatLockdown() then return true end
    if UnitExists("target") then return true end
    if UnitHealth("player") < UnitHealthMax("player") then return true end
    if not is_power_at_default() then return true end
    return false
end

-- Slash command: /spu or /stockplus opens the options panel.
SLASH_STOCKPLUSUI1 = "/stockplus"
SLASH_STOCKPLUSUI2 = "/stockplusui"
SLASH_STOCKPLUSUI3 = "/sui" 
SLASH_STOCKPLUSUI4 = "/spui"
SlashCmdList["STOCKPLUSUI"] = function()
    -- InterfaceOptionsFrame_OpenToCategory has a known 3.3.5 quirk: call twice.
    InterfaceOptionsFrame_OpenToCategory(SPU.options_panel)
    InterfaceOptionsFrame_OpenToCategory(SPU.options_panel)
end
