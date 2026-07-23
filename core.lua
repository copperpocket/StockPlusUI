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
