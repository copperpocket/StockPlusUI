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

-- Shared "should the UI be shown" state used by all fader modules. Reads the
-- configurable conditions from db.conditions. Combat/target default ON (only
-- skipped if explicitly disabled); group defaults OFF. Plus HP/MP thresholds.
-- Hover is intentionally NOT here — each module tracks its own frame's hover.
function SPU:should_ui_show()
    local c = (self.db and self.db.conditions) or {}

    if c.combat ~= false and InCombatLockdown() then return true end
    if c.target ~= false and UnitExists("target") then return true end
    if c.group and (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) then return true end

    local hp_t = c.hp_threshold or 100
    local mp_t = c.mp_threshold or 100

    local hp_max = UnitHealthMax("player")
    if hp_max > 0 and (UnitHealth("player") / hp_max * 100) < hp_t then
        return true
    end

    local mp_max = UnitPowerMax("player")
    if mp_max > 0 and (UnitPower("player") / mp_max * 100) < mp_t then
        return true
    end

    return false
end

-- Re-apply every module's fade state. Used when shared "general" settings
-- change so all elements re-evaluate immediately.
function SPU:refresh_all()
    if self.apply_fade         then self:apply_fade() end
    if self.apply_player_frame then self:apply_player_frame() end
    if self.apply_minimap      then self:apply_minimap() end
    if self.apply_buffs        then self:apply_buffs() end
    if self.apply_party        then self:apply_party() end
    if self.apply_objectives   then self:apply_objectives() end
    if self.apply_chat_fade    then self:apply_chat_fade() end
end

-- Re-evaluate all modules when group composition changes (for the group condition).
SPU:register_event("PARTY_MEMBERS_CHANGED", function() SPU:refresh_all() end)
SPU:register_event("RAID_ROSTER_UPDATE",    function() SPU:refresh_all() end)
SPU:register_event("PLAYER_LOGIN", function()
    if SPU.build_config_pages then SPU:build_config_pages() end
end)

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
