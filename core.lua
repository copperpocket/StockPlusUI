-- core.lua : addon table, shared event system, saved vars, profiles, slash cmd
local addon_name = ...

local SPU = {}
_G["StockPlusUI"] = SPU

SPU.name    = "StockPlusUI"
SPU.modules = {}
SPU.frame   = CreateFrame("Frame", "StockPlusUIEventFrame", UIParent)

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
        for i = 1, #fns do fns[i](event, ...) end
    end
end)

function SPU:register_module(module)
    table.insert(self.modules, module)
end

SPU.config_pages = {}

function SPU:register_config(name, build_fn)
    table.insert(self.config_pages, { name = name, build = build_fn })
end

-- ---- profiles --------------------------------------------------------------
-- StockPlusUIDB = { profiles = { Name = {...}, ... }, active = "Name" }
-- SPU.db points at the ACTIVE profile, so modules read SPU.db.<module> as before.

local DEFAULT_PROFILE = "Main"

local function ensure_structure()
    StockPlusUIDB = StockPlusUIDB or {}

    -- migrate old flat structure -> profiles.Main (preserves current config)
    if not StockPlusUIDB.profiles then
        local old = StockPlusUIDB
        local looks_flat = old.action_bar_fader or old.chat_enhance or old.conditions
        StockPlusUIDB = { profiles = {}, active = DEFAULT_PROFILE }
        StockPlusUIDB.profiles[DEFAULT_PROFILE] = looks_flat and old or {}
        StockPlusUIDB.profiles[DEFAULT_PROFILE].profiles = nil
        StockPlusUIDB.profiles[DEFAULT_PROFILE].active   = nil
    end

    StockPlusUIDB.active = StockPlusUIDB.active or DEFAULT_PROFILE
    StockPlusUIDB.profiles[StockPlusUIDB.active] =
        StockPlusUIDB.profiles[StockPlusUIDB.active] or {}
end

function SPU:get_profile_names()
    local names = {}
    for name in pairs(StockPlusUIDB.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function SPU:get_active_profile()
    return StockPlusUIDB.active
end

-- Switching sets active + reloads to apply the profile cleanly.
function SPU:set_active_profile(name)
    if not StockPlusUIDB.profiles[name] then return end
    StockPlusUIDB.active = name
    ReloadUI()
end

function SPU:create_profile(name)
    if not name or name == "" or StockPlusUIDB.profiles[name] then return false end
    StockPlusUIDB.profiles[name] = {}
    return true
end

function SPU:copy_profile(from, to)
    if not StockPlusUIDB.profiles[from] then return false end
    if not to or to == "" or StockPlusUIDB.profiles[to] then return false end
    local function deep_copy(t)
        local c = {}
        for k, v in pairs(t) do
            if type(v) == "table" then c[k] = deep_copy(v) else c[k] = v end
        end
        return c
    end
    StockPlusUIDB.profiles[to] = deep_copy(StockPlusUIDB.profiles[from])
    return true
end

function SPU:delete_profile(name)
    if name == DEFAULT_PROFILE then return false end       -- keep a baseline
    if name == StockPlusUIDB.active then return false end   -- can't delete active
    StockPlusUIDB.profiles[name] = nil
    return true
end

-- Bootstrap once saved variables are available.
SPU:register_event("ADDON_LOADED", function(_, loaded_name)
    if loaded_name ~= addon_name then return end

    ensure_structure()
    SPU.db = StockPlusUIDB.profiles[StockPlusUIDB.active]
    SPU:apply_defaults(SPU.db)   -- defined in config.lua

    for i = 1, #SPU.modules do
        local m = SPU.modules[i]
        SPU.db[m.name] = SPU.db[m.name] or {}
        if m.on_init then m:on_init(SPU.db[m.name]) end
    end
end)

-- Reusable taint-safe alpha fader.
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

-- Shared "should the UI be shown" state used by all fader modules.
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

    -- Power: rage/runic power rest at 0 (show when ABOVE 0); mana/energy/focus
    -- rest at full (show when BELOW the threshold %). This keeps the "show on
    -- resource activity" behavior correct per class.
    local pt = UnitPowerType("player")
    local mp_max = UnitPowerMax("player")
    if mp_max > 0 then
        if pt == 1 or pt == 6 then
            -- rage (1) or runic power (6): resting = 0, show if any is present
            if UnitPower("player") > 0 then return true end
        else
            -- mana (0) / energy (3) / focus (2): resting = full
            if (UnitPower("player") / mp_max * 100) < mp_t then return true end
        end
    end

    return false
end

function SPU:refresh_all()
    if self.apply_fade         then self:apply_fade() end
    if self.apply_player_frame then self:apply_player_frame() end
    if self.apply_minimap      then self:apply_minimap() end
    if self.apply_buffs        then self:apply_buffs() end
    if self.apply_party        then self:apply_party() end
    if self.apply_objectives   then self:apply_objectives() end
    if self.apply_chat_fade    then self:apply_chat_fade() end
end

SPU:register_event("PARTY_MEMBERS_CHANGED", function() SPU:refresh_all() end)
SPU:register_event("RAID_ROSTER_UPDATE",    function() SPU:refresh_all() end)
SPU:register_event("PLAYER_LOGIN", function()
    if SPU.build_config_pages then SPU:build_config_pages() end
end)

SLASH_STOCKPLUSUI1 = "/stockplus"
SLASH_STOCKPLUSUI2 = "/stockplusui"
SLASH_STOCKPLUSUI3 = "/sui"
SLASH_STOCKPLUSUI4 = "/spui"
SlashCmdList["STOCKPLUSUI"] = function()
    InterfaceOptionsFrame_OpenToCategory(SPU.options_panel)
    InterfaceOptionsFrame_OpenToCategory(SPU.options_panel)
end
