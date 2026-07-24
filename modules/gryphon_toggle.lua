-- modules/gryphon_toggle.lua : show or hide the action bar end-cap gryphons
local SPU = _G["StockPlusUI"]

local gryphon = { name = "gryphon_toggle" }
SPU:register_module(gryphon)

-- The two decorative end-cap textures on the main action bar. These are plain
-- textures (not secure frames), so Hide/Show is taint-safe.
local caps = {
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
}

local db  -- module settings (set in on_init)

-- Apply current setting: hidden == true -> hide gryphons; else show them.
local function apply_gryphons()
    if not db then return end
    for i = 1, #caps do
        local f = _G[caps[i]]
        if f then
            if db.hidden then
                f:Hide()
            else
                f:Show()
            end
        end
    end
end

SPU.apply_gryphons = apply_gryphons  -- expose for the config panel

function SPU:refresh_gryphons()
    apply_gryphons()
end

function gryphon:on_init(settings)
    db = settings
    -- Re-apply on load and whenever the bar art reappears (e.g. after a
    -- vehicle/bonus-bar swap that Blizzard rebuilds).
    SPU:register_event("PLAYER_ENTERING_WORLD", apply_gryphons)
    SPU:register_event("ACTIONBAR_PAGE_CHANGED", apply_gryphons)
    apply_gryphons()
end
