-- modules/game_menu_button.lua : adds a "StockPlusUI" entry to the ESC menu
local SPU = _G["StockPlusUI"]

local menu_button
local resized = false  -- only grow the frame once

local function open_config()
    HideUIPanel(GameMenuFrame)
    InterfaceOptionsFrame_OpenToCategory(SPU.options_panel)
    InterfaceOptionsFrame_OpenToCategory(SPU.options_panel)
end

local function build_menu_button()
    if menu_button then return end

    menu_button = CreateFrame("Button", "StockPlusUIMenuButton", GameMenuFrame, "GameMenuButtonTemplate")
    menu_button:SetText("StockPlusUI")
    menu_button:SetScript("OnClick", open_config)

    -- Synced normal/highlight so it doesn't resize on hover, then set exact size.
    menu_button:SetNormalFontObject("GameFontNormalLarge")
    menu_button:SetHighlightFontObject("GameFontHighlightLarge")

    local fs = menu_button:GetFontString()
    local font, _, flags = fs:GetFont()
    fs:SetFont(font, 14, flags)          -- between Normal(12) and Large(16)
    fs:SetTextColor(0.2, 1.0, 0.6)       -- StockPlusUI green text, native button art

    -- Anchor tight below "Return to Game", matching native button spacing.
    menu_button:SetPoint("TOP", GameMenuButtonContinue, "BOTTOM", 0, -1)
    menu_button:SetWidth(GameMenuButtonContinue:GetWidth())

    -- Grow the frame just enough for one more button (no section gap).
    if not resized then
        GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 24)
        resized = true
    end
end

local game_menu = { name = "game_menu_button" }
SPU:register_module(game_menu)

function game_menu:on_init()
    if GameMenuFrame then
        build_menu_button()
        GameMenuFrame:HookScript("OnShow", build_menu_button)
    end
end
