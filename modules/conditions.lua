-- modules/conditions.lua : shared visibility conditions used by all fader
-- modules. These feed SPU:should_ui_show(), so every element fades in under
-- the same conditions.
local SPU = _G["StockPlusUI"]

SPU:register_config("Conditions", function(panel)
    local c = function() return SPU.db.conditions end

    local header = SPU:make_header(panel, "Conditions", nil)
    local sub    = SPU:make_subtitle(panel, "Shared conditions controlling when all UI elements fade in.", header)

    local combat = SPU:make_checkbox(panel, "StockPlusUICondCombat", "Show in combat", sub, -16,
        function() return c().combat end,
        function(v) c().combat = v; if SPU.refresh_all then SPU:refresh_all() end end)

    local target = SPU:make_checkbox(panel, "StockPlusUICondTarget", "Show when target selected", combat, -6,
        function() return c().target end,
        function(v) c().target = v; if SPU.refresh_all then SPU:refresh_all() end end)

    local group = SPU:make_checkbox(panel, "StockPlusUICondGroup", "Show while in a group", target, -6,
        function() return c().group end,
        function(v) c().group = v; if SPU.refresh_all then SPU:refresh_all() end end)

    local hp = SPU:make_slider(panel, "StockPlusUICondHP", "Show below health %", group, -24,
        0, 100, 5, "Show below health %%: %d",
        function() return c().hp_threshold end,
        function(v) c().hp_threshold = v; if SPU.refresh_all then SPU:refresh_all() end end)

    SPU:make_slider(panel, "StockPlusUICondMP", "Show below power %", hp, -40,
        0, 100, 5, "Show below power %%: %d",
        function() return c().mp_threshold end,
        function(v) c().mp_threshold = v; if SPU.refresh_all then SPU:refresh_all() end end)
end)
