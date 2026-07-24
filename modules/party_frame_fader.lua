-- modules/party_fader.lua : fade the party frames by player state, but reveal
-- them whenever a party member is hurt (so you never miss a dropping ally).
local SPU = _G["StockPlusUI"]

local module = { name = "party_fader" }
SPU:register_module(module)

local db
local mouse_over = false
local fader
local current

local function get_frames()
    local out = {}
    for i = 1, MAX_PARTY_MEMBERS or 4 do
        local f = _G["PartyMemberFrame" .. i]
        if f then out[#out + 1] = f end
    end
    return out
end

-- Any party member below full health? (the party-specific show condition)
local function party_member_hurt()
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        if UnitExists(unit) and UnitHealth(unit) < UnitHealthMax(unit) then
            return true
        end
    end
    return false
end

local function should_show()
    if SPU:should_ui_show() then return true end
    if party_member_hurt() then return true end
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

SPU.apply_party = apply
function SPU:refresh_party()
    if db and db.enabled then current = nil; apply()
    else if fader then fader:set(1.0) end; current = 1.0 end
end

local function mouse_over_party()
    for i = 1, MAX_PARTY_MEMBERS or 4 do
        local f = _G["PartyMemberFrame" .. i]
        if f and f:IsVisible() and MouseIsOver(f) then return true end
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
    SPU:register_event("PARTY_MEMBERS_CHANGED",  apply)   -- join/leave

    -- player power/health
    SPU:register_event("UNIT_MANA",         function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_RAGE",         function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_ENERGY",       function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_RUNIC_POWER",  function(_, u) if u == "player" then apply() end end)
    SPU:register_event("UNIT_DISPLAYPOWER", function(_, u) if u == "player" then apply() end end)

    -- health for player AND party members -> reveal on any hurt ally
    SPU:register_event("UNIT_HEALTH", function(_, u)
        if u == "player" or u == "party1" or u == "party2" or u == "party3" or u == "party4" then
            apply()
        end
    end)

    local poller, acc = CreateFrame("Frame"), 0
    poller:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        local over = mouse_over_party()
        if over ~= mouse_over then mouse_over = over; apply() end
    end)

    apply()
end

-- ---- config page -----------------------------------------------------------

SPU:register_config("Party", function(panel)
    local p = function() return SPU.db.party_fader end

    local header = SPU:make_header(panel, "Party", nil)
    local sub    = SPU:make_subtitle(panel, "Fade party frames when idle. They reveal automatically when a party member is hurt.", header)

    local toggle = SPU:make_checkbox(panel, "StockPlusUIPartyFade", "Fade party frames", sub, -16,
        function() return p().enabled end,
        function(v) p().enabled = v; if SPU.refresh_party then SPU:refresh_party() end end)

    SPU:make_alpha_slider(panel, "StockPlusUIPartyAlpha", "Faded opacity", toggle, -24,
        function() return p().faded_alpha end,
        function(v) p().faded_alpha = v; if SPU.refresh_party then SPU:refresh_party() end end)
end)
